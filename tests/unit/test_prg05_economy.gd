extends GutTest
const P := "entity.player"
const Q := "entity.other"
const F := "faction.harbor"
const E := "faction.pirates"
const M := "market.harbor"
const I := "item.scrap"
const O := "outpost.harbor"

func _make() -> InventoryState:
	var state := InventoryState.new()
	assert_true(state.bind_owner(P, 12, 1000.0))
	assert_true(state.bind_owner(Q, 12, 1000.0))
	assert_true(state.register_item_spec(I, "material", 100, "", 1.0))
	assert_true(state.configure_prg05())
	assert_true(state.register_economy_faction(F))
	assert_true(state.register_economy_faction(E))
	assert_true(state.register_economy_market(M, F, I, "sector.harbor", 10, 8, 20))
	assert_true(state.register_economy_outpost(O, F))
	return state

func test_prg05_faction_reputation_and_hostility() -> void:
	var s := _make()
	assert_true(s.set_economy_faction_relation(F, E, FactionRelationResolver.HOSTILE))
	assert_eq(s.economy_faction_relation(F, E), FactionRelationResolver.HOSTILE)
	var r := s.adjust_economy_reputation_authoritative(P, F, "event.rep", -300)
	assert_true(r["accepted"])
	assert_eq(r, s.adjust_economy_reputation_authoritative(P, F, "event.rep", -300))
	assert_eq(s.adjust_economy_reputation_authoritative(P, F, "event.rep", -50)["reason"], "event_conflict")
	assert_eq(s.execute_transaction(P, "txn.hostile", InventoryState.OP_MARKET_BUY, {"market_id": M, "quantity": 1})["reason"], "hostile_market")
	print("PRG05_FACTION_REPUTATION_OK")

func test_prg05_market_atomic_trade_price_and_lost_ack() -> void:
	var s := _make()
	assert_true(s.grant_economy_currency_authoritative(P, "event.credit", 300)["accepted"])
	var payload := {"market_id": M, "quantity": 2}
	var first := s.execute_transaction(P, "txn.buy", InventoryState.OP_MARKET_BUY, payload)
	assert_true(first["accepted"])
	assert_eq(s.quantity(P, I), 2)
	assert_eq(first, s.execute_transaction(P, "txn.buy", InventoryState.OP_MARKET_BUY, payload))
	assert_eq(s.execute_transaction(P, "txn.buy", InventoryState.OP_MARKET_BUY, {"market_id": M, "quantity": 3})["reason"], "transaction_conflict")
	assert_eq(s.quantity(P, I), 2)
	assert_true(s.execute_transaction(P, "txn.sell", InventoryState.OP_MARKET_SELL, {"market_id": M, "quantity": 1})["accepted"])
	assert_eq(s.quantity(P, I), 1)
	print("PRG05_TRADE_ATOMIC_OK")

func test_prg05_convoy_outpost_pvp_diminishing_and_events() -> void:
	var s := _make()
	var before := s.economy_quote(P, M)
	var r := s.record_economy_convoy_loss_authoritative("event.convoy", M, 4)
	assert_true(r["accepted"])
	assert_eq(r, s.record_economy_convoy_loss_authoritative("event.convoy", M, 4))
	assert_eq(s.economy_quote(P, M)["stock"], 4)
	assert_true(s.economy_quote(P, M)["buy"] > before["buy"])
	assert_true(s.capture_economy_outpost_authoritative("event.outpost", O, E)["accepted"])
	assert_eq(s.economy_outpost_owner(O), E)
	var a := s.record_economy_pvp_kill_authoritative("event.pvp.a", P, Q, 100)
	var b := s.record_economy_pvp_kill_authoritative("event.pvp.b", P, Q, 100)
	assert_eq(a["reward"], 100)
	assert_eq(b["reward"], 50)
	assert_eq(a, s.record_economy_pvp_kill_authoritative("event.pvp.a", P, Q, 100))
	print("PRG05_CONVOY_OUTPOST_PVP_OK")

