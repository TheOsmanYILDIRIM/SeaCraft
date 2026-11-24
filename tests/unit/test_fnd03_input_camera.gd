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


func test_android_touch_compatibility_settings_are_enabled() -> void:
	assert_eq(
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),
		true
	)
	assert_eq(
		ProjectSettings.get_setting("input_devices/pointing/emulate_touch_from_mouse"),
		false
	)
	assert_eq(
		ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures"),
		true
	)


func test_touch_input_stage_emits_world_move_before_gui_can_swallow_it() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var camera := GameplayCamera.new()
	camera.name = "Camera"
	root.add_child(camera)
	var controller := GameplayInputController.new()
	controller.name = "Controller"
	controller.camera_path = NodePath("../Camera")
	root.add_child(controller)
	await get_tree().process_frame
	var commands: Array[Dictionary] = []
	controller.command_emitted.connect(func(command: Dictionary) -> void: commands.append(command))
	controller.ui_hit_test = func(_position: Vector2) -> bool: return false

	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = Vector2(900.0, 420.0)
	press.pressed = true
	controller._input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = Vector2(900.0, 420.0)
	release.pressed = false
	controller._input(release)

	assert_eq(commands.size(), 1)
	assert_eq(commands[0]["type"], COMMANDS.MOVE_TO_WORLD_POSITION)
	assert_eq(commands[0]["domain"], COMMANDS.DOMAIN_GAMEPLAY)


func test_touch_input_stage_respects_ui_hit_test() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var camera := GameplayCamera.new()
	camera.name = "Camera"
	root.add_child(camera)
	var controller := GameplayInputController.new()
	controller.name = "Controller"
	controller.camera_path = NodePath("../Camera")
	root.add_child(controller)
	await get_tree().process_frame
	var commands: Array[Dictionary] = []
	controller.command_emitted.connect(func(command: Dictionary) -> void: commands.append(command))
	controller.ui_hit_test = func(_position: Vector2) -> bool: return true

	var press := InputEventScreenTouch.new()
	press.index = 0
	press.position = Vector2(40.0, 40.0)
	press.pressed = true
	controller._input(press)
	var release := InputEventScreenTouch.new()
	release.index = 0
	release.position = Vector2(40.0, 40.0)
	release.pressed = false
	controller._input(release)

	assert_true(commands.is_empty())


func test_world_touch_release_over_ui_finishes_gesture_without_sticking() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var camera := GameplayCamera.new()
	camera.name = "Camera"
	root.add_child(camera)
	var controller := GameplayInputController.new()
	controller.name = "Controller"
	controller.camera_path = NodePath("../Camera")
	root.add_child(controller)
	await get_tree().process_frame
	var commands: Array[Dictionary] = []
	controller.command_emitted.connect(func(command: Dictionary) -> void: commands.append(command))
	controller.ui_hit_test = func(position: Vector2) -> bool: return position.x < 100.0

	var press := InputEventScreenTouch.new()
	press.index = 7
	press.position = Vector2(900.0, 420.0)
	press.pressed = true
	controller._input(press)
	var release := InputEventScreenTouch.new()
	release.index = 7
	release.position = Vector2(40.0, 40.0)
	release.pressed = false
	controller._input(release)

	# Crossing into UI may become a pan rather than a tap; the contract here is
	# that the world-owned finger is released and cannot poison the next touch.
	var after_crossing := commands.size()

	var ui_press := InputEventScreenTouch.new()
	ui_press.index = 7
	ui_press.position = Vector2(40.0, 40.0)
	ui_press.pressed = true
	controller._input(ui_press)
	var ui_release := InputEventScreenTouch.new()
	ui_release.index = 7
	ui_release.position = Vector2(40.0, 40.0)
	ui_release.pressed = false
	controller._input(ui_release)
	assert_eq(commands.size(), after_crossing)

	var second_press := InputEventScreenTouch.new()
	second_press.index = 7
	second_press.position = Vector2(900.0, 420.0)
	second_press.pressed = true
	controller._input(second_press)
	var second_release := InputEventScreenTouch.new()
	second_release.index = 7
	second_release.position = Vector2(900.0, 420.0)
	second_release.pressed = false
	controller._input(second_release)
	assert_eq(commands.size(), after_crossing + 1)
	assert_eq(commands[-1]["type"], COMMANDS.MOVE_TO_WORLD_POSITION)


func test_android_jittery_tap_still_commands_ship_motion() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var camera := GameplayCamera.new()
	camera.name = "Camera"
	root.add_child(camera)
	var motor := ShipMotor.new()
	motor.name = "Motor"
	root.add_child(motor)
	var controller := GameplayInputController.new()
	controller.name = "Controller"
	controller.camera_path = NodePath("../Camera")
	root.add_child(controller)
	await get_tree().process_frame
	controller.ui_hit_test = func(_position: Vector2) -> bool: return false
	controller.command_emitted.connect(func(command: Dictionary) -> void:
		motor.apply_authoritative_command(command)
	)

	var press := InputEventScreenTouch.new()
	press.index = 3
	press.position = Vector2(900.0, 420.0)
	press.pressed = true
	controller._input(press)

	var jitter := InputEventScreenDrag.new()
	jitter.index = 3
	jitter.position = Vector2(924.0, 432.0)
	jitter.relative = Vector2(24.0, 12.0)
	controller._input(jitter)

	var release := InputEventScreenTouch.new()
	release.index = 3
	release.position = Vector2(924.0, 432.0)
	release.pressed = false
	controller._input(release)

	assert_true(motor.has_target())
	var start := motor.global_position
	for _i in range(30):
		motor.step_authoritative(1.0 / 60.0, false)
	assert_gt(motor.global_position.distance_to(start), 1.0)


