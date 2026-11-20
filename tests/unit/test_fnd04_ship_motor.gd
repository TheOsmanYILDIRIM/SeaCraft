extends GutTest

const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const MOTOR := preload("res://src/simulation/movement/ship_motor.gd")
const TEST_PROFILE := preload("res://tests/fixtures/movement/ship_test_profile.tres")

const FIXED_DELTA := 1.0 / 60.0
const EPSILON := 0.01


func test_acceleration_from_zero_reaches_max_speed_gradually() -> void:
	var motor = _new_motor()
	assert_true(motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(10000.0, 0.0))))
	motor.step_authoritative(FIXED_DELTA, false)
	assert_gt(motor.velocity.length(), 0.0)
	assert_lt(motor.velocity.length(), motor.effective_max_forward_speed())
	_step(motor, 180)
	assert_almost_eq(motor.velocity.length(), motor.effective_max_forward_speed(), 0.05)
	motor.free()


func test_speed_never_exceeds_max_forward_speed() -> void:
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(100000.0, 0.0)))
	_step(motor, 600)
	assert_lte(motor.velocity.length(), motor.effective_max_forward_speed() + EPSILON)
	motor.free()


func test_deceleration_is_controlled_after_cancel() -> void:
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(10000.0, 0.0)))
	_step(motor, 90)
	var before: float = motor.velocity.length()
	assert_true(motor.apply_authoritative_command(COMMANDS.cancel()))
	motor.step_authoritative(FIXED_DELTA, false)
	assert_lt(motor.velocity.length(), before)
	assert_gt(motor.velocity.length(), 0.0)
	_step(motor, 180)
	assert_almost_eq(motor.velocity.length(), 0.0, EPSILON)
	motor.free()


func test_heading_does_not_snap_to_target_in_one_tick() -> void:
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(0.0, 1000.0)))
	motor.step_authoritative(FIXED_DELTA, false)
	var first_heading: float = motor.current_heading()
	motor.step_authoritative(FIXED_DELTA, false)
	assert_ne(motor.current_heading(), motor.desired_heading())
	assert_lt(absf(motor.current_heading()), PI * 0.5)
	assert_gte(absf(motor.current_heading()), absf(first_heading))
	motor.free()


func test_turn_rate_limit_is_respected() -> void:
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(10000.0, 0.0)))
	_step(motor, 60)
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(motor.global_position.x, motor.global_position.y + 10000.0)))
	var before: float = motor.rotation
	motor.step_authoritative(FIXED_DELTA, false)
	var max_turn: float = deg_to_rad(TEST_PROFILE.turn_rate_degrees_per_second) * FIXED_DELTA
	assert_lte(absf(MOTOR.signed_angular_difference(before, motor.rotation)), max_turn + 0.0001)
	motor.free()


func test_arrival_radius_stops_ship_controlled() -> void:
	var motor = _new_motor()
	var target := Vector2(180.0, 0.0)
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(target))
	_step(motor, 600)
	assert_lte(motor.global_position.distance_to(target), TEST_PROFILE.arrival_radius + 0.5)
	assert_lte(motor.velocity.length(), TEST_PROFILE.stop_speed_epsilon + EPSILON)
	assert_false(motor.has_target())
	motor.free()


func test_overshoot_remains_within_arrival_tolerance() -> void:
	var motor = _new_motor()
	var target := Vector2(140.0, 0.0)
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(target))
	var furthest_x: float = motor.global_position.x
	for index in range(600):
		motor.step_authoritative(FIXED_DELTA, false)
		furthest_x = maxf(furthest_x, motor.global_position.x)
	assert_lte(furthest_x, target.x + TEST_PROFILE.arrival_radius + 0.5)
	motor.free()


func test_fixed_step_command_replay_is_repeatable() -> void:
	var first = _new_motor()
	var second = _new_motor()
	for index in range(360):
		if index == 0:
			first.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(500.0, 180.0)))
			second.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(500.0, 180.0)))
		elif index == 150:
			first.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(-120.0, 420.0)))
			second.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(-120.0, 420.0)))
		elif index == 300:
			first.apply_authoritative_command(COMMANDS.cancel())
			second.apply_authoritative_command(COMMANDS.cancel())
		first.step_authoritative(FIXED_DELTA, false)
		second.step_authoritative(FIXED_DELTA, false)
	assert_lt(first.global_position.distance_to(second.global_position), 0.0001)
	assert_lt(first.velocity.distance_to(second.velocity), 0.0001)
	assert_lt(absf(MOTOR.signed_angular_difference(first.rotation, second.rotation)), 0.0001)
	first.free()
	second.free()


func test_cancel_command_ends_target_motion() -> void:
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(800.0, 0.0)))
	_step(motor, 40)
	assert_true(motor.has_target())
	assert_true(motor.apply_authoritative_command(COMMANDS.cancel()))
	assert_false(motor.has_target())
	_step(motor, 180)
	assert_almost_eq(motor.velocity.length(), 0.0, EPSILON)
	motor.free()


func test_damaged_speed_modifier_reduces_effective_max_speed() -> void:
	var motor = _new_motor()
	assert_almost_eq(motor.effective_max_forward_speed(), 120.0, EPSILON)
	assert_true(motor.set_speed_modifiers({
		"damage.speed": {"operation": "multiply", "value": 0.5, "priority": 0},
	}))
	assert_almost_eq(motor.effective_max_forward_speed(), 60.0, EPSILON)
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(10000.0, 0.0)))
	_step(motor, 300)
	assert_lte(motor.velocity.length(), 60.0 + EPSILON)
	motor.free()


