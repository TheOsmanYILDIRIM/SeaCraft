extends GutTest

const BOOT := preload("res://src/presentation/bootstrap.tscn")
const CURRENT := "res://tests/fixtures/save/current.json"
const LEGACY := "res://tests/fixtures/save/legacy_v0.json"
const OTHER := FoundationSector.OUTER_ID
const OTHER_PATH := "res://other_lazy_definition.tres"

class InterruptedService extends SaveService:
	func _rename(from: String, to: String) -> Error:
		if from == TEMP and to == PRIMARY:
			return ERR_CANT_CREATE
		return super._rename(from, to)

var _directory: String
var _service: SaveService
var _authority: RefCounted
var _world: SectorWorld
var _ship: ShipMotor
var _streams: SeedStreams
var _loaded_paths: Array[String]


func before_each() -> void:
	_directory = "user://fnd06-test-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(_directory), OK)
	_service = SaveService.new(_directory)
	_authority = RefCounted.new()
	_world = SectorWorld.new(FoundationSector.graph(), _authority)
	assert_true(_world.activate_initial(_authority, FoundationSector.ID, FoundationSector.ENTRY, FoundationSector.PLAYER))
	_ship = _new_ship()
	_ship.global_position = Vector2(-231, 13)
	_ship.rotation = 0.75
	_ship.velocity = Vector2(3.5, -1.5)
	assert_true(_ship.set_target_world_position(Vector2(-205, 21)))
	_streams = SeedStreams.new(-9223372036854775807)
	_loaded_paths = []


func after_each() -> void:
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP]:
		var path := _directory.path_join(name)
		if FileAccess.file_exists(path) or DirAccess.dir_exists_absolute(path):
			assert_eq(DirAccess.remove_absolute(path), OK)
	assert_eq(DirAccess.remove_absolute(_directory), OK)


func test_player_runtime_round_trip() -> void:
	_expect_save(_snapshot())
	var target_ship := _new_ship()
	var world := SectorWorld.new(FoundationSector.graph(), _authority)
	assert_eq(_restore(world, target_ship), "")
	assert_true(target_ship.has_target())
	assert_eq(target_ship.target_world_position(), _ship.target_world_position())
	assert_almost_eq(target_ship.desired_heading(), _ship.desired_heading(), 0.0001)
	assert_eq(world.active().entity_position(FoundationSector.PLAYER), _ship.global_position)


func test_active_sector_stable_id_round_trip() -> void:
	_expect_save(_snapshot())
	assert_eq(_service.load().get("snapshot", {}).get("sector_id"), FoundationSector.ID)


func test_position_heading_velocity_round_trip() -> void:
	_expect_save(_snapshot())
	var target_ship := _new_ship()
	assert_eq(_restore(SectorWorld.new(FoundationSector.graph(), _authority), target_ship), "")
	assert_eq(target_ship.global_position, _ship.global_position)
	assert_almost_eq(target_ship.rotation, _ship.rotation, 0.0001)
	assert_eq(target_ship.velocity, _ship.velocity)


func test_rng_state_resumes_all_streams_exactly() -> void:
	for name in SeedStreams.STREAM_NAMES:
		for index in 9:
			_streams.next_int(name, 0, 2147480000)
	_expect_save(_snapshot())
	var resumed := SeedStreams.new(7)
	var dto: Dictionary = _service.load().get("snapshot", {})
	var world := SectorWorld.new(FoundationSector.graph(), _authority)
	assert_eq(SaveSnapshot.restore(dto, world, _authority, FoundationSector.PLAYER, _new_ship(), resumed), "")
	assert_eq(resumed.snapshot_state(), _streams.snapshot_state())
	for name in SeedStreams.STREAM_NAMES:
		for index in 16:
			assert_eq(resumed.next_int(name, 0, 2147480000), _streams.next_int(name, 0, 2147480000))


