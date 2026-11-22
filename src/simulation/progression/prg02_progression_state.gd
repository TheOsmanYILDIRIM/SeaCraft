class_name Prg02ProgressionState
extends RefCounted

const VERSION := 1
const MAX_CORE_SLOTS := 16
const MAX_UNLOCKS := 128
const MAX_EVENTS := 128
const MAX_DEFINITIONS := 128
const MAX_QUANTITY := 2147483647

const OP_CRAFT := "progression_craft"
const OP_SALVAGE := "progression_salvage"
const OP_UPGRADE := "progression_ship_upgrade"
const OP_CORE_INSERT := "progression_core_insert"
const OP_CORE_REMOVE := "progression_core_remove"
const OP_CORE_REPLACE := "progression_core_replace"
const OP_TROPHY_UNLOCK := "progression_trophy_unlock"
const OPERATIONS := [OP_CRAFT, OP_SALVAGE, OP_UPGRADE, OP_CORE_INSERT, OP_CORE_REMOVE, OP_CORE_REPLACE, OP_TROPHY_UNLOCK]

var _inventory
var _streams: SeedStreams
var _recipes: Dictionary = {}
var _salvage_tables: Dictionary = {}
var _upgrades: Dictionary = {}
var _trophies: Dictionary = {}

var _core_slots: Dictionary = {}
var _unlocked_upgrades: Dictionary = {}
var _trophy_unlocks: Dictionary = {}
var _trophy_events: Dictionary = {}

func _init(inventory = null, streams: SeedStreams = null) -> void:
	_inventory = inventory
	_streams = streams

static func supports_operation(operation: String) -> bool:
	return operation in OPERATIONS

func bind_owner(owner_id: String) -> bool:
	if _inventory == null or not SectorIds.valid(owner_id):
		return false
	if not _core_slots.has(owner_id):
		_core_slots[owner_id] = {}
	if not _unlocked_upgrades.has(owner_id):
		_unlocked_upgrades[owner_id] = {}
	if not _trophy_unlocks.has(owner_id):
		_trophy_unlocks[owner_id] = {}
	if not _trophy_events.has(owner_id):
		_trophy_events[owner_id] = {}
	return true

func reassign_owner(from_id: String, to_id: String) -> bool:
	if not SectorIds.valid(from_id) or not SectorIds.valid(to_id):
		return false
	for store in [_core_slots, _unlocked_upgrades, _trophy_unlocks, _trophy_events]:
		if store.has(to_id):
			return false
	for store in [_core_slots, _unlocked_upgrades, _trophy_unlocks, _trophy_events]:
		if store.has(from_id):
			store[to_id] = store[from_id]
			store.erase(from_id)
	return true

func register_recipe(definition: RecipeDefinition) -> bool:
	if definition == null or not definition.valid() or _definitions_full() or _recipes.has(definition.stable_id):
		return false
	for row in definition.inputs + definition.outputs:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_recipes[definition.stable_id] = definition
	return true

func register_salvage_table(definition: SalvageTable) -> bool:
	if definition == null or not definition.valid() or _definitions_full() or _salvage_tables.has(definition.stable_id):
		return false
	for item_id in definition.source_item_ids:
		if not _inventory.has_item_spec(item_id):
			return false
	for row in definition.entries:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_salvage_tables[definition.stable_id] = definition
	return true

func register_upgrade(definition: ShipUpgradeDefinition) -> bool:
	if definition == null or not definition.valid() or _definitions_full() or _upgrades.has(definition.stable_id):
		return false
	for row in definition.costs:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_upgrades[definition.stable_id] = definition
	return true

func register_trophy(definition: TrophyDefinition) -> bool:
	if definition == null or not definition.valid() or _definitions_full() or _trophies.has(definition.stable_id):
		return false
	for row in definition.rewards:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_trophies[definition.stable_id] = definition
	return true

