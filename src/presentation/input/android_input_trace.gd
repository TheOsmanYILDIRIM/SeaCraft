extends RefCounted
## In-memory, local-only Android debug trace. Never writes saves or sends telemetry.

const LIMIT := 96
const BUILD_PATH := "res://seacraft_apk_commit.txt"
static var lines := PackedStringArray()
static var seq := 0
static var copy_button: Button


static func enabled() -> bool:
	return OS.has_feature("android") and OS.is_debug_build()


static func record(stage: String, details: String) -> void:
	if not enabled():
		return
	seq += 1
	if lines.size() >= LIMIT:
		lines.remove_at(0)
	lines.append("%d +%dms %s %s" % [seq, Time.get_ticks_msec(), stage, details.left(240)])


static func commit_sha() -> String:
	if not FileAccess.file_exists(BUILD_PATH):
		return "UNSTAMPED"
	var stamp := FileAccess.get_file_as_string(BUILD_PATH).strip_edges()
	return stamp if stamp.length() == 40 and stamp.is_valid_hex_number(false) else "INVALID"


static func attach(parent: Node) -> void:
	lines.clear()
	seq = 0
	var sha := commit_sha()
	var layer := CanvasLayer.new()
	layer.name = "AndroidDiagnostics"
	layer.layer = 96
	parent.add_child(layer)
	var button := Button.new()
	copy_button = button
	button.name = "CopyInputTrace"
	button.text = "Tanıyı kopyala · " + sha.left(12)
	button.focus_mode = Control.FOCUS_NONE
	layer.add_child(button)
	var place := func() -> void:
		var rect := parent.get_viewport().get_visible_rect()
		var button_size := button.get_minimum_size() + Vector2(24, 10)
		button.size = button_size
		button.position = Vector2(rect.end.x - button_size.x - 48.0, rect.position.y + 56.0)
	parent.get_viewport().size_changed.connect(place)
	place.call()
	button.pressed.connect(func() -> void:
		var header := "SeaCraft Android debug\ncommit=%s\nviewport=%s\n" % [sha, parent.get_viewport().get_visible_rect()]
		DisplayServer.clipboard_set(header + "\n".join(lines))
		button.text = "Kopyalandı · " + sha.left(12)
	)
	record("ready", "mouse_from_touch=%s native_pan_scale=%s" % [
		ProjectSettings.get_setting("input_devices/pointing/emulate_mouse_from_touch"),
		ProjectSettings.get_setting("input_devices/pointing/android/enable_pan_and_scale_gestures")])
