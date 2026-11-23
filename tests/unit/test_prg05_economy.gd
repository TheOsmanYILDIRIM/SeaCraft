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
