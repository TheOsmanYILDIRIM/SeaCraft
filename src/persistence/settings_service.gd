class_name SettingsService
extends RefCounted

const FILE_NAME := "settings.json"
const TEMP_NAME := "settings.tmp"
const MAX_BYTES := 32768
const OK_STATUS := "ok"
const MISSING := "not_found"

var _directory: String


func _init(directory: String = "user://seacraft-settings") -> void:
	assert(directory.begins_with("user://") and not directory.contains(".."))
	_directory = directory


func save(settings: Dictionary) -> Dictionary:
	var error := validate(settings)
	if not error.is_empty():
		return {"status": error}
	var encoded := JSON.stringify(_canonical(settings), "	", true, true)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return {"status": "settings_too_large"}
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return {"status": "directory_failed"}
	var file := FileAccess.open(_path(TEMP_NAME), FileAccess.WRITE)
	if file == null:
		return {"status": "settings_write_failed"}
	var stored := file.store_string(encoded)
	file.flush()
	var io_error := file.get_error()
	file.close()
	if not stored or io_error != OK:
		return {"status": "settings_write_failed"}
	if DirAccess.rename_absolute(_path(TEMP_NAME), _path(FILE_NAME)) != OK:
		return {"status": "settings_replace_failed"}
	return {"status": OK_STATUS}


func load() -> Dictionary:
	var file := FileAccess.open(_path(FILE_NAME), FileAccess.READ)
	if file == null:
		return {"status": MISSING}
	if file.get_length() > MAX_BYTES:
		file.close()
		return {"status": "settings_too_large"}
	var body := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(body) != OK:
		return {"status": "invalid_settings"}
	var error := validate(json.data)
	return {"status": OK_STATUS, "settings": json.data} if error.is_empty() else {"status": error}


static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 3 or not DtoContract.is_primitive_safe(value):
		return "invalid_settings"
	for key in ["graphics", "audio", "controls"]:
		var group: Variant = value.get(key)
		if not group is Dictionary or group.size() > 32:
			return "invalid_settings"
	for forbidden in ["world", "entities", "inventory", "rng", "loot", "combat", "authoritative_state"]:
		if value.has(forbidden):
			return "authority_in_settings"
	return ""


func _path(name: String) -> String:
	return _directory.path_join(name)


static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	return value