func test_schema_and_content_metadata() -> void:
	_expect_save(_snapshot())
	var dto: Dictionary = _service.load().get("snapshot", {})
	assert_eq(int(dto["schema_version"]), DataContractVersions.SCHEMA_VERSION)
	assert_eq(dto["content_version"], DataContractVersions.CONTENT_VERSION)
	assert_eq(dto["content_hash"], ContentManifest.current_hash())
	assert_eq(dto["content_manifest"]["hash"], dto["content_hash"])
	assert_eq(int(dto["content_manifest"]["entry_count"]), ContentManifest.current_entry_count())
	assert_eq(int(dto["rng_stream_version"]), DataContractVersions.RNG_STREAM_VERSION)


func test_objects_and_vector_values_are_rejected() -> void:
	var dto := _snapshot()
	dto["player"]["motion"]["x"] = Vector2.ONE
	assert_eq(_save_status(dto), "invalid_dto")
	dto["player"]["motion"]["x"] = _ship
	assert_eq(_save_status(dto), "invalid_dto")
	assert_false(_service.has_save())


func test_malformed_json_is_controlled() -> void:
	_write(SaveService.PRIMARY, "{\"schema_version\":@}")
	var result := _service.load()
	assert_eq(result["status"], SaveService.FAILED)
	assert_eq(result["primary_status"], "invalid_json")


func test_truncated_json_is_controlled() -> void:
	_write(SaveService.PRIMARY, JSON.stringify(_snapshot()).left(-20))
	var result := _service.load()
	assert_eq(result["status"], SaveService.FAILED)
	assert_eq(result["primary_status"], "invalid_json")


func test_unknown_sector_does_not_replace_active_runtime() -> void:
	var dto := _snapshot()
	dto["sector_id"] = "sector.unknown"
	var previous := _world.active()
	assert_eq(_save_status(dto), "unknown_sector")
	assert_same(_world.active(), previous)
	assert_false(_service.has_save())


func test_missing_definition_reference_is_controlled() -> void:
	_expect_save(_snapshot())
	var missing := SectorWorld.new(FoundationSector.graph(), _authority, func(_path: String) -> SectorDefinition: return null)
	assert_eq(_restore(missing, _new_ship()), "missing_or_invalid_sector_definition")
	assert_null(missing.active())


func test_temp_open_failure_preserves_verified_primary() -> void:
	_expect_save(_snapshot())
	var primary := _read_text(_directory.path_join(SaveService.PRIMARY))
	assert_eq(DirAccess.make_dir_absolute(_directory.path_join(SaveService.TEMP)), OK)
	_ship.rotation = 1.5
	assert_eq(_save_status(_snapshot()), "temp_open_failed")
	assert_eq(_read_text(_directory.path_join(SaveService.PRIMARY)), primary)
	assert_eq(_service.load()["status"], SaveService.OK_STATUS)


func test_interruption_before_rotation_ignores_temp() -> void:
	_expect_save(_snapshot())
	_write(SaveService.TEMP, "{\"partial\":")
	assert_eq(_service.load()["status"], SaveService.OK_STATUS)


func test_interruption_after_rotation_preserves_last_checkpoint() -> void:
	_expect_save(_snapshot())
	var primary := _read_text(_directory.path_join(SaveService.PRIMARY))
	_ship.rotation = 1.5
	var writer := InterruptedService.new(_directory)
	assert_eq(writer.save(_snapshot())["status"], "primary_replace_failed")
	assert_eq(_read_text(_directory.path_join(SaveService.BACKUP)), primary)
	var result := _service.load()
	assert_eq(result["status"], SaveService.RECOVERED)
	assert_almost_eq(float(result["snapshot"]["player"]["motion"]["heading"]), 0.75, 0.0001)


func test_bad_primary_recovers_good_backup_without_rotating_damage() -> void:
	_expect_save(_snapshot())
	_ship.rotation = 1.5
	_expect_save(_snapshot())
	_write(SaveService.PRIMARY, "bad")
	var backup := _read_text(_directory.path_join(SaveService.BACKUP))
	var result := _service.recover_backup()
	assert_eq(result["status"], SaveService.RECOVERED)
	assert_almost_eq(float(result["snapshot"]["player"]["motion"]["heading"]), 0.75, 0.0001)
	_expect_save(result["snapshot"])
	assert_eq(_service.load()["status"], SaveService.OK_STATUS)
	assert_eq(_read_text(_directory.path_join(SaveService.BACKUP)), backup)


