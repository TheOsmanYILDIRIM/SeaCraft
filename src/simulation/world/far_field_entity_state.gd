class_name FarFieldEntityState
extends RefCounted

const VERSION := 1
const RNG_VERSION := 1
const PAYLOAD_KEY := "ai04"
const MAX_ROUTE_SECTORS := 32
const MAX_ROLE_LENGTH := 32


static func default_semantic(lod: String, faction_id: String = "", fleet_id: String = "",
		role: String = "merchant", world_job: Dictionary = {}, destination_id: String = "",
		speed_per_tick: float = 0.02, region_profile: String = "low") -> Dictionary:
	var result := {
		"version": VERSION,
		"lod": lod,
		"residency_ticks": 0,
		"faction_id": faction_id,
		"fleet_id": fleet_id,
		"role": role,
		"world_job": world_job.duplicate(true),
		"travel": {
			"destination_id": destination_id,
			"route": [],
			"route_index": 0,
			"segment_progress": 0.0,
			"speed_per_tick": speed_per_tick,
		},
		"combat": {"status": "idle", "strength": 1.0, "hostile": false},
		"last_simulation_tick": 0,
		"next_due_tick": 1,
		"rng_event_sequence": 0,
		"rng_version": RNG_VERSION,
		"region_profile": region_profile,
	}
	return result if valid_semantic(result) else {}


static func attach(record: Dictionary, semantic: Dictionary) -> Dictionary:
	if not _base_record_shape(record) or not valid_semantic(semantic):
		return {}
	var result := record.duplicate(true)
	var payload: Dictionary = (result.get("payload", {}) as Dictionary).duplicate(true)
	payload[PAYLOAD_KEY] = semantic.duplicate(true)
	result["payload"] = payload
	return result if DtoContract.is_primitive_safe(result) else {}


static func semantic(record: Dictionary) -> Dictionary:
	if not _base_record_shape(record):
		return {}
	var payload: Variant = record.get("payload")
	if not payload is Dictionary:
		return {}
	var value: Variant = payload.get(PAYLOAD_KEY)
	return (value as Dictionary).duplicate(true) if valid_semantic(value) else {}


static func project(record: Dictionary) -> Dictionary:
	var state := semantic(record)
	if state.is_empty():
		return {}
	var position: Dictionary = record["position"]
	var result := {
		"version": VERSION,
		"instance_id": record["instance_id"],
		"definition_id": record["definition_id"],
		"entity_kind": record["entity_kind"],
		"faction_id": state["faction_id"],
		"sector_id": record["sector_id"],
		"position": {"x": float(position["x"]), "y": float(position["y"])},
		"hull_ratio": clampf(float(record["health"]) / 100.0, 0.0, 1.0),
		"alive": record["alive"],
		"fleet_id": state["fleet_id"],
		"role": state["role"],
		"world_job": (state["world_job"] as Dictionary).duplicate(true),
		"cargo_summary": (record["inventory"] as Dictionary).duplicate(true),
		"combat": (state["combat"] as Dictionary).duplicate(true),
		"cooldowns": (record["cooldowns"] as Dictionary).duplicate(true),
		"travel": (state["travel"] as Dictionary).duplicate(true),
		"lod": state["lod"],
		"residency_ticks": int(state["residency_ticks"]),
		"last_simulation_tick": int(state["last_simulation_tick"]),
		"next_due_tick": int(state["next_due_tick"]),
		"rng_event_sequence": int(state["rng_event_sequence"]),
		"rng_version": int(state["rng_version"]),
		"region_profile": state["region_profile"],
	}
	return result if valid_projection(result) else {}


static func apply_projection(record: Dictionary, projection: Dictionary) -> Dictionary:
	if not _base_record_shape(record) or not valid_projection(projection):
		return {}
	if projection["instance_id"] != record["instance_id"] or projection["definition_id"] != record["definition_id"] or projection["entity_kind"] != record["entity_kind"]:
		return {}
	var result := record.duplicate(true)
	result["sector_id"] = projection["sector_id"]
	result["position"] = (projection["position"] as Dictionary).duplicate(true)
	result["health"] = clampf(float(projection["hull_ratio"]) * 100.0, 0.0, 100.0)
	result["alive"] = bool(projection["alive"])
	result["cooldowns"] = (projection["cooldowns"] as Dictionary).duplicate(true)
	result["inventory"] = (projection["cargo_summary"] as Dictionary).duplicate(true)
	var state := semantic(record)
	if state.is_empty():
		return {}
	for key in ["faction_id", "fleet_id", "role", "lod", "region_profile"]:
		state[key] = projection[key]
	state["world_job"] = (projection["world_job"] as Dictionary).duplicate(true)
	state["combat"] = (projection["combat"] as Dictionary).duplicate(true)
	state["travel"] = (projection["travel"] as Dictionary).duplicate(true)
	for key in ["residency_ticks", "last_simulation_tick", "next_due_tick", "rng_event_sequence", "rng_version"]:
		state[key] = int(projection[key])
	return attach(result, state)


