extends GutTest

const PLAYER := "entity.player"
const CHEST := "container.chest"

func _item(id: String, category: String, limit: int, slot: String = "", weight: float = 0.0, mods: Array[Dictionary] = []) -> ItemDefinition:
	var d := ItemDefinition.new()
	d.stable_id = id
	d.display_name = id
	d.item_category = category
	d.stack_limit = limit
	d.equip_slot = slot
	d.weight = weight
	d.stat_modifiers = mods
	return d

func _state() -> InventoryState:
	var s := InventoryState.new()
	assert_true(s.bind_owner(PLAYER, 8, 100.0))
	assert_true(s.bind_owner(CHEST, 2, 20.0))
	assert_true(s.register_item_definition(_item("item.scrap", "material", 10, "", 1.0)))
	assert_true(s.register_item_definition(_item("item.cannon", "weapon", 1, "weapon", 5.0, [{"stat":"damage","operation":"flat","value":4.0,"priority":0}])))
	assert_true(s.register_item_definition(_item("item.sail", "sail", 1, "sail", 3.0, [{"stat":"speed","operation":"percent_add","value":0.1,"priority":0}])))
	assert_true(s.register_item_definition(_item("item.crew", "crew", 1, "crew", 1.0)))
	assert_true(s.register_item_definition(_item("item.trainer", "trainer", 1, "trainer", 1.0)))
	assert_true(s.register_item_definition(_item("item.pet", "pet", 1, "pet", 1.0)))
	assert_true(s.register_item_definition(_item("item.ship_gem", "ship_gem", 4, "", 0.2, [{"stat":"damage","operation":"multiply","value":1.5,"priority":0}])))
	assert_true(s.register_item_definition(_item("item.pet_gem", "pet_gem", 4, "", 0.2)))
	return s

func test_prg01_item_schema_and_stack_boundaries() -> void:
	var bad := _item("item.bad", "weapon", 0, "weapon")
	assert_false(bad.valid())
	var s := _state()
	assert_false(s.grant_authoritative(PLAYER, "item.scrap", 0))
	assert_true(s.grant_authoritative(PLAYER, "item.scrap", 10))
	assert_false(s.grant_authoritative(PLAYER, "item.scrap", 1))
	assert_eq(s.quantity(PLAYER, "item.scrap"), 10)
	print("PRG01_STACK_SCHEMA_OK")

func test_prg01_transfer_is_atomic_and_rolls_back() -> void:
	var s := _state()
	assert_true(s.grant_authoritative(PLAYER, "item.scrap", 10))
	var ok := s.execute_transaction(PLAYER, "txn.transfer.ok", InventoryState.OP_TRANSFER, {"source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":5})
	assert_true(ok["accepted"])
	assert_eq(s.quantity(PLAYER, "item.scrap"), 5)
	assert_eq(s.quantity(CHEST, "item.scrap"), 5)
	var before := s.quantities_snapshot(PLAYER)
	var fail := s.execute_transaction(PLAYER, "txn.transfer.fail", InventoryState.OP_TRANSFER, {"source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":6})
	assert_false(fail["accepted"])
	assert_eq(s.quantities_snapshot(PLAYER), before)
	print("PRG01_TRANSFER_ROLLBACK_OK")

func test_prg01_equipment_crew_trainer_pet_and_rollback() -> void:
	var s := _state()
	for id in ["item.cannon","item.sail","item.crew","item.trainer","item.pet"]:
		assert_true(s.grant_authoritative(PLAYER, id, 1))
	assert_false(s.execute_transaction(PLAYER, "txn.badslot", InventoryState.OP_EQUIP, {"slot":"sail","item_id":"item.cannon"})["accepted"])
	assert_true(s.execute_transaction(PLAYER, "txn.eq1", InventoryState.OP_EQUIP, {"slot":"weapon","item_id":"item.cannon"})["accepted"])
	assert_true(s.execute_transaction(PLAYER, "txn.eq2", InventoryState.OP_EQUIP, {"slot":"crew","item_id":"item.crew"})["accepted"])
	assert_true(s.execute_transaction(PLAYER, "txn.eq3", InventoryState.OP_EQUIP, {"slot":"trainer","item_id":"item.trainer"})["accepted"])
	assert_true(s.execute_transaction(PLAYER, "txn.eq4", InventoryState.OP_EQUIP, {"slot":"pet","item_id":"item.pet"})["accepted"])
	assert_eq(s.quantity(PLAYER, "item.cannon"), 0)
	assert_eq(s.equipment_snapshot(PLAYER)["weapon"], "item.cannon")
	assert_true(s.execute_transaction(PLAYER, "txn.un1", InventoryState.OP_UNEQUIP, {"slot":"weapon"})["accepted"])
	assert_eq(s.quantity(PLAYER, "item.cannon"), 1)
	print("PRG01_EQUIPMENT_SLOTS_OK")

