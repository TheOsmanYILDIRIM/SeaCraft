extends GutTest

const BOOT := preload("res://src/presentation/bootstrap.tscn")
const NPC := "entity.vs02_sc03"

class FaultService extends SaveService:
	var fault := ""

	func _write_temp(encoded: String) -> String:
		if fault == "temp_open":
			return "temp_open_failed"
		if fault == "short_write":
			var file := FileAccess.open(_path(TEMP), FileAccess.WRITE)
			if file != null:
				file.store_string(encoded.left(maxi(1, encoded.length() / 2)))
				file.close()
			return "temp_write_failed"
		return super._write_temp(encoded)

	func _verify(name: String, expected_text: String) -> String:
		if fault == "temp_verify" and name == TEMP:
			return "verification_mismatch"
		if fault == "primary_verify" and name == PRIMARY:
			var file := FileAccess.open(_path(PRIMARY), FileAccess.WRITE)
			if file != null:
				file.store_string("{\"corrupt\":")
				file.close()
			return "verification_mismatch"
		return super._verify(name, expected_text)

	func _rename(from: String, to: String) -> Error:
		if fault == "rotate" and from == PRIMARY and to == BACKUP:
			return ERR_CANT_CREATE
		if fault == "replace" and from == TEMP and to == PRIMARY:
			return ERR_CANT_CREATE
		return super._rename(from, to)


var _directory := ""
var _settings_directory := ""
var _authority: RefCounted
var _world: SectorWorld
var _ship: ShipMotor
var _streams: SeedStreams
var _service: SaveService


func before_each() -> void:
	_directory = "user://core04-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	_settings_directory = _directory + "-settings"
	assert_eq(DirAccess.make_dir_recursive_absolute(_directory), OK)
	_authority = RefCounted.new()
	_world = SectorWorld.new(FoundationSector.graph(), _authority)
	assert_true(_world.activate_initial(_authority, FoundationSector.ID, FoundationSector.ENTRY, FoundationSector.PLAYER))
	_ship = ShipMotor.new()
	add_child_autofree(_ship)
	_ship.set_physics_process(false)
	_ship.global_position = _world.active().entity_position(FoundationSector.PLAYER)
	_streams = SeedStreams.new(40404)
	_service = SaveService.new(_directory)


func after_each() -> void:
	_remove_store(_directory)
	_remove_store(_settings_directory)


func test_core04_migration_chain_is_sequential_and_deterministic() -> void:
	var legacy := _read_json("res://tests/fixtures/save/legacy_v0.json")
	var v1 := _read_json("res://tests/fixtures/save/current.json")
	var first := SaveSnapshot.migrate(legacy)
	var second := SaveSnapshot.migrate(legacy)
	assert_eq(first, second)
	assert_eq(first["status"], "")
	assert_true(first["migrated"])
	var current: Dictionary = first["snapshot"]
	assert_eq(int(current["schema_version"]), DataContractVersions.SCHEMA_VERSION)
	assert_eq(current["sector_id"], FoundationSector.ID)
	assert_eq(current["player"]["entity_id"], SaveMigrations.LEGACY_V0_ENTITY_ID)
	assert_eq(current["rng"]["master_seed"], str(SaveMigrations.LEGACY_V0_MASTER_SEED))
	assert_eq(current["content_hash"], ContentManifest.current_hash())
	var v1_result := SaveSnapshot.migrate(v1)
	assert_eq(v1_result["status"], "")
	assert_true(v1_result["migrated"])
	var now := _snapshot()
	assert_false(SaveSnapshot.migrate(now)["migrated"])
	var future := now.duplicate(true)
	future["schema_version"] = DataContractVersions.SCHEMA_VERSION + 1
	assert_eq(SaveSnapshot.migrate(future)["status"], "unsupported_version")
	assert_eq(SaveSnapshot.migrate({"schema_version": 0, "sector": "wrong", "player": {"x": 1.0, "y": 2.0}})["status"], "bad_migration_shape")
	print("CORE04_MIGRATION_CHAIN_OK")


