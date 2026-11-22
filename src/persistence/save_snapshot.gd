class_name SaveSnapshot
extends RefCounted

const LOCAL := "local"
const HOST := "host"
const MAX_DEPTH := 12
const MAX_CONTAINER_ITEMS := 4096
const MAX_LOOT_DROPS := 2048
const MAX_LEDGER_ENTRIES := 4096


static func capture(sector: SectorRuntime, entity_id: String, ship: ShipMotor, streams: SeedStreams,
		owner_kind: String = LOCAL, session_id: String = "", loot_state: Dictionary = {},
		authoritative_state: Dictionary = {}) -> Dictionary:
	if sector == null or ship == null or streams == null or not ship.authority_enabled:
		return {}
	if not sector.entity_position(entity_id).is_finite():
		return {}
	var content_hash := ContentManifest.current_hash()
	if content_hash.is_empty():
		return {}
	var dto := DataContractVersions.compatibility_stamp()
	var rng := streams.snapshot_state()
	rng["master_seed"] = str(rng["master_seed"])
	for name in SeedStreams.STREAM_NAMES:
		rng["streams"][name]["state"] = str(rng["streams"][name]["state"])
	dto["content_hash"] = content_hash
	dto["content_manifest"] = ContentManifest.metadata()
	dto["sector_id"] = sector.sector_id
	dto["player"] = {"entity_id": entity_id, "motion": ship.capture_save_motion()}
	dto["rng"] = rng
	dto["ownership"] = {"kind": owner_kind, "session_id": session_id}
	dto["loot"] = loot_state.duplicate(true) if not loot_state.is_empty() else empty_loot_state()
	if not authoritative_state.is_empty():
		dto["authoritative_state"] = authoritative_state.duplicate(true)
	return dto


static func migrate(value: Variant) -> Dictionary:
	if not _safe(value, 0):
		return {"status": "invalid_dto"}
	return SaveMigrations.migrate(value)


static func validate(value: Variant) -> String:
	var migration := migrate(value)
	var status := str(migration.get("status", "invalid_dto"))
	if not status.is_empty():
		return status
	return _validate_current(migration["snapshot"])


static func _validate_current(dto: Dictionary) -> String:
	if not _safe(dto, 0) or not DtoContract.is_primitive_safe(dto):
		return "invalid_dto"
	if not _integer_number(dto.get("schema_version")) or int(dto["schema_version"]) != DataContractVersions.SCHEMA_VERSION:
		return "unsupported_version"
	if dto.get("content_version") != DataContractVersions.CONTENT_VERSION:
		return "unsupported_content"
	var expected_hash := ContentManifest.current_hash()
	if expected_hash.is_empty():
		return "content_registry_unavailable"
	if dto.get("content_hash") != expected_hash:
		return "content_hash_mismatch"
	var manifest: Variant = dto.get("content_manifest")
	if not manifest is Dictionary or manifest.size() != 3 or manifest.get("algorithm") != ContentManifest.ALGORITHM:
		return "invalid_content_stamp"
	if manifest.get("hash") != expected_hash or int(manifest.get("entry_count", -1)) != ContentManifest.current_entry_count():
		return "content_hash_mismatch"
	if not _integer_number(dto.get("rng_stream_version")) or int(dto["rng_stream_version"]) != DataContractVersions.RNG_STREAM_VERSION:
		return "unsupported_rng_version"
	if not _stable(dto.get("sector_id")):
		return "invalid_sector"
	var registry := ContentManifest.registry()
	if registry == null:
		return "content_registry_unavailable"
	if not registry.matches_type(dto["sector_id"], "sector"):
		return "unknown_sector"
	if dto.has("loot"):
		var loot_error := _validate_loot(dto["loot"], registry)
		if not loot_error.is_empty():
			return loot_error
	if dto.has("authoritative_state"):
		var authoritative: Variant = dto["authoritative_state"]
		if not authoritative is Dictionary or authoritative.is_empty() or not _safe(authoritative, 0) or not DtoContract.is_primitive_safe(authoritative):
			return "invalid_authoritative_state"
		var content_error := _validate_authoritative_content(authoritative, registry)
		if not content_error.is_empty():
			return content_error
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
	var migration := migrate(dto)
	var status := str(migration.get("status", "invalid_dto"))
	if not status.is_empty():
		return status
	var current: Dictionary = migration["snapshot"]
	var error := _validate_current(current)
	if not error.is_empty():
		return error
	if current["player"]["entity_id"] != entity_id:
		return "unknown_entity"
	if world == null or ship == null or streams == null or not ship.authority_enabled:
		return "invalid_restore_target"
	var decoded_rng := _decoded_rng(current["rng"])
	if decoded_rng.is_empty():
		return "invalid_rng"
	var rng_probe := SeedStreams.new(1)
	if not rng_probe.restore_state(decoded_rng):
		return "invalid_rng"
	var motion: Dictionary = current["player"]["motion"]
	var authority_state := authoritative_state(current)
	var world_state: Variant = authority_state.get("sector_world")
	if world_state is Dictionary:
		if world_state.get("active_sector") != current["sector_id"]:
			return "invalid_world_state"
		error = world.restore_state(authority, world_state, entity_id, Vector2(motion["x"], motion["y"]))
	else:
		error = world.restore_active(authority, current["sector_id"], entity_id, Vector2(motion["x"], motion["y"]))
	if not error.is_empty():
		return error
	ship.restore_save_motion(motion)
	if not streams.restore_state(decoded_rng):
		return "invalid_rng"
	return ""


