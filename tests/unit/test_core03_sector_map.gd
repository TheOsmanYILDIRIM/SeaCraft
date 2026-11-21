extends GutTest

const PLAYER := FoundationSector.PLAYER
const MONSTER := "entity.core03_monster"
const TARGET := "entity.core03_target"
const ITEM_DEFINITION := preload("res://src/data/items/vs03_salvage_scrap.tres")
const LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")

class FakeCamera:
	extends Node
	func screen_to_world_position(value: Vector2) -> Vector2:
		return value
	func screen_delta_to_world_delta(value: Vector2) -> Vector2:
		return value
	func pan_world_delta(_value: Vector2) -> void:
		pass
	func zoom_by(_value: float) -> void:
		pass
	func recenter() -> void:
		pass


func test_core03_pilot_graph_and_valid_invalid_transition_rules() -> void:
	var graph := FoundationSector.graph()
	var snapshot := graph.presentation_snapshot()
	assert_eq(snapshot["sectors"].size(), 3)
	assert_eq(snapshot["connections"].size(), 4)
	var authority := RefCounted.new()
	var world := SectorWorld.new(graph, authority)
	assert_true(world.activate_initial(authority, FoundationSector.ID, FoundationSector.ENTRY, PLAYER))
	var original_position := world.active().entity_position(PLAYER)
	var rejected := world.request_transition(authority, PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "out_of_radius")
	assert_eq(world.active().sector_id, FoundationSector.ID)
	assert_eq(world.active().entity_position(PLAYER), original_position)
	rejected = world.request_transition(authority, "entity.missing", FoundationSector.GATE_FOUNDATION_OUTER)
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "invalid_actor")
	rejected = world.request_transition(authority, PLAYER, "gate.missing")
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "gate_not_found")
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	var accepted := world.request_transition(authority, PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)
	assert_true(accepted["accepted"])
	assert_eq(accepted["from_sector"], FoundationSector.ID)
	assert_eq(accepted["to_sector"], FoundationSector.OUTER_ID)
	assert_eq(accepted["entry_anchor"], FoundationSector.OUTER_WEST)
	rejected = world.request_transition(authority, PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "wrong_current_sector")
	var returned := world.request_transition(authority, PLAYER, FoundationSector.GATE_OUTER_FOUNDATION)
	assert_true(returned["accepted"])
	assert_eq(world.active().sector_id, FoundationSector.ID)

	var rows: Array[Dictionary] = [
		{"id": FoundationSector.ID, "path": FoundationSector.PATH, "anchors": PackedStringArray([FoundationSector.ENTRY])},
		{"id": FoundationSector.OUTER_ID, "path": FoundationSector.OUTER_PATH, "anchors": PackedStringArray([FoundationSector.OUTER_WEST])},
	]
	var bad_destination := _gate("gate.bad_destination", FoundationSector.ID, "sector.missing", FoundationSector.ENTRY, FoundationSector.OUTER_WEST)
	assert_eq(SectorGraph.new().configure(rows, [bad_destination], FoundationSector.ID), "invalid_destination")
	var bad_entry := _gate("gate.bad_entry", FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.ENTRY, "anchor.missing")
	assert_eq(SectorGraph.new().configure(rows, [bad_entry], FoundationSector.ID), "invalid_spawn_reference")
	print("CORE03_TRANSITION_RULES_OK")


