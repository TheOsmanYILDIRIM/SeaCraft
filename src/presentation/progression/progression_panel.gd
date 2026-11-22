class_name ProgressionPanel
extends Control

signal progression_intent_requested(intent_type: String, payload: Dictionary)

const MIN_TOUCH_TARGET := 48.0
const ACCESSIBILITY_FONT_SCALE := 1.3

var _selected_item_id := ""
var _selected_slot := "weapon"
var _selected_target_container := ""

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

static func apply_touch_target(control: Control) -> void:
	if control != null:
		control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, MIN_TOUCH_TARGET), maxf(control.custom_minimum_size.y, MIN_TOUCH_TARGET))