func test_core04_registry_manifest_and_unknown_content_policy() -> void:
	ContentManifest.reset_cache_for_tests()
	var registry := ContentManifest.registry()
	assert_not_null(registry)
	assert_gte(registry.indexed_count(), 20)
	for row in [
		["ammo.core_round", "ammo"], ["monster.core02_practice", "monster"],
		["harpoon.core02_debug", "harpoon"], ["safe_zone.haven_core", "safe_zone"],
		["loot_table.vs03_sc03", "loot_table"], ["sector.foundation", "sector"],
	]:
		assert_true(registry.matches_type(row[0], row[1]), str(row))
	var first_hash := registry.manifest_hash()
	var second := ContentManifest.registry()
	assert_eq(second.manifest_hash(), first_hash)
	assert_eq(ContentManifest.current_hash(), first_hash)
	var dto := _snapshot({"entity_index": _entity_index(2)})
	dto["authoritative_state"]["entity_index"]["records"][0]["definition_id"] = "ship.missing"
	assert_eq(SaveSnapshot.validate(dto), "unknown_content")
	print("CORE04_CONTENT_REGISTRY_OK")


func test_core04_content_hash_mismatch_is_transactional() -> void:
	var dto := _snapshot()
	dto["content_hash"] = "0".repeat(64)
	dto["content_manifest"]["hash"] = dto["content_hash"]
	var previous_runtime := _world.active()
	var before_motion := _ship.capture_save_motion()
	var before_rng := _streams.snapshot_state()
	assert_eq(SaveSnapshot.restore(dto, _world, _authority, FoundationSector.PLAYER, _ship, _streams), "content_hash_mismatch")
	assert_same(_world.active(), previous_runtime)
	assert_eq(_ship.capture_save_motion(), before_motion)
	assert_eq(_streams.snapshot_state(), before_rng)
	assert_eq(_service.save(dto)["status"], "content_hash_mismatch")
	print("CORE04_CONTENT_HASH_MISMATCH_OK")


func test_core04_entity_index_is_bounded_sorted_and_multi_sector() -> void:
	var registry := ContentManifest.registry()
	var raw: Array = [_entity_record(2, FoundationSector.HAVEN_ID), _entity_record(0, FoundationSector.ID), _entity_record(1, FoundationSector.OUTER_ID)]
	var index := PersistentEntityIndex.build(raw, registry)
	assert_eq(index["records"].size(), 3)
	assert_eq(index["records"][0]["instance_id"], "entity.core04.e0000")
	assert_eq(index["records"][2]["sector_id"], FoundationSector.HAVEN_ID)
	assert_eq(PersistentEntityIndex.validate(index, registry), "")
	var duplicate := index.duplicate(true)
	duplicate["records"][1]["instance_id"] = duplicate["records"][0]["instance_id"]
	assert_eq(PersistentEntityIndex.validate(duplicate, registry), "duplicate_entity_id")
	var unknown := index.duplicate(true)
	unknown["records"][0]["definition_id"] = "ship.unknown"
	assert_eq(PersistentEntityIndex.validate(unknown, registry), "unknown_content")
	print("CORE04_ENTITY_INDEX_OK")


