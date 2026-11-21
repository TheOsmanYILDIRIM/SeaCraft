extends GutTest


func test_ai04_lod_transition_preserves_identity_semantic_state_and_fleet_membership() -> void:
	var registry := ContentManifest.registry()
	var authority := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9401, true)
	var job := WorldJob.create("job.ai04.transition.trade", WorldJob.TRADE, "fleet.ai04.transition", "anchor.ai04.origin", "sector.safe_haven", FoundationSector.ID, WorldJob.TRAVEL)
	var source := _record("entity.ai04.transition", SimulationLOD.NEAR, FoundationSector.ID, 0, "faction.player", "fleet.ai04.transition", "merchant", 77.0, FoundationSector.HAVEN_ID, job)
	assert_true(authority.register_record(source))
	var original := authority.record(source["instance_id"])
	var tick := 0
	for _i in SimulationLOD.MIN_RESIDENCY_TICKS + 1:
		tick += 1
		authority.classify_entity(source["instance_id"], _lod_context(FoundationSector.ID, FoundationSector.OUTER_ID, 1, 0.0, 0.0, false), tick)
	assert_eq(FarFieldEntityState.semantic(authority.record(source["instance_id"]))["lod"], SimulationLOD.MID)
	for _i in SimulationLOD.MIN_RESIDENCY_TICKS + 1:
		tick += 1
		authority.classify_entity(source["instance_id"], _lod_context(FoundationSector.ID, FoundationSector.HAVEN_ID, 2, 0.0, 0.0, false), tick)
	assert_eq(FarFieldEntityState.semantic(authority.record(source["instance_id"]))["lod"], SimulationLOD.FAR)
	for _i in SimulationLOD.MIN_RESIDENCY_TICKS + 1:
		tick += 1
		authority.classify_entity(source["instance_id"], _lod_context(FoundationSector.ID, FoundationSector.OUTER_ID, 1, 25.0, 10.0, false), tick)
	assert_eq(FarFieldEntityState.semantic(authority.record(source["instance_id"]))["lod"], SimulationLOD.MID)
	for _i in SimulationLOD.MIN_RESIDENCY_TICKS + 1:
		tick += 1
		authority.classify_entity(source["instance_id"], _lod_context(FoundationSector.ID, FoundationSector.ID, 0, 80.0, 80.0, false), tick)
	var restored := authority.record(source["instance_id"])
	var semantic := FarFieldEntityState.semantic(restored)
	assert_eq(semantic["lod"], SimulationLOD.NEAR)
	assert_eq(restored["instance_id"], original["instance_id"])
	assert_eq(restored["definition_id"], original["definition_id"])
	assert_eq(float(restored["health"]), 77.0)
	assert_eq(semantic["fleet_id"], "fleet.ai04.transition")
	assert_eq(semantic["world_job"]["job_id"], job["job_id"])
	assert_eq(restored["cooldowns"], original["cooldowns"])
	assert_gte(int(authority.telemetry()["lod_transitions"]), 4)
	print("AI04_LOD_TRANSITION_OK")


func test_ai04_lod_hysteresis_and_minimum_residency_prevent_threshold_thrash() -> void:
	var near_context := _lod_context(FoundationSector.ID, FoundationSector.ID, 0, 50.0, 0.0, false)
	assert_eq(SimulationLOD.classify(near_context, SimulationLOD.NEAR), SimulationLOD.NEAR)
	assert_eq(SimulationLOD.classify(near_context, ""), SimulationLOD.MID)
	assert_eq(SimulationLOD.transition(SimulationLOD.NEAR, SimulationLOD.MID, SimulationLOD.MIN_RESIDENCY_TICKS - 1), SimulationLOD.NEAR)
	assert_eq(SimulationLOD.transition(SimulationLOD.NEAR, SimulationLOD.MID, SimulationLOD.MIN_RESIDENCY_TICKS), SimulationLOD.MID)
	var semantic := FarFieldEntityState.default_semantic(SimulationLOD.FAR, "faction.player")
	semantic["travel"]["speed_per_tick"] = INF
	assert_false(FarFieldEntityState.valid_semantic(semantic))
	for relevance in [41.0, 43.0, 40.0, 44.0, 42.0, 45.0]:
		var context := _lod_context(FoundationSector.ID, FoundationSector.ID, 0, relevance, 60.0, false)
		assert_eq(SimulationLOD.classify(context, SimulationLOD.NEAR), SimulationLOD.NEAR)
	print("AI04_LOD_HYSTERESIS_OK")


