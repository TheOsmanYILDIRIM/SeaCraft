class_name NpcBrain
extends RefCounted

const DEFAULT_ROLE := preload("res://src/data/ai/roles/trader.tres")

enum State {
	PATROL,
	ALERT,
	RETREAT,
	REPAIR,
	RESUME,
}

enum Intent {
	PATROL_TO_WAYPOINT,
	INVESTIGATE_THREAT,
	RETREAT_TO_SAFE_POINT,
	REPAIR,
	RESUME_PATROL,
	PROTECT_ALLY,
}

var decision_count: int = 0
var perception_query_count: int = 0
var perception_candidate_count: int = 0
var utility_evaluation_count: int = 0
var tactical_evaluation_count: int = 0
var tactical_fire_transactions: int = 0
var tactical_boarding_attempts: int = 0
var tactical_support_intents: int = 0
var tactical_ammo_selects: int = 0
var max_tactical_targets_evaluated: int = 0
var max_tactical_ammo_evaluated: int = 0
var max_tactical_escape_evaluated: int = 0
var max_tactical_line_of_fire_inspected: int = 0

var _valid := false
var _authority_enabled := true
var _sunk := false
var _entity_id := ""
var _sector: SectorRuntime
var _combat: CombatAuthority
var _motor: ShipMotor
var _tuning: NpcAiTuning
var _role: NpcRoleProfile
var _executor := NpcIntentExecutor.new()
var _perception := PerceptionService.new()
var _memory := MemoryBlackboard.new()
var _bt := AiBtRunner.new()

var _state: int = State.PATROL
var _intent: int = Intent.PATROL_TO_WAYPOINT
var _patrol_index := 0
var _selected_safe_id := ""
var _target_entity_id := ""
var _destination := Vector2.ZERO
var _decision_sequence := 0
var _last_decision_tick := 0
var _last_transition_reason := "spawned"
var _last_transition_trace := {
	"accepted": true,
	"changed": false,
	"previous_state": State.PATROL,
	"next_state": State.PATROL,
	"reason": "spawned",
	"tick": 0,
}
var _repair_started_tick := -1
var _next_repair_tick := 0
var _last_damage_sequence := 0
var _last_sense_query_tick := -1
var _sense_snapshot: Dictionary = {}
var _last_utility: Dictionary = {}
var _last_bt_status := -1
var _last_tactical: Dictionary = {}
var _fleet_command: Dictionary = {}
var _fleet_command_sequence := -1
var _tactical_state := {
	"range_band": "",
	"desired_side": 0,
	"next_support_tick": 0,
	"last_intent": TacticalDecision.NONE,
	"last_target_id": "",
}


static func create(entity_id: String, sector: SectorRuntime, combat: CombatAuthority, motor: ShipMotor,
		tuning: NpcAiTuning, authority_enabled: bool = true, role_profile: NpcRoleProfile = null) -> NpcBrain:
	var result := NpcBrain.new()
	if not result._configure(entity_id, sector, combat, motor, tuning, authority_enabled, role_profile):
		return null
	return result


func _configure(entity_id: String, sector: SectorRuntime, combat: CombatAuthority, motor: ShipMotor,
		tuning: NpcAiTuning, authority_enabled: bool, role_profile: NpcRoleProfile) -> bool:
	if not SectorIds.valid(entity_id) or sector == null or combat == null or motor == null or tuning == null or not tuning.valid():
		return false
	if not combat.has_combatant(entity_id) or not sector.entity_position(entity_id).is_finite():
		return false
	for point in tuning.patrol_waypoints:
		if not sector.navigation.accessible(point):
			return false
	var selected_role := role_profile if role_profile != null else DEFAULT_ROLE as NpcRoleProfile
	if selected_role == null or not selected_role.valid():
		return false
	if not _executor.configure(motor, sector.navigation):
		return false
	if not _memory.configure(tuning.memory_max_entries, tuning.memory_expiry_ticks):
		return false
	if not _bt.configure(motor, Callable(self, "_execute_bt_action")):
		return false
	if authority_enabled and not combat.configure_repair(entity_id, tuning.repair_amount, tuning.repair_interval_ticks, CoreCombatRules.NPC_REPAIR, true):
		return false
	_entity_id = entity_id
	_sector = sector
	_combat = combat
	_motor = motor
	_tuning = tuning.duplicate(true) as NpcAiTuning
	_role = selected_role.duplicate(true) as NpcRoleProfile
	_authority_enabled = authority_enabled
	_destination = _tuning.patrol_waypoints[0]
	_valid = true
	return true


