class_name WorldSimulationAuthority
extends RefCounted

const VERSION := 1
const MID_INTERVAL_TICKS := 4
const FAR_INTERVAL_TICKS := 8
const MAX_ENCOUNTERS_PER_TICK := 2
const MAX_PENDING_ENCOUNTERS := 64

var _authority_enabled := true
var _registry: DefinitionRegistry
var _graph_snapshot: Dictionary = {}
var _master_seed := 1
var _current_tick := 0
var _records: Dictionary = {}
var _scheduler: WorldWorkScheduler
var _spawn_director: WorldSpawnDirector
var _fleet_state: Dictionary = {}
var _encounters: Array = []
var _lod_transitions := 0
var _far_encounters_resolved := 0
var _mid_updates := 0
var _far_updates := 0


func _init(registry: DefinitionRegistry, graph: SectorGraph, master_seed: int = 1,
		authority_enabled: bool = true) -> void:
	_registry = registry
	_graph_snapshot = graph.presentation_snapshot().duplicate(true) if graph != null else {}
	_master_seed = master_seed
	_authority_enabled = authority_enabled
	_scheduler = WorldWorkScheduler.new(authority_enabled)
	_spawn_director = WorldSpawnDirector.new(registry, authority_enabled)


func register_record(record: Dictionary) -> bool:
	if not _authority_enabled or _registry == null or not _valid_record(record, _registry):
		return false
	var instance_id := str(record["instance_id"])
	if _records.has(instance_id):
		return false
	var state := FarFieldEntityState.semantic(record)
	if state.is_empty():
		return false
	if not _spawn_director.register_existing(instance_id, str(record["definition_id"]), str(record["sector_id"]),
			str(state["faction_id"]), str(state["role"]), str(state["lod"])):
		return false
	_records[instance_id] = record.duplicate(true)
	return true


func record(instance_id: String) -> Dictionary:
	var value: Variant = _records.get(instance_id)
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


func entity_count() -> int:
	return _records.size()


func classify_entity(instance_id: String, context: Dictionary, tick: int) -> String:
	if not _authority_enabled or tick < _current_tick or not _records.has(instance_id):
		return ""
	var record_in: Dictionary = _records[instance_id]
	var semantic := FarFieldEntityState.semantic(record_in)
	if semantic.is_empty():
		return ""
	var desired := SimulationLOD.classify(context, str(semantic["lod"]))
	if desired.is_empty():
		return ""
	var current := str(semantic["lod"])
	var next := SimulationLOD.transition(current, desired, int(semantic["residency_ticks"]))
	if next.is_empty():
		return ""
	if next == current:
		semantic["residency_ticks"] = int(semantic["residency_ticks"]) + 1
	else:
		if not _validate_transition(record_in, current, next):
			return ""
		semantic["lod"] = next
		semantic["residency_ticks"] = 0
		_lod_transitions += 1
	var updated := FarFieldEntityState.attach(record_in, semantic)
	if updated.is_empty() or not _spawn_director.update_population(instance_id, str(updated["sector_id"]), next):
		return ""
	_records[instance_id] = updated
	_current_tick = maxi(_current_tick, tick)
	return next


func force_lod_for_restore(instance_id: String, lod: String) -> bool:
	if not _authority_enabled or lod not in SimulationLOD.VALUES or not _records.has(instance_id):
		return false
	var existing: Dictionary = _records[instance_id]
	var semantic := FarFieldEntityState.semantic(existing)
	if semantic.is_empty() or not _validate_transition(existing, str(semantic["lod"]), lod):
		return false
	var previous_lod := str(semantic["lod"])
	semantic["lod"] = lod
	semantic["residency_ticks"] = 0
	var updated := FarFieldEntityState.attach(existing, semantic)
	if updated.is_empty() or not _spawn_director.update_population(instance_id, str(updated["sector_id"]), lod):
		return false
	if lod != previous_lod:
		_lod_transitions += 1
	_records[instance_id] = updated
	return true