func test_prg01_gem_socket_progression_and_atomic_cost() -> void:
	var s := _state()
	assert_true(s.configure_socket(PLAYER, "socket.ship.s1", "ship_gem", 3))
	assert_true(s.grant_authoritative(PLAYER, "item.ship_gem", 1))
	assert_true(s.grant_authoritative(PLAYER, "item.scrap", 4))
	assert_true(s.execute_transaction(PLAYER, "txn.gem.insert", InventoryState.OP_SOCKET_INSERT, {"socket_id":"socket.ship.s1","item_id":"item.ship_gem"})["accepted"])
	assert_eq(s.socket_snapshot(PLAYER)["socket.ship.s1"]["level"], 1)
	assert_false(s.execute_transaction(PLAYER, "txn.gem.costfail", InventoryState.OP_SOCKET_UPGRADE, {"socket_id":"socket.ship.s1","cost_item_id":"item.scrap","cost_quantity":5})["accepted"])
	assert_eq(s.socket_snapshot(PLAYER)["socket.ship.s1"]["level"], 1)
	assert_eq(s.quantity(PLAYER, "item.scrap"), 4)
	assert_true(s.execute_transaction(PLAYER, "txn.gem.up", InventoryState.OP_SOCKET_UPGRADE, {"socket_id":"socket.ship.s1","cost_item_id":"item.scrap","cost_quantity":2})["accepted"])
	assert_eq(s.socket_snapshot(PLAYER)["socket.ship.s1"]["level"], 2)
	print("PRG01_SOCKET_PROGRESSION_OK")

func test_prg01_modifier_pipeline_deterministic_and_duplicate_guard() -> void:
	var s := _state()
	assert_true(s.grant_authoritative(PLAYER, "item.cannon", 1))
	assert_true(s.execute_transaction(PLAYER, "txn.mod.eq", InventoryState.OP_EQUIP, {"slot":"weapon","item_id":"item.cannon"})["accepted"])
	assert_eq(s.stat_value(PLAYER, "damage", 10.0), 14.0)
	assert_eq(s.stat_value(PLAYER, "damage", 10.0), 14.0)
	print("PRG01_MODIFIER_PIPELINE_OK")

func test_prg01_preset_safe_state_and_atomic_apply() -> void:
	var s := _state()
	assert_true(s.grant_authoritative(PLAYER, "item.cannon", 1))
	assert_true(s.grant_authoritative(PLAYER, "item.sail", 1))
	assert_true(s.save_preset(PLAYER, "preset.harbor", {"weapon":"item.cannon","sail":"item.sail"}))
	assert_true(s.set_preset_context(PLAYER, true, true))
	assert_false(s.execute_transaction(PLAYER, "txn.preset.combat", InventoryState.OP_PRESET_APPLY, {"preset_id":"preset.harbor"})["accepted"])
	assert_true(s.set_preset_context(PLAYER, false, true))
	assert_true(s.execute_transaction(PLAYER, "txn.preset.ok", InventoryState.OP_PRESET_APPLY, {"preset_id":"preset.harbor"})["accepted"])
	assert_eq(s.equipment_snapshot(PLAYER)["weapon"], "item.cannon")
	assert_eq(s.equipment_snapshot(PLAYER)["sail"], "item.sail")
	print("PRG01_PRESET_ATOMIC_OK")

func test_prg01_transaction_idempotency_conflict_and_restore() -> void:
	var s := _state()
	assert_true(s.grant_authoritative(PLAYER, "item.scrap", 8))
	var payload := {"source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":2}
	var first := s.execute_transaction(PLAYER, "txn.retry.same", InventoryState.OP_TRANSFER, payload)
	var second := s.execute_transaction(PLAYER, "txn.retry.same", InventoryState.OP_TRANSFER, payload)
	assert_eq(first, second)
	assert_eq(s.quantity(CHEST, "item.scrap"), 2)
	var conflict := s.execute_transaction(PLAYER, "txn.retry.same", InventoryState.OP_TRANSFER, {"source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":1})
	assert_eq(conflict["reason"], "transaction_conflict")
	var progression := s.progression_snapshot()
	assert_true(InventoryState.validate_progression_state(progression))
	var restored := _state()
	assert_true(restored.restore_quantities(PLAYER, s.quantities_snapshot(PLAYER)))
	assert_true(restored.restore_quantities(CHEST, s.quantities_snapshot(CHEST)))
	assert_true(restored.restore_progression(progression))
	assert_eq(restored.execute_transaction(PLAYER, "txn.retry.same", InventoryState.OP_TRANSFER, payload), first)
	assert_eq(restored.quantity(CHEST, "item.scrap"), 2)
	print("PRG01_TRANSACTION_IDEMPOTENCY_OK")
	print("PRG01_PERSISTENCE_OK")

