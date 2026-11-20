class_name SaveSnapshot
extends RefCounted

# SHA-256 of newline-terminated Git blob IDs for the movement profile, sector
# definition and authored foundation graph (in that order). Bump on content changes.
const CONTENT_HASH := "b379fac338fb4ae59b52e9559180a97c9dedd90ff3463d7183ec7ab0ea0605d6"
const LOCAL := "local"
const HOST := "host"

static func capture(sector: SectorRuntime, entity_id: String, ship: ShipMotor, streams: SeedStreams,
		owner_kind: String = LOCAL, session_id: String = "") -> Dictionary:
	if sector == null or ship == null or streams == null or not ship.authority_enabled:
		return {}
	if not sector.entity_position(entity_id).is_finite():
		return {}
	var dto := DataContractVersions.compatibility_stamp()
	var rng := streams.snapshot_state()
	# JSON numbers parse as doubles. Decimal strings preserve signed 64-bit state.
	rng["master_seed"] = str(rng["master_seed"])
	for name in SeedStreams.STREAM_NAMES:
		rng["streams"][name]["state"] = str(rng["streams"][name]["state"])
	dto["content_hash"] = CONTENT_HASH
	dto["sector_id"] = sector.sector_id
	dto["player"] = {"entity_id": entity_id, "motion": ship.capture_save_motion()}
	dto["rng"] = rng
	dto["ownership"] = {"kind": owner_kind, "session_id": session_id}
	return dto


static func validate(value: Variant) -> String:
	if not value is Dictionary or not _safe(value, 0) or not DtoContract.is_primitive_safe(value):
		return "invalid_dto"
	var dto: Dictionary = value
	var schema: Variant = dto.get("schema_version")
	if not _integer_number(schema):
		return "invalid_schema"
	# Explicit dispatch: add sequential migrations here as historical schemas become supported.
	match int(schema):
		DataContractVersions.SCHEMA_VERSION:
			return _validate_current(dto)
		_:
			return "unsupported_version"


static func _validate_current(dto: Dictionary) -> String:
	if not dto.get("content_version") is String or not dto.get("content_hash") is String:
		return "invalid_content_stamp"
	if dto["content_version"] != DataContractVersions.CONTENT_VERSION or dto["content_hash"] != CONTENT_HASH:
		return "unsupported_content"
	if not _integer_number(dto.get("rng_stream_version")):
		return "invalid_rng"
	if dto["rng_stream_version"] != DataContractVersions.RNG_STREAM_VERSION:
		return "unsupported_rng_version"
	if dto.size() != 8 or not _stable(dto.get("sector_id")):
		return "invalid_sector"
	var player: Variant = dto.get("player")
	if not player is Dictionary or player.size() != 2 or not _stable(player.get("entity_id")):
		return "invalid_player"
	if not ShipMotor.valid_save_motion(player.get("motion")):
		return "invalid_motion"
	var owner: Variant = dto.get("ownership")
	if not owner is Dictionary or owner.size() != 2 or not owner.get("kind") is String or not owner.get("session_id") is String:
		return "invalid_ownership"
	if owner["kind"] not in [LOCAL, HOST]:
		return "invalid_ownership"
	if (owner["kind"] == HOST or owner["session_id"] != "") and not _stable(owner["session_id"]):
		return "invalid_ownership"
	return "" if not _decoded_rng(dto.get("rng")).is_empty() else "invalid_rng"


static func restore(dto: Dictionary, world: SectorWorld, authority: RefCounted, entity_id: String,
		ship: ShipMotor, streams: SeedStreams) -> String:
	var error := validate(dto)
	if not error.is_empty():
		return error
	if dto["player"]["entity_id"] != entity_id:
		return "unknown_entity"
	if world == null or ship == null or streams == null or not ship.authority_enabled:
		return "invalid_restore_target"
	var motion: Dictionary = dto["player"]["motion"]
	error = world.restore_active(authority, dto["sector_id"], entity_id, Vector2(motion["x"], motion["y"]))
	if not error.is_empty():
		return error
	# All remaining inputs were validated before replacing the active runtime.
	ship.restore_save_motion(motion)
	streams.restore_state(_decoded_rng(dto["rng"]))
	return ""


static func _decoded_rng(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 4:
		return {}
	var dto: Dictionary = value
	if not _integer_number(dto.get("schema_version")) or dto["schema_version"] != DataContractVersions.SCHEMA_VERSION:
		return {}
	if not _integer_number(dto.get("rng_stream_version")) or dto["rng_stream_version"] != DataContractVersions.RNG_STREAM_VERSION:
		return {}
	if not _decimal_int(dto.get("master_seed")):
		return {}
	var master := int(dto["master_seed"])
	var source: Variant = dto.get("streams")
	if not source is Dictionary or source.size() != SeedStreams.STREAM_NAMES.size():
		return {}
	var streams: Dictionary = {}
	for name in SeedStreams.STREAM_NAMES:
		var entry: Variant = source.get(name)
		if not entry is Dictionary or entry.size() != 2 or not _decimal_int(entry.get("state")):
			return {}
		var seed := SeedStreams.derive_stream_seed(master, name)
		if not _integer_number(entry.get("derived_seed")) or entry["derived_seed"] != seed:
			return {}
		streams[name] = {"derived_seed": seed, "state": int(entry["state"])}
	return {"schema_version": DataContractVersions.SCHEMA_VERSION,
		"rng_stream_version": DataContractVersions.RNG_STREAM_VERSION, "master_seed": master, "streams": streams}


static func _decimal_int(value: Variant) -> bool:
	return value is String and value.length() <= 20 and value.is_valid_int() and str(int(value)) == value


static func _integer_number(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and absf(number) <= 2147483647.0 and number == floorf(number)


static func _stable(value: Variant) -> bool:
	return value is String and SectorIds.valid(value)


# Bounds recursive input before invoking the shared DTO contract, including cyclic inputs.
static func _safe(value: Variant, depth: int) -> bool:
	if depth > 8:
		return false
	match typeof(value):
		TYPE_STRING:
			return value.length() <= 128
		TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_DICTIONARY:
			if value.size() > 16:
				return false
			for key in value:
				if typeof(key) != TYPE_STRING or key.length() > 64 or not _safe(value[key], depth + 1):
					return false
			return true
		_:
			return false
