extends GutTest

const ESCORT_PROFILE := preload("res://src/data/ai/roles/escort.tres")
const TUNING := preload("res://src/data/ai/vs02_sc03_tuning.tres")


func test_ai03_formation_slots_deterministic_insertion_independent_and_hysteretic() -> void:
	var fixture := Ai03ConvoyFixture.build(0, FoundationSector.ID)
	var reversed := fixture.duplicate(true)
	(reversed["members"] as Array).reverse()
	var a := FleetCoordinator.new(true)
	var b := FleetCoordinator.new(true)
	assert_true(a.register_fleet(fixture))
	assert_true(b.register_fleet(reversed))
	var formations := [FleetCoordinator.COLUMN, FleetCoordinator.LINE, FleetCoordinator.WEDGE]
	for index in formations.size():
		var formation: String = formations[index]
		var base_tick := 10 + index * 40
		assert_true(a.set_formation(fixture["fleet_id"], formation))
		assert_true(b.set_formation(fixture["fleet_id"], formation))
		assert_eq(a.formation_slots(fixture["fleet_id"]), b.formation_slots(fixture["fleet_id"]), formation)
		var first := a.formation_commands(fixture["fleet_id"], Vector2(100, 100), 0.0, base_tick)
		assert_true(DtoContract.is_primitive_safe(first))
		assert_gt(first.size(), 0)
		var jitter := a.formation_commands(fixture["fleet_id"], Vector2(101, 100), 0.0, base_tick + 1)
		assert_eq(jitter.size(), 0)
	assert_eq((a.formation_slots(fixture["fleet_id"]) as Array).size(), 3)
	print("AI03_FORMATION_SLOTS_OK")


