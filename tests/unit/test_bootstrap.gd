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
