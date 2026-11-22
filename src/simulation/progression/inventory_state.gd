class_name InventoryState
extends RefCounted

const VERSION := 1
const MAX_QUANTITY := 2147483647
const MAX_ITEMS := 128
const MAX_EQUIPMENT_SLOTS := 16
const MAX_SOCKETS := 16
const MAX_PRESETS := 16
const MAX_TRANSACTIONS := 128
const SLOT_TYPES := ["weapon", "structure", "sail", "figurehead", "crew", "trainer", "pet"]
const GEM_CATEGORIES := ["ship_gem", "pet_gem"]
const OP_TRANSFER := "inventory_transfer"
const OP_EQUIP := "inventory_equip"
const OP_UNEQUIP := "inventory_unequip"
const OP_SOCKET_INSERT := "inventory_socket_insert"
const OP_SOCKET_UPGRADE := "inventory_socket_upgrade"
const OP_PRESET_APPLY := "inventory_preset_apply"

var _catalog: Dictionary = {}
var _containers: Dictionary = {}
var _equipment: Dictionary = {}
var _sockets: Dictionary = {}
var _presets: Dictionary = {}
var _transactions: Dictionary = {}
var _combat_locked: Dictionary = {}
var _safe_state: Dictionary = {}

func bind_owner(owner_id: String, max_slots: int = 64, max_weight: float = 1000000.0) -> bool:
	if not SectorIds.valid(owner_id) or max_slots <= 0 or max_slots > MAX_ITEMS or not is_finite(max_weight) or max_weight < 0.0 or _containers.has(owner_id):
		return false
	_containers[owner_id] = {"max_slots": max_slots, "max_weight": max_weight, "items": {}}
	_equipment[owner_id] = {}
	_sockets[owner_id] = {}
	_presets[owner_id] = {}
	return true

func reassign_owner(from_id: String, to_id: String) -> bool:
	if not _containers.has(from_id) or _containers.has(to_id) or not SectorIds.valid(to_id):
		return false
	_containers[to_id] = _containers[from_id]
	_containers.erase(from_id)
	_equipment[to_id] = _equipment.get(from_id, {})
	_equipment.erase(from_id)
	_sockets[to_id] = _sockets.get(from_id, {})
	_sockets.erase(from_id)
	_presets[to_id] = _presets.get(from_id, {})
	_presets.erase(from_id)
	return true

func register_item_definition(definition: ItemDefinition) -> bool:
	if definition == null or not definition.valid():
		return false
	return register_item_spec(definition.stable_id, definition.item_category, definition.stack_limit, definition.equip_slot, definition.weight, definition.stat_modifiers)

func register_item_spec(item_id: String, category: String, stack_limit: int, equip_slot: String = "", weight: float = 0.0, modifiers: Array[Dictionary] = []) -> bool:
	if not SectorIds.valid(item_id) or category.is_empty() or stack_limit <= 0 or stack_limit > MAX_QUANTITY or not is_finite(weight) or weight < 0.0:
		return false
	if not equip_slot.is_empty() and equip_slot not in SLOT_TYPES:
		return false
	if _catalog.has(item_id):
		return false
	for modifier in modifiers:
		if not _valid_modifier(modifier):
			return false
	_catalog[item_id] = {"category": category, "stack_limit": stack_limit, "equip_slot": equip_slot, "weight": weight, "modifiers": modifiers.duplicate(true)}
	return true

func has_item_spec(item_id: String) -> bool:
	return _catalog.has(item_id)

func quantity(owner_id: String, item_id: String) -> int:
	var container: Dictionary = _containers.get(owner_id, {})
	if container.is_empty():
		return 0
	return int((container["items"] as Dictionary).get(item_id, 0))

func quantities_snapshot(owner_id: String) -> Dictionary:
	var container: Dictionary = _containers.get(owner_id, {})
	return (container.get("items", {}) as Dictionary).duplicate(true) if not container.is_empty() else {}