func test_prg05_persistence_v5_migration_and_invalid_rejection() -> void:
	var s := _make()
	assert_true(s.grant_economy_currency_authoritative(P, "event.save", 100)["accepted"])
	var state := s.progression_snapshot()
	assert_eq(state["version"], InventoryState.VERSION)
	assert_true(Prg05EconomyState.validate_state(state["prg05"]))
	var json_roundtrip: Variant = JSON.parse_string(JSON.stringify(state))
	assert_true(InventoryState.validate_progression_state(json_roundtrip))
	assert_true(Prg05EconomyState.validate_state(json_roundtrip["prg05"]))
	var restored := _make()
	assert_true(restored.restore_progression(state))
	assert_eq(restored.progression_snapshot(), state)
	var old := state.duplicate(true)
	old.erase("prg05")
	old["version"] = 4
	var migrated := _make()
	assert_true(migrated.restore_progression(old))
	assert_eq(migrated.economy_balance(P), 0)
	var invalid := state.duplicate(true)
	invalid["prg05"]["markets"][M]["stock"] = -1
	assert_false(restored.restore_progression(invalid))
	print("PRG05_PERSISTENCE_V5_OK")

func test_prg05_reputation_controls_runtime_combat_hostility() -> void:
	var s := _make()
	var sector := SectorRuntime.new()
	sector.bounds = Rect2(-640, -360, 1280, 720)
	assert_true(sector.register_entity(P, Vector2.ZERO))
	assert_true(sector.register_entity(Q, Vector2(0, 100)))
	var combat := CombatAuthority.new(sector, SeedStreams.new(42))
	assert_true(combat.register(P, "faction.player", 100.0))
	assert_true(combat.register(Q, F, 100.0))
	var base_relations := FactionRelationResolver.new()
	assert_true(base_relations.set_relation("faction.player", F, FactionRelationResolver.HOSTILE))
	assert_true(combat.bind_relation_resolver(base_relations))
	assert_true(combat.bind_economy_authority(s))
	assert_eq(combat.relation(P, Q), FactionRelationResolver.HOSTILE)
	# A non-opted-in NPC inventory owner cannot masquerade as the player.
	assert_eq(s.economy_actor_disposition(Q, F), FactionRelationResolver.NEUTRAL)
	assert_true(s.enable_economy_diplomacy(P))
	assert_true(s.adjust_economy_reputation_authoritative(P, F, "event.diplomacy.friendly", 300)["accepted"])
	assert_eq(combat.relation(P, Q), FactionRelationResolver.FRIENDLY)
	assert_eq(combat.relation(Q, P), FactionRelationResolver.FRIENDLY)
	assert_false(combat.hostile(Q, P))
	assert_true(s.adjust_economy_reputation_authoritative(P, F, "event.diplomacy.hostile", -600)["accepted"])
	assert_eq(combat.relation(P, Q), FactionRelationResolver.HOSTILE)
	assert_true(combat.hostile(Q, P))
	print("PRG05_RUNTIME_DIPLOMACY_OK")

func test_prg05_lan_host_intent_limits_price_and_identity_spoof() -> void:
	var envelope := SessionProtocol.make_envelope(1, InventoryState.OP_MARKET_BUY,
		{"transaction_id": "txn.market.lan", "market_id": M, "quantity": 1})
	assert_eq(SessionProtocol.validate_envelope(envelope), "")
	var injected := envelope.duplicate(true)
	injected["payload"]["price"] = 1
	assert_eq(SessionProtocol.validate_envelope(injected), SessionProtocol.REJECT_MALFORMED_PAYLOAD)
	var spoof := envelope.duplicate(true)
	spoof["payload"]["owner_id"] = Q
	assert_eq(SessionProtocol.validate_envelope(spoof), SessionProtocol.REJECT_FORBIDDEN_IDENTITY)
	print("PRG05_LAN_HOST_GUARD_OK")

