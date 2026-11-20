extends GutTest

const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const DTO_CONTRACT := preload("res://src/data/contracts/dto_contract.gd")
const MAPPER := preload("res://src/presentation/input/input_command_mapper.gd")
const TOUCH := preload("res://src/presentation/input/touch_gesture_interpreter.gd")
const BINDINGS := preload("res://src/presentation/input/input_bindings.gd")
const CAMERA_MATH := preload("res://src/presentation/camera/camera_math.gd")
const CAMERA_STATE := preload("res://src/presentation/camera/camera_presentation_state.gd")
const SAFE_AREA := preload("res://src/presentation/layout/safe_area_math.gd")


func test_mouse_and_touch_same_world_target_produce_same_command() -> void:
	var world_target := Vector2(412.25, -83.5)
	var mouse := MAPPER.map_world_pointer("mouse", world_target)
	var touch := MAPPER.map_world_pointer("touch", world_target)
	assert_eq(mouse, touch)
	assert_eq(mouse["type"], COMMANDS.MOVE_TO_WORLD_POSITION)


func test_screen_world_round_trip_is_within_tolerance() -> void:
	var camera_position := Vector2(320.0, -120.0)
	var zoom_value := Vector2(1.75, 1.75)
	var viewport_size := Vector2(1280.0, 720.0)
	var world_point := Vector2(-74.5, 918.25)
	var screen_point := CAMERA_MATH.world_to_screen(
		world_point,
		camera_position,
		zoom_value,
		viewport_size
	)
	var round_trip := CAMERA_MATH.screen_to_world(
		screen_point,
		camera_position,
		zoom_value,
		viewport_size
	)
	assert_lt(round_trip.distance_to(world_point), 0.001)


func test_ui_consumed_input_does_not_create_world_command() -> void:
	var command := MAPPER.map_world_pointer("mouse", Vector2(15.0, 20.0), true)
	assert_true(command.is_empty())


func test_camera_pan_does_not_change_simulation_state() -> void:
	var simulation_state := {
		"entity_id": "entity.player.1",
		"position_x": 30.0,
		"position_y": -9.0,
	}
	var before := simulation_state.duplicate(true)
	var camera_state = CAMERA_STATE.new()
	camera_state.position = Vector2(4.0, 6.0)
	camera_state.pan_world_delta(Vector2(12.0, -3.0))
	assert_eq(simulation_state, before)
	assert_eq(camera_state.position, Vector2(16.0, 3.0))
	assert_false(camera_state.follow_mode)


func test_camera_zoom_clamp_works() -> void:
	var camera_state = CAMERA_STATE.new()
	camera_state.configure_zoom(0.5, 2.0, 1.0)
	assert_eq(camera_state.zoom_by(10.0), 2.0)
	assert_eq(camera_state.zoom_by(0.01), 0.5)


func test_camera_limit_clamp_works() -> void:
	var camera_state = CAMERA_STATE.new()
	camera_state.position = Vector2(90.0, 40.0)
	camera_state.set_limits(Rect2(-100.0, -50.0, 200.0, 100.0), true)
	camera_state.pan_world_delta(Vector2(50.0, 30.0))
	assert_eq(camera_state.position, Vector2(100.0, 50.0))


func test_follow_and_recenter_mode_is_deterministic() -> void:
	var first = CAMERA_STATE.new()
	var second = CAMERA_STATE.new()
	for state in [first, second]:
		state.position = Vector2(-500.0, 220.0)
		state.set_limits(Rect2(-1000.0, -1000.0, 2000.0, 2000.0), true)
		state.set_follow_target_position(Vector2(125.0, -75.0))
		state.recenter()
		state.step_follow()
	assert_true(first.follow_mode)
	assert_eq(first.position, Vector2(125.0, -75.0))
	assert_eq(first.position, second.position)


func test_generated_commands_are_primitive_safe_dtos() -> void:
	var commands := [
		COMMANDS.move_to_world_position(Vector2(1.5, 2.5)),
		COMMANDS.select_world_position(Vector2(-4.0, 8.0)),
		COMMANDS.cancel(),
		COMMANDS.camera_pan(Vector2(3.0, -2.0)),
		COMMANDS.camera_zoom(1.25),
		COMMANDS.camera_recenter(),
		COMMANDS.target_cycle(1),
	]
	for command in commands:
		assert_true(DTO_CONTRACT.is_primitive_safe(command))


func test_malformed_or_unsupported_input_is_safely_rejected() -> void:
	assert_true(
		MAPPER.map_world_pointer(
			"unsupported-device",
			Vector2(1.0, 2.0)
		).is_empty()
	)
	assert_true(MAPPER.map_target_cycle(0).is_empty())
	assert_true(MAPPER.map_camera_zoom(-1.0).is_empty())
	var touch = TOUCH.new()
	assert_true(touch.drag(99, Vector2(10.0, 10.0)).is_empty())
	assert_true(touch.release(99, Vector2(10.0, 10.0)).is_empty())


func test_multitouch_cancels_tap_and_does_not_emit_pan() -> void:
	var touch = TOUCH.new()
	touch.press(0, Vector2(100.0, 100.0))
	touch.press(1, Vector2(200.0, 100.0))
	var gestures := touch.drag(1, Vector2(230.0, 100.0))
	assert_eq(gestures.size(), 1)
	assert_eq(gestures[0]["kind"], "zoom")
	assert_true(touch.release(1, Vector2(230.0, 100.0)).is_empty())
	assert_true(touch.release(0, Vector2(100.0, 100.0)).is_empty())


func test_inputmap_actions_are_installed_for_keyboard_and_gamepad() -> void:
	BINDINGS.ensure_default_actions()
	for action in [
		BINDINGS.ACTION_MOVE,
		BINDINGS.ACTION_SELECT,
		BINDINGS.ACTION_CANCEL,
		BINDINGS.ACTION_TARGET_NEXT,
		BINDINGS.ACTION_TARGET_PREVIOUS,
		BINDINGS.ACTION_PAN_LEFT,
		BINDINGS.ACTION_PAN_RIGHT,
		BINDINGS.ACTION_PAN_UP,
		BINDINGS.ACTION_PAN_DOWN,
		BINDINGS.ACTION_ZOOM_IN,
		BINDINGS.ACTION_ZOOM_OUT,
		BINDINGS.ACTION_RECENTER,
	]:
		assert_true(InputMap.has_action(action))
		assert_false(InputMap.action_get_events(action).is_empty())


func test_small_landscape_safe_area_and_expand_math_are_stable() -> void:
	var base := Vector2(1280.0, 720.0)
	var window := Vector2(2400.0, 1080.0)
	var logical_size := SAFE_AREA.logical_viewport_size(base, window)
	assert_lt(logical_size.distance_to(Vector2(1600.0, 720.0)), 0.001)
	var safe_display := Rect2(80.0, 0.0, 2320.0, 1080.0)
	var safe_logical := SAFE_AREA.display_safe_area_to_logical(safe_display, base, window)
	assert_lt(safe_logical.position.distance_to(Vector2(53.333333, 0.0)), 0.001)
	assert_lt(safe_logical.size.distance_to(Vector2(1546.666667, 720.0)), 0.001)


func test_touch_mouse_emulation_is_disabled_to_prevent_duplicate_commands() -> void:
	assert_eq(
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),
		false
	)
	assert_eq(
		ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"),
		false
	)
