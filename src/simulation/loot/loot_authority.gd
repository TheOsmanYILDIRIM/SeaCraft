class_name LootAuthority
extends RefCounted

signal drop_created(drop: Dictionary)
signal drop_claimed(drop_id: String, item_id: String, quantity: int)

const PICKUP := "pickup_loot"
const PICKUP_RADIUS := 96.0
const MAX_QUANTITY := 2147483647

var _sector: SectorRuntime
var _streams: SeedStreams
var _table: LootTable
var _item: ItemDefinition
var _authority_enabled := true
var _drops: Dictionary = {}
var _claimed: Dictionary = {}
var _inventory: Dictionary = {}
var _extra_inventory_ids: Dictionary = {}
var _inventory_owner := ""
var _reserved_by_item: Dictionary = {}
var _processed_events: Dictionary = {}
var _query_candidates: Array[String] = []
var _last_query_inspected := 0


func _init(sector: SectorRuntime, streams: SeedStreams, table: LootTable, item: ItemDefinition, authority_enabled: bool = true) -> void:
	_sector = sector
	_streams = streams
	_table = table
	_item = item
	_authority_enabled = authority_enabled


func on_ship_sunk(entity_id: String, sequence_id: int, position: Vector2) -> Dictionary:
	if not _authority_enabled or _sector == null or _streams == null or _table == null or _item == null:
		return {}
	if not SectorIds.valid(entity_id) or sequence_id <= 0 or not position.is_finite() or not _sector.bounds.has_point(position):
		return {}
	if not _table.valid() or not _valid_item(_item.stable_id):
		return {}
	var event_id := _event_id(entity_id, sequence_id)
	if _processed_events.has(event_id):
		return {}
	_processed_events[event_id] = ""
	var result := _table.roll(_streams)
	if result.is_empty() or result["item_id"] != _item.stable_id or not _valid_quantity(result["quantity"]):
		return {}
	var drop_id := _drop_id(entity_id, sequence_id)
	if _drops.has(drop_id) or _claimed.has(drop_id) or not _sector.register_entity(drop_id, position):
		return {}
	var drop := {
		"drop_id": drop_id,
		"sector_id": _sector.sector_id,
		"x": position.x,
		"y": position.y,
		"item_id": result["item_id"],
		"quantity": result["quantity"],
	}
	_drops[drop_id] = drop
	_processed_events[event_id] = drop_id
	drop_created.emit(drop.duplicate(true))
	return drop.duplicate(true)


func pickup(player_id: String, command: Dictionary) -> Dictionary:
	var result := {"accepted": false, "reason": "", "drop_id": "", "item_id": "", "quantity": 0}
	var drop_value: Variant = command.get("drop_id")
	if command.size() != 3 or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY or command.get("type") != PICKUP or not drop_value is String:
		result["reason"] = "malformed_command"
		return result
	var drop_id: String = drop_value
	result["drop_id"] = drop_id
	if not _authority_enabled:
		result["reason"] = "authority_disabled"
		return result
	if _claimed.has(drop_id):
		result["reason"] = "already_claimed"
		return result
	var drop: Dictionary = _drops.get(drop_id, {})
	if drop.is_empty():
		result["reason"] = "drop_not_found"
		return result
	if _sector == null or drop.get("sector_id") != _sector.sector_id:
		result["reason"] = "wrong_sector"
		return result
	var player_position := _sector.entity_position(player_id)
	var drop_position := Vector2(drop["x"], drop["y"])
	if not _inventory_owner.is_empty() and player_id != _inventory_owner:
		result["reason"] = "inventory_owner_mismatch"
		return result
	if not player_position.is_finite() or player_position.distance_to(drop_position) > PICKUP_RADIUS:
		result["reason"] = "out_of_range"
		return result
	var item_id: String = drop.get("item_id", "")
	var quantity: Variant = drop.get("quantity")
	if not _valid_item(item_id):
		result["reason"] = "invalid_item"
		return result
	if not quantity is int or not _valid_quantity(quantity):
		result["reason"] = "invalid_quantity"
		return result
	var current: int = _inventory.get(item_id, 0)
	if current < 0 or current > MAX_QUANTITY - quantity:
		result["reason"] = "quantity_overflow"
		return result
	_claimed[drop_id] = true
	_inventory[item_id] = current + quantity
	_drops.erase(drop_id)
	_sector.remove_entity(drop_id)
	result["accepted"] = true
	result["item_id"] = item_id
	result["quantity"] = quantity
	drop_claimed.emit(drop_id, item_id, quantity)
	return result