func rebind_sector(sector: SectorRuntime, combat: CombatAuthority) -> bool:
	if not _valid or sector == null or combat == null or _motor == null:
		return false
	_bt.interrupt()
	_executor.stop()
	_sector = sector
	_combat = combat
	_fleet_command.clear()
	_fleet_command_sequence = -1
	_sense_snapshot.clear()
	_last_sense_query_tick = -1
	return _executor.configure(_motor, sector.navigation)


func decision_tick(simulation_tick: int) -> bool:
	if not _valid or not _authority_enabled or _sunk or simulation_tick < 0 or not _combat.is_alive(_entity_id):
		return false
	decision_count += 1
	_decision_sequence += 1
	_last_decision_tick = simulation_tick
	if not _capture_sense(simulation_tick):
		return false
	_sanitize_hostility_memory()
	if not _memory.advance(_sense_snapshot, simulation_tick, _tuning.threat_decay_interval_ticks, _tuning.threat_decay_amount):
		return false
	_executor.advance_if_arrived()
	var hull_ratio := _combat.hull_ratio(_entity_id)
	var role_data := _role.data_snapshot()
	var context := {
		"max_threat": _tuning.max_threat,
		"perception_radius": _tuning.perception_radius,
		"protected_ally_threatened": false,
		"allow_repair": _state == State.REPAIR,
	}
	var decision := UtilityDecision.evaluate(_sense_snapshot, _memory.snapshot_state(), role_data, context, _decision_sequence)
	if decision.is_empty():
		return false
	utility_evaluation_count += 1
	_last_utility = decision.duplicate(true)
	var tactical := _evaluate_tactical(decision, simulation_tick)
	var tactical_forced_retreat := false
	if not tactical.is_empty() and str(tactical.get("tactical_intent", "")) == TacticalDecision.RETREAT and _state == State.ALERT:
		var tactical_target := str(tactical.get("target_id", _decision_target(decision)))
		if _transition(State.RETREAT, "tactical_disadvantage"):
			_start_retreat(tactical_target)
			_apply_tactical_maneuver(tactical)
			tactical_forced_retreat = true
	if not tactical_forced_retreat:
		match _state:
			State.PATROL:
				_decide_patrol(hull_ratio, decision)
			State.ALERT:
				_decide_alert(hull_ratio, decision)
			State.RETREAT:
				_decide_retreat(hull_ratio)
			State.REPAIR:
				_decide_repair(hull_ratio)
			State.RESUME:
				_decide_resume(hull_ratio, decision)
	if not tactical.is_empty() and _state in [State.ALERT, State.RETREAT]:
		_apply_tactical_maneuver(tactical)
	_apply_fleet_command_if_safe()
	var actual_hysteresis: Dictionary = decision["hysteresis_state"].duplicate(true)
	if int(decision["selected_intent_id"]) != _intent or str(decision["selected_target_id"]) != _target_entity_id:
		actual_hysteresis = {
			"intent_id": _intent,
			"target_id": _target_entity_id if _memory.snapshot_state()["entries"].any(func(entry: Dictionary) -> bool: return str(entry["stable_id"]) == _target_entity_id) else "",
			"score": float(decision["score"]),
			"hold_until_tick": simulation_tick + _role.minimum_decision_hold_ticks,
		}
	_memory.commit_decision(_intent, str(actual_hysteresis["target_id"]), float(decision["score"]), simulation_tick, actual_hysteresis)
	_last_bt_status = _bt.tick_intent(_intent, simulation_tick, _tuning.bt_timeout_ticks)
	_execute_tactical_authority(tactical)
	return true


func set_fleet_command(command: Dictionary) -> bool:
	if not _valid or not _authority_enabled or _sunk or not FleetCommand.valid(command):
		return false
	if command["member_id"] != _entity_id or int(command["sequence"]) <= _fleet_command_sequence:
		return false
	_fleet_command = command.duplicate(true)
	_fleet_command_sequence = int(command["sequence"])
	return true


func clear_fleet_command() -> void:
	_fleet_command.clear()


