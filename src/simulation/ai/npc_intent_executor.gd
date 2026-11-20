class_name NpcIntentExecutor
extends RefCounted

var path_request_count: int = 0

var _motor: ShipMotor
var _navigation: SectorNavigation
var _route: PackedVector2Array = PackedVector2Array()
var _route_index: int = 0
var _goal: Vector2 = Vector2.INF
var _path_valid: bool = false


func configure(motor: ShipMotor, navigation: SectorNavigation) -> bool:
	if motor == null or navigation == null or not motor.authority_enabled:
		return false
	_motor = motor
	_navigation = navigation
	return true


func request_destination(current_position: Vector2, destination: Vector2) -> bool:
	if _motor == null or _navigation == null or not current_position.is_finite() or not destination.is_finite():
		return false
	if _path_valid and destination == _goal:
		if not _motor.has_target():
			_advance_route()
		return true
	_goal = destination
	_route_index = 0
	_path_valid = false
	if not _navigation.accessible(destination):
		return false
	if _navigation.direct_clear(current_position, destination):
		_route = PackedVector2Array([current_position, destination])
	else:
		path_request_count += 1
		_route = _navigation.path(current_position, destination)
	if _route.size() < 2:
		return false
	_path_valid = true
	_route_index = 1
	return _command(_route[_route_index])


func advance_if_arrived() -> void:
	if _motor != null and _path_valid and not _motor.has_target():
		_advance_route()


func stop() -> void:
	if _motor != null:
		_motor.apply_authoritative_command(GameplayCommand.cancel())
	_path_valid = false
	_route = PackedVector2Array()
	_route_index = 0
	_goal = Vector2.INF


func invalidate_path() -> void:
	_path_valid = false
	_route = PackedVector2Array()
	_route_index = 0


func has_goal() -> bool:
	return _goal.is_finite()


func goal() -> Vector2:
	return _goal


func arrived(current_position: Vector2, radius: float) -> bool:
	return (_motor != null and _goal.is_finite() and current_position.is_finite()
		and is_finite(radius) and radius >= 0.0 and not _motor.has_target()
		and current_position.distance_to(_goal) <= radius)


func _advance_route() -> void:
	if not _path_valid:
		return
	if _route_index + 1 < _route.size():
		_route_index += 1
		_command(_route[_route_index])


func _command(point: Vector2) -> bool:
	return _motor.apply_authoritative_command(GameplayCommand.move_to_world_position(point))
