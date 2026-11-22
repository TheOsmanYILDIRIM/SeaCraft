class_name GameplayInputController
extends Node

signal command_emitted(command: Dictionary)

const BINDINGS := preload("res://src/presentation/input/input_bindings.gd")
const MAPPER := preload("res://src/presentation/input/input_command_mapper.gd")
const TOUCH := preload("res://src/presentation/input/touch_gesture_interpreter.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")

@export var camera_path: NodePath
@export var keyboard_pan_speed := 600.0

const ANDROID_TRACE := preload("res://src/presentation/input/android_input_trace.gd")
var _diag_mouse_pending: Dictionary = {}

var combat_target_at: Callable
var ui_hit_test: Callable
var _camera: Node
var _touch = TOUCH.new()
var _mouse_pan_active := false
var _world_input_blocked := false
var _world_touch_indices: Dictionary = {}
var _last_native_touch_ms := -100000
var _android_mouse_touch_active := false
const SYNTHETIC_MOUSE_SUPPRESS_MS := 300


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
	if ANDROID_TRACE.enabled():
		_trace_raw_pointer(event)
	if event is InputEventMagnifyGesture:
		if not _world_input_blocked and _camera != null:
			_dispatch(MAPPER.map_camera_zoom(float(event.factor)))
			get_viewport().set_input_as_handled()
		return
	if event is InputEventPanGesture:
		if not _world_input_blocked and _camera != null:
			var world_delta: Vector2 = _camera.call("screen_delta_to_world_delta", -event.delta)
			_dispatch(MAPPER.map_camera_pan(world_delta))
			get_viewport().set_input_as_handled()
		return
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	_last_native_touch_ms = Time.get_ticks_msec()
	if _world_input_blocked or _camera == null:
		ANDROID_TRACE.record("route", "native blocked: world_blocked=%s camera_present=%s" % [_world_input_blocked, _camera != null])
		return

	if event is InputEventScreenTouch:
		if event.pressed:
			if ui_hit_test.is_valid() and bool(ui_hit_test.call(event.position)):
				_world_touch_indices.erase(event.index)
				ANDROID_TRACE.record("route", "native press owned by UI")
				return
			ANDROID_TRACE.record("route", "native press owned by world")
			_world_touch_indices[event.index] = true
			process_device_event(event, false)
			get_viewport().set_input_as_handled()
			return
		if not _world_touch_indices.has(event.index):
			ANDROID_TRACE.record("route", "release blocked: no world owner")
			return
		process_device_event(event, false)
		_world_touch_indices.erase(event.index)
		get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag and _world_touch_indices.has(event.index):
		process_device_event(event, false)
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	# Touch is handled in _input so Android GUI dispatch cannot swallow world taps.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return
	# Android also emulates mouse from touch so ordinary Control/Button nodes work.
	# Suppress that synthetic mouse stream when the native touch stream was seen;
	# otherwise use it as a complete one-finger fallback for devices/ROMs where
	# native ScreenTouch/ScreenDrag does not reach the gameplay node.
	if OS.has_feature("android") and (event is InputEventMouseButton or event is InputEventMouseMotion):
		if ANDROID_TRACE.enabled():
			_diag_mouse_pending.erase(event.get_instance_id())
		if Time.get_ticks_msec() - _last_native_touch_ms <= SYNTHETIC_MOUSE_SUPPRESS_MS:
			if event is InputEventMouseButton:
				ANDROID_TRACE.record("route", "mouse suppressed after native touch")
			return
		if event is InputEventMouseButton:
			ANDROID_TRACE.record("route", "mouse reached fallback")
		_process_android_mouse_fallback(event)
		return
	process_device_event(event, false)



func _trace_raw_pointer(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		ANDROID_TRACE.record("raw_touch", "finger=%s pressed=%s canceled=%s pos=%s device=%s" % [
			event.index, event.pressed, event.canceled, event.position, event.device])
	elif event is InputEventScreenDrag:
		ANDROID_TRACE.record("raw_drag", "finger=%s pos=%s owned=%s" % [event.index, event.position, _world_touch_indices.has(event.index)])
	elif event is InputEventMouseButton:
		ANDROID_TRACE.record("raw_mouse", "button=%s pressed=%s pos=%s device=%s emulated=%s" % [
			event.button_index, event.pressed, event.position, event.device, event.device == InputEvent.DEVICE_ID_EMULATION])
		var event_id := event.get_instance_id()
		_diag_mouse_pending[event_id] = true
		_trace_mouse_not_unhandled.call_deferred(event_id)
	elif event is InputEventPanGesture or event is InputEventMagnifyGesture:
		ANDROID_TRACE.record("raw_gesture", "%s blocked=%s camera_present=%s" % [event.get_class(), _world_input_blocked, _camera != null])


func _trace_mouse_not_unhandled(event_id: int) -> void:
	if not _diag_mouse_pending.erase(event_id):
		return
	var hovered := get_viewport().gui_get_hovered_control()
	ANDROID_TRACE.record("route", "mouse did not reach _unhandled_input; hovered (not proof of consumer)=%s" % [
		str(hovered.get_path()) if is_instance_valid(hovered) else "<none>"])


func _process_android_mouse_fallback(event: InputEvent) -> void:
	if _world_input_blocked or _camera == null:
		ANDROID_TRACE.record("route", "mouse fallback blocked: world_blocked=%s camera_present=%s" % [_world_input_blocked, _camera != null])
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if ui_hit_test.is_valid() and bool(ui_hit_test.call(event.position)):
					_android_mouse_touch_active = false
					ANDROID_TRACE.record("route", "mouse press owned by UI hit test")
					return
				_android_mouse_touch_active = true
				_handle_touch_gestures(_touch.press(0, event.position))
			elif _android_mouse_touch_active:
				_handle_touch_gestures(_touch.release(0, event.position))
				_android_mouse_touch_active = false
			return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_dispatch(MAPPER.map_camera_zoom(1.1))
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_dispatch(MAPPER.map_camera_zoom(1.0 / 1.1))
		return
	if event is InputEventMouseMotion and _android_mouse_touch_active:
		_handle_touch_gestures(_touch.drag(0, event.position))


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
	ANDROID_TRACE.record("route", "touch state reset")
	_touch.reset()
	_world_touch_indices.clear()
	_android_mouse_touch_active = false


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
	if ANDROID_TRACE.enabled():
		ANDROID_TRACE.record("gesture", "none (candidate or rejected)" if gestures.is_empty() else str(gestures))
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
		if ANDROID_TRACE.enabled():
			ANDROID_TRACE.record("target", "screen=%s world=%s hit=%s selection=%s" % [screen_position, world_position, target_id, selection])
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
	if ANDROID_TRACE.enabled():
		ANDROID_TRACE.record("dispatch", "mapper produced no command" if command.is_empty() else str(command))
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