func nearest_pickup(player_id: String) -> String:
	_last_query_inspected = 0
	if _sector == null:
		return ""
	var center := _sector.entity_position(player_id)
	if not center.is_finite():
		return ""
	_last_query_inspected = _sector.spatial.query_radius(center, PICKUP_RADIUS, _query_candidates)
	var best := ""
	var best_distance := INF
	for id in _query_candidates:
		if not _drops.has(id):
			continue
		var drop: Dictionary = _drops[id]
		var distance := center.distance_squared_to(Vector2(drop["x"], drop["y"]))
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best.is_empty() or id < best)):
			best = id
			best_distance = distance
	return best


func snapshot_state() -> Dictionary:
	var drops: Array = []
	var ids := _drops.keys()
	ids.sort()
	for id in ids:
		drops.append((_drops[id] as Dictionary).duplicate(true))
	var claimed_ids := _claimed.keys()
	claimed_ids.sort()
	var events: Dictionary = {}
	var event_ids := _processed_events.keys()
	event_ids.sort()
	for event_id in event_ids:
		events[event_id] = _processed_events[event_id]
	return {"drops": drops, "claimed_ids": claimed_ids, "inventory": _inventory.duplicate(true), "processed_events": events}


func restore_state(value: Variant) -> bool:
	if not validate_state(value):
		return false
	for id in _drops:
		if _sector != null:
			_sector.remove_entity(id)
	_drops.clear()
	_claimed.clear()
	_inventory.clear()
	_processed_events.clear()
	var state: Dictionary = value
	for id in state["claimed_ids"]:
		_claimed[id] = true
	for item_id in state["inventory"]:
		_inventory[item_id] = int(state["inventory"][item_id])
	for event_id in state["processed_events"]:
		_processed_events[event_id] = state["processed_events"][event_id]
	for raw in state["drops"]:
		var drop: Dictionary = raw.duplicate(true)
		drop["quantity"] = int(drop["quantity"])
		var id: String = drop["drop_id"]
		_drops[id] = drop
		if _sector != null and drop["sector_id"] == _sector.sector_id:
			if not _sector.register_entity(id, Vector2(drop["x"], drop["y"])):
				return false
	return true