func validate_catalog() -> String:
	for recipe_id in _recipes:
		var recipe := _recipes[recipe_id] as RecipeDefinition
		for requirement in recipe.prerequisite_ids:
			if not _requirement_exists(requirement):
				return "missing_recipe_prerequisite"
	for trophy_id in _trophies:
		var trophy := _trophies[trophy_id] as TrophyDefinition
		for requirement in trophy.prerequisite_ids:
			if not _requirement_exists(requirement):
				return "missing_trophy_prerequisite"
	for upgrade_id in _upgrades:
		var upgrade := _upgrades[upgrade_id] as ShipUpgradeDefinition
		for requirement in upgrade.prerequisite_ids:
			if not _upgrades.has(requirement):
				return "missing_upgrade_prerequisite"
	var colors: Dictionary = {}
	for upgrade_id in _sorted_keys(_upgrades):
		if _visit_upgrade(str(upgrade_id), colors):
			return "upgrade_cycle"
	for upgrade_id in _upgrades:
		var upgrade := _upgrades[upgrade_id] as ShipUpgradeDefinition
		for requirement in upgrade.prerequisite_ids:
			var prerequisite := _upgrades[requirement] as ShipUpgradeDefinition
			if prerequisite.tier >= upgrade.tier:
				return "upgrade_tier_regression"
	var sources: Dictionary = {}
	for upgrade_id in _upgrades:
		for row in (_upgrades[upgrade_id] as ShipUpgradeDefinition).modifiers:
			if sources.has(str(row["source_id"])):
				return "duplicate_modifier_source"
			sources[str(row["source_id"])] = true
	for trophy_id in _trophies:
		for row in (_trophies[trophy_id] as TrophyDefinition).modifiers:
			if sources.has(str(row["source_id"])):
				return "duplicate_modifier_source"
			sources[str(row["source_id"])] = true
	return ""

func configure_core_slot(owner_id: String, slot_id: String, slot_type: String, allowed_core_type: String) -> bool:
	if not _ensure_owner(owner_id) or not SectorIds.valid(slot_id) or slot_type.is_empty() or allowed_core_type.is_empty():
		return false
	if slot_type.length() > 64 or allowed_core_type.length() > 64:
		return false
	var slots: Dictionary = _core_slots[owner_id]
	if slots.has(slot_id) or slots.size() >= MAX_CORE_SLOTS:
		return false
	slots[slot_id] = {"slot_type": slot_type, "allowed_core_type": allowed_core_type, "core_id": ""}
	return true

func execute(actor_id: String, operation: String, payload: Dictionary) -> Dictionary:
	if not supports_operation(operation) or not _ensure_owner(actor_id):
		return _reject(operation, "progression_unavailable")
	var catalog_error := validate_catalog()
	if not catalog_error.is_empty():
		return _reject(operation, catalog_error)
	match operation:
		OP_CRAFT:
			return _craft(actor_id, payload)
		OP_SALVAGE:
			return _salvage(actor_id, payload)
		OP_UPGRADE:
			return _upgrade(actor_id, payload)
		OP_CORE_INSERT:
			return _core_insert(actor_id, payload)
		OP_CORE_REMOVE:
			return _core_remove(actor_id, payload)
		OP_CORE_REPLACE:
			return _core_replace(actor_id, payload)
		OP_TROPHY_UNLOCK:
			return _trophy_unlock(actor_id, payload)
	return _reject(operation, "unsupported_operation")

func append_stat_modifiers(owner_id: String, stat_id: String, target: Dictionary) -> void:
	if not _ensure_owner(owner_id):
		return
	var upgrades: Dictionary = _unlocked_upgrades[owner_id]
	for upgrade_id in _sorted_keys(upgrades):
		if _upgrades.has(upgrade_id):
			for row in (_upgrades[upgrade_id] as ShipUpgradeDefinition).modifiers:
				_append_content_modifier(target, row, stat_id)
	var trophies: Dictionary = _trophy_unlocks[owner_id]
	for trophy_id in _sorted_keys(trophies):
		if _trophies.has(trophy_id):
			for row in (_trophies[trophy_id] as TrophyDefinition).modifiers:
				_append_content_modifier(target, row, stat_id)
	var slots: Dictionary = _core_slots[owner_id]
	for slot_id in _sorted_keys(slots):
		var core_id := str((slots[slot_id] as Dictionary).get("core_id", ""))
		if core_id.is_empty():
			continue
		var spec: Dictionary = _inventory.item_spec(core_id)
		var modifiers: Array = spec.get("modifiers", [])
		for index in modifiers.size():
			var row: Dictionary = modifiers[index]
			if str(row.get("stat", "")) != stat_id:
				continue
			var source_id := "core.%s.%d" % [core_id, index]
			if not target.has(source_id):
				target[source_id] = {"operation": row["operation"], "value": row["value"], "priority": row.get("priority", 0)}