func test_core04_npc_route_cooldown_and_scheduler_resume() -> void:
	var scene := BOOT.instantiate()
	scene.set("_save_service", _service)
	add_child(scene)
	var combat := scene.get("_combat") as CombatAuthority
	var brain := scene.get("_npc_brain") as NpcBrain
	var scheduler := scene.get("_ai_scheduler") as AiDecisionScheduler
	var npc_motor := scene.get("_npc_motor") as ShipMotor
	var world := scene.get("_world") as SectorWorld
	assert_not_null(brain)
	var state := combat.snapshot_state()
	for entry: Dictionary in state["combatants"]:
		if entry["entity_id"] == NPC:
			entry["hull"] = 25.0
	assert_true(combat.restore_state(state))
	assert_true(brain.record_combat_damage(FoundationSector.PLAYER, 70.0, 9001, 0))
	assert_true(brain.decision_tick(10))
	var destination: Dictionary = brain.persistence_state()["destination"]
	npc_motor.global_position = Vector2(destination["x"], destination["y"])
	npc_motor.cancel_target()
	assert_true(world.active().move_entity(NPC, npc_motor.global_position))
	assert_true(brain.decision_tick(20))
	assert_eq(brain.state_id(), NpcBrain.State.REPAIR)
	var action := combat.transact(FoundationSector.PLAYER, CombatAuthority.intent(CombatAuthority.ACTION, CoreCombatRules.ACTION))
	assert_true(action["accepted"])
	var before_brain := brain.persistence_state()
	var before_combat := combat.snapshot_state()
	var before_scheduler := scheduler.snapshot_state()
	assert_gt(int(before_brain["next_repair_tick"]), int(before_brain["repair_started_tick"]))
	_service.mark_dirty()
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(scene.get("save_status")["status"], SaveService.OK_STATUS)
	scene.free()
	var restored_scene := BOOT.instantiate()
	restored_scene.set("_save_service", _service)
	add_child(restored_scene)
	var restored_brain := restored_scene.get("_npc_brain") as NpcBrain
	var restored_combat := restored_scene.get("_combat") as CombatAuthority
	var restored_scheduler := restored_scene.get("_ai_scheduler") as AiDecisionScheduler
	assert_eq(restored_brain.persistence_state(), before_brain)
	assert_eq(restored_combat.snapshot_state(), before_combat)
	assert_eq(restored_scheduler.snapshot_state(), before_scheduler)
	assert_eq(restored_brain.persistence_state()["patrol_index"], before_brain["patrol_index"])
	assert_eq(restored_brain.persistence_state()["destination"], before_brain["destination"])
	assert_eq(restored_brain.persistence_state()["memory"], before_brain["memory"])
	restored_scene.free()
	print("CORE04_NPC_RESUME_OK")


func test_core04_recovery_fault_matrix_and_dirty_retry() -> void:
	assert_eq(_service.save(_snapshot())["status"], SaveService.OK_STATUS)
	var baseline: Dictionary = _service.load()["snapshot"]
	for fault in ["temp_open", "short_write", "temp_verify", "rotate", "replace", "primary_verify"]:
		var writer := FaultService.new(_directory)
		writer.fault = fault
		writer.mark_dirty()
		_ship.rotation += 0.01
		var result := writer.save_if_dirty(_snapshot())
		assert_ne(result["status"], SaveService.OK_STATUS, fault)
		assert_true(writer.is_dirty(), fault)
		var recovered := SaveService.new(_directory).load()
		assert_true(recovered["status"] in [SaveService.OK_STATUS, SaveService.RECOVERED], fault)
		if fault != "primary_verify":
			assert_eq(recovered["snapshot"]["player"]["motion"]["heading"], baseline["player"]["motion"]["heading"], fault)
		_remove_if_exists(_directory.path_join(SaveService.TEMP))
		if recovered["status"] == SaveService.RECOVERED:
			var healing := SaveService.new(_directory)
			assert_eq(healing.save(recovered["snapshot"])["status"], SaveService.OK_STATUS)
		baseline = SaveService.new(_directory).load()["snapshot"]
	var retry := FaultService.new(_directory)
	retry.fault = "short_write"
	retry.mark_dirty()
	assert_eq(retry.save_if_dirty(_snapshot())["status"], "temp_write_failed")
	retry.fault = ""
	assert_eq(retry.save_if_dirty(_snapshot())["status"], SaveService.OK_STATUS)
	assert_false(retry.is_dirty())
	_write_raw(_directory.path_join(SaveService.PRIMARY), "broken")
	_write_raw(_directory.path_join(SaveService.BACKUP), "broken")
	assert_eq(SaveService.new(_directory).load()["status"], SaveService.FAILED)
	print("CORE04_RECOVERY_OK")


