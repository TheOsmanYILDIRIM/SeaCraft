class_name ShipMotor
extends CharacterBody2D

const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const MODIFIER_PIPELINE := preload("res://src/simulation/stats/stat_modifier_pipeline.gd")
const DEFAULT_PROFILE := preload("res://src/data/movement/ship_placeholder_profile.tres")

const SIDE_PORT := -1
const SIDE_ALIGNED := 0
const SIDE_STARBOARD := 1
const SIDE_EPSILON := 0.0001
const MIN_POSITIVE := 0.000001

@export var movement_profile: ShipMovementProfile
@export var authority_enabled: bool = true

var _has_target: bool = false
var _target_position: Vector2 = Vector2.ZERO
var _desired_heading: float = 0.0
var _speed_modifiers: Dictionary = {}


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_desired_heading = rotation
	_configure_collision_envelope()


func _physics_process(delta: float) -> void:
	step_authoritative(delta, true)


func apply_authoritative_command(command: Dictionary) -> bool:
	if not authority_enabled or command.is_empty():
		return false
	if str(command.get("domain", "")) != COMMANDS.DOMAIN_GAMEPLAY:
		return false

	var command_type: String = str(command.get("type", ""))
	match command_type:
		COMMANDS.MOVE_TO_WORLD_POSITION:
			if not _movement_command_has_valid_target(command):
				return false
			var target := Vector2(float(command["world_x"]), float(command["world_y"]))
			return set_target_world_position(target)
		COMMANDS.CANCEL:
			cancel_target()
			return true
		_:
			return false


func set_target_world_position(world_position: Vector2) -> bool:
	if not authority_enabled or not world_position.is_finite():
		return false
	_target_position = world_position
	_has_target = true
	_desired_heading = global_position.angle_to_point(_target_position)
	return true


func cancel_target() -> void:
	if not authority_enabled:
		return
	_has_target = false
	_target_position = global_position
	_desired_heading = rotation


func set_speed_modifiers(modifiers_by_id: Dictionary) -> bool:
	if not authority_enabled or not _modifiers_are_finite(modifiers_by_id):
		return false
	_speed_modifiers = modifiers_by_id.duplicate(true)
	return true


func clear_speed_modifiers() -> void:
	if authority_enabled:
		_speed_modifiers.clear()


func step_authoritative(delta: float, apply_collision: bool = true) -> void:
	if not authority_enabled or not is_finite(delta) or delta <= 0.0:
		return
	var profile: ShipMovementProfile = _profile()
	var max_speed: float = effective_max_forward_speed()
	var current_speed: float = velocity.length()
	if not is_finite(current_speed):
		velocity = Vector2.ZERO
		current_speed = 0.0

	var target_speed: float = 0.0
	if _has_target:
		var to_target: Vector2 = _target_position - global_position
		if not to_target.is_finite():
			cancel_target()
		else:
			var distance_to_target: float = to_target.length()
			if distance_to_target > MIN_POSITIVE:
				_desired_heading = to_target.angle()
			_apply_turn(delta, current_speed, max_speed)
			target_speed = _arrival_limited_speed(distance_to_target, max_speed)
			var turn_error: float = absf(angular_difference_to_desired())
			var alignment: float = clampf(1.0 - (turn_error / PI) * 0.65, 0.35, 1.0)
			target_speed *= alignment
	else:
		_desired_heading = rotation

	var acceleration: float = _positive_or_zero(profile.acceleration)
	var deceleration: float = _positive_or_zero(profile.deceleration)
	if target_speed > current_speed:
		current_speed = move_toward(current_speed, target_speed, acceleration * delta)
	else:
		current_speed = move_toward(current_speed, target_speed, deceleration * delta)

	if current_speed <= _positive_or_zero(profile.stop_speed_epsilon):
		current_speed = 0.0
	velocity = Vector2.RIGHT.rotated(rotation) * current_speed

	if apply_collision and is_inside_tree():
		move_and_slide()
		if not velocity.is_finite():
			velocity = Vector2.ZERO
	else:
		global_position += velocity * delta

	if _has_target:
		var remaining: float = global_position.distance_to(_target_position)
		if remaining <= _positive_or_zero(profile.arrival_radius) and velocity.length() <= _positive_or_zero(profile.stop_speed_epsilon):
			velocity = Vector2.ZERO
			_has_target = false
			_desired_heading = rotation


func has_target() -> bool:
	return _has_target


func target_world_position() -> Vector2:
	return _target_position


func current_heading() -> float:
	return rotation


func desired_heading() -> float:
	return _desired_heading


func angular_difference_to_desired() -> float:
	return signed_angular_difference(rotation, _desired_heading)


func desired_side() -> int:
	return side_for_heading(rotation, _desired_heading)