func snapshot_state() -> Dictionary:
	return {
		"version": VERSION,
		"core_slots": _core_slots.duplicate(true),
		"unlocked_upgrades": _unlocked_upgrades.duplicate(true),
		"trophy_unlocks": _trophy_unlocks.duplicate(true),
		"trophy_events": _trophy_events.duplicate(true),
	}

func restore_state(value: Variant) -> bool:
	if not validate_state(value):
		return false
	var state: Dictionary = value
	for owner_id in state["core_slots"]:
		if not _inventory.has_owner(str(owner_id)):
			return false
		for slot_id in (state["core_slots"][owner_id] as Dictionary):
			var core_id := str((state["core_slots"][owner_id][slot_id] as Dictionary).get("core_id", ""))
			if not core_id.is_empty() and not _inventory.has_item_spec(core_id):
				return false
	for owner_id in state["unlocked_upgrades"]:
		if not _inventory.has_owner(str(owner_id)):
			return false
		for upgrade_id in (state["unlocked_upgrades"][owner_id] as Dictionary):
			if not _upgrades.has(upgrade_id):
				return false
	for owner_id in state["trophy_unlocks"]:
		if not _inventory.has_owner(str(owner_id)):
			return false
		for trophy_id in (state["trophy_unlocks"][owner_id] as Dictionary):
			if not _trophies.has(trophy_id):
				return false
	for owner_id in state["trophy_events"]:
		if not _inventory.has_owner(str(owner_id)):
			return false
		for event_id in (state["trophy_events"][owner_id] as Dictionary):
			if not _trophies.has(str(state["trophy_events"][owner_id][event_id])):
				return false
	_core_slots = (state["core_slots"] as Dictionary).duplicate(true)
	_unlocked_upgrades = (state["unlocked_upgrades"] as Dictionary).duplicate(true)
	_trophy_unlocks = (state["trophy_unlocks"] as Dictionary).duplicate(true)
	_trophy_events = (state["trophy_events"] as Dictionary).duplicate(true)
	return true

static func empty_state() -> Dictionary:
	return {"version": VERSION, "core_slots": {}, "unlocked_upgrades": {}, "trophy_unlocks": {}, "trophy_events": {}}

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 5 or int(state.get("version", 0)) != VERSION:
		return false
	for key in ["core_slots", "unlocked_upgrades", "trophy_unlocks", "trophy_events"]:
		if not state.get(key) is Dictionary:
			return false
	if state["core_slots"].size() > 32 or state["unlocked_upgrades"].size() > 32 or state["trophy_unlocks"].size() > 32 or state["trophy_events"].size() > 32:
		return false
	for owner_id in state["core_slots"]:
		if not owner_id is String or not SectorIds.valid(owner_id):
			return false
		var slots: Dictionary = state["core_slots"][owner_id]
		if slots.size() > MAX_CORE_SLOTS:
			return false
		for slot_id in slots:
			if not slot_id is String or not SectorIds.valid(slot_id) or not slots[slot_id] is Dictionary:
				return false
			var row: Dictionary = slots[slot_id]
			if row.size() != 3 or not row.get("slot_type") is String or not row.get("allowed_core_type") is String or not row.get("core_id") is String:
				return false
			if str(row["slot_type"]).is_empty() or str(row["allowed_core_type"]).is_empty():
				return false
			var core_id := str(row["core_id"])
			if not core_id.is_empty() and not SectorIds.valid(core_id):
				return false
	for key in ["unlocked_upgrades", "trophy_unlocks"]:
		for owner_id in state[key]:
			if not owner_id is String or not SectorIds.valid(owner_id) or not state[key][owner_id] is Dictionary:
				return false
			var rows: Dictionary = state[key][owner_id]
			if rows.size() > MAX_UNLOCKS:
				return false
			for stable_id in rows:
				if not stable_id is String or not SectorIds.valid(stable_id) or rows[stable_id] != true:
					return false
	for owner_id in state["trophy_events"]:
		if not owner_id is String or not SectorIds.valid(owner_id) or not state["trophy_events"][owner_id] is Dictionary:
			return false
		var events: Dictionary = state["trophy_events"][owner_id]
		if events.size() > MAX_EVENTS:
			return false
		for event_id in events:
			if not event_id is String or not SectorIds.valid(event_id) or not events[event_id] is String or not SectorIds.valid(events[event_id]):
				return false
	return true