func support_request() -> Dictionary:
	if str(_last_tactical.get("tactical_intent", "")) != TacticalDecision.SUPPORT:
		return {}
	return {
		"support_id": "support.%s.s%d" % [_entity_id, _decision_sequence],
		"requester_id": _entity_id,
		"target_id": str(_last_tactical.get("target_id", "")),
		"decision_sequence": _decision_sequence,
	}


func record_combat_damage(attacker_id: String, damage: float, combat_sequence: int, simulation_tick: int) -> bool:
	if not _valid or not _authority_enabled or _sunk or combat_sequence <= _last_damage_sequence:
		return false
	if not is_finite(damage) or damage <= 0.0 or simulation_tick < 0 or not _combat.hostile(_entity_id, attacker_id):
		return false
	var attacker_position := _sector.entity_position(attacker_id)
	if not attacker_position.is_finite():
		return false
	if not _memory.record_damage(attacker_id, damage, attacker_position, simulation_tick, _tuning.max_threat, _tuning.threat_per_damage):
		return false
	_last_damage_sequence = combat_sequence
	return true


func mark_sunk() -> void:
	if not _valid:
		return
	_sunk = true
	_fleet_command.clear()
	_bt.interrupt()
	_executor.stop()


func state_id() -> int:
	return _state


func intent_id() -> int:
	return _intent


func patrol_index() -> int:
	return _patrol_index


func selected_safe_point_id() -> String:
	return _selected_safe_id


func threat_score() -> int:
	return _memory.primary_threat()


func threat_attacker_id() -> String:
	return _memory.primary_target_id()


func last_threat_tick() -> int:
	return _memory.last_threat_tick()


func role_profile_id() -> String:
	return _role.stable_id if _role != null else ""


func last_transition_reason() -> String:
	return _last_transition_reason


func invalidate_path() -> void:
	_executor.invalidate_path()


func snapshot() -> Dictionary:
	var hull_ratio := _combat.hull_ratio(_entity_id) if _combat != null else 0.0
	return {
		"npc_stable_id": _entity_id,
		"state_id": _state,
		"intent_id": _intent,
		"role_profile_id": role_profile_id(),
		"target_entity_id": _target_entity_id,
		"destination": {"x": _destination.x, "y": _destination.y},
		"threat_score": _memory.primary_threat(),
		"current_hull_ratio": hull_ratio,
		"decision_sequence": _decision_sequence,
		"decision_tick": _last_decision_tick,
		"bt_status": _last_bt_status,
		"tactical_intent": str(_last_tactical.get("tactical_intent", TacticalDecision.NONE)),
		"tactical_maneuver": str(_last_tactical.get("maneuver_id", "")),
		"tactical_ammo_id": str(_last_tactical.get("selected_ammo_id", "")),
		"tactical_boarding": str(_last_tactical.get("tactical_intent", "")) == TacticalDecision.BOARD,
		"tactical_support": str(_last_tactical.get("tactical_intent", "")) == TacticalDecision.SUPPORT,
		"fleet_command_sequence": _fleet_command_sequence,
		"fleet_command_kind": str(_fleet_command.get("kind", "")),
	}


func telemetry() -> Dictionary:
	var bt_data := _bt.telemetry()
	return {
		"decision_count": decision_count,
		"path_request_count": _executor.path_request_count,
		"sense_query_count": _perception.query_count,
		"perception_query_count": _perception.query_count,
		"perception_candidate_count": _perception.last_candidate_count,
		"last_perception_inspected": _perception.last_inspected_count,
		"utility_evaluation_count": utility_evaluation_count,
		"selected_intent": _intent,
		"selected_target": _target_entity_id,
		"state": _state,
		"bt_status": _last_bt_status,
		"bt_tree_tick_count": int(bt_data["tree_tick_count"]),
		"bt_failure_count": int(bt_data["failure_count"]),
		"bt_timeout_count": int(bt_data["timeout_count"]),
		"tactical_evaluation_count": tactical_evaluation_count,
		"max_tactical_targets_evaluated": max_tactical_targets_evaluated,
		"max_tactical_ammo_evaluated": max_tactical_ammo_evaluated,
		"max_tactical_escape_evaluated": max_tactical_escape_evaluated,
		"max_tactical_line_of_fire_inspected": max_tactical_line_of_fire_inspected,
		"tactical_fire_transactions": tactical_fire_transactions,
		"tactical_boarding_attempts": tactical_boarding_attempts,
		"tactical_support_intents": tactical_support_intents,
		"tactical_ammo_selects": tactical_ammo_selects,
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
		"last_transition_trace": _last_transition_trace.duplicate(true),
		"repair_started_tick": _repair_started_tick,
		"next_repair_tick": _next_repair_tick,
		"last_damage_sequence": _last_damage_sequence,
		"role_profile_id": role_profile_id(),
		"memory": _memory.snapshot_state(),
		"bt": _bt.persistence_state(),
		"last_sense_query_tick": _last_sense_query_tick,
		"tactical_state": _tactical_state.duplicate(true),
	}


