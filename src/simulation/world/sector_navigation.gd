class_name SectorNavigation
extends RefCounted

const MAX_WAYPOINTS := 64
const MAX_OBSTACLES := 32
const START := MAX_WAYPOINTS
const GOAL := MAX_WAYPOINTS + 1

var _astar := AStar2D.new()
var _water: Rect2
var _obstacles: Array[Rect2] = []
var _blocked: Array[Rect2] = []
var _point_count: int
var _weighted: bool
var _ready: bool
var _cached_from: Vector2
var _cached_to: Vector2
var _cached_route: PackedVector2Array
var _has_cache: bool
var _hazards: Dictionary = {}
var search_count: int
var hazard_revision: int


func configure(bounds: Rect2, fixture: SectorNavigationFixture) -> bool:
	_ready = false
	if fixture == null or not _valid_rect(bounds) or not is_finite(fixture.clearance) or fixture.clearance < 0.0:
		return false
	if fixture.waypoints.size() > MAX_WAYPOINTS or fixture.obstacles.size() > MAX_OBSTACLES:
		return false
	_water = bounds.grow(-fixture.clearance)
	if not _valid_rect(_water):
		return false
	_obstacles = fixture.obstacles.duplicate()
	_blocked.clear()
	for obstacle in fixture.obstacles:
		if not _valid_rect(obstacle) or not bounds.encloses(obstacle):
			return false
		_blocked.append(obstacle.grow(fixture.clearance))
	_astar.clear()
	_hazards.clear()
	hazard_revision = 0
	_weighted = false
	_has_cache = false
	_cached_route = PackedVector2Array()
	_point_count = fixture.waypoints.size()
	for i in _point_count:
		var point := fixture.waypoints[i]
		if not accessible(point):
			return false
		_astar.add_point(i, point)
		for j in i:
			if direct_clear(point, _astar.get_point_position(j)):
				_astar.connect_points(i, j)
	_ready = true
	return true


func obstacle_rects() -> Array[Rect2]:
	return _obstacles.duplicate()


func waypoint_count() -> int:
	return _point_count


func accessible(point: Vector2) -> bool:
	if not point.is_finite() or not _water.has_point(point):
		return false
	for obstacle in _blocked:
		if obstacle.has_point(point):
			return false
	return true


# Navigation clearance is deliberately larger than the physics collider.
# A physically valid ship in that margin must be able to sail back in.
func helm_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _ready or not from.is_finite() or not accessible(to):
		return PackedVector2Array()
	if accessible(from):
		return rounded_helm_route(path(from, to))
	# Straight return across the navigation margin is preferable to a short
	# artificial intermediate target at the edge.
	var direct_egress := true
	for obstacle in _blocked:
		if _hits_rect(from, to, obstacle):
			direct_egress = false
			break
	if direct_egress:
		return PackedVector2Array([from, to])
	var inset := _water.grow(-2.0)
	if not inset.has_area():
		return PackedVector2Array()
	var origin := from.clamp(inset.position, inset.end)
	# Recovery from the boundary margin, or from a coast clearance halo.
	# Never teleport or choose a segment through actual land.
	var candidates := PackedVector2Array([origin])
	for obstacle in _blocked:
		if obstacle.has_point(origin):
			candidates.append(Vector2(obstacle.position.x - 2.0, origin.y))
			candidates.append(Vector2(obstacle.end.x + 2.0, origin.y))
			candidates.append(Vector2(origin.x, obstacle.position.y - 2.0))
			candidates.append(Vector2(origin.x, obstacle.end.y + 2.0))
	var best := PackedVector2Array()
	var best_distance := INF
	for candidate in candidates:
		if not accessible(candidate):
			continue
		var clear := true
		for land in _obstacles:
			if _hits_rect(from, candidate, land):
				clear = false
				break
		if not clear:
			continue
		var route := path(candidate, to)
		if route.size() < 2:
			continue
		var distance := from.distance_to(candidate)
		if distance < best_distance:
			best_distance = distance
			best = rounded_helm_route(route)
	if not best.is_empty():
		best.insert(0, from)
	return best


func rounded_helm_route(route: PackedVector2Array) -> PackedVector2Array:
	if route.size() < 3:
		return route
	var result := PackedVector2Array([route[0]])
	for i in range(1, route.size() - 1):
		var corner := route[i]
		var before := route[i - 1]
		var after := route[i + 1]
		var radius := minf(32.0, minf(before.distance_to(corner), after.distance_to(corner)) * 0.25)
		var rounded := PackedVector2Array()
		for attempt in range(5):
			var entry := corner.move_toward(before, radius)
			var exit := corner.move_toward(after, radius)
			var samples := PackedVector2Array([entry])
			for j in range(1, 5):
				var t := float(j) / 4.0
				samples.append(entry.lerp(corner, t).lerp(corner.lerp(exit, t), t))
			var valid := direct_clear(result[-1], samples[0]) and direct_clear(samples[-1], after)
			for j in range(1, samples.size()):
				valid = valid and direct_clear(samples[j - 1], samples[j])
			if valid:
				rounded = samples
				break
			radius *= 0.5
		if rounded.is_empty():
			result.append(corner)
		else:
			result.append_array(rounded)
	result.append(route[-1])
	return result


