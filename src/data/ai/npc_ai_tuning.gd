class_name NpcAiTuning
extends Resource

@export var decision_interval_ticks: int = 10
@export var perception_radius: float = 280.0
@export var perception_candidate_cap: int = 16
@export var perception_query_cadence_ticks: int = 10
@export var memory_max_entries: int = 8
@export var memory_expiry_ticks: int = 300
@export var bt_timeout_ticks: int = 90
@export var max_threat: int = 1000
@export var threat_per_damage: float = 20.0
@export var threat_decay_interval_ticks: int = 30
@export var threat_decay_amount: int = 50
@export var retreat_enter_hull_ratio: float = 0.35
@export var retreat_exit_hull_ratio: float = 0.55
@export var retreat_threat_min: int = 120
@export var alert_threat_min: int = 1
@export var repair_entry_threat_max: int = 1000
@export var repair_interrupt_threat: int = 120
@export var repair_interval_ticks: int = 30
@export var repair_amount: float = 8.0
@export var resume_hull_ratio: float = 0.70
@export var resume_threat_max: int = 50
@export var safe_distance: float = 180.0
@export var arrival_radius: float = 24.0
@export var retreat_fallback_distance: float = 160.0
@export var patrol_waypoint_ids: PackedStringArray = PackedStringArray()
@export var patrol_waypoints: PackedVector2Array = PackedVector2Array()
@export var safe_point_ids: PackedStringArray = PackedStringArray()
@export var safe_points: PackedVector2Array = PackedVector2Array()
@export var max_tactical_targets: int = 4
@export var max_ammo_candidates: int = 8
@export var max_escape_candidates: int = 4
@export var max_line_of_fire_inspected: int = 24
@export var preferred_min_ratio: float = 0.45
@export var preferred_max_ratio: float = 0.82
@export var range_hysteresis_ratio: float = 0.06
@export var ammo_reserve_stock: int = 5
@export var ammo_scarcity_penalty: float = 0.55
@export var ammo_switch_penalty: float = 0.15
@export var retreat_score_threshold: float = 0.58
@export var repair_score_threshold: float = 0.55
@export var boarding_score_threshold: float = 0.70
@export var support_score_threshold: float = 0.62
@export var support_cooldown_ticks: int = 300
@export var tactical_steering_distance: float = 96.0


func valid() -> bool:
	if decision_interval_ticks < 6 or decision_interval_ticks > 15:
		return false
	if not _positive_finite(perception_radius) or perception_radius > SectorSpatialHash.MAX_RADIUS:
		return false
	if perception_candidate_cap <= 0 or perception_candidate_cap > SenseSnapshot.MAX_CANDIDATES:
		return false
	if perception_query_cadence_ticks <= 0 or perception_query_cadence_ticks > decision_interval_ticks:
		return false
	if memory_max_entries <= 0 or memory_max_entries > MemoryBlackboard.MAX_ENTRIES_LIMIT:
		return false
	if memory_expiry_ticks <= 0 or memory_expiry_ticks > CoreCombatRules.MAX_CLOCK:
		return false
	if bt_timeout_ticks <= 0 or bt_timeout_ticks > CoreCombatRules.MAX_DURATION:
		return false
	if max_threat <= 0 or max_threat > 100000 or not _positive_finite(threat_per_damage):
		return false
	if threat_decay_interval_ticks <= 0 or threat_decay_amount <= 0 or threat_decay_amount > max_threat:
		return false
	if not _ratio(retreat_enter_hull_ratio) or not _ratio(retreat_exit_hull_ratio) or retreat_enter_hull_ratio >= retreat_exit_hull_ratio:
		return false
	if retreat_threat_min < 0 or retreat_threat_min > max_threat or alert_threat_min < 0 or alert_threat_min > max_threat:
		return false
	if repair_entry_threat_max < 0 or repair_entry_threat_max > max_threat or repair_interrupt_threat < 0 or repair_interrupt_threat > max_threat:
		return false
	if repair_interval_ticks <= 0 or not _positive_finite(repair_amount):
		return false
	if not _ratio(resume_hull_ratio) or resume_hull_ratio < retreat_exit_hull_ratio or resume_threat_max < 0 or resume_threat_max > max_threat:
		return false
	if not _positive_finite(safe_distance) or not _positive_finite(arrival_radius) or not _positive_finite(retreat_fallback_distance):
		return false
	if max_tactical_targets <= 0 or max_tactical_targets > SenseSnapshot.MAX_CANDIDATES:
		return false
	if max_ammo_candidates <= 0 or max_ammo_candidates > 16 or max_escape_candidates <= 0 or max_escape_candidates > 8:
		return false
	if max_line_of_fire_inspected <= 0 or max_line_of_fire_inspected > 64:
		return false
	if not _ratio(preferred_min_ratio) or not _ratio(preferred_max_ratio) or preferred_min_ratio >= preferred_max_ratio:
		return false
	if not _ratio(range_hysteresis_ratio) or range_hysteresis_ratio >= preferred_max_ratio - preferred_min_ratio:
		return false
	if ammo_reserve_stock <= 0 or ammo_reserve_stock > 100000:
		return false
	for value in [ammo_scarcity_penalty, ammo_switch_penalty, retreat_score_threshold, repair_score_threshold, boarding_score_threshold, support_score_threshold]:
		if not is_finite(value) or value < 0.0 or value > 4.0:
			return false
	if support_cooldown_ticks <= 0 or support_cooldown_ticks > CoreCombatRules.MAX_DURATION:
		return false
	if not _positive_finite(tactical_steering_distance) or tactical_steering_distance > SectorSpatialHash.MAX_RADIUS:
		return false
	if patrol_waypoint_ids.size() < 3 or patrol_waypoint_ids.size() > 5 or patrol_waypoint_ids.size() != patrol_waypoints.size():
		return false
	if safe_point_ids.is_empty() or safe_point_ids.size() > 8 or safe_point_ids.size() != safe_points.size():
		return false
	for i in patrol_waypoint_ids.size():
		if not SectorIds.valid(patrol_waypoint_ids[i]) or not patrol_waypoints[i].is_finite():
			return false
	for i in safe_point_ids.size():
		if not SectorIds.valid(safe_point_ids[i]) or not safe_points[i].is_finite():
			return false
	return true


static func _ratio(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0


static func _positive_finite(value: float) -> bool:
	return is_finite(value) and value > 0.0
