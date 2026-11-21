class_name NpcBrain
extends RefCounted

enum State { PATROL, ALERT, RETREAT, REPAIR, RESUME }
enum Intent { PATROL_TO_WAYPOINT, INVESTIGATE_THREAT, RETREAT_TO_SAFE_POINT, REPAIR, RESUME_PATROL }

var decision_count: int = 0
var perception_query_count: int = 0
var perception_candidate_count: int = 0

var _entity_id: String = ""
var _sector: SectorRuntime
var _combat: CombatAuthority
var _motor: ShipMotor
var _tuning: NpcAiTuning
var _executor := NpcIntentExecutor.new()
var _memory := NpcThreatMemory.new()
var _authority_enabled: bool = true
var _valid: bool = false
var _sunk: bool = false
var _state: int = State.PATROL
var _intent: int = Intent.PATROL_TO_WAYPOINT
var _target_entity_id: String = ""
var _destination: Vector2 = Vector2.ZERO
var _patrol_index: int = 0
var _selected_safe_id: String = ""
var _decision_sequence: int = 0
var _last_decision_tick: int = 0
var _last_transition_reason: String = "initial"
var _perception_candidates: Array[String] = []
var _perceived_target: String = ""
var _last_perception_inspected: int = 0
var _repair_started_tick: int = -1
var _next_repair_tick: int = 0
var _last_damage_sequence: int = 0


static func create(entity_id: String, sector: SectorRuntime, combat: CombatAuthority, motor: ShipMotor,
		tuning: NpcAiTuning, authority_enabled: bool = true) -> NpcBrain:
	var brain := NpcBrain.new()
	if not brain._configure(entity_id, sector, combat, motor, tuning, authority_enabled):
		return null
	return brain


func _configure(entity_id: String, sector: SectorRuntime, combat: CombatAuthority, motor: ShipMotor,
		tuning: NpcAiTuning, authority_enabled: bool) -> bool:
	if not SectorIds.valid(entity_id) or sector == null or sector.navigation == null or combat == null or motor == null or tuning == null:
		return false
	if not tuning.valid() or not sector.entity_position(entity_id).is_finite() or not combat.has_combatant(entity_id):
		return false
	for point in tuning.patrol_waypoints:
		if not sector.navigation.accessible(point):
			return false
	if not _executor.configure(motor, sector.navigation):
		return false
	if authority_enabled and not combat.configure_repair(entity_id, tuning.repair_amount, tuning.repair_interval_ticks, CoreCombatRules.NPC_REPAIR, true):
		return false
	_entity_id = entity_id
	_sector = sector
	_combat = combat
	_motor = motor
	_tuning = tuning.duplicate(true) as NpcAiTuning
	_authority_enabled = authority_enabled
	_destination = _tuning.patrol_waypoints[0]
	_valid = true
	return true


func rebind_sector(sector: SectorRuntime, combat: CombatAuthority) -> bool:
	if not _valid or sector == null or combat == null or _motor == null:
		return false
	_executor.stop()
	_sector = sector
	_combat = combat
	_perceived_target = ""
	_last_perception_inspected = 0
	return _executor.configure(_motor, sector.navigation)


func decision_tick(simulation_tick: int) -> bool:
	if not _valid or not _authority_enabled or _sunk or simulation_tick < 0 or not _combat.is_alive(_entity_id):
		return false
	decision_count += 1
	_decision_sequence += 1
	_last_decision_tick = simulation_tick
	_memory.decay_to(simulation_tick, _tuning.threat_decay_interval_ticks, _tuning.threat_decay_amount)
	_update_perception()
	_executor.advance_if_arrived()
	var hull_ratio := _combat.hull_ratio(_entity_id)
	match _state:
		State.PATROL:
			_decide_patrol(hull_ratio)
		State.ALERT:
			_decide_alert(hull_ratio)
		State.RETREAT:
			_decide_retreat(hull_ratio)
		State.REPAIR:
			_decide_repair(hull_ratio, simulation_tick)
		State.RESUME:
			_decide_resume(hull_ratio)
	return true


func record_combat_damage(attacker_id: String, damage: float, combat_sequence: int, simulation_tick: int) -> bool:
	if not _valid or not _authority_enabled or _sunk or combat_sequence <= _last_damage_sequence:
		return false
	if not is_finite(damage) or damage <= 0.0 or simulation_tick < 0 or not _combat.hostile(_entity_id, attacker_id):
		return false
	var attacker_position := _sector.entity_position(attacker_id)
	if not attacker_position.is_finite():
		return false
	if not _memory.record(attacker_id, damage, attacker_position, simulation_tick, _tuning.max_threat, _tuning.threat_per_damage):
		return false
	_last_damage_sequence = combat_sequence
	return true


