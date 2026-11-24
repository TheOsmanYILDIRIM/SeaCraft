class_name ContentManifest
extends RefCounted

const INDEX_DIRECTORY := "res://src/data/registry/gameplay_index"
const ALGORITHM := "sha256"

static var _cached_hash := ""
static var _cached_count := -1


static func registry() -> DefinitionRegistry:
	var result := DefinitionRegistry.new()
	if result.build_from_index_directory(INDEX_DIRECTORY) != OK:
		return null
	return result


static func current_hash() -> String:
	if not _cached_hash.is_empty():
		return _cached_hash
	var current := registry()
	if current == null:
		return ""
	var verified_hash := current.manifest_hash()
	if verified_hash.is_empty() or current.indexed_count() <= 0:
		return ""
	_cached_hash = verified_hash
	_cached_count = current.indexed_count()
	return _cached_hash


static func current_entry_count() -> int:
	if _cached_count < 0:
		current_hash()
	return _cached_count


static func metadata() -> Dictionary:
	return {
		"algorithm": ALGORITHM,
		"hash": current_hash(),
		"entry_count": current_entry_count(),
	}


static func reset_cache_for_tests() -> void:
	_cached_hash = ""
	_cached_count = -1
