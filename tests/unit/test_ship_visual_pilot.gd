extends GutTest

const SPRITE := preload("res://src/presentation/ship/pilot_atlas_sprite.gd")
const PILOT := preload("res://src/presentation/ship/visual_pilot.gd")


func test_world_heading_uses_all_eight_atlas_cells() -> void:
	for i in range(8):
		var heading := (float(i) - 2.0) * PI / 4.0
		assert_eq(SPRITE.frame_for_heading(heading), i)
		assert_eq(SPRITE.frame_for_heading(heading + TAU), i)
		assert_eq(SPRITE.frame_for_heading(heading - 0.38), i)
		assert_eq(SPRITE.frame_for_heading(heading + 0.38), i)


func test_atlas_follows_heading_with_bounded_residual_rotation() -> void:
	var target := Node2D.new()
	add_child_autofree(target)
	var ship := SPRITE.new()
	ship.hframes = 4
	ship.vframes = 2
	target.add_child(ship)
	for i in range(8):
		target.rotation = (float(i) - 2.0) * PI / 4.0
		ship.bind_heading(target)
		assert_eq(ship.frame, i)
		assert_almost_eq(ship.global_rotation, 0.0, 0.0001)
		target.rotation += 0.31
		ship._process(0.0)
		assert_eq(ship.frame, i)
		assert_almost_eq(ship.global_rotation, 0.31, 0.0001)
		assert_almost_eq(wrapf((float(ship.frame) - 2.0) * PI / 4.0 + ship.global_rotation - target.rotation, -PI, PI), 0.0, 0.0001)


func test_missing_atlas_is_not_replaced_with_a_different_ship() -> void:
	var target := Node2D.new()
	add_child_autofree(target)
	assert_null(PILOT.mount_atlas(target, "missing", 100.0))
	assert_eq(target.get_child_count(), 0)