func test_prg05_ai03_world_convoy_outcome_to_live_market_is_authoritative_and_persistent() -> void:
	var s := _make()
	var fleets := FleetCoordinator.new(true)
	var lost := Ai03ConvoyFixture.build(7, "sector.harbor")
	lost["world_job"]["cargo_mission"]["cargo_definition_id"] = I
	lost["world_job"]["cargo_mission"]["quantity"] = 4
	assert_true(fleets.register_fleet(lost))
	var bridge := Prg05ConvoyBridge.new(s, fleets, true)
	assert_false(bridge.bind_convoy(lost["fleet_id"], "market.unknown"))
	assert_true(bridge.bind_convoy(lost["fleet_id"], M))
	assert_true(bridge.bind_convoy(lost["fleet_id"], M))
	assert_eq(bridge.settle(lost["fleet_id"], 10)["reason"], "convoy_in_transit")
	assert_false(Prg05ConvoyBridge.new(s, fleets, false).bind_convoy(lost["fleet_id"], M))
	var before := s.economy_quote(P, M)
	assert_true(fleets.mark_member_status(lost["fleet_id"], lost["leader_id"], false, false, "sector.harbor"))
	var first := bridge.settle(lost["fleet_id"], 11)
	assert_true(first["accepted"])
	assert_eq(first["event"]["event_type"], "convoy_lost")
	assert_eq(s.economy_quote(P, M)["stock"], 4)
	assert_gt(int(s.economy_quote(P, M)["buy"]), int(before["buy"]))
	assert_eq(bridge.settle(lost["fleet_id"], 12)["stock"], 4)
	var saved := s.progression_snapshot()
	var restored := _make()
	assert_true(restored.restore_progression(saved))
	var resumed_fleet := FleetCoordinator.new(true)
	assert_true(resumed_fleet.restore_state(fleets.snapshot_state()))
	var resumed_bridge := Prg05ConvoyBridge.new(restored, resumed_fleet, true)
	assert_true(resumed_bridge.bind_convoy(lost["fleet_id"], M))
	assert_eq(resumed_bridge.settle(lost["fleet_id"], 13)["stock"], 4)
	assert_eq(restored.economy_quote(P, M)["stock"], 4)
	var delivered := Ai03ConvoyFixture.build(8, "sector.harbor")
	delivered["world_job"]["cargo_mission"]["cargo_definition_id"] = I
	delivered["world_job"]["cargo_mission"]["quantity"] = 6
	assert_true(resumed_fleet.register_fleet(delivered))
	assert_true(resumed_bridge.bind_convoy(delivered["fleet_id"], M))
	assert_true(resumed_fleet.advance_world_job(delivered["fleet_id"], WorldJob.COMPLETE, 1.0))
	var receipt := resumed_bridge.settle(delivered["fleet_id"], 14)
	assert_true(receipt["accepted"])
	assert_eq(receipt["event"]["event_type"], "trade_delivered")
	assert_eq(receipt["delivered"], 6)
	assert_eq(restored.economy_quote(P, M)["stock"], 10)
	assert_eq(resumed_bridge.settle(delivered["fleet_id"], 15)["stock"], 10)
	assert_true(Prg05EconomyState.validate_state(restored.progression_snapshot()["prg05"]))
	print("PRG05_CONVOY_WORLD_BRIDGE_OK")