func test_ai03_convoy_ambush_break_preserves_local_tactical_ai_then_regroups() -> void:
	var fixture := Ai03ConvoyFixture.build(1, FoundationSector.ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	var fleet_id: String = fixture["fleet_id"]
	assert_gt(coordinator.formation_commands(fleet_id, Vector2(-420, 120), 0.0, 1).size(), 0)
	assert_true(coordinator.set_threat(fleet_id, true, false))
	assert_eq(coordinator.fleet_snapshot(fleet_id)["fleet_state"], FleetCoordinator.BREAK_FOR_COMBAT)
	assert_eq(coordinator.formation_commands(fleet_id, Vector2(-420, 120), 0.0, 2).size(), 0)

	var sector := _foundation_sector()
	var escort_id := str(fixture["members"][1]["member_id"])
	var hostile_id := "entity.ai03.ambush.hostile"
	assert_true(sector.register_entity(escort_id, Vector2(-420, 120)))
	assert_true(sector.register_entity(hostile_id, Vector2(-220, 120)))
	var relations := FactionRelationResolver.new(true)
	assert_true(relations.set_relation("faction.ai03.convoy", "faction.ai03.hostile", FactionRelationResolver.HOSTILE))
	var combat := CombatAuthority.new(sector, SeedStreams.new(9301), 60)
	assert_true(combat.bind_relation_resolver(relations))
	assert_true(combat.register(escort_id, "faction.ai03.convoy", 200.0, _weapon()))
	assert_true(combat.register(hostile_id, "faction.ai03.hostile", 200.0))
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = sector.entity_position(escort_id)
	var brain := NpcBrain.create(escort_id, sector, combat, motor, TUNING as NpcAiTuning, true, ESCORT_PROFILE as NpcRoleProfile)
	assert_not_null(brain)
	var slot_command := FleetCommand.create(fleet_id, fixture["leader_id"], escort_id, "command.ai03.local.s1", FleetCommand.OCCUPY_SLOT, fixture["leader_id"], Vector2(-300, 120), {}, 1, 1, "formation_slot")
	assert_true(brain.set_fleet_command(slot_command))
	assert_true(brain.decision_tick(10))
	assert_eq(brain.state_id(), NpcBrain.State.ALERT)
	assert_gt(int(brain.telemetry()["tactical_evaluation_count"]), 0)
	assert_true(relations.set_relation("faction.ai03.convoy", "faction.ai03.hostile", FactionRelationResolver.NEUTRAL))
	assert_true(coordinator.set_threat(fleet_id, false, false))
	assert_eq(coordinator.fleet_snapshot(fleet_id)["fleet_state"], FleetCoordinator.REGROUP)
	var regroup_commands := coordinator.formation_commands(fleet_id, Vector2(-520, 160), 0.0, 20)
	var regroup_command: Dictionary = {}
	for command in regroup_commands:
		if command["member_id"] == escort_id:
			regroup_command = command
			break
	assert_false(regroup_command.is_empty())
	assert_true(brain.set_fleet_command(regroup_command))
	assert_true(brain.decision_tick(20))
	assert_eq(brain.state_id(), NpcBrain.State.PATROL)
	assert_eq(brain.snapshot()["destination"], regroup_command["destination"])
	assert_true(motor.has_target())
	assert_true(coordinator.complete_regroup(fleet_id))
	assert_eq(coordinator.fleet_snapshot(fleet_id)["fleet_state"], FleetCoordinator.FORMATION)
	print("AI03_CONVOY_AMBUSH_OK")


func test_ai03_leader_loss_selects_deterministic_successor_and_preserves_fleet_job() -> void:
	var fixture := Ai03ConvoyFixture.build(2, FoundationSector.ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	var fleet_id: String = fixture["fleet_id"]
	var before_job: Dictionary = coordinator.fleet_snapshot(fleet_id)["world_job"]
	assert_true(coordinator.mark_member_status(fleet_id, fixture["leader_id"], false, false, FoundationSector.ID))
	var fleet := coordinator.fleet_snapshot(fleet_id)
	assert_eq(fleet["fleet_id"], fleet_id)
	assert_eq(fleet["leader_id"], "entity.ai03.escort.c02.a")
	assert_eq(fleet["world_job"], before_job)
	assert_eq(fleet["fleet_state"], FleetCoordinator.REGROUP)
	assert_eq(int(coordinator.telemetry()["succession_count"]), 1)
	print("AI03_LEADER_SUCCESSION_OK")


func test_ai03_dock_queue_fifo_stable_tie_break_capacity_and_cleanup() -> void:
	var dock := DockAuthority.new(true)
	assert_true(dock.register_dock("dock.ai03.haven", FoundationSector.HAVEN_ID, 1, Vector2.ZERO))
	assert_true(dock.request("dock.ai03.haven", "entity.ai03.dock.b", 10))
	assert_true(dock.request("dock.ai03.haven", "entity.ai03.dock.a", 10))
	assert_true(dock.request("dock.ai03.haven", "entity.ai03.dock.c", 11))
	assert_true(dock.request("dock.ai03.haven", "entity.ai03.dock.c", 1))
	assert_eq(dock.queue_ids("dock.ai03.haven"), ["entity.ai03.dock.a", "entity.ai03.dock.b", "entity.ai03.dock.c"])
	assert_ne(dock.waiting_position("dock.ai03.haven", "entity.ai03.dock.a"), dock.waiting_position("dock.ai03.haven", "entity.ai03.dock.b"))
	assert_eq(dock.process_queue("dock.ai03.haven", ["entity.ai03.dock.a", "entity.ai03.dock.b", "entity.ai03.dock.c"]), ["entity.ai03.dock.a"])
	assert_eq(dock.admitted_ids("dock.ai03.haven").size(), 1)
	assert_true(dock.release("dock.ai03.haven", "entity.ai03.dock.a"))
	assert_eq(dock.process_queue("dock.ai03.haven", ["entity.ai03.dock.b"]), ["entity.ai03.dock.b"])
	assert_eq(dock.queue_ids("dock.ai03.haven").size(), 0)
	print("AI03_DOCK_QUEUE_OK")


func test_ai03_faction_relation_transition_drives_perception_without_hardcoded_factions() -> void:
	var sector := _foundation_sector()
	var observer := "entity.ai03.relation.observer"
	var target := "entity.ai03.relation.target"
	assert_true(sector.register_entity(observer, Vector2(-300, 100)))
	assert_true(sector.register_entity(target, Vector2(-120, 100)))
	var relations := FactionRelationResolver.new(true)
	var combat := CombatAuthority.new(sector, SeedStreams.new(9302), 60)
	assert_true(combat.bind_relation_resolver(relations))
	assert_true(combat.register(observer, "faction.ai03.alpha", 100.0))
	assert_true(combat.register(target, "faction.ai03.beta", 100.0))
	var perception := PerceptionService.new()
	var neutral := perception.capture(observer, 1, sector, combat, 280.0, 16, ESCORT_PROFILE as NpcRoleProfile)
	assert_eq(neutral["candidate_count"], 0)
	assert_true(relations.set_relation("faction.ai03.alpha", "faction.ai03.beta", FactionRelationResolver.HOSTILE))
	var hostile := perception.capture(observer, 2, sector, combat, 280.0, 16, ESCORT_PROFILE as NpcRoleProfile)
	assert_eq(hostile["candidate_count"], 1)
	assert_true(relations.set_relation("faction.ai03.alpha", "faction.ai03.beta", FactionRelationResolver.FRIENDLY))
	var friendly := perception.capture(observer, 3, sector, combat, 280.0, 16, ESCORT_PROFILE as NpcRoleProfile)
	assert_eq(friendly["candidate_count"], 0)
	assert_false(combat.hostile(observer, target))
	print("AI03_FACTION_RELATION_OK")


func test_ai03_safe_zone_target_cuts_pursuit_clears_memory_and_returns_to_regroup() -> void:
	var definition := ResourceLoader.load(FoundationSector.HAVEN_PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	var sector := SectorRuntime.build(definition)
	var actor := "entity.ai03.safe.escort"
	var target := "entity.ai03.safe.hostile"
	assert_true(sector.register_entity(actor, Vector2(0, 340)))
	assert_true(sector.register_entity(target, Vector2(120, 340)))
	var relations := FactionRelationResolver.new(true)
	assert_true(relations.set_relation("faction.ai03.safe.escort", "faction.ai03.safe.hostile", FactionRelationResolver.HOSTILE))
	var combat := CombatAuthority.new(sector, SeedStreams.new(9303), 60)
	assert_true(combat.bind_relation_resolver(relations))
	assert_true(combat.register(actor, "faction.ai03.safe.escort", 200.0, _weapon()))
	assert_true(combat.register(target, "faction.ai03.safe.hostile", 200.0))
	var motor := ShipMotor.new()
	add_child_autofree(motor)
	motor.set_physics_process(false)
	motor.global_position = sector.entity_position(actor)
	var brain := NpcBrain.create(actor, sector, combat, motor, TUNING as NpcAiTuning, true, ESCORT_PROFILE as NpcRoleProfile)
	assert_not_null(brain)
	assert_true(brain.decision_tick(10))
	assert_eq(brain.state_id(), NpcBrain.State.ALERT)
	assert_true(sector.move_entity(target, Vector2.ZERO))
	assert_true(brain.decision_tick(20))
	assert_ne(brain.state_id(), NpcBrain.State.ALERT)
	assert_eq(brain.threat_attacker_id(), "")
	assert_eq(combat.locked_target(actor), "")
	var fixture := Ai03ConvoyFixture.build(3, FoundationSector.HAVEN_ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	assert_true(coordinator.set_threat(fixture["fleet_id"], true, false))
	assert_true(coordinator.set_threat(fixture["fleet_id"], true, true))
	assert_eq(coordinator.fleet_snapshot(fixture["fleet_id"])["fleet_state"], FleetCoordinator.REGROUP)
	assert_eq(coordinator.fleet_snapshot(fixture["fleet_id"])["world_job"]["job_type"], WorldJob.TRADE)
	print("AI03_SAFE_ZONE_PURSUIT_OK")


func test_ai03_world_jobs_cargo_trade_salvage_patrol_and_economy_hook_are_typed() -> void:
	var fleet_id := "fleet.ai03.jobs"
	var cargo := WorldJob.cargo_mission("mission.ai03.jobs.cargo", "item.ai03.jobs.cargo", 7, "anchor.ai03.jobs.a", "anchor.ai03.jobs.b")
	assert_true(WorldJob.valid_cargo_mission(cargo))
	var trade := WorldJob.create("job.ai03.jobs.trade", WorldJob.TRADE, fleet_id, "anchor.ai03.jobs.a", "anchor.ai03.jobs.b", FoundationSector.ID, WorldJob.TRAVEL, "", cargo)
	var patrol := WorldJob.create("job.ai03.jobs.patrol", WorldJob.PATROL, fleet_id, "anchor.ai03.jobs.a", "anchor.ai03.jobs.b", FoundationSector.ID)
	var salvage := WorldJob.create("job.ai03.jobs.salvage", WorldJob.SALVAGE, fleet_id, "anchor.ai03.jobs.a", "anchor.ai03.jobs.b", FoundationSector.ID, WorldJob.APPROACH, "object.ai03.salvage")
	var escort := WorldJob.create("job.ai03.jobs.escort", WorldJob.ESCORT, fleet_id, "anchor.ai03.jobs.a", "anchor.ai03.jobs.b", FoundationSector.ID)
	var dock := WorldJob.create("job.ai03.jobs.dock", WorldJob.DOCK, fleet_id, "anchor.ai03.jobs.a", "dock.ai03.jobs", FoundationSector.ID, WorldJob.QUEUE)
	for job in [trade, patrol, salvage, escort, dock]:
		assert_true(WorldJob.valid(job))
		assert_true(DtoContract.is_primitive_safe(job))
	var claimed := WorldJob.claim_salvage(salvage, "entity.ai03.jobs.claimant")
	assert_false(claimed.is_empty())
	assert_eq(WorldJob.claim_salvage(claimed, "entity.ai03.jobs.other"), {})
	var delivered := WorldJob.with_phase(trade, WorldJob.COMPLETE, 1.0)
	var event := WorldJob.economy_event(delivered, "event.ai03.trade.delivered", "trade_delivered", 100)
	assert_true(DtoContract.is_primitive_safe(event))
	assert_eq(event["event_type"], "trade_delivered")
	print("AI03_WORLD_JOBS_OK")


func test_ai03_support_intent_dispatch_is_existing_member_bounded_and_loop_guarded() -> void:
	var fixture := Ai03ConvoyFixture.build(4, FoundationSector.ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	var before_members := coordinator.member_count()
	var request := {
		"support_id": "support.ai03.c04.s01",
		"requester_id": fixture["leader_id"],
		"target_id": "entity.ai03.support.target",
		"decision_sequence": 1,
	}
	var first := coordinator.consume_support_request(fixture["fleet_id"], request, 20, 0)
	assert_eq(first.size(), 2)
	for command in first:
		assert_eq(command["kind"], FleetCommand.SUPPORT_RESPONSE)
	assert_eq(coordinator.consume_support_request(fixture["fleet_id"], request, 21, 1).size(), 0)
	var over_hop := request.duplicate(true)
	over_hop["support_id"] = "support.ai03.c04.s02"
	over_hop["decision_sequence"] = 2
	assert_eq(coordinator.consume_support_request(fixture["fleet_id"], over_hop, 22, 3).size(), 0)
	assert_eq(coordinator.member_count(), before_members)
	print("AI03_SUPPORT_RESPONSE_OK")


func test_ai03_fleet_persistence_roundtrip_ambush_and_restore_succession() -> void:
	var fixture := Ai03ConvoyFixture.build(5, FoundationSector.ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	assert_true(coordinator.set_formation(fixture["fleet_id"], FleetCoordinator.WEDGE))
	assert_true(coordinator.set_threat(fixture["fleet_id"], true, false))
	var saved := coordinator.snapshot_state()
	assert_true(DtoContract.is_primitive_safe(saved))
	var restored := FleetCoordinator.new(true)
	assert_true(restored.restore_state(saved))
	var fleet := restored.fleet_snapshot(fixture["fleet_id"])
	assert_eq(fleet["fleet_id"], fixture["fleet_id"])
	assert_eq(fleet["leader_id"], fixture["leader_id"])
	assert_eq(fleet["slot_assignments"], coordinator.fleet_snapshot(fixture["fleet_id"])["slot_assignments"])
	assert_eq(fleet["world_job"], coordinator.fleet_snapshot(fixture["fleet_id"])["world_job"])
	assert_eq(fleet["fleet_state"], FleetCoordinator.BREAK_FOR_COMBAT)
	var damaged := saved.duplicate(true)
	for raw in damaged["fleets"][0]["members"]:
		if raw["member_id"] == fixture["leader_id"]:
			raw["alive"] = false
			raw["available"] = false
	var recovered := FleetCoordinator.new(true)
	assert_true(recovered.restore_state(damaged))
	assert_ne(recovered.fleet_snapshot(fixture["fleet_id"])["leader_id"], fixture["leader_id"])
	assert_eq(recovered.fleet_snapshot(fixture["fleet_id"])["fleet_id"], fixture["fleet_id"])
	assert_eq(recovered.fleet_snapshot(fixture["fleet_id"])["world_job"]["job_id"], fixture["world_job"]["job_id"])
	var sector := _foundation_sector()
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	assert_true(sector.register_entity("entity.ai03.persist.player", Vector2(-500, 0)))
	ship.global_position = Vector2(-500, 0)
	var dto := SaveSnapshot.capture(sector, "entity.ai03.persist.player", ship, SeedStreams.new(9304), SaveSnapshot.LOCAL, "", SaveSnapshot.empty_loot_state(), {"fleet": saved})
	assert_false(dto.is_empty())
	assert_eq(SaveSnapshot.authoritative_state(dto)["fleet"], saved)
	var disabled_fleet := FleetCoordinator.new(false)
	assert_false(disabled_fleet.register_fleet(fixture))
	assert_eq(disabled_fleet.fleet_count(), 0)
	var disabled_dock := DockAuthority.new(false)
	assert_false(disabled_dock.register_dock("dock.ai03.disabled", FoundationSector.ID, 1, Vector2.ZERO))
	var disabled_relations := FactionRelationResolver.new(false)
	assert_false(disabled_relations.set_relation("faction.ai03.alpha", "faction.ai03.beta", FactionRelationResolver.HOSTILE))
	print("AI03_PERSISTENCE_OK")


func test_ai03_24_ship_fixture_respects_formation_path_and_queue_budgets() -> void:
	var coordinator := FleetCoordinator.new(true)
	var fixtures: Array = []
	for i in 6:
		var fixture := Ai03ConvoyFixture.build(10 + i, FoundationSector.ID)
		fixtures.append(fixture)
		assert_true(coordinator.register_fleet(fixture))
	for tick in 80:
		assert_true(coordinator.begin_tick(tick))
		for i in fixtures.size():
			var fixture: Dictionary = fixtures[i]
			var leader_position := Vector2(-500 + i * 80 + tick * 2, -180 + i * 50)
			coordinator.formation_commands(fixture["fleet_id"], leader_position, 0.0, tick)
	assert_eq(coordinator.fleet_count(), 6)
	assert_eq(coordinator.member_count(), 24)
	assert_lte(int(coordinator.telemetry()["max_formation_updates_per_tick"]), FleetCoordinator.MAX_FORMATION_UPDATES_PER_TICK)
	assert_lte(int(coordinator.telemetry()["max_path_jobs_per_tick"]), FleetCoordinator.MAX_PATH_JOBS_PER_TICK)
	assert_gt(int(coordinator.telemetry()["path_requests"]), 0)
	assert_true(coordinator.set_threat(fixtures[0]["fleet_id"], true, false))
	assert_true(coordinator.set_threat(fixtures[0]["fleet_id"], false, false))
	assert_true(coordinator.mark_member_status(fixtures[1]["fleet_id"], fixtures[1]["leader_id"], false, false, FoundationSector.ID))
	var support := coordinator.dispatch_support(fixtures[2]["fleet_id"], "support.ai03.budget", fixtures[2]["leader_id"], "entity.ai03.budget.target", 90, 0)
	assert_gt(support.size(), 0)
	var dock := DockAuthority.new(true)
	assert_true(dock.register_dock("dock.ai03.budget", FoundationSector.ID, 2, Vector2.ZERO))
	for i in 24:
		assert_true(dock.request("dock.ai03.budget", "entity.ai03.queue.q%02d" % i, i))
	var metrics := coordinator.telemetry()
	print("AI03_FLEET_BUDGET_OK fleet_count=%d ship_count=%d formation_updates=%d max_formation_updates_per_tick=%d path_requests=%d max_path_jobs_per_tick=%d dock_queue_max=%d succession_count=%d break_reform_count=%d support_dispatch_count=%d bt_failures=0 bt_timeouts=0" % [
		coordinator.fleet_count(), coordinator.member_count(), int(metrics["formation_updates"]),
		int(metrics["max_formation_updates_per_tick"]), int(metrics["path_requests"]),
		int(metrics["max_path_jobs_per_tick"]), dock.queue_max_observed, int(metrics["succession_count"]),
		int(metrics["break_count"]) + int(metrics["regroup_count"]), int(metrics["support_handled"]),
	])


func _foundation_sector() -> SectorRuntime:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	return SectorRuntime.build(definition)


func _weapon() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.ai03.test"
	weapon.base_damage = 12.0
	weapon.min_range_meters = 40.0
	weapon.range_meters = 300.0
	weapon.reload_seconds = 2.0
	weapon.accuracy = 0.8
	weapon.crit_chance = 0.1
	weapon.crit_multiplier = 1.5
	weapon.broadside_half_arc_degrees = 40.0
	return weapon
