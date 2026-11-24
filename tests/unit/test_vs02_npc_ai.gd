extends GutTest

const PLAYER := "entity.player"
const NPC := "entity.vs02_sc03"
const FRIEND := "entity.friend"
const PLAYER_POS := Vector2(-240, 0)
const NPC_POS := Vector2(-240, 100)

var sector: SectorRuntime
var combat: CombatAuthority
var motor: ShipMotor
var brain: NpcBrain
var scheduler: AiDecisionScheduler
var tuning: NpcAiTuning


func before_each() -> void:
	_make_fixture()


func _make_fixture(damage: float = 20.0, npc_hull: float = 100.0, authority_enabled: bool = true) -> void:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	sector = SectorRuntime.build(definition)
	assert_not_null(sector)
	assert_true(sector.register_entity(PLAYER, PLAYER_POS))
	assert_true(sector.register_entity(NPC, NPC_POS))
	motor = ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = NPC_POS
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.vs02_test"
	weapon.base_damage = damage
	weapon.min_range_meters = 0.0
	weapon.range_meters = 600.0
	weapon.reload_seconds = 0.01
	weapon.accuracy = 1.0
	weapon.crit_chance = 0.0
	combat = CombatAuthority.new(sector, SeedStreams.new(77), 60)
	assert_true(combat.register(PLAYER, "faction.player", 100.0, weapon))
	assert_true(combat.register(NPC, "faction.hostile", npc_hull))
	var supply := LootAuthority.new(sector, null, null, null)
	assert_true(supply.reserve_inventory_item(NPC, CoreCombatRules.NPC_REPAIR))
	supply.initialize_missing_stock({CoreCombatRules.NPC_REPAIR: 24})
	assert_true(combat.attach_inventory(supply))
	tuning = _test_tuning()
	brain = NpcBrain.create(NPC, sector, combat, motor, tuning, authority_enabled)
	assert_not_null(brain)
	scheduler = AiDecisionScheduler.new(4)
	assert_true(scheduler.register_brain(brain, tuning.decision_interval_ticks, 0))
	combat.hull_damaged.connect(_on_damage)
	combat.ship_sunk.connect(_on_sunk)


func _test_tuning() -> NpcAiTuning:
	var value := NpcAiTuning.new()
	value.decision_interval_ticks = 10
	value.perception_radius = 60.0
	value.max_threat = 1000
	value.threat_per_damage = 20.0
	value.threat_decay_interval_ticks = 30
	value.threat_decay_amount = 100
	value.retreat_enter_hull_ratio = 0.35
	value.retreat_exit_hull_ratio = 0.55
	value.retreat_threat_min = 120
	value.alert_threat_min = 1
	value.repair_entry_threat_max = 1000
	value.repair_interrupt_threat = 120
	value.repair_interval_ticks = 30
	value.repair_amount = 8.0
	value.resume_hull_ratio = 0.70
	value.resume_threat_max = 50
	value.safe_distance = 80.0
	value.arrival_radius = 18.0
	value.retreat_fallback_distance = 120.0
	value.patrol_waypoint_ids = PackedStringArray(["waypoint.a", "waypoint.b", "waypoint.c", "waypoint.d"])
	value.patrol_waypoints = PackedVector2Array([NPC_POS, Vector2(-360, 100), Vector2(-360, -100), Vector2(-240, -100)])
	value.safe_point_ids = PackedStringArray(["safe.north", "safe.south"])
	value.safe_points = PackedVector2Array([Vector2(-520, 260), Vector2(-520, -260)])
	return value


func _on_damage(target_id: String, attacker_id: String, amount: float, _remaining: float, sequence_id: int) -> void:
	if target_id == NPC and brain != null:
		brain.record_combat_damage(attacker_id, amount, sequence_id, scheduler.current_tick())


func _on_sunk(entity_id: String, _sequence_id: int) -> void:
	if entity_id == NPC and brain != null:
		brain.mark_sunk()


func _fire_player() -> Dictionary:
	assert_true(combat.select(PLAYER, NPC))
	return combat.fire(PLAYER, 0.0, CombatAuthority.fire_intent(NPC))


func _critical_fixture() -> void:
	_make_fixture(70.0, 100.0)
	assert_true(_fire_player()["accepted"])


