extends GutTest

const PLAYER := "entity.player"
const CHEST := "container.chest"
const SCRAP := "item.scrap"
const CORE := "item.core.rigging"
const CORE_ALT := "item.core.rigging_alt"
const CORE_WRONG := "item.core.armor"
const RECIPE := "recipe.rigging_core"
const SALVAGE := "salvage.rigging_core"
const UPGRADE_ROOT := "upgrade.rigging_slot"
const UPGRADE_CHILD := "upgrade.rigging_tier2"
const TROPHY := "trophy.first_reclamation"
const EVENT := "event.prg02.first_reclamation"
const SLOT := "core_slot.rigging.s1"

func _item(id: String, category: String, limit: int, core_type: String = "", core_unique: bool = false, modifiers: Array[Dictionary] = []) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.stable_id = id
	definition.display_name = id
	definition.item_category = category
	definition.stack_limit = limit
	definition.core_type = core_type
	definition.core_unique = core_unique
	definition.stat_modifiers = modifiers
	return definition

func _recipe(id: String, input_id: String, input_quantity: int, output_id: String, output_quantity: int, max_count: int = 3, prerequisites: PackedStringArray = PackedStringArray()) -> RecipeDefinition:
	var definition := RecipeDefinition.new()
	definition.stable_id = id
	definition.inputs = [{"item_id": input_id, "quantity": input_quantity}]
	definition.outputs = [{"item_id": output_id, "quantity": output_quantity}]
	definition.max_craft_count = max_count
	definition.prerequisite_ids = prerequisites
	definition.category = "core"
	definition.tag = "prg02"
	return definition

func _salvage() -> SalvageTable:
	var definition := SalvageTable.new()
	definition.stable_id = SALVAGE
	definition.source_item_ids = PackedStringArray([CORE])
	definition.source_categories = PackedStringArray(["core"])
	definition.consume_quantity = 1
	definition.entries = [{"item_id": SCRAP, "min_quantity": 1, "max_quantity": 2, "weight": 7}]
	definition.tag = "prg02"
	return definition

func _upgrade(id: String, tier: int, prerequisites: PackedStringArray, with_slot: bool, cost: int = 0) -> ShipUpgradeDefinition:
	var definition := ShipUpgradeDefinition.new()
	definition.stable_id = id
	definition.tier = tier
	definition.prerequisite_ids = prerequisites
	var cost_rows: Array[Dictionary] = []
	if cost > 0:
		cost_rows.append({"item_id": SCRAP, "quantity": cost})
	definition.costs = cost_rows
	var modifier_rows: Array[Dictionary] = [{
		"source_id": "modifier." + id,
		"stat": "speed",
		"operation": "percent_add",
		"value": 0.02,
		"priority": tier,
	}]
	definition.modifiers = modifier_rows
	var slot_rows: Array[Dictionary] = []
	if with_slot:
		slot_rows.append({
			"slot_id": SLOT,
			"slot_type": "rigging",
			"allowed_core_type": "rigging",
		})
	definition.core_slots = slot_rows
	return definition

func _trophy() -> TrophyDefinition:
	var definition := TrophyDefinition.new()
	definition.stable_id = TROPHY
	definition.event_key = EVENT
	definition.prerequisite_ids = PackedStringArray([UPGRADE_ROOT])
	definition.rewards = [{"item_id": SCRAP, "quantity": 1}]
	definition.modifiers = [{
		"source_id": "modifier.trophy.first_reclamation",
		"stat": "speed",
		"operation": "flat",
		"value": 1.0,
		"priority": 0,
	}]
	return definition

func _state(seed: int = 20261122, max_slots: int = 8, scrap_limit: int = 20) -> Dictionary:
	var inventory := InventoryState.new()
	assert_true(inventory.bind_owner(PLAYER, max_slots, 100.0))
	assert_true(inventory.bind_owner(CHEST, 4, 100.0))
	assert_true(inventory.register_item_definition(_item(SCRAP, "material", scrap_limit)))
	assert_true(inventory.register_item_definition(_item(CORE, "core", 4, "rigging", true, [{"stat":"speed","operation":"percent_add","value":0.05,"priority":10}])))
	assert_true(inventory.register_item_definition(_item(CORE_ALT, "core", 4, "rigging", false, [{"stat":"speed","operation":"percent_add","value":0.03,"priority":20}])))
	assert_true(inventory.register_item_definition(_item(CORE_WRONG, "core", 4, "armor", false)))
	var streams := SeedStreams.new(seed)
	assert_true(inventory.configure_prg02(streams))
	return {"inventory": inventory, "streams": streams}

