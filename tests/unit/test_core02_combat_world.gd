extends GutTest

const PLAYER := "entity.core02_player"
const SHIP := "entity.core02_ship"
const MONSTER := "entity.core02_monster"
const ROUND_AMMO := "ammo.core02_round"
const HARPOON_ITEM := "item.core02_harpoon"
const MONSTER_ANCHOR := "anchor.core02_monster"
const CHEST_ANCHOR := "anchor.core02_chest"
const GLITTER_ANCHOR := "anchor.core02_glitter"
const WRECK_ANCHOR := "anchor.core02_wreck"
const ITEM_DEFINITION := preload("res://src/data/items/vs03_salvage_scrap.tres")
const LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")

var sector: SectorRuntime
var rng: SeedStreams
var loot: LootAuthority
var combat: CombatAuthority
var world_objects: WorldObjectAuthority
var cannon: WeaponDefinition
var harpoon_profile: HarpoonProfile
var monster_definition: MonsterDefinition
var chest_id := ""
var glitter_id := ""
var wreck_id := ""


func _setup(spawn_world: bool = true, enabled: bool = true) -> void:
	sector = _build_sector()
	assert_not_null(sector)
	assert_true(sector.register_entity(PLAYER, Vector2.ZERO))
	assert_true(sector.register_entity(SHIP, Vector2(0, 80)))
	rng = SeedStreams.new(202602)
	loot = LootAuthority.new(sector, rng, LOOT_TABLE as LootTable, ITEM_DEFINITION as ItemDefinition, enabled)
	assert_true(loot.bind_inventory_owner(PLAYER, {CoreCombatRules.ROUND: 4, HARPOON_ITEM: 4}))
	loot.initialize_missing_stock({CoreCombatRules.ROUND: 4, HARPOON_ITEM: 4})
	cannon = WeaponDefinition.new()
	cannon.stable_id = "weapon.core02_cannon"
	cannon.base_damage = 12.0
	cannon.min_range_meters = 0.0
	cannon.range_meters = 300.0
	cannon.reload_seconds = 1.0
	cannon.accuracy = 1.0
	cannon.crit_chance = 0.0
	cannon.crit_multiplier = 1.5
	combat = CombatAuthority.new(sector, rng, 1, enabled)
	assert_true(combat.register(PLAYER, "faction.core02_player", 100.0, cannon))
	assert_true(combat.register(SHIP, "faction.core02_enemy", 100.0, cannon))
	assert_true(combat.attach_inventory(loot))
	assert_true(combat.register_ammo(CoreCombatRules.ammo(ROUND_AMMO, CoreCombatRules.ROUND, CoreCombatRules.NEUTRAL, 1.0)))
	assert_true(combat.mount_ammo(PLAYER, PackedStringArray([ROUND_AMMO])))
	harpoon_profile = HarpoonProfile.new()
	harpoon_profile.stable_id = "harpoon.core02_standard"
	harpoon_profile.display_name = "Core 02 Harpoon"
	harpoon_profile.base_damage = 20.0
	harpoon_profile.range_meters = 180.0
	harpoon_profile.reload_seconds = 1.0
	harpoon_profile.element_id = CoreCombatRules.FIRE
	harpoon_profile.item_id = HARPOON_ITEM
	assert_true(harpoon_profile.valid())
	assert_true(combat.mount_harpoon(PLAYER, harpoon_profile))
	monster_definition = MonsterDefinition.new()
	monster_definition.stable_id = "monster.core02_test"
	monster_definition.display_name = "Core 02 Monster"
	monster_definition.max_health = 40.0
	monster_definition.faction_id = "faction.core02_monster"
	monster_definition.elemental_resistances = {CoreCombatRules.FIRE: 0.5}
	monster_definition.loot_table_id = (LOOT_TABLE as LootTable).stable_id
	monster_definition.territory_radius = 64.0
	assert_true(monster_definition.valid())
	assert_true(combat.register_monster(MONSTER, monster_definition, MONSTER_ANCHOR))
	world_objects = WorldObjectAuthority.new(sector, loot, combat, LOOT_TABLE as LootTable, PLAYER, enabled)
	chest_id = WorldObjectAuthority.stable_spawn_id(sector.sector_id, CHEST_ANCHOR, WorldObjectAuthority.CHEST, 0)
	glitter_id = WorldObjectAuthority.stable_spawn_id(sector.sector_id, GLITTER_ANCHOR, WorldObjectAuthority.GLITTER, 0)
	wreck_id = WorldObjectAuthority.stable_spawn_id(sector.sector_id, WRECK_ANCHOR, WorldObjectAuthority.WRECK, 0)
	if spawn_world:
		assert_eq(world_objects.spawn(WorldObjectAuthority.CHEST, CHEST_ANCHOR, 0)["entity_id"], chest_id)
		assert_eq(world_objects.spawn(WorldObjectAuthority.GLITTER, GLITTER_ANCHOR, 0)["entity_id"], glitter_id)
		assert_eq(world_objects.spawn(WorldObjectAuthority.WRECK, WRECK_ANCHOR, 0, 15.0)["entity_id"], wreck_id)


