extends GutTest

const BOOTSTRAP_SCENE := preload("res://src/presentation/bootstrap.tscn")


func test_bootstrap_scene_instantiates() -> void:
	var instance := BOOTSTRAP_SCENE.instantiate()
	assert_not_null(instance)
	assert_eq(instance.name, "Bootstrap")
	instance.free()


func test_foundation_renderer_is_compatibility() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"gl_compatibility"
	)
	assert_eq(
		ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile"),
		"gl_compatibility"
	)


func test_exports_exclude_source_sprite_archives() -> void:
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(presets.contains("*.zip"))


func test_ci_publishes_platform_specific_artifacts() -> void:
	var workflow := FileAccess.get_file_as_string("res://.github/workflows/ci.yml")
	assert_true(workflow.contains("SeaCraft-Android-${{ github.sha }}"))
	assert_true(workflow.contains("SeaCraft-Linux-${{ github.sha }}"))
	assert_false(workflow.contains("name: SeaCraft-PRG04-${{ github.sha }}"))


func test_core_action_feedback_is_transient() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/bootstrap.gd")
	assert_true(source.contains("func _show_core_feedback"))
	assert_true(source.contains("create_timer(0.75)"))


func test_npc_presenter_keeps_label_screen_upright() -> void:
	var parent := Node2D.new()
	add_child_autofree(parent)
	parent.rotation = 1.1
	var presenter := NpcStatePresenter.new()
	parent.add_child(presenter)
	presenter._process(0.0)
	assert_almost_eq(presenter.global_rotation, 0.0, 0.0001)


func test_hidden_fullscreen_ui_subtree_does_not_capture_world_touch() -> void:
	var scene := preload("res://src/presentation/bootstrap.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var hidden_panel := Control.new()
	hidden_panel.name = "HiddenFullscreenPanel"
	hidden_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hidden_panel.hide()
	scene.get_node("UI").add_child(hidden_panel)

	var child := Control.new()
	child.name = "LocallyVisibleChild"
	child.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	child.mouse_filter = Control.MOUSE_FILTER_STOP
	hidden_panel.add_child(child)

	assert_true(child.visible)
	assert_false(child.is_visible_in_tree())
	assert_false(scene._ui_captures_touch(Vector2(640.0, 360.0)))


func test_visible_control_still_captures_world_touch() -> void:
	var scene := preload("res://src/presentation/bootstrap.tscn").instantiate()
	add_child_autofree(scene)
	await get_tree().process_frame

	var panel := Control.new()
	panel.position = Vector2(300.0, 200.0)
	panel.size = Vector2(200.0, 120.0)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	scene.get_node("UI").add_child(panel)

	assert_true(panel.is_visible_in_tree())
	assert_true(scene._ui_captures_touch(Vector2(350.0, 250.0)))
	assert_false(scene._ui_captures_touch(Vector2(800.0, 500.0)))

# Android world-input regression sentinel: hidden UI descendants must never capture world touch.


func test_packed_bootstrap_routes_native_tap_to_player_motor() -> void:
	# Instantiate the shipped scene: constructing a controller and assigning a
	# camera in test code cannot detect a lost serialized export property.
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 720)
	viewport.world_2d = World2D.new()
	add_child_autofree(viewport)
	var scene := BOOTSTRAP_SCENE.instantiate()
	var controller := scene.get_node("InputController") as GameplayInputController
	var camera := scene.get_node("GameplayCamera") as GameplayCamera
	var motor := scene.get_node("ShipMotor") as ShipMotor
	assert_eq(controller.camera_path, NodePath("../GameplayCamera"))
	assert_eq(camera.follow_target_path, NodePath("../BoatMarker"))
	viewport.add_child(scene)
	assert_eq(controller._camera, camera)
	assert_eq(camera._follow_target, scene.get_node("BoatMarker"))
	assert_not_null(scene.active_sector())
	if scene.active_sector() == null:
		return

	motor.cancel_target()
	motor.velocity = Vector2.ZERO
	var start := motor.global_position
	var tap := Vector2.ZERO
	for offset in [Vector2(240, 0), Vector2(-240, 0), Vector2(0, 240), Vector2(0, -240)]:
		var screen := camera.world_to_screen_position(start + offset)
		if viewport.get_visible_rect().has_point(screen) and not scene._ui_captures_touch(screen) and scene._target_at(camera.screen_to_world_position(screen)).is_empty():
			tap = screen
			break
	assert_ne(tap, Vector2.ZERO, "fixture must provide a visible empty-water tap")
	if tap == Vector2.ZERO:
		return
	var press := InputEventScreenTouch.new()
	press.position = tap
	press.pressed = true
	controller._input(press)
	var release := InputEventScreenTouch.new()
	release.position = tap
	controller._input(release)
	assert_true(motor.has_target(), "native tap must reach Bootstrap's ShipMotor")
	for frame in range(12):
		await get_tree().physics_frame
	assert_gt(motor.global_position.distance_to(start), 0.1, "player position must change in physics")
