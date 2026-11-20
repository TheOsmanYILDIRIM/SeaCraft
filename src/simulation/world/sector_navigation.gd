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
var search_count: int


# Visibility graph, constructed only for the active fixture. No agents and no physics callback.
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


func accessible(point: Vector2) -> bool:
	if not point.is_finite() or not _water.has_point(point):
		return false
	for obstacle in _blocked:
		if obstacle.has_point(point):
			return false
	return true


func direct_clear(from: Vector2, to: Vector2) -> bool:
	if not accessible(from) or not accessible(to):
		return false
	for obstacle in _blocked:
		if _hits_rect(from, to, obstacle):
			return false
	return true


# Explicit event-driven call. Reuse the returned packed route until movement or hazard changes
# warrant a query. A bounded exact endpoint cache also avoids duplicate simultaneous requests.
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


# Cold-path waypoint weighting; zero hazards preserve the geometric heuristic.
# Frontier hazard systems can update these weights on events, never per physics frame.
func set_hazard_cost(point_index: int, storm: float, shallows: float, area: float, faction: float) -> bool:
	if not _ready or point_index < 0 or point_index >= _point_count:
		return false
	var weight := hazard_weight(storm, shallows, area, faction)
	if weight < 1.0:
		return false
	_astar.set_point_weight_scale(point_index, weight)
	_weighted = false
	for i in _point_count:
		if _astar.get_point_weight_scale(i) > 1.0:
			_weighted = true
			break
	_has_cache = false
	return true


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
