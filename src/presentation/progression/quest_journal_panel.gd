class_name QuestJournalPanel
extends Control

signal quest_intent_requested(intent_type: String, payload: Dictionary)
signal tracked_quest_changed(quest_id: String)

const MIN_TOUCH_TARGET := 48.0
const ACCESSIBILITY_FONT_SCALE := 1.3

var _snapshot: Dictionary = InventoryState.empty_quest_journal_snapshot("entity.player")
var _selected_quest_id := ""
var _tracked_quest_id := ""

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

func consume_snapshot(snapshot: Dictionary) -> bool:
	if not InventoryState.validate_quest_journal_snapshot(snapshot):
		return false
	_snapshot = snapshot.duplicate(true)
	if not _selected_quest_id.is_empty() and not _contains_quest(_selected_quest_id):
		_selected_quest_id = ""
	if not _tracked_quest_id.is_empty() and not _contains_quest(_tracked_quest_id):
		_tracked_quest_id = ""
	return true

func snapshot() -> Dictionary:
	return _snapshot.duplicate(true)

func select_quest(quest_id: String) -> bool:
	if not SectorIds.valid(quest_id) or not _contains_quest(quest_id):
		return false
	_selected_quest_id = quest_id
	return true

func selected_quest_id() -> String:
	return _selected_quest_id

func track_selected() -> bool:
	if _selected_quest_id.is_empty():
		return false
	_tracked_quest_id = _selected_quest_id
	tracked_quest_changed.emit(_tracked_quest_id)
	return true

func clear_tracking() -> void:
	_tracked_quest_id = ""
	tracked_quest_changed.emit("")

func tracked_quest_id() -> String:
	return _tracked_quest_id

func request_accept(transaction_id: String, npc_id: String) -> bool:
	if _selected_quest_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id) or not SectorIds.valid(npc_id):
		return false
	quest_intent_requested.emit(SessionProtocol.QUEST_ACCEPT, {
		"transaction_id": transaction_id,
		"quest_id": _selected_quest_id,
		"npc_id": npc_id,
	})
	return true

func request_turn_in(transaction_id: String, npc_id: String) -> bool:
	if _selected_quest_id.is_empty() or not SessionProtocol.valid_transaction_id(transaction_id) or not SectorIds.valid(npc_id):
		return false
	quest_intent_requested.emit(SessionProtocol.QUEST_TURN_IN, {
		"transaction_id": transaction_id,
		"quest_id": _selected_quest_id,
		"npc_id": npc_id,
	})
	return true

func selected_timer_remaining() -> int:
	var row := _find_row(_selected_quest_id)
	return int(row.get("remaining_ticks", -1)) if not row.is_empty() else -1

func selected_objectives() -> Array:
	var row := _find_row(_selected_quest_id)
	return (row.get("objectives", []) as Array).duplicate(true) if not row.is_empty() else []

func selected_reward_preview() -> Dictionary:
	var row := _find_row(_selected_quest_id)
	return (row.get("reward_preview", {}) as Dictionary).duplicate(true) if not row.is_empty() else {}

static func apply_touch_target(control: Control) -> void:
	if control != null:
		control.custom_minimum_size = Vector2(maxf(control.custom_minimum_size.x, MIN_TOUCH_TARGET), maxf(control.custom_minimum_size.y, MIN_TOUCH_TARGET))

func _contains_quest(quest_id: String) -> bool:
	return not _find_row(quest_id).is_empty()

func _find_row(quest_id: String) -> Dictionary:
	if quest_id.is_empty():
		return {}
	var groups: Dictionary = _snapshot.get("groups", {})
	for group in ["available", "active", "completable", "completed", "failed"]:
		for raw in groups.get(group, []):
			if raw is Dictionary and str(raw.get("quest_id", "")) == quest_id:
				return (raw as Dictionary).duplicate(true)
	return {}