func advance_entity(instance_id: String, elapsed_ticks: int, hazard_facts: Dictionary = {}) -> Dictionary:
	if not _authority_enabled or elapsed_ticks < 0 or not _records.has(instance_id):
		return {}
	var existing: Dictionary = _records[instance_id]
	var projection := FarFieldEntityState.project(existing)
	if projection.is_empty():
		return {}
	var lod := str(projection["lod"])
	if lod == SimulationLOD.NEAR:
		return {"state": projection, "events": []}
	if lod == SimulationLOD.MID:
		var mid := projection.duplicate(true)
		mid["last_simulation_tick"] = int(mid["last_simulation_tick"]) + elapsed_ticks
		mid["next_due_tick"] = int(mid["last_simulation_tick"]) + MID_INTERVAL_TICKS
		mid["world_job"] = _advance_world_job(mid["world_job"], elapsed_ticks, false)
		var mid_record := FarFieldEntityState.apply_projection(existing, mid)
		if mid_record.is_empty():
			return {}
		_records[instance_id] = mid_record
		_mid_updates += 1
		return {"state": mid, "events": []}
	var travel_result := FarTravelResolver.advance(projection, _graph_snapshot, hazard_facts, elapsed_ticks, _master_seed)
	if travel_result.is_empty():
		return {}
	var far: Dictionary = travel_result["state"]
	far["next_due_tick"] = int(far["last_simulation_tick"]) + FAR_INTERVAL_TICKS
	far["world_job"] = _advance_world_job(far["world_job"], elapsed_ticks, bool(travel_result["arrived"]))
	var far_record := FarFieldEntityState.apply_projection(existing, far)
	if far_record.is_empty() or not _spawn_director.update_population(instance_id, str(far["sector_id"]), SimulationLOD.FAR):
		return {}
	_records[instance_id] = far_record
	_far_updates += 1
	return travel_result


# Only the authoritative world queues FAR updates, never a client.
func queue_far_update(instance_id: String, due_tick: int) -> bool:
	if not _authority_enabled or due_tick < _current_tick or not _records.has(instance_id):
		return false
	var projection := FarFieldEntityState.project(_records[instance_id])
	if projection.is_empty() or str(projection["lod"]) != SimulationLOD.FAR:
		return false
	return _scheduler.enqueue("far", instance_id, "", due_tick)


func queue_path_job(instance_id: String, goal_id: String, due_tick: int) -> bool:
	return _scheduler.enqueue("path", instance_id, goal_id, due_tick) if _authority_enabled else false


func queue_spawn_job(request_id: String, sector_id: String, due_tick: int) -> bool:
	return _scheduler.enqueue("spawn", request_id, sector_id, due_tick) if _authority_enabled else false


func advance_scheduler(tick: int) -> Dictionary:
	if not _authority_enabled:
		return {}
	_current_tick = maxi(_current_tick, tick)
	return _scheduler.advance_tick(tick)


func queue_far_encounter(encounter_id: String, participant_ids: Array, elapsed_coarse_ticks: int) -> bool:
	if not _authority_enabled or not SectorIds.valid(encounter_id) or elapsed_coarse_ticks <= 0 or _encounters.size() >= MAX_PENDING_ENCOUNTERS:
		return false
	if participant_ids.size() < 2 or participant_ids.size() > FarCombatResolver.MAX_PARTICIPANTS:
		return false
	var normalized: Array = []
	var seen: Dictionary = {}
	for value in participant_ids:
		if not value is String or not SectorIds.valid(value) or seen.has(value) or not _records.has(value):
			return false
		var projection := FarFieldEntityState.project(_records[value])
		if projection.is_empty() or projection["lod"] != SimulationLOD.FAR:
			return false
		seen[value] = true
		normalized.append(value)
	normalized.sort()
	for raw in _encounters:
		if raw["encounter_id"] == encounter_id:
			return true
	_encounters.append({"encounter_id": encounter_id, "participant_ids": normalized, "elapsed_coarse_ticks": elapsed_coarse_ticks})
	_encounters.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["encounter_id"]) < str(b["encounter_id"]))
	return true


