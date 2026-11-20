extends GutTest

const PLAYER := "entity.player"
const NPC := "entity.vs02_sc03"
const ITEM_PATH := "res://src/data/items/vs03_salvage_scrap.tres"
const TABLE_PATH := "res://src/data/loot/vs03_sc03_loot_table.tres"

var sector: SectorRuntime
var streams: SeedStreams
var loot: LootAuthority
var item: ItemDefinition
var table: LootTable


func before_each() -> void:
	sector = SectorRuntime.new()
	sector.sector_id = FoundationSector.ID
	sector.bounds = Rect2(-640, -360, 1280, 720)
	assert_true(sector.register_entity(PLAYER, Vector2(-500, 260)))
	assert_true(sector.register_entity(NPC, Vector2(-520, 260)))
	streams = SeedStreams.new(424242)
	item = ResourceLoader.load(ITEM_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	table = ResourceLoader.load(TABLE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as LootTable
	assert_not_null(item)
	assert_not_null(table)
	loot = LootAuthority.new(sector, streams, table, item, true)


func _drop(sequence: int = 7) -> Dictionary:
	return loot.on_ship_sunk(NPC, sequence, sector.entity_position(NPC))


func _pickup(drop_id: String) -> Dictionary:
	return loot.pickup(PLAYER, LootAuthority.pickup_intent(drop_id))


func test_loot_table_is_typed_and_valid() -> void:
	assert_true(table is LootTable)
	assert_true(table.valid())
	assert_eq(table.stable_id, "loot_table.vs03_sc03")
	assert_eq(item.stable_id, "item.vs03_salvage_scrap")


func test_deterministic_loot_seed_and_state() -> void:
	var first := _drop()
	var first_state := streams.snapshot_state()
	before_each()
	assert_eq(_drop(), first)
	assert_eq(streams.snapshot_state(), first_state)


func test_loot_uses_only_loot_rng_stream() -> void:
	var before: Dictionary = streams.snapshot_state()["streams"]
	assert_false(_drop().is_empty())
	var after: Dictionary = streams.snapshot_state()["streams"]
	assert_eq(before["world"], after["world"])
	assert_eq(before["encounter"], after["encounter"])
	assert_ne(before["loot"], after["loot"])


func test_sunk_event_creates_one_drop() -> void:
	var drop := _drop()
	assert_false(drop.is_empty())
	assert_true(loot.has_drop(drop["drop_id"]))


func test_duplicate_sunk_event_creates_no_second_drop_or_rng_draw() -> void:
	var first := _drop()
	var state := streams.snapshot_state()
	assert_true(loot.on_ship_sunk(NPC, 7, sector.entity_position(NPC)).is_empty())
	assert_eq(streams.snapshot_state(), state)
	assert_eq(loot.snapshot_state()["drops"].size(), 1)
	assert_true(loot.has_drop(first["drop_id"]))


func test_drop_id_is_stable() -> void:
	assert_eq(_drop()["drop_id"], "drop.entity_vs02_sc03.7")


func test_valid_pickup_updates_inventory_and_removes_world_drop() -> void:
	var drop := _drop()
	var result := _pickup(drop["drop_id"])
	assert_true(result["accepted"])
	assert_eq(loot.inventory_quantity(item.stable_id), drop["quantity"])
	assert_false(loot.has_drop(drop["drop_id"]))
	assert_eq(sector.entity_position(drop["drop_id"]), Vector2.INF)


func test_pickup_range_boundary() -> void:
	var drop := _drop()
	assert_true(sector.move_entity(PLAYER, Vector2(drop["x"] + LootAuthority.PICKUP_RADIUS, drop["y"])))
	assert_true(_pickup(drop["drop_id"])["accepted"])


func test_out_of_range_pickup_has_no_mutation() -> void:
	var drop := _drop()
	assert_true(sector.move_entity(PLAYER, Vector2(drop["x"] + LootAuthority.PICKUP_RADIUS + 1.0, drop["y"])))
	var before := loot.snapshot_state()
	assert_eq(_pickup(drop["drop_id"])["reason"], "out_of_range")
	assert_eq(loot.snapshot_state(), before)


func test_invalid_nonexistent_drop_has_no_mutation() -> void:
	var before := loot.snapshot_state()
	assert_eq(_pickup("drop.absent.1")["reason"], "drop_not_found")
	assert_eq(loot.snapshot_state(), before)


func test_duplicate_pickup_is_idempotent() -> void:
	var drop := _drop()
	assert_true(_pickup(drop["drop_id"])["accepted"])
	var quantity := loot.inventory_quantity(item.stable_id)
	assert_eq(_pickup(drop["drop_id"])["reason"], "already_claimed")
	assert_eq(loot.inventory_quantity(item.stable_id), quantity)


func test_invalid_item_and_quantity_state_rejected() -> void:
	_drop()
	var state := loot.snapshot_state()
	state["drops"][0]["item_id"] = "item.invalid"
	assert_false(loot.validate_state(state))
	state = loot.snapshot_state()
	state["drops"][0]["quantity"] = -1
	assert_false(loot.validate_state(state))


func test_inventory_overflow_is_rejected_without_claim() -> void:
	var drop := _drop()
	var state := loot.snapshot_state()
	state["inventory"][item.stable_id] = LootAuthority.MAX_QUANTITY
	assert_true(loot.restore_state(state))
	assert_eq(_pickup(drop["drop_id"])["reason"], "quantity_overflow")
	assert_false(loot.is_claimed(drop["drop_id"]))
	assert_eq(loot.inventory_quantity(item.stable_id), LootAuthority.MAX_QUANTITY)


func test_save_load_unclaimed_drop_round_trip() -> void:
	var drop := _drop()
	var restored := _round_trip(loot)
	assert_true(restored.has_drop(drop["drop_id"]))
	assert_eq(restored.drop_snapshot(drop["drop_id"]), drop)


func test_save_load_claimed_drop_does_not_respawn() -> void:
	var drop := _drop()
	assert_true(_pickup(drop["drop_id"])["accepted"])
	var restored := _round_trip(loot)
	assert_true(restored.is_claimed(drop["drop_id"]))
	assert_false(restored.has_drop(drop["drop_id"]))


func test_save_load_inventory_is_preserved() -> void:
	var drop := _drop()
	assert_true(_pickup(drop["drop_id"])["accepted"])
	var restored := _round_trip(loot)
	assert_eq(restored.inventory_quantity(item.stable_id), drop["quantity"])


func test_load_then_same_sunk_event_does_not_duplicate() -> void:
	var drop := _drop()
	var restored := _round_trip(loot)
	var state := streams.snapshot_state()
	assert_true(restored.on_ship_sunk(NPC, 7, Vector2(-520, 260)).is_empty())
	assert_eq(streams.snapshot_state(), state)
	assert_true(restored.has_drop(drop["drop_id"]))


func test_loot_rng_continues_after_save_load() -> void:
	assert_false(_drop(7).is_empty())
	var saved_rng := streams.snapshot_state()
	var expected := loot.on_ship_sunk(NPC, 8, Vector2(-518, 260))
	assert_true(streams.restore_state(saved_rng))
	var restored := _round_trip(loot, saved_rng)
	var actual := restored.on_ship_sunk(NPC, 9, Vector2(-516, 260))
	assert_eq(actual["quantity"], expected["quantity"])


func test_presentation_snapshot_cannot_mutate_authority() -> void:
	var drop := _drop()
	var snapshot := loot.drop_snapshot(drop["drop_id"])
	snapshot["quantity"] = 999999
	snapshot["item_id"] = "item.fake"
	assert_eq(loot.drop_snapshot(drop["drop_id"]), drop)


func test_authority_disabled_rejects_mutation() -> void:
	loot.set_authority_enabled(false)
	var before_rng := streams.snapshot_state()
	assert_true(_drop().is_empty())
	assert_eq(streams.snapshot_state(), before_rng)
	loot.set_authority_enabled(true)
	var drop := _drop()
	loot.set_authority_enabled(false)
	var before := loot.snapshot_state()
	assert_eq(_pickup(drop["drop_id"])["reason"], "authority_disabled")
	assert_eq(loot.snapshot_state(), before)


func test_spatial_pickup_query_is_bounded() -> void:
	var drop := _drop()
	for i in 300:
		assert_true(sector.register_entity("entity.remote_%03d" % i, Vector2(500, 300)))
	assert_eq(loot.nearest_pickup(PLAYER), drop["drop_id"])
	assert_lt(loot.last_query_inspected(), 10)


func test_loot_state_is_primitive_safe_and_has_no_runtime_objects() -> void:
	_drop()
	var state := loot.snapshot_state()
	assert_true(DtoContract.is_primitive_safe(state))
	assert_false(state.has("resource"))
	assert_false(state.has("node"))


func test_pickup_button_consumes_touch_before_world_command() -> void:
	var view := SubViewport.new()
	view.size = Vector2i(512, 384)
	view.gui_disable_input = false
	add_child_autofree(view)
	var button := LootPickupButton.new()
	button.position = Vector2(100, 100)
	button.size = Vector2(224, 132)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	var captured := [0]
	button.touch_captured.connect(func() -> void: captured[0] += 1)
	view.add_child(button)
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(160, 140)
	touch.pressed = true
	view.push_input(touch, true)
	assert_eq(captured[0], 1)


func _round_trip(source: LootAuthority, rng_state: Dictionary = {}) -> LootAuthority:
	var directory := "user://vs03-save-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var service := SaveService.new(directory)
	var authority := RefCounted.new()
	var world := SectorWorld.new(FoundationSector.graph(), authority)
	assert_true(world.activate_initial(authority, FoundationSector.ID, FoundationSector.ENTRY, FoundationSector.PLAYER))
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	ship.global_position = world.active().entity_position(FoundationSector.PLAYER)
	var snapshot := service.create_snapshot(world.active(), FoundationSector.PLAYER, ship, streams, SaveSnapshot.LOCAL, "", source.snapshot_state())
	assert_eq(service.save(snapshot)["status"], SaveService.OK_STATUS)
	var loaded: Dictionary = service.load()["snapshot"]
	var resumed_streams := SeedStreams.new(1)
	assert_eq(SaveSnapshot.restore(loaded, world, authority, FoundationSector.PLAYER, ship, resumed_streams), "")
	if not rng_state.is_empty():
		assert_true(resumed_streams.restore_state(rng_state))
	streams = resumed_streams
	var restored := LootAuthority.new(world.active(), streams, table, item, true)
	assert_true(restored.restore_state(SaveSnapshot.loot_state(loaded)))
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(path), OK)
	assert_eq(DirAccess.remove_absolute(directory), OK)
	return restored
