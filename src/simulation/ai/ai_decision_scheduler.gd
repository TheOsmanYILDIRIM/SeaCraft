class_name AiDecisionScheduler
extends RefCounted

var decision_count: int = 0

var _physics_tick: int = 0
var _max_decisions_per_tick: int = 8
var _brains: Array[NpcBrain] = []
var _intervals: PackedInt32Array = PackedInt32Array()
var _next_due: PackedInt64Array = PackedInt64Array()
var _cursor: int = 0
var _pending_due_by_id: Dictionary = {}


func _init(max_decisions_per_tick: int = 8) -> void:
	_max_decisions_per_tick = clampi(max_decisions_per_tick, 1, 1024)


func register_brain(brain: NpcBrain, interval_ticks: int, stagger_offset: int = 0) -> bool:
	if brain == null or interval_ticks <= 1 or stagger_offset < 0 or stagger_offset >= interval_ticks:
		return false
	if _brains.has(brain):
		return false
	_brains.append(brain)
	_intervals.append(interval_ticks)
	var brain_id := str(brain.persistence_state().get("npc_stable_id", ""))
	var next_due := _physics_tick + 1 + stagger_offset
	if not brain_id.is_empty() and _pending_due_by_id.has(brain_id):
		next_due = maxi(_physics_tick + 1, int(_pending_due_by_id[brain_id]))
		_pending_due_by_id.erase(brain_id)
	_next_due.append(next_due)
	return true


func advance_physics_tick() -> int:
	_physics_tick += 1
	if _brains.is_empty():
		return 0
	var ran := 0
	var size := _brains.size()
	var last_index := _cursor
	for offset in size:
		if ran >= _max_decisions_per_tick:
			break
		var index := (_cursor + offset) % size
		if _physics_tick < _next_due[index]:
			continue
		if _brains[index].decision_tick(_physics_tick):
			decision_count += 1
		ran += 1
		_next_due[index] = _physics_tick + _intervals[index]
		last_index = index
	_cursor = (last_index + 1) % size
	return ran


func current_tick() -> int:
	return _physics_tick


func brain_count() -> int:
	return _brains.size()


func snapshot_state() -> Dictionary:
	var next_due_by_id: Dictionary = {}
	for index in _brains.size():
		var brain_id := str(_brains[index].persistence_state().get("npc_stable_id", ""))
		if not brain_id.is_empty():
			next_due_by_id[brain_id] = int(_next_due[index])
	return {"physics_tick": _physics_tick, "decision_count": decision_count, "next_due_by_id": next_due_by_id}


func restore_state(value: Variant) -> bool:
	if not _brains.is_empty() or not value is Dictionary or value.size() not in [2, 3]:
		return false
	var state: Dictionary = value
	if not _integer(state.get("physics_tick")) or int(state["physics_tick"]) < 0:
		return false
	if not _integer(state.get("decision_count")) or int(state["decision_count"]) < 0:
		return false
	var pending: Dictionary = {}
	if state.has("next_due_by_id"):
		var raw_due: Variant = state["next_due_by_id"]
		if not raw_due is Dictionary or raw_due.size() > 1024:
			return false
		for brain_id in raw_due:
			if not brain_id is String or not SectorIds.valid(brain_id) or not _integer(raw_due[brain_id]) or int(raw_due[brain_id]) <= int(state["physics_tick"]):
				return false
			pending[brain_id] = int(raw_due[brain_id])
	_physics_tick = int(state["physics_tick"])
	decision_count = int(state["decision_count"])
	_pending_due_by_id = pending
	_cursor = 0
	return true


static func _integer(value_in: Variant) -> bool:
	if typeof(value_in) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value_in)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
