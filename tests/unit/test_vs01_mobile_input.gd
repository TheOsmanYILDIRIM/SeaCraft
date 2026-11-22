extends GutTest

class CameraStub extends Node:
	func screen_to_world_position(point: Vector2) -> Vector2:
		return point


func _touch(point: Vector2, down: bool) -> InputEventScreenTouch:
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = point
	touch.pressed = down
	return touch


func test_combat_touch_and_fire_do_not_emit_world_move() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(512, 384)
	view.gui_disable_input = false
	add_child_autofree(view)
	var camera := CameraStub.new()
	camera.name = "CameraStub"
	view.add_child(camera)
	var input := GameplayInputController.new()
	input.camera_path = NodePath("../CameraStub")
	view.add_child(input)
	input.combat_target_at = func(point: Vector2) -> String: return "entity.target" if point.x < 100 else ""
	input.ui_hit_test = func(point: Vector2) -> bool: return Rect2(Vector2(192, 100), Vector2(224, 132)).has_point(point)
	var seen: Array[Dictionary] = []
	input.command_emitted.connect(func(command: Dictionary) -> void: seen.append(command))
	var button := CombatFireButton.new()
	button.position = Vector2(192, 100)
	button.size = Vector2(224, 132)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.touch_captured.connect(input.reset_touch)
	button.pressed.connect(func() -> void: input.emit_fire_intent("entity.target"))
	view.add_child(button)
	var tap := Vector2(30, 40)
	view.push_input(_touch(tap, true), true)
	view.push_input(_touch(tap, false), true)
	var fire := Vector2(280, 145)
	view.push_input(_touch(fire, true), true)
	view.push_input(_touch(fire, false), true)
	assert_eq(seen.size(), 2)
	if seen.size() == 2:
		assert_eq(seen[0]["type"], CombatAuthority.SELECT)
		assert_eq(seen[1]["type"], CombatAuthority.FIRE)
	seen.clear()
	var water := Vector2(150, 35)
	view.push_input(_touch(water, true), true)
	view.push_input(_touch(water, false), true)
	assert_eq(seen.size(), 1)
	if seen.size() == 1:
		assert_eq(seen[0]["type"], GameplayCommand.MOVE_TO_WORLD_POSITION)