func _register_standard(inventory: InventoryState) -> void:
	assert_true(inventory.register_recipe_definition(_recipe(RECIPE, SCRAP, 2, CORE, 1)))
	assert_true(inventory.register_salvage_definition(_salvage()))
	assert_true(inventory.register_upgrade_definition(_upgrade(UPGRADE_ROOT, 1, PackedStringArray(), true, 2)))
	assert_true(inventory.register_upgrade_definition(_upgrade(UPGRADE_CHILD, 2, PackedStringArray([UPGRADE_ROOT]), false, 1)))
	assert_true(inventory.register_trophy_definition(_trophy()))
	assert_eq(inventory.validate_prg02_catalog(), "")

func test_prg02_definition_registry_schema_and_missing_refs() -> void:
	for definition_type in ["recipe", "salvage_table", "ship_upgrade", "trophy"]:
		assert_true(DefinitionRegistry.VALID_DEFINITION_TYPES.has(definition_type))
	var invalid := _recipe("recipe.invalid", SCRAP, 0, CORE, 1)
	assert_false(invalid.valid())
	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	assert_false(inventory.register_recipe_definition(_recipe("recipe.missing", "item.missing", 1, CORE, 1)))
	var recipe := _recipe(RECIPE, SCRAP, 2, CORE, 1)
	assert_true(inventory.register_recipe_definition(recipe))
	assert_false(inventory.register_recipe_definition(recipe))
	var missing_prereq := _recipe("recipe.gated", SCRAP, 1, CORE, 1, 1, PackedStringArray(["upgrade.missing"]))
	assert_true(inventory.register_recipe_definition(missing_prereq))
	assert_eq(inventory.validate_prg02_catalog(), "missing_recipe_prerequisite")
	print("PRG02_RECIPE_REGISTRY_OK")

func test_prg02_craft_success_bounds_and_missing_input() -> void:
	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 6))
	var result := inventory.execute_transaction(PLAYER, "txn.prg02.craft.ok", InventoryState.OP_CRAFT, {"recipe_id": RECIPE, "count": 2})
	assert_true(result["accepted"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 2)
	assert_eq(inventory.quantity(PLAYER, CORE), 2)
	var before := inventory.quantities_snapshot(PLAYER)
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.craft.bounds", InventoryState.OP_CRAFT, {"recipe_id": RECIPE, "count": 4})["accepted"])
	assert_eq(inventory.quantities_snapshot(PLAYER), before)
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.craft.missing", InventoryState.OP_CRAFT, {"recipe_id": RECIPE, "count": 2})["accepted"])
	assert_eq(inventory.quantities_snapshot(PLAYER), before)
	print("PRG02_CRAFT_ATOMIC_OK")
	print("PRG02_CRAFT_BOUNDARY_OK")

func test_prg02_craft_capacity_rollback_duplicate_conflict_and_lost_ack() -> void:
	var full_bundle := _state()
	var full := full_bundle["inventory"] as InventoryState
	_register_standard(full)
	assert_true(full.grant_authoritative(PLAYER, SCRAP, 4))
	assert_true(full.grant_authoritative(PLAYER, CORE, 4))
	var full_before := full.quantities_snapshot(PLAYER)
	var rejected := full.execute_transaction(PLAYER, "txn.prg02.craft.capacity", InventoryState.OP_CRAFT, {"recipe_id": RECIPE, "count": 1})
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "output_capacity")
	assert_eq(full.quantities_snapshot(PLAYER), full_before)

	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 6))
	var payload := {"recipe_id": RECIPE, "count": 1}
	var first := inventory.execute_transaction(PLAYER, "txn.prg02.craft.retry", InventoryState.OP_CRAFT, payload)
	var quantities := inventory.quantities_snapshot(PLAYER)
	var retry := inventory.execute_transaction(PLAYER, "txn.prg02.craft.retry", InventoryState.OP_CRAFT, payload)
	assert_eq(retry, first)
	assert_eq(inventory.quantities_snapshot(PLAYER), quantities)
	var conflict := inventory.execute_transaction(PLAYER, "txn.prg02.craft.retry", InventoryState.OP_CRAFT, {"recipe_id": RECIPE, "count": 2})
	assert_eq(conflict["reason"], "transaction_conflict")

	var ledger := HostTransactionLedger.new()
	var fingerprint := HostTransactionLedger.fingerprint(InventoryState.OP_CRAFT, payload)
	assert_eq(ledger.inspect(PLAYER, "txn.prg02.host.retry", InventoryState.OP_CRAFT, fingerprint)["status"], HostTransactionLedger.STATUS_NEW)
	assert_true(ledger.commit(PLAYER, "txn.prg02.host.retry", InventoryState.OP_CRAFT, fingerprint, first))
	var restored_ledger := HostTransactionLedger.new()
	assert_true(restored_ledger.restore_state(ledger.snapshot_state()))
	assert_eq(restored_ledger.inspect(PLAYER, "txn.prg02.host.retry", InventoryState.OP_CRAFT, fingerprint)["status"], HostTransactionLedger.STATUS_CACHED)
	assert_eq(inventory.quantities_snapshot(PLAYER), quantities)
	print("PRG02_CRAFT_ROLLBACK_OK")
	print("PRG02_LOST_ACK_IDEMPOTENCY_OK")