func test_core03_failed_transition_is_atomic_and_stale_runtime_rebinds() -> void:
	var authority := RefCounted.new()
	var loader := func(path: String) -> SectorDefinition:
		if path == FoundationSector.PATH:
			return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
		return null
	var broken := SectorWorld.new(FoundationSector.graph(), authority, loader)
	assert_true(broken.activate_initial(authority, FoundationSector.ID, FoundationSector.ENTRY, PLAYER))
	assert_true(broken.active().move_entity(PLAYER, broken.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	var original := broken.active()
	var position_before := original.entity_position(PLAYER)
	var rng_probe := SeedStreams.new(991)
	var rng_before := rng_probe.snapshot_state()
	var failed := broken.request_transition(authority, PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)
	assert_false(failed["accepted"])
	assert_eq(failed["reason"], "destination_runtime_invalid")
	assert_same(broken.active(), original)
	assert_eq(broken.active().entity_position(PLAYER), position_before)
	assert_eq(rng_probe.snapshot_state(), rng_before)

	var fixture := _basic_bound_world()
	var world: SectorWorld = fixture["world"]
	var combat: CombatAuthority = fixture["combat"]
	var objects: WorldObjectAuthority = fixture["objects"]
	var old_runtime := weakref(world.active())
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	var result := world.request_transition(fixture["authority"], PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)
	assert_true(result["accepted"])
	assert_eq(world.active().sector_id, FoundationSector.OUTER_ID)
	assert_null(old_runtime.get_ref())
	assert_true(combat.is_alive(PLAYER))
	var spawned := objects.spawn(WorldObjectAuthority.CHEST, "anchor.outer_chest", 11)
	assert_false(spawned.is_empty())
	assert_true(world.active().entity_position(spawned["entity_id"]).is_finite())
	print("CORE03_STALE_RUNTIME_OK")


func test_core03_dormant_runtime_and_world_object_state_rehydrate() -> void:
	var f := _stateful_world()
	var world: SectorWorld = f["world"]
	var combat: CombatAuthority = f["combat"]
	var objects: WorldObjectAuthority = f["objects"]
	var a_chest: String = f["a_chest"]
	var a_hull: float = f["monster_hull"]
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	assert_true(world.request_transition(f["authority"], PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)["accepted"])
	var b_chest_row := objects.spawn(WorldObjectAuthority.CHEST, "anchor.outer_chest", 0)
	assert_false(b_chest_row.is_empty())
	var b_chest: String = b_chest_row["entity_id"]
	assert_true(world.active().move_entity(PLAYER, world.active().anchor("anchor.outer_chest").position))
	assert_true(objects.pickup(PLAYER, b_chest)["accepted"])
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.OUTER_WEST).position))
	assert_true(world.request_transition(f["authority"], PLAYER, FoundationSector.GATE_OUTER_FOUNDATION)["accepted"])
	assert_true(objects.is_claimed(a_chest))
	assert_true(objects.spawn(WorldObjectAuthority.CHEST, "anchor.foundation_chest", 0).is_empty())
	assert_eq(combat.hull(MONSTER), a_hull)
	assert_true(world.active().entity_position(MONSTER).is_finite())
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	assert_true(world.request_transition(f["authority"], PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)["accepted"])
	assert_true(objects.is_claimed(b_chest))
	assert_true(objects.spawn(WorldObjectAuthority.CHEST, "anchor.outer_chest", 0).is_empty())
	assert_eq(WorldObjectAuthority.stable_spawn_id(FoundationSector.ID, "anchor.foundation_chest", WorldObjectAuthority.CHEST, 0), a_chest)
	assert_ne(a_chest, b_chest)


