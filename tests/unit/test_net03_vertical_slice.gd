extends GutTest

const P := preload("res://src/network/session_protocol.gd")
const TARGET := "entity.vs02_sc03"
const DROP := "drop.entity_vs02_sc03.seq_5"
const ITEM := "item.vs03_salvage_scrap"


func test_net03_select_contract() -> void:
	assert_eq(_reason(P.SELECT_COMBAT_TARGET, {"target_id": TARGET}), "")
	assert_eq(_reason(P.SELECT_COMBAT_TARGET, {"target_id": TARGET, "actor": "entity.other"}), P.REJECT_MALFORMED_PAYLOAD)
	assert_eq(_reason(P.SELECT_COMBAT_TARGET, {"target_id": "Bad ID"}), P.REJECT_MALFORMED_PAYLOAD)


func test_net03_fire_contract() -> void:
	assert_eq(_reason(P.FIRE_WEAPON, {"target_id": TARGET}), "")
	for key in ["heading", "hit", "crit", "damage", "remaining_hull", "ammo_id", "sequence_id"]:
		var payload := {"target_id": TARGET}
		payload[key] = 1
		assert_eq(_reason(P.FIRE_WEAPON, payload), P.REJECT_MALFORMED_PAYLOAD, key)
	assert_eq(_reason(P.FIRE_WEAPON, {"target_id": TARGET, "player_id": FoundationSector.PLAYER}), P.REJECT_FORBIDDEN_IDENTITY)


func test_net03_pickup_contract() -> void:
	assert_eq(_reason(P.PICKUP_LOOT, {"drop_id": DROP}), "")
	for key in ["item_id", "quantity", "reward", "inventory_delta", "claimed"]:
		var payload := {"drop_id": DROP}
		payload[key] = true
		assert_eq(_reason(P.PICKUP_LOOT, payload), P.REJECT_MALFORMED_PAYLOAD, key)
	assert_eq(_reason(P.PICKUP_LOOT, {"drop_id": 5}), P.REJECT_MALFORMED_PAYLOAD)


func test_net03_outcomes_are_not_intents() -> void:
	for kind in ["set_hull", "damage_entity", "sink_entity", "spawn_loot", "create_loot", "claim_result", "set_inventory", "grant_item", "despawn_entity"]:
		assert_eq(_reason(str(kind), {"target_id": TARGET}), P.REJECT_UNSUPPORTED_INTENT)


func test_net03_fresh_sequence_is_not_a_fresh_drop() -> void:
	var original := P.make_envelope(4, P.PICKUP_LOOT, {"drop_id": DROP})
	var retry := P.make_envelope(5, P.PICKUP_LOOT, {"drop_id": DROP})
	assert_eq(P.validate_envelope(original), "")
	assert_eq(P.validate_envelope(retry), "")
	assert_eq(P.validate_sequence(original["client_sequence"], 4), P.REJECT_REPLAY)
	assert_eq(P.validate_sequence(retry["client_sequence"], 4), "")
	assert_eq(retry["payload"], original["payload"])


func test_net03_npc_semantic_shape_and_budget() -> void:
	var row := _row()
	assert_eq(P.validate_snapshot_row(row), "")
	assert_eq(P.validate_snapshot(P.make_snapshot(3, 3, FoundationSector.ID, [row])), "")
	row.erase("ai_intent_id")
	assert_eq(P.validate_snapshot_row(row), P.REJECT_MALFORMED_SNAPSHOT)
	row["ai_intent_id"] = 0.5
	assert_eq(P.validate_snapshot_row(row), P.REJECT_MALFORMED_SNAPSHOT)
	row["ai_intent_id"] = 32
	assert_eq(P.validate_snapshot_row(row), P.REJECT_MALFORMED_SNAPSHOT)
	row["ai_intent_id"] = 0
	row["target_entity_id"] = FoundationSector.PLAYER
	assert_eq(P.validate_snapshot_row(row), P.REJECT_MALFORMED_SNAPSHOT)


func test_net03_semantics_are_npc_only() -> void:
	var row := _row()
	for kind in ["player", "monster", "loot"]:
		row["entity_kind"] = kind
		assert_eq(P.validate_snapshot_row(row), P.REJECT_MALFORMED_SNAPSHOT)
	row.erase("ai_state_id")
	row.erase("ai_intent_id")
	assert_eq(P.validate_snapshot_row(row), "")


func test_net03_proxy_does_not_replay_stale_ai_state() -> void:
	var proxy := NetworkEntityProxy.new()
	add_child_autofree(proxy)
	assert_true(proxy.configure_spawn(P.spawn_payload(TARGET, "npc", FoundationSector.ID, "", 1, 1, 0, {})))
	var row := _row()
	assert_true(proxy.apply_snapshot(row, 4, 12))
	assert_eq(proxy.ai_state_id, NpcBrain.State.ALERT)
	assert_eq(proxy.ai_intent_id, NpcBrain.Intent.INVESTIGATE_THREAT)
	row["ai_state_id"] = NpcBrain.State.PATROL
	assert_false(proxy.apply_snapshot(row, 3, 9))
	assert_false(proxy.apply_snapshot(row, 4, 12))
	assert_eq(proxy.ai_state_id, NpcBrain.State.ALERT)
	assert_eq(proxy.sample_count(), 2)


func test_net03_offline_semantic_baseline() -> void:
	var scenario := VerticalSliceScenario.new()
	add_child_autofree(scenario)
	var result := scenario.run_full()
	assert_true(result["completed"], str(result["failure"]))
	if not result["completed"]:
		return
	var drop_id := str(result["last_drop_id"])
	var ledger := scenario._loot
	assert_true(ledger.claimed_by_inventory_owner(FoundationSector.PLAYER, drop_id))
	assert_false(ledger.claimed_by_inventory_owner("entity.spoof", drop_id))
	assert_false(ledger.claimed_by_inventory_owner(FoundationSector.PLAYER, "drop.unknown"))
	assert_eq(ledger.pickup(FoundationSector.PLAYER, LootAuthority.pickup_intent(drop_id))["reason"], "already_claimed")
	var inventory: Dictionary = result["inventory"]
	print("NET03_OFFLINE_DIGEST %s" % JSON.stringify({
		"player": FoundationSector.PLAYER, "npc": TARGET,
		"sector": result["sector_id"], "seed": VerticalSliceScenario.MASTER_SEED,
		"transitions": result["transitions"], "sunk": result["sunk_events"], "drops": result["drop_events"],
		"claims": result["pickup_events"], "fires": result["accepted_fires"],
		"hull": scenario._combat.hull(TARGET), "reward": int(inventory.get(ITEM, 0)),
		"item": ITEM, "drop": drop_id,
	}))
	scenario.reset_scenario()


func _row() -> Dictionary:
	return {
		"entity_id": TARGET, "entity_kind": "npc", "sector_id": FoundationSector.ID,
		"x": 1.0, "y": 2.0, "heading": 0.0, "hull_ratio": 0.6, "alive": true,
		"ai_state_id": NpcBrain.State.ALERT, "ai_intent_id": NpcBrain.Intent.INVESTIGATE_THREAT,
	}


func _reason(kind: String, payload: Dictionary) -> String:
	return P.validate_envelope(P.make_envelope(1, kind, payload))