func test_prg05_ai04_far_world_arrival_and_sinking_settle_economy_once() -> void:
	var market := "market.ai04.haven"
	var s := _make()
	assert_true(s.register_economy_market(market, F, I, FoundationSector.HAVEN_ID, 10, 8, 20))
	var world := WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(), 9402, true)
	var fleet_id := "fleet.prg05.far.deliver"
	var merchant_id := "entity.prg05.far.deliver"
	var job := _far_job(fleet_id, "job.prg05.far.deliver", 4)
	assert_true(world.register_record(_far_ship(merchant_id, fleet_id, job, 100.0)))
	var bridge := Prg05ConvoyBridge.new(s, FleetCoordinator.new(true), true)
	assert_true(bridge.bind_far_convoy(world, merchant_id, market))
	assert_false(bridge.bind_far_convoy(world, merchant_id, M))
	assert_eq(bridge.settle_far_convoy(world, merchant_id, 1)["reason"], "convoy_in_transit")
	assert_false(Prg05ConvoyBridge.new(s, FleetCoordinator.new(true), false).bind_far_convoy(world, merchant_id, market))
	var traveled := world.advance_entity(merchant_id, 200)
	assert_true(traveled["arrived"])
	var delivered := bridge.settle_far_convoy(world, merchant_id, 200)
	assert_true(delivered["accepted"])
	assert_eq(delivered["event"]["event_type"], "trade_delivered")
	assert_eq(delivered["delivered"], 4)
	assert_eq(s.economy_quote(P, market)["stock"], 12)
	assert_eq(bridge.settle_far_convoy(world, merchant_id, 201)["stock"], 12)
	var snapshot := s.progression_snapshot()
	var restored := _make()
	assert_true(restored.register_economy_market(market, F, I, FoundationSector.HAVEN_ID, 10, 8, 20))
	assert_true(restored.restore_progression(snapshot))
	var world_restored := WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(), 9402, true)
	assert_true(world_restored.restore_state(world.snapshot_state()))
	var replay := Prg05ConvoyBridge.new(restored, FleetCoordinator.new(true), true)
	assert_true(replay.bind_far_convoy(world_restored, merchant_id, market))
	assert_eq(replay.settle_far_convoy(world_restored, merchant_id, 202)["stock"], 12)
	var attacker_id := "entity.prg05.far.raider"
	var victim_id := "entity.prg05.far.lost"
	var lost_job := _far_job("fleet.prg05.far.lost", "job.prg05.far.lost", 5)
	var victim := _far_ship(victim_id, "fleet.prg05.far.lost", lost_job, 5.0)
	var raider := _far_ship(attacker_id, "", {}, 100.0)
	var raider_semantic := FarFieldEntityState.semantic(raider)
	raider_semantic["faction_id"] = "faction.practice_hostile"
	raider_semantic["role"] = "raider"
	raider_semantic["combat"]["strength"] = 500.0
	raider_semantic["combat"]["hostile"] = true
	raider = FarFieldEntityState.attach(raider, raider_semantic)
	assert_true(world_restored.register_record(victim))
	assert_true(world_restored.register_record(raider))
	assert_true(replay.bind_far_convoy(world_restored, victim_id, market))
	assert_true(world_restored.queue_far_encounter("encounter.prg05.far.loss", [victim_id, attacker_id], 4))
	var combat_results := world_restored.process_far_encounters()
	assert_eq(combat_results.size(), 1)
	assert_true(combat_results[0]["sunk_ids"].has(victim_id))
	var lost := replay.settle_far_convoy(world_restored, victim_id, 203)
	assert_true(lost["accepted"])
	assert_eq(lost["event"]["event_type"], "convoy_lost")
	assert_eq(restored.economy_quote(P, market)["stock"], 7)
	assert_eq(replay.settle_far_convoy(world_restored, victim_id, 204)["stock"], 7)
	assert_true(Prg05EconomyState.validate_state(restored.progression_snapshot()["prg05"]))
	print("PRG05_FAR_WORLD_BRIDGE_OK")


func test_prg05_ai04_scheduler_dispatches_trade_once_and_restores_ledger() -> void:
	var s := _make()
	var market := "market.scheduler.deliver"
	assert_true(s.register_economy_market(market, F, I, FoundationSector.HAVEN_ID, 10, 8, 20))
	var world := WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(), 9402, true)
	var merchant := "entity.scheduler.merchant"
	var fleet := "fleet.scheduler.merchant"
	assert_true(world.register_record(_far_ship(merchant, fleet, _far_job(fleet, "job.scheduler.merchant", 4), 100.0)))
	var bridge := Prg05ConvoyBridge.new(s, FleetCoordinator.new(true), true)
	var runner := Prg05EconomyWorldRunner.new(world, s, bridge, true)
	assert_false(Prg05EconomyWorldRunner.new(world, s, bridge, false).bind_far_convoy(merchant, market))
	assert_true(runner.bind_far_convoy(merchant, market))
	assert_true(runner.bind_far_convoy(merchant, market))
	assert_false(runner.bind_far_convoy(merchant, M))
	var batch := runner.advance_tick(200)
	assert_eq(batch["advanced"], [merchant])
	assert_eq(batch["settlements"].size(), 1)
	assert_eq(batch["settlements"][0]["result"]["event"]["event_type"], "trade_delivered")
	assert_eq(s.economy_quote(P, market)["stock"], 12)
	assert_true(runner.is_settled(merchant))
	assert_true(runner.advance_tick(200).is_empty())
	assert_eq(runner.advance_tick(208)["settlements"].size(), 0)
	var saved := s.progression_snapshot()
	var world_snapshot := world.snapshot_state()
	var restored := _make()
	assert_true(restored.register_economy_market(market, F, I, FoundationSector.HAVEN_ID, 10, 8, 20))
	assert_true(restored.restore_progression(saved))
	var new_world := WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(), 9402, true)
	assert_true(new_world.restore_state(world_snapshot))
	var resumed := Prg05EconomyWorldRunner.new(new_world, restored,
		Prg05ConvoyBridge.new(restored, FleetCoordinator.new(true), true), true)
	assert_true(resumed.bind_far_convoy(merchant, market, 208))
	assert_true(resumed.is_settled(merchant))
	assert_eq(resumed.advance_tick(216)["settlements"].size(), 0)
	assert_eq(restored.economy_quote(P, market)["stock"], 12)
	print("PRG05_AI04_SCHEDULER_DELIVERY_OK")


