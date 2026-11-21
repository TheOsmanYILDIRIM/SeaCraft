class_name MinimapTransform
extends RefCounted


static func world_to_map(world_position: Vector2, world_bounds: Rect2, map_rect: Rect2, clamp_outside: bool = true) -> Vector2:
	if not _valid(world_bounds, map_rect) or not world_position.is_finite():
		return Vector2.INF
	var uv := (world_position - world_bounds.position) / world_bounds.size
	if clamp_outside:
		uv.x = clampf(uv.x, 0.0, 1.0)
		uv.y = clampf(uv.y, 0.0, 1.0)
	elif uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2.INF
	return map_rect.position + uv * map_rect.size


static func map_to_world(map_position: Vector2, world_bounds: Rect2, map_rect: Rect2, clamp_outside: bool = true) -> Vector2:
	if not _valid(world_bounds, map_rect) or not map_position.is_finite():
		return Vector2.INF
	var uv := (map_position - map_rect.position) / map_rect.size
	if clamp_outside:
		uv.x = clampf(uv.x, 0.0, 1.0)
		uv.y = clampf(uv.y, 0.0, 1.0)
	elif uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2.INF
	return world_bounds.position + uv * world_bounds.size


static func world_rect_to_map(world_rect: Rect2, world_bounds: Rect2, map_rect: Rect2) -> Rect2:
	var start := world_to_map(world_rect.position, world_bounds, map_rect, true)
	var finish := world_to_map(world_rect.end, world_bounds, map_rect, true)
	if not start.is_finite() or not finish.is_finite():
		return Rect2()
	return Rect2(start, finish - start)


static func _valid(world_bounds: Rect2, map_rect: Rect2) -> bool:
	return world_bounds.position.is_finite() and world_bounds.end.is_finite() and map_rect.position.is_finite() \
		and map_rect.end.is_finite() and world_bounds.size.x > 0.0 and world_bounds.size.y > 0.0 \
		and map_rect.size.x > 0.0 and map_rect.size.y > 0.0
