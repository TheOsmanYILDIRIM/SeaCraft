class_name MonsterDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var max_health: float = 1.0
@export var faction_id: String = "faction.monster"
@export var target_class: String = "monster"
@export var elemental_resistances: Dictionary = {}
@export var loot_table_id: String = ""
@export var territory_radius: float = 128.0


func definition_type() -> String:
	return "monster"


func valid() -> bool:
	return (SectorIds.valid(stable_id)
		and not display_name.is_empty()
		and CoreCombatRules.bounded(max_health, 0.000001, CoreCombatRules.MAX_VALUE)
		and SectorIds.valid(faction_id)
		and target_class == TargetingService.MONSTER
		and CoreCombatRules.valid_resistances(elemental_resistances)
		and SectorIds.valid(loot_table_id)
		and CoreCombatRules.bounded(territory_radius, 1.0, SectorSpatialHash.MAX_RADIUS))


func referenced_stable_ids() -> PackedStringArray:
	return PackedStringArray([faction_id, loot_table_id])