func direct_clear(from: Vector2, to: Vector2) -> bool:
	if not accessible(from) or not accessible(to):
		return false
	for obstacle in _blocked:
		if _hits_rect(from, to, obstacle):
			return false
	return true


func path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not _ready or not accessible(from) or not accessible(to):
		return PackedVector2Array()
	if _has_cache and from == _cached_from and to == _cached_to:
		return _cached_route
	_cached_from = from
	_cached_to = to
	_has_cache = true
	if not _weighted and direct_clear(from, to):
		_cached_route = PackedVector2Array([from, to])
		return _cached_route
	_astar.add_point(START, from)
	_astar.add_point(GOAL, to)
	if direct_clear(from, to):
		_astar.connect_points(START, GOAL)
	for i in _point_count:
		var point := _astar.get_point_position(i)
		if direct_clear(from, point):
			_astar.connect_points(START, i)
		if direct_clear(to, point):
			_astar.connect_points(i, GOAL)
	search_count += 1
	_cached_route = _astar.get_point_path(START, GOAL)
	_astar.remove_point(START)
	_astar.remove_point(GOAL)
	return _cached_route


func set_hazard_cost(point_index: int, storm: float, shallows: float, area: float, faction: float) -> bool:
	if not _ready or point_index < 0 or point_index >= _point_count:
		return false
	var weight := hazard_weight(storm, shallows, area, faction)
	if weight < 1.0:
		return false
	var next := {"point_index": point_index, "storm": clampf(storm, 0.0, 100.0),
		"shallows": clampf(shallows, 0.0, 100.0), "area": clampf(area, 0.0, 100.0),
		"faction": clampf(faction, 0.0, 100.0)}
	var previous: Dictionary = _hazards.get(point_index, {})
	if previous == next:
		return true
	_astar.set_point_weight_scale(point_index, weight)
	if is_equal_approx(weight, 1.0):
		_hazards.erase(point_index)
	else:
		_hazards[point_index] = next
	_weighted = not _hazards.is_empty()
	_has_cache = false
	hazard_revision += 1
	return true


func snapshot_hazard_state() -> Array:
	var result: Array = []
	var ids := _hazards.keys()
	ids.sort()
	for id in ids:
		result.append((_hazards[id] as Dictionary).duplicate(true))
	return result


func restore_hazard_state(value: Variant) -> bool:
	if not value is Array or value.size() > _point_count:
		return false
	var planned: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw in value:
		if not raw is Dictionary or raw.size() != 5:
			return false
		var index_value: Variant = raw.get("point_index")
		if typeof(index_value) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var index := int(index_value)
		if float(index_value) != float(index) or index < 0 or index >= _point_count or seen.has(index):
			return false
		for key in ["storm", "shallows", "area", "faction"]:
			if typeof(raw.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw[key])) or float(raw[key]) < 0.0 or float(raw[key]) > 100.0:
				return false
		var entry: Dictionary = raw.duplicate(true)
		entry["point_index"] = index
		planned.append(entry)
		seen[index] = true
	for i in _point_count:
		_astar.set_point_weight_scale(i, 1.0)
	_hazards.clear()
	_weighted = false
	_has_cache = false
	for entry in planned:
		if not set_hazard_cost(int(entry["point_index"]), float(entry["storm"]), float(entry["shallows"]), float(entry["area"]), float(entry["faction"])):
			return false
	return true


func route_cost(route: PackedVector2Array) -> float:
	if route.size() < 2:
		return INF
	var total := 0.0
	for index in range(1, route.size()):
		var segment := route[index - 1].distance_to(route[index])
		if not is_finite(segment):
			return INF
		var weight := 1.0
		for point_index in _point_count:
			if _astar.get_point_position(point_index).is_equal_approx(route[index]):
				weight = _astar.get_point_weight_scale(point_index)
				break
		total += segment * weight
	return total if is_finite(total) else INF


static func hazard_weight(storm: float, shallows: float, area: float, faction: float) -> float:
	if not is_finite(storm) or not is_finite(shallows) or not is_finite(area) or not is_finite(faction):
		return 0.0
	return 1.0 + clampf(storm, 0.0, 100.0) + clampf(shallows, 0.0, 100.0) + clampf(area, 0.0, 100.0) + clampf(faction, 0.0, 100.0)


static func _valid_rect(rect: Rect2) -> bool:
	return SectorSpatialHash.accepts_position(rect.position) and SectorSpatialHash.accepts_position(rect.end) and rect.size.x > 0.0 and rect.size.y > 0.0


static func _hits_rect(from: Vector2, to: Vector2, rect: Rect2) -> bool:
	var delta := to - from
	var enter := 0.0
	var leave := 1.0
	for axis in 2:
		if is_zero_approx(delta[axis]):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return false
			continue
		var first := (rect.position[axis] - from[axis]) / delta[axis]
		var last := (rect.end[axis] - from[axis]) / delta[axis]
		enter = maxf(enter, minf(first, last))
		leave = minf(leave, maxf(first, last))
		if enter > leave:
			return false
	return true
