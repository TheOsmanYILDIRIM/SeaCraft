class_name WeaponDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var base_damage: float = 1.0
@export var range_meters: float = 1.0


func definition_type() -> String:
	return "weapon"