static func validate_content_refs(value: Variant, registry: DefinitionRegistry) -> bool:
	if registry == null or not validate_state(value):
		return false
	var state: Dictionary = value
	for owner_id in state["core_slots"]:
		for slot_id in (state["core_slots"][owner_id] as Dictionary):
			var core_id := str((state["core_slots"][owner_id][slot_id] as Dictionary)["core_id"])
			if not core_id.is_empty() and not registry.matches_type(core_id, "item"):
				return false
	for owner_id in state["unlocked_upgrades"]:
		for upgrade_id in (state["unlocked_upgrades"][owner_id] as Dictionary):
			if not registry.matches_type(str(upgrade_id), "ship_upgrade"):
				return false
	for owner_id in state["trophy_unlocks"]:
		for trophy_id in (state["trophy_unlocks"][owner_id] as Dictionary):
			if not registry.matches_type(str(trophy_id), "trophy"):
				return false
	for owner_id in state["trophy_events"]:
		for event_id in (state["trophy_events"][owner_id] as Dictionary):
			if not registry.matches_type(str(state["trophy_events"][owner_id][event_id]), "trophy"):
				return false
	return true

func _craft(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["recipe_id", "count"]):
		return _reject(OP_CRAFT, "malformed_payload")
	var recipe_id := str(payload["recipe_id"])
	if not _recipes.has(recipe_id) or not _integer(payload["count"]):
		return _reject(OP_CRAFT, "invalid_recipe")
	var recipe := _recipes[recipe_id] as RecipeDefinition
	var count := int(payload["count"])
	if count <= 0 or count > recipe.max_craft_count:
		return _reject(OP_CRAFT, "craft_count_out_of_bounds")
	if not _requirements_met(owner_id, recipe.prerequisite_ids):
		return _reject(OP_CRAFT, "prerequisite_missing")
	var deltas: Dictionary = {}
	for row in recipe.inputs:
		var amount := _product(int(row["quantity"]), count)
		var item_id := str(row["item_id"])
		if amount <= 0 or _inventory.quantity(owner_id, item_id) < amount or not _add_delta(deltas, item_id, -amount):
			return _reject(OP_CRAFT, "missing_input")
	var outputs: Dictionary = {}
	for row in recipe.outputs:
		var amount := _product(int(row["quantity"]), count)
		var item_id := str(row["item_id"])
		if amount <= 0 or not _add_delta(deltas, item_id, amount):
			return _reject(OP_CRAFT, "quantity_overflow")
		outputs[item_id] = amount
	if not _inventory.can_apply_item_deltas(owner_id, deltas):
		return _reject(OP_CRAFT, "output_capacity")
	if not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_CRAFT, "atomic_commit_failed")
	return {"accepted": true, "reason": "", "operation": OP_CRAFT, "recipe_id": recipe_id, "count": count}