func test_ai04_mid_scheduler_is_sparse_bounded_and_authority_disabled_is_read_only() -> void:
	var scheduler := WorldWorkScheduler.new(true)
	for i in 20:
		assert_true(scheduler.enqueue("mid", "entity.ai04.mid.e%02d" % i, "goal.ai04.mid", 0))
	var first := scheduler.advance_tick(1)
	assert_eq(first["mid"].size(), WorldWorkScheduler.MAX_MID_UPDATES_PER_TICK)
	for tick in range(2, 6):
		var batch := scheduler.advance_tick(tick)
		assert_lte(batch["mid"].size(), WorldWorkScheduler.MAX_MID_UPDATES_PER_TICK)
	assert_eq(scheduler.pending_count(), 0)
	assert_lte(int(scheduler.telemetry()["max_mid_updates_per_tick"]), WorldWorkScheduler.MAX_MID_UPDATES_PER_TICK)
	var disabled := WorldWorkScheduler.new(false)
	assert_false(disabled.enqueue("mid", "entity.ai04.disabled", "goal.ai04.disabled", 0))
	assert_eq(disabled.advance_tick(1), {})
	assert_eq(disabled.pending_count(), 0)
	print("AI04_MID_SCHEDULER_OK")


func test_ai04_far_travel_uses_sector_graph_hazards_and_advances_world_jobs_without_physics() -> void:
	var registry := ContentManifest.registry()
	var authority_a := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9402, true)
	var authority_b := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9402, true)
	var job := WorldJob.create("job.ai04.travel.trade", WorldJob.TRADE, "fleet.ai04.travel", "anchor.ai04.origin", FoundationSector.HAVEN_ID, FoundationSector.ID, WorldJob.TRAVEL)
	var record_in := _record("entity.ai04.travel", SimulationLOD.FAR, FoundationSector.ID, 1, "faction.player", "fleet.ai04.travel", "merchant", 91.0, FoundationSector.HAVEN_ID, job)
	assert_true(authority_a.register_record(record_in))
	assert_true(authority_b.register_record(record_in))
	var hazards := {"hazard.storm_lane": {"cost": 1.0, "delay": 0.5, "risk": 0.25}}
	var route := FarTravelResolver.plan_route(FoundationSector.graph().presentation_snapshot(), FoundationSector.ID, FoundationSector.HAVEN_ID, hazards)
	assert_eq(route, [FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.HAVEN_ID])
	var a := authority_a.advance_entity(record_in["instance_id"], 200, hazards)
	var b := authority_b.advance_entity(record_in["instance_id"], 200, hazards)
	assert_eq(a, b)
	assert_true(bool(a["arrived"]))
	assert_eq(a["state"]["sector_id"], FoundationSector.HAVEN_ID)
	assert_true(bool(a["state"]["world_job"]["completed"]))
	var dock_job := WorldJob.create("job.ai04.travel.dock", WorldJob.DOCK, "fleet.ai04.dock", "anchor.ai04.origin", "dock.ai04.haven", FoundationSector.HAVEN_ID, WorldJob.QUEUE)
	var dock_record := _record("entity.ai04.dock", SimulationLOD.FAR, FoundationSector.HAVEN_ID, 2, "faction.player", "fleet.ai04.dock", "merchant", 100.0, "", dock_job)
	assert_true(authority_a.register_record(dock_record))
	assert_eq(authority_a.advance_entity(dock_record["instance_id"], 8)["state"]["world_job"]["phase"], WorldJob.SERVICE)
	assert_eq(authority_a.advance_entity(dock_record["instance_id"], 8)["state"]["world_job"]["phase"], WorldJob.COMPLETE)
	print("AI04_FAR_TRAVEL_OK")