func _build_sector() -> SectorRuntime:
	var definition := SectorDefinition.new()
	definition.stable_id = "sector.core02"
	definition.display_name = "CORE-02 Test Sector"
	definition.label_id = "label.core02"
	definition.bounds = Rect2(-640, -360, 1280, 720)
	var navigation := SectorNavigationFixture.new()
	navigation.clearance = 0.0
	navigation.obstacles = []
	navigation.waypoints = PackedVector2Array()
	definition.navigation_fixture = navigation
	definition.spawn_anchors = [
		_anchor(MONSTER_ANCHOR, "monster_territory", Vector2(0, 100)),
		_anchor(CHEST_ANCHOR, WorldObjectAuthority.CHEST, Vector2(30, 0)),
		_anchor(GLITTER_ANCHOR, WorldObjectAuthority.GLITTER, Vector2(55, 0)),
		_anchor(WRECK_ANCHOR, WorldObjectAuthority.WRECK, Vector2(0, 120)),
	]
	return SectorRuntime.build(definition)


func _anchor(id: String, category: String, position: Vector2) -> SectorAnchor:
	var anchor := SectorAnchor.new()
	anchor.stable_id = id
	anchor.sector_id = "sector.core02"
	anchor.category = category
	anchor.position = position
	return anchor


func _select(id: String) -> void:
	combat.clear_target(PLAYER)
	assert_true(combat.select(PLAYER, id))


func _fire(id: String) -> Dictionary:
	return combat.fire(PLAYER, 0.0, CombatAuthority.fire_intent(id))


func _harpoon(id: String) -> Dictionary:
	return combat.harpoon(PLAYER, CombatAuthority.harpoon_intent(id))


func _state() -> Array:
	return [combat.snapshot_state(), rng.snapshot_state(), loot.snapshot_state(), world_objects.snapshot_state()]


func _set_hull(id: String, hull: float) -> void:
	var state := combat.snapshot_state()
	for entry: Dictionary in state["combatants"]:
		if entry["entity_id"] == id:
			entry["hull"] = hull
	assert_true(combat.restore_state(state))


func _hull(id: String) -> float:
	return combat.hull(id)


func test_core02_definitions_and_target_tag_matrix() -> void:
	_setup()
	assert_eq(monster_definition.definition_type(), "monster")
	assert_eq(harpoon_profile.definition_type(), "harpoon")
	for row: Array in [
		[TargetingService.CANNON, SHIP, true],
		[TargetingService.CANNON, MONSTER, false],
		[TargetingService.CANNON, wreck_id, false],
		[TargetingService.CANNON, chest_id, false],
		[TargetingService.CANNON, glitter_id, false],
		[TargetingService.HARPOON, MONSTER, true],
		[TargetingService.HARPOON, wreck_id, true],
		[TargetingService.HARPOON, SHIP, false],
		[TargetingService.HARPOON, chest_id, false],
		[TargetingService.HARPOON, glitter_id, false],
	]:
		_setup()
		var kind: String = row[0]
		var id: String = row[1]
		if combat.has_combatant(id):
			_select(id)
		var result := _fire(id) if kind == TargetingService.CANNON else _harpoon(id)
		assert_eq(result["accepted"], row[2], str(row))
	var invalid := harpoon_profile.duplicate() as HarpoonProfile
	invalid.target_classes = PackedStringArray([TargetingService.SHIP])
	assert_false(invalid.valid())
	invalid = harpoon_profile.duplicate() as HarpoonProfile
	invalid.element_id = "element.invalid"
	assert_false(invalid.valid())
	print("CORE02_TARGET_TAG_MATRIX_OK")


func test_core02_wrong_target_rejection_is_atomic() -> void:
	_setup()
	_select(MONSTER)
	var before := _state()
	var result := _fire(MONSTER)
	assert_false(result["accepted"])
	assert_eq(result["reason"], "wrong_target_class")
	assert_eq(_state(), before)
	assert_eq(loot.inventory_quantity(CoreCombatRules.ROUND), 4)
	_select(SHIP)
	before = _state()
	result = _harpoon(SHIP)
	assert_false(result["accepted"])
	assert_eq(result["reason"], "wrong_target_class")
	assert_eq(_state(), before)
	assert_eq(loot.inventory_quantity(HARPOON_ITEM), 4)
	before = _state()
	result = _harpoon(chest_id)
	assert_false(result["accepted"])
	assert_eq(result["reason"], "invalid_target")
	assert_eq(_state(), before)


