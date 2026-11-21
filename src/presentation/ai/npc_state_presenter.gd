class_name NpcStatePresenter
extends Node2D

var _label: Label
var _last_sequence: int = -1


func _ready() -> void:
	_label = Label.new()
	_label.position = Vector2(-84, -54)
	_label.size = Vector2(190, 52)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override("font_size", 16)
	add_child(_label)


func apply_snapshot(snapshot: Dictionary) -> bool:
	if _label == null or not DtoContract.is_primitive_safe(snapshot):
		return false
	var sequence: Variant = snapshot.get("decision_sequence")
	var state_value: Variant = snapshot.get("state_id")
	var intent_value: Variant = snapshot.get("intent_id")
	var role_value: Variant = snapshot.get("role_profile_id")
	var target_value: Variant = snapshot.get("target_entity_id")
	if not sequence is int or not state_value is int or not intent_value is int:
		return false
	if not role_value is String or not target_value is String:
		return false
	if sequence < _last_sequence:
		return false
	_last_sequence = sequence
	var target_suffix := "" if target_value.is_empty() else " → %s" % target_value
	_label.text = "%s | %s\n%s%s" % [
		state_label(state_value),
		intent_label(intent_value),
		role_value,
		target_suffix,
	]
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


static func intent_label(intent_id: int) -> String:
	match intent_id:
		NpcBrain.Intent.PATROL_TO_WAYPOINT:
			return "patrol"
		NpcBrain.Intent.INVESTIGATE_THREAT:
			return "investigate"
		NpcBrain.Intent.RETREAT_TO_SAFE_POINT:
			return "retreat"
		NpcBrain.Intent.REPAIR:
			return "repair"
		NpcBrain.Intent.RESUME_PATROL:
			return "resume"
		NpcBrain.Intent.PROTECT_ALLY:
			return "protect"
		_:
			return "unknown"