func test_ai04_far_combat_replay_is_byte_equal_rng_isolated_and_reuses_fleet_succession() -> void:
	var registry := ContentManifest.registry()
	var a := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9403, true)
	var b := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9403, true)
	var fixture := Ai03ConvoyFixture.build(50, FoundationSector.ID)
	var coordinator := FleetCoordinator.new(true)
	assert_true(coordinator.register_fleet(fixture))
	assert_true(a.set_fleet_state(coordinator.snapshot_state()))
	assert_true(b.set_fleet_state(coordinator.snapshot_state()))
	for index in fixture["members"].size():
		var member: Dictionary = fixture["members"][index]
		var hull := 5.0 if member["member_id"] == fixture["leader_id"] else 100.0
		var friendly := _record(member["member_id"], SimulationLOD.FAR, FoundationSector.ID, 10 + index, "faction.player", fixture["fleet_id"], member["role"], hull, "", fixture["world_job"])
		var semantic := FarFieldEntityState.semantic(friendly)
		semantic["combat"]["strength"] = 10.0
		semantic["combat"]["hostile"] = true
		friendly = FarFieldEntityState.attach(friendly, semantic)
		assert_true(a.register_record(friendly))
		assert_true(b.register_record(friendly))
	var hostile := _record("entity.ai04.combat.hostile", SimulationLOD.FAR, FoundationSector.ID, 20, "faction.practice_hostile", "", "raider", 100.0, "", {})
	var hostile_semantic := FarFieldEntityState.semantic(hostile)
	hostile_semantic["combat"]["strength"] = 500.0
	hostile_semantic["combat"]["hostile"] = true
	hostile = FarFieldEntityState.attach(hostile, hostile_semantic)
	assert_true(a.register_record(hostile))
	assert_true(b.register_record(hostile))
	var participants: Array = []
	for member in fixture["members"]:
		participants.append(member["member_id"])
	participants.append(hostile["instance_id"])
	assert_true(a.queue_far_encounter("encounter.ai04.replay", participants, 4))
	assert_true(b.queue_far_encounter("encounter.ai04.replay", participants, 4))
	var near_rng := SeedStreams.new(9403)
	var rng_before := near_rng.snapshot_state()
	var result_a := a.process_far_encounters()
	var result_b := b.process_far_encounters()
	assert_eq(result_a, result_b)
	assert_eq(JSON.stringify(result_a), JSON.stringify(result_b))
	assert_eq(near_rng.snapshot_state(), rng_before)
	assert_true(result_a[0]["sunk_ids"].has(fixture["leader_id"]))
	assert_eq(a.fleet_state(), b.fleet_state())
	assert_ne(a.fleet_state()["fleets"][0]["leader_id"], fixture["leader_id"])
	assert_eq(a.fleet_state()["fleets"][0]["fleet_id"], fixture["fleet_id"])
	print("AI04_FAR_COMBAT_REPLAY_OK")


func test_ai04_path_queue_is_bounded_coalesced_deterministic_and_starvation_free() -> void:
	var scheduler := WorldWorkScheduler.new(true)
	for i in 40:
		assert_true(scheduler.enqueue("path", "entity.ai04.path.e%02d" % i, "goal.ai04.path.a", 0))
	assert_true(scheduler.enqueue("path", "entity.ai04.path.e00", "goal.ai04.path.b", 0))
	assert_eq(scheduler.pending_count(), 40)
	var processed: Array = []
	for tick in range(1, 12):
		var batch: Array = scheduler.advance_tick(tick)["path"]
		assert_lte(batch.size(), WorldWorkScheduler.MAX_PATH_JOBS_PER_TICK)
		processed.append_array(batch)
	assert_eq(processed.size(), 40)
	assert_eq(scheduler.pending_count(), 0)
	assert_eq(int(scheduler.telemetry()["starvation_count"]), 0)
	assert_eq(processed[0]["stable_id"], "entity.ai04.path.e00")
	assert_eq(processed[0]["goal_id"], "goal.ai04.path.b")
	print("AI04_PATH_BUDGET_OK")


