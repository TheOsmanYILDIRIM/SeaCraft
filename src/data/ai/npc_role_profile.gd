class_name NpcRoleProfile
extends BaseDefinition

@export var patrol_travel_weight: float = 1.0
@export var avoid_threat_weight: float = 1.0
@export var investigate_protect_weight: float = 1.0
@export var pursue_aggression_weight: float = 1.0
@export var repair_safety_weight: float = 1.0
@export var switch_threshold: float = 0.12
@export var hold_bonus: float = 0.08
@export var minimum_decision_hold_ticks: int = 20
@export var tactical_fight_weight: float = 1.0
@export var tactical_retreat_weight: float = 1.0
@export var ammo_conservation_weight: float = 1.0
@export var tactical_boarding_weight: float = 1.0
@export var tactical_support_weight: float = 1.0
@export var interested_target_classes: PackedStringArray = PackedStringArray(["ship", "monster"])


func definition_type() -> String:
	return "ai_role"


func valid() -> bool:
	if not SectorIds.valid(stable_id):
		return false
	for value in [
		patrol_travel_weight,
		avoid_threat_weight,
		investigate_protect_weight,
		pursue_aggression_weight,
		repair_safety_weight,
		switch_threshold,
		hold_bonus,
		tactical_fight_weight,
		tactical_retreat_weight,
		ammo_conservation_weight,
		tactical_boarding_weight,
		tactical_support_weight,
	]:
		if not is_finite(value) or value < 0.0 or value > 100.0:
			return false
	if minimum_decision_hold_ticks < 0 or minimum_decision_hold_ticks > CoreCombatRules.MAX_DURATION:
		return false
	if interested_target_classes.is_empty() or interested_target_classes.size() > TargetingService.TARGET_CLASSES.size():
		return false
	var seen: Dictionary = {}
	for target_class in interested_target_classes:
		if not TargetingService.target_class_valid(target_class) or seen.has(target_class):
			return false
		seen[target_class] = true
	return true


func accepts_target_class(target_class: String) -> bool:
	return valid() and interested_target_classes.has(target_class)


func data_snapshot() -> Dictionary:
	if not valid():
		return {}
	var classes: Array = []
	for target_class in interested_target_classes:
		classes.append(target_class)
	classes.sort()
	return {
		"stable_id": stable_id,
		"patrol_travel": patrol_travel_weight,
		"avoid_threat": avoid_threat_weight,
		"investigate_protect": investigate_protect_weight,
		"pursue_aggression": pursue_aggression_weight,
		"repair_safety": repair_safety_weight,
		"switch_threshold": switch_threshold,
		"hold_bonus": hold_bonus,
		"minimum_decision_hold_ticks": minimum_decision_hold_ticks,
		"tactical_fight": tactical_fight_weight,
		"tactical_retreat": tactical_retreat_weight,
		"ammo_conservation": ammo_conservation_weight,
		"tactical_boarding": tactical_boarding_weight,
		"tactical_support": tactical_support_weight,
		"interested_target_classes": classes,
	}