func mark_sunk() -> void:
	if not _valid:
		return
	_sunk = true
	_executor.stop()


func snapshot() -> Dictionary:
	var hull_ratio := _combat.hull_ratio(_entity_id) if _combat != null else 0.0
	return {
		"npc_stable_id": _entity_id,
		"state_id": _state,
		"intent_id": _intent,
		"target_entity_id": _target_entity_id,
		"destination": {"x": _destination.x, "y": _destination.y},
		"threat_score": _memory.value,
		"current_hull_ratio": hull_ratio,
		"decision_sequence": _decision_sequence,
		"decision_tick": _last_decision_tick,
	}


func telemetry() -> Dictionary:
	return {
		"decision_count": decision_count,
		"path_request_count": _executor.path_request_count,
		"perception_query_count": perception_query_count,
		"perception_candidate_count": perception_candidate_count,
		"last_perception_inspected": _last_perception_inspected,
	}


func persistence_state() -> Dictionary:
	return {
		"npc_stable_id": _entity_id,
		"sunk": _sunk,
		"state_id": _state,
		"intent_id": _intent,
		"target_entity_id": _target_entity_id,
		"destination": {"x": _destination.x, "y": _destination.y},
		"patrol_index": _patrol_index,
		"selected_safe_id": _selected_safe_id,
		"decision_sequence": _decision_sequence,
		"last_decision_tick": _last_decision_tick,
		"last_transition_reason": _last_transition_reason,
		"repair_started_tick": _repair_started_tick,
		"next_repair_tick": _next_repair_tick,
		"last_damage_sequence": _last_damage_sequence,
		"memory": _memory.snapshot_state(),
	}


