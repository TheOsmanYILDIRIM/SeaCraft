extends GutTest

const PLAYER := "entity.ai01_player"
const NPC := "entity.ai01_npc"
const PLAYER_POS := Vector2(-240, 0)
const NPC_POS := Vector2(-240, 100)
const TRADER := preload("res://src/data/ai/roles/trader.tres")
const ESCORT := preload("res://src/data/ai/roles/escort.tres")
const RAIDER := preload("res://src/data/ai/roles/raider.tres")

var _bt_mode := "success"


func test_ai01_sense_pipeline_uses_spatial_hash_cap_filters_and_stable_order() -> void:
	var sector := _sector()
	assert_not_null(sector)
	assert_true(sector.register_entity(NPC, NPC_POS))
	assert_true(sector.register_entity("entity.ai01_hostile_b", Vector2(-240, 130)))
	assert_true(sector.register_entity("entity.ai01_hostile_a", Vector2(-240, 130)))
	assert_true(sector.register_entity("entity.ai01_friendly", Vector2(-240, 120)))
	assert_true(sector.register_entity("entity.ai01_hidden", Vector2(-240, 110)))
	for i in 100:
		assert_true(sector.register_entity("entity.ai01_remote_%03d" % i, Vector2(500 + float(i % 4), 300 + float(i % 5))))
	var combat := CombatAuthority.new(sector, SeedStreams.new(1), 60)
	assert_true(combat.register(NPC, "faction.ai01_ally", 100.0))
	assert_true(combat.register("entity.ai01_hostile_a", "faction.ai01_hostile", 100.0))
	assert_true(combat.register("entity.ai01_hostile_b", "faction.ai01_hostile", 100.0))
	assert_true(combat.register("entity.ai01_friendly", "faction.ai01_ally", 100.0))
	assert_true(combat.register("entity.ai01_hidden", "faction.ai01_hostile", 100.0, null, 0.0, 0.0, false))
	assert_true(combat.register_dormant("entity.ai01_other_sector", "faction.ai01_hostile", 100.0, "sector.outer_reach", Vector2.ZERO))
	var service := PerceptionService.new()
	var first := service.capture(NPC, 10, sector, combat, 80.0, 2, TRADER as NpcRoleProfile)
	var second := service.capture(NPC, 10, sector, combat, 80.0, 2, TRADER as NpcRoleProfile)
	assert_eq(first, second)
	assert_true(DtoContract.is_primitive_safe(first))
	assert_eq(first["candidate_count"], 2)
	assert_eq(first["candidates"][0]["stable_id"], "entity.ai01_hostile_a")
	assert_eq(first["candidates"][1]["stable_id"], "entity.ai01_hostile_b")
	assert_lte(int(first["inspected_count"]), 5)
	assert_lt(int(first["inspected_count"]), 105)
	assert_eq(service.last_candidate_count, 2)
	print("AI01_SENSE_PIPELINE_OK")


func test_ai01_memory_multitarget_decay_expiry_bounded_and_roundtrip() -> void:
	var memory := MemoryBlackboard.new()
	assert_true(memory.configure(2, 60))
	assert_true(memory.record_damage("entity.hostile_a", 10.0, Vector2(10, 0), 0, 1000, 10.0))
	assert_true(memory.record_damage("entity.hostile_b", 5.0, Vector2(20, 0), 0, 1000, 10.0))
	assert_eq(memory.entry_count(), 2)
	assert_eq(memory.primary_target_id(), "entity.hostile_a")
	assert_true(memory.record_damage("entity.hostile_c", 20.0, Vector2(30, 0), 1, 1000, 10.0))
	assert_eq(memory.entry_count(), 2)
	assert_eq(memory.primary_target_id(), "entity.hostile_c")
	var snapshot := SenseSnapshot.build("entity.observer", 31, "sector.foundation", Vector2.ZERO, 1.0, [], 0)
	assert_true(memory.advance(snapshot, 31, 30, 50))
	assert_eq(memory.primary_threat(), 150)
	var saved := memory.snapshot_state()
	assert_true(DtoContract.is_primitive_safe(saved))
	var restored := MemoryBlackboard.new()
	assert_true(restored.configure(2, 60))
	assert_true(restored.restore_state(saved))
	assert_eq(restored.snapshot_state(), saved)
	var expired := SenseSnapshot.build("entity.observer", 200, "sector.foundation", Vector2.ZERO, 1.0, [], 0)
	assert_true(restored.advance(expired, 200, 30, 100))
	assert_eq(restored.entry_count(), 0)
	print("AI01_MEMORY_DECAY_OK")