func test_core02_harpoon_damage_range_cooldown_and_elements() -> void:
	_setup()
	_select(MONSTER)
	var result := _harpoon(MONSTER)
	assert_true(result["accepted"])
	assert_eq(result["applied_damage"], 10.0)
	assert_eq(_hull(MONSTER), 30.0)
	assert_eq(loot.inventory_quantity(HARPOON_ITEM), 3)
	var after := _state()
	var cooldown := _harpoon(MONSTER)
	assert_false(cooldown["accepted"])
	assert_eq(cooldown["reason"], "reloading")
	assert_eq(_state(), after)
	combat.advance_tick()
	assert_true(combat.configure_defense(MONSTER, 0.0, {CoreCombatRules.FIRE: -0.5}, 0.0, 0.0))
	result = _harpoon(MONSTER)
	assert_true(result["accepted"])
	assert_eq(result["applied_damage"], 30.0)
	assert_true(result["destroyed"])
	_setup()
	assert_true(sector.move_entity(PLAYER, Vector2(-300, 0)))
	_select(MONSTER)
	var before := _state()
	result = _harpoon(MONSTER)
	assert_false(result["accepted"])
	assert_eq(result["reason"], "out_of_range")
	assert_eq(_state(), before)
	print("CORE02_HARPOON_DAMAGE_OK")


func test_core02_monster_territory_death_and_loot_once() -> void:
	_setup()
	assert_true(combat.update_monster_position(MONSTER, Vector2(400, 100)))
	assert_lte(sector.entity_position(MONSTER).distance_to(Vector2(0, 100)), 64.001)
	_set_hull(MONSTER, 10.0)
	assert_true(combat.configure_defense(MONSTER, 0.0, {}, 0.0, 0.0))
	var events := [0]
	combat.monster_defeated.connect(func(id: String, sequence: int) -> void:
		events[0] += 1
		var reward := loot.grant_from_table(PLAYER, "monster_defeat.%s.seq_%d" % [id, sequence], LOOT_TABLE as LootTable)
		assert_true(reward["accepted"])
	)
	_select(MONSTER)
	var result := _harpoon(MONSTER)
	assert_true(result["accepted"])
	assert_true(result["destroyed"])
	assert_eq(events[0], 1)
	var quantity := loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id)
	var rng_after := rng.snapshot_state()
	result = _harpoon(MONSTER)
	assert_false(result["accepted"])
	assert_eq(events[0], 1)
	assert_eq(loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id), quantity)
	assert_eq(rng.snapshot_state(), rng_after)


func test_core02_world_spawn_pickup_duplicate_and_spatial_bounds() -> void:
	_setup()
	assert_false(chest_id.is_empty())
	var rng_before := rng.snapshot_state()
	assert_true(world_objects.spawn(WorldObjectAuthority.CHEST, CHEST_ANCHOR, 0).is_empty())
	assert_eq(rng.snapshot_state(), rng_before)
	var first := world_objects.pickup(PLAYER, chest_id)
	assert_true(first["accepted"])
	var quantity := loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id)
	var after_claim_rng := rng.snapshot_state()
	var duplicate := world_objects.pickup(PLAYER, chest_id)
	assert_false(duplicate["accepted"])
	assert_eq(duplicate["reason"], "already_claimed")
	assert_eq(loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id), quantity)
	assert_eq(rng.snapshot_state(), after_claim_rng)
	assert_true(sector.move_entity(PLAYER, Vector2(-200, 0)))
	var before := _state()
	var out := world_objects.pickup(PLAYER, glitter_id)
	assert_false(out["accepted"])
	assert_eq(out["reason"], "out_of_range")
	assert_eq(_state(), before)
	assert_true(sector.move_entity(PLAYER, Vector2.ZERO))
	for i in 200:
		assert_true(sector.register_entity("entity.core02_remote_%03d" % i, Vector2(500, 300)))
	assert_eq(world_objects.nearest_pickup(PLAYER), glitter_id)
	assert_lt(world_objects.last_query_inspected(), 10)
	print("CORE02_DUPLICATE_SPAWN_CLAIM_OK")