static func valid_semantic(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 14 or int(state.get("version", -1)) != VERSION:
		return false
	if str(state.get("lod", "")) not in SimulationLOD.VALUES:
		return false
	for key in ["residency_ticks", "last_simulation_tick", "next_due_tick", "rng_event_sequence", "rng_version"]:
		if not _integer(state.get(key)) or int(state[key]) < 0:
			return false
	if int(state["rng_version"]) != RNG_VERSION:
		return false
	for key in ["faction_id", "fleet_id"]:
		var stable: Variant = state.get(key, "")
		if not stable is String or (not stable.is_empty() and not SectorIds.valid(stable)):
			return false
	if not state.get("role") is String or state["role"].is_empty() or state["role"].length() > MAX_ROLE_LENGTH:
		return false
	if str(state.get("region_profile", "")) not in ["low", "high"]:
		return false
	var job: Variant = state.get("world_job")
	if not job is Dictionary or (not job.is_empty() and not WorldJob.valid(job)):
		return false
	if not _valid_travel(state.get("travel")) or not _valid_combat(state.get("combat")):
		return false
	return true


static func valid_projection(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 23 or int(state.get("version", -1)) != VERSION:
		return false
	for key in ["instance_id", "definition_id", "entity_kind", "sector_id"]:
		if not state.get(key) is String or not SectorIds.valid(state[key]):
			return false
	if not state.get("faction_id") is String or (not state["faction_id"].is_empty() and not SectorIds.valid(state["faction_id"])):
		return false
	if not state.get("fleet_id") is String or (not state["fleet_id"].is_empty() and not SectorIds.valid(state["fleet_id"])):
		return false
	if not state.get("role") is String or state["role"].is_empty() or state["role"].length() > MAX_ROLE_LENGTH:
		return false
	if not _vector(state.get("position")) or not _finite(state.get("hull_ratio")) or float(state["hull_ratio"]) < 0.0 or float(state["hull_ratio"]) > 1.0:
		return false
	if not state.get("alive") is bool:
		return false
	for key in ["cargo_summary", "cooldowns"]:
		if not state.get(key) is Dictionary:
			return false
	var job: Variant = state.get("world_job")
	if not job is Dictionary or (not job.is_empty() and not WorldJob.valid(job)):
		return false
	if not _valid_travel(state.get("travel")) or not _valid_combat(state.get("combat")):
		return false
	if str(state.get("lod", "")) not in SimulationLOD.VALUES or str(state.get("region_profile", "")) not in ["low", "high"]:
		return false
	for key in ["residency_ticks", "last_simulation_tick", "next_due_tick", "rng_event_sequence", "rng_version"]:
		if not _integer(state.get(key)) or int(state[key]) < 0:
			return false
	return int(state["rng_version"]) == RNG_VERSION


static func _valid_travel(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var travel: Dictionary = value
	if travel.size() != 5:
		return false
	var destination: Variant = travel.get("destination_id", "")
	if not destination is String or (not destination.is_empty() and not SectorIds.valid(destination)):
		return false
	var route: Variant = travel.get("route")
	if not route is Array or route.size() > MAX_ROUTE_SECTORS:
		return false
	for sector_id in route:
		if not sector_id is String or not SectorIds.valid(sector_id):
			return false
	if not _integer(travel.get("route_index")) or int(travel["route_index"]) < 0 or int(travel["route_index"]) > maxi(0, route.size() - 1):
		return false
	if not _finite(travel.get("segment_progress")) or float(travel["segment_progress"]) < 0.0 or float(travel["segment_progress"]) > 1.0:
		return false
	return _finite(travel.get("speed_per_tick")) and float(travel["speed_per_tick"]) > 0.0 and float(travel["speed_per_tick"]) <= 1.0


static func _valid_combat(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3:
		return false
	var combat: Dictionary = value
	if str(combat.get("status", "")) not in ["idle", "engaged", "retreat", "disabled", "sunk"]:
		return false
	if not _finite(combat.get("strength")) or float(combat["strength"]) < 0.0 or float(combat["strength"]) > 1000000.0:
		return false
	return combat.get("hostile") is bool


static func _base_record_shape(record: Dictionary) -> bool:
	for key in ["instance_id", "definition_id", "entity_kind", "sector_id"]:
		if not record.get(key) is String or not SectorIds.valid(record[key]):
			return false
	if not _vector(record.get("position")) or not _finite(record.get("health")) or not record.get("alive") is bool:
		return false
	for key in ["motion", "route", "cooldowns", "inventory", "payload"]:
		if not record.get(key) is Dictionary:
			return false
	return true


static func _vector(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and _finite(value.get("x")) and _finite(value.get("y"))


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 1.0e9


static func _integer(value: Variant) -> bool:
	return _finite(value) and float(value) == floorf(float(value))
