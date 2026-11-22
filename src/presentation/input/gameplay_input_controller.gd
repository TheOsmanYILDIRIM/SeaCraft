class_name GameplayInputController
extends Node

signal command_emitted(command: Dictionary)

const BINDINGS := preload("res://src/presentation/input/input_bindings.gd")
const MAPPER := preload("res://src/presentation/input/input_command_mapper.gd")
const TOUCH := preload("res://src/presentation/input/touch_gesture_interpreter.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")

@export var camera_path: NodePath
@export var keyboard_pan_speed := 600.0

var combat_target_at: Callable
var ui_hit_test: Callable
var _camera: Node
var _touch = TOUCH.new()
var _mouse_pan_active := false
var _world_input_blocked := false


func _ready() -> void:
	BINDINGS.ensure_default_actions()
	_camera = get_node_or_null(camera_path)


func _process(delta: float) -> void:
	if _camera == null or _world_input_blocked:
		return
	var axis := Input.get_vector(
		BINDINGS.ACTION_PAN_LEFT,
		BINDINGS.ACTION_PAN_RIGHT,
		BINDINGS.ACTION_PAN_UP,
		BINDINGS.ACTION_PAN_DOWN
	)
	if axis != Vector2.ZERO:
		_dispatch(MAPPER.map_camera_pan(axis * keyboard_pan_speed * delta))


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	if _world_input_blocked or _camera == null:
		return
	var screen_position := event.position
	if ui_hit_test.is_valid() and bool(ui_hit_test.call(screen_position)):
		return
	process_device_event(event, false)
	get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Touch is handled in _input so Android GUI dispatch cannot swallow world taps.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	process_device_event(event, false)


func process_device_event(event: InputEvent, ui_consumed: bool = false) -> void:
	if ui_consumed or _world_input_blocked or _camera == null or event == null:
		return

	if event is InputEventMouseButton:
		_handle_mouse_button(event)
		return
	if event is InputEventMouseMotion:
		_handle_mouse_motion(event)
		return
	if event is InputEventScreenTouch:
		_handle_screen_touch(event)
		return
	if event is InputEventScreenDrag:
		_handle_screen_drag(event)
		return

	if event.is_action_pressed(BINDINGS.ACTION_MOVE):
		_emit_pointer_command("mouse", get_viewport().get_mouse_position(), false)
	elif event.is_action_pressed(BINDINGS.ACTION_SELECT):
		_emit_pointer_command("mouse", get_viewport().get_mouse_position(), true)
	elif event.is_action_pressed(BINDINGS.ACTION_CANCEL):
		_dispatch(MAPPER.map_cancel())
	elif event.is_action_pressed(BINDINGS.ACTION_TARGET_NEXT):
		_dispatch(MAPPER.map_target_cycle(1))
	elif event.is_action_pressed(BINDINGS.ACTION_TARGET_PREVIOUS):
		_dispatch(MAPPER.map_target_cycle(-1))
	elif event.is_action_pressed(BINDINGS.ACTION_ZOOM_IN):
		_dispatch(MAPPER.map_camera_zoom(1.1))
	elif event.is_action_pressed(BINDINGS.ACTION_ZOOM_OUT):
		_dispatch(MAPPER.map_camera_zoom(1.0 / 1.1))
	elif event.is_action_pressed(BINDINGS.ACTION_RECENTER):
		_dispatch(MAPPER.map_camera_recenter())


func set_world_input_blocked(blocked: bool) -> void:
	_world_input_blocked = blocked
	if blocked:
		_mouse_pan_active = false
		reset_touch()


func world_input_blocked() -> bool:
	return _world_input_blocked


func reset_touch() -> void:
	_touch.reset()


func emit_fire_intent(target_id: String) -> void:
	if not target_id.is_empty():
		_dispatch(CombatAuthority.fire_intent(target_id))


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_MIDDLE:
		_mouse_pan_active = event.pressed
		return
	if not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			_emit_pointer_command("mouse", event.position, false)
		MOUSE_BUTTON_RIGHT:
			_emit_pointer_command("mouse", event.position, true)
		MOUSE_BUTTON_WHEEL_UP:
			_dispatch(MAPPER.map_camera_zoom(1.1))
		MOUSE_BUTTON_WHEEL_DOWN:
			_dispatch(MAPPER.map_camera_zoom(1.0 / 1.1))


func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if not _mouse_pan_active:
		return
	var world_delta: Vector2 = _camera.call(
		"screen_delta_to_world_delta",
		-event.relative
	)
	_dispatch(MAPPER.map_camera_pan(world_delta))


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.canceled:
		reset_touch()
		return
	var gestures: Array[Dictionary]
	if event.pressed:
		gestures = _touch.press(event.index, event.position)
	else:
		gestures = _touch.release(event.index, event.position)
	_handle_touch_gestures(gestures)


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_handle_touch_gestures(_touch.drag(event.index, event.position))


func _handle_touch_gestures(gestures: Array[Dictionary]) -> void:
	for gesture in gestures:
		match str(gesture.get("kind", "")):
			"tap":
				_emit_pointer_command(
					"touch",
					Vector2(
						float(gesture.get("screen_x", 0.0)),
						float(gesture.get("screen_y", 0.0))
					),
					false
				)
			"pan":
				var screen_delta := Vector2(
					float(gesture.get("delta_x", 0.0)),
					float(gesture.get("delta_y", 0.0))
				)
				var world_delta: Vector2 = _camera.call(
					"screen_delta_to_world_delta",
					-screen_delta
				)
				_dispatch(MAPPER.map_camera_pan(world_delta))
			"zoom":
				_dispatch(MAPPER.map_camera_zoom(float(gesture.get("factor", 1.0))))


func _emit_pointer_command(
	pointer_source: String,
	screen_position: Vector2,
	selection: bool
) -> void:
	var world_position: Vector2 = _camera.call(
		"screen_to_world_position",
		screen_position
	)
	# Combat hit-testing precedes world movement. Empty primary taps still sail.
	if combat_target_at.is_valid():
		var target_id: String = combat_target_at.call(world_position)
		if selection or not target_id.is_empty():
			_dispatch({"domain": COMMANDS.DOMAIN_GAMEPLAY, "type": CombatAuthority.SELECT, "target_id": target_id})
			return
	_dispatch(
		MAPPER.map_world_pointer(
			pointer_source,
			world_position,
			false,
			selection
		)
	)


func _dispatch(command: Dictionary) -> void:
	if command.is_empty():
		return
	command_emitted.emit(command)

	if str(command.get("domain", "")) != COMMANDS.DOMAIN_PRESENTATION:
		return

	var command_type := str(command.get("type", ""))
	if command_type == COMMANDS.CAMERA_PAN:
		_camera.call(
			"pan_world_delta",
			Vector2(
				float(command.get("delta_x", 0.0)),
				float(command.get("delta_y", 0.0))
			)
		)
	elif command_type == COMMANDS.CAMERA_ZOOM:
		_camera.call("zoom_by", float(command.get("factor", 1.0)))
	elif command_type == COMMANDS.CAMERA_RECENTER:
		_camera.call("recenter")