func _enter_repair(at_tick: int = 20) -> void:
	_critical_fixture()
	assert_true(brain.decision_tick(10))
	assert_eq(brain.state_id(), NpcBrain.State.RETREAT)
	var dto := brain.snapshot()
	var destination: Dictionary = dto["destination"]
	var point := Vector2(destination["x"], destination["y"])
	motor.global_position = point
	motor.cancel_target()
	assert_true(sector.move_entity(NPC, point))
	assert_true(brain.decision_tick(at_tick))
	assert_eq(brain.state_id(), NpcBrain.State.REPAIR)


func test_npc_starts_in_patrol() -> void:
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)
	assert_eq(brain.intent_id(), NpcBrain.Intent.PATROL_TO_WAYPOINT)


func test_dormant_brain_boots_outside_home_sector_and_reactivates_after_rebind() -> void:
	var haven_definition := ResourceLoader.load(FoundationSector.HAVEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	var haven := SectorRuntime.build(haven_definition)
	assert_not_null(haven)
	var haven_player := haven.anchor("anchor.haven_center").position
	assert_true(haven.register_entity(PLAYER, haven_player))
	var dormant_motor := ShipMotor.new()
	add_child_autofree(dormant_motor)
	dormant_motor.set_physics_process(false)
	dormant_motor.global_position = NPC_POS
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.vs02_dormant_test"
	weapon.base_damage = 20.0
	weapon.min_range_meters = 0.0
	weapon.range_meters = 600.0
	weapon.reload_seconds = 0.01
	weapon.accuracy = 1.0
	weapon.crit_chance = 0.0
	var dormant_combat := CombatAuthority.new(haven, SeedStreams.new(88), 60)
	assert_true(dormant_combat.register(PLAYER, "faction.player", 100.0, weapon))
	assert_true(dormant_combat.register_dormant(NPC, "faction.hostile", 100.0, FoundationSector.ID, NPC_POS))
	var dormant_brain := NpcBrain.create(NPC, haven, dormant_combat, dormant_motor, _test_tuning(), true)
	assert_not_null(dormant_brain)
	assert_false(dormant_brain.decision_tick(10))
	var foundation_definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	var foundation := SectorRuntime.build(foundation_definition)
	assert_not_null(foundation)
	assert_true(foundation.register_entity(PLAYER, PLAYER_POS))
	assert_true(dormant_combat.rebind_sector(foundation, PLAYER))
	assert_true(foundation.entity_position(NPC).is_finite())
	assert_true(dormant_brain.rebind_sector(foundation, dormant_combat))
	assert_true(dormant_brain.decision_tick(20))


func test_patrol_waypoint_order_is_deterministic() -> void:
	assert_true(brain.decision_tick(10))
	assert_eq(brain.patrol_index(), 0)
	motor.global_position = tuning.patrol_waypoints[0]
	motor.cancel_target()
	assert_true(sector.move_entity(NPC, tuning.patrol_waypoints[0]))
	assert_true(brain.decision_tick(20))
	assert_eq(brain.patrol_index(), 1)
	motor.global_position = tuning.patrol_waypoints[1]
	motor.cancel_target()
	assert_true(sector.move_entity(NPC, tuning.patrol_waypoints[1]))
	assert_true(brain.decision_tick(30))
	assert_eq(brain.patrol_index(), 2)


func test_waypoint_arrival_selects_next_waypoint() -> void:
	brain.decision_tick(10)
	motor.global_position = tuning.patrol_waypoints[0]
	motor.cancel_target()
	sector.move_entity(NPC, tuning.patrol_waypoints[0])
	brain.decision_tick(20)
	var dto := brain.snapshot()
	assert_eq(dto["destination"]["x"], tuning.patrol_waypoints[1].x)
	assert_eq(dto["destination"]["y"], tuning.patrol_waypoints[1].y)


func test_perception_uses_spatial_hash() -> void:
	var source := FileAccess.get_file_as_string("res://src/simulation/ai/perception_service.gd")
	assert_true(source.contains("spatial.query_radius"))
	assert_false(source.contains("_entities"))


func test_perception_does_not_scan_whole_sector() -> void:
	for i in 200:
		assert_true(sector.register_entity("entity.remote_%03d" % i, Vector2(500, 300)))
	brain.decision_tick(10)
	assert_lte(brain.telemetry()["last_perception_inspected"], 2)


func test_friendly_entity_does_not_create_threat() -> void:
	assert_true(sector.register_entity(FRIEND, Vector2(-230, 100)))
	assert_true(combat.register(FRIEND, "faction.hostile", 50.0))
	assert_false(brain.record_combat_damage(FRIEND, 10.0, 1, 0))
	brain.decision_tick(10)
	assert_eq(brain.threat_score(), 0)


func test_player_attack_creates_threat() -> void:
	assert_true(_fire_player()["accepted"])
	assert_gt(brain.threat_score(), 0)


func test_threat_memory_keeps_attacker_stable_id() -> void:
	_fire_player()
	assert_eq(brain.threat_attacker_id(), PLAYER)
	assert_eq(brain.last_threat_tick(), 0)


func test_threat_decay_is_deterministic() -> void:
	assert_true(brain.record_combat_damage(PLAYER, 10.0, 1, 0))
	assert_eq(brain.threat_score(), 200)
	brain.decision_tick(30)
	assert_eq(brain.threat_score(), 100)
	brain.decision_tick(60)
	assert_eq(brain.threat_score(), 0)


func test_threat_never_becomes_negative() -> void:
	assert_true(brain.record_combat_damage(PLAYER, 1.0, 1, 0))
	brain.decision_tick(1000)
	assert_eq(brain.threat_score(), 0)


func test_high_hull_single_attack_does_not_retreat() -> void:
	assert_true(_fire_player()["accepted"])
	brain.decision_tick(10)
	assert_eq(brain.state_id(), NpcBrain.State.ALERT)


func test_critical_hull_plus_threat_enters_retreat() -> void:
	_critical_fixture()
	brain.decision_tick(10)
	assert_eq(brain.state_id(), NpcBrain.State.RETREAT)
	assert_eq(brain.intent_id(), NpcBrain.Intent.RETREAT_TO_SAFE_POINT)


func test_retreat_safe_point_selection_is_deterministic() -> void:
	_critical_fixture()
	brain.decision_tick(10)
	var first := brain.selected_safe_point_id()
	_make_fixture(70.0, 100.0)
	_fire_player()
	brain.decision_tick(10)
	assert_eq(brain.selected_safe_point_id(), first)


func test_unreachable_safe_point_uses_alternative() -> void:
	_make_fixture(70.0, 100.0)
	tuning.safe_point_ids = PackedStringArray(["safe.blocked", "safe.valid"])
	tuning.safe_points = PackedVector2Array([Vector2.ZERO, Vector2(-520, 260)])
	brain = NpcBrain.create(NPC, sector, combat, motor, tuning, true)
	assert_not_null(brain)
	assert_true(combat.select(PLAYER, NPC))
	combat.fire(PLAYER, 0.0, CombatAuthority.fire_intent(NPC))
	brain.decision_tick(10)
	assert_eq(brain.selected_safe_point_id(), "safe.valid")


func test_all_unreachable_safe_points_use_controlled_fallback() -> void:
	_make_fixture(70.0, 100.0)
	tuning.safe_point_ids = PackedStringArray(["safe.blocked"])
	tuning.safe_points = PackedVector2Array([Vector2.ZERO])
	brain = NpcBrain.create(NPC, sector, combat, motor, tuning, true)
	assert_not_null(brain)
	assert_true(combat.select(PLAYER, NPC))
	combat.fire(PLAYER, 0.0, CombatAuthority.fire_intent(NPC))
	brain.decision_tick(10)
	assert_eq(brain.selected_safe_point_id(), "fallback")
	assert_true(Vector2(brain.snapshot()["destination"]["x"], brain.snapshot()["destination"]["y"]).is_finite())


func test_retreat_movement_goes_through_ship_motor_authority_api() -> void:
	_critical_fixture()
	brain.decision_tick(10)
	assert_true(motor.has_target())
	var source := FileAccess.get_file_as_string("res://src/simulation/ai/npc_intent_executor.gd")
	assert_true(source.contains("apply_authoritative_command"))


func test_npc_brain_does_not_write_transform() -> void:
	var source := FileAccess.get_file_as_string("res://src/simulation/ai/npc_brain.gd")
	assert_false(source.contains("global_position"))
	assert_false(source.contains("velocity ="))
	assert_false(source.contains("rotation ="))


func test_safe_point_arrival_enters_repair() -> void:
	_enter_repair()
	assert_eq(brain.intent_id(), NpcBrain.Intent.REPAIR)


func test_repair_applies_on_fixed_tick_interval() -> void:
	_enter_repair(20)
	var before := combat.hull(NPC)
	brain.decision_tick(49)
	assert_eq(combat.hull(NPC), before)
	brain.decision_tick(50)
	assert_gt(combat.hull(NPC), before)


func test_repair_never_exceeds_max_hull() -> void:
	_enter_repair(20)
	var snapshot := combat.snapshot_state()
	for entry: Dictionary in snapshot["combatants"]:
		if entry["entity_id"] == NPC:
			entry["hull"] = 98.0
	assert_true(combat.restore_state(snapshot))
	assert_eq(combat.hull(NPC), 98.0)
	brain.decision_tick(50)
	assert_eq(combat.hull(NPC), 100.0)


func test_new_threat_interrupts_repair() -> void:
	_enter_repair(20)
	assert_true(brain.record_combat_damage(PLAYER, 10.0, 999, 21))
	brain.decision_tick(30)
	assert_ne(brain.state_id(), NpcBrain.State.REPAIR)


func test_threat_decay_and_hull_threshold_enter_resume() -> void:
	_enter_repair(20)
	var tick := 50
	while tick <= 500 and brain.state_id() == NpcBrain.State.REPAIR:
		brain.decision_tick(tick)
		tick += 30
	assert_eq(brain.state_id(), NpcBrain.State.RESUME)
	assert_gte(combat.hull_ratio(NPC), tuning.resume_hull_ratio)
	assert_lte(brain.threat_score(), tuning.resume_threat_max)


func test_resume_is_followed_by_patrol() -> void:
	_enter_repair(20)
	var tick := 50
	while tick <= 500 and brain.state_id() == NpcBrain.State.REPAIR:
		brain.decision_tick(tick)
		tick += 30
	assert_eq(brain.state_id(), NpcBrain.State.RESUME)
	brain.decision_tick(tick)
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)