func process_far_encounters() -> Array:
	var outputs: Array = []
	if not _authority_enabled:
		return outputs
	var remaining: Array = []
	for raw in _encounters:
		if outputs.size() >= MAX_ENCOUNTERS_PER_TICK:
			remaining.append(raw)
			continue
		var result := _resolve_far_encounter(raw)
		if result.is_empty():
			remaining.append(raw)
		else:
			outputs.append(result)
			_far_encounters_resolved += 1
	_encounters = remaining
	return outputs


func request_spawn(logical_key: String, sector_id: String, definition_id: String,
		faction_id: String, role: String, lod: String, tick: int) -> Dictionary:
	return _spawn_director.request_spawn(logical_key, sector_id, definition_id, faction_id, role, lod, tick)


func record_admiral_event(region_id: String, event_id: String, sector_id: String,
		definition_id: String, tick: int, threshold: int = WorldSpawnDirector.DEFAULT_ADMIRAL_THRESHOLD,
		cooldown_ticks: int = WorldSpawnDirector.DEFAULT_ADMIRAL_COOLDOWN_TICKS) -> Dictionary:
	return _spawn_director.record_admiral_event(region_id, event_id, sector_id, definition_id, tick, threshold, cooldown_ticks)


func set_fleet_state(value: Dictionary) -> bool:
	if not _authority_enabled:
		return false
	if value.is_empty():
		_fleet_state = {}
		return true
	var probe := FleetCoordinator.new(true)
	if not probe.restore_state(value):
		return false
	_fleet_state = probe.snapshot_state()
	return true


func fleet_state() -> Dictionary:
	return _fleet_state.duplicate(true)


func snapshot_state() -> Dictionary:
	var rows: Array = []
	var ids := _records.keys()
	ids.sort()
	for instance_id in ids:
		rows.append((_records[instance_id] as Dictionary).duplicate(true))
	var index := PersistentEntityIndex.build(rows, _registry)
	if index.is_empty():
		return {}
	return {
		"version": VERSION,
		"entity_index": index,
		"scheduler": _scheduler.snapshot_state(),
		"spawn_director": _spawn_director.snapshot_state(),
		"fleet_state": _fleet_state.duplicate(true),
		"master_seed": _master_seed,
		"current_tick": _current_tick,
		"pending_encounters": _encounters.duplicate(true),
	}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled:
		return false
	var error := validate_snapshot(value, _registry)
	if not error.is_empty():
		return false
	var state: Dictionary = value
	var scheduler := WorldWorkScheduler.new(true)
	if not scheduler.restore_state(state["scheduler"]):
		return false
	var spawn := WorldSpawnDirector.new(_registry, true)
	if not spawn.restore_state(state["spawn_director"]):
		return false
	var records: Dictionary = {}
	for raw in state["entity_index"]["records"]:
		var normalized := FarFieldEntityState.normalize_record(raw)
		if normalized.is_empty():
			return false
		records[normalized["instance_id"]] = normalized
	var encounters: Array = []
	for raw in state["pending_encounters"]:
		var encounter: Dictionary = (raw as Dictionary).duplicate(true)
		encounter["elapsed_coarse_ticks"] = int(encounter["elapsed_coarse_ticks"])
		encounters.append(encounter)
	_records = records
	_scheduler = scheduler
	_spawn_director = spawn
	_fleet_state = (state["fleet_state"] as Dictionary).duplicate(true)
	_master_seed = int(state["master_seed"])
	_current_tick = int(state["current_tick"])
	_encounters = encounters
	_lod_transitions = 0
	_far_encounters_resolved = 0
	_mid_updates = 0
	_far_updates = 0
	return true