func restore_quantities(owner_id: String, quantities: Dictionary) -> bool:
	if not _containers.has(owner_id) or quantities.size() > MAX_ITEMS:
		return false
	var next: Dictionary = {}
	for item_id in quantities:
		if not item_id is String or not _catalog.has(item_id) or not _integer(quantities[item_id]):
			return false
		var value := int(quantities[item_id])
		if value < 0 or value > int((_catalog[item_id] as Dictionary)["stack_limit"]):
			return false
		if value > 0:
			next[item_id] = value
	var probe: Dictionary = (_containers[owner_id] as Dictionary).duplicate(true)
	probe["items"] = next
	if not _container_within_limits(probe):
		return false
	_containers[owner_id] = probe
	return true

func can_add(owner_id: String, item_id: String, amount: int) -> bool:
	if not _containers.has(owner_id) or not _catalog.has(item_id) or amount <= 0:
		return false
	var clone := _containers.duplicate(true)
	return _add_to(clone, owner_id, item_id, amount)

func grant_authoritative(owner_id: String, item_id: String, amount: int) -> bool:
	var clone := _containers.duplicate(true)
	if not _add_to(clone, owner_id, item_id, amount):
		return false
	_containers = clone
	return true

func consume_authoritative(owner_id: String, item_id: String, amount: int) -> bool:
	var clone := _containers.duplicate(true)
	if not _remove_from(clone, owner_id, item_id, amount):
		return false
	_containers = clone
	return true

func configure_socket(owner_id: String, socket_id: String, socket_kind: String, max_level: int = 5) -> bool:
	if not _sockets.has(owner_id) or not SectorIds.valid(socket_id) or socket_kind not in GEM_CATEGORIES or max_level <= 0 or max_level > 32:
		return false
	var owner_sockets: Dictionary = _sockets[owner_id]
	if owner_sockets.has(socket_id) or owner_sockets.size() >= MAX_SOCKETS:
		return false
	owner_sockets[socket_id] = {"kind": socket_kind, "gem_id": "", "level": 0, "max_level": max_level}
	return true

func save_preset(owner_id: String, preset_id: String, slots: Dictionary) -> bool:
	if not _presets.has(owner_id) or not SectorIds.valid(preset_id) or slots.size() > MAX_EQUIPMENT_SLOTS:
		return false
	var normalized: Dictionary = {}
	for slot in slots:
		if not slot is String or slot not in SLOT_TYPES:
			return false
		var item_id := str(slots[slot])
		if not item_id.is_empty() and (not _catalog.has(item_id) or not _compatible_slot(item_id, str(slot))):
			return false
		normalized[slot] = item_id
	var owner_presets: Dictionary = _presets[owner_id]
	if not owner_presets.has(preset_id) and owner_presets.size() >= MAX_PRESETS:
		return false
	owner_presets[preset_id] = normalized
	return true

func set_preset_context(owner_id: String, in_combat: bool, safe_state: bool) -> bool:
	if not _containers.has(owner_id):
		return false
	_combat_locked[owner_id] = in_combat
	_safe_state[owner_id] = safe_state
	return true

func execute_transaction(actor_id: String, transaction_id: String, operation: String, payload: Dictionary) -> Dictionary:
	var base := {"accepted": false, "reason": "", "operation": operation}
	if not SectorIds.valid(actor_id) or not _valid_transaction_id(transaction_id) or not DtoContract.is_primitive_safe(payload):
		base["reason"] = "invalid_transaction"
		return base
	var fingerprint := (operation + "|" + JSON.stringify(_canonical(payload))).sha256_text()
	var key := actor_id + "|" + transaction_id
	if _transactions.has(key):
		var row: Dictionary = _transactions[key]
		if row["operation"] != operation or row["fingerprint"] != fingerprint:
			base["reason"] = "transaction_conflict"
			return base
		return (row["result"] as Dictionary).duplicate(true)
	if _transactions.size() >= MAX_TRANSACTIONS:
		base["reason"] = "transaction_ledger_full"
		return base
	var result := _execute_uncached(actor_id, operation, payload)
	_transactions[key] = {"actor_id": actor_id, "transaction_id": transaction_id, "operation": operation, "fingerprint": fingerprint, "result": result.duplicate(true)}
	return result

