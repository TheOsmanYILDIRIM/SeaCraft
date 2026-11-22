class_name ItemDefinition
extends BaseDefinition

const VALID_CATEGORIES := ["salvage", "material", "consumable", "ammo", "weapon", "structure", "sail", "figurehead", "crew", "trainer", "pet", "companion", "ship_gem", "pet_gem"]
const VALID_SLOTS := ["", "weapon", "structure", "sail", "figurehead", "crew", "trainer", "pet"]

@export var display_name: String = ""
@export var item_category: String = ""
@export var stack_limit: int = 1
@export var equip_slot: String = ""
@export var weight: float = 0.0
@export var stat_modifiers: Array[Dictionary] = []

func definition_type() -> String:
	return "item"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or display_name.is_empty() or item_category not in VALID_CATEGORIES:
		return false
	if stack_limit <= 0 or stack_limit > 2147483647 or equip_slot not in VALID_SLOTS or not is_finite(weight) or weight < 0.0:
		return false
	if not equip_slot.is_empty():
		var normalized := "pet" if item_category == "companion" else item_category
		if normalized != equip_slot:
			return false
	for modifier in stat_modifiers:
		if modifier.size() < 3 or not modifier.get("stat") is String or str(modifier["stat"]).is_empty():
			return false
		if modifier.get("operation") not in StatModifierPipeline.PHASE_ORDER:
			return false
		if typeof(modifier.get("value")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(modifier["value"])):
			return false
	return true