func current_turn_radius() -> float:
	var profile: ShipMovementProfile = _profile()
	var turn_rate_radians: float = deg_to_rad(_positive_or_zero(profile.turn_rate_degrees_per_second))
	var speed: float = velocity.length()
	var effective_turn_rate: float = turn_rate_radians * _maneuver_factor(
		speed,
		effective_max_forward_speed()
	)
	if effective_turn_rate <= MIN_POSITIVE:
		return INF
	return speed / effective_turn_rate


func effective_max_forward_speed() -> float:
	var base_speed: float = _positive_or_zero(_profile().max_forward_speed)
	var modified_speed: float = MODIFIER_PIPELINE.apply_from_dictionary(base_speed, _speed_modifiers)
	if not is_finite(modified_speed):
		return 0.0
	return maxf(0.0, modified_speed)


func refresh_collision_envelope() -> void:
	_configure_collision_envelope()


static func signed_angular_difference(from_heading: float, to_heading: float) -> float:
	if not is_finite(from_heading) or not is_finite(to_heading):
		return 0.0
	return wrapf(to_heading - from_heading, -PI, PI)


static func side_for_heading(from_heading: float, to_heading: float) -> int:
	var difference: float = signed_angular_difference(from_heading, to_heading)
	if difference > SIDE_EPSILON:
		return SIDE_STARBOARD
	if difference < -SIDE_EPSILON:
		return SIDE_PORT
	return SIDE_ALIGNED


func _apply_turn(delta: float, current_speed: float, max_speed: float) -> void:
	var profile: ShipMovementProfile = _profile()
	var turn_rate_radians: float = deg_to_rad(_positive_or_zero(profile.turn_rate_degrees_per_second))
	if turn_rate_radians <= MIN_POSITIVE:
		return
	var maneuver_factor: float = _maneuver_factor(current_speed, max_speed)
	var max_step: float = turn_rate_radians * maneuver_factor * delta
	var difference: float = angular_difference_to_desired()
	rotation += clampf(difference, -max_step, max_step)


func _maneuver_factor(current_speed: float, max_speed: float) -> float:
	var profile: ShipMovementProfile = _profile()
	var speed_for_turn: float = current_speed
	if max_speed > MIN_POSITIVE:
		speed_for_turn = minf(current_speed, max_speed)
	if speed_for_turn <= _positive_or_zero(profile.stop_speed_epsilon):
		return 0.0
	var minimum_speed: float = _positive_or_zero(profile.minimum_maneuvering_speed)
	if minimum_speed <= MIN_POSITIVE:
		return 1.0
	return clampf(speed_for_turn / minimum_speed, 0.25, 1.0)


func _arrival_limited_speed(distance_to_target: float, max_speed: float) -> float:
	var profile: ShipMovementProfile = _profile()
	var remaining: float = maxf(0.0, distance_to_target - _positive_or_zero(profile.arrival_radius))
	if remaining <= MIN_POSITIVE:
		return 0.0
	var deceleration: float = maxf(_positive_or_zero(profile.deceleration), MIN_POSITIVE)
	var braking_speed: float = sqrt(2.0 * deceleration * remaining)
	return minf(max_speed, braking_speed)


func _movement_command_has_valid_target(command: Dictionary) -> bool:
	if not command.has("world_x") or not command.has("world_y"):
		return false
	var x_value: Variant = command["world_x"]
	var y_value: Variant = command["world_y"]
	if not _is_number(x_value) or not _is_number(y_value):
		return false
	return is_finite(float(x_value)) and is_finite(float(y_value))


func _modifiers_are_finite(modifiers_by_id: Dictionary) -> bool:
	for modifier_id in modifiers_by_id:
		var source: Variant = modifiers_by_id[modifier_id]
		if not source is Dictionary:
			return false
		var modifier: Dictionary = modifiers_by_id[modifier_id]
		var raw_value: Variant = modifier.get("value", 0.0)
		if not _is_number(raw_value) or not is_finite(float(raw_value)):
			return false
	return true


func _configure_collision_envelope() -> void:
	var envelope: CollisionShape2D = get_node_or_null("CollisionEnvelope") as CollisionShape2D
	if envelope == null:
		envelope = CollisionShape2D.new()
		envelope.name = "CollisionEnvelope"
		add_child(envelope)
	var circle := CircleShape2D.new()
	circle.radius = maxf(_positive_or_zero(_profile().collision_radius), 0.1)
	envelope.shape = circle


func _profile() -> ShipMovementProfile:
	if movement_profile == null:
		movement_profile = DEFAULT_PROFILE as ShipMovementProfile
	return movement_profile


static func _is_number(value: Variant) -> bool:
	var value_type: int = typeof(value)
	return value_type == TYPE_INT or value_type == TYPE_FLOAT


static func _positive_or_zero(value: float) -> float:
	if not is_finite(value):
		return 0.0
	return maxf(0.0, value)