static func canonicalize(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = canonicalize(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(canonicalize(item))
		return result
	return value


static func empty_loot_state() -> Dictionary:
	return {"drops": [], "claimed_ids": [], "inventory": {}, "processed_events": {}}


static func loot_state(dto: Dictionary) -> Dictionary:
	var migration := migrate(dto)
	if str(migration.get("status", "")) != "":
		return empty_loot_state()
	var current: Dictionary = migration["snapshot"]
	return (current.get("loot", empty_loot_state()) as Dictionary).duplicate(true)


static func authoritative_state(dto: Dictionary) -> Dictionary:
	var value: Variant = dto.get("authoritative_state", {})
	return (value as Dictionary).duplicate(true) if value is Dictionary else {}


static func _validate_loot(value: Variant, registry: DefinitionRegistry) -> String:
	if not value is Dictionary or value.size() != 4:
		return "invalid_loot"
	var loot: Dictionary = value
	if not loot.get("drops") is Array or not loot.get("claimed_ids") is Array or not loot.get("inventory") is Dictionary or not loot.get("processed_events") is Dictionary:
		return "invalid_loot"
	if loot["drops"].size() > MAX_LOOT_DROPS or loot["claimed_ids"].size() > MAX_LEDGER_ENTRIES or loot["inventory"].size() > 128 or loot["processed_events"].size() > MAX_LEDGER_ENTRIES:
		return "invalid_loot"
	var seen: Dictionary = {}
	for raw in loot["drops"]:
		if not raw is Dictionary or raw.size() != 6:
			return "invalid_loot"
		var drop: Dictionary = raw
		var drop_id: Variant = drop.get("drop_id")
		if not drop_id is String or not _stable(drop_id) or seen.has(drop_id) or loot["claimed_ids"].has(drop_id):
			return "invalid_loot"
		if not _stable(drop.get("sector_id")) or not registry.matches_type(drop["sector_id"], "sector"):
			return "unknown_sector"
		if not _stable(drop.get("item_id")) or not registry.matches_type(drop["item_id"], "item"):
			return "unknown_content"
		if not _integer_number(drop.get("quantity")) or int(drop["quantity"]) <= 0:
			return "invalid_loot"
		if typeof(drop.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(drop.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return "invalid_loot"
		if not is_finite(float(drop["x"])) or not is_finite(float(drop["y"])):
			return "invalid_loot"
		seen[drop_id] = true
	for drop_id in loot["claimed_ids"]:
		if not drop_id is String or not _stable(drop_id):
			return "invalid_loot"
	for item_id in loot["inventory"]:
		if not item_id is String or not registry.matches_type(item_id, "item"):
			return "unknown_content"
		if not _integer_number(loot["inventory"][item_id]) or int(loot["inventory"][item_id]) < 0:
			return "invalid_loot"
	for event_id in loot["processed_events"]:
		var drop_id: Variant = loot["processed_events"][event_id]
		if not event_id is String or not _stable(event_id) or not drop_id is String or (not drop_id.is_empty() and not _stable(drop_id)):
			return "invalid_loot"
		if not drop_id.is_empty() and drop_id != event_id and not seen.has(drop_id) and not loot["claimed_ids"].has(drop_id):
			return "ledger_reference_mismatch"
	for claimed_id in loot["claimed_ids"]:
		var referenced := false
		for event_id in loot["processed_events"]:
			if loot["processed_events"][event_id] == claimed_id:
				referenced = true
				break
		if not referenced:
			return "ledger_reference_mismatch"
	return ""


static func _validate_authoritative_content(authoritative: Dictionary, registry: DefinitionRegistry) -> String:
	if authoritative.has("progression"):
		var progression: Variant = authoritative["progression"]
		if not InventoryState.validate_progression_state(progression):
			return "invalid_progression_state"
		if progression is Dictionary and int((progression as Dictionary).get("version", 0)) == InventoryState.VERSION:
			if not Prg02ProgressionState.validate_content_refs((progression as Dictionary).get("prg02"), registry):
				return "unknown_progression_content"
			if not Prg03ProgressionState.validate_content_refs((progression as Dictionary).get("prg03"), registry):
				return "unknown_progression_content"
		if progression is Dictionary and int((progression as Dictionary).get("version", 0)) == InventoryState.VERSION:
			if not Prg04QuestState.validate_content_refs((progression as Dictionary).get("prg04"), registry):
				return "unknown_quest_content"
	if authoritative.has("entity_index"):
		var index_error := PersistentEntityIndex.validate(authoritative["entity_index"], registry)
		if not index_error.is_empty():
			return index_error
	if authoritative.has("ai04_world"):
		var ai04_error := WorldSimulationAuthority.validate_snapshot(authoritative["ai04_world"], registry)
		if not ai04_error.is_empty():
			return ai04_error
	if authoritative.has("combat"):
		var combat: Variant = authoritative["combat"]
		if not combat is Dictionary or not combat.get("combatants") is Array:
			return "invalid_authoritative_state"
		for raw in combat["combatants"]:
			if not raw is Dictionary:
				return "invalid_authoritative_state"
			var combat_sector: Variant = raw.get("sector_id", "")
			if not combat_sector is String or not registry.matches_type(combat_sector, "sector"):
				return "unknown_sector"
			var core: Variant = raw.get("core", {})
			if core is Dictionary:
				var ammo: Variant = core.get("selected_ammo", "")
				if ammo is String and not ammo.is_empty() and not registry.matches_type(ammo, "ammo"):
					return "unknown_content"
	if authoritative.has("world"):
		var object_state: Variant = authoritative["world"]
		if not object_state is Dictionary or not object_state.get("objects", []) is Array:
			return "invalid_authoritative_state"
		for raw_object in object_state["objects"]:
			if not raw_object is Dictionary:
				return "invalid_authoritative_state"
			var object_sector: Variant = raw_object.get("sector_id", "")
			if not object_sector is String or not registry.matches_type(object_sector, "sector"):
				return "unknown_sector"
	if authoritative.has("npc_ai"):
		var npc_ai: Variant = authoritative["npc_ai"]
		if not npc_ai is Dictionary:
			return "invalid_authoritative_state"
		var role_profile: Variant = npc_ai.get("role_profile_id", "")
		if not role_profile is String or (not role_profile.is_empty() and not registry.matches_type(role_profile, "ai_role")):
			return "unknown_content"
	if authoritative.has("sector_world"):
		var state: Variant = authoritative["sector_world"]
		if not state is Dictionary:
			return "invalid_world_state"
		var active: Variant = state.get("active_sector")
		if not active is String or not registry.matches_type(active, "sector"):
			return "unknown_sector"
		var dormant: Variant = state.get("dormant", {})
		if dormant is Dictionary:
			for sector_id in dormant:
				if not sector_id is String or not registry.matches_type(sector_id, "sector"):
					return "unknown_sector"
	return ""


static func _decoded_rng(value: Variant) -> Dictionary:
	if not value is Dictionary or value.size() != 4:
		return {}
	var dto: Dictionary = value
	if not _integer_number(dto.get("schema_version")) or int(dto["schema_version"]) != DataContractVersions.SCHEMA_VERSION:
		return {}
	if not _integer_number(dto.get("rng_stream_version")) or int(dto["rng_stream_version"]) != DataContractVersions.RNG_STREAM_VERSION:
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
		if not _integer_number(entry.get("derived_seed")) or int(entry["derived_seed"]) != seed:
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


static func _safe(value: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_STRING:
			return value.length() <= 256
		TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(value)
		TYPE_ARRAY:
			if value.size() > MAX_CONTAINER_ITEMS:
				return false
			for item in value:
				if not _safe(item, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			if value.size() > MAX_CONTAINER_ITEMS:
				return false
			for key in value:
				if typeof(key) != TYPE_STRING or key.length() > 128 or not _safe(value[key], depth + 1):
					return false
			return true
		_:
			return false