func restore_state(value: Variant) -> bool:
	if not _valid or not value is Dictionary or value.size() != 15:
		return false
	var state: Dictionary = value
	if state.get("npc_stable_id") != _entity_id or not state.get("sunk") is bool:
		return false
	if not _state_integer(state.get("state_id")) or int(state["state_id"]) < State.PATROL or int(state["state_id"]) > State.RESUME:
		return false
	if not _state_integer(state.get("intent_id")) or int(state["intent_id"]) < Intent.PATROL_TO_WAYPOINT or int(state["intent_id"]) > Intent.RESUME_PATROL:
		return false
	var raw_target: Variant = state.get("target_entity_id")
	if not raw_target is String or (not raw_target.is_empty() and not SectorIds.valid(raw_target)):
		return false
	var raw_destination: Variant = state.get("destination")
	if not raw_destination is Dictionary or raw_destination.size() != 2:
		return false
	if typeof(raw_destination.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_destination.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var destination := Vector2(float(raw_destination["x"]), float(raw_destination["y"]))
	if not destination.is_finite():
		return false
	if not _state_integer(state.get("patrol_index")) or int(state["patrol_index"]) < 0 or int(state["patrol_index"]) >= _tuning.patrol_waypoints.size():
		return false
	var raw_safe: Variant = state.get("selected_safe_id")
	if not raw_safe is String or (not raw_safe.is_empty() and raw_safe != "fallback" and not SectorIds.valid(raw_safe)):
		return false
	for key in ["decision_sequence", "last_decision_tick", "next_repair_tick", "last_damage_sequence"]:
		if not _state_integer(state.get(key)) or int(state[key]) < 0:
			return false
	if not _state_integer(state.get("repair_started_tick")) or int(state["repair_started_tick"]) < -1:
		return false
	var raw_reason: Variant = state.get("last_transition_reason")
	if not raw_reason is String or raw_reason.length() > 128:
		return false
	var restored_memory := NpcThreatMemory.new()
	if not restored_memory.restore_state(state.get("memory")):
		return false

	_sunk = state["sunk"]
	_state = int(state["state_id"])
	_intent = int(state["intent_id"])
	_target_entity_id = raw_target
	_destination = destination
	_patrol_index = int(state["patrol_index"])
	_selected_safe_id = raw_safe
	_decision_sequence = int(state["decision_sequence"])
	_last_decision_tick = int(state["last_decision_tick"])
	_last_transition_reason = raw_reason
	_repair_started_tick = int(state["repair_started_tick"])
	_next_repair_tick = int(state["next_repair_tick"])
	_last_damage_sequence = int(state["last_damage_sequence"])
	_memory = restored_memory
	_perceived_target = ""
	_last_perception_inspected = 0
	if _sunk or _state == State.REPAIR:
		_executor.stop()
		return true
	if _intent == Intent.REPAIR:
		_executor.stop()
		return true
	return _executor.request_destination(_sector.entity_position(_entity_id), _destination)


func state_id() -> int:
	return _state


func intent_id() -> int:
	return _intent


func threat_score() -> int:
	return _memory.value


func threat_attacker_id() -> String:
	return _memory.attacker_id


func last_threat_tick() -> int:
	return _memory.last_threat_tick


func patrol_index() -> int:
	return _patrol_index


func selected_safe_point_id() -> String:
	return _selected_safe_id


func last_transition_reason() -> String:
	return _last_transition_reason


func invalidate_path() -> void:
	_executor.invalidate_path()


func _decide_patrol(hull_ratio: float) -> void:
	if _should_retreat(hull_ratio):
		_transition(State.RETREAT, "critical_hull_and_threat")
		_start_retreat()
		return
	if _memory.value >= _tuning.alert_threat_min or not _perceived_target.is_empty():
		_transition(State.ALERT, "hostile_perceived_or_remembered")
		_investigate()
		return
	_patrol()


func _decide_alert(hull_ratio: float) -> void:
	if _should_retreat(hull_ratio):
		_transition(State.RETREAT, "critical_hull_and_threat")
		_start_retreat()
		return
	if _memory.value < _tuning.alert_threat_min and _perceived_target.is_empty():
		_transition(State.PATROL, "alert_cleared")
		_patrol()
		return
	_investigate()


func _decide_retreat(_hull_ratio: float) -> void:
	var position := _sector.entity_position(_entity_id)
	if _executor.arrived(position, _tuning.arrival_radius) and _safe_for_repair(position):
		_transition(State.REPAIR, "safe_point_reached")
		_intent = Intent.REPAIR
		_target_entity_id = ""
		_destination = position
		_executor.stop()
		_repair_started_tick = _last_decision_tick
		_next_repair_tick = _last_decision_tick + _tuning.repair_interval_ticks
		return
	if not _executor.has_goal():
		_start_retreat()


func _decide_repair(hull_ratio: float, simulation_tick: int) -> void:
	if _memory.last_threat_tick > _repair_started_tick and _memory.value >= _tuning.repair_interrupt_threat:
		if hull_ratio < _tuning.retreat_exit_hull_ratio:
			_transition(State.RETREAT, "repair_interrupted_by_threat")
			_start_retreat()
		else:
			_transition(State.ALERT, "repair_interrupted_by_threat")
			_investigate()
		return
	if simulation_tick >= _next_repair_tick:
		_combat._ai_repair(_entity_id, simulation_tick)
		_next_repair_tick = simulation_tick + _tuning.repair_interval_ticks
	hull_ratio = _combat.hull_ratio(_entity_id)
	_intent = Intent.REPAIR
	_target_entity_id = ""
	if hull_ratio >= _tuning.resume_hull_ratio and _memory.value <= _tuning.resume_threat_max:
		_transition(State.RESUME, "repair_complete_and_threat_decayed")
		_resume_to_patrol()


func _decide_resume(hull_ratio: float) -> void:
	if _should_retreat(hull_ratio):
		_transition(State.RETREAT, "renewed_critical_threat")
		_start_retreat()
		return
	if _memory.value >= _tuning.alert_threat_min or not _perceived_target.is_empty():
		_transition(State.ALERT, "renewed_alert")
		_investigate()
		return
	_transition(State.PATROL, "patrol_route_resumed")
	_patrol()


func _patrol() -> void:
	var position := _sector.entity_position(_entity_id)
	var destination := _tuning.patrol_waypoints[_patrol_index]
	if _executor.arrived(position, _tuning.arrival_radius):
		_patrol_index = (_patrol_index + 1) % _tuning.patrol_waypoints.size()
		destination = _tuning.patrol_waypoints[_patrol_index]
	_intent = Intent.PATROL_TO_WAYPOINT
	_target_entity_id = ""
	_destination = destination
	_executor.request_destination(position, destination)


func _investigate() -> void:
	var position := _sector.entity_position(_entity_id)
	var target := _perceived_target if not _perceived_target.is_empty() else _memory.attacker_id
	var target_position := _sector.entity_position(target)
	if not target_position.is_finite() and target == _memory.attacker_id:
		target_position = _memory.last_known_position
	_intent = Intent.INVESTIGATE_THREAT
	_target_entity_id = target
	if target_position.is_finite() and _sector.navigation.accessible(target_position):
		_destination = target_position
		_executor.request_destination(position, target_position)


func _start_retreat() -> void:
	var position := _sector.entity_position(_entity_id)
	var attacker_position := _sector.entity_position(_memory.attacker_id)
	if not attacker_position.is_finite():
		attacker_position = _memory.last_known_position
	var rejected_mask := 0
	for attempt in _tuning.safe_points.size():
		var best_index := _best_safe_point(position, attacker_position, rejected_mask)
		if best_index < 0:
			break
		var point := _tuning.safe_points[best_index]
		if _executor.request_destination(position, point):
			_selected_safe_id = _tuning.safe_point_ids[best_index]
			_destination = point
			_intent = Intent.RETREAT_TO_SAFE_POINT
			_target_entity_id = _memory.attacker_id
			return
		rejected_mask |= 1 << best_index
	var fallback := _fallback_point(position, attacker_position)
	_selected_safe_id = "fallback"
	_destination = fallback
	_intent = Intent.RETREAT_TO_SAFE_POINT
	_target_entity_id = _memory.attacker_id
	if not _executor.request_destination(position, fallback):
		_executor.stop()
		_destination = position


func _best_safe_point(position: Vector2, attacker_position: Vector2, rejected_mask: int) -> int:
	var best_index := -1
	var best_score := -INF
	for i in _tuning.safe_points.size():
		if (rejected_mask & (1 << i)) != 0:
			continue
		var point := _tuning.safe_points[i]
		if not _sector.navigation.accessible(point):
			continue
		var score := attacker_position.distance_squared_to(point) - position.distance_squared_to(point) * 0.25
		if score > best_score or (is_equal_approx(score, best_score) and (best_index < 0 or _tuning.safe_point_ids[i] < _tuning.safe_point_ids[best_index])):
			best_score = score
			best_index = i
	return best_index


func _fallback_point(position: Vector2, attacker_position: Vector2) -> Vector2:
	var away := position - attacker_position
	if not away.is_finite() or away.length_squared() <= 0.000001:
		away = Vector2.LEFT
	var candidate := position + away.normalized() * _tuning.retreat_fallback_distance
	candidate.x = clampf(candidate.x, _sector.bounds.position.x + _tuning.arrival_radius, _sector.bounds.end.x - _tuning.arrival_radius)
	candidate.y = clampf(candidate.y, _sector.bounds.position.y + _tuning.arrival_radius, _sector.bounds.end.y - _tuning.arrival_radius)
	if _sector.navigation.accessible(candidate):
		return candidate
	for point in _tuning.patrol_waypoints:
		if _sector.navigation.accessible(point):
			return point
	return position


func _resume_to_patrol() -> void:
	var position := _sector.entity_position(_entity_id)
	var best_index := 0
	var best_distance := INF
	for i in _tuning.patrol_waypoints.size():
		var distance := position.distance_squared_to(_tuning.patrol_waypoints[i])
		if distance < best_distance or (distance == best_distance and _tuning.patrol_waypoint_ids[i] < _tuning.patrol_waypoint_ids[best_index]):
			best_distance = distance
			best_index = i
	_patrol_index = best_index
	_destination = _tuning.patrol_waypoints[best_index]
	_intent = Intent.RESUME_PATROL
	_target_entity_id = ""
	_executor.request_destination(position, _destination)


func _update_perception() -> void:
	perception_query_count += 1
	_perceived_target = ""
	var position := _sector.entity_position(_entity_id)
	_last_perception_inspected = _sector.spatial.query_radius(position, _tuning.perception_radius, _perception_candidates)
	perception_candidate_count += _last_perception_inspected
	var best_distance := INF
	for candidate in _perception_candidates:
		if candidate == _entity_id or not _combat.hostile(_entity_id, candidate) or not _combat.is_alive(candidate):
			continue
		var target_position := _sector.entity_position(candidate)
		var distance := position.distance_squared_to(target_position)
		if distance < best_distance or (distance == best_distance and candidate < _perceived_target):
			best_distance = distance
			_perceived_target = candidate


func _safe_for_repair(position: Vector2) -> bool:
	if _memory.value > _tuning.repair_entry_threat_max:
		return false
	var attacker_position := _sector.entity_position(_memory.attacker_id)
	return not attacker_position.is_finite() or position.distance_to(attacker_position) >= _tuning.safe_distance


func _should_retreat(hull_ratio: float) -> bool:
	return is_finite(hull_ratio) and hull_ratio <= _tuning.retreat_enter_hull_ratio and _memory.value >= _tuning.retreat_threat_min


func _transition(next_state: int, reason: String) -> void:
	if _state == next_state:
		return
	_state = next_state
	_last_transition_reason = reason


static func _state_integer(value_in: Variant) -> bool:
	if typeof(value_in) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value_in)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