func _salvage(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["table_id", "source_item_id"]):
		return _reject(OP_SALVAGE, "malformed_payload")
	var table_id := str(payload["table_id"])
	var source_item_id := str(payload["source_item_id"])
	if _streams == null or not _salvage_tables.has(table_id) or not _inventory.has_item_spec(source_item_id):
		return _reject(OP_SALVAGE, "invalid_salvage")
	var table := _salvage_tables[table_id] as SalvageTable
	var spec: Dictionary = _inventory.item_spec(source_item_id)
	if not table.source_item_ids.has(source_item_id) and not table.source_categories.has(str(spec.get("category", ""))):
		return _reject(OP_SALVAGE, "source_not_allowed")
	if _inventory.item_equipped(owner_id, source_item_id):
		return _reject(OP_SALVAGE, "source_equipped")
	if _inventory.quantity(owner_id, source_item_id) < table.consume_quantity:
		return _reject(OP_SALVAGE, "missing_source")
	var rng_before := _streams.snapshot_state()
	var reward := _roll_salvage(table)
	if reward.is_empty():
		_streams.restore_state(rng_before)
		return _reject(OP_SALVAGE, "invalid_reward")
	var deltas := {source_item_id: -table.consume_quantity}
	if not _add_delta(deltas, str(reward["item_id"]), int(reward["quantity"])):
		_streams.restore_state(rng_before)
		return _reject(OP_SALVAGE, "quantity_overflow")
	if not _inventory.can_apply_item_deltas(owner_id, deltas):
		_streams.restore_state(rng_before)
		return _reject(OP_SALVAGE, "output_capacity")
	if not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		_streams.restore_state(rng_before)
		return _reject(OP_SALVAGE, "atomic_commit_failed")
	return {"accepted": true, "reason": "", "operation": OP_SALVAGE, "table_id": table_id, "source_item_id": source_item_id, "item_id": reward["item_id"], "quantity": reward["quantity"]}

func _upgrade(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["upgrade_id"]):
		return _reject(OP_UPGRADE, "malformed_payload")
	var upgrade_id := str(payload["upgrade_id"])
	if not _upgrades.has(upgrade_id):
		return _reject(OP_UPGRADE, "invalid_upgrade")
	var unlocked: Dictionary = _unlocked_upgrades[owner_id]
	if unlocked.has(upgrade_id):
		return _reject(OP_UPGRADE, "already_unlocked")
	var definition := _upgrades[upgrade_id] as ShipUpgradeDefinition
	if not _requirements_met(owner_id, definition.prerequisite_ids):
		return _reject(OP_UPGRADE, "prerequisite_missing")
	var deltas: Dictionary = {}
	for row in definition.costs:
		var item_id := str(row["item_id"])
		var amount := int(row["quantity"])
		if _inventory.quantity(owner_id, item_id) < amount or not _add_delta(deltas, item_id, -amount):
			return _reject(OP_UPGRADE, "missing_cost")
	var next_slots: Dictionary = (_core_slots[owner_id] as Dictionary).duplicate(true)
	for row in definition.core_slots:
		var slot_id := str(row["slot_id"])
		if next_slots.has(slot_id) or next_slots.size() >= MAX_CORE_SLOTS:
			return _reject(OP_UPGRADE, "core_slot_conflict")
		next_slots[slot_id] = {"slot_type": row["slot_type"], "allowed_core_type": row["allowed_core_type"], "core_id": ""}
	if not _inventory.can_apply_item_deltas(owner_id, deltas):
		return _reject(OP_UPGRADE, "cost_rejected")
	if not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_UPGRADE, "atomic_commit_failed")
	unlocked[upgrade_id] = true
	_unlocked_upgrades[owner_id] = unlocked
	_core_slots[owner_id] = next_slots
	return {"accepted": true, "reason": "", "operation": OP_UPGRADE, "upgrade_id": upgrade_id}

func _core_insert(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["slot_id", "item_id"]):
		return _reject(OP_CORE_INSERT, "malformed_payload")
	var slot_id := str(payload["slot_id"])
	var item_id := str(payload["item_id"])
	var check := _core_candidate_error(owner_id, slot_id, item_id, "")
	if not check.is_empty():
		return _reject(OP_CORE_INSERT, check)
	var slots: Dictionary = _core_slots[owner_id]
	if not str((slots[slot_id] as Dictionary)["core_id"]).is_empty():
		return _reject(OP_CORE_INSERT, "slot_occupied")
	if _inventory.quantity(owner_id, item_id) < 1 or not _inventory.apply_item_deltas_atomic(owner_id, {item_id: -1}):
		return _reject(OP_CORE_INSERT, "missing_core")
	var row: Dictionary = slots[slot_id]
	row["core_id"] = item_id
	slots[slot_id] = row
	return {"accepted": true, "reason": "", "operation": OP_CORE_INSERT, "slot_id": slot_id, "item_id": item_id}

