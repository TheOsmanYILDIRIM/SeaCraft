class_name SectorSpatialHash
extends RefCounted

const CELL_SIZE := 128.0
const MAX_RADIUS := CELL_SIZE * 16.0
const MAX_COORDINATE := 10000000.0

var _buckets: Dictionary = {}
var _positions: Dictionary = {}


static func accepts_position(point: Vector2) -> bool:
	return point.is_finite() and absf(point.x) <= MAX_COORDINATE and absf(point.y) <= MAX_COORDINATE


func insert(id: String, point: Vector2) -> bool:
	if not SectorIds.valid(id) or _positions.has(id) or not accepts_position(point):
		return false
	_positions[id] = point
	_add_to_cell(id, _cell(point))
	return true


func move(id: String, point: Vector2) -> bool:
	if not _positions.has(id) or not accepts_position(point):
		return false
	var previous: Vector2 = _positions[id]
	if previous == point:
		return true
	var old_cell := _cell(previous)
	var new_cell := _cell(point)
	if old_cell != new_cell:
		_remove_from_cell(id, old_cell)
		_add_to_cell(id, new_cell)
	_positions[id] = point
	return true


func remove(id: String) -> bool:
	if not _positions.has(id):
		return false
	_remove_from_cell(id, _cell(_positions[id]))
	return _positions.erase(id)


# Unordered broadphase candidates filtered by exact radius. Caller owns reusable output.
# Returns occupied candidate count inspected, useful for profiling and scale tests.
func query_radius(center: Vector2, radius: float, output: Array[String]) -> int:
	output.clear()
	if not accepts_position(center) or not is_finite(radius) or radius < 0.0 or radius > MAX_RADIUS:
		return 0
	var low := _cell(center - Vector2(radius, radius))
	var high := _cell(center + Vector2(radius, radius))
	var squared := radius * radius
	var inspected := 0
	for y in range(low.y, high.y + 1):
		for x in range(low.x, high.x + 1):
			var key := Vector2i(x, y)
			if not _buckets.has(key):
				continue
			var bucket: Dictionary = _buckets[key]
			for id: String in bucket:
				inspected += 1
				var point: Vector2 = _positions[id]
				if center.distance_squared_to(point) <= squared:
					output.append(id)
	return inspected


static func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))


func _add_to_cell(id: String, cell: Vector2i) -> void:
	if not _buckets.has(cell):
		_buckets[cell] = {}
	var bucket: Dictionary = _buckets[cell]
	bucket[id] = true


func _remove_from_cell(id: String, cell: Vector2i) -> void:
	var bucket: Dictionary = _buckets[cell]
	bucket.erase(id)
	if bucket.is_empty():
		_buckets.erase(cell)
