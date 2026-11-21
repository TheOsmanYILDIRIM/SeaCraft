class_name FleetCoordinator
extends RefCounted

const VERSION := 1
const MAX_FLEETS_ACTIVE := 8
const MAX_FLEET_MEMBERS := 8
const MAX_FORMATION_UPDATES_PER_TICK := 8
const MAX_PATH_JOBS_PER_TICK := 4
const MAX_SUPPORT_RECIPIENTS := 4
const MAX_SUPPORT_HOPS := 2
const MAX_SUPPORT_LEDGER := 64
const DESTINATION_HYSTERESIS := 16.0
const COMMAND_REFRESH_TICKS := 30

const COLUMN := "column"
const LINE := "line"
const WEDGE := "wedge"
const FORMATIONS := [COLUMN, LINE, WEDGE]

const MERCHANT := "merchant"
const ESCORT := "escort"
const SCOUT := "scout"
const ROLES := [MERCHANT, ESCORT, SCOUT]

const FORMATION := "formation"
const BREAK_FOR_COMBAT := "break_for_combat"
const REGROUP := "regroup"

var _authority_enabled := true
var _fleets: Dictionary = {}
var _support_handled: Dictionary = {}
var _current_tick := -1
var _formation_updates_tick := 0
var _path_jobs_tick := 0

var formation_updates := 0
var path_requests := 0
var max_formation_updates_observed := 0
var max_path_jobs_observed := 0
var slot_changes := 0
var break_count := 0
var regroup_count := 0
var succession_count := 0
var world_jobs_completed := 0
var support_requests := 0
var support_handled_count := 0


func _init(authority_enabled: bool = true) -> void:
	_authority_enabled = authority_enabled


func register_fleet(fixture: Dictionary) -> bool:
	if not _authority_enabled or _fleets.size() >= MAX_FLEETS_ACTIVE or not DtoContract.is_primitive_safe(fixture):
		return false
	var fleet_id := str(fixture.get("fleet_id", ""))
	var leader_id := str(fixture.get("leader_id", ""))
	var sector_id := str(fixture.get("sector_id", ""))
	var formation_type := str(fixture.get("formation_type", ""))
	var members: Variant = fixture.get("members")
	var job: Variant = fixture.get("world_job")
	if not SectorIds.valid(fleet_id) or _fleets.has(fleet_id) or not SectorIds.valid(leader_id) or not SectorIds.valid(sector_id):
		return false
	if formation_type not in FORMATIONS or not members is Array or members.is_empty() or members.size() > MAX_FLEET_MEMBERS:
		return false
	if not job is Dictionary or not WorldJob.valid(job) or str(job["owner_id"]) != fleet_id:
		return false
	var normalized: Array = []
	var seen: Dictionary = {}
	var leader_found := false
	for raw in members:
		if not raw is Dictionary:
			return false
		var id := str(raw.get("member_id", ""))
		var role := str(raw.get("role", ""))
		var member_sector := str(raw.get("sector_id", ""))
		if not SectorIds.valid(id) or seen.has(id) or role not in ROLES or not SectorIds.valid(member_sector):
			return false
		if not raw.get("alive") is bool or not raw.get("available") is bool:
			return false
		var preferred := float(raw.get("preferred_distance", 120.0))
		if not is_finite(preferred) or preferred < 0.0 or preferred > 4096.0:
			return false
		seen[id] = true
		leader_found = leader_found or id == leader_id
		normalized.append({
			"member_id": id,
			"role": role,
			"alive": bool(raw["alive"]),
			"available": bool(raw["available"]),
			"sector_id": member_sector,
			"preferred_distance": preferred,
			"slot_index": -1,
		})
	if not leader_found:
		return false
	normalized.sort_custom(_member_before)
	var fleet := {
		"fleet_id": fleet_id,
		"leader_id": leader_id,
		"sector_id": sector_id,
		"members": normalized,
		"formation_type": formation_type,
		"slot_assignments": [],
		"fleet_state": FORMATION,
		"fleet_goal_id": str(fixture.get("fleet_goal_id", job.get("destination_id", ""))),
		"world_job": (job as Dictionary).duplicate(true),
		"route_progress": float(job.get("progress", 0.0)),
		"commander_sequence": 0,
		"last_destinations": {},
		"last_command_ticks": {},
	}
	_assign_slots(fleet)
	_fleets[fleet_id] = fleet
	return true