func test_ai01_role_utility_differs_for_trader_escort_raider_and_rejects_nonfinite() -> void:
	var snapshot := _utility_snapshot(10, [
		_candidate("entity.hostile_a", 20.0),
	], 0.40)
	var memory := _utility_memory([
		_memory_entry("entity.hostile_a", 700, 10, 20.0),
	], 10)
	var context := {"max_threat": 1000, "perception_radius": 100.0, "protected_ally_threatened": true, "allow_repair": false}
	var trader := UtilityDecision.evaluate(snapshot, memory, (TRADER as NpcRoleProfile).data_snapshot(), context, 1)
	var escort := UtilityDecision.evaluate(snapshot, memory, (ESCORT as NpcRoleProfile).data_snapshot(), context, 1)
	var raider := UtilityDecision.evaluate(snapshot, memory, (RAIDER as NpcRoleProfile).data_snapshot(), context, 1)
	assert_eq(trader["selected_intent_id"], UtilityDecision.RETREAT_TO_SAFE_POINT)
	assert_eq(escort["selected_intent_id"], UtilityDecision.PROTECT_ALLY)
	assert_eq(raider["selected_intent_id"], UtilityDecision.INVESTIGATE_THREAT)
	assert_eq(UtilityDecision.evaluate(snapshot, memory, (RAIDER as NpcRoleProfile).data_snapshot(), context, 1), raider)
	var bad_role := (RAIDER as NpcRoleProfile).data_snapshot()
	bad_role["pursue_aggression"] = NAN
	assert_true(UtilityDecision.evaluate(snapshot, memory, bad_role, context, 2).is_empty())
	print("AI01_ROLE_UTILITY_OK")


func test_ai01_hysteresis_prevents_close_target_thrash_switches_when_clear_and_persists() -> void:
	var role := (RAIDER as NpcRoleProfile).data_snapshot()
	var context := {"max_threat": 1000, "perception_radius": 100.0, "protected_ally_threatened": false, "allow_repair": false}
	var memory := _utility_memory([
		_memory_entry("entity.target_a", 500, 0, 40.0),
		_memory_entry("entity.target_b", 500, 0, 42.0),
	], 0)
	var first := UtilityDecision.evaluate(_utility_snapshot(0, [_candidate("entity.target_a", 40.0), _candidate("entity.target_b", 42.0)], 0.8), memory, role, context, 1)
	assert_eq(first["selected_target_id"], "entity.target_a")
	memory["hysteresis"] = first["hysteresis_state"].duplicate(true)
	var close_memory := memory.duplicate(true)
	close_memory["entries"][0]["distance"] = 42.0
	close_memory["entries"][1]["distance"] = 40.0
	var held := UtilityDecision.evaluate(_utility_snapshot(5, [_candidate("entity.target_b", 40.0), _candidate("entity.target_a", 42.0)], 0.8), close_memory, role, context, 2)
	assert_eq(held["selected_target_id"], "entity.target_a")
	assert_true(bool(held["reason_debug"]["hysteresis_hold"]))
	close_memory["hysteresis"] = held["hysteresis_state"].duplicate(true)
	var restored_memory := MemoryBlackboard.new()
	assert_true(restored_memory.configure(8, 300))
	var persisted := {
		"version": 1,
		"max_entries": 8,
		"expiry_ticks": 300,
		"entries": close_memory["entries"].duplicate(true),
		"selected_target_id": "entity.target_a",
		"recent_intent_id": int(held["selected_intent_id"]),
		"recent_decision_tick": 5,
		"hysteresis": held["hysteresis_state"].duplicate(true),
	}
	assert_true(restored_memory.restore_state(persisted))
	var clear_memory := restored_memory.snapshot_state()
	for entry in clear_memory["entries"]:
		entry["distance"] = 100.0 if entry["stable_id"] == "entity.target_a" else 0.0
	var switched := UtilityDecision.evaluate(_utility_snapshot(50, [_candidate("entity.target_b", 0.0), _candidate("entity.target_a", 100.0)], 0.8), clear_memory, role, context, 3)
	assert_eq(switched["selected_target_id"], "entity.target_b")
	print("AI01_HYSTERESIS_OK")