func test_core04_malformed_corpus_is_controlled_and_transactional() -> void:
	var base := _snapshot({"entity_index": _entity_index(2)})
	var cases: Array[Dictionary] = []
	var wrong := base.duplicate(true); wrong["player"]["motion"]["heading"] = "north"; cases.append(wrong)
	var negative := base.duplicate(true); negative["loot"]["inventory"]["item.core_round"] = -1; cases.append(negative)
	var nan_case := base.duplicate(true); nan_case["player"]["motion"]["vx"] = NAN; cases.append(nan_case)
	var deep := base.duplicate(true); var cursor: Dictionary = deep["authoritative_state"]; for i in 14: cursor["x"] = {}; cursor = cursor["x"]; cases.append(deep)
	var oversized := base.duplicate(true); oversized["loot"]["drops"] = []; for i in SaveSnapshot.MAX_LOOT_DROPS + 1: oversized["loot"]["drops"].append({}); cases.append(oversized)
	var duplicate := base.duplicate(true); duplicate["authoritative_state"]["entity_index"]["records"][1]["instance_id"] = duplicate["authoritative_state"]["entity_index"]["records"][0]["instance_id"]; cases.append(duplicate)
	var unknown_definition := base.duplicate(true); unknown_definition["authoritative_state"]["entity_index"]["records"][0]["definition_id"] = "ship.missing"; cases.append(unknown_definition)
	var unknown_sector := base.duplicate(true); unknown_sector["sector_id"] = "sector.missing"; cases.append(unknown_sector)
	var bad_hash := base.duplicate(true); bad_hash["content_hash"] = "f".repeat(64); bad_hash["content_manifest"]["hash"] = bad_hash["content_hash"]; cases.append(bad_hash)
	var future := base.duplicate(true); future["schema_version"] = DataContractVersions.SCHEMA_VERSION + 1; cases.append(future)
	var bad_rng := base.duplicate(true); bad_rng["rng"]["master_seed"] = "not-int"; cases.append(bad_rng)
	var bad_cooldown := base.duplicate(true); bad_cooldown["authoritative_state"]["entity_index"]["records"][0]["cooldowns"]["reload"] = -1; cases.append(bad_cooldown)
	var bad_hp := base.duplicate(true); bad_hp["authoritative_state"]["entity_index"]["records"][0]["health"] = CoreCombatRules.MAX_VALUE + 1.0; cases.append(bad_hp)
	var bad_route := base.duplicate(true); bad_route["authoritative_state"]["entity_index"]["records"][0]["route"]["goal"] = {"x": 1.0e10, "y": 0.0}; cases.append(bad_route)
	var ledger := base.duplicate(true); ledger["loot"] = {"drops": [], "claimed_ids": [], "inventory": {}, "processed_events": {"event.core04": "drop.missing"}}; cases.append(ledger)
	var migration := {"schema_version": 0, "sector": "bad", "player": {"x": 0.0, "y": 0.0}}
	cases.append(migration)
	var before_runtime := _world.active()
	var before_motion := _ship.capture_save_motion()
	var before_rng := _streams.snapshot_state()
	for dto in cases:
		var error := SaveSnapshot.restore(dto, _world, _authority, FoundationSector.PLAYER, _ship, _streams)
		assert_ne(error, "", str(dto))
		assert_same(_world.active(), before_runtime)
		assert_eq(_ship.capture_save_motion(), before_motion)
		assert_eq(_streams.snapshot_state(), before_rng)
	_write_raw(_directory.path_join(SaveService.PRIMARY), JSON.stringify(base).left(-24))
	assert_eq(SaveService.new(_directory).load()["status"], SaveService.FAILED)
	print("CORE04_MALFORMED_CORPUS_OK")