func set_formation(fleet_id: String, formation_type: String) -> bool:
	if not _authority_enabled or formation_type not in FORMATIONS or not _fleets.has(fleet_id):
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	if fleet["formation_type"] == formation_type:
		return true
	fleet["formation_type"] = formation_type
	_assign_slots(fleet)
	fleet["last_destinations"] = {}
	fleet["last_command_ticks"] = {}
	_fleets[fleet_id] = fleet
	return true


func formation_slots(fleet_id: String) -> Array:
	var fleet: Dictionary = _fleets.get(fleet_id, {})
	return (fleet.get("slot_assignments", []) as Array).duplicate(true)


func begin_tick(tick: int) -> bool:
	if tick < 0:
		return false
	if tick != _current_tick:
		_current_tick = tick
		_formation_updates_tick = 0
		_path_jobs_tick = 0
	return true


func formation_commands(fleet_id: String, leader_position: Vector2, leader_heading: float, tick: int) -> Array:
	var commands: Array = []
	if not _authority_enabled or not begin_tick(tick) or not leader_position.is_finite() or not is_finite(leader_heading):
		return commands
	var fleet: Dictionary = _fleets.get(fleet_id, {})
	if fleet.is_empty() or fleet["fleet_state"] == BREAK_FOR_COMBAT:
		return commands
	var assignments: Array = fleet["slot_assignments"]
	assignments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot_index"]) < int(b["slot_index"]))
	for raw in assignments:
		if _formation_updates_tick >= MAX_FORMATION_UPDATES_PER_TICK or _path_jobs_tick >= MAX_PATH_JOBS_PER_TICK:
			break
		var slot: Dictionary = raw
		var member := _member(fleet, str(slot["member_id"]))
		if member.is_empty() or not bool(member["alive"]) or not bool(member["available"]) or str(member["sector_id"]) != str(fleet["sector_id"]):
			continue
		var local := Vector2(float(slot["local_offset"]["x"]), float(slot["local_offset"]["y"]))
		var destination := leader_position + local.rotated(leader_heading)
		var last_map: Dictionary = fleet["last_destinations"]
		var tick_map: Dictionary = fleet["last_command_ticks"]
		var previous: Variant = last_map.get(member["member_id"])
		var last_tick := int(tick_map.get(member["member_id"], -COMMAND_REFRESH_TICKS))
		if previous is Dictionary:
			var previous_point := Vector2(float(previous["x"]), float(previous["y"]))
			if previous_point.distance_to(destination) < DESTINATION_HYSTERESIS and tick - last_tick < COMMAND_REFRESH_TICKS:
				continue
		fleet["commander_sequence"] = int(fleet["commander_sequence"]) + 1
		var sequence := int(fleet["commander_sequence"])
		var kind := FleetCommand.REGROUP if fleet["fleet_state"] == REGROUP else FleetCommand.OCCUPY_SLOT
		var reason := "regroup_to_slot" if fleet["fleet_state"] == REGROUP else "formation_slot"
		var command := FleetCommand.create(
			fleet_id, str(fleet["leader_id"]), str(member["member_id"]),
			"command.%s.%d" % [fleet_id, sequence], kind, str(fleet["fleet_goal_id"]),
			destination, slot, tick, sequence, reason
		)
		if command.is_empty():
			continue
		commands.append(command)
		last_map[member["member_id"]] = {"x": destination.x, "y": destination.y}
		tick_map[member["member_id"]] = tick
		_formation_updates_tick += 1
		_path_jobs_tick += 1
		formation_updates += 1
		path_requests += 1
	_fleets[fleet_id] = fleet
	max_formation_updates_observed = maxi(max_formation_updates_observed, _formation_updates_tick)
	max_path_jobs_observed = maxi(max_path_jobs_observed, _path_jobs_tick)
	return commands


func set_threat(fleet_id: String, hostile_present: bool, target_safe_zone: bool) -> bool:
	if not _authority_enabled or not _fleets.has(fleet_id):
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	var effective_hostile := hostile_present and not target_safe_zone
	if effective_hostile:
		if fleet["fleet_state"] != BREAK_FOR_COMBAT:
			fleet["fleet_state"] = BREAK_FOR_COMBAT
			break_count += 1
	elif fleet["fleet_state"] == BREAK_FOR_COMBAT:
		fleet["fleet_state"] = REGROUP
		regroup_count += 1
		fleet["last_destinations"] = {}
		fleet["last_command_ticks"] = {}
	_fleets[fleet_id] = fleet
	return true