func test_prg05_ai04_scheduler_combat_loss_precedes_market_delivery() -> void:
	var s := _make()
	var market := "market.scheduler.loss"
	assert_true(s.register_economy_market(market, F, I, FoundationSector.HAVEN_ID, 10, 8, 20))
	var world := WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(), 9402, true)
	var merchant := "entity.scheduler.loss"
	var raider_id := "entity.scheduler.raider"
	var fleet := "fleet.scheduler.loss"
	assert_true(world.register_record(_far_ship(merchant, fleet, _far_job(fleet, "job.scheduler.loss", 5), 5.0)))
	var raider := _far_ship(raider_id, "", {}, 100.0)
	var semantic := FarFieldEntityState.semantic(raider)
	semantic["faction_id"] = "faction.practice_hostile"
	semantic["role"] = "raider"
	semantic["combat"]["strength"] = 500.0
	semantic["combat"]["hostile"] = true
	assert_true(world.register_record(FarFieldEntityState.attach(raider, semantic)))
	var runner := Prg05EconomyWorldRunner.new(world, s,
		Prg05ConvoyBridge.new(s, FleetCoordinator.new(true), true), true)
	assert_true(runner.bind_far_convoy(merchant, market))
	assert_true(world.queue_far_encounter("encounter.scheduler.loss", [merchant, raider_id], 4))
	var batch := runner.advance_tick(8)
	assert_eq(batch["encounters"].size(), 1)
	assert_true(batch["encounters"][0]["sunk_ids"].has(merchant))
	assert_eq(batch["settlements"].size(), 1)
	assert_eq(batch["settlements"][0]["result"]["event"]["event_type"], "convoy_lost")
	assert_eq(s.economy_quote(P, market)["stock"], 3)
	assert_eq(runner.advance_tick(16)["settlements"].size(), 0)
	assert_eq(s.economy_quote(P, market)["stock"], 3)
	print("PRG05_AI04_SCHEDULER_LOSS_OK")


func test_prg05_lan_market_sector_range_and_authoritative_position_gate() -> void:
	var s := _make()
	var harbor := SectorRuntime.new()
	harbor.sector_id = "sector.harbor"
	harbor.bounds = Rect2(-600, -300, 1200, 600)
	assert_true(harbor.register_entity(P, Vector2(0, 0)))
	var motor := ShipMotor.new()
	motor.global_position = Vector2(0, 0)
	var gate := Prg05MarketAccessGuard.new(s)
	assert_true(gate.is_bound_to(s))
	assert_false(Prg05MarketAccessGuard.new(_make()).is_bound_to(s))
	assert_false(gate.bind_market(M, harbor, Vector2(0, 0), INF))
	assert_false(gate.bind_market(M, harbor, Vector2(0, 0), 0.0))
	assert_true(gate.bind_market(M, harbor, Vector2(40, 0), 100.0))
	assert_false(gate.bind_market(M, harbor, Vector2(40, 0), 100.0))
	assert_true(gate.allows(P, M, motor))
	assert_false(gate.allows(Q, M, motor))
	assert_false(gate.allows(P, "market.nonexistent", motor))
	motor.global_position = Vector2(300, 0)
	assert_false(gate.allows(P, M, motor))
	motor.global_position = Vector2(0, 0)
	assert_true(harbor.move_entity(P, Vector2(300, 0)))
	assert_false(gate.allows(P, M, motor))
	assert_true(harbor.move_entity(P, Vector2(0, 0)))
	assert_true(gate.allows(P, M, motor))
	motor.authority_enabled = false
	assert_false(gate.allows(P, M, motor))
	motor.free()
	var wrong_sector := SectorRuntime.new()
	wrong_sector.sector_id = "sector.elsewhere"
	wrong_sector.bounds = harbor.bounds
	assert_false(Prg05MarketAccessGuard.new(s).bind_market(M, wrong_sector, Vector2.ZERO))
	# Real SessionHost also fails closed before binding, no bypass via client payload.
	var host := SessionHost.new()
	assert_eq(host.call("_execute_gameplay_intent", 1, P, InventoryState.OP_MARKET_BUY,
		{"transaction_id": "txn.market.host", "market_id": M, "quantity": 1}),
		SessionProtocol.REJECT_AUTHORITY_COMMAND)
	host.free()
	print("PRG05_LAN_MARKET_ACCESS_GUARD_OK")


