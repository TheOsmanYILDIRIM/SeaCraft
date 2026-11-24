extends GutTest

const A := "entity.attacker"
const B := "entity.target"

var sector: SectorRuntime
var rng: SeedStreams
var c: CombatAuthority


func _weapon() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.test"
	weapon.base_damage = 20.0
	weapon.min_range_meters = 10.0
	weapon.range_meters = 200.0
	weapon.crit_multiplier = 2.0
	return weapon


func _fixture(weapon: WeaponDefinition, target_hull: float = 50.0, defense: float = 0.0, dodge: float = 0.0, mods: Dictionary = {}) -> CombatAuthority:
	sector = SectorRuntime.new()
	sector.bounds = Rect2(-640, -360, 1280, 720)
	assert_true(sector.register_entity(A, Vector2.ZERO))
	assert_true(sector.register_entity(B, Vector2(0, 100)))
	rng = SeedStreams.new(17)
	var authority := CombatAuthority.new(sector, rng)
	assert_true(authority.register(A, "faction.a", 100.0, weapon, 0.0, 0.0, true, mods))
	assert_true(authority.register(B, "faction.b", target_hull, null, defense, dodge))
	assert_true(authority.select(A, B))
	return authority


func _fire(authority: CombatAuthority) -> Dictionary:
	return authority.fire(A, 0, CombatAuthority.fire_intent(B))


func _add_target(authority: CombatAuthority, id: String, position: Vector2, faction: String = "faction.b") -> bool:
	return sector.register_entity(id, position) and authority.register(id, faction, 50.0)


func test_valid_hostile_target() -> void:
	c = _fixture(_weapon())
	assert_eq(c.acquire(A, Vector2(0, 100), 24), B)
	assert_true(c.select(A, B))
	assert_eq(c.locked_target(A), B)


func test_dormant_registration_preserves_weapon_shape_for_state_restore() -> void:
	var home := SectorRuntime.new()
	home.sector_id = "sector.vs01_home"
	home.bounds = Rect2(-640, -360, 1280, 720)
	assert_true(home.register_entity(B, Vector2(0, 100)))
	var weapon := _weapon()
	var source := CombatAuthority.new(home, SeedStreams.new(91))
	assert_true(source.register(B, "faction.b", 50.0, weapon, 4.0, 0.05))
	var saved := source.snapshot_state()

	var away := SectorRuntime.new()
	away.sector_id = "sector.vs01_away"
	away.bounds = Rect2(-640, -360, 1280, 720)
	var restored := CombatAuthority.new(away, SeedStreams.new(91))
	assert_true(restored.register_dormant(B, "faction.b", 50.0, home.sector_id, Vector2(0, 100),
		TargetingService.SHIP, weapon, 4.0, 0.05))
	assert_true(restored.restore_state(saved))
	assert_eq(restored.snapshot_state(), saved)


func test_friendly_target() -> void:
	c = _fixture(_weapon())
	assert_true(_add_target(c, "entity.friend", Vector2(8, 100), "faction.a"))
	assert_false(c.select(A, "entity.friend"))
	assert_eq(c.acquire(A, Vector2(8, 100), 1), "")


func test_invalid_and_sunk_target() -> void:
	c = _fixture(_weapon(), 10.0)
	assert_false(c.select(A, "entity.absent"))
	assert_true(c.fire(A, 0, CombatAuthority.fire_intent(B))["sunk"])
	assert_false(c.select(A, B))
	assert_eq(c.acquire(A, Vector2(0, 100), 24), "")


func test_spatial_near_acquisition() -> void:
	c = _fixture(_weapon())
	assert_eq(c.acquire(A, Vector2(8, 100), 12), B)
	assert_eq(c.acquire(A, Vector2(18, 100), 12), "")


func test_stable_tie_break() -> void:
	c = _fixture(_weapon())
	assert_true(_add_target(c, "entity.aaa", Vector2(0, 100)))
	assert_eq(c.acquire(A, Vector2(0, 100), 12), "entity.aaa")


func test_maximum_range() -> void:
	c = _fixture(_weapon())
	assert_true(sector.move_entity(B, Vector2(0, 300)))
	assert_eq(_fire(c)["reason"], "out_of_range")


func test_minimum_range() -> void:
	c = _fixture(_weapon())
	assert_true(sector.move_entity(B, Vector2(0, 5)))
	assert_eq(_fire(c)["reason"], "out_of_range")


func test_wrong_arc() -> void:
	c = _fixture(_weapon())
	assert_true(sector.move_entity(B, Vector2(100, 0)))
	assert_eq(_fire(c)["reason"], "invalid_arc")


