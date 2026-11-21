class_name MemoryBlackboard
extends RefCounted

const VERSION := 1
const MAX_ENTRIES_LIMIT := 32

var _max_entries: int = 8
var _expiry_ticks: int = 300
var _entries: Dictionary = {}
var _selected_target_id: String = ""
var _recent_intent_id: int = 0
var _recent_decision_tick: int = 0
var _hysteresis := {
	"intent_id": 0,
	"target_id": "",
	"score": 0.0,
	"hold_until_tick": 0,
}


func configure(max_entries: int, expiry_ticks: int) -> bool:
	if max_entries <= 0 or max_entries > MAX_ENTRIES_LIMIT or expiry_ticks <= 0 or expiry_ticks > CoreCombatRules.MAX_CLOCK:
		return false
	_max_entries = max_entries
	_expiry_ticks = expiry_ticks
	return true


func record_damage(attacker_id: String, damage: float, position: Vector2, simulation_tick: int,
		max_threat: int, threat_per_damage: float) -> bool:
	if not SectorIds.valid(attacker_id) or not is_finite(damage) or damage <= 0.0 or not position.is_finite():
		return false
	if simulation_tick < 0 or max_threat <= 0 or not is_finite(threat_per_damage) or threat_per_damage <= 0.0:
		return false
	var entry := _entry_for(attacker_id, simulation_tick)
	if entry.is_empty():
		return false
	var added := maxi(1, roundi(damage * threat_per_damage))
	entry["threat"] = clampi(int(entry["threat"]) + added, 0, max_threat)
	entry["last_threat_tick"] = simulation_tick
	entry["last_seen_tick"] = maxi(int(entry["last_seen_tick"]), simulation_tick)
	entry["last_decay_tick"] = simulation_tick
	entry["x"] = position.x
	entry["y"] = position.y
	entry["distance"] = maxf(0.0, float(entry.get("distance", 0.0)))
	_entries[attacker_id] = entry
	return true


func advance(snapshot: Dictionary, simulation_tick: int, decay_interval_ticks: int, decay_amount: int) -> bool:
	if not DtoContract.is_primitive_safe(snapshot) or simulation_tick < 0:
		return false
	if int(snapshot.get("simulation_tick", -1)) != simulation_tick or not snapshot.get("candidates") is Array:
		return false
	if decay_interval_ticks <= 0 or decay_amount <= 0:
		return false
	_decay_to(simulation_tick, decay_interval_ticks, decay_amount)
	var visible: Dictionary = {}
	for raw in snapshot["candidates"]:
		if not raw is Dictionary:
			return false
		var candidate: Dictionary = raw
		var candidate_id := str(candidate.get("stable_id", ""))
		var position: Variant = candidate.get("position")
		if not SectorIds.valid(candidate_id) or not position is Dictionary:
			return false
		if not _entries.has(candidate_id) and _entries.size() >= _max_entries:
			continue
		var entry := _entry_for(candidate_id, simulation_tick)
		if entry.is_empty():
			return false
		entry["last_seen_tick"] = simulation_tick
		entry["x"] = float(position["x"])
		entry["y"] = float(position["y"])
		entry["distance"] = float(candidate.get("distance", INF))
		_entries[candidate_id] = entry
		visible[candidate_id] = true
	_expire(simulation_tick, visible)
	if not _selected_target_id.is_empty() and not _entries.has(_selected_target_id):
		_selected_target_id = ""
	if not str(_hysteresis["target_id"]).is_empty() and not _entries.has(str(_hysteresis["target_id"])):
		_hysteresis["target_id"] = ""
	return true


func primary_target_id() -> String:
	var ordered := _ordered_entries()
	return str(ordered[0]["stable_id"]) if not ordered.is_empty() else ""


func primary_threat() -> int:
	var target := primary_target_id()
	return int(_entries[target]["threat"]) if not target.is_empty() else 0


func last_threat_tick() -> int:
	var target := primary_target_id()
	return int(_entries[target]["last_threat_tick"]) if not target.is_empty() else -1


func last_known_position(target_id: String = "") -> Vector2:
	var resolved := target_id if not target_id.is_empty() else primary_target_id()
	if resolved.is_empty() or not _entries.has(resolved):
		return Vector2.INF
	var entry: Dictionary = _entries[resolved]
	return Vector2(float(entry["x"]), float(entry["y"]))


