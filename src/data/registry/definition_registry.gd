class_name DefinitionRegistry
extends RefCounted

const VALID_DEFINITION_TYPES := ["ship", "weapon", "item", "faction", "sector"]

var last_error: String = ""
var _entries_by_id: Dictionary = {}


func build_from_index_directory(index_directory: String) -> Error:
	_entries_by_id.clear()
	last_error = ""

	var directory := DirAccess.open(index_directory)
	if directory == null:
		return _fail("index directory cannot be opened: %s" % index_directory, ERR_CANT_OPEN)

	var file_names := directory.get_files()
	file_names.sort()

	for file_name in file_names:
		if file_name.get_extension().to_lower() != "tres":
			continue

		var entry_path := index_directory.path_join(file_name)
		var loaded := ResourceLoader.load(
			entry_path,
			"",
			ResourceLoader.CACHE_MODE_IGNORE
		)
		if loaded == null or not (loaded is DefinitionIndexEntry):
			return _fail("index entry is not a DefinitionIndexEntry: %s" % entry_path, ERR_PARSE_ERROR)

		var entry := loaded as DefinitionIndexEntry
		var validation_error := _validate_entry(entry, entry_path)
		if validation_error != OK:
			return validation_error

		if _entries_by_id.has(entry.stable_id):
			return _fail("duplicate stable ID: %s" % entry.stable_id, ERR_INVALID_DATA)

		_entries_by_id[entry.stable_id] = entry

	for stable_id in _entries_by_id:
		var entry := _entries_by_id[stable_id] as DefinitionIndexEntry
		for referenced_id in entry.referenced_ids:
			if referenced_id.is_empty():
				return _fail("empty reference in definition: %s" % stable_id, ERR_INVALID_DATA)
			if not _entries_by_id.has(referenced_id):
				return _fail(
					"missing reference: %s -> %s" % [stable_id, referenced_id],
					ERR_INVALID_DATA
				)

	return OK


func load_definition(stable_id: String) -> BaseDefinition:
	last_error = ""
	if not _entries_by_id.has(stable_id):
		_fail("unknown stable ID: %s" % stable_id, ERR_DOES_NOT_EXIST)
		return null

	var entry := _entries_by_id[stable_id] as DefinitionIndexEntry
	var loaded := ResourceLoader.load(
		entry.resource_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if loaded == null or not (loaded is BaseDefinition):
		_fail("definition is not a BaseDefinition: %s" % entry.resource_path, ERR_PARSE_ERROR)
		return null

	var definition := loaded as BaseDefinition
	if definition.stable_id != stable_id:
		_fail(
			"stable ID/index mismatch: %s != %s" % [definition.stable_id, stable_id],
			ERR_INVALID_DATA
		)
		return null
	if definition.definition_type() != entry.definition_type:
		_fail(
			"definition type/index mismatch for %s: %s != %s"
			% [stable_id, definition.definition_type(), entry.definition_type],
			ERR_INVALID_DATA
		)
		return null

	var expected_refs := entry.referenced_ids.duplicate()
	var actual_refs := definition.referenced_stable_ids()
	expected_refs.sort()
	actual_refs.sort()
	if expected_refs != actual_refs:
		_fail("reference/index mismatch for stable ID: %s" % stable_id, ERR_INVALID_DATA)
		return null

	return definition


func has_id(stable_id: String) -> bool:
	return _entries_by_id.has(stable_id)


func indexed_count() -> int:
	return _entries_by_id.size()


func indexed_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for stable_id in _entries_by_id:
		ids.append(str(stable_id))
	ids.sort()
	return ids


func _validate_entry(entry: DefinitionIndexEntry, entry_path: String) -> Error:
	if entry.stable_id.is_empty():
		return _fail("index entry has empty stable ID: %s" % entry_path, ERR_INVALID_DATA)
	if not VALID_DEFINITION_TYPES.has(entry.definition_type):
		return _fail(
			"index entry has unsupported definition type: %s" % entry.definition_type,
			ERR_INVALID_DATA
		)
	if not entry.resource_path.begins_with("res://"):
		return _fail(
			"definition path must be a res:// resource: %s" % entry.resource_path,
			ERR_INVALID_DATA
		)
	if not ResourceLoader.exists(entry.resource_path):
		return _fail("definition resource is missing: %s" % entry.resource_path, ERR_FILE_NOT_FOUND)
	return OK


func _fail(message: String, error: Error) -> Error:
	last_error = message
	return error
