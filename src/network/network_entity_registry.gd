class_name NetworkEntityRegistry
extends RefCounted

const PROTOCOL := preload("res://src/network/session_protocol.gd")

var _entries: Dictionary = {}
var _generations: Dictionary = {}
var _spatial_by_sector: Dictionary = {}


func next_generation(entity_id: String) -> int:
	if not PROTOCOL.valid_stable_id(entity_id):
		return -1
	var current := int(_generations.get(entity_id, 0))
	if current >= PROTOCOL.MAX_SEQUENCE:
		return -1
	return current + 1


func register_authority(payload: Dictionary, proxy: NetworkEntityProxy = null) -> bool:
	return _register(payload, true, proxy)


func register_mirror(payload: Dictionary, proxy: NetworkEntityProxy) -> bool:
	if proxy == null:
		return false
	return _register(payload, false, proxy)


func _register(payload: Dictionary, authority_owned: bool, proxy: NetworkEntityProxy) -> bool:
	if PROTOCOL.validate_spawn_payload(payload) != "":
		return false
	var entity_id := str(payload["entity_id"])
	var generation := int(payload["generation"])
	if _entries.has(entity_id) or generation <= int(_generations.get(entity_id, 0)):
		return false
	var row := _row_from_spawn(payload)
	if PROTOCOL.validate_snapshot_row(row) != "":
		return false
	_generations[entity_id] = generation
	_entries[entity_id] = {
		"authority": authority_owned,
		"generation": generation,
		"lifecycle_sequence": int(payload["lifecycle_sequence"]),
		"definition_id": str(payload["definition_id"]),
		"row": row,
		"proxy": proxy,
	}
	_index_insert(entity_id, str(row["sector_id"]), Vector2(float(row["x"]), float(row["y"])))
	return true


func attach_proxy(entity_id: String, generation: int, proxy: NetworkEntityProxy) -> bool:
	if proxy == null or not _entries.has(entity_id):
		return false
	var entry: Dictionary = _entries[entity_id]
	if int(entry["generation"]) != generation:
		return false
	entry["proxy"] = proxy
	return true


func has_entity(entity_id: String) -> bool:
	return _entries.has(entity_id)


func generation(entity_id: String) -> int:
	if not _entries.has(entity_id):
		return -1
	return int((_entries[entity_id] as Dictionary)["generation"])


func authority_owned(entity_id: String) -> bool:
	return _entries.has(entity_id) and bool((_entries[entity_id] as Dictionary)["authority"])


func entity_ids() -> Array[String]:
	var result: Array[String] = []
	for raw_id in _entries.keys():
		result.append(str(raw_id))
	result.sort()
	return result


func active_count() -> int:
	return _entries.size()


func proxy(entity_id: String) -> NetworkEntityProxy:
	if not _entries.has(entity_id):
		return null
	return (_entries[entity_id] as Dictionary).get("proxy") as NetworkEntityProxy


func state_row(entity_id: String) -> Dictionary:
	if not _entries.has(entity_id):
		return {}
	return ((_entries[entity_id] as Dictionary)["row"] as Dictionary).duplicate(true)


func spawn_payload_for(entity_id: String, state_sequence: int) -> Dictionary:
	if not _entries.has(entity_id):
		return {}
	var entry: Dictionary = _entries[entity_id]
	var row: Dictionary = entry["row"]
	return PROTOCOL.spawn_payload(
		entity_id,
		str(row["entity_kind"]),
		str(row["sector_id"]),
		str(entry.get("definition_id", "")),
		int(entry["generation"]),
		int(entry["lifecycle_sequence"]),
		state_sequence,
		row
	)


func update_authority_state(entity_id: String, changes: Dictionary) -> bool:
	if not _entries.has(entity_id):
		return false
	var entry: Dictionary = _entries[entity_id]
	if not bool(entry["authority"]) or not PROTOCOL.primitive_safe(changes):
		return false
	for key in changes.keys():
		if str(key) not in ["sector_id", "x", "y", "heading", "hull_ratio", "alive", "ai_state_id", "ai_intent_id"]:
			return false
	var previous: Dictionary = entry["row"]
	var row := previous.duplicate(true)
	for key in changes:
		row[key] = changes[key]
	if PROTOCOL.validate_snapshot_row(row) != "":
		return false
	var old_sector := str(previous["sector_id"])
	var new_sector := str(row["sector_id"])
	var old_position := Vector2(float(previous["x"]), float(previous["y"]))
	var new_position := Vector2(float(row["x"]), float(row["y"]))
	if old_sector != new_sector:
		_index_remove(entity_id, old_sector)
		_index_insert(entity_id, new_sector, new_position)
	elif old_position != new_position:
		var spatial := _spatial(new_sector)
		if spatial == null or not spatial.move(entity_id, new_position):
			return false
	entry["row"] = row
	var node := entry.get("proxy") as NetworkEntityProxy
	if node != null and is_instance_valid(node) and bool(entry["authority"]):
		node.sector_id = new_sector
	return true