func test_prg05_bounty_combat_proof_reward_and_intel_save_resume() -> void:
	var s := _make()
	var bounty := "bounty.prg05.raider"
	assert_true(s.register_economy_bounty(bounty, F, Q, 80))
	assert_false(s.register_economy_bounty(bounty, F, Q, 80))
	assert_eq(s.economy_bounty_contract(bounty)["reward"], 80)
	assert_eq(s.economy_bounty_board(P, 0)[0]["claimed"], false)
	var sector := SectorRuntime.new()
	sector.sector_id = "sector.harbor"
	sector.bounds = Rect2(-640, -360, 1280, 720)
	assert_true(sector.register_entity(P, Vector2.ZERO))
	assert_true(sector.register_entity(Q, Vector2(0, 100)))
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.bounty.test"
	weapon.base_damage = 20.0
	weapon.min_range_meters = 10.0
	weapon.range_meters = 200.0
	weapon.crit_multiplier = 2.0
	var combat := CombatAuthority.new(sector, SeedStreams.new(51))
	assert_true(combat.register(P, F, 100.0, weapon))
	assert_true(combat.register(Q, E, 10.0))
	var bridge := Prg05BountyCombatBridge.new(combat, s, true)
	assert_true(bridge.bind_bounty(bounty, Q))
	assert_false(bridge.bind_bounty(bounty, P))
	var sunk := combat.fire(P, 0, CombatAuthority.fire_intent(Q))
	assert_true(sunk["sunk"])
	assert_eq(bridge.outcomes_snapshot().size(), 1)
	assert_eq(s.economy_balance(P), 80)
	assert_true(s.economy_bounty_board(P, 0)[0]["claimed"])
	assert_eq(s.claim_economy_bounty_authoritative(P, bounty, Q, int(sunk["sequence_id"]), 0)["reward"], 80)
	assert_eq(s.economy_balance(P), 80)
	assert_eq(s.claim_economy_bounty_authoritative(Q, bounty, Q, 999, 0)["reason"], "event_conflict")
	var intel := s.record_economy_intel_authoritative(P, "intel.prg05.raider", "sector.harbor", Q, 42)
	assert_true(intel["accepted"])
	assert_eq(intel, s.record_economy_intel_authoritative(P, "intel.prg05.raider", "sector.harbor", Q, 42))
	assert_eq(s.record_economy_intel_authoritative(P, "intel.prg05.raider", "sector.other", Q, 42)["reason"], "event_conflict")
	var reports := s.economy_intel_reports(P)
	assert_eq(reports.size(), 1)
	reports[0]["subject_id"] = "entity.injected"
	assert_eq(s.economy_intel_reports(P)[0]["subject_id"], Q)
	var saved := s.progression_snapshot()
	var json: Variant = JSON.parse_string(JSON.stringify(saved))
	assert_true(InventoryState.validate_progression_state(json))
	var restored := _make()
	assert_true(restored.register_economy_bounty(bounty, F, Q, 80))
	assert_true(restored.restore_progression(json))
	assert_eq(restored.economy_balance(P), 80)
	assert_true(restored.economy_bounty_board(P, 0)[0]["claimed"])
	assert_eq(restored.economy_intel_reports(P)[0]["tick"], 42)
	assert_eq(restored.claim_economy_bounty_authoritative(P, bounty, Q, int(sunk["sequence_id"]), 0)["reward"], 80)
	assert_eq(restored.economy_balance(P), 80)
	var corrupted: Dictionary = json.duplicate(true)
	corrupted["prg05"]["events"]["intel.prg05.raider"]["result"]["tick"] = 1.5
	assert_false(Prg05EconomyState.validate_state(corrupted["prg05"]))
	print("PRG05_BOUNTY_INTEL_COMBAT_SAVE_OK")