func test_core03_save_load_in_b_then_return_a_preserves_state_and_rng() -> void:
	var f := _stateful_world()
	var world: SectorWorld = f["world"]
	var combat: CombatAuthority = f["combat"]
	var loot: LootAuthority = f["loot"]
	var objects: WorldObjectAuthority = f["objects"]
	assert_true(world.active().move_entity(PLAYER, world.active().anchor(FoundationSector.FOUNDATION_GATE).position))
	assert_true(world.request_transition(f["authority"], PLAYER, FoundationSector.GATE_FOUNDATION_OUTER)["accepted"])
	var b_chest_row := objects.spawn(WorldObjectAuthority.CHEST, "anchor.outer_chest", 0)
	assert_false(b_chest_row.is_empty())
	assert_true(world.active().move_entity(PLAYER, world.active().anchor("anchor.outer_chest").position))
	assert_true(objects.pickup(PLAYER, b_chest_row["entity_id"])["accepted"])
	var expected_rng: Dictionary = f["rng"].snapshot_state()
	var directory := "user://core03-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var service := SaveService.new(directory)
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	ship.global_position = world.active().entity_position(PLAYER)
	var authoritative := {
		"sector_world": world.snapshot_state(PLAYER),
		"combat": combat.snapshot_state(),
		"world": objects.snapshot_state(),
	}
	var dto := service.create_snapshot(world.active(), PLAYER, ship, f["rng"], SaveSnapshot.LOCAL, "", loot.snapshot_state(), authoritative)
	assert_eq(service.save(dto)["status"], SaveService.OK_STATUS)
	var loaded: Dictionary = service.load()["snapshot"]

	var authority2 := RefCounted.new()
	var world2 := SectorWorld.new(FoundationSector.graph(), authority2)
	var rng2 := SeedStreams.new(1)
	var ship2 := ShipMotor.new()
	add_child_autofree(ship2)
	ship2.set_physics_process(false)
	assert_eq(SaveSnapshot.restore(loaded, world2, authority2, PLAYER, ship2, rng2), "")
	assert_eq(world2.active().sector_id, FoundationSector.OUTER_ID)
	assert_eq(rng2.snapshot_state(), expected_rng)
	var loot2 := LootAuthority.new(world2.active(), rng2, LOOT_TABLE as LootTable, ITEM_DEFINITION as ItemDefinition)
	assert_true(loot2.bind_inventory_owner(PLAYER, {CoreCombatRules.STOWED: 12}))
	assert_true(loot2.restore_state(SaveSnapshot.loot_state(loaded)))
	var combat2 := CombatAuthority.new(world2.active(), rng2, 1)
	assert_true(combat2.register(PLAYER, "faction.core03_player", 100.0))
	assert_true(combat2.mount_harpoon(PLAYER, _harpoon_profile()))
	assert_true(combat2.register_dormant(MONSTER, "faction.core03_enemy", 50.0, FoundationSector.ID, Vector2(220, -220), TargetingService.MONSTER))
	var wreck_id := WorldObjectAuthority.stable_spawn_id(FoundationSector.ID, "anchor.foundation_wreck", WorldObjectAuthority.WRECK, 0)
	assert_true(combat2.register_dormant(wreck_id, WorldObjectAuthority.WRECK_FACTION, 40.0, FoundationSector.ID, Vector2(220, 220), TargetingService.WRECK))
	assert_true(combat2.attach_inventory(loot2))
	var saved_authority := SaveSnapshot.authoritative_state(loaded)
	assert_true(combat2.restore_state(saved_authority["combat"]))
	var objects2 := WorldObjectAuthority.new(world2.active(), loot2, combat2, LOOT_TABLE as LootTable, PLAYER)
	assert_true(objects2.restore_state(saved_authority["world"]))
	assert_true(world2.bind_runtime(SectorRuntimeBinding.new(combat2, loot2, objects2)))
	assert_true(world2.active().move_entity(PLAYER, world2.active().anchor(FoundationSector.OUTER_WEST).position))
	assert_true(world2.request_transition(authority2, PLAYER, FoundationSector.GATE_OUTER_FOUNDATION)["accepted"])
	assert_eq(combat2.hull(MONSTER), f["monster_hull"])
	assert_true(objects2.is_claimed(f["a_chest"]))
	assert_true(objects2.spawn(WorldObjectAuthority.CHEST, "anchor.foundation_chest", 0).is_empty())
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(path), OK)
	assert_eq(DirAccess.remove_absolute(directory), OK)
	print("CORE03_MULTI_SECTOR_PERSISTENCE_OK")