func test_ai04_population_cap_spawn_ids_content_validation_and_retry_idempotency() -> void:
	var registry := ContentManifest.registry()
	var director := WorldSpawnDirector.new(registry, true)
	var first := director.request_spawn("spawn.ai04.logical.first", FoundationSector.ID, "ship.vs02_practice", "faction.player", "merchant", SimulationLOD.FAR, 1)
	assert_true(bool(first["accepted"]))
	var retry := director.request_spawn("spawn.ai04.logical.first", FoundationSector.ID, "ship.vs02_practice", "faction.player", "merchant", SimulationLOD.FAR, 2)
	assert_eq(retry, first)
	assert_eq(director.population_count(), 1)
	var sectors := [FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.HAVEN_ID]
	for i in range(1, WorldSpawnDirector.MAX_TOTAL_PERSISTENT_WORLD_ENTITIES):
		var role := "merchant" if i % 2 == 0 else "escort"
		var lod := SimulationLOD.NEAR if i <= WorldSpawnDirector.MAX_NEAR_ENTITIES else SimulationLOD.FAR
		assert_true(director.register_existing("entity.ai04.population.e%03d" % i, "ship.vs02_practice", sectors[i % sectors.size()], "faction.player", role, lod))
	assert_eq(director.population_count(), WorldSpawnDirector.MAX_TOTAL_PERSISTENT_WORLD_ENTITIES)
	var sequence_before := int(director.telemetry()["director_sequence"])
	var rejected := director.request_spawn("spawn.ai04.logical.overcap", FoundationSector.ID, "ship.vs02_practice", "faction.player", "merchant", SimulationLOD.FAR, 3)
	assert_false(bool(rejected["accepted"]))
	assert_eq(rejected["reason"], "population_cap")
	assert_eq(rejected["instance_id"], "")
	assert_eq(int(director.telemetry()["director_sequence"]), sequence_before)
	var unknown := WorldSpawnDirector.new(registry, true).request_spawn("spawn.ai04.logical.unknown", FoundationSector.ID, "ship.unknown", "faction.player", "merchant", SimulationLOD.FAR, 1)
	assert_eq(unknown["reason"], "unknown_content")
	var restored := WorldSpawnDirector.new(registry, true)
	assert_true(restored.restore_state(director.snapshot_state()))
	assert_eq(restored.population_count(), WorldSpawnDirector.MAX_TOTAL_PERSISTENT_WORLD_ENTITIES)
	assert_ne(WorldSpawnDirector.region_profile("low"), WorldSpawnDirector.region_profile("high"))
	print("AI04_POPULATION_CAP_OK")


func test_ai04_admiral_threshold_is_exact_idempotent_cooldown_bounded_and_persistent() -> void:
	var registry := ContentManifest.registry()
	var director := WorldSpawnDirector.new(registry, true)
	var region := "region.ai04.outer"
	for i in 2:
		var result := director.record_admiral_event(region, "event.ai04.admiral.e%d" % i, FoundationSector.OUTER_ID, "ship.vs02_practice", 10 + i, 3, 100)
		assert_true(result["spawn_request"].is_empty())
	var threshold := director.record_admiral_event(region, "event.ai04.admiral.e2", FoundationSector.OUTER_ID, "ship.vs02_practice", 12, 3, 100)
	assert_true(bool(threshold["spawn_request"]["accepted"]))
	assert_eq(director.population_count(), 1)
	var duplicate := director.record_admiral_event(region, "event.ai04.admiral.e2", FoundationSector.OUTER_ID, "ship.vs02_practice", 13, 3, 100)
	assert_eq(duplicate["reason"], "duplicate_event")
	assert_eq(director.population_count(), 1)
	var cooldown := director.record_admiral_event(region, "event.ai04.admiral.e3", FoundationSector.OUTER_ID, "ship.vs02_practice", 20, 3, 100)
	assert_true(cooldown["spawn_request"].is_empty())
	var restored := WorldSpawnDirector.new(registry, true)
	assert_true(restored.restore_state(director.snapshot_state()))
	assert_eq(restored.snapshot_state(), director.snapshot_state())
	assert_eq(restored.population_count(), 1)
	print("AI04_ADMIRAL_COUNTER_OK")


