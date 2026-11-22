class_name NetworkEntityProxy
extends Node2D

const PROTOCOL := preload("res://src/network/session_protocol.gd")

var entity_id: String = ""
var entity_kind: String = ""
var sector_id: String = ""
var definition_id: String = ""
var generation: int = 0
var lifecycle_sequence: int = 0
var last_state_sequence: int = -1
var hull_ratio: float = 1.0
var alive: bool = true
var ai_state_id: int = -1
var ai_intent_id: int = -1
var aoi_visible: bool = false

var _samples: Array[Dictionary] = []
var _target_position: Vector2 = Vector2.ZERO
var _target_heading: float = 0.0
var _visual_alpha: float = 1.0


func configure_spawn(payload: Dictionary) -> bool:
	if PROTOCOL.validate_spawn_payload(payload) != "":
		return false
	entity_id = str(payload["entity_id"])
	entity_kind = str(payload["entity_kind"])
	sector_id = str(payload["sector_id"])
	definition_id = str(payload["definition_id"])
	generation = int(payload["generation"])
	lifecycle_sequence = int(payload["lifecycle_sequence"])
	last_state_sequence = int(payload["state_sequence"])
	hull_ratio = float(payload["hull_ratio"])
	alive = bool(payload["alive"])
	_target_position = Vector2(float(payload["x"]), float(payload["y"]))
	_target_heading = float(payload["heading"])
	global_position = _target_position
	rotation = _target_heading
	_samples.clear()
	_samples.append({
		"sequence": last_state_sequence,
		"server_tick": 0,
		"x": _target_position.x,
		"y": _target_position.y,
		"heading": _target_heading,
	})
	visible = false
	return true


func apply_snapshot(row: Dictionary, snapshot_sequence: int, server_tick: int) -> bool:
	if PROTOCOL.validate_snapshot_row(row) != "" or str(row["entity_id"]) != entity_id:
		return false
	if snapshot_sequence <= last_state_sequence:
		return false
	if str(row["entity_kind"]) != entity_kind or str(row["sector_id"]) != sector_id:
		return false
	last_state_sequence = snapshot_sequence
	hull_ratio = float(row["hull_ratio"])
	alive = bool(row["alive"])
	ai_state_id = int(row.get("ai_state_id", -1))
	ai_intent_id = int(row.get("ai_intent_id", -1))
	_target_position = Vector2(float(row["x"]), float(row["y"]))
	_target_heading = float(row["heading"])
	_samples.append({
		"sequence": snapshot_sequence,
		"server_tick": server_tick,
		"x": _target_position.x,
		"y": _target_position.y,
		"heading": _target_heading,
	})
	while _samples.size() > PROTOCOL.MAX_INTERPOLATION_SAMPLES:
		_samples.pop_front()
	_visual_alpha = 0.0
	return true


func set_aoi_visible(value: bool) -> void:
	aoi_visible = value
	visible = value


func sample_count() -> int:
	return _samples.size()


func samples() -> Array[Dictionary]:
	return _samples.duplicate(true)


func authoritative_state() -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_kind": entity_kind,
		"sector_id": sector_id,
		"x": _target_position.x,
		"y": _target_position.y,
		"heading": _target_heading,
		"hull_ratio": hull_ratio,
		"alive": alive,
		"sequence": last_state_sequence,
	}


func interpolated_position(alpha: float) -> Vector2:
	if _samples.is_empty():
		return _target_position
	if _samples.size() == 1:
		var only: Dictionary = _samples[0]
		return Vector2(float(only["x"]), float(only["y"]))
	var previous: Dictionary = _samples[_samples.size() - 2]
	var current: Dictionary = _samples[_samples.size() - 1]
	var from := Vector2(float(previous["x"]), float(previous["y"]))
	var to := Vector2(float(current["x"]), float(current["y"]))
	return from.lerp(to, clampf(alpha, 0.0, 1.0))


func _process(delta: float) -> void:
	if _samples.size() < 2 or not is_finite(delta) or delta <= 0.0:
		return
	_visual_alpha = minf(1.0, _visual_alpha + delta * 10.0)
	var previous: Dictionary = _samples[_samples.size() - 2]
	var current: Dictionary = _samples[_samples.size() - 1]
	global_position = Vector2(float(previous["x"]), float(previous["y"])).lerp(
		Vector2(float(current["x"]), float(current["y"])),
		_visual_alpha
	)
	rotation = lerp_angle(float(previous["heading"]), float(current["heading"]), _visual_alpha)