func test_prg02_salvage_determinism_rng_persistence_and_rollback() -> void:
	var a_bundle := _state(777)
	var a := a_bundle["inventory"] as InventoryState
	var a_streams := a_bundle["streams"] as SeedStreams
	_register_standard(a)
	assert_true(a.grant_authoritative(PLAYER, CORE, 1))
	var rejected_before := a_streams.snapshot_state()
	assert_false(a.execute_transaction(PLAYER, "txn.prg02.salvage.reject", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE_ALT})["accepted"])
	assert_eq(a_streams.snapshot_state(), rejected_before)
	var first := a.execute_transaction(PLAYER, "txn.prg02.salvage.a", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE})
	assert_true(first["accepted"])

	var b_bundle := _state(777)
	var b := b_bundle["inventory"] as InventoryState
	_register_standard(b)
	assert_true(b.grant_authoritative(PLAYER, CORE, 1))
	var second := b.execute_transaction(PLAYER, "txn.prg02.salvage.b", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE})
	assert_eq(second, first)

	assert_true(a.grant_authoritative(PLAYER, CORE, 1))
	var continuation_quantities := a.quantities_snapshot(PLAYER)
	var continuation_progression := a.progression_snapshot()
	var continuation_rng := a_streams.snapshot_state()
	var next_a := a.execute_transaction(PLAYER, "txn.prg02.salvage.next", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE})

	var c_bundle := _state(1)
	var c := c_bundle["inventory"] as InventoryState
	var c_streams := c_bundle["streams"] as SeedStreams
	_register_standard(c)
	assert_true(c.restore_quantities(PLAYER, continuation_quantities))
	assert_true(c.restore_progression(continuation_progression))
	assert_true(c_streams.restore_state(continuation_rng))
	var next_c := c.execute_transaction(PLAYER, "txn.prg02.salvage.next", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE})
	assert_eq(next_c, next_a)

	var cap_bundle := _state(991, 8, 2)
	var cap := cap_bundle["inventory"] as InventoryState
	var cap_streams := cap_bundle["streams"] as SeedStreams
	_register_standard(cap)
	assert_true(cap.grant_authoritative(PLAYER, SCRAP, 2))
	assert_true(cap.grant_authoritative(PLAYER, CORE, 1))
	var cap_quantities := cap.quantities_snapshot(PLAYER)
	var cap_rng := cap_streams.snapshot_state()
	var cap_result := cap.execute_transaction(PLAYER, "txn.prg02.salvage.capacity", InventoryState.OP_SALVAGE, {"table_id": SALVAGE, "source_item_id": CORE})
	assert_false(cap_result["accepted"])
	assert_eq(cap_result["reason"], "output_capacity")
	assert_eq(cap.quantities_snapshot(PLAYER), cap_quantities)
	assert_eq(cap_streams.snapshot_state(), cap_rng)
	print("PRG02_SALVAGE_DETERMINISM_OK")
	print("PRG02_SALVAGE_RNG_PERSISTENCE_OK")
	print("PRG02_SALVAGE_ROLLBACK_OK")

