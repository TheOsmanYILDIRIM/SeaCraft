class_name WeaponDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var base_damage: float = 1.0
@export var range_meters: float = 1.0
@export var min_range_meters: float = 0.0
@export var reload_seconds: float = 1.0
@export var accuracy: float = 1.0
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 1.5
@export var broadside_half_arc_degrees: float = 35.0
@export var defense_penetration: float = 0.0


func definition_type() -> String:
	return "weapon"
