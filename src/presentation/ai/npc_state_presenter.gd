class_name NpcStatePresenter
extends Node2D

var _label: Label
var _last_sequence: int = -1


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(-48, -48)
	_label.size = Vector2(120, 30)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 18)
	add_child(_label)


func apply_snapshot(snapshot: Dictionary) -> bool:
	if _label == null or not DtoContract.is_primitive_safe(snapshot):
		return false
	var sequence: Variant = snapshot.get("decision_sequence")
	var state_value: Variant = snapshot.get("state_id")
	if not sequence is int or not state_value is int:
		return false
	if sequence < _last_sequence:
		return false
	_last_sequence = sequence
	_label.text = state_label(state_value)
	return true


static func state_label(state_id: int) -> String:
	match state_id:
		NpcBrain.State.PATROL:
			return "PATROL ▷"
		NpcBrain.State.ALERT:
			return "ALERT !"
		NpcBrain.State.RETREAT:
			return "RETREAT «"
		NpcBrain.State.REPAIR:
			return "REPAIR +"
		NpcBrain.State.RESUME:
			return "RESUME ↻"
		_:
			return "UNKNOWN ?"