func test_prg05_bounty_invalid_proofs_expiry_hostility_and_lan_spoof() -> void:
	var s := _make()
	var bounty := "bounty.prg05.expires"
	assert_true(s.register_economy_bounty(bounty, F, Q, 100, 8))
	assert_eq(s.claim_economy_bounty_authoritative(P, bounty, P, 1, 5)["reason"], "invalid_bounty_proof")
	assert_eq(s.claim_economy_bounty_authoritative(P, bounty, Q, 0, 5)["reason"], "invalid_bounty_proof")
	assert_eq(s.claim_economy_bounty_authoritative(P, bounty, Q, 1, 9)["reason"], "bounty_expired")
	assert_true(s.adjust_economy_reputation_authoritative(P, F, "event.bounty.reputation", -300)["accepted"])
	assert_eq(s.claim_economy_bounty_authoritative(P, bounty, Q, 1, 5)["reason"], "hostile_bounty_board")
	assert_eq(s.economy_balance(P), 0)
	assert_eq(s.record_economy_intel_authoritative(P, "intel.bad", "sector.harbor", Q, -1)["reason"], "invalid_intel")
	assert_eq(SessionProtocol.validate_envelope(SessionProtocol.make_envelope(1, "claim_bounty",
		{"bounty_id": bounty, "target_id": Q})), SessionProtocol.REJECT_UNSUPPORTED_INTENT)
	print("PRG05_BOUNTY_PROOF_GUARD_OK")


func _far_job(fleet_id: String, job_id: String, quantity: int) -> Dictionary:
	var cargo := WorldJob.cargo_mission("mission.%s" % job_id, I, quantity, "anchor.prg05.origin", FoundationSector.HAVEN_ID)
	return WorldJob.create(job_id, WorldJob.TRADE, fleet_id, "anchor.prg05.origin", FoundationSector.HAVEN_ID, FoundationSector.ID, WorldJob.TRAVEL, "", cargo)


func _far_ship(instance_id: String, fleet_id: String, job: Dictionary, health: float) -> Dictionary:
	var base := {
		"instance_id": instance_id,
		"definition_id": "ship.vs02_practice",
		"entity_kind": "npc_ship",
		"sector_id": FoundationSector.ID,
		"position": {"x": 100.0, "y": -100.0},
		"motion": {"heading": 0.25, "vx": 1.0, "vy": -1.0},
		"health": health,
		"alive": true,
		"route": {"patrol_index": 0, "intent_id": 0},
		"cooldowns": {"reload": 10, "repair": 20},
		"inventory": {"item.vs03_salvage_scrap": 1},
		"payload": {"content_refs": ["ammo.core_round"]},
	}
	return FarFieldEntityState.attach(base, FarFieldEntityState.default_semantic(SimulationLOD.FAR, "faction.player", fleet_id, "merchant", job, FoundationSector.HAVEN_ID, 0.02, "low"))

func test_prg05_market_panel_mobile_intents_are_bounded_and_price_untrusted() -> void:
	var panel := Prg05MarketPanel.new()
	add_child_autofree(panel)
	var emitted: Array = []
	panel.market_intent_requested.connect(func(operation: String, payload: Dictionary) -> void:
		emitted.append({"operation": operation, "payload": payload.duplicate(true)})
	)
	assert_false(panel.request_trade(InventoryState.OP_MARKET_BUY, 1))
	var s := _make()
	assert_true(panel.consume_snapshot(M, s.economy_quote(P, M), s.economy_balance(P)))
	assert_true(panel.set_quantity(2))
	assert_false(panel.set_quantity(Prg05MarketPanel.MAX_ORDER + 1))
	assert_true(panel.request_trade(InventoryState.OP_MARKET_BUY, 2))
	assert_true(panel.request_trade(InventoryState.OP_MARKET_SELL, 1))
	assert_false(panel.request_trade("economy_cheat", 1))
	assert_false(panel.request_trade(InventoryState.OP_MARKET_BUY, 0))
	assert_eq(emitted.size(), 2)
	assert_eq(emitted[0]["operation"], InventoryState.OP_MARKET_BUY)
	assert_eq(emitted[0]["payload"], {"market_id": M, "quantity": 2})
	assert_false(emitted[0]["payload"].has("price"))
	assert_false(emitted[0]["payload"].has("owner_id"))
	print("PRG05_MOBILE_MARKET_INTENT_OK")
