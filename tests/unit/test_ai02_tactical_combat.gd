extends GutTest

const A := "entity.ai02_actor"
const B := "entity.ai02_target"
const F := "entity.ai02_friendly"
const RAIDER := preload("res://src/data/ai/roles/raider.tres")
const TRADER := preload("res://src/data/ai/roles/trader.tres")
const ESCORT := preload("res://src/data/ai/roles/escort.tres")
const TUNING := preload("res://src/data/ai/vs02_sc03_tuning.tres")
const LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")
const LOOT_ITEM := preload("res://src/data/items/vs03_salvage_scrap.tres")


func test_ai02_tactical_context_is_detached_primitive_safe_and_bounded() -> void:
	var sector := _sector()
	assert_true(sector.register_entity(A, Vector2(-300, 100)))
	assert_true(sector.register_entity(B, Vector2(-100, 100)))
	var rng := SeedStreams.new(7102)
	var combat := CombatAuthority.new(sector, rng, 60)
	assert_true(combat.register(A, "faction.ai02_a", 200.0, _weapon()))
	assert_true(combat.register(B, "faction.ai02_b", 220.0, _weapon(), 5.0, 0.1))
	assert_true(combat.configure_defense(B, 0.15, {CoreCombatRules.FIRE: -0.25}, 0.0, 6.0))
	var sense := SenseSnapshot.build(A, 10, sector.sector_id, sector.entity_position(A), 1.0, [_sense_candidate(B, sector.entity_position(B), 200.0)], 1)
	var memory := _memory(B, 650, 10, 200.0)
	var before_sequence := combat.sequence_id()
	var context := TacticalContext.capture(A, 10, sector, combat, 0.0, 0.0, NpcBrain.State.ALERT, NpcBrain.Intent.INVESTIGATE_THREAT, sense, memory, TUNING as NpcAiTuning, RAIDER as NpcRoleProfile, _previous(B))
	assert_false(context.is_empty())
	assert_true(DtoContract.is_primitive_safe(context))
	assert_lte((context["targets"] as Array).size(), (TUNING as NpcAiTuning).max_tactical_targets)
	assert_lte((context["escape_candidates"] as Array).size(), (TUNING as NpcAiTuning).max_escape_candidates)
	assert_eq(combat.sequence_id(), before_sequence)
	var target: Dictionary = context["targets"][0]
	target["hull"] = 0.0
	assert_gt(float(combat.target_snapshot(B)["hull"]), 0.0)
	print("AI02_TACTICAL_CONTEXT_OK")


func test_ai02_expected_dps_uses_core_rules_without_rng_or_transaction_mutation() -> void:
	var sector := _sector()
	assert_true(sector.register_entity(A, Vector2(-300, 100)))
	assert_true(sector.register_entity(B, Vector2(-100, 100)))
	var rng := SeedStreams.new(7103)
	var combat := CombatAuthority.new(sector, rng, 60)
	assert_true(combat.register(A, "faction.ai02_a", 200.0, _weapon()))
	assert_true(combat.register(B, "faction.ai02_b", 200.0, null, 8.0, 0.2))
	assert_true(combat.configure_defense(B, 0.25, {CoreCombatRules.FIRE: -0.2}, 0.0, 5.0))
	var before_rng := rng.snapshot_state()
	var before_sequence := combat.sequence_id()
	var weapon := _weapon_dictionary()
	var ammo := {"ammo_id": "ammo.test.fire", "element_id": CoreCombatRules.FIRE, "base_damage": 30.0}
	var target := {"dodge": 0.2, "crit_prevention": 0.25, "resistances": {CoreCombatRules.FIRE: -0.2}, "defense": 8.0, "hull": 200.0, "max_hull": 200.0}
	var first := TacticalDecision.expected_damage_and_dps(weapon, ammo, target)
	var second := TacticalDecision.expected_damage_and_dps(weapon, ammo, target)
	assert_eq(first, second)
	assert_gt(float(first["expected_hit"]), 0.0)
	assert_gt(float(first["expected_dps"]), 0.0)
	assert_eq(rng.snapshot_state(), before_rng)
	assert_eq(combat.sequence_id(), before_sequence)
	print("AI02_EXPECTED_DPS_OK")


