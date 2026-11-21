class_name SaveService
extends RefCounted

const PRIMARY := "world.json"
const TEMP := "world.tmp"
const BACKUP := "world.bak"
const MAX_BYTES := 4194304
const OK_STATUS := "ok"
const RECOVERED := "recovered_backup"
const MISSING := "not_found"
const FAILED := "corrupt_save"
const CLEAN := "unchanged"

var _directory: String
var _dirty := false


func _init(directory: String = "user://seacraft-save") -> void:
	assert(directory.begins_with("user://") and not directory.contains(".."))
	_directory = directory


func create_snapshot(sector: SectorRuntime, entity_id: String, ship: ShipMotor, streams: SeedStreams,
		owner_kind: String = SaveSnapshot.LOCAL, session_id: String = "", loot_state: Dictionary = {},
		authoritative_state: Dictionary = {}) -> Dictionary:
	return SaveSnapshot.capture(sector, entity_id, ship, streams, owner_kind, session_id, loot_state, authoritative_state)


func validate_snapshot(dto: Variant) -> String:
	return SaveSnapshot.validate(dto)


func mark_dirty() -> void:
	_dirty = true


func is_dirty() -> bool:
	return _dirty


func has_save() -> bool:
	return FileAccess.file_exists(_path(PRIMARY)) or FileAccess.file_exists(_path(BACKUP))


func load() -> Dictionary:
	var primary := _read(PRIMARY)
	if primary["status"] == OK_STATUS or _blocked(primary["status"]):
		return primary
	return _fallback(primary)


func recover_backup() -> Dictionary:
	return self.load()


func save_if_dirty(dto: Dictionary) -> Dictionary:
	return save(dto) if _dirty else _result(CLEAN)


func save(dto: Dictionary) -> Dictionary:
	var migration := SaveSnapshot.migrate(dto)
	var migration_status := str(migration.get("status", "invalid_dto"))
	if not migration_status.is_empty():
		return _result(migration_status)
	var current: Dictionary = migration["snapshot"]
	var validation := SaveSnapshot.validate(current)
	if not validation.is_empty():
		return _result(validation)
	var encoded := JSON.stringify(SaveSnapshot.canonicalize(current), "	", true, true)
	if encoded.to_utf8_buffer().size() > MAX_BYTES:
		return _result("save_too_large")
	var primary := _read(PRIMARY)
	var primary_status: String = primary["status"]
	if _blocked(primary_status):
		return primary
	if primary_status != OK_STATUS:
		var previous := _fallback(primary)
		if previous["status"] != MISSING and previous["status"] != RECOVERED:
			return previous
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		return _result("directory_failed")
	var write_status := _write_temp(encoded)
	if not write_status.is_empty():
		return _result(write_status)
	if _verify(TEMP, encoded) != OK_STATUS:
		return _result("temp_verification_failed")
	if primary_status == OK_STATUS and _rename(PRIMARY, BACKUP) != OK:
		return _result("backup_rotate_failed")
	if _rename(TEMP, PRIMARY) != OK:
		return _result("primary_replace_failed")
	if _verify(PRIMARY, encoded) != OK_STATUS:
		return _result("primary_verification_failed")
	_dirty = false
	return _result(OK_STATUS)


func _write_temp(encoded: String) -> String:
	var file := FileAccess.open(_path(TEMP), FileAccess.WRITE)
	if file == null:
		return "temp_open_failed"
	var stored := file.store_string(encoded)
	file.flush()
	var write_error := file.get_error()
	file.close()
	return "" if stored and write_error == OK else "temp_write_failed"


func _verify(name: String, expected_text: String) -> String:
	return str(_read(name, expected_text).get("status", "read_failed"))


func _fallback(primary: Dictionary) -> Dictionary:
	var backup := _read(BACKUP)
	var status: String = backup["status"]
	if status == OK_STATUS:
		return {"status": RECOVERED, "snapshot": backup["snapshot"], "primary_status": primary["status"]}
	if _blocked(status):
		return {"status": status, "source": BACKUP, "primary_status": primary["status"]}
	if primary["status"] == MISSING and status == MISSING:
		return _result(MISSING)
	return {"status": FAILED, "primary_status": primary["status"], "backup_status": status}


func _path(name: String) -> String:
	return _directory.path_join(name)


func _rename(from: String, to: String) -> Error:
	return DirAccess.rename_absolute(_path(from), _path(to))


func _read(name: String, expected_text: String = "") -> Dictionary:
	var path := _path(name)
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var code := FileAccess.get_open_error()
		return _result(MISSING if code == ERR_FILE_NOT_FOUND else "read_failed")
	if file.get_length() > MAX_BYTES:
		file.close()
		return _result("save_too_large")
	var length := file.get_length()
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.size() != length:
		return _result("read_failed")
	var body := bytes.get_string_from_utf8()
	if not expected_text.is_empty() and body != expected_text:
		return _result("verification_mismatch")
	var trimmed := body.strip_edges()
	if not trimmed.begins_with("{") or not trimmed.ends_with("}"):
		return _result("invalid_json")
	var json := JSON.new()
	if json.parse(body) != OK:
		return _result("invalid_json")
	var migration := SaveSnapshot.migrate(json.data)
	var migration_status := str(migration.get("status", "invalid_dto"))
	if not migration_status.is_empty():
		return _result(migration_status)
	var current: Dictionary = migration["snapshot"]
	var validation := SaveSnapshot.validate(current)
	if not validation.is_empty():
		return _result(validation)
	return {"status": OK_STATUS, "snapshot": current, "migrated": bool(migration.get("migrated", false))}


static func _blocked(status: String) -> bool:
	return status.begins_with("unsupported_") or status in ["read_failed", "content_hash_mismatch", "unknown_content", "unknown_sector"]


static func _result(status: String) -> Dictionary:
	return {"status": status}
