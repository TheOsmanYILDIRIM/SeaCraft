class_name EntityRuntimeState
extends RefCounted

var instance_id: String = ""
var definition_id: String = ""
var sector_id: String = ""
var current_hp: float = 0.0
var position_x: float = 0.0
var position_y: float = 0.0
var inventory: Dictionary = {}


func _init(
	p_instance_id: String = "",
	p_definition_id: String = "",
	p_sector_id: String = ""
) -> void:
	instance_id = p_instance_id
	definition_id = p_definition_id
	sector_id = p_sector_id


func to_dto() -> Dictionary:
	return {
		"instance_id": instance_id,
		"definition_id": definition_id,
		"sector_id": sector_id,
		"current_hp": current_hp,
		"position_x": position_x,
		"position_y": position_y,
		"inventory": inventory.duplicate(true),
	}