func test_ai02_scenario_matrix_too_far_bad_broadside_ready_and_blocked() -> void:
	var far := TacticalDecision.evaluate(_manual_context(Vector2(0, 310), 0.0, true, true, 1.0, 1, 1), 1)
	assert_eq(far["maneuver_id"], TacticalDecision.CLOSE_RANGE)
	assert_false(far["fire_allowed"])
	var bow := TacticalDecision.evaluate(_manual_context(Vector2(200, 0), 0.0, true, true, 1.0, 1, 1), 2)
	assert_eq(bow["maneuver_id"], TacticalDecision.ALIGN_BROADSIDE)
	assert_false(bow["fire_allowed"])
	var ready := TacticalDecision.evaluate(_manual_context(Vector2(0, 200), 0.0, true, true, 1.0, 1, 1), 3)
	assert_eq(ready["tactical_intent"], TacticalDecision.FIRE)
	assert_true(ready["fire_allowed"])
	var blocked := TacticalDecision.evaluate(_manual_context(Vector2(0, 200), 0.0, false, true, 1.0, 1, 1), 4)
	assert_false(blocked["fire_allowed"])
	assert_ne(blocked["tactical_intent"], TacticalDecision.FIRE)


func test_ai02_range_band_hysteresis_and_port_starboard_are_deterministic() -> void:
	var far_context := _manual_context(Vector2(0, 250), 0.0, true, true, 1.0, 1, 1)
	far_context["previous"]["range_band"] = TacticalDecision.BAND_FAR
	var held_far := TacticalDecision.evaluate(far_context, 10)
	assert_eq(held_far["range_band"], TacticalDecision.BAND_FAR)
	var settle_context := _manual_context(Vector2(0, 230), 0.0, true, true, 1.0, 1, 1)
	settle_context["previous"]["range_band"] = TacticalDecision.BAND_FAR
	assert_eq(TacticalDecision.evaluate(settle_context, 11)["range_band"], TacticalDecision.BAND_HOLD)
	var close_context := _manual_context(Vector2(0, 170), 0.0, true, true, 1.0, 1, 1)
	close_context["previous"]["range_band"] = TacticalDecision.BAND_CLOSE
	assert_eq(TacticalDecision.evaluate(close_context, 12)["range_band"], TacticalDecision.BAND_CLOSE)
	var starboard := TacticalDecision.evaluate(_manual_context(Vector2(0, 200), 0.0, true, true, 1.0, 1, 1), 13)
	var port := TacticalDecision.evaluate(_manual_context(Vector2(0, -200), 0.0, true, true, 1.0, 1, 1), 14)
	assert_eq(int(starboard["factors"]["current_side"]), ShipMotor.SIDE_STARBOARD)
	assert_eq(int(port["factors"]["current_side"]), ShipMotor.SIDE_PORT)
	var bow := TacticalDecision.evaluate(_manual_context(Vector2(200, 0), 0.0, true, true, 1.0, 1, 1), 15)
	assert_eq(bow["desired_side"], ShipMotor.SIDE_PORT)
	var mounted := _manual_context(Vector2(0, 200), 0.0, true, true, 1.0, 1, 1)
	mounted["actor"]["weapon"]["mounted_side"] = ShipMotor.SIDE_PORT
	var constrained := TacticalDecision.evaluate(mounted, 16)
	assert_eq(constrained["desired_side"], ShipMotor.SIDE_PORT)
	assert_false(bool(constrained["factors"]["broadside_valid"]))
	print("AI02_RANGE_BROADSIDE_OK")