func restore_state(value: Variant) -> bool:
	if not _valid or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() not in [15, 19, 20]:
		return false
	if state.get("npc_stable_id") != _entity_id or not state.get("sunk") is bool:
		return false
	if not _state_integer(state.get("state_id")) or int(state["state_id"]) < State.PATROL or int(state["state_id"]) > State.RESUME:
		return false
	if not _state_integer(state.get("intent_id")) or int(state["intent_id"]) < Intent.PATROL_TO_WAYPOINT or int(state["intent_id"]) > Intent.PROTECT_ALLY:
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
	if not state.get("last_transition_reason") is String or str(state["last_transition_reason"]).length() > 128:
		return false
	var memory_probe := MemoryBlackboard.new()
	if not memory_probe.configure(_tuning.memory_max_entries, _tuning.memory_expiry_ticks) or not memory_probe.restore_state(state.get("memory")):
		return false
	var role_id := str(state.get("role_profile_id", role_profile_id()))
	if role_id != role_profile_id():
		return false
	var transition_source: Variant = state.get("last_transition_trace", {
		"accepted": true,
		"changed": false,
		"previous_state": int(state["state_id"]),
		"next_state": int(state["state_id"]),
		"reason": str(state["last_transition_reason"]),
		"tick": int(state["last_decision_tick"]),
	})
	if not transition_source is Dictionary or not DtoContract.is_primitive_safe(transition_source):
		return false
	var transition_raw: Dictionary = transition_source
	if not transition_raw.get("accepted") is bool or not transition_raw.get("changed") is bool:
		return false
	for key in ["previous_state", "next_state", "tick"]:
		if not _state_integer(transition_raw.get(key)):
			return false
	if not transition_raw.get("reason") is String:
		return false
	var transition_trace := {
		"accepted": bool(transition_raw["accepted"]),
		"changed": bool(transition_raw["changed"]),
		"previous_state": int(transition_raw["previous_state"]),
		"next_state": int(transition_raw["next_state"]),
		"reason": str(transition_raw["reason"]),
		"tick": int(transition_raw["tick"]),
	}
	var last_sense_tick := int(state.get("last_sense_query_tick", -1))
	if last_sense_tick < -1:
		return false
	var tactical_source: Variant = state.get("tactical_state", {
		"range_band": "",
		"desired_side": 0,
		"next_support_tick": 0,
		"last_intent": TacticalDecision.NONE,
		"last_target_id": "",
	})
	if not TacticalDecision.valid_persistent_state(tactical_source):
		return false
	var bt_state: Dictionary = state.get("bt", {"intent_id": -1, "action_kind": "", "started_tick": -1, "last_status": -1})
	if not _bt.restore_state(bt_state):
		return false
	_sunk = bool(state["sunk"])
	_state = int(state["state_id"])
	_intent = int(state["intent_id"])
	_target_entity_id = raw_target
	_destination = destination
	_patrol_index = int(state["patrol_index"])
	_selected_safe_id = raw_safe
	_decision_sequence = int(state["decision_sequence"])
	_last_decision_tick = int(state["last_decision_tick"])
	_last_transition_reason = str(state["last_transition_reason"])
	_last_transition_trace = transition_trace.duplicate(true)
	_repair_started_tick = int(state["repair_started_tick"])
	_next_repair_tick = int(state["next_repair_tick"])
	_last_damage_sequence = int(state["last_damage_sequence"])
	_last_sense_query_tick = last_sense_tick
	var tactical_raw := tactical_source as Dictionary
	_tactical_state = {
		"range_band": str(tactical_raw.get("range_band", "")),
		"desired_side": int(tactical_raw.get("desired_side", 0)),
		"next_support_tick": int(tactical_raw.get("next_support_tick", 0)),
		"last_intent": str(tactical_raw.get("last_intent", TacticalDecision.NONE)),
		"last_target_id": str(tactical_raw.get("last_target_id", "")),
	}
	_last_tactical.clear()
	_memory = memory_probe
	_sense_snapshot.clear()
	if _sunk:
		_bt.interrupt()
		_executor.stop()
	return true