func test_hysteresis_prevents_retreat_alert_oscillation() -> void:
	_enter_repair(20)
	var snapshot := combat.snapshot_state()
	for entry: Dictionary in snapshot["combatants"]:
		if entry["entity_id"] == NPC:
			entry["hull"] = 50.0
	assert_true(combat.restore_state(snapshot))
	brain.decision_tick(30)
	assert_eq(brain.state_id(), NpcBrain.State.REPAIR)
	assert_lt(combat.hull_ratio(NPC), tuning.resume_hull_ratio)


func test_sunk_npc_does_not_produce_decisions() -> void:
	_make_fixture(200.0, 100.0)
	assert_true(_fire_player()["sunk"])
	var before := brain.decision_count
	assert_false(brain.decision_tick(10))
	assert_eq(brain.decision_count, before)


func test_nan_and_inf_inputs_are_rejected() -> void:
	var invalid := _test_tuning()
	invalid.perception_radius = NAN
	assert_null(NpcBrain.create(NPC, sector, combat, motor, invalid, true))
	assert_false(brain.record_combat_damage(PLAYER, INF, 1, 0))
	assert_false(brain.record_combat_damage(PLAYER, NAN, 2, 0))


func test_intent_snapshot_is_primitive_safe() -> void:
	brain.decision_tick(10)
	assert_true(DtoContract.is_primitive_safe(brain.snapshot()))
	assert_eq(brain.snapshot()["npc_stable_id"], NPC)