func test_large_single_finger_drag_remains_camera_pan_not_ship_move() -> void:
	var touch := TOUCH.new()
	touch.press(2, Vector2(300.0, 300.0))
	var gestures := touch.drag(2, Vector2(360.0, 300.0))
	assert_eq(gestures.size(), 1)
	assert_eq(gestures[0]["kind"], "pan")
	assert_true(touch.release(2, Vector2(360.0, 300.0)).is_empty())


func test_android_mouse_fallback_can_move_and_pan_when_native_touch_is_missing() -> void:
	var root := Node2D.new()
	add_child_autofree(root)
	var camera := GameplayCamera.new()
	camera.name = "Camera"
	root.add_child(camera)
	var controller := GameplayInputController.new()
	controller.name = "Controller"
	controller.camera_path = NodePath("../Camera")
	root.add_child(controller)
	await get_tree().process_frame
	controller.ui_hit_test = func(_position: Vector2) -> bool: return false
	var commands: Array[Dictionary] = []
	controller.command_emitted.connect(func(command: Dictionary) -> void: commands.append(command))

	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.position = Vector2(700.0, 360.0)
	press.pressed = true
	controller._process_android_mouse_fallback(press)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = Vector2(700.0, 360.0)
	release.pressed = false
	controller._process_android_mouse_fallback(release)
	assert_eq(commands.size(), 1)
	assert_eq(commands[0]["type"], COMMANDS.MOVE_TO_WORLD_POSITION)

	commands.clear()
	press.position = Vector2(400.0, 300.0)
	controller._process_android_mouse_fallback(press)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(470.0, 300.0)
	motion.relative = Vector2(70.0, 0.0)
	controller._process_android_mouse_fallback(motion)
	release.position = Vector2(470.0, 300.0)
	controller._process_android_mouse_fallback(release)
	assert_eq(commands.size(), 1)
	assert_eq(commands[0]["type"], COMMANDS.CAMERA_PAN)


func test_play01_rendered_canvas_hit_test_with_camera_limits_and_smoothing() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640, 360)
	add_child_autofree(viewport)
	var root := Node2D.new()
	viewport.add_child(root)
	var camera := GameplayCamera.new()
	root.add_child(camera)
	camera.make_current()
	camera.set_world_limits(Rect2(-640, -360, 1280, 720))
	camera.global_position = Vector2(630, 320)
	camera.reset_smoothing()
	camera.force_update_scroll()
	var marker := Node2D.new()
	marker.position = Vector2(390, 180)
	root.add_child(marker)
	await get_tree().process_frame
	var rendered := marker.get_global_transform_with_canvas().origin
	assert_lt(camera.screen_to_world_position(rendered).distance_to(marker.global_position), 0.01)
	assert_lt(camera.world_to_screen_position(marker.global_position).distance_to(rendered), 0.01)
	camera.global_position = Vector2(-400, -180)
	camera.force_update_scroll()
	rendered = marker.get_global_transform_with_canvas().origin
	assert_lt(camera.screen_to_world_position(rendered).distance_to(marker.global_position), 0.01)
	camera.zoom_by(1.5)
	rendered = marker.get_global_transform_with_canvas().origin
	assert_lt(camera.screen_to_world_position(rendered).distance_to(marker.global_position), 0.01)
	camera.set_follow_target(marker)
	camera.recenter()
	assert_true(camera.is_follow_mode())
	assert_lt(camera.screen_to_world_position(marker.get_global_transform_with_canvas().origin).distance_to(marker.global_position), 0.01)
	print("PLAY01_RENDERED_CANVAS_OK")


func test_play01_packed_helm_controls_and_destination() -> void:
	var scene := preload("res://src/presentation/bootstrap.tscn").instantiate()
	scene.set("_save_service", SaveService.new("user://play01-helm-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	add_child_autofree(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	var motor := scene.get_node("ShipMotor") as ShipMotor
	motor.set_physics_process(false)
	var camera := scene.get_node("GameplayCamera") as GameplayCamera
	var stop := scene.get_node("UI/Play01Stop") as Button
	var center := scene.get_node("UI/Play01Center") as Button
	var marker := scene.get_node("Play01Destination") as Line2D
	var route_line := scene.get_node("Play01Route") as Line2D
	assert_false(marker.visible)
	assert_false(route_line.visible)
	assert_true(stop.disabled)
	camera.pan_world_delta(Vector2(100, 0))
	assert_false(camera.is_follow_mode())
	motor.global_position += Vector2(12, 8)
	center.pressed.emit()
	assert_true(camera.is_follow_mode())
	assert_eq(camera._follow_target, scene.get_node("BoatMarker"))
	assert_eq(camera._follow_target.global_position, motor.global_position)
	var target := motor.global_position + Vector2(100, 0)
	scene._on_gameplay_command(COMMANDS.move_to_world_position(target))
	assert_true(motor.has_target())
	assert_true(marker.visible)
	assert_eq(marker.global_position, target)
	assert_true(route_line.visible)
	assert_eq(route_line.points[-1], target)
	assert_false(stop.disabled)
	assert_true(scene._ui_captures_touch(stop.get_global_rect().get_center()))
	stop.pressed.emit()
	assert_false(motor.has_target())
	assert_false(marker.visible)
	assert_false(route_line.visible)
	assert_true(stop.disabled)
	print("PLAY01_PACKED_HELM_OK")