func validate_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value) or value.size() != 4:
		return false
	var state: Dictionary = value
	if not state.get("drops") is Array or not state.get("claimed_ids") is Array or not state.get("inventory") is Dictionary or not state.get("processed_events") is Dictionary:
		return false
	if state["drops"].size() > 256 or state["claimed_ids"].size() > 512 or state["inventory"].size() > 128 or state["processed_events"].size() > 512:
		return false
	var seen: Dictionary = {}
	for raw in state["drops"]:
		if not raw is Dictionary or raw.size() != 6:
			return false
		var drop: Dictionary = raw
		var id: Variant = drop.get("drop_id")
		if not id is String or not SectorIds.valid(id) or seen.has(id) or state["claimed_ids"].has(id):
			return false
		if not drop.get("sector_id") is String or not SectorIds.valid(drop["sector_id"]):
			return false
		if not drop.get("item_id") is String or not _valid_item(drop["item_id"]):
			return false
		if not _integer_quantity(drop.get("quantity")):
			return false
		if typeof(drop.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(drop.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(drop["x"])) or not is_finite(float(drop["y"])):
			return false
		seen[id] = true
	for id in state["claimed_ids"]:
		if not id is String or not SectorIds.valid(id):
			return false
	for item_id in state["inventory"]:
		if not item_id is String or not (_valid_item(item_id) or _extra_inventory_ids.has(item_id)) or not _integer_inventory_quantity(state["inventory"][item_id]):
			return false
	for event_id in state["processed_events"]:
		var drop_id: Variant = state["processed_events"][event_id]
		if not event_id is String or not SectorIds.valid(event_id) or not drop_id is String or (not drop_id.is_empty() and not SectorIds.valid(drop_id)):
			return false
	return true


func inventory_quantity(item_id: String) -> int:
	return _inventory.get(item_id, 0)


# Trusted world setup only; gameplay cannot grant stock through an intent.
func bind_inventory_owner(actor: String, initial_stock: Dictionary) -> bool:
	if not _inventory_owner.is_empty() or not SectorIds.valid(actor) or initial_stock.size() > 8:
		return false
	for item in initial_stock:
		if not item is String or not SectorIds.valid(item) or not initial_stock[item] is int or not _integer_inventory_quantity(initial_stock[item]):
			return false
	_inventory_owner = actor
	for item in initial_stock:
		_extra_inventory_ids[item] = true
	return true


# Reservation grants another authority-owned actor access only to its dedicated supply.
# The quantity remains in the same persisted VS-03 inventory map.
func reserve_inventory_item(actor: String, item: String) -> bool:
	if not SectorIds.valid(actor) or not SectorIds.valid(item) or _extra_inventory_ids.has(item) or _valid_item(item) or _reserved_by_item.size() >= 8:
		return false
	_extra_inventory_ids[item] = true
	_reserved_by_item[item] = actor
	return true


func initialize_missing_stock(initial_stock: Dictionary) -> void:
	for item in initial_stock:
		if _extra_inventory_ids.has(item) and not _inventory.has(item) and initial_stock[item] is int and _integer_inventory_quantity(initial_stock[item]):
			_inventory[item] = initial_stock[item]


func can_consume(actor: String, item: String, amount: int) -> bool:
	return _authority_enabled and not actor.is_empty() and actor == _reserved_by_item.get(item, _inventory_owner) and _valid_quantity(amount) and inventory_quantity(item) >= amount


func consume(actor: String, item: String, amount: int) -> bool:
	if not can_consume(actor, item, amount):
		return false
	_inventory[item] = inventory_quantity(item) - amount
	return true


func has_drop(drop_id: String) -> bool:
	return _drops.has(drop_id)


func is_claimed(drop_id: String) -> bool:
	return _claimed.has(drop_id)


func drop_snapshot(drop_id: String) -> Dictionary:
	return (_drops.get(drop_id, {}) as Dictionary).duplicate(true)


func last_query_inspected() -> int:
	return _last_query_inspected


func set_authority_enabled(enabled: bool) -> void:
	_authority_enabled = enabled


static func pickup_intent(drop_id: String) -> Dictionary:
	return {"domain": GameplayCommand.DOMAIN_GAMEPLAY, "type": PICKUP, "drop_id": drop_id}


func _valid_item(item_id: String) -> bool:
	return _item != null and SectorIds.valid(item_id) and item_id == _item.stable_id and _item.stack_limit > 0


static func _valid_quantity(value: int) -> bool:
	return value > 0 and value <= MAX_QUANTITY


static func _integer_quantity(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and number > 0.0 and number <= float(MAX_QUANTITY)


static func _integer_inventory_quantity(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and number >= 0.0 and number <= float(MAX_QUANTITY)


static func _drop_id(entity_id: String, sequence_id: int) -> String:
	return "drop.%s.seq_%d" % [entity_id.replace(".", "_"), sequence_id]


static func _event_id(entity_id: String, sequence_id: int) -> String:
	return "sunk.%s.seq_%d" % [entity_id.replace(".", "_"), sequence_id]
