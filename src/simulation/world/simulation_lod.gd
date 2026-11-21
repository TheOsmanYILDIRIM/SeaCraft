class_name SimulationLOD
extends RefCounted

const NEAR := "near"
const MID := "mid"
const FAR := "far"
const VALUES := [NEAR, MID, FAR]

const MIN_RESIDENCY_TICKS := 12
const NEAR_ENTER_RELEVANCE := 55.0
const NEAR_EXIT_RELEVANCE := 42.0
const NEAR_ENTER_SCORE := 82.0
const NEAR_EXIT_SCORE := 68.0
const MID_ENTER_RELEVANCE := 24.0
const MID_EXIT_RELEVANCE := 16.0
const MID_IMPORTANCE := 48.0
const MID_EXIT_DISTANCE := 1


static func classify(context: Dictionary, current_lod: String = "") -> String:
	if not valid_context(context) or (not current_lod.is_empty() and current_lod not in VALUES):
		return ""
	var graph_distance := int(context["graph_distance"])
	var relevance := float(context["explicit_relevance"])
	var importance := float(context["importance"])
	var same_sector := bool(context["same_sector"])
	var neighbor_sector := bool(context["neighbor_sector"])
	var combat := bool(context["combat_involvement"])
	var score := relevance + importance * 0.5
	if combat:
		return NEAR
	if current_lod == NEAR:
		if same_sector and relevance >= NEAR_EXIT_RELEVANCE:
			return NEAR
		if graph_distance <= 1 and score >= NEAR_EXIT_SCORE:
			return NEAR
	if same_sector and relevance >= NEAR_ENTER_RELEVANCE:
		return NEAR
	if graph_distance <= 1 and score >= NEAR_ENTER_SCORE:
		return NEAR
	if current_lod == MID:
		if graph_distance <= MID_EXIT_DISTANCE or relevance >= MID_EXIT_RELEVANCE or importance >= MID_IMPORTANCE:
			return MID
	if graph_distance <= 1 or neighbor_sector or relevance >= MID_ENTER_RELEVANCE or importance >= MID_IMPORTANCE:
		return MID
	return FAR


static func transition(current_lod: String, desired_lod: String, residency_ticks: int,
		minimum_residency_ticks: int = MIN_RESIDENCY_TICKS) -> String:
	if current_lod not in VALUES or desired_lod not in VALUES or residency_ticks < 0 or minimum_residency_ticks < 0:
		return ""
	if current_lod == desired_lod:
		return current_lod
	return current_lod if residency_ticks < minimum_residency_ticks else desired_lod


static func valid_context(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var context: Dictionary = value
	for key in ["active_sector", "entity_sector"]:
		if not context.get(key) is String or not SectorIds.valid(context[key]):
			return false
	if not _integer(context.get("graph_distance")) or int(context["graph_distance"]) < 0 or int(context["graph_distance"]) > 64:
		return false
	for key in ["same_sector", "neighbor_sector", "combat_involvement"]:
		if not context.get(key) is bool:
			return false
	for key in ["explicit_relevance", "importance"]:
		if not _finite(context.get(key)) or float(context[key]) < 0.0 or float(context[key]) > 100.0:
			return false
	if bool(context["same_sector"]) != (context["active_sector"] == context["entity_sector"]):
		return false
	if bool(context["same_sector"]) and bool(context["neighbor_sector"]):
		return false
	return true


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))


static func _integer(value: Variant) -> bool:
	return _finite(value) and float(value) == floorf(float(value))
