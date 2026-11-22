class_name ProgressionPanel
extends Control

signal progression_intent_requested(intent_type: String, payload: Dictionary)

const MIN_TOUCH_TARGET := 48.0
const ACCESSIBILITY_FONT_SCALE := 1.3

var _selected_item_id := ""
var _selected_slot := "weapon"
var _selected_target_container := ""
var _selected_recipe_id := ""
var _selected_salvage_table_id := ""
var _selected_upgrade_id := ""
var _selected_core_slot_id := ""
var _selected_trophy_id := ""
var _selected_skill_id := ""
var _selected_gate_id := ""
var _selected_challenge_id := ""
var _skill_view_zoom := 1.0
var _skill_view_pan := Vector2.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func select_item(item_id: String) -> bool:
	if not SectorIds.valid(item_id):
		return false
	_selected_item_id = item_id
	return true

func select_slot(slot: String) -> bool:
	if slot not in InventoryState.SLOT_TYPES:
		return false
	_selected_slot = slot
	return true

func select_target_container(container_id: String) -> bool:
	if not SectorIds.valid(container_id):
		return false
	_selected_target_container = container_id
	return true

func request_equip(transaction_id: String) -> bool:
	if _selected_item_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.INVENTORY_EQUIP, {
		"transaction_id": transaction_id,
		"slot": _selected_slot,
		"item_id": _selected_item_id,
	})
	return true

func request_transfer(transaction_id: String, source_container: String, quantity: int) -> bool:
	if _selected_item_id.is_empty() or _selected_target_container.is_empty() or quantity <= 0 or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	if not SectorIds.valid(source_container):
		return false
	progression_intent_requested.emit(SessionProtocol.INVENTORY_TRANSFER, {
		"transaction_id": transaction_id,
		"source_container": source_container,
		"target_container": _selected_target_container,
		"item_id": _selected_item_id,
		"quantity": quantity,
	})
	return true

func select_recipe(recipe_id: String) -> bool:
	if not SectorIds.valid(recipe_id):
		return false
	_selected_recipe_id = recipe_id
	return true

func select_salvage_table(table_id: String) -> bool:
	if not SectorIds.valid(table_id):
		return false
	_selected_salvage_table_id = table_id
	return true

func select_upgrade(upgrade_id: String) -> bool:
	if not SectorIds.valid(upgrade_id):
		return false
	_selected_upgrade_id = upgrade_id
	return true

func select_core_slot(slot_id: String) -> bool:
	if not SectorIds.valid(slot_id):
		return false
	_selected_core_slot_id = slot_id
	return true

func select_trophy(trophy_id: String) -> bool:
	if not SectorIds.valid(trophy_id):
		return false
	_selected_trophy_id = trophy_id
	return true

func request_craft(transaction_id: String, count: int = 1) -> bool:
	if _selected_recipe_id.is_empty() or count <= 0 or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_CRAFT, {"transaction_id": transaction_id, "recipe_id": _selected_recipe_id, "count": count})
	return true

func request_salvage(transaction_id: String) -> bool:
	if _selected_salvage_table_id.is_empty() or _selected_item_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_SALVAGE, {"transaction_id": transaction_id, "table_id": _selected_salvage_table_id, "source_item_id": _selected_item_id})
	return true

func request_upgrade(transaction_id: String) -> bool:
	if _selected_upgrade_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_SHIP_UPGRADE, {"transaction_id": transaction_id, "upgrade_id": _selected_upgrade_id})
	return true

func request_core_insert(transaction_id: String) -> bool:
	if _selected_core_slot_id.is_empty() or _selected_item_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_CORE_INSERT, {"transaction_id": transaction_id, "slot_id": _selected_core_slot_id, "item_id": _selected_item_id})
	return true

func request_core_remove(transaction_id: String) -> bool:
	if _selected_core_slot_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_CORE_REMOVE, {"transaction_id": transaction_id, "slot_id": _selected_core_slot_id})
	return true

func request_core_replace(transaction_id: String) -> bool:
	if _selected_core_slot_id.is_empty() or _selected_item_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_CORE_REPLACE, {"transaction_id": transaction_id, "slot_id": _selected_core_slot_id, "item_id": _selected_item_id})
	return true

func select_skill(skill_id: String) -> bool:
	if not SectorIds.valid(skill_id):
		return false
	_selected_skill_id = skill_id
	return true

func select_gate(gate_id: String) -> bool:
	if not SectorIds.valid(gate_id):
		return false
	_selected_gate_id = gate_id
	return true

func select_challenge(challenge_id: String) -> bool:
	if not SectorIds.valid(challenge_id):
		return false
	_selected_challenge_id = challenge_id
	return true

func set_skill_view_transform(zoom: float, pan: Vector2) -> bool:
	if not is_finite(zoom) or zoom < 0.5 or zoom > 2.5 or not is_finite(pan.x) or not is_finite(pan.y):
		return false
	_skill_view_zoom = zoom
	_skill_view_pan = pan
	return true

func skill_view_transform() -> Dictionary:
	return {"zoom": _skill_view_zoom, "pan_x": _skill_view_pan.x, "pan_y": _skill_view_pan.y}

func request_skill_spend(transaction_id: String) -> bool:
	if _selected_skill_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_SKILL_SPEND, {"transaction_id": transaction_id, "skill_id": _selected_skill_id})
	return true

func request_respec(transaction_id: String) -> bool:
	if not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_RESPEC, {"transaction_id": transaction_id})
	return true

func request_gate_complete(transaction_id: String) -> bool:
	if _selected_gate_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_GATE_COMPLETE, {"transaction_id": transaction_id, "gate_id": _selected_gate_id})
	return true

func request_challenge_event(transaction_id: String, event_id: String) -> bool:
	if _selected_challenge_id.is_empty() or not SectorIds.valid(event_id) or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_CHALLENGE_EVENT, {"transaction_id": transaction_id, "challenge_id": _selected_challenge_id, "event_id": event_id})
	return true

func request_trophy_unlock(transaction_id: String, event_key: String) -> bool:
	if _selected_trophy_id.is_empty() or not SectorIds.valid(event_key) or not SessionProtocol.valid_transaction_id(transaction_id):
		return false
	progression_intent_requested.emit(SessionProtocol.PROGRESSION_TROPHY_UNLOCK, {"transaction_id": transaction_id, "trophy_id": _selected_trophy_id, "event_key": event_key})
	return true

static func apply_touch_target(control: Control) -> void:
	if control != null:
		control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, MIN_TOUCH_TARGET), maxf(control.custom_minimum_size.y, MIN_TOUCH_TARGET))
