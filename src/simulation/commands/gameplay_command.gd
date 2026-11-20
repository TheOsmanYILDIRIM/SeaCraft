class_name GameplayCommand
extends RefCounted

const DOMAIN_GAMEPLAY := "gameplay"
const DOMAIN_PRESENTATION := "presentation"

const MOVE_TO_WORLD_POSITION := "move_to_world_position"
const SELECT_WORLD_POSITION := "select_world_position"
const CANCEL := "cancel"
const CAMERA_PAN := "camera_pan"
const CAMERA_ZOOM := "camera_zoom"
const CAMERA_RECENTER := "camera_recenter"
const TARGET_CYCLE := "target_cycle"


static func move_to_world_position(world_position: Vector2) -> Dictionary:
	return _world_position_command(MOVE_TO_WORLD_POSITION, world_position)


static func select_world_position(world_position: Vector2) -> Dictionary:
	return _world_position_command(SELECT_WORLD_POSITION, world_position)


static func cancel() -> Dictionary:
	return {
		"domain": DOMAIN_GAMEPLAY,
		"type": CANCEL,
	}


static func camera_pan(world_delta: Vector2) -> Dictionary:
	return {
		"domain": DOMAIN_PRESENTATION,
		"type": CAMERA_PAN,
		"delta_x": float(world_delta.x),
		"delta_y": float(world_delta.y),
	}


static func camera_zoom(factor: float) -> Dictionary:
	return {
		"domain": DOMAIN_PRESENTATION,
		"type": CAMERA_ZOOM,
		"factor": factor,
	}


static func camera_recenter() -> Dictionary:
	return {
		"domain": DOMAIN_PRESENTATION,
		"type": CAMERA_RECENTER,
	}


static func target_cycle(direction: int) -> Dictionary:
	return {
		"domain": DOMAIN_GAMEPLAY,
		"type": TARGET_CYCLE,
		"direction": direction,
	}


static func _world_position_command(command_type: String, world_position: Vector2) -> Dictionary:
	return {
		"domain": DOMAIN_GAMEPLAY,
		"type": command_type,
		"world_x": float(world_position.x),
		"world_y": float(world_position.y),
	}
