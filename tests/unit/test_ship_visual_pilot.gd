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


func test_all_approved_runtime_atlases_are_available_in_staged_build() -> void:
	# CI stages the approved ZIPs before Godot import.
	var root := "res://src/presentation/ship/pilot_atlases/"
	for id in ["SC-01", "SC-02", "SC-03", "SC-04", "SC-06", "SC-08", "M01", "M02"]:
		var texture := load(root + id + ".png") as Texture2D
		assert_not_null(texture, id)
		if texture != null:
			assert_eq(texture.get_width(), texture.get_height() * 2, id)
	assert_false(ResourceLoader.exists(root + "SC-07.png"))
	print("PLAY01_APPROVED_ATLASES_OK")
