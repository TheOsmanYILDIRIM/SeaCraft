class_name HarpoonProfile
extends BaseDefinition

@export var display_name: String = ""
@export var base_damage: float = 1.0
@export var range_meters: float = 120.0
@export var reload_seconds: float = 1.0
@export var element_id: String = CoreCombatRules.NEUTRAL
@export var target_classes: PackedStringArray = PackedStringArray([TargetingService.MONSTER, TargetingService.WRECK])
@export var item_id: String = ""


func definition_type() -> String:
	return "harpoon"


func valid() -> bool:
	if not SectorIds.valid(stable_id) or display_name.is_empty():
		return false
	if not CoreCombatRules.bounded(base_damage, 0.0, CoreCombatRules.MAX_VALUE / 16.0):
		return false
	if not CoreCombatRules.bounded(range_meters, 0.000001, SectorSpatialHash.MAX_RADIUS):
		return false
	if not CoreCombatRules.bounded(reload_seconds, 0.000001, 3600.0):
		return false
	if not CoreCombatRules.element_valid(element_id) or (not item_id.is_empty() and not SectorIds.valid(item_id)):
		return false
	if target_classes.is_empty() or target_classes.size() > 4:
		return false
	var seen: Dictionary = {}
	for target_class in target_classes:
		if not TargetingService.target_class_valid(target_class) or TargetingService.weapon_rejection(TargetingService.HARPOON, target_class) != "" or seen.has(target_class):
			return false
		seen[target_class] = true
	return true


func accepts(target_class: String) -> bool:
	return valid() and target_classes.has(target_class)