func test_bad_primary_and_backup_refuse_overwrite() -> void:
	_write(SaveService.PRIMARY, "broken primary")
	_write(SaveService.BACKUP, "broken backup")
	var result := _service.load()
	assert_eq(result["status"], SaveService.FAILED)
	assert_eq(result["primary_status"], "invalid_json")
	assert_eq(result["backup_status"], "invalid_json")
	assert_eq(_save_status(_snapshot()), SaveService.FAILED)
	assert_eq(_read_text(_directory.path_join(SaveService.PRIMARY)), "broken primary")


func test_schema1_fixture_migrates_to_current() -> void:
	_write(SaveService.PRIMARY, _read_text(CURRENT))
	var result := _service.load()
	assert_eq(result["status"], SaveService.OK_STATUS)
	assert_true(result["migrated"])
	assert_eq(int(result["snapshot"]["schema_version"]), DataContractVersions.SCHEMA_VERSION)


func test_legacy_v0_fixture_migrates_to_current() -> void:
	_write(SaveService.PRIMARY, _read_text(LEGACY))
	var result := _service.load()
	assert_eq(result["status"], SaveService.OK_STATUS)
	assert_true(result["migrated"])
	assert_eq(int(result["snapshot"]["schema_version"]), DataContractVersions.SCHEMA_VERSION)
	assert_eq(result["snapshot"]["sector_id"], FoundationSector.ID)
	assert_eq(result["snapshot"]["player"]["entity_id"], SaveMigrations.LEGACY_V0_ENTITY_ID)
	assert_eq(result["snapshot"]["rng"]["master_seed"], str(SaveMigrations.LEGACY_V0_MASTER_SEED))


func test_future_schema_is_not_bypassed_with_backup() -> void:
	var dto := _snapshot()
	_write(SaveService.BACKUP, JSON.stringify(dto))
	dto["schema_version"] = DataContractVersions.SCHEMA_VERSION + 1
	_write(SaveService.PRIMARY, JSON.stringify(dto))
	assert_eq(_service.load()["status"], "unsupported_version")
	assert_eq(_save_status(_snapshot()), "unsupported_version")


func test_content_mismatch_is_not_a_schema_migration() -> void:
	var dto := _snapshot()
	dto["content_version"] = "not-current"
	_write(SaveService.PRIMARY, JSON.stringify(dto))
	assert_eq(_service.load()["status"], "unsupported_content")


func test_only_requested_sector_is_loaded_from_two_sector_catalog() -> void:
	var dto := _snapshot()
	dto["sector_id"] = OTHER
	_expect_save(dto)
	var graph := _two_sector_graph()
	var world := SectorWorld.new(graph, _authority, _load_other)
	assert_eq(_restore(world, _new_ship()), "")
	assert_eq(_loaded_paths, [OTHER_PATH])
	assert_eq(world.active().sector_id, OTHER)
	assert_eq(world.active().entity_position(FoundationSector.PLAYER), _ship.global_position)


func test_only_active_entity_is_reconstituted() -> void:
	assert_true(_world.active().register_entity("entity.unrelated", Vector2(-200, 40)))
	_expect_save(_snapshot())
	assert_eq(_restore(_world, _new_ship()), "")
	assert_eq(_world.active().entity_position("entity.unrelated"), Vector2.INF)
	assert_eq(_world.active().entity_position(FoundationSector.PLAYER), _ship.global_position)


func test_nan_and_infinity_never_reach_disk() -> void:
	for invalid in [NAN, INF, -INF]:
		var dto := _snapshot()
		dto["player"]["motion"]["vx"] = invalid
		assert_eq(_save_status(dto), "invalid_dto")
	assert_false(_service.has_save())


func test_owner_and_session_are_primitive_and_round_trip() -> void:
	var dto := _service.create_snapshot(_world.active(), FoundationSector.PLAYER, _ship, _streams, SaveSnapshot.HOST, "session.host-one")
	assert_true(DtoContract.is_primitive_safe(dto["ownership"]))
	_expect_save(dto)
	assert_eq(_service.load()["snapshot"]["ownership"], dto["ownership"])
	dto["ownership"]["kind"] = "client"
	assert_eq(_save_status(dto), "invalid_ownership")