func test_ai02_ammo_economy_scarcity_weakness_resistance_zero_stock_and_tie_break() -> void:
	var scarce := _manual_context(Vector2(0, 200), 0.0, true, true, 1.0, 1, 1)
	scarce["role"] = (TRADER as NpcRoleProfile).data_snapshot()
	scarce["tuning"]["ammo_scarcity_penalty"] = 1.2
	_set_ammo(scarce, [
		_ammo("ammo.common", CoreCombatRules.NEUTRAL, 20.0, 40),
		_ammo("ammo.expensive", CoreCombatRules.FIRE, 40.0, 1),
		_ammo("ammo.alternate", CoreCombatRules.NEUTRAL, 18.0, 30),
	])
	assert_eq(TacticalDecision.evaluate(scarce, 20)["selected_ammo_id"], "ammo.common")
	var weakness := scarce.duplicate(true)
	weakness["role"] = (RAIDER as NpcRoleProfile).data_snapshot()
	weakness["targets"][0]["resistances"] = {CoreCombatRules.FIRE: -0.5}
	weakness["targets"][0]["threat_ratio"] = 1.0
	weakness["targets"][0]["hull_ratio"] = 0.9
	weakness["actor"]["ammo_candidates"][1]["stock"] = 20
	weakness["tuning"]["ammo_scarcity_penalty"] = 0.55
	assert_eq(TacticalDecision.evaluate(weakness, 21)["selected_ammo_id"], "ammo.expensive")
	var resistant := weakness.duplicate(true)
	resistant["targets"][0]["resistances"] = {CoreCombatRules.FIRE: 0.8}
	assert_ne(TacticalDecision.evaluate(resistant, 22)["selected_ammo_id"], "ammo.expensive")
	var zero := weakness.duplicate(true)
	zero["actor"]["ammo_candidates"][1]["stock"] = 0
	zero["actor"]["ammo_candidates"][1]["available"] = false
	assert_ne(TacticalDecision.evaluate(zero, 23)["selected_ammo_id"], "ammo.expensive")
	var tied := scarce.duplicate(true)
	_set_ammo(tied, [_ammo("ammo.zeta", CoreCombatRules.NEUTRAL, 20.0, 40), _ammo("ammo.alpha", CoreCombatRules.NEUTRAL, 20.0, 40)])
	assert_eq(TacticalDecision.evaluate(tied, 24)["selected_ammo_id"], "ammo.alpha")
	print("AI02_AMMO_ECONOMY_OK")


func test_ai02_retreat_prefers_safer_escape_and_repair_waits_for_disengage() -> void:
	var retreat := _manual_context(Vector2(0, 200), 0.0, true, true, 0.2, 4, 0)
	retreat["targets"][0]["threat_ratio"] = 1.0
	retreat["escape_candidates"] = [
		{"escape_id": "safe.short_hazard", "x": -100.0, "y": 0.0, "geometric_distance": 100.0, "weighted_path_cost": 800.0, "hazard_cost": 700.0, "enemy_clearance": 80.0, "safe_zone": false},
		{"escape_id": "safe.long_safe", "x": -300.0, "y": 0.0, "geometric_distance": 300.0, "weighted_path_cost": 300.0, "hazard_cost": 0.0, "enemy_clearance": 500.0, "safe_zone": true},
	]
	var retreat_decision := TacticalDecision.evaluate(retreat, 30)
	assert_eq(retreat_decision["tactical_intent"], TacticalDecision.RETREAT)
	assert_eq(retreat_decision["factors"]["escape_id"], "safe.long_safe")
	var repair := _manual_context(Vector2(0, 200), 0.0, true, true, 0.4, 0, 0)
	repair["targets"] = []
	repair["actor"]["repair_available"] = true
	repair["actor"]["repair_ready"] = true
	repair["actor"]["safe_zone"] = true
	var repair_decision := TacticalDecision.evaluate(repair, 31)
	assert_eq(repair_decision["tactical_intent"], TacticalDecision.REPAIR)
	var pressure := repair.duplicate(true)
	pressure["nearby_hostile_count"] = 3
	assert_ne(TacticalDecision.evaluate(pressure, 32)["tactical_intent"], TacticalDecision.REPAIR)
	print("AI02_RETREAT_REPAIR_OK")


func test_ai02_line_of_fire_friendly_blocker_prevents_fire_without_mutation() -> void:
	var sector := SectorRuntime.new()
	sector.bounds = Rect2(-640, -360, 1280, 720)
	sector.sector_id = FoundationSector.ID
	assert_true(sector.register_entity(A, Vector2.ZERO))
	assert_true(sector.register_entity(B, Vector2(0, 200)))
	assert_true(sector.register_entity(F, Vector2(0, 100)))
	var rng := SeedStreams.new(7104)
	var combat := CombatAuthority.new(sector, rng, 60)
	var weapon := _weapon()
	assert_true(combat.register(A, "faction.ai02_a", 200.0, weapon))
	assert_true(combat.register(B, "faction.ai02_b", 200.0))
	assert_true(combat.register(F, "faction.ai02_a", 200.0))
	assert_true(combat.select(A, B))
	var before_rng := rng.snapshot_state()
	var before_combat := combat.snapshot_state()
	var snap := combat.tactical_snapshot(A, [B], 0.0, 300.0, 1, 8, 8)
	assert_false(bool(snap["targets"][0]["line_of_fire_clear"]))
	assert_eq(snap["targets"][0]["friendly_blocker_id"], F)
	var context := _context_from_snapshot(snap)
	var decision := TacticalDecision.evaluate(context, 40)
	assert_false(decision["fire_allowed"])
	assert_ne(decision["tactical_intent"], TacticalDecision.FIRE)
	assert_eq(rng.snapshot_state(), before_rng)
	assert_eq(combat.snapshot_state(), before_combat)
	print("AI02_LINE_OF_FIRE_OK")