func _evaluate_tactical(high_level_decision: Dictionary, simulation_tick: int) -> Dictionary:
	var preferred_target := _decision_target(high_level_decision)
	var previous := _tactical_state.duplicate(true)
	if not preferred_target.is_empty():
		previous["last_target_id"] = preferred_target
	var context := TacticalContext.capture(
		_entity_id,
		simulation_tick,
		_sector,
		_combat,
		_motor.current_heading(),
		_motor.velocity.length(),
		_state,
		_intent,
		_sense_snapshot,
		_memory.snapshot_state(),
		_tuning,
		_role,
		previous
	)
	if context.is_empty():
		_last_tactical.clear()
		return {}
	var tactical := TacticalDecision.evaluate(context, _decision_sequence)
	if tactical.is_empty():
		_last_tactical.clear()
		return {}
	tactical_evaluation_count += 1
	max_tactical_targets_evaluated = maxi(max_tactical_targets_evaluated, (context.get("targets", []) as Array).size())
	var actor: Dictionary = context.get("actor", {})
	max_tactical_ammo_evaluated = maxi(max_tactical_ammo_evaluated, (actor.get("ammo_candidates", []) as Array).size())
	max_tactical_escape_evaluated = maxi(max_tactical_escape_evaluated, (context.get("escape_candidates", []) as Array).size())
	for raw in context.get("targets", []):
		if raw is Dictionary:
			max_tactical_line_of_fire_inspected = maxi(max_tactical_line_of_fire_inspected, int(raw.get("line_of_fire_inspected", 0)))
	_last_tactical = tactical.duplicate(true)
	_tactical_state = TacticalDecision.persistent_state(tactical, _tactical_state, _tuning.support_cooldown_ticks)
	return tactical


func _apply_tactical_maneuver(tactical: Dictionary) -> void:
	var destination: Variant = tactical.get("destination")
	if not destination is Dictionary:
		return
	var point := Vector2(float(destination.get("x", INF)), float(destination.get("y", INF)))
	if not point.is_finite():
		return
	var maneuver := str(tactical.get("maneuver_id", ""))
	if maneuver == TacticalDecision.RETREAT_MANEUVER:
		_selected_safe_id = str((tactical.get("factors", {}) as Dictionary).get("escape_id", _selected_safe_id))
	if maneuver in [TacticalDecision.CLOSE_RANGE, TacticalDecision.OPEN_RANGE, TacticalDecision.ALIGN_BROADSIDE, TacticalDecision.RETREAT_MANEUVER]:
		if _sector.navigation.accessible(point):
			_destination = point
	elif maneuver in [TacticalDecision.HOLD_RANGE, TacticalDecision.REPAIR_WINDOW]:
		_destination = _sector.entity_position(_entity_id)


func _execute_tactical_authority(tactical: Dictionary) -> void:
	if tactical.is_empty() or not _authority_enabled or _sunk:
		return
	var target_id := str(tactical.get("target_id", ""))
	var intent := str(tactical.get("tactical_intent", TacticalDecision.NONE))
	if intent == TacticalDecision.SUPPORT:
		tactical_support_intents += 1
		return
	if target_id.is_empty() or not _combat.has_combatant(target_id):
		return
	if intent == TacticalDecision.ACQUIRE_TARGET:
		_combat.select(_entity_id, target_id)
		return
	var selected_ammo := str(tactical.get("selected_ammo_id", ""))
	if bool(tactical.get("ammo_switch_required", false)) and not selected_ammo.is_empty():
		var ammo_result := _combat.transact(_entity_id, CombatAuthority.intent(CombatAuthority.AMMO_SELECT, selected_ammo))
		if bool(ammo_result.get("accepted", false)):
			tactical_ammo_selects += 1
		return
	if intent == TacticalDecision.BOARD:
		tactical_boarding_attempts += 1
		_combat.transact(_entity_id, CombatAuthority.intent(CombatAuthority.BOARD, target_id))
		return
	if intent == TacticalDecision.FIRE and bool(tactical.get("fire_allowed", false)):
		var fire_result := _combat.fire(_entity_id, _motor.current_heading(), CombatAuthority.fire_intent(target_id))
		if bool(fire_result.get("accepted", false)):
			tactical_fire_transactions += 1