func test_core03_safe_zone_hostile_negative_matrix() -> void:
	var cases := [
		{"kind": "cannon", "protected_attacker": true, "target_class": TargetingService.SHIP},
		{"kind": "cannon", "protected_attacker": false, "target_class": TargetingService.SHIP},
		{"kind": "harpoon", "protected_attacker": true, "target_class": TargetingService.MONSTER},
		{"kind": "harpoon", "protected_attacker": false, "target_class": TargetingService.WRECK},
	]
	for row in cases:
		var state := _safe_combat(str(row["target_class"]), bool(row["protected_attacker"]))
		var combat: CombatAuthority = state["combat"]
		var before := [combat.snapshot_state(), state["rng"].snapshot_state(), state["loot"].snapshot_state()]
		var result: Dictionary
		if row["kind"] == "cannon":
			result = combat.fire(PLAYER, 0.0, CombatAuthority.fire_intent(TARGET))
		else:
			result = combat.harpoon(PLAYER, CombatAuthority.harpoon_intent(TARGET))
		assert_false(result["accepted"], str(row))
		assert_eq(result["reason"], "safe_zone", str(row))
		assert_eq([combat.snapshot_state(), state["rng"].snapshot_state(), state["loot"].snapshot_state()], before, str(row))
	print("CORE03_SAFE_ZONE_MATRIX_OK")


