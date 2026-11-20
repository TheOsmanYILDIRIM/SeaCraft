class_name ShipDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var visual_profile_id: String = ""
@export var faction_id: String = ""
@export var weapon_ids: PackedStringArray = PackedStringArray()
@export var base_hull_hp: float = 100.0


func definition_type() -> String:
	return "ship"


func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	if not faction_id.is_empty():
		refs.append(faction_id)
	for weapon_id in weapon_ids:
		if not weapon_id.is_empty():
			refs.append(weapon_id)
	return refs