func test_same_scenario_trace_is_deterministic() -> void:
	var first := _scenario_trace()
	var second := _scenario_trace()
	assert_eq(second, first)


func test_ai_decision_tick_is_sparser_than_physics_tick() -> void:
	for i in 600:
		scheduler.advance_physics_tick()
	assert_eq(scheduler.current_tick(), 600)
	assert_lte(brain.decision_count, 60)
	assert_gt(brain.decision_count, 0)


func test_path_is_not_recomputed_every_frame() -> void:
	for i in 600:
		scheduler.advance_physics_tick()
	assert_lt(brain.telemetry()["path_request_count"], brain.decision_count)
	assert_lte(brain.telemetry()["path_request_count"], 1)


func test_perception_is_not_run_every_physics_frame() -> void:
	for i in 600:
		scheduler.advance_physics_tick()
	assert_eq(brain.telemetry()["perception_query_count"], brain.decision_count)
	assert_lte(brain.telemetry()["perception_query_count"], 60)


func test_presentation_snapshot_cannot_mutate_ai_state() -> void:
	var presenter := NpcStatePresenter.new()
	add_child_autofree(presenter)
	var dto := brain.snapshot()
	assert_true(presenter.apply_snapshot(dto))
	dto["state_id"] = NpcBrain.State.REPAIR
	dto["threat_score"] = 999
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)
	assert_eq(brain.threat_score(), 0)


