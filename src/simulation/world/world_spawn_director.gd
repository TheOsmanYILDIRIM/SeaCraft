class_name WorldSpawnDirector
extends RefCounted

const VERSION := 1
const MAX_TOTAL_PERSISTENT_WORLD_ENTITIES := 256
const MAX_NEAR_ENTITIES := 32
const MAX_SECTOR_POPULATION := 96
const MAX_FACTION_ROLE_POPULATION := 128
const MAX_SPAWN_JOBS_PER_TICK := 4
const MAX_LOGICAL_SPAWNS := 1024
const MAX_ADMIRAL_EVENTS := 2048
const DEFAULT_ADMIRAL_THRESHOLD := 3
const DEFAULT_ADMIRAL_COOLDOWN_TICKS := 120

var _authority_enabled := true
var _registry: DefinitionRegistry
var _sequence := 0
var _population: Dictionary = {}
var _logical_spawns: Dictionary = {}
var _admiral_counters: Dictionary = {}
var _admiral_events: Dictionary = {}
var _spawn_accepted := 0
var _spawn_rejected := 0
var _population_peak := 0


func _init(registry: DefinitionRegistry, authority_enabled: bool = true) -> void:
	_registry = registry
	_authority_enabled = authority_enabled


func register_existing(instance_id: String, definition_id: String, sector_id: String,
		faction_id: String, role: String, lod: String) -> bool:
	if not _authority_enabled or not _valid_population_row({
		"instance_id": instance_id, "definition_id": definition_id, "sector_id": sector_id,
		"faction_id": faction_id, "role": role, "lod": lod,
	}):
		return false
	if _population.has(instance_id) or _population.size() >= MAX_TOTAL_PERSISTENT_WORLD_ENTITIES:
		return false
	if _sector_count(sector_id) >= MAX_SECTOR_POPULATION or (lod == SimulationLOD.NEAR and _near_count() >= MAX_NEAR_ENTITIES):
		return false
	_population[instance_id] = {
		"instance_id": instance_id, "definition_id": definition_id, "sector_id": sector_id,
		"faction_id": faction_id, "role": role, "lod": lod,
	}
	_population_peak = maxi(_population_peak, _population.size())
	return true


func update_population(instance_id: String, sector_id: String, lod: String) -> bool:
	if not _authority_enabled or not _population.has(instance_id) or not SectorIds.valid(sector_id) or lod not in SimulationLOD.VALUES:
		return false
	var previous: Dictionary = _population[instance_id]
	if sector_id != previous["sector_id"] and _sector_count(sector_id) >= MAX_SECTOR_POPULATION:
		return false
	if lod == SimulationLOD.NEAR and previous["lod"] != SimulationLOD.NEAR and _near_count() >= MAX_NEAR_ENTITIES:
		return false
	previous["sector_id"] = sector_id
	previous["lod"] = lod
	_population[instance_id] = previous
	return true


