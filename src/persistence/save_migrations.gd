class_name SaveMigrations
extends RefCounted

const LEGACY_SCHEMA_0 := 0
const LEGACY_SCHEMA_1 := 1
const LEGACY_CONTENT_VERSION := "fnd02-fixture-1"
const LEGACY_CONTENT_HASH := "8b9a1b829700f114e7b6a16daa14c4e2288e1e7ff9b36125e30f078c55d6b39d"
const PRG05_CONTENT_HASH := "beb8c26f0aac774639e4224b273ad93a231a2076b96a0be9c571cc48680b8e49"
const PRG05_CONTENT_COUNT := 23
const LEGACY_V0_MASTER_SEED := 10404
const LEGACY_V0_ENTITY_ID := "entity.player"


static func migrate(value: Variant) -> Dictionary:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return {"status": "invalid_dto"}
	var current: Dictionary = value.duplicate(true)
	var raw_schema: Variant = current.get("schema_version")
	if not _integer(raw_schema):
		return {"status": "invalid_schema"}
	var version := int(raw_schema)
	if version < LEGACY_SCHEMA_0:
		return {"status": "invalid_schema"}
	if version > DataContractVersions.SCHEMA_VERSION:
		return {"status": "unsupported_version"}
	var original_version := version
	while version < DataContractVersions.SCHEMA_VERSION:
		var validation := _validate_version(version, current)
		if not validation.is_empty():
			return {"status": validation}
		var next: Dictionary = {}
		match version:
			LEGACY_SCHEMA_0:
				next = _v0_to_v1(current)
			LEGACY_SCHEMA_1:
				next = _v1_to_v2(current)
			_:
				return {"status": "unsupported_version"}
		if next.is_empty() or not _integer(next.get("schema_version")) or int(next["schema_version"]) != version + 1:
			return {"status": "migration_failed"}
		current = next
		version += 1
		var step_validation := _validate_version(version, current)
		if version < DataContractVersions.SCHEMA_VERSION and not step_validation.is_empty():
			return {"status": step_validation}
	# Exact additive PRG-05 predecessor only; arbitrary content mismatches still fail closed.
	var content_migrated := false
	if current.get("content_hash") == PRG05_CONTENT_HASH and current.get("content_version") == DataContractVersions.CONTENT_VERSION:
		var stamp: Variant = current.get("content_manifest")
		if stamp is Dictionary and stamp.size() == 3 and stamp.get("algorithm") == ContentManifest.ALGORITHM and stamp.get("hash") == PRG05_CONTENT_HASH and _integer(stamp.get("entry_count")) and int(stamp["entry_count"]) == PRG05_CONTENT_COUNT and current.get("sector_id") in [FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.HAVEN_ID]:
			var new_hash := ContentManifest.current_hash()
			if not new_hash.is_empty() and new_hash != PRG05_CONTENT_HASH:
				current["content_hash"] = new_hash
				current["content_manifest"] = ContentManifest.metadata()
				content_migrated = true
	return {"status": "", "snapshot": current, "migrated": original_version != version or content_migrated}


static func _validate_version(version: int, dto: Dictionary) -> String:
	match version:
		LEGACY_SCHEMA_0:
			return _validate_v0(dto)
		LEGACY_SCHEMA_1:
			return _validate_v1(dto)
		DataContractVersions.SCHEMA_VERSION:
			return ""
		_:
			return "unsupported_version"


static func _validate_v0(dto: Dictionary) -> String:
	if dto.size() != 3 or int(dto.get("schema_version", -1)) != LEGACY_SCHEMA_0:
		return "bad_migration_shape"
	var sector: Variant = dto.get("sector")
	var player: Variant = dto.get("player")
	if sector != "foundation" or not player is Dictionary or player.size() != 2:
		return "bad_migration_shape"
	for key in ["x", "y"]:
		if typeof(player.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(player[key])):
			return "bad_migration_shape"
	return ""