func test_npc_brain_has_no_network_dependency() -> void:
	var source := FileAccess.get_file_as_string("res://src/simulation/ai/npc_brain.gd")
	for forbidden in ["MultiplayerAPI", "ENet", "@rpc", "rpc(", "MultiplayerPeer"]:
		assert_false(source.contains(forbidden), forbidden)


func test_combat_damage_signal_is_authority_hook() -> void:
	var seen: Array = []
	combat.hull_damaged.connect(func(target: String, attacker: String, amount: float, remaining: float, seq: int) -> void:
		seen.append([target, attacker, amount, remaining, seq]))
	var result := _fire_player()
	assert_true(result["accepted"])
	assert_eq(seen.size(), 1)
	assert_eq(seen[0][0], NPC)
	assert_eq(seen[0][1], PLAYER)


func test_authority_disabled_brain_does_not_tick() -> void:
	_make_fixture(20.0, 100.0, false)
	assert_false(brain.decision_tick(10))
	assert_eq(brain.decision_count, 0)


func test_scheduler_budget_staggers_many_brains() -> void:
	var budget_scheduler := AiDecisionScheduler.new(1)
	assert_true(budget_scheduler.register_brain(brain, 10, 0))
	var second_motor := ShipMotor.new()
	add_child_autofree(second_motor)
	second_motor.set_physics_process(false)
	second_motor.global_position = Vector2(-300, 180)
	assert_true(sector.register_entity("entity.second", second_motor.global_position))
	assert_true(combat.register("entity.second", "faction.hostile", 100.0))
	var second := NpcBrain.create("entity.second", sector, combat, second_motor, tuning, true)
	assert_not_null(second)
	assert_true(budget_scheduler.register_brain(second, 10, 0))
	assert_eq(budget_scheduler.advance_physics_tick(), 1)
	assert_eq(brain.decision_count + second.decision_count, 1)
	assert_eq(budget_scheduler.advance_physics_tick(), 1)
	assert_eq(brain.decision_count + second.decision_count, 2)


func test_state_changes_are_centralized() -> void:
	var source := FileAccess.get_file_as_string("res://src/simulation/ai/npc_brain.gd")
	assert_true(source.contains("func _transition"))
	assert_eq(source.count("_state = next_state"), 1)


func test_beehave_is_pinned_and_manual_for_ai01() -> void:
	assert_true(DirAccess.dir_exists_absolute("res://addons/beehave"))
	var runner := FileAccess.get_file_as_string("res://src/simulation/ai/ai_bt_runner.gd")
	assert_true(runner.contains("BeehaveTree.ProcessThread.MANUAL"))
	assert_true(runner.contains("_tree.tick()"))
	var readme := FileAccess.get_file_as_string("res://README.md")
	assert_true(readme.contains("v2.9.3"))
	assert_true(readme.contains("773a5f6dd9b3433cdb8735ab35e9043d4cd60674"))
	assert_true(readme.contains("custom FSM"))


func _scenario_trace() -> Array:
	_make_fixture(70.0, 100.0)
	var trace: Array = []
	assert_true(_fire_player()["accepted"])
	brain.decision_tick(10)
	trace.append([brain.state_id(), brain.intent_id(), brain.threat_score()])
	var destination: Dictionary = brain.snapshot()["destination"]
	var safe := Vector2(destination["x"], destination["y"])
	motor.global_position = safe
	motor.cancel_target()
	sector.move_entity(NPC, safe)
	brain.decision_tick(20)
	trace.append([brain.state_id(), brain.intent_id(), brain.threat_score()])
	for tick in range(50, 501, 30):
		brain.decision_tick(tick)
		trace.append([brain.state_id(), brain.intent_id(), brain.threat_score()])
		if brain.state_id() == NpcBrain.State.RESUME:
			brain.decision_tick(tick + 1)
			trace.append([brain.state_id(), brain.intent_id(), brain.threat_score()])
			break
	return trace
