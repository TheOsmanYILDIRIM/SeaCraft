class_name FarTravelResolver
extends RefCounted

const VERSION := 1
const MAX_ROUTE_SECTORS := 32
const MAX_SEGMENTS_PER_UPDATE := 32
const MAX_HAZARD_EVENTS_PER_UPDATE := 8


static func plan_route(graph_snapshot: Dictionary, start_sector: String, destination_sector: String,
		hazard_facts: Dictionary = {}) -> Array:
	if not SectorIds.valid(start_sector) or not SectorIds.valid(destination_sector):
		return []
	var sectors: Variant = graph_snapshot.get("sectors")
	var connections: Variant = graph_snapshot.get("connections")
	if not sectors is Array or not connections is Array or sectors.size() > 64 or connections.size() > 256:
		return []
	var known: Dictionary = {}
	var hazard_by_sector: Dictionary = {}
	for raw in sectors:
		if not raw is Dictionary:
			return []
		var sector_id := str(raw.get("sector_id", ""))
		var tag := str(raw.get("hazard_tag", ""))
		if not SectorIds.valid(sector_id) or known.has(sector_id):
			return []
		known[sector_id] = true
		hazard_by_sector[sector_id] = tag
	if not known.has(start_sector) or not known.has(destination_sector):
		return []
	if start_sector == destination_sector:
		return [start_sector]
	var outgoing: Dictionary = {}
	for sector_id in known:
		outgoing[sector_id] = []
	for raw in connections:
		if not raw is Dictionary:
			return []
		var from_sector := str(raw.get("from_sector", ""))
		var to_sector := str(raw.get("to_sector", ""))
		if not known.has(from_sector) or not known.has(to_sector):
			return []
		(outgoing[from_sector] as Array).append(to_sector)
	for sector_id in outgoing:
		(outgoing[sector_id] as Array).sort()
	var distance: Dictionary = {start_sector: 0.0}
	var previous: Dictionary = {}
	var open: Array = [start_sector]
	while not open.is_empty():
		open.sort_custom(func(a: String, b: String) -> bool:
			var ad := float(distance.get(a, INF))
			var bd := float(distance.get(b, INF))
			return a < b if is_equal_approx(ad, bd) else ad < bd)
		var current: String = open.pop_front()
		if current == destination_sector:
			break
		for neighbor in outgoing[current]:
			var cost := 1.0 + _hazard_cost(str(hazard_by_sector.get(neighbor, "")), hazard_facts)
			var candidate := float(distance[current]) + cost
			if candidate < float(distance.get(neighbor, INF)) - 0.000001:
				distance[neighbor] = candidate
				previous[neighbor] = current
				if not open.has(neighbor):
					open.append(neighbor)
			elif is_equal_approx(candidate, float(distance.get(neighbor, INF))):
				var old_previous := str(previous.get(neighbor, "~"))
				if current < old_previous:
					previous[neighbor] = current
	if not distance.has(destination_sector):
		return []
	var reversed: Array = [destination_sector]
	var cursor := destination_sector
	while cursor != start_sector:
		cursor = str(previous.get(cursor, ""))
		if cursor.is_empty() or reversed.size() >= MAX_ROUTE_SECTORS:
			return []
		reversed.append(cursor)
	reversed.reverse()
	return reversed