func equipment_snapshot(owner_id: String) -> Dictionary:
	return (_equipment.get(owner_id, {}) as Dictionary).duplicate(true)

func socket_snapshot(owner_id: String) -> Dictionary:
	return (_sockets.get(owner_id, {}) as Dictionary).duplicate(true)

func progression_snapshot() -> Dictionary:
	return {"version": VERSION, "equipment": _equipment.duplicate(true), "sockets": _sockets.duplicate(true), "presets": _presets.duplicate(true), "transactions": _transactions.duplicate(true)}

func restore_progression(value: Variant) -> bool:
	if not validate_progression_state(value, _catalog):
		return false
	var state: Dictionary = value
	for owner_id in state["equipment"]:
		if not _containers.has(owner_id):
			return false
	_equipment = (state["equipment"] as Dictionary).duplicate(true)
	_sockets = (state["sockets"] as Dictionary).duplicate(true)
	_presets = (state["presets"] as Dictionary).duplicate(true)
	_transactions = (state["transactions"] as Dictionary).duplicate(true)
	return true

static func validate_progression_state(value: Variant, catalog: Dictionary = {}) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 5 or int(state.get("version", 0)) != VERSION:
		return false
	for key in ["equipment", "sockets", "presets", "transactions"]:
		if not state.get(key) is Dictionary:
			return false
	if state["transactions"].size() > MAX_TRANSACTIONS:
		return false
	for owner_id in state["equipment"]:
		if not owner_id is String or not SectorIds.valid(owner_id):
			return false
		var slots: Variant = state["equipment"][owner_id]
		if not slots is Dictionary or slots.size() > MAX_EQUIPMENT_SLOTS:
			return false
		for slot in slots:
			if slot not in SLOT_TYPES or not slots[slot] is String or (not catalog.is_empty() and not catalog.has(slots[slot])):
				return false
	for owner_id in state["sockets"]:
		if not owner_id is String or not SectorIds.valid(owner_id) or not state["sockets"][owner_id] is Dictionary or state["sockets"][owner_id].size() > MAX_SOCKETS:
			return false
	for owner_id in state["presets"]:
		if not owner_id is String or not SectorIds.valid(owner_id) or not state["presets"][owner_id] is Dictionary or state["presets"][owner_id].size() > MAX_PRESETS:
			return false
	return true

func stat_value(owner_id: String, stat_id: String, base_value: float) -> float:
	var by_id: Dictionary = {}
	var slots: Dictionary = _equipment.get(owner_id, {})
	for slot in slots:
		_append_modifiers(by_id, str(slots[slot]), stat_id, "equip." + str(slot))
	var socket_rows: Dictionary = _sockets.get(owner_id, {})
	for socket_id in socket_rows:
		var row: Dictionary = socket_rows[socket_id]
		var gem_id := str(row.get("gem_id", ""))
		if not gem_id.is_empty():
			_append_modifiers(by_id, gem_id, stat_id, "socket." + str(socket_id))
	return StatModifierPipeline.apply_from_dictionary(base_value, by_id)