func test_port_broadside() -> void:
	c = _fixture(_weapon())
	assert_true(sector.move_entity(B, Vector2(0, -100)))
	assert_true(_fire(c)["accepted"])
	assert_eq(CombatAuthority.broadside(0, Vector2(0, -100), 25), ShipMotor.SIDE_PORT)


func test_starboard_broadside() -> void:
	c = _fixture(_weapon())
	var result := _fire(c)
	assert_true(result["accepted"])
	assert_eq(result["side"], ShipMotor.SIDE_STARBOARD)


func test_reload_before_ready() -> void:
	c = _fixture(_weapon())
	assert_true(_fire(c)["accepted"])
	for i in range(59):
		c.advance_tick()
	assert_eq(_fire(c)["reason"], "reloading")


func test_reload_at_ready_tick() -> void:
	c = _fixture(_weapon())
	assert_true(_fire(c)["accepted"])
	for i in range(60):
		c.advance_tick()
	var result := _fire(c)
	assert_true(result["accepted"])
	assert_eq(result["sequence_id"], 2)


func test_deterministic_rng_resume() -> void:
	c = _fixture(_weapon())
	var weapon := _weapon()
	weapon.accuracy = 0.7
	weapon.crit_chance = 0.4
	c = _fixture(weapon)
	var initial := rng.snapshot_state()
	var first := _fire(c)
	var expected := rng.snapshot_state()
	c = _fixture(weapon)
	assert_true(rng.restore_state(initial))
	assert_eq(_fire(c), first)
	assert_eq(rng.snapshot_state(), expected)


func test_miss_zero_damage() -> void:
	c = _fixture(_weapon())
	var weapon := _weapon()
	weapon.accuracy = 0.0
	c = _fixture(weapon)
	var result := _fire(c)
	assert_true(result["accepted"])
	assert_false(result["hit"])
	assert_eq(result["applied_hull_damage"], 0.0)
	assert_eq(c.hull(B), 50.0)


func test_normal_hit_damage() -> void:
	c = _fixture(_weapon())
	var result := _fire(c)
	assert_true(result["hit"])
	assert_false(result["crit"])
	assert_eq(result["raw_damage"], 20.0)
	assert_eq(c.hull(B), 30.0)


func test_critical_multiplier() -> void:
	c = _fixture(_weapon())
	var weapon := _weapon()
	weapon.crit_chance = 1.0
	c = _fixture(weapon)
	var result := _fire(c)
	assert_true(result["crit"])
	assert_eq(result["applied_hull_damage"], 40.0)


func test_defense_penetration() -> void:
	c = _fixture(_weapon())
	var weapon := _weapon()
	weapon.defense_penetration = 3.0
	c = _fixture(weapon, 50.0, 8.0)
	var result := _fire(c)
	assert_eq(result["prevented_damage"], 5.0)
	assert_eq(result["applied_hull_damage"], 15.0)


func test_defense_cannot_make_negative_damage() -> void:
	c = _fixture(_weapon())
	c = _fixture(_weapon(), 50.0, 100.0)
	var result := _fire(c)
	assert_eq(result["prevented_damage"], 20.0)
	assert_eq(result["applied_hull_damage"], 0.0)


func test_overkill_clamps_hull() -> void:
	c = _fixture(_weapon(), 10.0)
	var result := _fire(c)
	assert_eq(result["applied_hull_damage"], 10.0)
	assert_eq(c.hull(B), 0.0)
	assert_true(result["sunk"])


func test_sunk_signal_once() -> void:
	c = _fixture(_weapon(), 10.0)
	var events: Array = []
	c.ship_sunk.connect(func(id: String, seq: int) -> void: events.append([id, seq]))
	assert_true(_fire(c)["sunk"])
	assert_false(_fire(c)["sunk"])
	assert_eq(events, [[B, 1]])


func test_second_sunk_hit_rejected() -> void:
	c = _fixture(_weapon(), 10.0)
	assert_true(_fire(c)["accepted"])
	var initial := rng.snapshot_state()
	assert_eq(_fire(c)["reason"], "sunk_target")
	assert_eq(c.hull(B), 0.0)
	assert_eq(rng.snapshot_state(), initial)
	assert_eq(c.locked_target(A), "")


func test_friendly_fire_blocked() -> void:
	c = _fixture(_weapon())
	assert_true(_add_target(c, "entity.friend", Vector2(0, 100), "faction.a"))
	assert_eq(c.fire(A, 0, CombatAuthority.fire_intent("entity.friend"))["reason"], "friendly_target")


