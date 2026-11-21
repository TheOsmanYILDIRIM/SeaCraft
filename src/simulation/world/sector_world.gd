class_name SectorWorld
extends RefCounted

const MAX_DORMANT_SECTORS := 32

var _authority: RefCounted
var _graph: SectorGraph
var _loader: Callable
var _runtime: SectorRuntime
var _dormant: Dictionary = {}
var _binding: SectorRuntimeBinding


func _init(graph: SectorGraph, authority: RefCounted, loader: Callable = Callable()) -> void:
	_graph = graph
	_authority = authority
	_loader = loader


func active() -> SectorRuntime:
	return _runtime


func bind_runtime(binding: SectorRuntimeBinding) -> bool:
	if _binding != null or binding == null or _runtime == null:
		return false
	_binding = binding
	return true


func world_graph_snapshot() -> Dictionary:
	return _graph.presentation_snapshot().duplicate(true) if _graph != null else {}


func activate_initial(authority: RefCounted, id: String, entry_id: String, entity_id: String) -> bool:
	return _authorized(authority) and _runtime == null and _activate(id, entry_id, entity_id)


func can_transition(authority: RefCounted, entity_id: String, gate_id: String) -> Dictionary:
	var plan := _transition_plan(authority, entity_id, gate_id)
	return {"sector_id": plan["to_sector"], "entry_anchor_id": plan["entry_anchor"]} if plan["reason"].is_empty() else {}


func request_transition(authority: RefCounted, entity_id: String, gate_id: String) -> Dictionary:
	var plan := _transition_plan(authority, entity_id, gate_id)
	var result := _transition_dto(false, plan["reason"], plan["from_sector"], plan["to_sector"], gate_id, plan["entry_anchor"])
	if not plan["reason"].is_empty():
		return result
	var candidate := _build_runtime(plan["to_sector"], _graph.definition_path(plan["to_sector"]))
	if candidate == null:
		result["reason"] = "destination_runtime_invalid"
		return result
	var dormant_state: Variant = _dormant.get(plan["to_sector"])
	if dormant_state != null and not candidate.restore_state(dormant_state, entity_id):
		result["reason"] = "dormant_state_invalid"
		return result
	var entry := candidate.anchor(plan["entry_anchor"])
	if entry == null or not candidate.register_entity(entity_id, entry.position):
		result["reason"] = "entry_anchor_invalid"
		return result
	if _binding != null and not _binding.can_rebind(candidate, entity_id):
		result["reason"] = "runtime_rebind_rejected"
		return result
	var previous := _runtime
	var dormant_before := _dormant.duplicate(true)
	if _dormant.size() >= MAX_DORMANT_SECTORS and not _dormant.has(previous.sector_id):
		result["reason"] = "dormant_capacity"
		return result
	_dormant[previous.sector_id] = previous.snapshot_state(entity_id)
	_runtime = candidate
	_dormant.erase(candidate.sector_id)
	if _binding != null and not _binding.rebind_sector(candidate, entity_id):
		_runtime = previous
		_dormant = dormant_before
		_binding.rebind_sector(previous, entity_id)
		result["reason"] = "runtime_rebind_failed"
		return result
	result["accepted"] = true
	result["reason"] = ""
	return result


func leave(authority: RefCounted) -> bool:
	if not _authorized(authority) or _runtime == null:
		return false
	_runtime = null
	_binding = null
	return true


func snapshot_state(entity_id: String) -> Dictionary:
	if _runtime == null or not SectorIds.valid(entity_id):
		return {}
	return {"active_sector": _runtime.sector_id, "active_runtime": _runtime.snapshot_state(entity_id),
		"dormant": _dormant.duplicate(true)}