func complete_regroup(fleet_id: String) -> bool:
	if not _authority_enabled or not _fleets.has(fleet_id):
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	if fleet["fleet_state"] != REGROUP:
		return false
	fleet["fleet_state"] = FORMATION
	_fleets[fleet_id] = fleet
	return true


func mark_member_status(fleet_id: String, member_id: String, alive: bool, available: bool, sector_id: String) -> bool:
	if not _authority_enabled or not _fleets.has(fleet_id) or not SectorIds.valid(member_id) or not SectorIds.valid(sector_id):
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	var found := false
	for raw in fleet["members"]:
		if raw["member_id"] == member_id:
			raw["alive"] = alive
			raw["available"] = available
			raw["sector_id"] = sector_id
			found = true
			break
	if not found:
		return false
	if member_id == fleet["leader_id"] and (not alive or not available or sector_id != fleet["sector_id"]):
		_select_successor(fleet)
	_fleets[fleet_id] = fleet
	return true


func set_world_job(fleet_id: String, job: Dictionary) -> bool:
	if not _authority_enabled or not _fleets.has(fleet_id) or not WorldJob.valid(job) or str(job["owner_id"]) != fleet_id:
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	fleet["world_job"] = job.duplicate(true)
	fleet["fleet_goal_id"] = str(job.get("destination_id", ""))
	fleet["route_progress"] = float(job.get("progress", 0.0))
	_fleets[fleet_id] = fleet
	return true


func advance_world_job(fleet_id: String, phase: String, progress: float) -> bool:
	if not _authority_enabled or not _fleets.has(fleet_id):
		return false
	var fleet: Dictionary = _fleets[fleet_id]
	var next := WorldJob.with_phase(fleet["world_job"], phase, progress)
	if next.is_empty():
		return false
	var was_complete := bool(fleet["world_job"].get("completed", false))
	fleet["world_job"] = next
	fleet["route_progress"] = progress
	fleet["fleet_goal_id"] = str(next.get("destination_id", ""))
	if not was_complete and bool(next["completed"]):
		world_jobs_completed += 1
	_fleets[fleet_id] = fleet
	return true


func dispatch_support(fleet_id: String, support_id: String, requester_id: String, target_id: String,
		tick: int, hop_count: int = 0) -> Array:
	var commands: Array = []
	if not _authority_enabled or not _fleets.has(fleet_id) or not SectorIds.valid(support_id) or not SectorIds.valid(requester_id):
		return commands
	if not target_id.is_empty() and not SectorIds.valid(target_id):
		return commands
	if tick < 0 or hop_count < 0 or hop_count > MAX_SUPPORT_HOPS or _support_handled.has(support_id):
		return commands
	if _support_handled.size() >= MAX_SUPPORT_LEDGER:
		return commands
	support_requests += 1
	var fleet: Dictionary = _fleets[fleet_id]
	var candidates: Array = []
	for raw in fleet["members"]:
		if raw["member_id"] == requester_id or raw["role"] != ESCORT:
			continue
		if bool(raw["alive"]) and bool(raw["available"]) and str(raw["sector_id"]) == str(fleet["sector_id"]):
			candidates.append(raw)
	candidates.sort_custom(_member_before)
	for raw in candidates:
		if commands.size() >= MAX_SUPPORT_RECIPIENTS:
			break
		fleet["commander_sequence"] = int(fleet["commander_sequence"]) + 1
		var sequence := int(fleet["commander_sequence"])
		var command := FleetCommand.create(
			fleet_id, str(fleet["leader_id"]), str(raw["member_id"]),
			"command.%s.%d" % [fleet_id, sequence], FleetCommand.SUPPORT_RESPONSE,
			target_id, Vector2.INF, {}, tick, sequence, "bounded_existing_fleet_support"
		)
		if not command.is_empty():
			commands.append(command)
	_support_handled[support_id] = {"tick": tick, "hop_count": hop_count, "requester_id": requester_id}
	support_handled_count += commands.size()
	_fleets[fleet_id] = fleet
	return commands


func fleet_snapshot(fleet_id: String) -> Dictionary:
	var fleet: Dictionary = _fleets.get(fleet_id, {})
	return fleet.duplicate(true)


