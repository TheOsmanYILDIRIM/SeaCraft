class_name ItemDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var item_category: String = ""
@export var stack_limit: int = 1


func definition_type() -> String:
	return "item"