func apply_snapshot_row(row: Dictionary, snapshot_sequence: int, server_tick: int) -> bool:
	if PROTOCOL.validate_snapshot_row(row) != "":
		return false
	var entity_id := str(row["entity_id"])
	if not _entries.has(entity_id):
		return false
	var entry: Dictionary = _entries[entity_id]
	if bool(entry["authority"]):
		return false
	var current: Dictionary = entry["row"]
	if str(current["entity_kind"]) != str(row["entity_kind"]):
		return false
	var node := entry.get("proxy") as NetworkEntityProxy
	if node == null or not is_instance_valid(node) or not node.apply_snapshot(row, snapshot_sequence, server_tick):
		return false
	var old_sector := str(current["sector_id"])
	var old_position := Vector2(float(current["x"]), float(current["y"]))
	var new_sector := str(row["sector_id"])
	var new_position := Vector2(float(row["x"]), float(row["y"]))
	if old_sector != new_sector:
		_index_remove(entity_id, old_sector)
		_index_insert(entity_id, new_sector, new_position)
	elif old_position != new_position:
		var spatial := _spatial(new_sector)
		if spatial != null:
			spatial.move(entity_id, new_position)
	entry["row"] = row.duplicate(true)
	return true


func visible_ids(sector_id: String, center: Vector2, radius: float, own_entity_id: String = "") -> Array[String]:
	var result: Array[String] = []
	if not PROTOCOL.valid_stable_id(sector_id) or not center.is_finite() or not is_finite(radius) or radius < 0.0 or radius > SectorSpatialHash.MAX_RADIUS:
		return result
	var spatial := _spatial(sector_id)
	if spatial != null:
		spatial.query_radius(center, radius, result)
	if not own_entity_id.is_empty() and _entries.has(own_entity_id) and not result.has(own_entity_id):
		result.append(own_entity_id)
	result.sort()
	return result


func set_proxy_visibility(visible_entity_ids: Array[String]) -> void:
	var visible_set: Dictionary = {}
	for entity_id in visible_entity_ids:
		visible_set[entity_id] = true
	for entity_id in entity_ids():
		var node := proxy(entity_id)
		if node != null and is_instance_valid(node):
			node.set_aoi_visible(visible_set.has(entity_id))


func remove(entity_id: String, generation_value: int) -> bool:
	if not _entries.has(entity_id):
		return false
	var entry: Dictionary = _entries[entity_id]
	if int(entry["generation"]) != generation_value:
		return false
	var row: Dictionary = entry["row"]
	_index_remove(entity_id, str(row["sector_id"]))
	_entries.erase(entity_id)
	return true


func clear() -> void:
	_entries.clear()
	_spatial_by_sector.clear()


func _row_from_spawn(payload: Dictionary) -> Dictionary:
	return {
		"entity_id": str(payload["entity_id"]),
		"entity_kind": str(payload["entity_kind"]),
		"sector_id": str(payload["sector_id"]),
		"x": float(payload["x"]),
		"y": float(payload["y"]),
		"heading": float(payload["heading"]),
		"hull_ratio": float(payload["hull_ratio"]),
		"alive": bool(payload["alive"]),
	}


func _spatial(sector_id: String) -> SectorSpatialHash:
	return _spatial_by_sector.get(sector_id) as SectorSpatialHash


func _ensure_spatial(sector_id: String) -> SectorSpatialHash:
	var spatial := _spatial(sector_id)
	if spatial == null:
		spatial = SectorSpatialHash.new()
		_spatial_by_sector[sector_id] = spatial
	return spatial


func _index_insert(entity_id: String, sector_id: String, position: Vector2) -> void:
	var spatial := _ensure_spatial(sector_id)
	spatial.insert(entity_id, position)


func _index_remove(entity_id: String, sector_id: String) -> void:
	var spatial := _spatial(sector_id)
	if spatial != null:
		spatial.remove(entity_id)