func _capture_sense(simulation_tick: int) -> bool:
	if _sense_snapshot.is_empty() or _last_sense_query_tick < 0 or simulation_tick - _last_sense_query_tick >= _tuning.perception_query_cadence_ticks:
		var snapshot := _perception.capture(
			_entity_id,
			simulation_tick,
			_sector,
			_combat,
			_tuning.perception_radius,
			_tuning.perception_candidate_cap,
			_role
		)
		if snapshot.is_empty():
			return false
		_sense_snapshot = snapshot
		_last_sense_query_tick = simulation_tick
	else:
		_sense_snapshot = _sense_snapshot.duplicate(true)
		_sense_snapshot["simulation_tick"] = simulation_tick
		_sense_snapshot["observer_hull_ratio"] = _combat.hull_ratio(_entity_id)
	perception_query_count = _perception.query_count
	perception_candidate_count = _perception.last_candidate_count
	return true


func _sanitize_hostility_memory() -> void:
	var filtered: Array = []
	for raw in _sense_snapshot.get("candidates", []):
		if not raw is Dictionary:
			continue
		var id := str(raw.get("stable_id", ""))
		if SectorIds.valid(id) and _combat.hostile(_entity_id, id) and not _sector.entity_in_safe_zone(id):
			filtered.append(raw)
		else:
			_memory.invalidate_target(id)
	_sense_snapshot["candidates"] = filtered
	_sense_snapshot["candidate_count"] = filtered.size()
	for raw in _memory.snapshot_state().get("entries", []):
		if not raw is Dictionary:
			continue
		var id := str(raw.get("stable_id", ""))
		if SectorIds.valid(id) and (not _combat.hostile(_entity_id, id) or _sector.entity_in_safe_zone(id)):
			_memory.invalidate_target(id)
	var locked := _combat.locked_target(_entity_id)
	if not locked.is_empty() and (not _combat.hostile(_entity_id, locked) or _sector.entity_in_safe_zone(locked)):
		_combat.clear_target(_entity_id)


func _apply_fleet_command_if_safe() -> void:
	if _fleet_command.is_empty() or _state not in [State.PATROL, State.RESUME] or _has_visible_hostile():
		return
	if _combat.hull_ratio(_entity_id) <= _tuning.retreat_enter_hull_ratio:
		return
	var kind := str(_fleet_command.get("kind", ""))
	if kind not in [FleetCommand.FOLLOW_LEADER, FleetCommand.OCCUPY_SLOT, FleetCommand.REGROUP, FleetCommand.DOCK, FleetCommand.ROUTE_JOB, FleetCommand.PATROL, FleetCommand.TRADE_ROUTE, FleetCommand.SALVAGE_ROUTE]:
		return
	var destination: Variant = _fleet_command.get("destination", {})
	if not destination is Dictionary or destination.size() != 2:
		return
	var point := Vector2(float(destination.get("x", INF)), float(destination.get("y", INF)))
	if not point.is_finite() or not _sector.navigation.accessible(point):
		return
	_destination = point
	_intent = Intent.PATROL_TO_WAYPOINT
	_target_entity_id = ""


func _decide_patrol(hull_ratio: float, decision: Dictionary) -> void:
	var target := _decision_target(decision)
	if _should_retreat(hull_ratio) or (int(decision["selected_intent_id"]) == Intent.RETREAT_TO_SAFE_POINT and not target.is_empty()):
		_transition(State.RETREAT, "critical_hull_with_threat" if _should_retreat(hull_ratio) else "role_avoidance")
		_start_retreat(target)
		return
	if _memory.primary_threat() >= _tuning.alert_threat_min or _has_visible_hostile():
		_transition(State.ALERT, "threat_detected")
		_investigate(target, int(decision["selected_intent_id"]))
		return
	_patrol()