static func validate_snapshot(value: Variant, registry: DefinitionRegistry) -> String:
	if registry == null or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return "invalid_ai04_world"
	var state: Dictionary = value
	if state.size() != 8 or int(state.get("version", -1)) != VERSION:
		return "invalid_ai04_world"
	var index_error := PersistentEntityIndex.validate(state.get("entity_index"), registry)
	if not index_error.is_empty():
		return index_error
	var scheduler := WorldWorkScheduler.new(true)
	if not scheduler.restore_state(state.get("scheduler")):
		return "invalid_ai04_scheduler"
	var spawn := WorldSpawnDirector.new(registry, true)
	if not spawn.restore_state(state.get("spawn_director")):
		return "invalid_ai04_spawn"
	var fleet: Variant = state.get("fleet_state")
	if not fleet is Dictionary:
		return "invalid_ai04_fleet"
	if not fleet.is_empty():
		var coordinator := FleetCoordinator.new(true)
		if not coordinator.restore_state(fleet):
			return "invalid_ai04_fleet"
	if not _integer(state.get("master_seed")) or not _integer(state.get("current_tick")) or int(state["current_tick"]) < 0:
		return "invalid_ai04_world"
	var encounters: Variant = state.get("pending_encounters")
	if not encounters is Array or encounters.size() > MAX_PENDING_ENCOUNTERS:
		return "invalid_ai04_encounters"
	var encounter_ids: Dictionary = {}
	for raw in encounters:
		if not _valid_encounter(raw) or encounter_ids.has(raw["encounter_id"]):
			return "invalid_ai04_encounters"
		encounter_ids[raw["encounter_id"]] = true
	return ""


func presentation_snapshot() -> Dictionary:
	var lod_counts := {SimulationLOD.NEAR: 0, SimulationLOD.MID: 0, SimulationLOD.FAR: 0}
	var entities: Array = []
	var ids := _records.keys()
	ids.sort()
	for instance_id in ids:
		var state := FarFieldEntityState.project(_records[instance_id])
		if state.is_empty():
			continue
		lod_counts[state["lod"]] = int(lod_counts[state["lod"]]) + 1
		entities.append({"instance_id": instance_id, "lod": state["lod"], "sector_id": state["sector_id"], "fleet_id": state["fleet_id"], "job": state["world_job"]})
	return {
		"entities": entities,
		"lod_counts": lod_counts,
		"spawn_director": _spawn_director.presentation_snapshot(),
		"fleet_state": _fleet_state.duplicate(true),
	}


func telemetry() -> Dictionary:
	var counts := {SimulationLOD.NEAR: 0, SimulationLOD.MID: 0, SimulationLOD.FAR: 0}
	for record_in in _records.values():
		var state := FarFieldEntityState.semantic(record_in)
		if not state.is_empty():
			counts[state["lod"]] = int(counts[state["lod"]]) + 1
	var scheduler_metrics := _scheduler.telemetry()
	var spawn_metrics := _spawn_director.telemetry()
	return {
		"world_entities": _records.size(),
		"near_count": int(counts[SimulationLOD.NEAR]),
		"mid_count": int(counts[SimulationLOD.MID]),
		"far_count": int(counts[SimulationLOD.FAR]),
		"lod_transitions": _lod_transitions,
		"mid_updates": _mid_updates,
		"far_updates": _far_updates,
		"far_encounters_resolved": _far_encounters_resolved,
		"pending_encounters": _encounters.size(),
		"scheduler": scheduler_metrics,
		"spawn": spawn_metrics,
	}