func test_prg02_upgrade_dag_cycle_missing_prereq_and_atomic_unlock() -> void:
	var missing_bundle := _state()
	var missing := missing_bundle["inventory"] as InventoryState
	assert_true(missing.register_upgrade_definition(_upgrade("upgrade.missing_test", 2, PackedStringArray(["upgrade.ghost"]), false)))
	assert_eq(missing.validate_prg02_catalog(), "missing_upgrade_prerequisite")

	var cycle_bundle := _state()
	var cycle := cycle_bundle["inventory"] as InventoryState
	assert_true(cycle.register_upgrade_definition(_upgrade("upgrade.a", 2, PackedStringArray(["upgrade.b"]), false)))
	assert_true(cycle.register_upgrade_definition(_upgrade("upgrade.b", 1, PackedStringArray(["upgrade.a"]), false)))
	assert_eq(cycle.validate_prg02_catalog(), "upgrade_cycle")

	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.up.child.early", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_CHILD})["accepted"])
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 2))
	var root := inventory.execute_transaction(PLAYER, "txn.prg02.up.root", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_ROOT})
	assert_true(root["accepted"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 0)
	var state := inventory.prg02_state_snapshot()
	assert_true(state["unlocked_upgrades"][PLAYER].has(UPGRADE_ROOT))
	assert_true(state["core_slots"][PLAYER].has(SLOT))
	var after := inventory.quantities_snapshot(PLAYER)
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.up.root.again", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_ROOT})["accepted"])
	assert_eq(inventory.quantities_snapshot(PLAYER), after)
	print("PRG02_UPGRADE_DAG_OK")
	print("PRG02_UPGRADE_ATOMIC_OK")

func test_prg02_core_compatibility_replace_modifier_guard_and_remove_rollback() -> void:
	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 2))
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.core.upgrade", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_ROOT})["accepted"])
	assert_true(inventory.grant_authoritative(PLAYER, CORE, 1))
	assert_true(inventory.grant_authoritative(PLAYER, CORE_ALT, 1))
	assert_true(inventory.grant_authoritative(PLAYER, CORE_WRONG, 1))
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.core.wrong", InventoryState.OP_CORE_INSERT, {"slot_id": SLOT, "item_id": CORE_WRONG})["accepted"])
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.core.insert", InventoryState.OP_CORE_INSERT, {"slot_id": SLOT, "item_id": CORE})["accepted"])
	var value := inventory.stat_value(PLAYER, "speed", 100.0)
	assert_almost_eq(value, 107.1, 0.001)
	assert_almost_eq(inventory.stat_value(PLAYER, "speed", 100.0), value, 0.001)
	assert_true(inventory.configure_prg02_core_slot(PLAYER, "core_slot.rigging.s2", "rigging", "rigging"))
	assert_true(inventory.grant_authoritative(PLAYER, CORE, 1))
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.core.unique", InventoryState.OP_CORE_INSERT, {"slot_id": "core_slot.rigging.s2", "item_id": CORE})["accepted"])
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.core.replace", InventoryState.OP_CORE_REPLACE, {"slot_id": SLOT, "item_id": CORE_ALT})["accepted"])
	assert_eq(inventory.quantity(PLAYER, CORE), 2)

	var small := InventoryState.new()
	assert_true(small.bind_owner(PLAYER, 1, 100.0))
	assert_true(small.register_item_definition(_item(SCRAP, "material", 5)))
	assert_true(small.register_item_definition(_item(CORE, "core", 2, "rigging", true)))
	var small_streams := SeedStreams.new(5)
	assert_true(small.configure_prg02(small_streams))
	assert_true(small.configure_prg02_core_slot(PLAYER, SLOT, "rigging", "rigging"))
	assert_true(small.grant_authoritative(PLAYER, CORE, 1))
	assert_true(small.execute_transaction(PLAYER, "txn.prg02.small.insert", InventoryState.OP_CORE_INSERT, {"slot_id": SLOT, "item_id": CORE})["accepted"])
	assert_true(small.grant_authoritative(PLAYER, SCRAP, 1))
	var before := small.prg02_state_snapshot()
	assert_false(small.execute_transaction(PLAYER, "txn.prg02.small.remove", InventoryState.OP_CORE_REMOVE, {"slot_id": SLOT})["accepted"])
	assert_eq(small.prg02_state_snapshot(), before)
	assert_eq(small.quantity(PLAYER, SCRAP), 1)
	assert_eq(small.quantity(PLAYER, CORE), 0)
	print("PRG02_CORE_COMPATIBILITY_OK")
	print("PRG02_MODIFIER_GUARD_OK")
	print("PRG02_CORE_ROLLBACK_OK")