func test_core03_hazard_weighted_route_and_cache_invalidation() -> void:
	var definition := ResourceLoader.load(FoundationSector.OUTER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	var runtime := SectorRuntime.build(definition)
	assert_not_null(runtime)
	var nav := runtime.navigation
	var start := runtime.anchor(FoundationSector.OUTER_WEST).position
	var goal := runtime.anchor(FoundationSector.OUTER_EAST).position
	var route := nav.path(start, goal)
	assert_gte(route.size(), 4)
	var initial_searches := nav.search_count
	assert_eq(nav.path(start, goal), route)
	assert_eq(nav.search_count, initial_searches)
	var top := route[1].y < 0.0
	var penalized := [0, 1] if top else [2, 3]
	assert_true(nav.set_hazard_cost(penalized[0], 100.0, 0.0, 0.0, 0.0))
	assert_true(nav.set_hazard_cost(penalized[1], 100.0, 0.0, 0.0, 0.0))
	var changed := nav.path(start, goal)
	assert_gte(changed.size(), 4)
	assert_lt(changed[1].y * route[1].y, 0.0)
	assert_eq(nav.search_count, initial_searches + 1)
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	var executor := NpcIntentExecutor.new()
	assert_true(executor.configure(motor, nav))
	assert_true(executor.request_destination(start, goal))
	assert_eq(executor.path_request_count, 1)
	print("CORE03_HAZARD_ROUTE_OK")


func test_core03_invalid_hazard_input_no_mutation() -> void:
	var runtime := SectorRuntime.build(ResourceLoader.load(FoundationSector.OUTER_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition)
	var nav := runtime.navigation
	var start := runtime.anchor(FoundationSector.OUTER_WEST).position
	var goal := runtime.anchor(FoundationSector.OUTER_EAST).position
	var route := nav.path(start, goal)
	var before := nav.snapshot_hazard_state()
	var revision := nav.hazard_revision
	var searches := nav.search_count
	assert_false(nav.set_hazard_cost(0, NAN, 0.0, 0.0, 0.0))
	assert_false(nav.set_hazard_cost(999, 1.0, 0.0, 0.0, 0.0))
	assert_eq(nav.snapshot_hazard_state(), before)
	assert_eq(nav.hazard_revision, revision)
	assert_eq(nav.path(start, goal), route)
	assert_eq(nav.search_count, searches)


func test_core03_world_map_snapshot_is_detached() -> void:
	var graph := FoundationSector.graph()
	var first := graph.presentation_snapshot()
	assert_true(DtoContract.is_primitive_safe(first))
	first["sectors"][0]["label_id"] = "label.forged"
	first["connections"].clear()
	var second := graph.presentation_snapshot()
	assert_ne(second["sectors"][0]["label_id"], "label.forged")
	assert_eq(second["connections"].size(), 4)
	var haven_found := false
	for row: Dictionary in second["sectors"]:
		if row["sector_id"] == FoundationSector.HAVEN_ID:
			haven_found = true
			assert_true(row["safe_haven"])
	assert_true(haven_found)


func test_core03_minimap_transform_round_trip_aspect_and_clamp() -> void:
	var world_bounds := Rect2(-640, -360, 1280, 720)
	var map_rect := Rect2(20, 30, 320, 110)
	for point in [Vector2(-500, -200), Vector2.ZERO, Vector2(500, 200)]:
		var mapped := MinimapTransform.world_to_map(point, world_bounds, map_rect, false)
		assert_true(mapped.is_finite())
		var round_trip := MinimapTransform.map_to_world(mapped, world_bounds, map_rect, false)
		assert_almost_eq(round_trip.x, point.x, 0.0001)
		assert_almost_eq(round_trip.y, point.y, 0.0001)
	var clamped := MinimapTransform.world_to_map(Vector2(5000, -5000), world_bounds, map_rect, true)
	assert_eq(clamped, Vector2(map_rect.end.x, map_rect.position.y))
	assert_false(MinimapTransform.world_to_map(Vector2(5000, 0), world_bounds, map_rect, false).is_finite())
	assert_true(MinimapTransform.world_rect_to_map(Rect2(-100, -50, 200, 100), world_bounds, map_rect).has_area())
	print("CORE03_MAP_TRANSFORM_OK")


func test_core03_map_gestures_do_not_leak_world_input() -> void:
	var controller := GameplayInputController.new()
	var camera := FakeCamera.new()
	controller.set("_camera", camera)
	var emitted := [0]
	controller.command_emitted.connect(func(_command: Dictionary) -> void: emitted[0] += 1)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = Vector2(30, 40)
	controller.set_world_input_blocked(true)
	controller.process_device_event(event, false)
	assert_eq(emitted[0], 0)
	controller.set_world_input_blocked(false)
	controller.process_device_event(event, false)
	assert_eq(emitted[0], 1)
	var graph := FoundationSector.graph()
	var before := graph.presentation_snapshot()
	var overlay := SectorMapOverlay.new()
	add_child_autofree(overlay)
	overlay.size = Vector2(320, 180)
	overlay.configure_world(before, FoundationSector.ID)
	assert_true(overlay.apply_pan(Vector2(12, -7)))
	assert_true(overlay.apply_zoom(1.25))
	assert_eq(graph.presentation_snapshot(), before)
	overlay.set_world_view(false)
	assert_false(overlay.apply_pan(Vector2.ONE))


func _basic_bound_world() -> Dictionary:
	var authority := RefCounted.new()
	var world := SectorWorld.new(FoundationSector.graph(), authority)
	assert_true(world.activate_initial(authority, FoundationSector.ID, FoundationSector.ENTRY, PLAYER))
	var rng := SeedStreams.new(303)
	var loot := LootAuthority.new(world.active(), rng, LOOT_TABLE as LootTable, ITEM_DEFINITION as ItemDefinition)
	assert_true(loot.bind_inventory_owner(PLAYER, {CoreCombatRules.STOWED: 12, CoreCombatRules.ROUND: 12}))
	loot.initialize_missing_stock({CoreCombatRules.STOWED: 12, CoreCombatRules.ROUND: 12})
	var combat := CombatAuthority.new(world.active(), rng, 1)
	assert_true(combat.register(PLAYER, "faction.core03_player", 100.0))
	assert_true(combat.attach_inventory(loot))
	var objects := WorldObjectAuthority.new(world.active(), loot, combat, LOOT_TABLE as LootTable, PLAYER)
	assert_true(world.bind_runtime(SectorRuntimeBinding.new(combat, loot, objects)))
	return {"authority": authority, "world": world, "rng": rng, "loot": loot, "combat": combat, "objects": objects}


func _stateful_world() -> Dictionary:
	var f := _basic_bound_world()
	var world: SectorWorld = f["world"]
	var combat: CombatAuthority = f["combat"]
	var objects: WorldObjectAuthority = f["objects"]
	assert_true(combat.mount_harpoon(PLAYER, _harpoon_profile()))
	var chest := objects.spawn(WorldObjectAuthority.CHEST, "anchor.foundation_chest", 0)
	assert_false(chest.is_empty())
	var a_chest: String = chest["entity_id"]
	assert_true(world.active().move_entity(PLAYER, world.active().anchor("anchor.foundation_chest").position))
	assert_true(objects.pickup(PLAYER, a_chest)["accepted"])
	var monster_position := world.active().anchor("anchor.foundation_monster").position
	assert_true(world.active().register_entity(MONSTER, monster_position))
	assert_true(combat.register(MONSTER, "faction.core03_enemy", 50.0, null, 0.0, 0.0, true, {}, 0, TargetingService.MONSTER))
	assert_false(objects.spawn(WorldObjectAuthority.WRECK, "anchor.foundation_wreck", 0, 40.0).is_empty())
	assert_true(combat.select(PLAYER, MONSTER))
	var damage := combat.harpoon(PLAYER, CombatAuthority.harpoon_intent(MONSTER))
	assert_true(damage["accepted"])
	assert_gt(damage["applied_damage"], 0.0)
	f["a_chest"] = a_chest
	f["monster_hull"] = combat.hull(MONSTER)
	return f


func _safe_combat(target_class: String, protected_attacker: bool) -> Dictionary:
	var definition := ResourceLoader.load(FoundationSector.HAVEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	var sector := SectorRuntime.build(definition)
	var attacker_position := Vector2.ZERO if protected_attacker else Vector2(0, 340)
	var target_position := Vector2(0, 340) if protected_attacker else Vector2.ZERO
	assert_true(sector.register_entity(PLAYER, attacker_position))
	assert_true(sector.register_entity(TARGET, target_position))
	var rng := SeedStreams.new(404)
	var loot := LootAuthority.new(sector, rng, LOOT_TABLE as LootTable, ITEM_DEFINITION as ItemDefinition)
	var supplies := {CoreCombatRules.STOWED: 3, CoreCombatRules.ROUND: 3}
	assert_true(loot.bind_inventory_owner(PLAYER, supplies))
	loot.initialize_missing_stock(supplies)
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.core03_cannon"
	weapon.base_damage = 20.0
	weapon.range_meters = 700.0
	weapon.reload_seconds = 1.0
	weapon.accuracy = 1.0
	weapon.crit_chance = 0.5
	weapon.crit_multiplier = 1.5
	weapon.broadside_half_arc_degrees = 45.0
	var combat := CombatAuthority.new(sector, rng, 1)
	assert_true(combat.register(PLAYER, "faction.core03_player", 100.0, weapon))
	assert_true(combat.register(TARGET, "faction.core03_enemy", 100.0, null, 0.0, 0.0, true, {}, 0, target_class))
	assert_true(combat.attach_inventory(loot))
	var ammo := CoreCombatRules.ammo("ammo.core03_round", CoreCombatRules.ROUND, CoreCombatRules.NEUTRAL, 1.0)
	assert_true(combat.register_ammo(ammo))
	assert_true(combat.mount_ammo(PLAYER, PackedStringArray([ammo.stable_id])))
	assert_true(combat.mount_harpoon(PLAYER, _harpoon_profile()))
	assert_true(combat.select(PLAYER, TARGET))
	return {"combat": combat, "rng": rng, "loot": loot}


func _harpoon_profile() -> HarpoonProfile:
	var profile := HarpoonProfile.new()
	profile.stable_id = "harpoon.core03"
	profile.display_name = "CORE-03 Harpoon"
	profile.base_damage = 7.0
	profile.range_meters = 1000.0
	profile.reload_seconds = 1.0
	profile.element_id = CoreCombatRules.NEUTRAL
	profile.target_classes = PackedStringArray([TargetingService.MONSTER, TargetingService.WRECK])
	profile.item_id = CoreCombatRules.STOWED
	return profile


func _gate(id: String, from_sector: String, to_sector: String, exit_anchor: String, entry_anchor: String) -> SectorGate:
	var edge := SectorGate.new()
	edge.stable_id = id
	edge.from_sector = from_sector
	edge.to_sector = to_sector
	edge.exit_anchor = exit_anchor
	edge.entry_anchor = entry_anchor
	edge.activation_radius = 64.0
	return edge