func test_removing_damage_modifier_restores_normal_max_speed() -> void:
	var motor = _new_motor()
	motor.set_speed_modifiers({
		"damage.speed": {"operation": "multiply", "value": 0.4, "priority": 0},
	})
	assert_almost_eq(motor.effective_max_forward_speed(), 48.0, EPSILON)
	motor.clear_speed_modifiers()
	assert_almost_eq(motor.effective_max_forward_speed(), 120.0, EPSILON)
	motor.free()


func test_invalid_movement_commands_do_not_corrupt_state() -> void:
	var motor = _new_motor()
	var before_position: Vector2 = motor.global_position
	var before_velocity: Vector2 = motor.velocity
	var invalid_commands: Array[Dictionary] = [
		{},
		{"domain": COMMANDS.DOMAIN_GAMEPLAY, "type": COMMANDS.MOVE_TO_WORLD_POSITION},
		{"domain": COMMANDS.DOMAIN_GAMEPLAY, "type": COMMANDS.MOVE_TO_WORLD_POSITION, "world_x": NAN, "world_y": 10.0},
		{"domain": COMMANDS.DOMAIN_GAMEPLAY, "type": COMMANDS.MOVE_TO_WORLD_POSITION, "world_x": INF, "world_y": 10.0},
		{"domain": COMMANDS.DOMAIN_GAMEPLAY, "type": COMMANDS.MOVE_TO_WORLD_POSITION, "world_x": "bad", "world_y": 10.0},
	]
	for command in invalid_commands:
		assert_false(motor.apply_authoritative_command(command))
	assert_eq(motor.global_position, before_position)
	assert_eq(motor.velocity, before_velocity)
	assert_true(motor.global_position.is_finite())
	assert_true(motor.velocity.is_finite())
	motor.free()


func test_collision_boundary_is_not_crossed() -> void:
	var motor = _new_motor()
	add_child(motor)
	motor.set_physics_process(false)
	var wall := _make_wall(Vector2(60.0, 0.0))
	add_child(wall)
	await get_tree().physics_frame
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(400.0, 0.0)))
	var envelope := motor.get_node_or_null("CollisionEnvelope") as CollisionShape2D
	assert_not_null(envelope)
	assert_true(envelope.shape is CircleShape2D)
	assert_almost_eq((envelope.shape as CircleShape2D).radius, TEST_PROFILE.collision_radius, EPSILON)
	for index in range(180):
		motor.step_authoritative(FIXED_DELTA, true)
	assert_lte(motor.global_position.x, 47.5)
	wall.queue_free()
	motor.queue_free()
	await get_tree().process_frame


func test_collision_keeps_position_and_velocity_finite() -> void:
	var motor = _new_motor()
	add_child(motor)
	motor.set_physics_process(false)
	var wall := _make_wall(Vector2(50.0, 0.0))
	add_child(wall)
	await get_tree().physics_frame
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(500.0, 0.0)))
	for index in range(240):
		motor.step_authoritative(FIXED_DELTA, true)
	assert_true(motor.global_position.is_finite())
	assert_true(motor.velocity.is_finite())
	assert_lte(motor.velocity.length(), motor.effective_max_forward_speed() + EPSILON)
	wall.queue_free()
	motor.queue_free()
	await get_tree().process_frame


func test_heading_side_and_turn_radius_helpers_are_pure() -> void:
	assert_almost_eq(MOTOR.signed_angular_difference(0.0, PI * 0.5), PI * 0.5, 0.0001)
	assert_eq(MOTOR.side_for_heading(0.0, PI * 0.5), MOTOR.SIDE_STARBOARD)
	assert_eq(MOTOR.side_for_heading(0.0, -PI * 0.5), MOTOR.SIDE_PORT)
	assert_eq(MOTOR.side_for_heading(0.0, 0.0), MOTOR.SIDE_ALIGNED)
	var motor = _new_motor()
	motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(10000.0, 0.0)))
	_step(motor, 60)
	assert_gt(motor.current_turn_radius(), 0.0)
	motor.free()


func test_ship_motor_has_no_network_api_dependency() -> void:
	var source := FileAccess.get_file_as_string("res://src/simulation/movement/ship_motor.gd")
	for forbidden in ["ENet", "MultiplayerAPI", "@rpc", "rpc(", "multiplayer_peer"]:
		assert_false(source.contains(forbidden))


func test_fnd03_command_flows_through_authoritative_motor_api() -> void:
	var motor = _new_motor()
	var command: Dictionary = COMMANDS.move_to_world_position(Vector2(240.0, 80.0))
	assert_true(motor.apply_authoritative_command(command))
	assert_true(motor.has_target())
	assert_eq(motor.target_world_position(), Vector2(240.0, 80.0))
	motor.authority_enabled = false
	assert_false(motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(999.0, 999.0))))
	assert_eq(motor.target_world_position(), Vector2(240.0, 80.0))
	motor.free()


func test_input_controller_has_no_direct_authoritative_transform_writes() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/input/gameplay_input_controller.gd")
	for forbidden in ["global_position =", "velocity =", "rotation ="]:
		assert_false(source.contains(forbidden))


func _new_motor():
	var motor = MOTOR.new()
	motor.movement_profile = TEST_PROFILE.duplicate(true)
	motor.authority_enabled = true
	motor.rotation = 0.0
	return motor


func _step(motor, count: int) -> void:
	for index in range(count):
		motor.step_authoritative(FIXED_DELTA, false)


func _make_wall(position: Vector2) -> StaticBody2D:
	var wall := StaticBody2D.new()
	wall.global_position = position
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(10.0, 300.0)
	shape_node.shape = shape
	wall.add_child(shape_node)
	return wall