func _decide_alert(hull_ratio: float, decision: Dictionary) -> void:
	var target := _decision_target(decision)
	if _should_retreat(hull_ratio) or (int(decision["selected_intent_id"]) == Intent.RETREAT_TO_SAFE_POINT and not target.is_empty()):
		_transition(State.RETREAT, "retreat_threshold_crossed" if _should_retreat(hull_ratio) else "role_avoidance")
		_start_retreat(target)
		return
	if _memory.primary_threat() < _tuning.alert_threat_min and not _has_visible_hostile():
		_transition(State.PATROL, "threat_cleared")
		_patrol()
		return
	_investigate(target, int(decision["selected_intent_id"]))


func _decide_retreat(_hull_ratio: float) -> void:
	var position := _sector.entity_position(_entity_id)
	if _executor.arrived(position, _tuning.arrival_radius) and _safe_for_repair(position):
		_transition(State.REPAIR, "safe_point_reached")
		_intent = Intent.REPAIR
		_target_entity_id = ""
		_repair_started_tick = _last_decision_tick
		_next_repair_tick = _last_decision_tick + _tuning.repair_interval_ticks
		return
	if not _destination.is_finite() or _selected_safe_id.is_empty():
		_start_retreat(_memory.primary_target_id())
	_intent = Intent.RETREAT_TO_SAFE_POINT


func _decide_repair(hull_ratio: float) -> void:
	if _memory.last_threat_tick() > _repair_started_tick and _memory.primary_threat() >= _tuning.repair_interrupt_threat:
		if hull_ratio < _tuning.retreat_exit_hull_ratio:
			_transition(State.RETREAT, "repair_interrupted_by_threat")
			_start_retreat(_memory.primary_target_id())
		else:
			_transition(State.ALERT, "repair_interrupted_by_threat")
			_investigate(_memory.primary_target_id(), Intent.INVESTIGATE_THREAT)
		return
	_intent = Intent.REPAIR
	_target_entity_id = ""
	if hull_ratio >= _tuning.resume_hull_ratio and _memory.primary_threat() <= _tuning.resume_threat_max:
		_transition(State.RESUME, "repair_complete_and_threat_decayed")
		_resume_to_patrol()


func _decide_resume(hull_ratio: float, decision: Dictionary) -> void:
	var target := _decision_target(decision)
	if _should_retreat(hull_ratio):
		_transition(State.RETREAT, "renewed_critical_threat")
		_start_retreat(target)
		return
	if _memory.primary_threat() >= _tuning.alert_threat_min or _has_visible_hostile():
		_transition(State.ALERT, "renewed_alert")
		_investigate(target, int(decision["selected_intent_id"]))
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


func _investigate(target: String, selected_intent: int) -> void:
	var resolved := target if not target.is_empty() else _memory.primary_target_id()
	var target_position := _sector.entity_position(resolved)
	if not target_position.is_finite():
		target_position = _memory.last_known_position(resolved)
	_intent = Intent.PROTECT_ALLY if selected_intent == Intent.PROTECT_ALLY else Intent.INVESTIGATE_THREAT
	_target_entity_id = resolved
	if target_position.is_finite() and _sector.navigation.accessible(target_position):
		_destination = target_position


func _start_retreat(target: String) -> void:
	var position := _sector.entity_position(_entity_id)
	var threat_position := _sector.entity_position(target)
	if not threat_position.is_finite():
		threat_position = _memory.last_known_position(target)
	var best := _best_safe_point(position, threat_position)
	_selected_safe_id = str(best["id"])
	_destination = best["point"]
	_intent = Intent.RETREAT_TO_SAFE_POINT
	_target_entity_id = target


func _best_safe_point(position: Vector2, threat_position: Vector2) -> Dictionary:
	var best_id := ""
	var best_point := Vector2.INF
	var best_score := -INF
	for index in _tuning.safe_points.size():
		var point := _tuning.safe_points[index]
		if not _sector.navigation.accessible(point):
			continue
		var score := point.distance_to(threat_position) if threat_position.is_finite() else position.distance_to(point)
		var id := _tuning.safe_point_ids[index]
		if score > best_score or (is_equal_approx(score, best_score) and (best_id.is_empty() or id < best_id)):
			best_score = score
			best_id = id
			best_point = point
	if not best_point.is_finite():
		best_id = "fallback"
		best_point = _fallback_point(position, threat_position)
	return {"id": best_id, "point": best_point}