func _core_remove(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["slot_id"]):
		return _reject(OP_CORE_REMOVE, "malformed_payload")
	var slot_id := str(payload["slot_id"])
	var slots: Dictionary = _core_slots[owner_id]
	if not slots.has(slot_id):
		return _reject(OP_CORE_REMOVE, "invalid_core_slot")
	var row: Dictionary = slots[slot_id]
	var item_id := str(row.get("core_id", ""))
	if item_id.is_empty():
		return _reject(OP_CORE_REMOVE, "slot_empty")
	if not _inventory.can_apply_item_deltas(owner_id, {item_id: 1}):
		return _reject(OP_CORE_REMOVE, "output_capacity")
	if not _inventory.apply_item_deltas_atomic(owner_id, {item_id: 1}):
		return _reject(OP_CORE_REMOVE, "atomic_commit_failed")
	row["core_id"] = ""
	slots[slot_id] = row
	return {"accepted": true, "reason": "", "operation": OP_CORE_REMOVE, "slot_id": slot_id, "item_id": item_id}

func _core_replace(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["slot_id", "item_id"]):
		return _reject(OP_CORE_REPLACE, "malformed_payload")
	var slot_id := str(payload["slot_id"])
	var item_id := str(payload["item_id"])
	var slots: Dictionary = _core_slots[owner_id]
	if not slots.has(slot_id):
		return _reject(OP_CORE_REPLACE, "invalid_core_slot")
	var row: Dictionary = slots[slot_id]
	var old_id := str(row.get("core_id", ""))
	if old_id.is_empty():
		return _reject(OP_CORE_REPLACE, "slot_empty")
	if old_id == item_id:
		return {"accepted": true, "reason": "", "operation": OP_CORE_REPLACE, "slot_id": slot_id, "item_id": item_id}
	var check := _core_candidate_error(owner_id, slot_id, item_id, slot_id)
	if not check.is_empty():
		return _reject(OP_CORE_REPLACE, check)
	if _inventory.quantity(owner_id, item_id) < 1:
		return _reject(OP_CORE_REPLACE, "missing_core")
	var deltas := {old_id: 1, item_id: -1}
	if not _inventory.can_apply_item_deltas(owner_id, deltas):
		return _reject(OP_CORE_REPLACE, "output_capacity")
	if not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_CORE_REPLACE, "atomic_commit_failed")
	row["core_id"] = item_id
	slots[slot_id] = row
	return {"accepted": true, "reason": "", "operation": OP_CORE_REPLACE, "slot_id": slot_id, "item_id": item_id, "previous_item_id": old_id}

func _trophy_unlock(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["trophy_id", "event_key"]):
		return _reject(OP_TROPHY_UNLOCK, "malformed_payload")
	var trophy_id := str(payload["trophy_id"])
	var event_key := str(payload["event_key"])
	if not _trophies.has(trophy_id):
		return _reject(OP_TROPHY_UNLOCK, "invalid_trophy")
	var definition := _trophies[trophy_id] as TrophyDefinition
	if definition.event_key != event_key:
		return _reject(OP_TROPHY_UNLOCK, "event_mismatch")
	var events: Dictionary = _trophy_events[owner_id]
	if events.has(event_key):
		return _reject(OP_TROPHY_UNLOCK, "event_already_processed")
	var unlocks: Dictionary = _trophy_unlocks[owner_id]
	if unlocks.has(trophy_id):
		return _reject(OP_TROPHY_UNLOCK, "already_unlocked")
	if not _requirements_met(owner_id, definition.prerequisite_ids):
		return _reject(OP_TROPHY_UNLOCK, "prerequisite_missing")
	var deltas: Dictionary = {}
	var rewards: Dictionary = {}
	for row in definition.rewards:
		var item_id := str(row["item_id"])
		var amount := int(row["quantity"])
		if not _add_delta(deltas, item_id, amount):
			return _reject(OP_TROPHY_UNLOCK, "quantity_overflow")
		rewards[item_id] = amount
	if not _inventory.can_apply_item_deltas(owner_id, deltas):
		return _reject(OP_TROPHY_UNLOCK, "reward_capacity")
	if not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_TROPHY_UNLOCK, "atomic_commit_failed")
	unlocks[trophy_id] = true
	events[event_key] = trophy_id
	return {"accepted": true, "reason": "", "operation": OP_TROPHY_UNLOCK, "trophy_id": trophy_id, "event_key": event_key}