func test_malformed_intent_no_mutation() -> void:
	c = _fixture(_weapon())
	var before := rng.snapshot_state()
	assert_eq(c.fire(A, 0, {"type": CombatAuthority.FIRE, "target_id": Vector2.ZERO})["reason"], "malformed_command")
	assert_eq(c.fire(A, INF, CombatAuthority.fire_intent(B))["reason"], "malformed_command")
	assert_eq(c.hull(B), 50.0)
	assert_eq(c.locked_target(A), B)
	assert_eq(rng.snapshot_state(), before)
	assert_eq(_fire(c)["sequence_id"], 1)


func test_primitive_dto() -> void:
	c = _fixture(_weapon())
	assert_true(DtoContract.is_primitive_safe(_fire(c)))
	assert_true(DtoContract.is_primitive_safe(_fire(c)))
	assert_eq(_fire(c)["sequence_id"], 0)


func test_presentation_dto_detached() -> void:
	c = _fixture(_weapon())
	var snapshot := _fire(c)
	snapshot["remaining_hull"] = 0.0
	snapshot["sunk"] = true
	assert_eq(c.hull(B), 30.0)
	assert_eq(c.locked_target(A), B)


func test_no_transport_in_offline_authority() -> void:
	c = _fixture(_weapon())
	assert_eq(_fire(c)["reason"], "")
	assert_eq(c.fire("entity.absent", 0, CombatAuthority.fire_intent(B))["reason"], "invalid_attacker")


func test_bounded_spatial_visits() -> void:
	c = _fixture(_weapon())
	for i in range(300):
		assert_true(_add_target(c, "entity.remote_" + str(i), Vector2(500, 300)))
	assert_eq(c.acquire(A, Vector2(0, 100), 24), B)
	assert_true(c.acquisition_inspected() < 10)


func test_dodge_and_stream_isolation() -> void:
	c = _fixture(_weapon())
	c = _fixture(_weapon(), 50.0, 0.0, 1.0)
	var before: Dictionary = rng.snapshot_state()["streams"]
	assert_false(_fire(c)["hit"])
	var after: Dictionary = rng.snapshot_state()["streams"]
	assert_eq(before["world"], after["world"])
	assert_eq(before["loot"], after["loot"])
	assert_ne(before["encounter"], after["encounter"])


func test_invalid_profile_inputs() -> void:
	c = _fixture(_weapon())
	var invalid := _weapon()
	invalid.base_damage = NAN
	assert_false(c.register("entity.bad_damage", "faction.a", 10.0, invalid) if sector.register_entity("entity.bad_damage", Vector2.ZERO) else true)
	invalid.base_damage = 1.0
	invalid.range_meters = INF
	assert_false(c.register("entity.bad_damage", "faction.a", 10.0, invalid))
	assert_false(sector.register_entity("entity.bad_pos", Vector2(INF, 0)))
	assert_eq(c.acquire(A, Vector2(NAN, 0), 24), "")
	assert_eq(c.acquire(A, Vector2.ZERO, INF), "")
	assert_false(c.register("entity.bad_damage", "faction.a", 10.0, _weapon(), 0.0, 0.0, true, {"modifier.bad": {"operation": "flat", "value": INF}}))


func test_ordered_attack_modifiers() -> void:
	c = _fixture(_weapon())
	var mods := {"modifier.multiply": {"operation": "multiply", "value": 2.0}, "modifier.flat": {"operation": "flat", "value": 3.0}}
	c = _fixture(_weapon(), 100.0, 0.0, 0.0, mods)
	assert_eq(_fire(c)["raw_damage"], 46.0)


func test_invalid_lock_clears() -> void:
	c = _fixture(_weapon())
	assert_true(sector.remove_entity(B))
	assert_eq(c.locked_target(A), "")
	assert_eq(_fire(c)["reason"], "invalid_target")


func test_explicit_clear_and_unlocked_fire() -> void:
	c = _fixture(_weapon())
	c.clear_target(A)
	assert_eq(c.locked_target(A), "")
	assert_eq(_fire(c)["reason"], "target_not_locked")


func test_unselectable_ship() -> void:
	c = _fixture(_weapon())
	assert_true(sector.register_entity("entity.hidden", Vector2(12, 100)))
	assert_true(c.register("entity.hidden", "faction.b", 10.0, null, 0.0, 0.0, false))
	assert_eq(c.acquire(A, Vector2(12, 100), 4), "")
	assert_false(c.select(A, "entity.hidden"))


func test_shared_cooldown_across_sides() -> void:
	c = _fixture(_weapon())
	assert_true(_fire(c)["accepted"])
	assert_true(sector.move_entity(B, Vector2(0, -100)))
	assert_eq(_fire(c)["reason"], "reloading")