func _fallback_point(position: Vector2, threat_position: Vector2) -> Vector2:
	var direction := Vector2.LEFT
	if threat_position.is_finite() and not position.is_equal_approx(threat_position):
		direction = (position - threat_position).normalized()
	var candidate := position + direction * _tuning.retreat_fallback_distance
	candidate.x = clampf(candidate.x, _sector.bounds.position.x + 24.0, _sector.bounds.end.x - 24.0)
	candidate.y = clampf(candidate.y, _sector.bounds.position.y + 24.0, _sector.bounds.end.y - 24.0)
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
	for index in _tuning.patrol_waypoints.size():
		var distance := position.distance_squared_to(_tuning.patrol_waypoints[index])
		if distance < best_distance or (is_equal_approx(distance, best_distance) and _tuning.patrol_waypoint_ids[index] < _tuning.patrol_waypoint_ids[best_index]):
			best_distance = distance
			best_index = index
	_patrol_index = best_index
	_intent = Intent.RESUME_PATROL
	_target_entity_id = ""
	_selected_safe_id = ""
	_destination = _tuning.patrol_waypoints[_patrol_index]


func _safe_for_repair(position: Vector2) -> bool:
	if _memory.primary_threat() > _tuning.repair_entry_threat_max:
		return false
	var attacker_position := _sector.entity_position(_memory.primary_target_id())
	if not attacker_position.is_finite():
		attacker_position = _memory.last_known_position()
	return not attacker_position.is_finite() or position.distance_to(attacker_position) >= _tuning.safe_distance


func _should_retreat(hull_ratio: float) -> bool:
	return hull_ratio <= _tuning.retreat_enter_hull_ratio and _memory.primary_threat() >= _tuning.retreat_threat_min


func _has_visible_hostile() -> bool:
	return int(_sense_snapshot.get("candidate_count", 0)) > 0


func _decision_target(decision: Dictionary) -> String:
	var target := str(decision.get("selected_target_id", ""))
	return target if not target.is_empty() else _memory.primary_target_id()


func _execute_bt_action(action_kind: String, simulation_tick: int) -> int:
	if not _authority_enabled or _sunk:
		return BeehaveNode.FAILURE
	if action_kind.begins_with("interrupt:"):
		var interrupted_kind := action_kind.trim_prefix("interrupt:")
		if interrupted_kind in [AiBtRunner.ACTION_DESTINATION, AiBtRunner.ACTION_TARGET]:
			_executor.stop()
		return BeehaveNode.SUCCESS
	var position := _sector.entity_position(_entity_id)
	match action_kind:
		AiBtRunner.ACTION_DESTINATION, AiBtRunner.ACTION_TARGET:
			if not position.is_finite() or not _destination.is_finite():
				return BeehaveNode.FAILURE
			if _executor.goal() == _destination and _executor.arrived(position, _tuning.arrival_radius):
				return BeehaveNode.SUCCESS
			return BeehaveNode.RUNNING if _executor.request_destination(position, _destination) else BeehaveNode.FAILURE
		AiBtRunner.ACTION_REPAIR:
			if simulation_tick >= _next_repair_tick:
				var result := _combat._ai_repair(_entity_id, simulation_tick)
				if not bool(result.get("accepted", false)):
					return BeehaveNode.FAILURE
				_next_repair_tick = simulation_tick + _tuning.repair_interval_ticks
			return BeehaveNode.RUNNING
		AiBtRunner.ACTION_WAIT_OBSERVE:
			return BeehaveNode.RUNNING
		AiBtRunner.ACTION_STOP:
			_executor.stop()
			return BeehaveNode.SUCCESS
		_:
			return BeehaveNode.FAILURE


func _transition(next_state: int, reason: String) -> bool:
	var trace := NpcStateMachine.transition(_state, next_state, reason, _last_decision_tick)
	_last_transition_trace = trace.duplicate(true)
	if trace.is_empty() or not bool(trace.get("accepted", false)):
		return false
	if bool(trace["changed"]):
		_state = next_state
		_last_transition_reason = reason
	return true


static func _state_integer(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