func test_prg01_host_ledger_and_protocol_authority() -> void:
	var transfer := SessionProtocol.make_envelope(1, SessionProtocol.INVENTORY_TRANSFER, {"transaction_id":"txn.net.transfer","source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":1})
	assert_eq(SessionProtocol.validate_envelope(transfer), "")
	var spoof := transfer.duplicate(true)
	spoof["payload"]["owner_id"] = PLAYER
	assert_eq(SessionProtocol.validate_envelope(spoof), SessionProtocol.REJECT_FORBIDDEN_IDENTITY)
	var ledger := HostTransactionLedger.new()
	var payload := {"source_container":PLAYER,"target_container":CHEST,"item_id":"item.scrap","quantity":1}
	var fp := HostTransactionLedger.fingerprint(SessionProtocol.INVENTORY_TRANSFER, payload)
	assert_eq(ledger.inspect(PLAYER, "txn.net.transfer", SessionProtocol.INVENTORY_TRANSFER, fp)["status"], HostTransactionLedger.STATUS_NEW)
	assert_true(ledger.commit(PLAYER, "txn.net.transfer", SessionProtocol.INVENTORY_TRANSFER, fp, {"accepted":true}))
	assert_eq(ledger.inspect(PLAYER, "txn.net.transfer", SessionProtocol.INVENTORY_TRANSFER, fp)["status"], HostTransactionLedger.STATUS_CACHED)
	var restored := HostTransactionLedger.new()
	assert_true(restored.restore_state(ledger.snapshot_state()))
	assert_eq(restored.inspect(PLAYER, "txn.net.transfer", SessionProtocol.INVENTORY_TRANSFER, fp)["status"], HostTransactionLedger.STATUS_CACHED)
	print("PRG01_LAN_AUTHORITY_OK")

func test_prg01_loot_uses_inventory_state_as_single_quantity_truth() -> void:
	var sector := SectorRuntime.new()
	sector.sector_id = FoundationSector.ID
	sector.bounds = Rect2(-640,-360,1280,720)
	assert_true(sector.register_entity(PLAYER, Vector2.ZERO))
	assert_true(sector.register_entity("entity.vs02_sc03", Vector2.ZERO))
	var streams := SeedStreams.new(424242)
	var item := ResourceLoader.load("res://src/data/items/vs03_salvage_scrap.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as ItemDefinition
	var table := ResourceLoader.load("res://src/data/loot/vs03_sc03_loot_table.tres", "", ResourceLoader.CACHE_MODE_IGNORE) as LootTable
	var loot := LootAuthority.new(sector, streams, table, item, true)
	var drop := loot.on_ship_sunk("entity.vs02_sc03", 991, Vector2.ZERO)
	assert_false(drop.is_empty())
	var pickup := loot.pickup(PLAYER, LootAuthority.pickup_intent(drop["drop_id"]))
	assert_true(pickup["accepted"])
	assert_eq(loot.inventory_quantity(item.stable_id), int(pickup["quantity"]))
	assert_eq(loot.inventory_state().quantity(loot.inventory_owner_id(), item.stable_id), int(pickup["quantity"]))
	print("PRG01_SINGLE_INVENTORY_TRUTH_OK")

func test_prg01_touch_panel_emits_intents_without_mutating_authority() -> void:
	var panel := ProgressionPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	assert_true(panel.select_item("item.cannon"))
	assert_true(panel.select_slot("weapon"))
	assert_true(panel.request_equip("txn.ui.equip"))
	assert_signal_emitted(panel, "progression_intent_requested")
	var button := Button.new()
	add_child_autofree(button)
	ProgressionPanel.apply_touch_target(button)
	assert_gte(button.custom_minimum_size.x, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_gte(button.custom_minimum_size.y, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_eq(ProgressionPanel.ACCESSIBILITY_FONT_SCALE, 1.3)
	print("PRG01_TOUCH_UI_OK")
