class_name InputBindings
extends RefCounted

const ACTION_MOVE := "move_to_world_position"
const ACTION_SELECT := "select_world_position"
const ACTION_CANCEL := "cancel_deselect"
const ACTION_TARGET_NEXT := "target_cycle_next"
const ACTION_TARGET_PREVIOUS := "target_cycle_previous"
const ACTION_PAN_LEFT := "camera_pan_left"
const ACTION_PAN_RIGHT := "camera_pan_right"
const ACTION_PAN_UP := "camera_pan_up"
const ACTION_PAN_DOWN := "camera_pan_down"
const ACTION_ZOOM_IN := "camera_zoom_in"
const ACTION_ZOOM_OUT := "camera_zoom_out"
const ACTION_RECENTER := "camera_recenter"


static func ensure_default_actions() -> void:
	var bindings := [
		[ACTION_MOVE, KEY_ENTER, 0],
		[ACTION_SELECT, KEY_SPACE, 2],
		[ACTION_CANCEL, KEY_ESCAPE, 1],
		[ACTION_TARGET_NEXT, KEY_E, 10],
		[ACTION_TARGET_PREVIOUS, KEY_Q, 9],
		[ACTION_PAN_LEFT, KEY_A, 13],
		[ACTION_PAN_RIGHT, KEY_D, 14],
		[ACTION_PAN_UP, KEY_W, 11],
		[ACTION_PAN_DOWN, KEY_S, 12],
		[ACTION_ZOOM_IN, KEY_EQUAL, -1],
		[ACTION_ZOOM_OUT, KEY_MINUS, -1],
		[ACTION_RECENTER, KEY_C, 6],
	]
	for binding in bindings:
		var action: StringName = str(binding[0])
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.5)
		if InputMap.action_get_events(action).is_empty():
			_add_key(action, int(binding[1]))
			if int(binding[2]) >= 0:
				_add_joy_button(action, int(binding[2]))


static func _add_key(action: StringName, keycode: int) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)


static func _add_joy_button(action: StringName, button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	InputMap.action_add_event(action, event)