func test_ai04_persistence_roundtrip_continuation_is_deterministic_and_restore_is_atomic() -> void:
	var registry := ContentManifest.registry()
	var original := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9404, true)
	var continuous := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9404, true)
	for i in 3:
		var row := _record("entity.ai04.persist.e%d" % i, SimulationLOD.FAR, FoundationSector.ID, 30 + i, "faction.player", "", "merchant", 80.0 + i, FoundationSector.HAVEN_ID, {})
		assert_true(original.register_record(row))
		assert_true(continuous.register_record(row))
	for instance_id in ["entity.ai04.persist.e0", "entity.ai04.persist.e1", "entity.ai04.persist.e2"]:
		original.advance_entity(instance_id, 40, _hazards())
		continuous.advance_entity(instance_id, 80, _hazards())
	var saved := original.snapshot_state()
	assert_eq(WorldSimulationAuthority.validate_snapshot(saved, registry), "")
	var encoded := JSON.stringify(saved)
	var json := JSON.new()
	assert_eq(json.parse(encoded), OK)
	var restored := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 1, true)
	assert_true(restored.restore_state(json.data))
	for instance_id in ["entity.ai04.persist.e0", "entity.ai04.persist.e1", "entity.ai04.persist.e2"]:
		restored.advance_entity(instance_id, 40, _hazards())
		assert_eq(restored.record(instance_id), continuous.record(instance_id))
	var invalid := restored.snapshot_state()
	invalid["entity_index"]["records"][0]["definition_id"] = "ship.missing"
	var before := restored.record("entity.ai04.persist.e0")
	assert_false(restored.restore_state(invalid))
	assert_eq(restored.record("entity.ai04.persist.e0"), before)
	var sector := _foundation_sector()
	var ship := ShipMotor.new()
	add_child_autofree(ship)
	ship.set_physics_process(false)
	assert_true(sector.register_entity("entity.ai04.persist.player", Vector2(-500, 0)))
	ship.global_position = Vector2(-500, 0)
	var dto := SaveSnapshot.capture(sector, "entity.ai04.persist.player", ship, SeedStreams.new(9404), SaveSnapshot.LOCAL, "", SaveSnapshot.empty_loot_state(), {"ai04_world": restored.snapshot_state()})
	assert_eq(SaveSnapshot.validate(dto), "")
	var disabled := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9404, false)
	assert_false(disabled.register_record(_record("entity.ai04.disabled", SimulationLOD.FAR, FoundationSector.ID, 99, "faction.player", "", "merchant", 100.0, "", {})))
	assert_eq(disabled.entity_count(), 0)
	assert_false(disabled.restore_state(saved))
	print("AI04_PERSISTENCE_OK")