func _resolve_far_encounter(encounter: Dictionary) -> Dictionary:
	var participants: Array = []
	var max_sequence := 0
	for instance_id in encounter["participant_ids"]:
		var projection := FarFieldEntityState.project(_records[instance_id])
		var participant := FarCombatResolver.participant_from_far(projection)
		if participant.is_empty():
			return {}
		participants.append(participant)
		max_sequence = maxi(max_sequence, int(projection["rng_event_sequence"]))
	var result := FarCombatResolver.resolve(participants, int(encounter["elapsed_coarse_ticks"]), _master_seed, max_sequence)
	if result.is_empty():
		return {}
	var sunk_fleet_rows: Array = []
	for participant in result["participants"]:
		var instance_id := str(participant["instance_id"])
		var current := FarFieldEntityState.project(_records[instance_id])
		current["hull_ratio"] = participant["hull_ratio"]
		current["alive"] = participant["alive"]
		current["combat"]["status"] = participant["status"]
		current["rng_event_sequence"] = int(result["next_event_sequence"])
		var updated := FarFieldEntityState.apply_projection(_records[instance_id], current)
		if updated.is_empty():
			return {}
		_records[instance_id] = updated
		if participant["status"] == "sunk" and not current["fleet_id"].is_empty():
			sunk_fleet_rows.append({"fleet_id": current["fleet_id"], "member_id": instance_id, "sector_id": current["sector_id"]})
	if not _fleet_state.is_empty() and not sunk_fleet_rows.is_empty():
		var coordinator := FleetCoordinator.new(true)
		if not coordinator.restore_state(_fleet_state):
			return {}
		for row in sunk_fleet_rows:
			coordinator.mark_member_status(row["fleet_id"], row["member_id"], false, false, row["sector_id"])
		_fleet_state = coordinator.snapshot_state()
	return result


func _validate_transition(record_in: Dictionary, _current: String, desired: String) -> bool:
	if desired not in SimulationLOD.VALUES:
		return false
	if _registry == null or not _registry.has_id(str(record_in["definition_id"])) or not _registry.matches_type(str(record_in["sector_id"]), "sector"):
		return false
	return not FarFieldEntityState.semantic(record_in).is_empty()


static func _advance_world_job(value: Variant, elapsed_ticks: int, arrived: bool) -> Dictionary:
	if not value is Dictionary or value.is_empty():
		return {} if value is Dictionary else {}
	var job: Dictionary = value
	if not WorldJob.valid(job) or bool(job["completed"]):
		return job.duplicate(true)
	if job["job_type"] == WorldJob.DOCK:
		if job["phase"] == WorldJob.QUEUE and elapsed_ticks > 0:
			return WorldJob.with_phase(job, WorldJob.SERVICE, minf(0.75, float(job["progress"]) + 0.25))
		if job["phase"] == WorldJob.SERVICE and elapsed_ticks > 0:
			return WorldJob.with_phase(job, WorldJob.COMPLETE, 1.0)
	if arrived:
		return WorldJob.with_phase(job, WorldJob.COMPLETE, 1.0)
	var progress := clampf(float(job["progress"]) + float(elapsed_ticks) * 0.0025, 0.0, 0.95)
	return WorldJob.with_phase(job, str(job["phase"]), progress)


static func _valid_record(record_in: Dictionary, registry: DefinitionRegistry) -> bool:
	var built := PersistentEntityIndex.build([record_in], registry)
	return not built.is_empty() and not FarFieldEntityState.semantic(record_in).is_empty()


static func _valid_encounter(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not SectorIds.valid(str(value.get("encounter_id", ""))):
		return false
	if not value.get("participant_ids") is Array or value["participant_ids"].size() < 2 or value["participant_ids"].size() > FarCombatResolver.MAX_PARTICIPANTS:
		return false
	var seen: Dictionary = {}
	for participant_id in value["participant_ids"]:
		if not participant_id is String or not SectorIds.valid(participant_id) or seen.has(participant_id):
			return false
		seen[participant_id] = true
	return _integer(value.get("elapsed_coarse_ticks")) and int(value["elapsed_coarse_ticks"]) > 0


static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 2147483647.0
