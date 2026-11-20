class_name GameplayCamera
extends Camera2D

const CAMERA_STATE := preload("res://src/presentation/camera/camera_presentation_state.gd")
const CAMERA_MATH := preload("res://src/presentation/camera/camera_math.gd")

@export var min_zoom := 0.5
@export var max_zoom := 3.0
@export var smoothing_speed := 7.0
@export var world_limits := Rect2(-2048.0, -2048.0, 4096.0, 4096.0)
@export var follow_target_path: NodePath

var _state = CAMERA_STATE.new()
var _follow_target: Node2D


func _ready() -> void:
	_state.configure_zoom(min_zoom, max_zoom, zoom.x)
	_state.position = global_position
	_state.set_limits(world_limits, true)

	position_smoothing_enabled = true
	position_smoothing_speed = smoothing_speed
	limit_smoothed = true
	_sync_limits()
	zoom = Vector2.ONE * _state.zoom_value

	if not follow_target_path.is_empty():
		_follow_target = get_node_or_null(follow_target_path) as Node2D
	if _follow_target != null:
		_state.set_follow_target_position(_follow_target.global_position)
		_state.recenter()
		global_position = _state.position


func _process(_delta: float) -> void:
	if _follow_target == null or not _state.follow_mode:
		return
	_state.set_follow_target_position(_follow_target.global_position)
	_state.step_follow()
	global_position = _state.position


func pan_world_delta(world_delta: Vector2) -> void:
	_state.position = global_position
	_state.pan_world_delta(world_delta)
	global_position = _state.position


func zoom_by(factor: float) -> void:
	_state.zoom_value = zoom.x
	zoom = Vector2.ONE * _state.zoom_by(factor)


func recenter() -> void:
	if _follow_target != null:
		_state.set_follow_target_position(_follow_target.global_position)
	_state.recenter()
	global_position = _state.position


func set_follow_target(target: Node2D) -> void:
	_follow_target = target
	if _follow_target != null:
		_state.set_follow_target_position(_follow_target.global_position)


func set_world_limits(limits: Rect2) -> void:
	world_limits = limits
	_state.set_limits(world_limits, true)
	_sync_limits()
	_state.position = global_position
	_state.step_follow()
	global_position = _state.position


func screen_to_world_position(screen_position: Vector2) -> Vector2:
	return CAMERA_MATH.screen_to_world(
		screen_position,
		global_position,
		zoom,
		get_viewport_rect().size
	)


func world_to_screen_position(world_position: Vector2) -> Vector2:
	return CAMERA_MATH.world_to_screen(
		world_position,
		global_position,
		zoom,
		get_viewport_rect().size
	)


func screen_delta_to_world_delta(screen_delta: Vector2) -> Vector2:
	return screen_delta / Vector2(
		max(abs(zoom.x), CAMERA_MATH.MIN_ZOOM_COMPONENT),
		max(abs(zoom.y), CAMERA_MATH.MIN_ZOOM_COMPONENT)
	)


func is_follow_mode() -> bool:
	return _state.follow_mode


func _sync_limits() -> void:
	var opposite := world_limits.position + world_limits.size
	limit_left = int(floor(min(world_limits.position.x, opposite.x)))
	limit_right = int(ceil(max(world_limits.position.x, opposite.x)))
	limit_top = int(floor(min(world_limits.position.y, opposite.y)))
	limit_bottom = int(ceil(max(world_limits.position.y, opposite.y)))
