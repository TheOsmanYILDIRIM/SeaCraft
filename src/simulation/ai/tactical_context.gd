class_name TacticalContext
extends RefCounted

const VERSION := 1


static func capture(actor_id: String, simulation_tick: int, sector: SectorRuntime, combat: CombatAuthority,
		heading: float, movement_speed: float, current_state: int, high_level_intent: int,
		sense_snapshot: Dictionary, memory_snapshot: Dictionary, tuning: NpcAiTuning,
		role_profile: NpcRoleProfile, previous_state: Dictionary) -> Dictionary:
	if not SectorIds.valid(actor_id) or simulation_tick < 0 or sector == null or combat == null:
		return {}
	if tuning == null or not tuning.valid() or role_profile == null or not role_profile.valid():
		return {}
	if not is_finite(heading) or not is_finite(movement_speed) or movement_speed < 0.0:
		return {}
	if not DtoContract.is_primitive_safe(sense_snapshot) or not DtoContract.is_primitive_safe(memory_snapshot):
		return {}
	var candidate_ids: Array[String] = []
	for raw in sense_snapshot.get("candidates", []):
		if candidate_ids.size() >= tuning.max_tactical_targets:
			break
		if not raw is Dictionary:
			continue
		var id := str(raw.get("stable_id", ""))
		if SectorIds.valid(id) and not candidate_ids.has(id):
			candidate_ids.append(id)
	var authority := combat.tactical_snapshot(
		actor_id,
		candidate_ids,
		heading,
		tuning.perception_radius,
		tuning.max_tactical_targets,
		tuning.max_ammo_candidates,
		tuning.max_line_of_fire_inspected
	)
	if authority.is_empty() or not DtoContract.is_primitive_safe(authority):
		return {}
	var memory_by_id: Dictionary = {}
	for raw in memory_snapshot.get("entries", []):
		if raw is Dictionary:
			var id := str(raw.get("stable_id", ""))
			if SectorIds.valid(id):
				memory_by_id[id] = {
					"threat": int(raw.get("threat", 0)),
					"last_seen_tick": int(raw.get("last_seen_tick", 0)),
				}
	var targets: Array = []
	for raw in authority.get("targets", []):
		if not raw is Dictionary:
			continue
		var entry: Dictionary = raw.duplicate(true)
		var id := str(entry.get("entity_id", ""))
		var memory: Dictionary = memory_by_id.get(id, {})
		entry["threat"] = int(memory.get("threat", 0))
		entry["threat_ratio"] = clampf(float(entry["threat"]) / maxf(1.0, float(tuning.max_threat)), 0.0, 1.0)
		targets.append(entry)
	var escapes: Array = []
	var limit := mini(tuning.max_escape_candidates, tuning.safe_points.size())
	var actor_position := sector.entity_position(actor_id)
	for index in limit:
		var point := tuning.safe_points[index]
		if not point.is_finite() or not sector.navigation.accessible(point):
			continue
		var route := sector.navigation.path(actor_position, point)
		if route.size() < 2:
			continue
		var geometric := 0.0
		for route_index in range(1, route.size()):
			geometric += route[route_index - 1].distance_to(route[route_index])
		var weighted := sector.navigation.route_cost(route)
		if not is_finite(weighted):
			continue
		var enemy_clearance := tuning.perception_radius
		for target in targets:
			var target_position := Vector2(float(target["x"]), float(target["y"]))
			enemy_clearance = minf(enemy_clearance, point.distance_to(target_position))
		escapes.append({
			"escape_id": tuning.safe_point_ids[index],
			"x": point.x,
			"y": point.y,
			"geometric_distance": geometric,
			"weighted_path_cost": weighted,
			"hazard_cost": maxf(0.0, weighted - geometric),
			"enemy_clearance": enemy_clearance,
			"safe_zone": not sector.safe_zone_at(point).is_empty(),
		})
	var actor: Dictionary = authority.get("actor", {}).duplicate(true)
	actor["heading"] = heading
	actor["movement_speed"] = movement_speed
	actor["current_state"] = current_state
	actor["high_level_intent"] = high_level_intent
	var role := role_profile.data_snapshot()
	var previous := previous_state.duplicate(true) if DtoContract.is_primitive_safe(previous_state) else {}
	var result := {
		"version": VERSION,
		"simulation_tick": simulation_tick,
		"sector_id": sector.sector_id,
		"actor": actor,
		"targets": targets,
		"nearby_hostile_count": int(authority.get("nearby_hostile_count", targets.size())),
		"nearby_ally_count": int(authority.get("nearby_ally_count", 0)),
		"escape_candidates": escapes,
		"rules": authority.get("rules", {}).duplicate(true),
		"role": role,
		"previous": previous,
		"limits": {
			"max_tactical_targets": tuning.max_tactical_targets,
			"max_ammo_candidates": tuning.max_ammo_candidates,
			"max_escape_candidates": tuning.max_escape_candidates,
			"max_line_of_fire_inspected": tuning.max_line_of_fire_inspected,
		},
		"tuning": {
			"preferred_min_ratio": tuning.preferred_min_ratio,
			"preferred_max_ratio": tuning.preferred_max_ratio,
			"range_hysteresis_ratio": tuning.range_hysteresis_ratio,
			"ammo_reserve_stock": tuning.ammo_reserve_stock,
			"ammo_scarcity_penalty": tuning.ammo_scarcity_penalty,
			"ammo_switch_penalty": tuning.ammo_switch_penalty,
			"retreat_score_threshold": tuning.retreat_score_threshold,
			"repair_score_threshold": tuning.repair_score_threshold,
			"boarding_score_threshold": tuning.boarding_score_threshold,
			"support_score_threshold": tuning.support_score_threshold,
			"support_cooldown_ticks": tuning.support_cooldown_ticks,
			"tactical_steering_distance": tuning.tactical_steering_distance,
			"arrival_radius": tuning.arrival_radius,
			"max_threat": tuning.max_threat,
		},
	}
	return result if DtoContract.is_primitive_safe(result) else {}


static func candidate_ids(context: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw in context.get("targets", []):
		if raw is Dictionary:
			var id := str(raw.get("entity_id", ""))
			if SectorIds.valid(id):
				result.append(id)
	return result