func test_ai02_boarding_utility_rejects_bad_advantage_and_authority_executes_good_board() -> void:
	var bad := _manual_context(Vector2(0, 100), 0.0, true, true, 1.0, 1, 1)
	bad["actor"]["boarding_power"] = 4.0
	bad["targets"][0]["boarding_protection"] = 5.0
	bad["targets"][0]["hull_ratio"] = 0.3
	bad["targets"][0]["hull"] = 60.0
	bad["rules"] = {"board_range": CombatAuthority.BOARD_RANGE, "board_threshold": CombatAuthority.BOARD_THRESHOLD, "board_cooldown": CombatAuthority.BOARD_COOLDOWN}
	assert_ne(TacticalDecision.evaluate(bad, 50)["tactical_intent"], TacticalDecision.BOARD)
	var good := bad.duplicate(true)
	good["role"] = (RAIDER as NpcRoleProfile).data_snapshot()
	good["actor"]["boarding_power"] = 12.0
	assert_eq(TacticalDecision.evaluate(good, 51)["tactical_intent"], TacticalDecision.BOARD)

	var sector := SectorRuntime.new()
	sector.bounds = Rect2(-640, -360, 1280, 720)
	sector.sector_id = FoundationSector.ID
	assert_true(sector.register_entity(A, Vector2.ZERO))
	assert_true(sector.register_entity(B, Vector2(0, 100)))
	var rng := SeedStreams.new(7105)
	var loot := LootAuthority.new(sector, rng, LOOT_TABLE as LootTable, LOOT_ITEM as ItemDefinition)
	assert_true(loot.bind_inventory_owner(A, {CoreCombatRules.STOWED: 4}))
	loot.initialize_missing_stock({CoreCombatRules.STOWED: 4})
	var combat := CombatAuthority.new(sector, rng, 60)
	assert_true(combat.register(A, "faction.ai02_a", 200.0))
	assert_true(combat.register(B, "faction.ai02_b", 200.0))
	assert_true(combat.attach_inventory(loot))
	assert_true(combat.configure_defense(A, 0.0, {}, 12.0, 0.0))
	assert_true(combat.configure_defense(B, 0.0, {}, 0.0, 5.0))
	var state := combat.snapshot_state()
	for entry: Dictionary in state["combatants"]:
		if entry["entity_id"] == B:
			entry["hull"] = 60.0
	assert_true(combat.restore_state(state))
	var boarded := combat.transact(A, CombatAuthority.intent(CombatAuthority.BOARD, B))
	assert_true(boarded["accepted"])
	assert_true(boarded["success"])
	print("AI02_BOARDING_OK")


func test_ai02_support_is_semantic_cooldown_without_reinforcement_side_effect() -> void:
	var context := _manual_context(Vector2(0, 200), 0.0, false, true, 0.7, 4, 0)
	context["role"] = (ESCORT as NpcRoleProfile).data_snapshot()
	context["escape_candidates"] = []
	var decision := TacticalDecision.evaluate(context, 60)
	assert_eq(decision["tactical_intent"], TacticalDecision.SUPPORT)
	assert_true(decision["support_requested"])
	var persisted := TacticalDecision.persistent_state(decision, context["previous"], int(context["tuning"]["support_cooldown_ticks"]))
	assert_gt(int(persisted["next_support_tick"]), int(context["simulation_tick"]))
	var cooldown_context := context.duplicate(true)
	cooldown_context["previous"] = persisted
	cooldown_context["simulation_tick"] = int(context["simulation_tick"]) + 10
	var cooled := TacticalDecision.evaluate(cooldown_context, 61)
	assert_ne(cooled["tactical_intent"], TacticalDecision.SUPPORT)
	assert_true(TacticalDecision.valid_persistent_state(persisted))
	print("AI02_SUPPORT_INTENT_OK")