func request_spawn(logical_key: String, sector_id: String, definition_id: String,
		faction_id: String, role: String, lod: String, tick: int) -> Dictionary:
	if not _authority_enabled:
		return _result(false, "not_authorized")
	if not SectorIds.valid(logical_key) or not SectorIds.valid(sector_id) or not SectorIds.valid(faction_id) or tick < 0:
		return _reject("invalid_spawn_request")
	if role.is_empty() or role.length() > 32 or lod not in SimulationLOD.VALUES:
		return _reject("invalid_spawn_request")
	if _logical_spawns.has(logical_key):
		return (_logical_spawns[logical_key] as Dictionary).duplicate(true)
	if _registry == null or not _registry.has_id(definition_id) or not _registry.matches_type(faction_id, "faction"):
		return _reject("unknown_content")
	if not _registry.matches_type(definition_id, "ship") and not _registry.matches_type(definition_id, "monster"):
		return _reject("unsupported_spawn_definition")
	if not _registry.matches_type(sector_id, "sector"):
		return _reject("unknown_sector")
	if _population.size() >= MAX_TOTAL_PERSISTENT_WORLD_ENTITIES:
		return _reject("population_cap")
	if _sector_count(sector_id) >= MAX_SECTOR_POPULATION:
		return _reject("sector_population_cap")
	if lod == SimulationLOD.NEAR and _near_count() >= MAX_NEAR_ENTITIES:
		return _reject("near_population_cap")
	if _faction_role_count(faction_id, role) >= MAX_FACTION_ROLE_POPULATION:
		return _reject("faction_role_cap")
	if _logical_spawns.size() >= MAX_LOGICAL_SPAWNS:
		return _reject("spawn_ledger_cap")
	var instance_id := "entity.spawn.v1.s%06d" % _sequence
	while _population.has(instance_id):
		_sequence += 1
		instance_id = "entity.spawn.v1.s%06d" % _sequence
	var plan := {
		"accepted": true,
		"reason": "",
		"logical_key": logical_key,
		"instance_id": instance_id,
		"definition_id": definition_id,
		"sector_id": sector_id,
		"faction_id": faction_id,
		"role": role,
		"lod": lod,
		"director_sequence": _sequence,
		"tick": tick,
	}
	_sequence += 1
	_logical_spawns[logical_key] = plan.duplicate(true)
	_population[instance_id] = {
		"instance_id": instance_id, "definition_id": definition_id, "sector_id": sector_id,
		"faction_id": faction_id, "role": role, "lod": lod,
	}
	_spawn_accepted += 1
	_population_peak = maxi(_population_peak, _population.size())
	return plan


func retire(instance_id: String, reason: String) -> bool:
	if not _authority_enabled or not _population.has(instance_id) or reason not in ["sunk", "mission_complete", "lifecycle_rule"]:
		return false
	_population.erase(instance_id)
	return true


func record_admiral_event(region_id: String, event_id: String, sector_id: String,
		definition_id: String, tick: int, threshold: int = DEFAULT_ADMIRAL_THRESHOLD,
		cooldown_ticks: int = DEFAULT_ADMIRAL_COOLDOWN_TICKS) -> Dictionary:
	if not _authority_enabled:
		return _result(false, "not_authorized")
	if not SectorIds.valid(region_id) or not SectorIds.valid(event_id) or not SectorIds.valid(sector_id) or tick < 0 or threshold <= 0 or cooldown_ticks < 0:
		return _result(false, "invalid_admiral_event")
	if _admiral_events.has(event_id):
		return {"accepted": false, "reason": "duplicate_event", "spawn_request": {}}
	if _admiral_events.size() >= MAX_ADMIRAL_EVENTS:
		return {"accepted": false, "reason": "event_ledger_cap", "spawn_request": {}}
	_admiral_events[event_id] = {"region_id": region_id, "tick": tick}
	var counter: Dictionary = (_admiral_counters.get(region_id, {
		"count": 0, "cooldown_until": 0, "spawn_cycle": 0,
	}) as Dictionary).duplicate(true)
	counter["count"] = mini(threshold, int(counter["count"]) + 1)
	var spawn_request := {}
	if int(counter["count"]) >= threshold and tick >= int(counter["cooldown_until"]):
		var cycle := int(counter["spawn_cycle"])
		var logical_key := "spawn.admiral.%s.c%06d" % [region_id, cycle]
		spawn_request = request_spawn(logical_key, sector_id, definition_id, "faction.practice_hostile", "admiral", SimulationLOD.FAR, tick)
		if bool(spawn_request.get("accepted", false)):
			counter["count"] = 0
			counter["spawn_cycle"] = cycle + 1
			counter["cooldown_until"] = tick + cooldown_ticks
	_admiral_counters[region_id] = counter
	return {"accepted": true, "reason": "", "spawn_request": spawn_request}


func population_count() -> int:
	return _population.size()


func population_snapshot() -> Array:
	var rows: Array = []
	var ids := _population.keys()
	ids.sort()
	for instance_id in ids:
		rows.append((_population[instance_id] as Dictionary).duplicate(true))
	return rows


