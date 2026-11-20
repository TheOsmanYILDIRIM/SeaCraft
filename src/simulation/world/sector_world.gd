class_name SectorWorld
extends RefCounted

# Only the offline/host simulation composition root receives the authority object.
# The capability is not a security boundary against arbitrary scripts in-process.
var _authority: RefCounted
var _graph: SectorGraph
var _loader: Callable
var _runtime: SectorRuntime


func _init(graph: SectorGraph, authority: RefCounted, loader: Callable = Callable()) -> void:
	_graph = graph
	_authority = authority
	_loader = loader


func active() -> SectorRuntime:
	return _runtime


func activate_initial(authority: RefCounted, id: String, entry_id: String, entity_id: String) -> bool:
	return _authorized(authority) and _runtime == null and _activate(id, entry_id, entity_id)


# Returns target sector and entry anchor only for an authority-owned eligible entity.
func can_transition(authority: RefCounted, entity_id: String, gate_id: String) -> Dictionary:
	if not _authorized(authority) or _runtime == null:
		return {}
	var edge := _graph.gate(gate_id)
	if edge == null or edge.from_sector != _runtime.sector_id:
		return {}
	var exit := _runtime.anchor(edge.exit_anchor)
	var position := _runtime.entity_position(entity_id)
	if exit == null or not position.is_finite() or position.distance_squared_to(exit.position) > edge.activation_radius * edge.activation_radius:
		return {}
	return {"sector_id": edge.to_sector, "entry_anchor_id": edge.entry_anchor}


func request_transition(authority: RefCounted, entity_id: String, gate_id: String) -> Dictionary:
	var target := can_transition(authority, entity_id, gate_id)
	if target.is_empty() or not _activate(target["sector_id"], target["entry_anchor_id"], entity_id):
		return {}
	return target


func leave(authority: RefCounted) -> bool:
	if not _authorized(authority) or _runtime == null:
		return false
	_runtime = null
	return true


func _authorized(candidate: RefCounted) -> bool:
	return _authority != null and candidate == _authority


func _activate(id: String, entry_id: String, entity_id: String) -> bool:
	var path := _graph.definition_path(id)
	if path.is_empty():
		return false
	var candidate_runtime := _build_runtime(id, path)
	if candidate_runtime == null:
		return false
	var entry := candidate_runtime.anchor(entry_id)
	if entry == null or not candidate_runtime.register_entity(entity_id, entry.position):
		return false
	_runtime = candidate_runtime
	return true


# Restore only the selected world runtime, committing it after validation.
func restore_active(authority: RefCounted, id: String, entity_id: String, position: Vector2) -> String:
	if not _authorized(authority):
		return "not_authorized"
	var path := _graph.definition_path(id)
	if not SectorIds.valid(id) or path.is_empty():
		return "unknown_sector"
	var candidate := _build_runtime(id, path)
	if candidate == null:
		return "missing_or_invalid_sector_definition"
	if not position.is_finite() or not candidate.bounds.has_point(position) or not candidate.register_entity(entity_id, position):
		return "invalid_spawn_state"
	_runtime = candidate
	return ""


func _build_runtime(id: String, path: String) -> SectorRuntime:
	var definition: SectorDefinition
	if _loader.is_valid():
		definition = _loader.call(path) as SectorDefinition
	elif ResourceLoader.exists(path):
		definition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	if definition == null or definition.stable_id != id or not _graph.matches_definition(definition):
		return null
	return SectorRuntime.build(definition)