func selected_target_id() -> String:
	return _selected_target_id


func entry_count() -> int:
	return _entries.size()


func commit_decision(intent_id: int, target_id: String, score: float, decision_tick: int, hysteresis_state: Dictionary) -> bool:
	if intent_id < 0 or decision_tick < 0 or not is_finite(score):
		return false
	if not target_id.is_empty() and (not SectorIds.valid(target_id) or not _entries.has(target_id)):
		return false
	if not _valid_hysteresis(hysteresis_state):
		return false
	_selected_target_id = target_id
	_recent_intent_id = intent_id
	_recent_decision_tick = decision_tick
	_hysteresis = hysteresis_state.duplicate(true)
	return true


func snapshot_state() -> Dictionary:
	var entries: Array = []
	var ids: Array = _entries.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = _entries[id]
		entries.append({
			"stable_id": str(id),
			"threat": int(entry["threat"]),
			"last_seen_tick": int(entry["last_seen_tick"]),
			"last_threat_tick": int(entry["last_threat_tick"]),
			"last_decay_tick": int(entry["last_decay_tick"]),
			"x": float(entry["x"]),
			"y": float(entry["y"]),
			"distance": float(entry["distance"]),
		})
	return {
		"version": VERSION,
		"max_entries": _max_entries,
		"expiry_ticks": _expiry_ticks,
		"entries": entries,
		"selected_target_id": _selected_target_id,
		"recent_intent_id": _recent_intent_id,
		"recent_decision_tick": _recent_decision_tick,
		"hysteresis": _hysteresis.duplicate(true),
	}


func restore_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() == 6 and state.has("attacker_id"):
		return _restore_legacy(state)
	if state.size() != 8 or int(state.get("version", -1)) != VERSION:
		return false
	if not _integer(state.get("max_entries")) or int(state["max_entries"]) <= 0 or int(state["max_entries"]) > MAX_ENTRIES_LIMIT:
		return false
	if not _integer(state.get("expiry_ticks")) or int(state["expiry_ticks"]) <= 0:
		return false
	if not state.get("entries") is Array or state["entries"].size() > int(state["max_entries"]):
		return false
	var planned: Dictionary = {}
	for raw in state["entries"]:
		if not raw is Dictionary or raw.size() != 8:
			return false
		var entry: Dictionary = raw
		var stable_id: Variant = entry.get("stable_id")
		if not stable_id is String or not SectorIds.valid(stable_id) or planned.has(stable_id):
			return false
		for key in ["threat", "last_seen_tick", "last_threat_tick", "last_decay_tick"]:
			if not _integer(entry.get(key)):
				return false
		if int(entry["threat"]) < 0 or int(entry["last_seen_tick"]) < -1 or int(entry["last_threat_tick"]) < -1 or int(entry["last_decay_tick"]) < 0:
			return false
		for key in ["x", "y", "distance"]:
			if not _finite(entry.get(key)):
				return false
		if float(entry["distance"]) < 0.0:
			return false
		planned[stable_id] = entry.duplicate(true)
	var selected: Variant = state.get("selected_target_id")
	if not selected is String or (not selected.is_empty() and not planned.has(selected)):
		return false
	if not _integer(state.get("recent_intent_id")) or int(state["recent_intent_id"]) < 0:
		return false
	if not _integer(state.get("recent_decision_tick")) or int(state["recent_decision_tick"]) < 0:
		return false
	var hysteresis: Variant = state.get("hysteresis")
	if not hysteresis is Dictionary or not _valid_hysteresis(hysteresis):
		return false
	if not str(hysteresis["target_id"]).is_empty() and not planned.has(str(hysteresis["target_id"])):
		return false
	_max_entries = int(state["max_entries"])
	_expiry_ticks = int(state["expiry_ticks"])
	_entries = planned
	_selected_target_id = selected
	_recent_intent_id = int(state["recent_intent_id"])
	_recent_decision_tick = int(state["recent_decision_tick"])
	_hysteresis = (hysteresis as Dictionary).duplicate(true)
	return true


func hysteresis_state() -> Dictionary:
	return _hysteresis.duplicate(true)