func test_core04_large_entity_roundtrip_is_bounded_and_deterministic() -> void:
	var index := _entity_index(512)
	assert_eq(index["records"].size(), 512)
	var dto := _snapshot({"entity_index": index})
	var encoded_a := JSON.stringify(SaveSnapshot.canonicalize(dto), "\t", true, true)
	var encoded_b := JSON.stringify(SaveSnapshot.canonicalize(dto), "\t", true, true)
	assert_eq(encoded_a, encoded_b)
	var bytes := encoded_a.to_utf8_buffer().size()
	assert_lt(bytes, SaveService.MAX_BYTES)
	var save_start := Time.get_ticks_usec()
	assert_eq(_service.save(dto)["status"], SaveService.OK_STATUS)
	var save_ms := float(Time.get_ticks_usec() - save_start) / 1000.0
	var load_start := Time.get_ticks_usec()
	var loaded := _service.load()
	assert_eq(loaded["status"], SaveService.OK_STATUS)
	var loaded_index: Dictionary = loaded["snapshot"]["authoritative_state"]["entity_index"]
	assert_eq(PersistentEntityIndex.validate(loaded_index, ContentManifest.registry()), "")
	_assert_entity_index_semantic_equal(index, loaded_index)
	var authority := RefCounted.new()
	var world := SectorWorld.new(FoundationSector.graph(), authority)
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	var streams := SeedStreams.new(1)
	assert_eq(SaveSnapshot.restore(loaded["snapshot"], world, authority, FoundationSector.PLAYER, ship, streams), "")
	var load_ms := float(Time.get_ticks_usec() - load_start) / 1000.0
	assert_eq(streams.snapshot_state(), _streams.snapshot_state())
	print("CORE04_LARGE_ROUNDTRIP_OK entity_count=512 encoded_bytes=%d save_ms=%.3f load_restore_ms=%.3f" % [bytes, save_ms, load_ms])


func test_core04_world_ledgers_survive_roundtrip_without_duplicate_claims() -> void:
	var loot := {
		"drops": [],
		"claimed_ids": ["drop.core04.claimed"],
		"inventory": {"item.vs03_salvage_scrap": 3},
		"processed_events": {"event.core04.claimed": "drop.core04.claimed"},
	}
	var dto := _service.create_snapshot(_world.active(), FoundationSector.PLAYER, _ship, _streams, SaveSnapshot.LOCAL, "", loot, {"entity_index": _entity_index(3)})
	assert_eq(_service.save(dto)["status"], SaveService.OK_STATUS)
	var loaded := _service.load()
	assert_eq(loaded["status"], SaveService.OK_STATUS)
	var loaded_loot := SaveSnapshot.loot_state(loaded["snapshot"])
	assert_eq(loaded_loot["drops"], loot["drops"])
	assert_eq(loaded_loot["claimed_ids"], loot["claimed_ids"])
	assert_eq(loaded_loot["processed_events"], loot["processed_events"])
	assert_eq(loaded_loot["inventory"].keys(), loot["inventory"].keys())
	for item_id in loot["inventory"]:
		assert_eq(int(loaded_loot["inventory"][item_id]), int(loot["inventory"][item_id]))
	assert_eq(loaded["snapshot"]["authoritative_state"]["entity_index"]["records"][1]["sector_id"], FoundationSector.OUTER_ID)


func test_core04_host_world_and_client_settings_are_separated() -> void:
	var world_dto := _service.create_snapshot(_world.active(), FoundationSector.PLAYER, _ship, _streams, SaveSnapshot.HOST, "session.core04")
	assert_eq(_service.save(world_dto)["status"], SaveService.OK_STATUS)
	var settings := SettingsService.new(_settings_directory)
	var local := {"graphics": {"scale": 0.8}, "audio": {"master": 0.5}, "controls": {"touch": true}}
	assert_eq(settings.save(local)["status"], SettingsService.OK_STATUS)
	assert_eq(settings.load()["settings"], local)
	assert_false(settings.load()["settings"].has("rng"))
	var forbidden := local.duplicate(true)
	forbidden["world"] = {"entities": []}
	assert_ne(SettingsService.validate(forbidden), "")
	assert_eq(_service.load()["snapshot"]["ownership"]["kind"], SaveSnapshot.HOST)


func _snapshot(authoritative: Dictionary = {}) -> Dictionary:
	return _service.create_snapshot(_world.active(), FoundationSector.PLAYER, _ship, _streams, SaveSnapshot.LOCAL, "", SaveSnapshot.empty_loot_state(), authoritative)


