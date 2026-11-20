class_name InputCommandMapper
extends RefCounted

const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")


static func map_world_pointer(
	pointer_source: String,
	world_position: Vector2,
	ui_consumed: bool = false,
	selection: bool = false
) -> Dictionary:
	if ui_consumed:
		return {}
	if pointer_source != "mouse" and pointer_source != "touch":
		return {}
	if selection:
		return COMMANDS.select_world_position(world_position)
	return COMMANDS.move_to_world_position(world_position)


static func map_cancel(ui_consumed: bool = false) -> Dictionary:
	if ui_consumed:
		return {}
	return COMMANDS.cancel()


static func map_target_cycle(direction: int, ui_consumed: bool = false) -> Dictionary:
	if ui_consumed or direction == 0:
		return {}
	return COMMANDS.target_cycle(1 if direction > 0 else -1)


static func map_camera_pan(world_delta: Vector2, ui_consumed: bool = false) -> Dictionary:
	if ui_consumed:
		return {}
	return COMMANDS.camera_pan(world_delta)


static func map_camera_zoom(factor: float, ui_consumed: bool = false) -> Dictionary:
	if ui_consumed or factor <= 0.0:
		return {}
	return COMMANDS.camera_zoom(factor)


static func map_camera_recenter(ui_consumed: bool = false) -> Dictionary:
	if ui_consumed:
		return {}
	return COMMANDS.camera_recenter()