func presentation_snapshot() -> Dictionary:
	var rows: Array = []
	var ids := _fleets.keys()
	ids.sort()
	for id in ids:
		var fleet: Dictionary = _fleets[id]
		var members: Array = []
		for raw in fleet["members"]:
			members.append({"member_id": raw["member_id"], "role": raw["role"], "slot_index": raw["slot_index"]})
		rows.append({
			"fleet_id": id, "leader_id": fleet["leader_id"], "members": members,
			"formation_type": fleet["formation_type"], "fleet_state": fleet["fleet_state"],
			"job_type": fleet["world_job"]["job_type"], "job_phase": fleet["world_job"]["phase"],
			"fleet_goal_id": fleet["fleet_goal_id"],
		})
	return {"fleets": rows}


func snapshot_state() -> Dictionary:
	var rows: Array = []
	var ids := _fleets.keys()
	ids.sort()
	for id in ids:
		rows.append((_fleets[id] as Dictionary).duplicate(true))
	var support: Array = []
	var support_ids := _support_handled.keys()
	support_ids.sort()
	for id in support_ids:
		var row: Dictionary = (_support_handled[id] as Dictionary).duplicate(true)
		row["support_id"] = id
		support.append(row)
	return {"version": VERSION, "fleets": rows, "support_handled": support}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if int(state.get("version", -1)) != VERSION or not state.get("fleets") is Array or not state.get("support_handled") is Array:
		return false
	if state["fleets"].size() > MAX_FLEETS_ACTIVE or state["support_handled"].size() > MAX_SUPPORT_LEDGER:
		return false
	var planned: Dictionary = {}
	for raw in state["fleets"]:
		if not raw is Dictionary:
			return false
		var fleet: Dictionary = raw.duplicate(true)
		if not _valid_fleet_snapshot(fleet) or planned.has(fleet["fleet_id"]):
			return false
		var leader := _member(fleet, str(fleet["leader_id"]))
		if leader.is_empty() or not bool(leader["alive"]) or not bool(leader["available"]) or str(leader["sector_id"]) != str(fleet["sector_id"]):
			_select_successor(fleet)
		planned[fleet["fleet_id"]] = fleet
	var support: Dictionary = {}
	for raw in state["support_handled"]:
		if not raw is Dictionary:
			return false
		var support_id := str(raw.get("support_id", ""))
		if not SectorIds.valid(support_id) or support.has(support_id):
			return false
		support[support_id] = {"tick": int(raw.get("tick", 0)), "hop_count": int(raw.get("hop_count", 0)), "requester_id": str(raw.get("requester_id", ""))}
	_fleets = planned
	_support_handled = support
	return true


func fleet_count() -> int:
	return _fleets.size()


func member_count() -> int:
	var total := 0
	for fleet in _fleets.values():
		total += (fleet["members"] as Array).size()
	return total


func telemetry() -> Dictionary:
	return {
		"active_fleets": fleet_count(), "member_count": member_count(),
		"formation_updates": formation_updates, "max_formation_updates_per_tick": max_formation_updates_observed,
		"path_requests": path_requests, "max_path_jobs_per_tick": max_path_jobs_observed,
		"slot_changes": slot_changes, "break_count": break_count, "regroup_count": regroup_count,
		"succession_count": succession_count, "world_jobs_completed": world_jobs_completed,
		"support_requests": support_requests, "support_handled": support_handled_count,
	}


func _assign_slots(fleet: Dictionary) -> void:
	var leader_id := str(fleet["leader_id"])
	var candidates: Array = []
	for raw in fleet["members"]:
		raw["slot_index"] = -1
		if raw["member_id"] != leader_id:
			candidates.append(raw)
	candidates.sort_custom(_member_before)
	var slots := _slot_definitions(str(fleet["formation_type"]), candidates.size())
	var assignments: Array = []
	for member in candidates:
		var best_index := -1
		var best_score := INF
		for i in slots.size():
			var slot: Dictionary = slots[i]
			if bool(slot.get("assigned", false)):
				continue
			var offset := Vector2(float(slot["local_offset"]["x"]), float(slot["local_offset"]["y"]))
			var score := absf(offset.length() - float(member["preferred_distance"]))
			if str(slot["role_preference"]) != str(member["role"]):
				score += 10000.0
			if score < best_score or (is_equal_approx(score, best_score) and (best_index < 0 or int(slot["slot_index"]) < int(slots[best_index]["slot_index"]))):
				best_score = score
				best_index = i
		if best_index < 0:
			continue
		slots[best_index]["assigned"] = true
		member["slot_index"] = int(slots[best_index]["slot_index"])
		assignments.append({
			"slot_index": int(slots[best_index]["slot_index"]),
			"local_offset": (slots[best_index]["local_offset"] as Dictionary).duplicate(true),
			"role_preference": str(slots[best_index]["role_preference"]),
			"member_id": str(member["member_id"]),
		})
	assignments.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["slot_index"]) < int(b["slot_index"]))
	if fleet.get("slot_assignments", []) != assignments:
		slot_changes += 1
	fleet["slot_assignments"] = assignments


