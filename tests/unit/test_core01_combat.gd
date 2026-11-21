extends GutTest

const A := "entity.core_player"
const B := "entity.core_opponent"
const ROUND := "ammo.core_round"
const EMBER := "ammo.core_ember"
const ITEM := CoreCombatRules.STOWED
const ITEM_DEFINITION := preload("res://src/data/items/vs03_salvage_scrap.tres")
const LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")

var sector: SectorRuntime
var rng: SeedStreams
var loot: LootAuthority
var combat: CombatAuthority
var weapon: WeaponDefinition


func _setup(stock: int = 4, dodge: float = 0.0, accuracy: float = 1.0, enabled: bool = true) -> void:
	sector = SectorRuntime.new()
	sector.bounds = Rect2(-640, -360, 1280, 720)
	sector.sector_id = "sector.core"
	assert_true(sector.register_entity(A, Vector2.ZERO))
	assert_true(sector.register_entity(B, Vector2(0, 100)))
	rng = SeedStreams.new(71)
	loot = LootAuthority.new(sector, rng, LOOT_TABLE as LootTable, ITEM_DEFINITION as ItemDefinition)
	var supplies := {CoreCombatRules.ROUND: stock, CoreCombatRules.EMBER: stock, ITEM: stock}
	assert_true(loot.bind_inventory_owner(A, supplies))
	loot.initialize_missing_stock(supplies)
	weapon = WeaponDefinition.new()
	weapon.stable_id = "weapon.core_matrix"
	weapon.base_damage = 20.0
	weapon.accuracy = accuracy
	weapon.crit_chance = 1.0
	weapon.crit_multiplier = 2.0
	weapon.defense_penetration = 3.0
	weapon.range_meters = 300.0
	weapon.reload_seconds = 1.0
	combat = CombatAuthority.new(sector, rng, 1, enabled)
	assert_true(combat.register(A, "faction.core_player", 200.0, weapon, 0.0, 0.0, true, {
		"mod.multiply": {"operation": "multiply", "value": 2.0},
		"mod.flat": {"operation": "flat", "value": 4.0},
		"mod.relative": {"operation": "percent_add", "value": 0.25},
	}))
	assert_true(combat.register(B, "faction.core_enemy", 200.0, weapon, 8.0, dodge))
	assert_true(combat.attach_inventory(loot))
	assert_true(combat.register_ammo(CoreCombatRules.ammo(ROUND, CoreCombatRules.ROUND, CoreCombatRules.NEUTRAL, 1.0)))
	assert_true(combat.register_ammo(CoreCombatRules.ammo(EMBER, CoreCombatRules.EMBER, CoreCombatRules.FIRE, 1.5, "status.scorched")))
	assert_true(combat.mount_ammo(A, PackedStringArray([ROUND, EMBER])))
	assert_true(combat.configure_repair(A, 25.0, 180, ITEM))
	if enabled:
		assert_true(combat.select(A, B))


func _advance(count: int) -> void:
	for _i in count:
		combat.advance_tick()


func _fire() -> Dictionary:
	return combat.fire(A, 0.0, CombatAuthority.fire_intent(B))


func _intent(kind: String, id: String = "") -> Dictionary:
	return combat.transact(A, CombatAuthority.intent(kind, id))


func _state() -> Array:
	return [combat.snapshot_state(), rng.snapshot_state(), loot.snapshot_state()]


func _reject_without_change(result: Dictionary, reason: String, before: Array) -> void:
	assert_false(result["accepted"])
	assert_eq(result["reason"], reason)
	assert_eq(_state(), before)


func _actor(id: String) -> Dictionary:
	for entry: Dictionary in combat.snapshot_state()["combatants"]:
		if entry["entity_id"] == id:
			return entry
	return {}


func _hull(id: String, value: float) -> void:
	var snapshot := combat.snapshot_state()
	for entry: Dictionary in snapshot["combatants"]:
		if entry["entity_id"] == id:
			entry["hull"] = value
	assert_true(combat.restore_state(snapshot))


