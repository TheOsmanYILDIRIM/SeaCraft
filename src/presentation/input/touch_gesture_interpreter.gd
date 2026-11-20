class_name TouchGestureInterpreter
extends RefCounted

const TAP_MOVE_THRESHOLD := 12.0

var _touch_positions: Dictionary = {}
var _tap_candidate_index := -1
var _tap_start := Vector2.ZERO
var _tap_moved := false
var _pinch_distance := 0.0


func reset() -> void:
	_touch_positions.clear()
	_tap_candidate_index = -1
	_tap_start = Vector2.ZERO
	_tap_moved = false
	_pinch_distance = 0.0


func press(index: int, position: Vector2) -> Array[Dictionary]:
	if index < 0 or _touch_positions.has(index):
		return []
	_touch_positions[index] = position
	if _touch_positions.size() == 1:
		_tap_candidate_index = index
		_tap_start = position
		_tap_moved = false
		_pinch_distance = 0.0
	else:
		_tap_candidate_index = -1
		_tap_moved = true
		if _touch_positions.size() == 2:
			_pinch_distance = _distance_between_two_touches()
	return []


func drag(index: int, position: Vector2) -> Array[Dictionary]:
	if not _touch_positions.has(index):
		return []

	var previous: Vector2 = _touch_positions[index]
	_touch_positions[index] = position

	if _touch_positions.size() >= 2:
		_tap_candidate_index = -1
		_tap_moved = true
		if _touch_positions.size() != 2:
			_pinch_distance = 0.0
			return []
		var distance := _distance_between_two_touches()
		if _pinch_distance <= 0.0:
			_pinch_distance = distance
			return []
		var factor := distance / _pinch_distance if _pinch_distance > 0.0 else 1.0
		_pinch_distance = distance
		if abs(factor - 1.0) < 0.001:
			return []
		return [{"kind": "zoom", "factor": factor}]

	if index != _tap_candidate_index:
		return []

	if position.distance_to(_tap_start) > TAP_MOVE_THRESHOLD:
		_tap_moved = true
	if not _tap_moved:
		return []

	var delta := position - previous
	return [{
		"kind": "pan",
		"delta_x": float(delta.x),
		"delta_y": float(delta.y),
	}]


func release(index: int, position: Vector2) -> Array[Dictionary]:
	if not _touch_positions.has(index):
		return []

	_touch_positions[index] = position
	var was_single_touch := _touch_positions.size() == 1
	var is_tap := (
		was_single_touch
		and index == _tap_candidate_index
		and not _tap_moved
		and position.distance_to(_tap_start) <= TAP_MOVE_THRESHOLD
	)

	_touch_positions.erase(index)
	_pinch_distance = 0.0
	if _touch_positions.is_empty():
		_tap_candidate_index = -1
		_tap_moved = false

	if is_tap:
		return [{
			"kind": "tap",
			"screen_x": float(position.x),
			"screen_y": float(position.y),
		}]
	return []


func _distance_between_two_touches() -> float:
	if _touch_positions.size() != 2:
		return 0.0
	var keys := _touch_positions.keys()
	var first: Vector2 = _touch_positions[keys[0]]
	var second: Vector2 = _touch_positions[keys[1]]
	return first.distance_to(second)
