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
