class_name BaseDefinition
extends Resource

@export var stable_id: String = ""


func definition_type() -> String:
	return "base"


func referenced_stable_ids() -> PackedStringArray:
	return PackedStringArray()