func _core_candidate_error(owner_id: String, slot_id: String, item_id: String, ignore_slot: String) -> String:
	var slots: Dictionary = _core_slots[owner_id]
	if not slots.has(slot_id) or not _inventory.has_item_spec(item_id):
		return "invalid_core_slot"
	var spec: Dictionary = _inventory.item_spec(item_id)
	if str(spec.get("category", "")) != "core":
		return "item_not_core"
	var row: Dictionary = slots[slot_id]
	if str(spec.get("core_type", "")) != str(row["allowed_core_type"]):
		return "core_incompatible"
	if bool(spec.get("core_unique", false)):
		for other_slot in slots:
			if str(other_slot) == ignore_slot:
				continue
			if str((slots[other_slot] as Dictionary).get("core_id", "")) == item_id:
				return "core_unique_conflict"
	return ""

func _roll_salvage(table: SalvageTable) -> Dictionary:
	var total := 0
	for row in table.entries:
		total += int(row["weight"])
	var roll := _streams.next_int(SeedStreams.STREAM_LOOT, 1, total)
	var cursor := 0
	for row in table.entries:
		cursor += int(row["weight"])
		if roll <= cursor:
			return {
				"item_id": str(row["item_id"]),
				"quantity": _streams.next_int(SeedStreams.STREAM_LOOT, int(row["min_quantity"]), int(row["max_quantity"])),
			}
	return {}

func _requirements_met(owner_id: String, requirements: PackedStringArray) -> bool:
	var upgrades: Dictionary = _unlocked_upgrades.get(owner_id, {})
	var trophies: Dictionary = _trophy_unlocks.get(owner_id, {})
	for requirement in requirements:
		if _upgrades.has(requirement):
			if not upgrades.has(requirement):
				return false
		elif _trophies.has(requirement):
			if not trophies.has(requirement):
				return false
		else:
			return false
	return true

func _requirement_exists(requirement: String) -> bool:
	return _upgrades.has(requirement) or _trophies.has(requirement)

func _visit_upgrade(upgrade_id: String, colors: Dictionary) -> bool:
	var color := int(colors.get(upgrade_id, 0))
	if color == 1:
		return true
	if color == 2:
		return false
	colors[upgrade_id] = 1
	var definition := _upgrades[upgrade_id] as ShipUpgradeDefinition
	for requirement in definition.prerequisite_ids:
		if _upgrades.has(requirement) and _visit_upgrade(requirement, colors):
			return true
	colors[upgrade_id] = 2
	return false

func _ensure_owner(owner_id: String) -> bool:
	if _inventory == null or not _inventory.has_owner(owner_id):
		return false
	return bind_owner(owner_id)

func _definitions_full() -> bool:
	return _recipes.size() + _salvage_tables.size() + _upgrades.size() + _trophies.size() >= MAX_DEFINITIONS

static func _reject(operation: String, reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "operation": operation}

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _integer(value: Variant) -> bool:
	return value is int and int(value) >= -MAX_QUANTITY and int(value) <= MAX_QUANTITY

static func _product(left: int, right: int) -> int:
	if left <= 0 or right <= 0 or left > MAX_QUANTITY / right:
		return -1
	return left * right

static func _add_delta(deltas: Dictionary, item_id: String, amount: int) -> bool:
	if not SectorIds.valid(item_id) or amount == 0:
		return false
	var current := int(deltas.get(item_id, 0))
	if amount > 0 and current > MAX_QUANTITY - amount:
		return false
	if amount < 0 and current < -MAX_QUANTITY - amount:
		return false
	var next := current + amount
	if next == 0:
		deltas.erase(item_id)
	else:
		deltas[item_id] = next
	return true

static func _sorted_keys(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys

static func _append_content_modifier(target: Dictionary, row: Dictionary, stat_id: String) -> void:
	if str(row.get("stat", "")) != stat_id:
		return
	var source_id := str(row.get("source_id", ""))
	if source_id.is_empty() or target.has(source_id):
		return
	target[source_id] = {"operation": row["operation"], "value": row["value"], "priority": row.get("priority", 0)}
