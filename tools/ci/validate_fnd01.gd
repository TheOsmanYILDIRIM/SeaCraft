extends SceneTree

var _failures: Array[String] = []


func _initialize() -> void:
	_check_setting("application/run/main_scene", "res://src/presentation/bootstrap.tscn")
	_check_setting("rendering/renderer/rendering_method", "gl_compatibility")
	_check_setting("rendering/renderer/rendering_method.mobile", "gl_compatibility")
	_check_setting("rendering/textures/vram_compression/import_etc2_astc", true)
	_check_setting("display/window/handheld/orientation", 0)
	_check_setting("display/window/size/viewport_width", 1280)
	_check_setting("display/window/size/viewport_height", 720)
	_check_setting("display/window/stretch/mode", "canvas_items")
	_check_setting("display/window/stretch/aspect", "expand")
	_check_expected_autoloads()
	_check_required_paths()
	_check_bootstrap_scene()
	_check_export_presets()

	if _failures.is_empty():
		print("FND-01 validation passed")
		quit(0)
		return

	for failure in _failures:
		printerr("FND-01 validation failure: %s" % failure)
	quit(1)


func _check_setting(key: String, expected: Variant) -> void:
	var actual: Variant = ProjectSettings.get_setting(key, null)
	if actual != expected:
		_failures.append("%s expected %s, got %s" % [key, expected, actual])


func _check_expected_autoloads() -> void:
	var expected := {
		"autoload/BeehaveGlobalMetrics": "*res://addons/beehave/metrics/beehave_global_metrics.gd",
		"autoload/BeehaveGlobalDebugger": "*res://addons/beehave/debug/global_debugger.gd",
	}
	var seen: Dictionary = {}
	for property in ProjectSettings.get_property_list():
		var key := str(property.get("name", ""))
		if not key.begins_with("autoload/"):
			continue
		if not expected.has(key):
			_failures.append("unexpected autoload: %s" % key)
			continue
		var actual := str(ProjectSettings.get_setting(key, ""))
		if actual != expected[key]:
			_failures.append("%s expected %s, got %s" % [key, expected[key], actual])
		seen[key] = true
	for key in expected:
		if not seen.has(key):
			_failures.append("missing required AI-01 runtime autoload: %s" % key)


func _check_required_paths() -> void:
	for path in [
		"res://src/simulation",
		"res://src/presentation",
		"res://src/data",
		"res://tests",
	]:
		if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path)):
			_failures.append("missing boundary directory: %s" % path)


func _check_bootstrap_scene() -> void:
	var packed := load("res://src/presentation/bootstrap.tscn") as PackedScene
	if packed == null:
		_failures.append("bootstrap scene could not be loaded")
		return
	var instance := packed.instantiate()
	if instance == null:
		_failures.append("bootstrap scene could not be instantiated")
		return
	if instance.name != "Bootstrap":
		_failures.append("bootstrap root must be named Bootstrap")
	instance.free()


func _check_export_presets() -> void:
	var config := ConfigFile.new()
	var err := config.load("res://export_presets.cfg")
	if err != OK:
		_failures.append("export_presets.cfg parse error: %s" % error_string(err))
		return

	var found_linux := false
	var found_android := false
	for section in config.get_sections():
		if not section.begins_with("preset.") or section.ends_with(".options"):
			continue
		var platform := str(config.get_value(section, "platform", ""))
		if platform == "Linux":
			found_linux = true
		if platform == "Android":
			found_android = true
			var export_path := str(config.get_value(section, "export_path", ""))
			if not export_path.ends_with(".apk"):
				_failures.append("Android preset export_path must be an APK")

	if not found_linux:
		_failures.append("Linux desktop export preset missing")
	if not found_android:
		_failures.append("Android export preset missing")