static func advance(state: Dictionary, graph_snapshot: Dictionary, hazard_facts: Dictionary,
		elapsed_ticks: int, master_seed: int) -> Dictionary:
	if not FarFieldEntityState.valid_projection(state) or state["lod"] != SimulationLOD.FAR or elapsed_ticks < 0:
		return {}
	var result := state.duplicate(true)
	var travel: Dictionary = (result["travel"] as Dictionary).duplicate(true)
	var destination := str(travel["destination_id"])
	var events: Array = []
	if destination.is_empty() or destination == result["sector_id"] or elapsed_ticks == 0:
		result["last_simulation_tick"] = int(result["last_simulation_tick"]) + elapsed_ticks
		return {"state": result, "arrived": destination == result["sector_id"] and not destination.is_empty(), "events": events}
	var route: Array = (travel["route"] as Array).duplicate()
	var route_index := int(travel["route_index"])
	var route_matches: bool = not route.is_empty() and route_index >= 0 and route_index < route.size() and route[route_index] == result["sector_id"] and route[route.size() - 1] == destination
	if not route_matches:
		route = plan_route(graph_snapshot, str(result["sector_id"]), destination, hazard_facts)
		if route.is_empty():
			return {}
		travel["route"] = route
		travel["route_index"] = 0
		travel["segment_progress"] = 0.0
		route_index = 0
	var budget := float(elapsed_ticks) * float(travel["speed_per_tick"])
	var segments := 0
	var hazard_events := 0
	while budget > 0.0 and route_index < route.size() - 1 and segments < MAX_SEGMENTS_PER_UPDATE:
		var next_sector := str(route[route_index + 1])
		var tag := _sector_hazard_tag(graph_snapshot, next_sector)
		var delay := _hazard_delay(tag, hazard_facts)
		var effective_budget := budget / (1.0 + delay)
		var remaining := 1.0 - float(travel["segment_progress"])
		if effective_budget + 0.000001 < remaining:
			travel["segment_progress"] = clampf(float(travel["segment_progress"]) + effective_budget, 0.0, 1.0)
			budget = 0.0
			break
		var consumed := remaining * (1.0 + delay)
		budget = maxf(0.0, budget - consumed)
		travel["segment_progress"] = 0.0
		route_index += 1
		travel["route_index"] = route_index
		result["sector_id"] = next_sector
		segments += 1
		var risk := _hazard_risk(tag, hazard_facts)
		if risk > 0.0 and hazard_events < MAX_HAZARD_EVENTS_PER_UPDATE:
			var sequence := int(result["rng_event_sequence"])
			var rng := RandomNumberGenerator.new()
			rng.seed = SeedStreams.derive_stream_seed(master_seed, "far_travel.v1.%s.%d" % [result["instance_id"], sequence])
			result["rng_event_sequence"] = sequence + 1
			if rng.randf() < risk:
				events.append({"type": "hazard_delay", "entity_id": result["instance_id"], "sector_id": next_sector, "sequence": sequence})
				hazard_events += 1
	var arrived := route_index == route.size() - 1
	if arrived:
		travel["segment_progress"] = 1.0
	result["travel"] = travel
	result["last_simulation_tick"] = int(result["last_simulation_tick"]) + elapsed_ticks
	return {"state": result, "arrived": arrived, "events": events}


static func _sector_hazard_tag(graph_snapshot: Dictionary, sector_id: String) -> String:
	for raw in graph_snapshot.get("sectors", []):
		if raw is Dictionary and raw.get("sector_id") == sector_id:
			return str(raw.get("hazard_tag", ""))
	return ""


static func _hazard_cost(tag: String, facts: Dictionary) -> float:
	var row: Variant = facts.get(tag, {})
	if not row is Dictionary:
		return 0.0
	var value: Variant = row.get("cost", 0.0)
	return clampf(float(value), 0.0, 100.0) if _finite(value) else 0.0


static func _hazard_delay(tag: String, facts: Dictionary) -> float:
	var row: Variant = facts.get(tag, {})
	if not row is Dictionary:
		return 0.0
	var value: Variant = row.get("delay", 0.0)
	return clampf(float(value), 0.0, 10.0) if _finite(value) else 0.0


static func _hazard_risk(tag: String, facts: Dictionary) -> float:
	var row: Variant = facts.get(tag, {})
	if not row is Dictionary:
		return 0.0
	var value: Variant = row.get("risk", 0.0)
	return clampf(float(value), 0.0, 1.0) if _finite(value) else 0.0


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