func presentation_snapshot() -> Dictionary:
	var sectors: Dictionary = {}
	for row in _population.values():
		var sector_id := str(row["sector_id"])
		sectors[sector_id] = int(sectors.get(sector_id, 0)) + 1
	return {
		"population_total": _population.size(),
		"near_count": _near_count(),
		"sector_population": sectors,
		"spawn_accepted": _spawn_accepted,
		"spawn_rejected": _spawn_rejected,
	}


func snapshot_state() -> Dictionary:
	var logical: Array = []
	var logical_keys := _logical_spawns.keys()
	logical_keys.sort()
	for key in logical_keys:
		logical.append((_logical_spawns[key] as Dictionary).duplicate(true))
	var counters: Array = []
	var region_ids := _admiral_counters.keys()
	region_ids.sort()
	for region_id in region_ids:
		var counter: Dictionary = (_admiral_counters[region_id] as Dictionary).duplicate(true)
		counter["region_id"] = region_id
		counters.append(counter)
	var events: Array = []
	var event_ids := _admiral_events.keys()
	event_ids.sort()
	for event_id in event_ids:
		var event: Dictionary = (_admiral_events[event_id] as Dictionary).duplicate(true)
		event["event_id"] = event_id
		events.append(event)
	return {
		"version": VERSION,
		"sequence": _sequence,
		"population": population_snapshot(),
		"logical_spawns": logical,
		"admiral_counters": counters,
		"admiral_events": events,
	}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 6 or int(state.get("version", -1)) != VERSION or not _integer(state.get("sequence")) or int(state["sequence"]) < 0:
		return false
	for key in ["population", "logical_spawns", "admiral_counters", "admiral_events"]:
		if not state.get(key) is Array:
			return false
	if state["population"].size() > MAX_TOTAL_PERSISTENT_WORLD_ENTITIES or state["logical_spawns"].size() > MAX_LOGICAL_SPAWNS or state["admiral_events"].size() > MAX_ADMIRAL_EVENTS:
		return false
	var population: Dictionary = {}
	for raw in state["population"]:
		if not _valid_population_row(raw):
			return false
		var row: Dictionary = raw
		if population.has(row["instance_id"]):
			return false
		population[row["instance_id"]] = row.duplicate(true)
	var logical: Dictionary = {}
	for raw in state["logical_spawns"]:
		if not _valid_spawn_plan(raw):
			return false
		var row: Dictionary = raw
		if logical.has(row["logical_key"]) or not population.has(row["instance_id"]):
			return false
		logical[row["logical_key"]] = row.duplicate(true)
	var counters: Dictionary = {}
	for raw in state["admiral_counters"]:
		if not raw is Dictionary or raw.size() != 4 or not SectorIds.valid(str(raw.get("region_id", ""))):
			return false
		for key in ["count", "cooldown_until", "spawn_cycle"]:
			if not _integer(raw.get(key)) or int(raw[key]) < 0:
				return false
		if counters.has(raw["region_id"]):
			return false
		counters[raw["region_id"]] = {"count": int(raw["count"]), "cooldown_until": int(raw["cooldown_until"]), "spawn_cycle": int(raw["spawn_cycle"])}
	var events: Dictionary = {}
	for raw in state["admiral_events"]:
		if not raw is Dictionary or raw.size() != 3 or not SectorIds.valid(str(raw.get("event_id", ""))) or not SectorIds.valid(str(raw.get("region_id", ""))) or not _integer(raw.get("tick")) or int(raw["tick"]) < 0:
			return false
		if events.has(raw["event_id"]):
			return false
		events[raw["event_id"]] = {"region_id": raw["region_id"], "tick": int(raw["tick"])}
	# Validate hard caps against the plan before mutating current state.
	if _near_count_in(population) > MAX_NEAR_ENTITIES or _population_exceeds_sector_cap_in(population) or _population_exceeds_faction_role_cap_in(population):
		return false
	_population = population
	_logical_spawns = logical
	_admiral_counters = counters
	_admiral_events = events
	_sequence = int(state["sequence"])
	_population_peak = _population.size()
	_spawn_accepted = 0
	_spawn_rejected = 0
	return true


