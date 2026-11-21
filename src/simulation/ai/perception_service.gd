class_name PerceptionService
extends RefCounted

var query_count: int = 0
var last_inspected_count: int = 0
var last_candidate_count: int = 0

var _raw_candidates: Array[String] = []


func capture(observer_id: String, simulation_tick: int, sector: SectorRuntime, combat: CombatAuthority,
		radius: float, candidate_cap: int, role_profile: NpcRoleProfile) -> Dictionary:
	if sector == null or combat == null or role_profile == null or not role_profile.valid():
		return {}
	if not SectorIds.valid(observer_id) or simulation_tick < 0 or not is_finite(radius) or radius <= 0.0:
		return {}
	if radius > SectorSpatialHash.MAX_RADIUS or candidate_cap <= 0 or candidate_cap > SenseSnapshot.MAX_CANDIDATES:
		return {}
	var observer_position := sector.entity_position(observer_id)
	if not observer_position.is_finite() or not combat.has_combatant(observer_id):
		return {}
	query_count += 1
	last_inspected_count = sector.spatial.query_radius(observer_position, radius, _raw_candidates)
	var filtered: Array[Dictionary] = []
	for candidate_id in _raw_candidates:
		if candidate_id == observer_id or not combat.has_combatant(candidate_id):
			continue
		if not combat.is_alive(candidate_id) or not combat.hostile(observer_id, candidate_id):
			continue
		var target := combat.target_snapshot(candidate_id)
		if target.is_empty() or not bool(target.get("selectable", false)):
			continue
		var target_class := str(target.get("target_class", ""))
		if not role_profile.accepts_target_class(target_class):
			continue
		var target_position := sector.entity_position(candidate_id)
		if not target_position.is_finite():
			continue
		var distance := observer_position.distance_to(target_position)
		if not is_finite(distance) or distance > radius:
			continue
		filtered.append({
			"stable_id": candidate_id,
			"faction_id": combat.faction_id(candidate_id),
			"relation": SenseSnapshot.RELATION_HOSTILE,
			"target_class": target_class,
			"position": {"x": target_position.x, "y": target_position.y},
			"distance": distance,
			"alive": true,
			"selectable": true,
			"visible": true,
			"threat_facts": {"hostile": true},
		})
	filtered.sort_custom(_candidate_before)
	if filtered.size() > candidate_cap:
		filtered.resize(candidate_cap)
	last_candidate_count = filtered.size()
	return SenseSnapshot.build(
		observer_id,
		simulation_tick,
		sector.sector_id,
		observer_position,
		combat.hull_ratio(observer_id),
		filtered,
		last_inspected_count
	)


static func _candidate_before(left: Dictionary, right: Dictionary) -> bool:
	var left_distance := float(left["distance"])
	var right_distance := float(right["distance"])
	if not is_equal_approx(left_distance, right_distance):
		return left_distance < right_distance
	return str(left["stable_id"]) < str(right["stable_id"])