func test_ai02_npcbrain_persists_tactical_hold_side_support_and_resumes() -> void:
	var first := _brain_fixture("persist_a")
	var brain: NpcBrain = first["brain"]
	assert_true(brain.decision_tick(10))
	var saved := brain.persistence_state()
	assert_true(saved.has("tactical_state"))
	assert_true(TacticalDecision.valid_persistent_state(saved["tactical_state"]))
	assert_true(DtoContract.is_primitive_safe(saved))
	var second := _brain_fixture("persist_b")
	var restored: NpcBrain = second["brain"]
	assert_true(restored.restore_state(saved))
	assert_eq(restored.persistence_state()["tactical_state"], saved["tactical_state"])
	assert_true(restored.decision_tick(20))
	assert_gt(restored.telemetry()["tactical_evaluation_count"], 0)
	print("AI02_PERSISTENCE_OK")


func test_ai02_scheduler_budget_20_npc_bounded_no_starvation_or_double_bt_tick() -> void:
	var sector := _sector()
	var target := "entity.ai02_sched_target"
	assert_true(sector.register_entity(target, Vector2(-260, 0)))
	var rng := SeedStreams.new(7106)
	var combat := CombatAuthority.new(sector, rng, 60)
	assert_true(combat.register(target, "faction.ai02_enemy", 100000000.0))
	var scheduler := AiDecisionScheduler.new(2)
	var brains: Array[NpcBrain] = []
	var motors: Array[ShipMotor] = []
	var weapon := _weapon()
	weapon.base_damage = 1.0
	weapon.accuracy = 0.0
	var tuning := (TUNING as NpcAiTuning).duplicate(true) as NpcAiTuning
	tuning.bt_timeout_ticks = 10000
	for i in 20:
		var id := "entity.ai02_sched_%02d" % i
		var position := Vector2(-470 + float(i % 5) * 28.0, -140 + float(i / 5) * 28.0)
		assert_true(sector.register_entity(id, position))
		assert_true(combat.register(id, "faction.ai02_allies", 100.0, weapon))
		var motor := ShipMotor.new()
		add_child_autofree(motor)
		motor.set_physics_process(false)
		motor.global_position = position
		var brain := NpcBrain.create(id, sector, combat, motor, tuning, true, RAIDER as NpcRoleProfile)
		assert_not_null(brain)
		assert_true(scheduler.register_brain(brain, 10, i % 10))
		brains.append(brain)
		motors.append(motor)
	for _tick in 240:
		scheduler.advance_physics_tick()
	var total_tactical := 0
	var max_targets := 0
	var max_ammo := 0
	var max_escape := 0
	var max_line := 0
	var fire_transactions := 0
	var boarding_attempts := 0
	var support_intents := 0
	var bt_failures := 0
	var bt_timeouts := 0
	for brain in brains:
		assert_gt(brain.decision_count, 0)
		var telemetry := brain.telemetry()
		total_tactical += int(telemetry["tactical_evaluation_count"])
		max_targets = maxi(max_targets, int(telemetry["max_tactical_targets_evaluated"]))
		max_ammo = maxi(max_ammo, int(telemetry["max_tactical_ammo_evaluated"]))
		max_escape = maxi(max_escape, int(telemetry["max_tactical_escape_evaluated"]))
		max_line = maxi(max_line, int(telemetry["max_tactical_line_of_fire_inspected"]))
		fire_transactions += int(telemetry["tactical_fire_transactions"])
		boarding_attempts += int(telemetry["tactical_boarding_attempts"])
		support_intents += int(telemetry["tactical_support_intents"])
		bt_failures += int(telemetry["bt_failure_count"])
		bt_timeouts += int(telemetry["bt_timeout_count"])
	assert_eq(scheduler.decision_count, 480)
	assert_lte(scheduler.max_decisions_observed, 2)
	assert_gt(total_tactical, 0)
	assert_lte(max_targets, tuning.max_tactical_targets)
	assert_lte(max_ammo, tuning.max_ammo_candidates)
	assert_lte(max_escape, tuning.max_escape_candidates)
	assert_lte(max_line, tuning.max_line_of_fire_inspected)
	assert_eq(bt_timeouts, 0)
	print("AI02_SCHEDULER_BUDGET_OK npc_count=20 total_decisions=%d max_decisions_per_tick=%d total_tactical_evaluations=%d max_target_candidates=%d max_ammo_candidates=%d max_escape_candidates=%d max_line_of_fire_inspected=%d fire_transactions=%d boarding_attempts=%d support_intents=%d bt_failures=%d bt_timeouts=%d" % [
		scheduler.decision_count, scheduler.max_decisions_observed, total_tactical, max_targets, max_ammo, max_escape, max_line, fire_transactions, boarding_attempts, support_intents, bt_failures, bt_timeouts,
	])