func _entity_index(count: int) -> Dictionary:
	var records: Array = []
	var sectors := [FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.HAVEN_ID]
	for index in count:
		records.append(_entity_record(index, sectors[index % sectors.size()]))
	return PersistentEntityIndex.build(records, ContentManifest.registry())


func _entity_record(index: int, sector_id: String) -> Dictionary:
	return {
		"instance_id": "entity.core04.e%04d" % index,
		"definition_id": "ship.vs02_practice",
		"entity_kind": "npc_ship",
		"sector_id": sector_id,
		"position": {"x": float(index), "y": float(-index)},
		"motion": {"heading": 0.25, "vx": 1.0, "vy": -1.0},
		"health": 75.0,
		"alive": true,
		"route": {"goal": {"x": float(index + 1), "y": float(index + 2)}, "patrol_index": index % 4, "intent_id": 0},
		"cooldowns": {"reload": index + 10, "repair": index + 20},
		"inventory": {"item.vs03_salvage_scrap": index % 3},
		"payload": {"content_refs": ["ammo.core_round", "harpoon.core02_debug"]},
	}


func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	assert_eq(json.parse(text), OK)
	return json.data


func _write_raw(path: String, body: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	assert_true(file.store_string(body))
	file.close()


func _remove_if_exists(path: String) -> void:
	if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
		DirAccess.remove_absolute(path)


func _remove_store(directory: String) -> void:
	if directory.is_empty() or not DirAccess.dir_exists_absolute(directory):
		return
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP, SettingsService.FILE_NAME, SettingsService.TEMP_NAME]:
		_remove_if_exists(directory.path_join(name))
	DirAccess.remove_absolute(directory)


func _assert_entity_index_semantic_equal(expected: Dictionary, actual: Dictionary) -> void:
	assert_eq(int(actual["version"]), int(expected["version"]))
	assert_eq(actual["records"].size(), expected["records"].size())
	for index in expected["records"].size():
		var left: Dictionary = expected["records"][index]
		var right: Dictionary = actual["records"][index]
		for key in ["instance_id", "definition_id", "entity_kind", "sector_id", "alive"]:
			assert_eq(right[key], left[key], "record %d %s" % [index, key])
		for key in ["x", "y"]:
			assert_eq(float(right["position"][key]), float(left["position"][key]), "record %d position.%s" % [index, key])
		for key in ["heading", "vx", "vy"]:
			assert_eq(float(right["motion"][key]), float(left["motion"][key]), "record %d motion.%s" % [index, key])
		assert_eq(float(right["health"]), float(left["health"]), "record %d health" % index)
		var left_route_keys: Array = left["route"].keys()
		var right_route_keys: Array = right["route"].keys()
		left_route_keys.sort()
		right_route_keys.sort()
		assert_eq(right_route_keys, left_route_keys, "record %d route keys" % index)
		if left["route"].has("goal"):
			for key in ["x", "y"]:
				assert_eq(float(right["route"]["goal"][key]), float(left["route"]["goal"][key]), "record %d route.goal.%s" % [index, key])
		for key in ["patrol_index", "intent_id", "next_waypoint"]:
			if left["route"].has(key):
				assert_eq(int(right["route"][key]), int(left["route"][key]), "record %d route.%s" % [index, key])
		if left["route"].has("goal_id"):
			assert_eq(right["route"]["goal_id"], left["route"]["goal_id"])
		assert_eq(right["cooldowns"].keys(), left["cooldowns"].keys(), "record %d cooldown keys" % index)
		for key in left["cooldowns"]:
			assert_eq(int(right["cooldowns"][key]), int(left["cooldowns"][key]), "record %d cooldown.%s" % [index, key])
		assert_eq(right["inventory"].keys(), left["inventory"].keys(), "record %d inventory keys" % index)
		for key in left["inventory"]:
			assert_eq(int(right["inventory"][key]), int(left["inventory"][key]), "record %d inventory.%s" % [index, key])
		assert_eq(right["payload"], left["payload"], "record %d payload" % index)