func test_ai04_100_entity_long_simulated_time_soak_respects_all_work_and_population_bounds() -> void:
	var registry := ContentManifest.registry()
	var authority := WorldSimulationAuthority.new(registry, FoundationSector.graph(), 9405, true)
	var scheduler := WorldWorkScheduler.new(true)
	var sectors := [FoundationSector.ID, FoundationSector.OUTER_ID, FoundationSector.HAVEN_ID]
	for i in 100:
		var lod := SimulationLOD.FAR
		if i < 20:
			lod = SimulationLOD.NEAR
		elif i < 50:
			lod = SimulationLOD.MID
		var sector_id: String = sectors[i % sectors.size()]
		var destination := FoundationSector.HAVEN_ID if sector_id != FoundationSector.HAVEN_ID else FoundationSector.ID
		assert_true(authority.register_record(_record("entity.ai04.soak.e%03d" % i, lod, sector_id, 100 + i, "faction.player", "", "merchant", 100.0, destination, {})))
		assert_true(scheduler.enqueue(lod, "entity.ai04.soak.e%03d" % i, destination, 0))
		if i < 20:
			assert_true(scheduler.enqueue("path", "entity.ai04.soak.e%03d" % i, destination, 0))
		if i < 12:
			assert_true(scheduler.enqueue("spawn", "spawn.ai04.soak.e%03d" % i, sector_id, 0))
	for tick in range(1, 40):
		scheduler.advance_tick(tick)
	assert_eq(scheduler.pending_count(), 0)
	for tick in range(1, 1441):
		if tick % WorldSimulationAuthority.MID_INTERVAL_TICKS == 0:
			for i in range(20, 50):
				authority.advance_entity("entity.ai04.soak.e%03d" % i, WorldSimulationAuthority.MID_INTERVAL_TICKS)
		if tick % WorldSimulationAuthority.FAR_INTERVAL_TICKS == 0:
			for i in range(50, 100):
				authority.advance_entity("entity.ai04.soak.e%03d" % i, WorldSimulationAuthority.FAR_INTERVAL_TICKS, _hazards())
	assert_eq(authority.entity_count(), 100)
	var ids: Dictionary = {}
	for row in authority.snapshot_state()["entity_index"]["records"]:
		assert_false(ids.has(row["instance_id"]))
		ids[row["instance_id"]] = true
	assert_eq(ids.size(), 100)
	var metrics := authority.telemetry()
	var work := scheduler.telemetry()
	assert_eq(int(metrics["near_count"]), 20)
	assert_eq(int(metrics["mid_count"]), 30)
	assert_eq(int(metrics["far_count"]), 50)
	assert_lte(int(work["max_near_decisions_per_tick"]), WorldWorkScheduler.MAX_NEAR_DECISIONS_PER_TICK)
	assert_lte(int(work["max_mid_updates_per_tick"]), WorldWorkScheduler.MAX_MID_UPDATES_PER_TICK)
	assert_lte(int(work["max_far_updates_per_tick"]), WorldWorkScheduler.MAX_FAR_UPDATES_PER_TICK)
	assert_lte(int(work["max_path_jobs_per_tick"]), WorldWorkScheduler.MAX_PATH_JOBS_PER_TICK)
	assert_lte(int(work["max_spawn_jobs_per_tick"]), WorldWorkScheduler.MAX_SPAWN_JOBS_PER_TICK)
	assert_eq(int(work["starvation_count"]), 0)
	assert_eq(int(metrics["spawn"]["population_peak"]), 100)
	print("AI04_LONG_SOAK_OK world_entities=100 near_count=20 mid_count=30 far_count=50 max_near_decisions_per_tick=%d max_mid_updates_per_tick=%d max_far_updates_per_tick=%d max_path_jobs_per_tick=%d max_spawn_jobs_per_tick=%d max_pending_jobs=%d lod_transitions=%d far_encounters_resolved=%d spawn_accepted=%d spawn_rejected=%d population_peak=%d starvation_count=%d simulated_ticks=1440 duplicate_ids=0 id_loss=0 ledger_size=%d" % [
		int(work["max_near_decisions_per_tick"]), int(work["max_mid_updates_per_tick"]), int(work["max_far_updates_per_tick"]), int(work["max_path_jobs_per_tick"]), int(work["max_spawn_jobs_per_tick"]), int(work["max_pending_jobs"]), int(metrics["lod_transitions"]), int(metrics["far_encounters_resolved"]), int(metrics["spawn"]["spawn_accepted"]), int(metrics["spawn"]["spawn_rejected"]), int(metrics["spawn"]["population_peak"]), int(work["starvation_count"]), int(metrics["spawn"]["logical_spawn_ledger"]),
	])


func _record(instance_id: String, lod: String, sector_id: String, index: int, faction_id: String,
		fleet_id: String, role: String, health: float, destination_id: String, job: Dictionary) -> Dictionary:
	var base := {
		"instance_id": instance_id,
		"definition_id": "ship.vs02_practice",
		"entity_kind": "npc_ship",
		"sector_id": sector_id,
		"position": {"x": float(index), "y": float(-index)},
		"motion": {"heading": 0.25, "vx": 1.0, "vy": -1.0},
		"health": health,
		"alive": true,
		"route": {"patrol_index": index % 4, "intent_id": 0},
		"cooldowns": {"reload": index + 10, "repair": index + 20},
		"inventory": {"item.vs03_salvage_scrap": index % 3},
		"payload": {"content_refs": ["ammo.core_round"]},
	}
	var semantic := FarFieldEntityState.default_semantic(lod, faction_id, fleet_id, role, job, destination_id, 0.02, "low")
	return FarFieldEntityState.attach(base, semantic)


func _lod_context(active_sector: String, entity_sector: String, distance: int, relevance: float, importance: float, combat: bool) -> Dictionary:
	return {
		"active_sector": active_sector,
		"entity_sector": entity_sector,
		"graph_distance": distance,
		"same_sector": active_sector == entity_sector,
		"neighbor_sector": distance == 1,
		"explicit_relevance": relevance,
		"combat_involvement": combat,
		"importance": importance,
	}


func _hazards() -> Dictionary:
	return {"hazard.storm_lane": {"cost": 1.0, "delay": 0.5, "risk": 0.2}}


func _foundation_sector() -> SectorRuntime:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	return SectorRuntime.build(definition)