func _sector() -> SectorRuntime:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	return SectorRuntime.build(definition)


func _weapon() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.ai02_test"
	weapon.base_damage = 20.0
	weapon.min_range_meters = 50.0
	weapon.range_meters = 300.0
	weapon.reload_seconds = 2.0
	weapon.accuracy = 0.8
	weapon.crit_chance = 0.2
	weapon.crit_multiplier = 2.0
	weapon.broadside_half_arc_degrees = 35.0
	weapon.defense_penetration = 2.0
	return weapon


func _weapon_dictionary() -> Dictionary:
	return {
		"weapon_id": "weapon.ai02_test",
		"min_range": 50.0,
		"max_range": 300.0,
		"reload_seconds": 2.0,
		"accuracy": 0.8,
		"crit_chance": 0.2,
		"crit_multiplier": 2.0,
		"broadside_half_arc_degrees": 35.0,
		"defense_penetration": 2.0,
		"mounted_side": 0,
		"last_side": 0,
		"normal_damage": 20.0,
	}


func _sense_candidate(id: String, position: Vector2, distance: float) -> Dictionary:
	return {
		"stable_id": id,
		"faction_id": "faction.ai02_enemy",
		"relation": SenseSnapshot.RELATION_HOSTILE,
		"target_class": TargetingService.SHIP,
		"position": {"x": position.x, "y": position.y},
		"distance": distance,
		"alive": true,
		"selectable": true,
		"visible": true,
		"threat_facts": {"hostile": true},
	}


func _memory(id: String, threat: int, tick: int, distance: float) -> Dictionary:
	return {
		"version": 1,
		"max_entries": 8,
		"expiry_ticks": 300,
		"entries": [{
			"stable_id": id,
			"threat": threat,
			"last_seen_tick": tick,
			"last_threat_tick": tick,
			"last_decay_tick": tick,
			"x": 0.0,
			"y": distance,
			"distance": distance,
		}],
		"selected_target_id": id,
		"recent_intent_id": NpcBrain.Intent.INVESTIGATE_THREAT,
		"recent_decision_tick": tick,
		"hysteresis": {"intent_id": NpcBrain.Intent.INVESTIGATE_THREAT, "target_id": id, "score": 1.0, "hold_until_tick": tick},
	}


func _previous(target_id: String = B) -> Dictionary:
	return {"range_band": "", "desired_side": 0, "next_support_tick": 0, "last_intent": TacticalDecision.NONE, "last_target_id": target_id}


func _manual_context(target_position: Vector2, heading: float, line_clear: bool, reload_ready: bool, hull_ratio: float, hostiles: int, allies: int) -> Dictionary:
	var actor := {
		"entity_id": A,
		"sector_id": FoundationSector.ID,
		"faction_id": "faction.ai02_a",
		"x": 0.0,
		"y": 0.0,
		"heading": heading,
		"movement_speed": 0.0,
		"hull": 200.0 * hull_ratio,
		"max_hull": 200.0,
		"hull_ratio": hull_ratio,
		"current_state": NpcBrain.State.ALERT,
		"high_level_intent": NpcBrain.Intent.INVESTIGATE_THREAT,
		"locked_target_id": B,
		"selected_ammo_id": "",
		"requires_ammo": false,
		"available_ammo_count": 0,
		"ammo_candidates": [],
		"weapon": _weapon_dictionary(),
		"reload_ready": reload_ready,
		"boarding_power": 0.0,
		"boarding_ready": true,
		"repair_available": true,
		"repair_ready": true,
		"safe_zone": false,
	}
	var target := {
		"entity_id": B,
		"target_class": TargetingService.SHIP,
		"faction_id": "faction.ai02_b",
		"hostile": true,
		"x": target_position.x,
		"y": target_position.y,
		"distance": target_position.length(),
		"relative_bearing": ShipMotor.signed_angular_difference(heading, target_position.angle()),
		"hull": 200.0,
		"max_hull": 200.0,
		"hull_ratio": 1.0,
		"defense": 0.0,
		"dodge": 0.0,
		"crit_prevention": 0.0,
		"resistances": {},
		"boarding_protection": 0.0,
		"alive": true,
		"selectable": true,
		"safe_zone": false,
		"line_of_fire_clear": line_clear,
		"friendly_blocker_id": "" if line_clear else F,
		"line_of_fire_inspected": 1,
		"threat": 500,
		"threat_ratio": 0.5,
	}
	return {
		"version": 1,
		"simulation_tick": 100,
		"sector_id": FoundationSector.ID,
		"actor": actor,
		"targets": [target],
		"nearby_hostile_count": hostiles,
		"nearby_ally_count": allies,
		"escape_candidates": [{"escape_id": "safe.ai02", "x": -300.0, "y": 0.0, "geometric_distance": 300.0, "weighted_path_cost": 300.0, "hazard_cost": 0.0, "enemy_clearance": 400.0, "safe_zone": true}],
		"rules": {"board_range": 120.0, "board_threshold": 0.45, "board_cooldown": 240},
		"role": (RAIDER as NpcRoleProfile).data_snapshot(),
		"previous": _previous(B),
		"limits": {"max_tactical_targets": 4, "max_ammo_candidates": 8, "max_escape_candidates": 4, "max_line_of_fire_inspected": 24},
		"tuning": {
			"preferred_min_ratio": 0.45,
			"preferred_max_ratio": 0.82,
			"range_hysteresis_ratio": 0.06,
			"ammo_reserve_stock": 5,
			"ammo_scarcity_penalty": 0.55,
			"ammo_switch_penalty": 0.15,
			"retreat_score_threshold": 0.58,
			"repair_score_threshold": 0.55,
			"boarding_score_threshold": 0.70,
			"support_score_threshold": 0.62,
			"support_cooldown_ticks": 300,
			"tactical_steering_distance": 96.0,
			"arrival_radius": 24.0,
			"max_threat": 1000,
		},
	}


