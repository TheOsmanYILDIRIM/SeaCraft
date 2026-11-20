class_name SectorRuntime
extends RefCounted

var sector_id: String
var bounds: Rect2
var navigation: SectorNavigation
var spatial := SectorSpatialHash.new()
var _anchors: Dictionary = {}
var _entities: Dictionary = {}


static func build(definition: SectorDefinition) -> SectorRuntime:
	if definition == null or not SectorIds.valid(definition.stable_id) or not SectorIds.valid(definition.label_id):
		return null
	if definition.layer < 0 or definition.layer > 1:
		return null
	if not definition.hazard_cost_profile_id.is_empty() and not SectorIds.valid(definition.hazard_cost_profile_id):
		return null
	var runtime := SectorRuntime.new()
	runtime.sector_id = definition.stable_id
	runtime.bounds = definition.bounds
	runtime.navigation = SectorNavigation.new()
	if not runtime.navigation.configure(definition.bounds, definition.navigation_fixture):
		return null
	for anchor in definition.spawn_anchors:
		if anchor == null or not SectorIds.valid(anchor.stable_id) or anchor.sector_id != runtime.sector_id or runtime._anchors.has(anchor.stable_id):
			return null
		if not runtime.navigation.accessible(anchor.position) or not is_finite(anchor.heading) or anchor.category.is_empty():
			return null
		runtime._anchors[anchor.stable_id] = anchor.duplicate()
	return runtime


func anchor(id: String) -> SectorAnchor:
	var value: SectorAnchor = _anchors.get(id)
	return value.duplicate() as SectorAnchor if value != null else null


func register_entity(id: String, position: Vector2) -> bool:
	if not bounds.has_point(position) or not spatial.insert(id, position):
		return false
	_entities[id] = position
	return true


func move_entity(id: String, position: Vector2) -> bool:
	if not bounds.has_point(position) or not spatial.move(id, position):
		return false
	_entities[id] = position
	return true


func remove_entity(id: String) -> bool:
	if not spatial.remove(id):
		return false
	return _entities.erase(id)


func entity_position(id: String) -> Vector2:
	return _entities.get(id, Vector2.INF)
