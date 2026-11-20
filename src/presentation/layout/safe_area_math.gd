class_name SafeAreaMath
extends RefCounted


static func logical_viewport_size(base_viewport: Vector2, window_size: Vector2) -> Vector2:
	var scale := _expand_scale(base_viewport, window_size)
	if scale <= 0.0:
		return Vector2.ZERO
	return window_size / scale


static func display_safe_area_to_logical(
	safe_area: Rect2,
	base_viewport: Vector2,
	window_size: Vector2
) -> Rect2:
	var scale := _expand_scale(base_viewport, window_size)
	if scale <= 0.0:
		return Rect2()
	return Rect2(safe_area.position / scale, safe_area.size / scale)


static func _expand_scale(base_viewport: Vector2, window_size: Vector2) -> float:
	if (
		base_viewport.x <= 0.0
		or base_viewport.y <= 0.0
		or window_size.x <= 0.0
		or window_size.y <= 0.0
	):
		return 0.0
	return min(window_size.x / base_viewport.x, window_size.y / base_viewport.y)
