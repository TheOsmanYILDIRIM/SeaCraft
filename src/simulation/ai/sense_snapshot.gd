class_name SenseSnapshot
extends RefCounted

const RELATION_HOSTILE := "hostile"
const MAX_CANDIDATES := 64


static func build(observer_id: String, simulation_tick: int, sector_id: String, observer_position: Vector2,
		observer_hull_ratio: float, candidates: Array[Dictionary], inspected_count: int) -> Dictionary:
	if not SectorIds.valid(observer_id) or simulation_tick < 0 or not SectorIds.valid(sector_id):
		return {}
	if not observer_position.is_finite() or not is_finite(observer_hull_ratio) or observer_hull_ratio < 0.0 or observer_hull_ratio > 1.0:
		return {}
	if inspected_count < 0 or candidates.size() > MAX_CANDIDATES:
		return {}
	var copied: Array = []
	for candidate in candidates:
		if not _candidate_valid(candidate):
			return {}
		copied.append(candidate.duplicate(true))
	return {
		"observer_stable_id": observer_id,
		"simulation_tick": simulation_tick,
		"sector_id": sector_id,
		"observer_position": {"x": observer_position.x, "y": observer_position.y},
		"observer_hull_ratio": observer_hull_ratio,
		"candidate_count": copied.size(),
		"inspected_count": inspected_count,
		"candidates": copied,
	}


static func _candidate_valid(candidate: Dictionary) -> bool:
	if candidate.size() != 10:
		return false
	var stable_id: Variant = candidate.get("stable_id")
	var faction_id: Variant = candidate.get("faction_id")
	var relation: Variant = candidate.get("relation")
	var target_class: Variant = candidate.get("target_class")
	var position: Variant = candidate.get("position")
	if not stable_id is String or not SectorIds.valid(stable_id):
		return false
	if not faction_id is String or not SectorIds.valid(faction_id):
		return false
	if relation != RELATION_HOSTILE:
		return false
	if not target_class is String or not TargetingService.target_class_valid(target_class):
		return false
	if not position is Dictionary or position.size() != 2:
		return false
	if not _finite(position.get("x")) or not _finite(position.get("y")):
		return false
	if not _finite(candidate.get("distance")) or float(candidate["distance"]) < 0.0:
		return false
	for flag in ["alive", "selectable", "visible"]:
		if not candidate.get(flag) is bool:
			return false
	var facts: Variant = candidate.get("threat_facts")
	return facts is Dictionary and facts.size() == 1 and facts.get("hostile") is bool and bool(facts["hostile"])


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
