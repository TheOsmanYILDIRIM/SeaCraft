class_name SectorDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var controlling_faction_id: String = ""


func definition_type() -> String:
	return "sector"


func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	if not controlling_faction_id.is_empty():
		refs.append(controlling_faction_id)
	return refs