func clear() -> void:
	_entries.clear()
	_selected_target_id = ""
	_recent_intent_id = 0
	_recent_decision_tick = 0
	_hysteresis = {"intent_id": 0, "target_id": "", "score": 0.0, "hold_until_tick": 0}


func _entry_for(stable_id: String, simulation_tick: int) -> Dictionary:
	if _entries.has(stable_id):
		return (_entries[stable_id] as Dictionary).duplicate(true)
	if _entries.size() >= _max_entries:
		_evict_one()
	if _entries.size() >= _max_entries:
		return {}
	var entry := {
		"stable_id": stable_id,
		"threat": 0,
		"last_seen_tick": -1,
		"last_threat_tick": -1,
		"last_decay_tick": simulation_tick,
		"x": 0.0,
		"y": 0.0,
		"distance": 0.0,
	}
	_entries[stable_id] = entry
	return entry.duplicate(true)


func _decay_to(simulation_tick: int, interval_ticks: int, amount: int) -> void:
	var ids: Array = _entries.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = _entries[id]
		var last_decay := int(entry["last_decay_tick"])
		if simulation_tick <= last_decay:
			continue
		var intervals := floori(float(simulation_tick - last_decay) / float(interval_ticks))
		if intervals <= 0:
			continue
		entry["threat"] = maxi(0, int(entry["threat"]) - intervals * amount)
		entry["last_decay_tick"] = last_decay + intervals * interval_ticks
		_entries[id] = entry


func _expire(simulation_tick: int, visible: Dictionary) -> void:
	var ids: Array = _entries.keys()
	ids.sort()
	for id in ids:
		var entry: Dictionary = _entries[id]
		if visible.has(id):
			continue
		if int(entry["threat"]) <= 0 and simulation_tick - int(entry["last_seen_tick"]) > _expiry_ticks:
			_entries.erase(id)


func _evict_one() -> void:
	var ordered := _ordered_entries()
	if ordered.is_empty():
		return
	var victim: Dictionary = ordered[ordered.size() - 1]
	_entries.erase(str(victim["stable_id"]))


func _ordered_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for id in _entries:
		var entry: Dictionary = (_entries[id] as Dictionary).duplicate(true)
		result.append(entry)
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["threat"]) != int(b["threat"]):
			return int(a["threat"]) > int(b["threat"])
		if int(a["last_seen_tick"]) != int(b["last_seen_tick"]):
			return int(a["last_seen_tick"]) > int(b["last_seen_tick"])
		if not is_equal_approx(float(a["distance"]), float(b["distance"])):
			return float(a["distance"]) < float(b["distance"])
		return str(a["stable_id"]) < str(b["stable_id"])
	)
	return result


func _restore_legacy(state: Dictionary) -> bool:
	var attacker: Variant = state.get("attacker_id")
	if not attacker is String or (not attacker.is_empty() and not SectorIds.valid(attacker)):
		return false
	for key in ["value", "last_threat_tick", "last_decay_tick"]:
		if not _integer(state.get(key)):
			return false
	if int(state["value"]) < 0 or int(state["last_threat_tick"]) < -1 or int(state["last_decay_tick"]) < 0:
		return false
	if not _finite(state.get("last_known_x")) or not _finite(state.get("last_known_y")):
		return false
	clear()
	if attacker.is_empty():
		return true
	var entry := {
		"stable_id": attacker,
		"threat": int(state["value"]),
		"last_seen_tick": int(state["last_threat_tick"]),
		"last_threat_tick": int(state["last_threat_tick"]),
		"last_decay_tick": int(state["last_decay_tick"]),
		"x": float(state["last_known_x"]),
		"y": float(state["last_known_y"]),
		"distance": 0.0,
	}
	_entries[attacker] = entry
	return true


static func _valid_hysteresis(value: Dictionary) -> bool:
	if value.size() != 4:
		return false
	if not _integer(value.get("intent_id")) or int(value["intent_id"]) < 0:
		return false
	var target: Variant = value.get("target_id")
	if not target is String or (not target.is_empty() and not SectorIds.valid(target)):
		return false
	if not _finite(value.get("score")):
		return false
	return _integer(value.get("hold_until_tick")) and int(value["hold_until_tick"]) >= 0


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _finite(value) and float(value) == floorf(float(value)) and absf(float(value)) <= 2147483647.0