func test_core01_formula_matrix() -> void:
	# ammo, resistance, prevention, dodge, accuracy, hit, crit, raw, damage
	for row: Array in [
		[ROUND, -0.5, 1.0, 0.0, 1.0, true, false, 60.0, 55.0],
		[ROUND, 0.0, 0.0, 0.0, 1.0, true, true, 120.0, 115.0],
		[EMBER, -0.5, 1.0, 0.0, 1.0, true, false, 127.5, 122.5],
		[EMBER, 0.5, 1.0, 0.0, 1.0, true, false, 42.5, 37.5],
		[EMBER, 1.0, 0.0, 0.0, 1.0, true, true, 0.0, 0.0],
		[ROUND, 0.0, 0.0, 1.0, 4.0, false, false, 0.0, 0.0],
		[ROUND, 0.0, 1.0, 0.5, 2.0, true, false, 60.0, 55.0],
		[ROUND, 0.0, 0.0, 0.0, 0.0, false, false, 0.0, 0.0],
	]:
		_setup(4, row[3], row[4])
		assert_true(combat.configure_defense(B, row[2], {CoreCombatRules.FIRE: row[1]}, 0.0, 0.0))
		assert_true(_intent(CombatAuthority.AMMO_SELECT, row[0])["accepted"])
		var before_rng := rng.snapshot_state()
		var result := _fire()
		assert_true(result["accepted"], str(row))
		assert_eq([result["hit"], result["crit"], result["raw_damage"], result["applied_hull_damage"]], row.slice(5))
		assert_eq(loot.inventory_quantity(CoreCombatRules.ROUND if row[0] == ROUND else CoreCombatRules.EMBER), 3)
		var expect := SeedStreams.new(71)
		assert_true(expect.restore_state(before_rng))
		expect.next_float(SeedStreams.STREAM_ENCOUNTER)
		expect.next_float(SeedStreams.STREAM_ENCOUNTER)
		assert_eq(rng.snapshot_state(), expect.snapshot_state())
	print("CORE01_FORMULA_MATRIX_EXECUTED")


func test_core01_ammo_validation_and_atomic_rejections() -> void:
	_setup(0)
	var before := _state()
	_reject_without_change(_fire(), "insufficient_resource", before)
	_reject_without_change(_intent(CombatAuthority.AMMO_SELECT, EMBER), "insufficient_resource", before)
	_reject_without_change(_intent(CombatAuthority.AMMO_SELECT, "ammo.unknown"), "invalid_ammo", before)
	for row: Array in [["element.unknown", 1.0], [CoreCombatRules.FIRE, INF], [CoreCombatRules.FIRE, -1.0]]:
		assert_false(combat.register_ammo(CoreCombatRules.ammo("ammo.invalid", ITEM, row[0], row[1])))
	assert_false(combat.configure_defense(B, 0.0, {"element.unknown": 0.1}, 0.0, 0.0))
	assert_false(combat.configure_defense(B, 0.0, {CoreCombatRules.FIRE: NAN}, 0.0, 0.0))
	assert_false(combat.configure_defense(B, 1.01, {}, 0.0, 0.0))
	assert_eq(_state(), before)
	_setup(4, 0.0, 1.0, false)
	before = _state()
	_reject_without_change(_fire(), "authority_disabled", before)
	_reject_without_change(_intent(CombatAuthority.REPAIR), "authority_disabled", before)


func test_core01_repair_shared_stock_and_interruption() -> void:
	_setup(0)
	_hull(A, 180.0)
	var before := _state()
	_reject_without_change(_intent(CombatAuthority.REPAIR), "insufficient_resource", before)
	var drop := loot.on_ship_sunk("entity.reward_dummy", 1, Vector2.ZERO)
	assert_false(drop.is_empty())
	assert_true(loot.pickup(A, LootAuthority.pickup_intent(str(drop.get("drop_id", ""))))["accepted"])
	assert_true(combat.select(B, A))
	assert_true(combat.fire(B, 0.0, CombatAuthority.fire_intent(A))["accepted"])
	before = _state()
	_reject_without_change(_intent(CombatAuthority.REPAIR), "repair_interrupted", before)
	_advance(120)
	var quantity := loot.inventory_quantity(ITEM)
	var repaired_from := combat.hull(A)
	var repaired := _intent(CombatAuthority.REPAIR)
	assert_true(repaired["accepted"])
	assert_eq(combat.hull(A), repaired_from + 25.0)
	assert_eq(loot.inventory_quantity(ITEM), quantity - 1)
	before = _state()
	_reject_without_change(_intent(CombatAuthority.REPAIR), "cooldown", before)