func _execute_uncached(actor_id: String, operation: String, payload: Dictionary) -> Dictionary:
	var result := {"accepted": false, "reason": "", "operation": operation}
	match operation:
		OP_TRANSFER:
			if not _exact(payload, ["source_container", "target_container", "item_id", "quantity"]):
				result["reason"] = "malformed_payload"
				return result
			var source := str(payload["source_container"])
			var target := str(payload["target_container"])
			var item_id := str(payload["item_id"])
			var amount := int(payload["quantity"]) if _integer(payload["quantity"]) else 0
			if actor_id != source:
				result["reason"] = "authority_mismatch"
				return result
			var clone := _containers.duplicate(true)
			if not _remove_from(clone, source, item_id, amount) or not _add_to(clone, target, item_id, amount):
				result["reason"] = "transfer_rejected"
				return result
			_containers = clone
		OP_EQUIP:
			if not _exact(payload, ["slot", "item_id"]):
				result["reason"] = "malformed_payload"
				return result
			if not _equip_atomic(actor_id, str(payload["slot"]), str(payload["item_id"])):
				result["reason"] = "equip_rejected"
				return result
		OP_UNEQUIP:
			if not _exact(payload, ["slot"]):
				result["reason"] = "malformed_payload"
				return result
			if not _unequip_atomic(actor_id, str(payload["slot"])):
				result["reason"] = "unequip_rejected"
				return result
		OP_SOCKET_INSERT:
			if not _exact(payload, ["socket_id", "item_id"]) or not _socket_insert_atomic(actor_id, str(payload["socket_id"]), str(payload["item_id"])):
				result["reason"] = "socket_rejected"
				return result
		OP_SOCKET_UPGRADE:
			if not _exact(payload, ["socket_id", "cost_item_id", "cost_quantity"]) or not _socket_upgrade_atomic(actor_id, str(payload["socket_id"]), str(payload["cost_item_id"]), int(payload["cost_quantity"]) if _integer(payload["cost_quantity"]) else 0):
				result["reason"] = "upgrade_rejected"
				return result
		OP_PRESET_APPLY:
			if not _exact(payload, ["preset_id"]):
				result["reason"] = "malformed_payload"
				return result
			if bool(_combat_locked.get(actor_id, false)) or not bool(_safe_state.get(actor_id, false)):
				result["reason"] = "preset_restricted"
				return result
			if not _preset_apply_atomic(actor_id, str(payload["preset_id"])):
				result["reason"] = "preset_rejected"
				return result
		_:
			result["reason"] = "unsupported_operation"
			return result
	result["accepted"] = true
	result["reason"] = ""
	return result

func _equip_atomic(owner_id: String, slot: String, item_id: String) -> bool:
	if not _containers.has(owner_id) or slot not in SLOT_TYPES or not _catalog.has(item_id) or not _compatible_slot(item_id, slot) or quantity(owner_id, item_id) <= 0:
		return false
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment.get(owner_id, {})
	var previous := str(slots.get(slot, ""))
	if not previous.is_empty() and not _add_to(containers, owner_id, previous, 1):
		return false
	if not _remove_from(containers, owner_id, item_id, 1):
		return false
	slots[slot] = item_id
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _unequip_atomic(owner_id: String, slot: String) -> bool:
	if not _equipment.has(owner_id) or slot not in SLOT_TYPES:
		return false
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment[owner_id]
	var previous := str(slots.get(slot, ""))
	if previous.is_empty() or not _add_to(containers, owner_id, previous, 1):
		return false
	slots.erase(slot)
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _socket_insert_atomic(owner_id: String, socket_id: String, item_id: String) -> bool:
	if not _sockets.has(owner_id) or not _catalog.has(item_id):
		return false
	var sockets := _sockets.duplicate(true)
	var rows: Dictionary = sockets[owner_id]
	if not rows.has(socket_id):
		return false
	var row: Dictionary = rows[socket_id]
	if not str(row.get("gem_id", "")).is_empty() or str((_catalog[item_id] as Dictionary)["category"]) != str(row["kind"]):
		return false
	var containers := _containers.duplicate(true)
	if not _remove_from(containers, owner_id, item_id, 1):
		return false
	row["gem_id"] = item_id
	row["level"] = 1
	rows[socket_id] = row
	sockets[owner_id] = rows
	_containers = containers
	_sockets = sockets
	return true