func test_ai01_real_beehave_bt_lifecycle_success_failure_timeout_interrupt_and_reentry() -> void:
	var actor := Node.new()
	add_child_autofree(actor)
	var runner := AiBtRunner.new()
	assert_true(runner.configure(actor, Callable(self, "_bt_handler")))
	_bt_mode = "success"
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_STOP, 10, 1, 5), BeehaveNode.SUCCESS)
	_bt_mode = "failure"
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_WAIT_OBSERVE, 11, 2, 5), BeehaveNode.FAILURE)
	_bt_mode = "running"
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_TARGET, 12, 3, 3), BeehaveNode.RUNNING)
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_TARGET, 12, 6, 3), BeehaveNode.FAILURE)
	assert_eq(runner.telemetry()["timeout_count"], 1)
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_DESTINATION, 20, 4, 10), BeehaveNode.RUNNING)
	runner.interrupt()
	assert_gte(int(runner.telemetry()["interrupt_count"]), 1)
	runner.reset()
	_bt_mode = "success"
	assert_eq(runner.tick_action_kind(AiBtRunner.ACTION_DESTINATION, 21, 4, 10), BeehaveNode.SUCCESS)
	assert_true(bool(runner.telemetry()["manual_process_thread"]))
	assert_false(bool(runner.telemetry()["idle_processing"]))
	assert_false(bool(runner.telemetry()["physics_processing"]))
	print("AI01_BT_LIFECYCLE_OK")


func test_ai01_custom_fsm_trace_and_vs02_patrol_alert_retreat_repair_resume_regression() -> void:
	var valid := NpcStateMachine.transition(NpcStateMachine.PATROL, NpcStateMachine.ALERT, "threat", 10)
	assert_true(valid["accepted"])
	assert_true(valid["changed"])
	assert_eq(valid["previous_state"], NpcStateMachine.PATROL)
	assert_eq(valid["next_state"], NpcStateMachine.ALERT)
	assert_false(NpcStateMachine.transition(NpcStateMachine.PATROL, NpcStateMachine.REPAIR, "invalid", 10)["accepted"])
	var fixture := _brain_fixture("ai01_regression", true, TRADER as NpcRoleProfile)
	var brain: NpcBrain = fixture["brain"]
	var combat: CombatAuthority = fixture["combat"]
	var sector: SectorRuntime = fixture["sector"]
	var motor: ShipMotor = fixture["motor"]
	assert_true(brain.record_combat_damage(PLAYER, 10.0, 1, 0))
	assert_true(brain.decision_tick(10))
	assert_eq(brain.state_id(), NpcBrain.State.ALERT)
	var combat_state := combat.snapshot_state()
	for entry: Dictionary in combat_state["combatants"]:
		if entry["entity_id"] == NPC:
			entry["hull"] = 30.0
	assert_true(combat.restore_state(combat_state))
	assert_true(brain.record_combat_damage(PLAYER, 10.0, 2, 11))
	assert_true(brain.decision_tick(20))
	assert_eq(brain.state_id(), NpcBrain.State.RETREAT)
	var destination: Dictionary = brain.snapshot()["destination"]
	var safe := Vector2(float(destination["x"]), float(destination["y"]))
	motor.global_position = safe
	motor.cancel_target()
	assert_true(sector.move_entity(NPC, safe))
	assert_true(brain.decision_tick(30))
	assert_eq(brain.state_id(), NpcBrain.State.REPAIR)
	var saw_resume := false
	for tick in range(60, 721, 30):
		assert_true(brain.decision_tick(tick))
		if brain.state_id() == NpcBrain.State.RESUME:
			saw_resume = true
			assert_true(brain.decision_tick(tick + 1))
			break
	assert_true(saw_resume)
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)
	print("AI01_FSM_REGRESSION_OK")