func _slot_definitions(formation_type: String, count: int) -> Array:
	var slots: Array = []
	for i in count:
		var offset := Vector2.ZERO
		var role := ESCORT
		match formation_type:
			COLUMN:
				if i == 0:
					offset = Vector2(0, -140)
					role = SCOUT
				else:
					offset = Vector2(0, 100 * i)
			LINE:
				if i == 0:
					offset = Vector2(-120, 0)
				elif i == 1:
					offset = Vector2(120, 0)
				elif i == 2:
					offset = Vector2(0, -150)
					role = SCOUT
				else:
					offset = Vector2((i - 1) * 90, 80)
			WEDGE:
				if i == 0:
					offset = Vector2(-95, 95)
				elif i == 1:
					offset = Vector2(95, 95)
				elif i == 2:
					offset = Vector2(0, -150)
					role = SCOUT
				else:
					var side := -1.0 if i % 2 == 0 else 1.0
					offset = Vector2(side * (95 + 45 * i), 95 + 55 * i)
		slots.append({"slot_index": i, "local_offset": {"x": offset.x, "y": offset.y}, "role_preference": role, "assigned": false})
	return slots


func _select_successor(fleet: Dictionary) -> void:
	var candidates: Array = []
	for raw in fleet["members"]:
		if not bool(raw["alive"]) or not bool(raw["available"]) or str(raw["sector_id"]) != str(fleet["sector_id"]):
			continue
		if raw["member_id"] == fleet["leader_id"]:
			continue
		candidates.append(raw)
	candidates.sort_custom(_member_before)
	fleet["leader_id"] = "" if candidates.is_empty() else str(candidates[0]["member_id"])
	fleet["fleet_state"] = REGROUP
	fleet["last_destinations"] = {}
	fleet["last_command_ticks"] = {}
	succession_count += 1
	_assign_slots(fleet)


func _member(fleet: Dictionary, member_id: String) -> Dictionary:
	for raw in fleet.get("members", []):
		if raw is Dictionary and raw.get("member_id") == member_id:
			return raw
	return {}


static func _member_before(a: Dictionary, b: Dictionary) -> bool:
	var ap := _role_priority(str(a.get("role", "")))
	var bp := _role_priority(str(b.get("role", "")))
	if ap != bp:
		return ap < bp
	return str(a.get("member_id", "")) < str(b.get("member_id", ""))


static func _role_priority(role: String) -> int:
	match role:
		MERCHANT:
			return 0
		ESCORT:
			return 1
		SCOUT:
			return 2
	return 99


func _valid_fleet_snapshot(fleet: Dictionary) -> bool:
	if not SectorIds.valid(str(fleet.get("fleet_id", ""))) or not SectorIds.valid(str(fleet.get("sector_id", ""))):
		return false
	var leader := str(fleet.get("leader_id", ""))
	if not leader.is_empty() and not SectorIds.valid(leader):
		return false
	if str(fleet.get("formation_type", "")) not in FORMATIONS or str(fleet.get("fleet_state", "")) not in [FORMATION, BREAK_FOR_COMBAT, REGROUP]:
		return false
	if not fleet.get("members") is Array or fleet["members"].is_empty() or fleet["members"].size() > MAX_FLEET_MEMBERS:
		return false
	if not fleet.get("slot_assignments") is Array or not fleet.get("last_destinations") is Dictionary or not fleet.get("last_command_ticks") is Dictionary:
		return false
	if not WorldJob.valid(fleet.get("world_job", {})):
		return false
	if typeof(fleet.get("commander_sequence")) not in [TYPE_INT, TYPE_FLOAT] or int(fleet["commander_sequence"]) < 0:
		return false
	return true