func _ammo(id: String, element: String, base_damage: float, stock: int) -> Dictionary:
	return {"ammo_id": id, "item_id": "item.%s" % id.trim_prefix("ammo."), "element_id": element, "status_id": "", "base_damage": base_damage, "stock": stock, "available": stock > 0}


func _set_ammo(context: Dictionary, candidates: Array) -> void:
	context["actor"]["requires_ammo"] = true
	context["actor"]["ammo_candidates"] = candidates
	context["actor"]["available_ammo_count"] = candidates.filter(func(entry: Dictionary) -> bool: return bool(entry["available"])).size()
	context["actor"]["selected_ammo_id"] = "ammo.common" if candidates.any(func(entry: Dictionary) -> bool: return entry["ammo_id"] == "ammo.common") else ""


func _context_from_snapshot(snapshot: Dictionary) -> Dictionary:
	var context := _manual_context(Vector2(0, 200), 0.0, true, true, 1.0, int(snapshot["nearby_hostile_count"]), int(snapshot["nearby_ally_count"]))
	context["actor"] = snapshot["actor"].duplicate(true)
	context["actor"]["heading"] = 0.0
	context["actor"]["movement_speed"] = 0.0
	context["actor"]["current_state"] = NpcBrain.State.ALERT
	context["actor"]["high_level_intent"] = NpcBrain.Intent.INVESTIGATE_THREAT
	context["targets"] = snapshot["targets"].duplicate(true)
	for target: Dictionary in context["targets"]:
		target["threat"] = 500
		target["threat_ratio"] = 0.5
	context["rules"] = snapshot["rules"].duplicate(true)
	return context


func _brain_fixture(label: String) -> Dictionary:
	var sector := _sector()
	var actor_id := A
	var target_id := B
	var actor_position := Vector2(-360, 100)
	var target_position := Vector2(-160, 100)
	assert_true(sector.register_entity(actor_id, actor_position))
	assert_true(sector.register_entity(target_id, target_position))
	var rng := SeedStreams.new(8000 + label.length())
	var combat := CombatAuthority.new(sector, rng, 60)
	assert_true(combat.register(actor_id, "faction.ai02_actor", 200.0, _weapon()))
	assert_true(combat.register(target_id, "faction.ai02_enemy", 1000000.0))
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = actor_position
	var tuning := (TUNING as NpcAiTuning).duplicate(true) as NpcAiTuning
	tuning.bt_timeout_ticks = 10000
	var brain := NpcBrain.create(actor_id, sector, combat, motor, tuning, true, RAIDER as NpcRoleProfile)
	assert_not_null(brain)
	return {"sector": sector, "combat": combat, "motor": motor, "brain": brain, "rng": rng}