func test_core01_boarding_and_action_atomicity() -> void:
	for power: float in [12.0, 2.0]:
		_setup()
		assert_true(combat.configure_defense(A, 0.0, {}, power, 0.0))
		assert_true(combat.configure_defense(B, 0.0, {}, 0.0, 5.0))
		var before := _state()
		_reject_without_change(_intent(CombatAuthority.BOARD, "entity.absent"), "invalid_target", before)
		_reject_without_change(_intent(CombatAuthority.BOARD, B), "hull_threshold", before)
		_hull(B, 80.0)
		assert_true(sector.move_entity(B, Vector2(0, 140)))
		before = _state()
		_reject_without_change(_intent(CombatAuthority.BOARD, B), "out_of_range", before)
		assert_true(sector.move_entity(B, Vector2(0, 100)))
		var boarded := _intent(CombatAuthority.BOARD, B)
		assert_true(boarded["accepted"])
		assert_eq(boarded["success"], power > 5.0)
		assert_eq(boarded["reward_id"], "reward.boarding_salvage" if power > 5.0 else "")
		assert_eq(loot.inventory_quantity(ITEM), 3)
		assert_eq(rng.snapshot_state(), before[1])
		before = _state()
		_reject_without_change(_intent(CombatAuthority.BOARD, B), "cooldown", before)
		_reject_without_change(_intent(CombatAuthority.ACTION, "action.unknown"), "invalid_action", before)
		var wrong_target := CombatAuthority.intent(CombatAuthority.ACTION, CoreCombatRules.ACTION)
		wrong_target["target_id"] = B
		_reject_without_change(combat.transact(A, wrong_target), "invalid_action_target", before)
		assert_true(_intent(CombatAuthority.ACTION, CoreCombatRules.ACTION)["accepted"])
		assert_eq(loot.inventory_quantity(ITEM), 2)
		before = _state()
		_reject_without_change(_intent(CombatAuthority.ACTION, CoreCombatRules.ACTION), "cooldown", before)
	_setup(0)
	_hull(B, 80.0)
	var empty := _state()
	_reject_without_change(_intent(CombatAuthority.BOARD, B), "insufficient_resource", empty)
	_reject_without_change(_intent(CombatAuthority.ACTION, CoreCombatRules.ACTION), "insufficient_resource", empty)
	print("CORE01_ATOMICITY_EXECUTED")


func test_core01_status_stacking_expiry_and_detached_snapshot() -> void:
	_setup(5)
	assert_true(combat.configure_defense(B, 1.0, {CoreCombatRules.FIRE: 0.9}, 0.0, 0.0))
	assert_true(_intent(CombatAuthority.AMMO_SELECT, EMBER)["accepted"])
	for index in 4:
		var shot := _fire()
		assert_true(shot["accepted"])
		assert_gt(shot["applied_hull_damage"], 0.0)
		var actor := _actor(B)
		var scorch: Dictionary = actor["core"]["statuses"]["status.scorched"]
		assert_eq(scorch["stacks"], mini(index + 1, 3))
		assert_eq(scorch["source"], A)
		assert_eq(scorch["expires"], 180 + index)
		scorch["stacks"] = 99
		shot["remaining_hull"] = 0.0
		assert_true(combat.is_alive(B))
		_advance(1)
	assert_eq(_actor(B)["core"]["statuses"]["status.scorched"]["stacks"], 3)
	assert_true(_intent(CombatAuthority.ACTION, CoreCombatRules.ACTION)["accepted"])
	_advance(120)
	assert_false(_actor(A)["core"]["statuses"].has("status.braced"))
	assert_true(_actor(B)["core"]["statuses"].has("status.scorched"))
	_advance(59)
	assert_false(_actor(B)["core"]["statuses"].has("status.scorched"))


func test_core01_checkpoint_continuation() -> void:
	_setup()
	assert_true(_intent(CombatAuthority.AMMO_SELECT, EMBER)["accepted"])
	assert_true(_intent(CombatAuthority.ACTION, CoreCombatRules.ACTION)["accepted"])
	assert_true(_fire()["accepted"])
	var saved := _state()
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	var directory := "user://core01-%s-%s" % [get_instance_id(), Time.get_ticks_usec()]
	assert_eq(DirAccess.make_dir_recursive_absolute(directory), OK)
	var service := SaveService.new(directory)
	var save_sector := SectorRuntime.new()
	save_sector.sector_id = FoundationSector.ID
	save_sector.bounds = sector.bounds
	assert_true(save_sector.register_entity(A, motor.global_position))
	var dto := service.create_snapshot(save_sector, A, motor, rng, SaveSnapshot.LOCAL, "", loot.snapshot_state(), {"combat": combat.snapshot_state()})
	assert_eq(service.save(dto)["status"], SaveService.OK_STATUS)
	var loaded := service.load()
	assert_eq(loaded["status"], SaveService.OK_STATUS)
	var disk: Dictionary = loaded.get("snapshot", {})
	assert_eq(DirAccess.remove_absolute(directory.path_join(SaveService.PRIMARY)), OK)
	assert_eq(DirAccess.remove_absolute(directory), OK)
	_advance(1)
	var expected := _fire()
	var end := _state()
	_setup()
	assert_true(combat.restore_state(SaveSnapshot.authoritative_state(disk).get("combat")))
	assert_true(rng.restore_state(saved[1]))
	assert_true(loot.restore_state(SaveSnapshot.loot_state(disk)))
	assert_eq(_state(), saved)
	_advance(1)
	assert_eq(_fire(), expected)
	assert_eq(_state(), end)
