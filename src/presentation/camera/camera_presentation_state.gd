class_name CameraPresentationState
extends RefCounted

const CAMERA_MATH := preload("res://src/presentation/camera/camera_math.gd")

var position := Vector2.ZERO
var zoom_value := 1.0
var min_zoom := 0.5
var max_zoom := 3.0
var follow_mode := true
var follow_target_position := Vector2.ZERO

var _limits := Rect2(-2048.0, -2048.0, 4096.0, 4096.0)
var _limits_enabled := false


func configure_zoom(minimum: float, maximum: float, current: float = 1.0) -> void:
	min_zoom = min(minimum, maximum)
	max_zoom = max(minimum, maximum)
	zoom_value = CAMERA_MATH.clamp_zoom(current, min_zoom, max_zoom)


func set_limits(limits: Rect2, enabled: bool = true) -> void:
	_limits = limits
	_limits_enabled = enabled
	_apply_limits()


func pan_world_delta(world_delta: Vector2) -> void:
	follow_mode = false
	position += world_delta
	_apply_limits()


func zoom_by(factor: float) -> float:
	if factor <= 0.0:
		return zoom_value
	zoom_value = CAMERA_MATH.clamp_zoom(zoom_value * factor, min_zoom, max_zoom)
	return zoom_value


func set_follow_target_position(world_position: Vector2) -> void:
	follow_target_position = world_position


func recenter() -> void:
	follow_mode = true
	position = follow_target_position
	_apply_limits()


func step_follow() -> void:
	if not follow_mode:
		return
	position = follow_target_position
	_apply_limits()


func _apply_limits() -> void:
	if _limits_enabled:
		position = CAMERA_MATH.clamp_position_to_limits(position, _limits)
