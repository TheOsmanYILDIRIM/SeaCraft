class_name CameraMath
extends RefCounted

const MIN_ZOOM_COMPONENT := 0.0001


static func screen_to_world(
	screen_position: Vector2,
	camera_position: Vector2,
	zoom_value: Vector2,
	viewport_size: Vector2
) -> Vector2:
	var safe_zoom: Vector2 = _safe_zoom(zoom_value)
	return camera_position + (screen_position - viewport_size * 0.5) / safe_zoom


static func world_to_screen(
	world_position: Vector2,
	camera_position: Vector2,
	zoom_value: Vector2,
	viewport_size: Vector2
) -> Vector2:
	var safe_zoom: Vector2 = _safe_zoom(zoom_value)
	return viewport_size * 0.5 + (world_position - camera_position) * safe_zoom


static func clamp_zoom(value: float, minimum: float, maximum: float) -> float:
	var low: float = minf(minimum, maximum)
	var high: float = maxf(minimum, maximum)
	return clampf(value, low, high)


static func clamp_position_to_limits(position: Vector2, limits: Rect2) -> Vector2:
	var opposite: Vector2 = limits.position + limits.size
	var min_x: float = minf(limits.position.x, opposite.x)
	var max_x: float = maxf(limits.position.x, opposite.x)
	var min_y: float = minf(limits.position.y, opposite.y)
	var max_y: float = maxf(limits.position.y, opposite.y)
	return Vector2(
		clampf(position.x, min_x, max_x),
		clampf(position.y, min_y, max_y)
	)


static func _safe_zoom(zoom_value: Vector2) -> Vector2:
	return Vector2(
		maxf(absf(zoom_value.x), MIN_ZOOM_COMPONENT),
		maxf(absf(zoom_value.y), MIN_ZOOM_COMPONENT)
	)