func test_prg02_trophy_event_ledger_idempotent_reward() -> void:
	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_false(inventory.execute_transaction(PLAYER, "txn.prg02.trophy.early", InventoryState.OP_TROPHY_UNLOCK, {"trophy_id": TROPHY, "event_key": EVENT})["accepted"])
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 2))
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.trophy.root", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_ROOT})["accepted"])
	var first := inventory.execute_transaction(PLAYER, "txn.prg02.trophy.unlock", InventoryState.OP_TROPHY_UNLOCK, {"trophy_id": TROPHY, "event_key": EVENT})
	assert_true(first["accepted"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 1)
	var duplicate_transaction := inventory.execute_transaction(PLAYER, "txn.prg02.trophy.unlock", InventoryState.OP_TROPHY_UNLOCK, {"trophy_id": TROPHY, "event_key": EVENT})
	assert_eq(duplicate_transaction, first)
	assert_eq(inventory.quantity(PLAYER, SCRAP), 1)
	var second_event := inventory.execute_transaction(PLAYER, "txn.prg02.trophy.event2", InventoryState.OP_TROPHY_UNLOCK, {"trophy_id": TROPHY, "event_key": EVENT})
	assert_false(second_event["accepted"])
	assert_eq(second_event["reason"], "event_already_processed")
	assert_eq(inventory.quantity(PLAYER, SCRAP), 1)
	print("PRG02_TROPHY_LEDGER_OK")

func test_prg02_progression_save_restore_legacy_migration_and_corrupt_rejection() -> void:
	var bundle := _state()
	var inventory := bundle["inventory"] as InventoryState
	_register_standard(inventory)
	assert_true(inventory.grant_authoritative(PLAYER, SCRAP, 3))
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.persist.up", InventoryState.OP_UPGRADE, {"upgrade_id": UPGRADE_ROOT})["accepted"])
	assert_true(inventory.grant_authoritative(PLAYER, CORE, 1))
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg02.persist.core", InventoryState.OP_CORE_INSERT, {"slot_id": SLOT, "item_id": CORE})["accepted"])
	var progression := inventory.progression_snapshot()
	var quantities := inventory.quantities_snapshot(PLAYER)
	assert_true(InventoryState.validate_progression_state(progression))

	var restored_bundle := _state(3)
	var restored := restored_bundle["inventory"] as InventoryState
	_register_standard(restored)
	assert_true(restored.restore_quantities(PLAYER, quantities))
	assert_true(restored.restore_progression(progression))
	assert_eq(restored.progression_snapshot(), progression)

	var legacy := progression.duplicate(true)
	legacy["version"] = 1
	legacy.erase("prg02")
	legacy.erase("prg03")
	legacy.erase("prg04")
	legacy.erase("prg05")
	assert_true(InventoryState.validate_progression_state(legacy))
	var legacy_bundle := _state(4)
	var legacy_inventory := legacy_bundle["inventory"] as InventoryState
	_register_standard(legacy_inventory)
	assert_true(legacy_inventory.restore_progression(legacy))
	assert_true((legacy_inventory.prg02_state_snapshot()["unlocked_upgrades"] as Dictionary).is_empty())

	var corrupt := progression.duplicate(true)
	corrupt["prg02"]["core_slots"][PLAYER][SLOT]["core_id"] = 7
	assert_false(InventoryState.validate_progression_state(corrupt))
	print("PRG02_PERSISTENCE_MIGRATION_OK")

func test_prg02_protocol_host_authority_spoof_replay_and_malformed_guards() -> void:
	assert_eq(SessionProtocol.PROTOCOL_VERSION, 8)
	var envelopes := [
		SessionProtocol.make_envelope(1, SessionProtocol.PROGRESSION_CRAFT, {"transaction_id":"txn.net.craft","recipe_id":RECIPE,"count":1}),
		SessionProtocol.make_envelope(2, SessionProtocol.PROGRESSION_SALVAGE, {"transaction_id":"txn.net.salvage","table_id":SALVAGE,"source_item_id":CORE}),
		SessionProtocol.make_envelope(3, SessionProtocol.PROGRESSION_SHIP_UPGRADE, {"transaction_id":"txn.net.upgrade","upgrade_id":UPGRADE_ROOT}),
		SessionProtocol.make_envelope(4, SessionProtocol.PROGRESSION_CORE_INSERT, {"transaction_id":"txn.net.core.insert","slot_id":SLOT,"item_id":CORE}),
		SessionProtocol.make_envelope(5, SessionProtocol.PROGRESSION_CORE_REMOVE, {"transaction_id":"txn.net.core.remove","slot_id":SLOT}),
		SessionProtocol.make_envelope(6, SessionProtocol.PROGRESSION_CORE_REPLACE, {"transaction_id":"txn.net.core.replace","slot_id":SLOT,"item_id":CORE_ALT}),
		SessionProtocol.make_envelope(7, SessionProtocol.PROGRESSION_TROPHY_UNLOCK, {"transaction_id":"txn.net.trophy","trophy_id":TROPHY,"event_key":EVENT}),
	]
	for envelope in envelopes:
		assert_eq(SessionProtocol.validate_envelope(envelope), "")
	var malformed := SessionProtocol.make_envelope(8, SessionProtocol.PROGRESSION_CRAFT, {"transaction_id":"txn.net.bad","recipe_id":RECIPE,"count":1,"output_item_id":CORE})
	assert_eq(SessionProtocol.validate_envelope(malformed), SessionProtocol.REJECT_MALFORMED_PAYLOAD)
	var spoof := SessionProtocol.make_envelope(9, SessionProtocol.PROGRESSION_CRAFT, {"transaction_id":"txn.net.spoof","recipe_id":RECIPE,"count":1,"owner_id":PLAYER})
	assert_eq(SessionProtocol.validate_envelope(spoof), SessionProtocol.REJECT_FORBIDDEN_IDENTITY)
	assert_eq(SessionProtocol.validate_sequence(10, 10), SessionProtocol.REJECT_REPLAY)
	for operation in [SessionProtocol.PROGRESSION_CRAFT, SessionProtocol.PROGRESSION_SALVAGE, SessionProtocol.PROGRESSION_SHIP_UPGRADE, SessionProtocol.PROGRESSION_CORE_INSERT, SessionProtocol.PROGRESSION_CORE_REMOVE, SessionProtocol.PROGRESSION_CORE_REPLACE, SessionProtocol.PROGRESSION_TROPHY_UNLOCK]:
		assert_true(SessionProtocol.PROGRESSION_INTENTS.has(operation))
	print("PRG02_LAN_AUTHORITY_OK")

func test_prg02_touch_panel_emits_bounded_intents_only() -> void:
	var panel := ProgressionPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	assert_true(panel.select_item(CORE))
	assert_true(panel.select_recipe(RECIPE))
	assert_true(panel.request_craft("txn.ui.craft", 1))
	assert_true(panel.select_salvage_table(SALVAGE))
	assert_true(panel.request_salvage("txn.ui.salvage"))
	assert_true(panel.select_upgrade(UPGRADE_ROOT))
	assert_true(panel.request_upgrade("txn.ui.upgrade"))
	assert_true(panel.select_core_slot(SLOT))
	assert_true(panel.request_core_insert("txn.ui.core.insert"))
	assert_true(panel.request_core_remove("txn.ui.core.remove"))
	assert_true(panel.select_item(CORE_ALT))
	assert_true(panel.request_core_replace("txn.ui.core.replace"))
	assert_true(panel.select_trophy(TROPHY))
	assert_true(panel.request_trophy_unlock("txn.ui.trophy", EVENT))
	assert_signal_emitted(panel, "progression_intent_requested")
	var button := Button.new()
	add_child_autofree(button)
	ProgressionPanel.apply_touch_target(button)
	assert_gte(button.custom_minimum_size.x, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_gte(button.custom_minimum_size.y, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_eq(ProgressionPanel.ACCESSIBILITY_FONT_SCALE, 1.3)
	print("PRG02_TOUCH_UI_OK")
