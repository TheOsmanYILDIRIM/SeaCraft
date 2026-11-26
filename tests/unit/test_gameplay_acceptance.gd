extends GutTest
# Shipped scene, viewport event dispatch, real physics and isolated on-disk saves.
# No direct controller._input(), button.pressed.emit(), or motor position writes.
const BOOT := preload("res://src/presentation/bootstrap.tscn")
var _directory := ""

func after_each() -> void:
	if not _directory.is_empty():
		for file in [SaveService.PRIMARY, SaveService.BACKUP, SaveService.TEMP]:
			var path := _directory.path_join(file)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		if DirAccess.dir_exists_absolute(_directory):
			DirAccess.remove_absolute(_directory)

func _viewport() -> SubViewport:
	_directory = "user://acceptance-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 720)
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child_autofree(viewport)
	return viewport

func _boot(viewport: SubViewport) -> Node:
	var scene := BOOT.instantiate()
	scene.set("_save_service", SaveService.new(_directory))
	viewport.add_child(scene)
	return scene

func _touch(viewport: SubViewport, point: Vector2, down: bool, index: int = 0) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	viewport.push_input(event, true)

func _tap(viewport: SubViewport, point: Vector2) -> void:
	_touch(viewport, point, true)
	_touch(viewport, point, false)

func _click(viewport: SubViewport, point: Vector2) -> void:
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = down
		viewport.push_input(event, true)

func _water_point(scene: Node, viewport: SubViewport) -> Vector2:
	var motor := scene.get_node("ShipMotor") as ShipMotor
	var camera := scene.get_node("GameplayCamera") as GameplayCamera
	for offset in [Vector2(240, 0), Vector2(-240, 0), Vector2(0, 240), Vector2(0, -240)]:
		var screen := camera.world_to_screen_position(motor.global_position + offset)
		var world := camera.screen_to_world_position(screen)
		if viewport.get_visible_rect().has_point(screen) and not scene._ui_captures_touch(screen) and scene.active_sector().navigation.accessible(world) and scene._target_at(world).is_empty():
			return screen
	return Vector2.INF

func test_viewport_tap_sails_stop_button_and_pause_resume() -> void:
	var viewport := _viewport()
	var scene := _boot(viewport)
	await get_tree().process_frame
	assert_not_null(scene.active_sector(), "packed game must boot")
	if scene.active_sector() == null:
		return
	var motor := scene.get_node("ShipMotor") as ShipMotor
	var start := motor.global_position
	var point := _water_point(scene, viewport)
	assert_true(point.is_finite(), "fixture must expose tappable water")
	if not point.is_finite():
		return
	_tap(viewport, point)
	assert_true(motor.has_target(), "viewport input must reach authoritative helm")
	for frame in range(30):
		await get_tree().physics_frame
	assert_gt(motor.global_position.distance_to(start), 1.0, "actual physics movement")
	var stop := scene.get_node("UI/Play01Stop") as Button
	assert_false(stop.disabled)
	_tap(viewport, stop.get_global_rect().get_center())
	assert_false(motor.has_target(), "GUI touch must cancel, not route to the water behind it")
	assert_false(scene.get_node("Play01Route").visible)
	for frame in range(180):
		await get_tree().physics_frame
	assert_lt(motor.velocity.length(), 0.1, "ship must physically stop")
	var saved_position := motor.global_position
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	var service := SaveService.new(_directory)
	var saved := service.load()
	assert_eq(saved["status"], SaveService.OK_STATUS, "background save must be readable")
	if saved["status"] != SaveService.OK_STATUS:
		return
	scene.free()
	var resumed := _boot(viewport)
	assert_not_null(resumed.active_sector())
	if resumed.active_sector() == null:
		return
	var resumed_motor := resumed.get_node("ShipMotor") as ShipMotor
	assert_lt(resumed_motor.global_position.distance_to(saved_position), 0.1)
	assert_false(resumed_motor.has_target())
	assert_lt(resumed_motor.velocity.length(), 0.1)
	print("ACCEPTANCE_VIEWPORT_HELM_PAUSE_RESUME_OK")

func test_viewport_map_modal_blocks_world_and_releases_input() -> void:
	var viewport := _viewport()
	var scene := _boot(viewport)
	await get_tree().process_frame
	assert_not_null(scene.active_sector())
	if scene.active_sector() == null:
		return
	var motor := scene.get_node("ShipMotor") as ShipMotor
	var controller := scene.get_node("InputController") as GameplayInputController
	var map_button := scene.get_node("UI/Core03MapButton") as Button
	var point := _water_point(scene, viewport)
	assert_true(point.is_finite())
	if not point.is_finite():
		return
	var commands: Array[Dictionary] = []
	controller.command_emitted.connect(func(command: Dictionary) -> void: commands.append(command))
	_click(viewport, map_button.get_global_rect().get_center())
	assert_true(controller.world_input_blocked(), "actual map GUI click must open modal")
	_tap(viewport, point)
	assert_false(motor.has_target())
	assert_eq(commands.size(), 0, "modal must not leak a world or camera command")
	_click(viewport, map_button.get_global_rect().get_center())
	assert_false(controller.world_input_blocked(), "closing map must restore input")
	point = _water_point(scene, viewport)
	assert_true(point.is_finite())
	if not point.is_finite():
		return
	_tap(viewport, point)
	assert_true(motor.has_target())
	assert_eq(commands.size(), 1, "one physical tap, one gameplay command")
	if commands.size() == 1:
		assert_eq(commands[0]["type"], GameplayCommand.MOVE_TO_WORLD_POSITION)
	print("ACCEPTANCE_VIEWPORT_MAP_MODAL_OK")