func test_ai01_scheduler_budget_20_npc_no_starvation_stagger_or_double_bt_tick() -> void:
	var sector := _sector()
	assert_not_null(sector)
	var combat := CombatAuthority.new(sector, SeedStreams.new(88), 60)
	var scheduler := AiDecisionScheduler.new(3)
	var brains: Array[NpcBrain] = []
	for i in 20:
		var id := "entity.ai01_sched_%02d" % i
		var pos := Vector2(-420 + float(i % 5) * 18.0, -120 + float(i / 5) * 18.0)
		assert_true(sector.register_entity(id, pos))
		assert_true(combat.register(id, "faction.ai01_sched", 100.0))
		var motor := ShipMotor.new()
		add_child_autofree(motor)
		motor.set_physics_process(false)
		motor.global_position = pos
		var brain := NpcBrain.create(id, sector, combat, motor, _tuning(), true, RAIDER as NpcRoleProfile)
		assert_not_null(brain)
		brains.append(brain)
		assert_true(scheduler.register_brain(brain, 10, i % 10))
	for i in 100:
		assert_true(sector.register_entity("entity.ai01_far_%03d" % i, Vector2(450 + float(i % 10), 300 + float(i % 9))))
	var active_ticks := 0
	for _tick in 240:
		var ran := scheduler.advance_physics_tick()
		assert_lte(ran, 3)
		if ran > 0:
			active_ticks += 1
	assert_gt(active_ticks, 20)
	var total_candidates := 0
	var max_inspected := 0
	var bt_failures := 0
	var bt_timeouts := 0
	for brain in brains:
		assert_gt(brain.decision_count, 0)
		var telemetry := brain.telemetry()
		assert_eq(int(telemetry["bt_tree_tick_count"]), brain.decision_count)
		total_candidates += int(telemetry["perception_candidate_count"])
		max_inspected = maxi(max_inspected, int(telemetry["last_perception_inspected"]))
		bt_failures += int(telemetry["bt_failure_count"])
		bt_timeouts += int(telemetry["bt_timeout_count"])
	assert_lte(scheduler.max_decisions_observed, 3)
	assert_lt(max_inspected, 120)
	print("AI01_SCHEDULER_BUDGET_OK npc_count=20 total_decision_ticks=%d max_decisions_in_tick=%d total_perception_candidates=%d max_inspected_candidates=%d bt_failures=%d bt_timeouts=%d" % [
		scheduler.decision_count,
		scheduler.max_decisions_observed,
		total_candidates,
		max_inspected,
		bt_failures,
		bt_timeouts,
	])


func test_ai01_persistence_preserves_role_memory_target_hysteresis_fsm_route_bt_and_scheduler() -> void:
	var first := _brain_fixture("ai01_persist_a", true, TRADER as NpcRoleProfile)
	var brain: NpcBrain = first["brain"]
	var scheduler := AiDecisionScheduler.new(2)
	assert_true(scheduler.register_brain(brain, 10, 0))
	assert_true(brain.record_combat_damage(PLAYER, 10.0, 1, 0))
	for _tick in 5:
		scheduler.advance_physics_tick()
	var brain_state := brain.persistence_state()
	var scheduler_state := scheduler.snapshot_state()
	assert_eq(brain_state["role_profile_id"], "ai_role.trader")
	assert_true(DtoContract.is_primitive_safe(brain_state))
	var second := _brain_fixture("ai01_persist_b", true, TRADER as NpcRoleProfile)
	var restored: NpcBrain = second["brain"]
	assert_true(restored.restore_state(brain_state))
	assert_eq(restored.persistence_state(), brain_state)
	var restored_scheduler := AiDecisionScheduler.new(2)
	assert_true(restored_scheduler.restore_state(scheduler_state))
	assert_true(restored_scheduler.register_brain(restored, 10, 0))
	assert_eq(restored_scheduler.snapshot_state(), scheduler_state)
	var before := restored.decision_count
	for _tick in 20:
		restored_scheduler.advance_physics_tick()
	assert_gt(restored.decision_count, before)
	assert_eq(restored.role_profile_id(), "ai_role.trader")
	print("AI01_PERSISTENCE_OK")


func test_ai01_authority_disabled_is_read_only_and_presenter_consumes_detached_snapshot() -> void:
	var fixture := _brain_fixture("ai01_readonly", false, TRADER as NpcRoleProfile)
	var brain: NpcBrain = fixture["brain"]
	var combat: CombatAuthority = fixture["combat"]
	var motor: ShipMotor = fixture["motor"]
	var before_motion := motor.capture_save_motion()
	var before_combat := combat.snapshot_state()
	assert_false(brain.decision_tick(10))
	assert_eq(brain.telemetry()["sense_query_count"], 0)
	assert_eq(motor.capture_save_motion(), before_motion)
	assert_eq(combat.snapshot_state(), before_combat)
	var presenter := NpcStatePresenter.new()
	add_child_autofree(presenter)
	var dto := brain.snapshot()
	assert_true(presenter.apply_snapshot(dto))
	dto["state_id"] = NpcBrain.State.REPAIR
	dto["intent_id"] = NpcBrain.Intent.REPAIR
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)
	assert_eq(brain.intent_id(), NpcBrain.Intent.PATROL_TO_WAYPOINT)