func telemetry() -> Dictionary:
	return {
		"population": _population.size(),
		"population_peak": _population_peak,
		"near_count": _near_count(),
		"spawn_accepted": _spawn_accepted,
		"spawn_rejected": _spawn_rejected,
		"director_sequence": _sequence,
		"logical_spawn_ledger": _logical_spawns.size(),
		"admiral_event_ledger": _admiral_events.size(),
	}


static func region_profile(name: String) -> Dictionary:
	match name:
		"low":
			return {"decision_cadence": 1.0, "formation_sophistication": 1, "encounter_tier": 1, "hazard_intensity": 1.0, "spawn_mix": 1}
		"high":
			return {"decision_cadence": 1.35, "formation_sophistication": 2, "encounter_tier": 2, "hazard_intensity": 1.5, "spawn_mix": 2}
	return {}


func _reject(reason: String) -> Dictionary:
	_spawn_rejected += 1
	return _result(false, reason)


static func _result(accepted: bool, reason: String) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "instance_id": ""}


func _near_count() -> int:
	var result := 0
	for row in _population.values():
		if row["lod"] == SimulationLOD.NEAR:
			result += 1
	return result




func _near_count_in(population: Dictionary) -> int:
	var result := 0
	for row in population.values():
		if row["lod"] == SimulationLOD.NEAR:
			result += 1
	return result


func _sector_count(sector_id: String) -> int:
	var result := 0
	for row in _population.values():
		if row["sector_id"] == sector_id:
			result += 1
	return result


func _faction_role_count(faction_id: String, role: String) -> int:
	var result := 0
	for row in _population.values():
		if row["faction_id"] == faction_id and row["role"] == role:
			result += 1
	return result


func _population_exceeds_sector_cap() -> bool:
	return _population_exceeds_sector_cap_in(_population)


func _population_exceeds_sector_cap_in(population: Dictionary) -> bool:
	var counts: Dictionary = {}
	for row in population.values():
		counts[row["sector_id"]] = int(counts.get(row["sector_id"], 0)) + 1
		if int(counts[row["sector_id"]]) > MAX_SECTOR_POPULATION:
			return true
	return false


func _population_exceeds_faction_role_cap() -> bool:
	return _population_exceeds_faction_role_cap_in(_population)


func _population_exceeds_faction_role_cap_in(population: Dictionary) -> bool:
	var counts: Dictionary = {}
	for row in population.values():
		var key := "%s|%s" % [row["faction_id"], row["role"]]
		counts[key] = int(counts.get(key, 0)) + 1
		if int(counts[key]) > MAX_FACTION_ROLE_POPULATION:
			return true
	return false


func _valid_population_row(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 6 or _registry == null:
		return false
	var row: Dictionary = value
	for key in ["instance_id", "definition_id", "sector_id", "faction_id"]:
		if not row.get(key) is String or not SectorIds.valid(row[key]):
			return false
	if not _registry.has_id(row["definition_id"]) or not _registry.matches_type(row["sector_id"], "sector") or not _registry.matches_type(row["faction_id"], "faction"):
		return false
	if not row.get("role") is String or row["role"].is_empty() or row["role"].length() > 32:
		return false
	return str(row.get("lod", "")) in SimulationLOD.VALUES


func _valid_spawn_plan(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 11 or value.get("accepted") != true or value.get("reason") != "":
		return false
	var row: Dictionary = value
	for key in ["logical_key", "instance_id", "definition_id", "sector_id", "faction_id"]:
		if not row.get(key) is String or not SectorIds.valid(row[key]):
			return false
	if not _valid_population_row({"instance_id": row["instance_id"], "definition_id": row["definition_id"], "sector_id": row["sector_id"], "faction_id": row["faction_id"], "role": row.get("role", ""), "lod": row.get("lod", "")}):
		return false
	return _integer(row.get("director_sequence")) and int(row["director_sequence"]) >= 0 and _integer(row.get("tick")) and int(row["tick"]) >= 0


static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 2147483647.0