func test_core02_wreck_harpoon_destroy_loot_once() -> void:
	_setup()
	var outcomes: Array = []
	combat.wreck_destroyed.connect(func(id: String, sequence: int) -> void:
		outcomes.append(world_objects.on_wreck_destroyed(PLAYER, id, sequence))
	)
	_select(wreck_id)
	var result := _harpoon(wreck_id)
	assert_true(result["accepted"])
	assert_true(result["destroyed"])
	assert_eq(outcomes.size(), 1)
	assert_true(outcomes[0]["accepted"])
	assert_true(world_objects.is_claimed(wreck_id))
	var quantity := loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id)
	var rng_after := rng.snapshot_state()
	var duplicate := world_objects.on_wreck_destroyed(PLAYER, wreck_id, result["sequence_id"])
	assert_false(duplicate["accepted"])
	assert_eq(duplicate["reason"], "already_claimed")
	assert_eq(loot.inventory_quantity((ITEM_DEFINITION as ItemDefinition).stable_id), quantity)
	assert_eq(rng.snapshot_state(), rng_after)


func test_core02_world_persistence_claim_ledger_health_and_rng_continuation() -> void:
	_setup()
	assert_true(world_objects.pickup(PLAYER, glitter_id)["accepted"])
	_set_hull(MONSTER, 23.0)
	_set_hull(wreck_id, 7.0)
	assert_true(combat.update_monster_position(MONSTER, Vector2(40, 100)))
	var saved_rng := rng.snapshot_state()
	var expected_state := [combat.snapshot_state(), loot.snapshot_state(), world_objects.snapshot_state()]
	var directory := "user://core02-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var service := SaveService.new(directory)
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = sector.entity_position(PLAYER)
	var dto := service.create_snapshot(sector, PLAYER, motor, rng, SaveSnapshot.LOCAL, "", loot.snapshot_state(), {
		"combat": combat.snapshot_state(),
		"world": world_objects.snapshot_state(),
	})
	assert_eq(service.save(dto)["status"], SaveService.OK_STATUS)
	var loaded := service.load()
	assert_eq(loaded["status"], SaveService.OK_STATUS)
	var disk: Dictionary = loaded["snapshot"]
	var expected_reward := loot.grant_from_table(PLAYER, "event.core02_after_save", LOOT_TABLE as LootTable)
	assert_true(expected_reward["accepted"])
	_setup(false)
	assert_true(rng.restore_state(saved_rng))
	assert_true(loot.restore_state(SaveSnapshot.loot_state(disk)))
	var authoritative := SaveSnapshot.authoritative_state(disk)
	assert_true(world_objects.restore_state(authoritative["world"]))
	assert_true(combat.restore_state(authoritative["combat"]))
	assert_eq([combat.snapshot_state(), loot.snapshot_state(), world_objects.snapshot_state()], expected_state)
	assert_true(world_objects.has_object(chest_id))
	assert_false(world_objects.has_object(glitter_id))
	assert_true(world_objects.is_claimed(glitter_id))
	assert_eq(combat.hull(MONSTER), 23.0)
	assert_eq(combat.hull(wreck_id), 7.0)
	assert_eq(sector.entity_position(MONSTER), Vector2(40, 100))
	var before_duplicate_rng := rng.snapshot_state()
	assert_true(world_objects.spawn(WorldObjectAuthority.GLITTER, GLITTER_ANCHOR, 0).is_empty())
	assert_eq(rng.snapshot_state(), before_duplicate_rng)
	var actual_reward := loot.grant_from_table(PLAYER, "event.core02_after_save", LOOT_TABLE as LootTable)
	assert_true(actual_reward["accepted"])
	assert_eq(actual_reward["quantity"], expected_reward["quantity"])
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP]:
		var path := directory.path_join(name)
		if FileAccess.file_exists(path):
			assert_eq(DirAccess.remove_absolute(path), OK)
	assert_eq(DirAccess.remove_absolute(directory), OK)
	print("CORE02_WORLD_PERSISTENCE_OK")


func test_core02_detached_presentation_and_authority_gate() -> void:
	_setup()
	var snapshot := world_objects.presentation_snapshot()
	snapshot["objects"][0]["archetype"] = "forged"
	assert_ne(world_objects.presentation_snapshot()["objects"][0]["archetype"], "forged")
	var target := combat.target_snapshot(MONSTER)
	target["target_class"] = TargetingService.SHIP
	assert_eq(combat.target_class(MONSTER), TargetingService.MONSTER)
	world_objects.set_authority_enabled(false)
	var before := _state()
	assert_true(world_objects.spawn(WorldObjectAuthority.CHEST, CHEST_ANCHOR, 1).is_empty())
	assert_eq(_state(), before)