func test_dirty_flag_prevents_repeated_disk_writes() -> void:
	_service.mark_dirty()
	assert_eq(_service.save_if_dirty(_snapshot())["status"], SaveService.OK_STATUS)
	assert_false(_service.is_dirty())
	assert_eq(_service.save_if_dirty(_snapshot())["status"], SaveService.CLEAN)
	assert_false(FileAccess.file_exists(_directory.path_join(SaveService.BACKUP)))


func test_absence_is_distinct_from_corruption() -> void:
	assert_false(_service.has_save())
	assert_eq(_service.load()["status"], SaveService.MISSING)


func test_bootstrap_load_and_pause_hook_use_isolated_store() -> void:
	_expect_save(_snapshot())
	var scene := BOOT.instantiate()
	scene.set("_save_service", _service)
	add_child_autofree(scene)
	assert_eq(scene.get("save_status")["status"], SaveService.OK_STATUS)
	assert_eq(scene.get_node("ShipMotor").global_position, _ship.global_position)
	_service.mark_dirty()
	scene.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_eq(scene.get("save_status")["status"], SaveService.OK_STATUS, "legacy 64-bit seed must save with AI-04 world")
	assert_false(_service.is_dirty())
	assert_true(FileAccess.file_exists(_directory.path_join(SaveService.BACKUP)))


func test_persistence_and_simulation_boundary() -> void:
	for path in ["res://src/simulation/world/sector_world.gd", "res://src/simulation/movement/ship_motor.gd"]:
		var source := _read_text(path)
		assert_ne(source, "")
		for forbidden in ["FileAccess", "SaveService", "MultiplayerAPI", "@rpc"]:
			assert_false(source.contains(forbidden))


func _two_sector_graph() -> SectorGraph:
	var gate := SectorGate.new()
	gate.stable_id = "gate.to_other"
	gate.from_sector = FoundationSector.ID
	gate.to_sector = OTHER
	gate.exit_anchor = FoundationSector.ENTRY
	gate.entry_anchor = FoundationSector.ENTRY
	gate.activation_radius = 100.0
	var graph := SectorGraph.new()
	var rows: Array[Dictionary] = [
		{"id": FoundationSector.ID, "path": FoundationSector.PATH, "anchors": PackedStringArray([FoundationSector.ENTRY])},
		{"id": OTHER, "path": OTHER_PATH, "anchors": PackedStringArray([FoundationSector.ENTRY])},
	]
	assert_eq(graph.configure(rows, [gate], FoundationSector.ID), "")
	return graph


func _load_other(path: String) -> SectorDefinition:
	_loaded_paths.append(path)
	if path != OTHER_PATH:
		return null
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	definition.spawn_anchors = [definition.spawn_anchors[0]]
	definition.neighbor_ids = PackedStringArray()
	definition.transition_gates = []
	definition.safe_haven = false
	definition.safe_zones = []
	definition.map_node_position = Vector2.ZERO
	definition.map_layer = 0
	definition.biome_tag = ""
	definition.stable_id = OTHER
	definition.spawn_anchors[0].sector_id = OTHER
	return definition


func _new_ship() -> ShipMotor:
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	return ship


func _snapshot() -> Dictionary:
	return _service.create_snapshot(_world.active(), FoundationSector.PLAYER, _ship, _streams)


func _restore(world: SectorWorld, ship: ShipMotor) -> String:
	return SaveSnapshot.restore(_service.load().get("snapshot", {}), world, _authority, FoundationSector.PLAYER, ship, SeedStreams.new())


func _expect_save(dto: Dictionary) -> void:
	assert_eq(_save_status(dto), SaveService.OK_STATUS)


func _save_status(dto: Dictionary) -> String:
	return _service.save(dto)["status"]


func _write(name: String, body: String) -> void:
	var file := FileAccess.open(_directory.path_join(name), FileAccess.WRITE)
	assert_not_null(file)
	assert_true(file.store_string(body))
	file.close()


func _read_text(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_not_null(file)
	if file == null:
		return ""
	var body := file.get_as_text()
	file.close()
	return body