func _socket_upgrade_atomic(owner_id: String, socket_id: String, cost_item_id: String, cost_quantity: int) -> bool:
	if cost_quantity <= 0 or not _sockets.has(owner_id):
		return false
	var sockets := _sockets.duplicate(true)
	var rows: Dictionary = sockets[owner_id]
	if not rows.has(socket_id):
		return false
	var row: Dictionary = rows[socket_id]
	if str(row.get("gem_id", "")).is_empty() or int(row["level"]) >= int(row["max_level"]):
		return false
	var containers := _containers.duplicate(true)
	if not _remove_from(containers, owner_id, cost_item_id, cost_quantity):
		return false
	row["level"] = int(row["level"]) + 1
	rows[socket_id] = row
	sockets[owner_id] = rows
	_containers = containers
	_sockets = sockets
	return true

func _preset_apply_atomic(owner_id: String, preset_id: String) -> bool:
	var owner_presets: Dictionary = _presets.get(owner_id, {})
	if not owner_presets.has(preset_id):
		return false
	var target: Dictionary = owner_presets[preset_id]
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment.get(owner_id, {})
	for slot in target:
		var current := str(slots.get(slot, ""))
		var desired := str(target[slot])
		if current == desired:
			continue
		if not current.is_empty() and not _add_to(containers, owner_id, current, 1):
			return false
		if desired.is_empty():
			slots.erase(slot)
		else:
			if not _compatible_slot(desired, str(slot)) or not _remove_from(containers, owner_id, desired, 1):
				return false
			slots[slot] = desired
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _compatible_slot(item_id: String, slot: String) -> bool:
	if not _catalog.has(item_id):
		return false
	var spec: Dictionary = _catalog[item_id]
	var category := str(spec["category"])
	var required := str(spec["equip_slot"])
	if category == "companion":
		category = "pet"
	return required == slot or (required.is_empty() and category == slot)

func _add_to(containers: Dictionary, owner_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or not containers.has(owner_id) or not _catalog.has(item_id):
		return false
	var container: Dictionary = containers[owner_id]
	var items: Dictionary = container["items"]
	var current := int(items.get(item_id, 0))
	var limit := int((_catalog[item_id] as Dictionary)["stack_limit"])
	if current > limit - amount:
		return false
	items[item_id] = current + amount
	container["items"] = items
	if not _container_within_limits(container):
		return false
	containers[owner_id] = container
	return true

func _remove_from(containers: Dictionary, owner_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or not containers.has(owner_id):
		return false
	var container: Dictionary = containers[owner_id]
	var items: Dictionary = container["items"]
	var current := int(items.get(item_id, 0))
	if current < amount:
		return false
	var next := current - amount
	if next == 0:
		items.erase(item_id)
	else:
		items[item_id] = next
	container["items"] = items
	containers[owner_id] = container
	return true

func _container_within_limits(container: Dictionary) -> bool:
	var items: Dictionary = container["items"]
	if items.size() > int(container["max_slots"]):
		return false
	var weight := 0.0
	for item_id in items:
		if not _catalog.has(item_id):
			return false
		weight += float((_catalog[item_id] as Dictionary)["weight"]) * int(items[item_id])
	return weight <= float(container["max_weight"]) + 0.0001

func _append_modifiers(by_id: Dictionary, item_id: String, stat_id: String, source_prefix: String) -> void:
	if not _catalog.has(item_id):
		return
	var modifiers: Array = (_catalog[item_id] as Dictionary)["modifiers"]
	for index in modifiers.size():
		var row: Dictionary = modifiers[index]
		if str(row.get("stat", "")) != stat_id:
			continue
		var id := "%s.%s.%d" % [source_prefix, item_id, index]
		if not by_id.has(id):
			by_id[id] = {"operation": row["operation"], "value": row["value"], "priority": row.get("priority", 0)}

static func _valid_modifier(row: Dictionary) -> bool:
	return row.size() >= 3 and row.get("stat") is String and not str(row["stat"]).is_empty() and row.get("operation") in StatModifierPipeline.PHASE_ORDER and typeof(row.get("value")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(row["value"]))

static func _valid_transaction_id(value: String) -> bool:
	return value.begins_with("txn.") and value.length() <= 96 and SectorIds.valid(value)

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= float(MAX_QUANTITY)

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	return value