func restore_state(authority: RefCounted, value: Variant, entity_id: String, active_position: Vector2) -> String:
	if not _authorized(authority):
		return "not_authorized"
	if not value is Dictionary or value.size() != 3 or not DtoContract.is_primitive_safe(value):
		return "invalid_world_state"
	var state: Dictionary = value
	if not state.get("active_sector") is String or not SectorIds.valid(state["active_sector"]):
		return "invalid_world_state"
	if not state.get("active_runtime") is Dictionary or not state.get("dormant") is Dictionary or state["dormant"].size() > MAX_DORMANT_SECTORS:
		return "invalid_world_state"
	var id: String = state["active_sector"]
	var path := _graph.definition_path(id)
	if path.is_empty():
		return "unknown_sector"
	var candidate := _build_runtime(id, path)
	if candidate == null:
		return "missing_or_invalid_sector_definition"
	if not candidate.restore_state(state["active_runtime"], entity_id):
		return "invalid_world_state"
	if not active_position.is_finite() or not candidate.bounds.has_point(active_position) or not candidate.register_entity(entity_id, active_position):
		return "invalid_spawn_state"
	var planned_dormant: Dictionary = {}
	for dormant_id in state["dormant"]:
		if not dormant_id is String or not SectorIds.valid(dormant_id) or dormant_id == id or _graph.definition_path(dormant_id).is_empty():
			return "invalid_world_state"
		var raw: Variant = state["dormant"][dormant_id]
		if not raw is Dictionary:
			return "invalid_world_state"
		var check := _build_runtime(dormant_id, _graph.definition_path(dormant_id))
		if check == null or not check.restore_state(raw, entity_id):
			return "invalid_world_state"
		planned_dormant[dormant_id] = raw.duplicate(true)
	_runtime = candidate
	_dormant = planned_dormant
	if _binding != null and not _binding.rebind_sector(candidate, entity_id):
		return "runtime_rebind_failed"
	return ""


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
	_dormant.clear()
	if _binding != null and not _binding.rebind_sector(candidate, entity_id):
		return "runtime_rebind_failed"
	return ""


func _transition_plan(authority: RefCounted, entity_id: String, gate_id: String) -> Dictionary:
	var from_sector := _runtime.sector_id if _runtime != null else ""
	var edge := _graph.gate(gate_id) if _graph != null else null
	var to_sector := edge.to_sector if edge != null else ""
	var entry_anchor := edge.entry_anchor if edge != null else ""
	if not _authorized(authority):
		return {"reason": "not_authorized", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	if _runtime == null:
		return {"reason": "no_active_sector", "from_sector": "", "to_sector": to_sector, "entry_anchor": entry_anchor}
	if not SectorIds.valid(entity_id) or not _runtime.entity_position(entity_id).is_finite():
		return {"reason": "invalid_actor", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	if edge == null:
		return {"reason": "gate_not_found", "from_sector": from_sector, "to_sector": "", "entry_anchor": ""}
	if edge.from_sector != _runtime.sector_id:
		return {"reason": "wrong_current_sector", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	var exit := _runtime.anchor(edge.exit_anchor)
	var position := _runtime.entity_position(entity_id)
	if exit == null:
		return {"reason": "exit_anchor_invalid", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	if position.distance_squared_to(exit.position) > edge.activation_radius * edge.activation_radius:
		return {"reason": "out_of_radius", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	if _graph.definition_path(edge.to_sector).is_empty():
		return {"reason": "invalid_destination", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}
	return {"reason": "", "from_sector": from_sector, "to_sector": to_sector, "entry_anchor": entry_anchor}


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


func _authorized(candidate: RefCounted) -> bool:
	return _authority != null and candidate == _authority


func _build_runtime(id: String, path: String) -> SectorRuntime:
	var definition: SectorDefinition
	if _loader.is_valid():
		definition = _loader.call(path) as SectorDefinition
	elif ResourceLoader.exists(path):
		definition = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	if definition == null or definition.stable_id != id or not _graph.matches_definition(definition):
		return null
	return SectorRuntime.build(definition)


static func _transition_dto(accepted: bool, reason: String, from_sector: String, to_sector: String,
		gate_id: String, entry_anchor: String) -> Dictionary:
	return {"accepted": accepted, "reason": reason, "from_sector": from_sector, "to_sector": to_sector,
		"gate_id": gate_id, "entry_anchor": entry_anchor}
