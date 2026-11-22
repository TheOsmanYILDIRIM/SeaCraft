class_name DefinitionRegistry
extends RefCounted

const VALID_DEFINITION_TYPES := [
	"ship", "weapon", "item", "faction", "sector",
	"ammo", "monster", "harpoon", "safe_zone", "loot_table", "ai_role",
]

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
		var loaded := ResourceLoader.load(entry_path, "", ResourceLoader.CACHE_MODE_IGNORE)
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
				return _fail("missing reference: %s -> %s" % [stable_id, referenced_id], ERR_INVALID_DATA)
	for stable_id in indexed_ids():
		if _load_entry(stable_id) == null:
			return ERR_INVALID_DATA
	last_error = ""
	return OK


func load_definition(stable_id: String) -> BaseDefinition:
	var value := load_content(stable_id)
	return value as BaseDefinition if value is BaseDefinition else null


func load_content(stable_id: String) -> Resource:
	last_error = ""
	return _load_entry(stable_id)


func has_id(stable_id: String) -> bool:
	return _entries_by_id.has(stable_id)


func definition_type(stable_id: String) -> String:
	var entry := _entries_by_id.get(stable_id) as DefinitionIndexEntry
	return entry.definition_type if entry != null else ""


func matches_type(stable_id: String, expected_type: String) -> bool:
	return has_id(stable_id) and definition_type(stable_id) == expected_type


func indexed_count() -> int:
	return _entries_by_id.size()


func indexed_ids() -> PackedStringArray:
	var ids := PackedStringArray()
	for stable_id in _entries_by_id:
		ids.append(str(stable_id))
	ids.sort()
	return ids


func manifest_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for stable_id in indexed_ids():
		var entry := _entries_by_id[stable_id] as DefinitionIndexEntry
		var refs := PackedStringArray()
		for reference in entry.referenced_ids:
			refs.append(reference)
		refs.sort()
		var resource_hash := _file_sha256(entry.definition_path)
		if resource_hash.is_empty():
			last_error = "manifest resource cannot be hashed: %s" % entry.definition_path
			return []
		rows.append({
			"stable_id": stable_id,
			"definition_type": entry.definition_type,
			"resource_path": entry.definition_path,
			"referenced_ids": refs,
			"resource_sha256": resource_hash,
		})
	return rows


func manifest_hash() -> String:
	var rows := manifest_rows()
	if rows.size() != _entries_by_id.size():
		return ""
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		last_error = "sha256 context failed"
		return ""
	for row in rows:
		var refs: PackedStringArray = row["referenced_ids"]
		var line := "%s|%s|%s|%s|%s\n" % [
			row["stable_id"], row["definition_type"], row["resource_path"],
			",".join(refs), row["resource_sha256"],
		]
		context.update(line.to_utf8_buffer())
	return context.finish().hex_encode()


func _load_entry(stable_id: String) -> Resource:
	if not _entries_by_id.has(stable_id):
		_fail("unknown stable ID: %s" % stable_id, ERR_DOES_NOT_EXIST)
		return null
	var entry := _entries_by_id[stable_id] as DefinitionIndexEntry
	var loaded := ResourceLoader.load(entry.definition_path, "", ResourceLoader.CACHE_MODE_IGNORE)
	if loaded == null:
		_fail("definition resource cannot be loaded: %s" % entry.definition_path, ERR_PARSE_ERROR)
		return null
	var content: Resource
	var actual_type := ""
	var actual_refs := PackedStringArray()
	if entry.definition_type == "loot_table":
		if not (loaded is LootTable):
			_fail("definition type/index mismatch for %s" % stable_id, ERR_INVALID_DATA)
			return null
		var table := loaded as LootTable
		if table.stable_id != stable_id or not table.valid():
			_fail("stable ID/index mismatch: %s" % stable_id, ERR_INVALID_DATA)
			return null
		content = table
		actual_type = "loot_table"
		for item in table.entries:
			if item != null:
				actual_refs.append(item.item_id)
	elif entry.definition_type == "safe_zone":
		if not (loaded is SectorDefinition):
			_fail("safe-zone adapter requires SectorDefinition: %s" % entry.definition_path, ERR_INVALID_DATA)
			return null
		var sector := loaded as SectorDefinition
		for zone in sector.safe_zones:
			if zone != null and zone.stable_id == stable_id:
				content = zone
				break
		if content == null:
			_fail("safe-zone index/resource ID mismatch: %s" % stable_id, ERR_INVALID_DATA)
			return null
		actual_type = "safe_zone"
		actual_refs = (content as SafeZoneDefinition).referenced_stable_ids()
	else:
		if not (loaded is BaseDefinition):
			_fail("definition is not a BaseDefinition: %s" % entry.definition_path, ERR_PARSE_ERROR)
			return null
		var definition := loaded as BaseDefinition
		if definition.stable_id != stable_id:
			_fail("stable ID/index mismatch: %s != %s" % [definition.stable_id, stable_id], ERR_INVALID_DATA)
			return null
		if definition is NpcRoleProfile and not (definition as NpcRoleProfile).valid():
			_fail("invalid AI role profile: %s" % stable_id, ERR_INVALID_DATA)
			return null
		if definition is ItemDefinition and not (definition as ItemDefinition).valid():
			_fail("invalid item definition: %s" % stable_id, ERR_INVALID_DATA)
			return null
		actual_type = definition.definition_type()
		actual_refs = definition.referenced_stable_ids()
		content = definition
	if actual_type != entry.definition_type:
		_fail("definition type/index mismatch for %s: %s != %s" % [stable_id, actual_type, entry.definition_type], ERR_INVALID_DATA)
		return null
	var expected_refs := entry.referenced_ids.duplicate()
	expected_refs.sort()
	actual_refs.sort()
	if expected_refs != actual_refs:
		_fail("reference/index mismatch for stable ID: %s" % stable_id, ERR_INVALID_DATA)
		return null
	return content


func _validate_entry(entry: DefinitionIndexEntry, entry_path: String) -> Error:
	if not SectorIds.valid(entry.stable_id):
		return _fail("index entry has invalid stable ID: %s" % entry_path, ERR_INVALID_DATA)
	if not VALID_DEFINITION_TYPES.has(entry.definition_type):
		return _fail("index entry has unsupported definition type: %s" % entry.definition_type, ERR_INVALID_DATA)
	if not entry.definition_path.begins_with("res://"):
		return _fail("definition path must be a res:// resource: %s" % entry.definition_path, ERR_INVALID_DATA)
	if not ResourceLoader.exists(entry.definition_path):
		return _fail("definition resource is missing: %s" % entry.definition_path, ERR_FILE_NOT_FOUND)
	return OK


static func _file_sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var bytes := file.get_buffer(file.get_length())
	file.close()
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return ""
	context.update(bytes)
	return context.finish().hex_encode()


func _fail(message: String, error: Error) -> Error:
	last_error = message
	return error
