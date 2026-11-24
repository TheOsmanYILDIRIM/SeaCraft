extends GutTest

const P := FoundationSector.PLAYER

func test_prg06_authority_gate_and_far_route() -> void:
	var graph := FoundationSector.graph()
	var authority := RefCounted.new()
	var world := SectorWorld.new(graph, authority)
	assert_true(world.activate_initial(authority, FoundationSector.HAVEN_ID, "anchor.haven_center", P))
	assert_eq(world.active().mode, 0)
	assert_eq(world.request_transition(authority, P, FoundationSector.GATE_HAVEN_DEEP)["reason"], "out_of_radius")
	assert_true(world.active().move_entity(P, world.active().anchor(FoundationSector.HAVEN_DIVE).position))
	assert_eq(world.request_transition(RefCounted.new(), P, FoundationSector.GATE_HAVEN_DEEP)["reason"], "not_authorized")
	assert_true(world.request_transition(authority, P, FoundationSector.GATE_HAVEN_DEEP)["accepted"])
	assert_eq(world.active().mode, 1)
	assert_eq(world.active().sector_id, FoundationSector.DEEP_ID)
	assert_true(world.active().entity_in_safe_zone(P))
	assert_eq(world.request_transition(authority, P, FoundationSector.GATE_HAVEN_OUTER)["reason"], "wrong_current_sector")
	assert_true(world.request_transition(authority, P, FoundationSector.GATE_DEEP_HAVEN)["accepted"])
	assert_eq(world.active().mode, 0)
	assert_eq(FarTravelResolver.plan_route(graph.presentation_snapshot(), FoundationSector.HAVEN_ID, FoundationSector.DEEP_ID), [])
	var rows: Array[Dictionary] = [
		{"id": "sector.a", "path": FoundationSector.PATH, "anchors": PackedStringArray(["anchor.a"])},
		{"id": "sector.b", "path": FoundationSector.DEEP_PATH, "anchors": PackedStringArray(["anchor.b"]), "mode": 1},
	]
	var invalid := SectorGate.new()
	invalid.stable_id = "gate.a_b"
	invalid.from_sector = "sector.a"
	invalid.to_sector = "sector.b"
	invalid.exit_anchor = "anchor.a"
	invalid.entry_anchor = "anchor.b"
	assert_eq(SectorGraph.new().configure(rows, [invalid], "sector.a"), "invalid_mode_gate")
	print("PRG06_MODE_GATE_OK")


func test_prg06_packed_scene_shared_save_and_mode_ui() -> void:
	var directory := "user://prg06-mode-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]
	var scene := preload("res://src/presentation/bootstrap.tscn").instantiate()
	scene.set("_save_service", SaveService.new(directory))
	add_child_autofree(scene)
	scene.set_process(false)
	scene.set_physics_process(false)
	var motor := scene.get_node("ShipMotor") as ShipMotor
	motor.set_physics_process(false)
	var npc := scene.get("_npc_motor") as ShipMotor
	assert_not_null(npc)
	if npc == null:
		return
	npc.set_physics_process(false)
	var inventory := (scene.get("_loot") as LootAuthority).inventory_state()
	var before := inventory.quantities_snapshot(P)
	motor.global_position = scene.active_sector().anchor(FoundationSector.FOUNDATION_GATE).position
	assert_true(scene.request_sector_transition(FoundationSector.GATE_FOUNDATION_OUTER)["accepted"])
	motor.global_position = scene.active_sector().anchor(FoundationSector.OUTER_EAST).position
	assert_true(scene.request_sector_transition(FoundationSector.GATE_OUTER_HAVEN)["accepted"])
	motor.global_position = scene.active_sector().anchor(FoundationSector.HAVEN_DIVE).position
	scene._refresh_mode_button()
	var mode_button := scene.get_node("UI/Prg06ModeButton") as Button
	assert_true(mode_button.visible)
	assert_eq(mode_button.text, "DAL")
	mode_button.pressed.emit()
	assert_eq(scene.active_sector().sector_id, FoundationSector.DEEP_ID)
	assert_eq(scene.active_sector().mode, 1)
	assert_eq(inventory.quantities_snapshot(P), before)
	assert_false(scene.start_lan_host(17350)["accepted"])
	scene._flush_checkpoint()
	var service := scene.get("_save_service") as SaveService
	var saved := service.load()
	assert_eq(saved["status"], SaveService.OK_STATUS)
	if saved["status"] != SaveService.OK_STATUS:
		return
	assert_eq(saved["snapshot"]["sector_id"], FoundationSector.DEEP_ID)
	scene.free()
	var restored := preload("res://src/presentation/bootstrap.tscn").instantiate()
	restored.set("_save_service", SaveService.new(directory))
	add_child_autofree(restored)
	restored.set_process(false)
	restored.set_physics_process(false)
	assert_not_null(restored.active_sector())
	if restored.active_sector() == null:
		return
	assert_eq(restored.active_sector().mode, 1)
	var restored_motor := restored.get_node("ShipMotor") as ShipMotor
	restored_motor.set_physics_process(false)
	assert_eq(restored_motor.global_position, restored.active_sector().anchor(FoundationSector.DEEP_ENTRY).position)
	var restored_loot := restored.get("_loot") as LootAuthority
	assert_not_null(restored_loot)
	if restored_loot == null:
		return
	assert_eq(restored_loot.inventory_state().quantities_snapshot(P), before)
	(restored.get_node("UI/Prg06ModeButton") as Button).pressed.emit()
	assert_eq(restored.active_sector().sector_id, FoundationSector.HAVEN_ID)
	assert_eq(restored.active_sector().mode, 0)
	assert_eq(restored_loot.inventory_state().quantities_snapshot(P), before)
	print("PRG06_SHARED_SAVE_OK")


func test_prg06_exact_predecessor_content_migration_and_lan_rejection() -> void:
	var sector := SectorRuntime.build(load(FoundationSector.PATH) as SectorDefinition)
	assert_true(sector.register_entity(P, Vector2.ZERO))
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	var dto := SaveSnapshot.capture(sector, P, motor, SeedStreams.new(606))
	assert_false(dto.is_empty())
	if dto.is_empty():
		return
	dto["content_hash"] = SaveMigrations.PRG05_CONTENT_HASH
	dto["content_manifest"] = {"algorithm": "sha256", "hash": SaveMigrations.PRG05_CONTENT_HASH, "entry_count": SaveMigrations.PRG05_CONTENT_COUNT}
	var migrated := SaveSnapshot.migrate(dto)
	assert_true(migrated["migrated"])
	assert_eq(migrated["snapshot"]["content_hash"], ContentManifest.current_hash())
	assert_eq(SaveSnapshot.validate(dto), "")
	dto["content_manifest"]["entry_count"] = 22
	assert_eq(SaveSnapshot.validate(dto), "content_hash_mismatch")
	var old_hello := SessionProtocol.client_hello({"content_hash": SaveMigrations.PRG05_CONTENT_HASH, "manifest_entry_count": SaveMigrations.PRG05_CONTENT_COUNT})
	assert_eq(SessionProtocol.validate_handshake(old_hello), SessionProtocol.REJECT_CONTENT_HASH_MISMATCH)
	print("PRG06_LEGACY_CONTENT_OK")
