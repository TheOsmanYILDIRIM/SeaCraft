class_name SectorRuntime
extends RefCounted

const MAX_RUNTIME_ENTITIES := 1024

var sector_id: String
var bounds: Rect2
var navigation: SectorNavigation
var spatial := SectorSpatialHash.new()
var safe_haven := false
var map_node_position := Vector2.ZERO
var map_layer := 0
var biome_tag := ""
var _anchors: Dictionary = {}
var _gates: Dictionary = {}
var _safe_zones: Dictionary = {}
var _entities: Dictionary = {}


static func build(definition: SectorDefinition) -> SectorRuntime:
	if definition == null or not SectorIds.valid(definition.stable_id) or not SectorIds.valid(definition.label_id):
		return null
	if definition.layer < 0 or definition.layer > 1 or definition.map_layer < -8 or definition.map_layer > 8:
		return null
	if not definition.map_node_position.is_finite() or definition.biome_tag.length() > 64:
		return null
	if not definition.hazard_cost_profile_id.is_empty() and not SectorIds.valid(definition.hazard_cost_profile_id):
		return null
	var runtime := SectorRuntime.new()
	runtime.sector_id = definition.stable_id
	runtime.bounds = definition.bounds
	runtime.safe_haven = definition.safe_haven
	runtime.map_node_position = definition.map_node_position
	runtime.map_layer = definition.map_layer
	runtime.biome_tag = definition.biome_tag
	runtime.navigation = SectorNavigation.new()
	if not runtime.navigation.configure(definition.bounds, definition.navigation_fixture):
		return null
	for anchor in definition.spawn_anchors:
		if anchor == null or not SectorIds.valid(anchor.stable_id) or anchor.sector_id != runtime.sector_id or runtime._anchors.has(anchor.stable_id):
			return null
		if not runtime.navigation.accessible(anchor.position) or not is_finite(anchor.heading) or anchor.category.is_empty():
			return null
		runtime._anchors[anchor.stable_id] = anchor.duplicate()
	for edge in definition.transition_gates:
		if edge == null or edge.from_sector != runtime.sector_id or not SectorIds.valid(edge.stable_id) or runtime._gates.has(edge.stable_id):
			return null
		runtime._gates[edge.stable_id] = edge.duplicate()
	for zone in definition.safe_zones:
		if zone == null or not zone.valid_for_sector(runtime.sector_id) or runtime._safe_zones.has(zone.stable_id):
			return null
		if not runtime.bounds.has_point(zone.center):
			return null
		runtime._safe_zones[zone.stable_id] = zone.duplicate()
	if runtime.safe_haven and runtime._safe_zones.is_empty():
		return null
	return runtime


func anchor(id: String) -> SectorAnchor:
	var value: SectorAnchor = _anchors.get(id)
	return value.duplicate() as SectorAnchor if value != null else null


func gate(id: String) -> SectorGate:
	var value: SectorGate = _gates.get(id)
	return value.duplicate() as SectorGate if value != null else null


func gate_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _gates.keys():
		ids.append(id)
	ids.sort()
	return ids


func safe_zone_at(position: Vector2) -> String:
	if not position.is_finite():
		return ""
	var ids := _safe_zones.keys()
	ids.sort()
	for id in ids:
		var zone: SafeZoneDefinition = _safe_zones[id]
		if position.distance_squared_to(zone.center) <= zone.radius * zone.radius:
			return id
	return ""


func entity_safe_zone(id: String) -> String:
	return safe_zone_at(entity_position(id))


func entity_in_safe_zone(id: String) -> bool:
	return not entity_safe_zone(id).is_empty()


func register_entity(id: String, position: Vector2) -> bool:
	if _entities.size() >= MAX_RUNTIME_ENTITIES or not bounds.has_point(position) or not spatial.insert(id, position):
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


# Shared offline/LAN interaction geometry. Both the live authority motor and
# the sector index must agree; callers supply trusted content coordinates.
func entity_within_interaction_range(id: String, position: Vector2, center: Vector2,
		radius: float, max_position_lag: float = 64.0) -> bool:
	if not is_finite(radius) or radius <= 0.0 or not is_finite(max_position_lag) or max_position_lag < 0.0:
		return false
	var indexed := entity_position(id)
	if not position.is_finite() or not indexed.is_finite() or not center.is_finite():
		return false
	if not bounds.has_point(position) or not bounds.has_point(center):
		return false
	if position.distance_squared_to(indexed) > max_position_lag * max_position_lag:
		return false
	return position.distance_squared_to(center) <= radius * radius


func snapshot_state(exclude_entity_id: String = "") -> Dictionary:
	var entities: Array = []
	var ids := _entities.keys()
	ids.sort()
	for id in ids:
		if id == exclude_entity_id:
			continue
		var position: Vector2 = _entities[id]
		entities.append({"entity_id": id, "x": position.x, "y": position.y})
	return {"entities": entities, "hazards": navigation.snapshot_hazard_state()}


func restore_state(value: Variant, exclude_entity_id: String = "") -> bool:
	if not value is Dictionary or value.size() != 2 or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if not state.get("entities") is Array or state["entities"].size() > MAX_RUNTIME_ENTITIES:
		return false
	if not state.get("hazards") is Array:
		return false
	var planned: Array[Dictionary] = []
	var seen: Dictionary = {}
	for raw in state["entities"]:
		if not raw is Dictionary or raw.size() != 3:
			return false
		var id: Variant = raw.get("entity_id")
		if not id is String or not SectorIds.valid(id) or seen.has(id):
			return false
		if typeof(raw.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var position := Vector2(float(raw["x"]), float(raw["y"]))
		if not position.is_finite() or not bounds.has_point(position):
			return false
		seen[id] = true
		if id != exclude_entity_id:
			planned.append({"entity_id": id, "position": position})
	if not navigation.restore_hazard_state(state["hazards"]):
		return false
	var current := _entities.keys()
	for id in current:
		remove_entity(id)
	for entry in planned:
		if not register_entity(entry["entity_id"], entry["position"]):
			return false
	return true


func presentation_snapshot() -> Dictionary:
	var zones: Array = []
	var zone_ids := _safe_zones.keys()
	zone_ids.sort()
	for id in zone_ids:
		var zone: SafeZoneDefinition = _safe_zones[id]
		zones.append({"safe_zone_id": id, "x": zone.center.x, "y": zone.center.y, "radius": zone.radius})
	var gates: Array = []
	for id in gate_ids():
		var edge: SectorGate = _gates[id]
		var exit := anchor(edge.exit_anchor)
		if exit != null:
			gates.append({"gate_id": id, "to_sector": edge.to_sector, "x": exit.position.x, "y": exit.position.y})
	return {
		"sector_id": sector_id,
		"bounds": {"x": bounds.position.x, "y": bounds.position.y, "w": bounds.size.x, "h": bounds.size.y},
		"safe_haven": safe_haven,
		"safe_zones": zones,
		"gates": gates,
		"map_node": {"x": map_node_position.x, "y": map_node_position.y, "layer": map_layer},
		"biome_tag": biome_tag,
	}