static func _validate_v1(dto: Dictionary) -> String:
	if int(dto.get("schema_version", -1)) != LEGACY_SCHEMA_1:
		return "bad_migration_shape"
	if dto.get("content_version") != LEGACY_CONTENT_VERSION:
		return "unsupported_content"
	if dto.get("content_hash") != LEGACY_CONTENT_HASH:
		return "content_hash_mismatch"
	if int(dto.get("rng_stream_version", -1)) != DataContractVersions.RNG_STREAM_VERSION:
		return "unsupported_rng_version"
	if not SectorIds.valid(str(dto.get("sector_id", ""))):
		return "bad_migration_shape"
	var player: Variant = dto.get("player")
	if not player is Dictionary or player.size() != 2 or not SectorIds.valid(str(player.get("entity_id", ""))):
		return "bad_migration_shape"
	if not ShipMotor.valid_save_motion(player.get("motion")):
		return "bad_migration_shape"
	if not _valid_v1_rng(dto.get("rng")):
		return "invalid_rng"
	var ownership: Variant = dto.get("ownership")
	if not ownership is Dictionary or ownership.size() != 2 or ownership.get("kind") not in ["local", "host"] or not ownership.get("session_id") is String:
		return "bad_migration_shape"
	return ""


static func _v0_to_v1(dto: Dictionary) -> Dictionary:
	var player: Dictionary = dto["player"]
	var rng := SeedStreams.new(LEGACY_V0_MASTER_SEED).snapshot_state()
	rng["schema_version"] = LEGACY_SCHEMA_1
	rng["master_seed"] = str(rng["master_seed"])
	for name in SeedStreams.STREAM_NAMES:
		rng["streams"][name]["state"] = str(rng["streams"][name]["state"])
	return {
		"schema_version": LEGACY_SCHEMA_1,
		"content_version": LEGACY_CONTENT_VERSION,
		"rng_stream_version": DataContractVersions.RNG_STREAM_VERSION,
		"content_hash": LEGACY_CONTENT_HASH,
		"sector_id": FoundationSector.ID,
		"player": {
			"entity_id": LEGACY_V0_ENTITY_ID,
			"motion": {
				"x": float(player["x"]), "y": float(player["y"]), "heading": 0.0,
				"vx": 0.0, "vy": 0.0, "has_target": false,
				"target_x": float(player["x"]), "target_y": float(player["y"]), "desired_heading": 0.0,
			},
		},
		"rng": rng,
		"ownership": {"kind": "local", "session_id": ""},
	}


static func _v1_to_v2(dto: Dictionary) -> Dictionary:
	var result := dto.duplicate(true)
	var content_hash := ContentManifest.current_hash()
	if content_hash.is_empty():
		return {}
	result["schema_version"] = DataContractVersions.SCHEMA_VERSION
	result["content_version"] = DataContractVersions.CONTENT_VERSION
	result["rng_stream_version"] = DataContractVersions.RNG_STREAM_VERSION
	result["content_hash"] = content_hash
	result["content_manifest"] = ContentManifest.metadata()
	var rng: Dictionary = result["rng"]
	rng["schema_version"] = DataContractVersions.SCHEMA_VERSION
	result["rng"] = rng
	if not result.has("loot"):
		result["loot"] = SaveSnapshot.empty_loot_state()
	return result


static func _valid_v1_rng(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4:
		return false
	var dto: Dictionary = value
	if int(dto.get("schema_version", -1)) != LEGACY_SCHEMA_1 or int(dto.get("rng_stream_version", -1)) != DataContractVersions.RNG_STREAM_VERSION:
		return false
	var master_value: Variant = dto.get("master_seed")
	if not master_value is String or not master_value.is_valid_int() or str(int(master_value)) != master_value:
		return false
	var master := int(master_value)
	var streams: Variant = dto.get("streams")
	if not streams is Dictionary or streams.size() != SeedStreams.STREAM_NAMES.size():
		return false
	for name in SeedStreams.STREAM_NAMES:
		var entry: Variant = streams.get(name)
		if not entry is Dictionary or entry.size() != 2:
			return false
		var state_value: Variant = entry.get("state")
		if not state_value is String or not state_value.is_valid_int() or str(int(state_value)) != state_value:
			return false
		if not _integer(entry.get("derived_seed")) or int(entry["derived_seed"]) != SeedStreams.derive_stream_seed(master, name):
			return false
	return true


static func _integer(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