func test_ai01_content_registry_and_runtime_beehave_export_contract() -> void:
	ContentManifest.reset_cache_for_tests()
	var registry := ContentManifest.registry()
	assert_not_null(registry)
	for id in ["ai_role.trader", "ai_role.escort", "ai_role.raider"]:
		assert_true(registry.matches_type(id, "ai_role"), id)
		var role := registry.load_content(id) as NpcRoleProfile
		assert_not_null(role)
		assert_true(role.valid())
	assert_true(ResourceLoader.exists("res://addons/beehave/nodes/beehave_tree.gd"))
	assert_true(ResourceLoader.exists("res://addons/beehave/nodes/leaves/action.gd"))
	var presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_false(presets.contains("addons/**"))
	assert_true(presets.contains("tests/**"))
	assert_true(presets.contains("tools/**"))
	assert_true(presets.contains("addons/gut/**"))
	assert_false(presets.contains("addons/beehave/**"))


func _sector() -> SectorRuntime:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	return SectorRuntime.build(definition)


func _tuning() -> NpcAiTuning:
	var value := NpcAiTuning.new()
	value.decision_interval_ticks = 10
	value.perception_radius = 90.0
	value.perception_candidate_cap = 8
	value.perception_query_cadence_ticks = 10
	value.memory_max_entries = 8
	value.memory_expiry_ticks = 120
	value.bt_timeout_ticks = 300
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
	value.patrol_waypoint_ids = PackedStringArray(["waypoint.ai01_a", "waypoint.ai01_b", "waypoint.ai01_c", "waypoint.ai01_d"])
	value.patrol_waypoints = PackedVector2Array([NPC_POS, Vector2(-360, 100), Vector2(-360, -100), Vector2(-240, -100)])
	value.safe_point_ids = PackedStringArray(["safe.ai01_north", "safe.ai01_south"])
	value.safe_points = PackedVector2Array([Vector2(-520, 260), Vector2(-520, -260)])
	return value


func _brain_fixture(_label: String, authority_enabled: bool, role: NpcRoleProfile) -> Dictionary:
	var sector := _sector()
	assert_not_null(sector)
	assert_true(sector.register_entity(PLAYER, PLAYER_POS))
	assert_true(sector.register_entity(NPC, NPC_POS))
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = NPC_POS
	var combat := CombatAuthority.new(sector, SeedStreams.new(77), 60)
	assert_true(combat.register(PLAYER, "faction.ai01_player", 100.0))
	assert_true(combat.register(NPC, "faction.ai01_hostile", 100.0))
	var supply := LootAuthority.new(sector, null, null, null)
	assert_true(supply.reserve_inventory_item(NPC, CoreCombatRules.NPC_REPAIR))
	supply.initialize_missing_stock({CoreCombatRules.NPC_REPAIR: 64})
	assert_true(combat.attach_inventory(supply))
	var brain := NpcBrain.create(NPC, sector, combat, motor, _tuning(), authority_enabled, role)
	assert_not_null(brain)
	return {"sector": sector, "combat": combat, "motor": motor, "brain": brain, "supply": supply}


func _utility_snapshot(tick: int, candidates: Array, hull_ratio: float) -> Dictionary:
	return SenseSnapshot.build("entity.utility_observer", tick, "sector.foundation", Vector2.ZERO, hull_ratio, candidates, candidates.size())


func _candidate(id: String, distance: float) -> Dictionary:
	return {
		"stable_id": id,
		"faction_id": "faction.utility_hostile",
		"relation": SenseSnapshot.RELATION_HOSTILE,
		"target_class": TargetingService.SHIP,
		"position": {"x": distance, "y": 0.0},
		"distance": distance,
		"alive": true,
		"selectable": true,
		"visible": true,
		"threat_facts": {"hostile": true},
	}


func _memory_entry(id: String, threat: int, tick: int, distance: float) -> Dictionary:
	return {
		"stable_id": id,
		"threat": threat,
		"last_seen_tick": tick,
		"last_threat_tick": tick,
		"last_decay_tick": tick,
		"x": distance,
		"y": 0.0,
		"distance": distance,
	}


func _utility_memory(entries: Array, tick: int) -> Dictionary:
	return {
		"version": 1,
		"max_entries": 8,
		"expiry_ticks": 300,
		"entries": entries,
		"selected_target_id": "",
		"recent_intent_id": 0,
		"recent_decision_tick": tick,
		"hysteresis": {"intent_id": 0, "target_id": "", "score": 0.0, "hold_until_tick": 0},
	}


func _bt_handler(action_kind: String, _tick: int) -> int:
	if action_kind.begins_with("interrupt:"):
		return BeehaveNode.SUCCESS
	match _bt_mode:
		"success":
			return BeehaveNode.SUCCESS
		"failure":
			return BeehaveNode.FAILURE
		_:
			return BeehaveNode.RUNNING
