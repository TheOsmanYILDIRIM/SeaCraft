class_name DockAuthority
extends RefCounted

const VERSION := 1
const MAX_DOCKS := 32
const MAX_QUEUE_SIZE := 32
const MAX_CAPACITY := 8

var request_count := 0
var admission_count := 0
var queue_operation_count := 0
var queue_max_observed := 0

var _authority_enabled := true
var _docks: Dictionary = {}


func _init(authority_enabled: bool = true) -> void:
	_authority_enabled = authority_enabled


func register_dock(dock_id: String, sector_id: String, capacity: int, anchor: Vector2, waiting_spacing: float = 48.0) -> bool:
	if not _authority_enabled or _docks.size() >= MAX_DOCKS or _docks.has(dock_id):
		return false
	if not SectorIds.valid(dock_id) or not SectorIds.valid(sector_id) or capacity <= 0 or capacity > MAX_CAPACITY:
		return false
	if not anchor.is_finite() or not is_finite(waiting_spacing) or waiting_spacing <= 0.0 or waiting_spacing > 512.0:
		return false
	_docks[dock_id] = {
		"dock_id": dock_id,
		"sector_id": sector_id,
		"capacity": capacity,
		"anchor": {"x": anchor.x, "y": anchor.y},
		"waiting_spacing": waiting_spacing,
		"queue": [],
		"admitted": [],
	}
	return true


func request(dock_id: String, member_id: String, requested_tick: int) -> bool:
	if not _authority_enabled or not SectorIds.valid(member_id) or requested_tick < 0:
		return false
	var dock_state: Dictionary = _docks.get(dock_id, {})
	if dock_state.is_empty():
		return false
	if (dock_state["admitted"] as Array).has(member_id):
		return true
	for raw in dock_state["queue"]:
		if raw is Dictionary and raw.get("member_id") == member_id:
			return true
	var queue: Array = dock_state["queue"]
	if queue.size() >= MAX_QUEUE_SIZE:
		return false
	queue.append({"member_id": member_id, "requested_tick": requested_tick})
	queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["requested_tick"]) != int(b["requested_tick"]):
			return int(a["requested_tick"]) < int(b["requested_tick"])
		return str(a["member_id"]) < str(b["member_id"])
	)
	dock_state["queue"] = queue
	_docks[dock_id] = dock_state
	request_count += 1
	queue_operation_count += 1
	queue_max_observed = maxi(queue_max_observed, queue.size())
	return true


func process_queue(dock_id: String, eligible_members: Array[String]) -> Array[String]:
	var admitted_now: Array[String] = []
	if not _authority_enabled:
		return admitted_now
	var dock_state: Dictionary = _docks.get(dock_id, {})
	if dock_state.is_empty():
		return admitted_now
	var eligible: Dictionary = {}
	for id in eligible_members:
		if SectorIds.valid(id):
			eligible[id] = true
	var kept_admitted: Array = []
	for id in dock_state["admitted"]:
		if eligible.has(id):
			kept_admitted.append(id)
	var kept_queue: Array = []
	for raw in dock_state["queue"]:
		if raw is Dictionary and eligible.has(str(raw.get("member_id", ""))):
			kept_queue.append(raw)
	kept_queue.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["requested_tick"]) != int(b["requested_tick"]):
			return int(a["requested_tick"]) < int(b["requested_tick"])
		return str(a["member_id"]) < str(b["member_id"])
	)
	while kept_admitted.size() < int(dock_state["capacity"]) and not kept_queue.is_empty():
		var next: Dictionary = kept_queue.pop_front()
		var id := str(next["member_id"])
		if not kept_admitted.has(id):
			kept_admitted.append(id)
			admitted_now.append(id)
			admission_count += 1
	dock_state["admitted"] = kept_admitted
	dock_state["queue"] = kept_queue
	_docks[dock_id] = dock_state
	queue_operation_count += 1
	return admitted_now


func cancel(dock_id: String, member_id: String) -> bool:
	if not _authority_enabled:
		return false
	var dock_state: Dictionary = _docks.get(dock_id, {})
	if dock_state.is_empty():
		return false
	var changed := false
	var queue: Array = []
	for raw in dock_state["queue"]:
		if raw is Dictionary and raw.get("member_id") == member_id:
			changed = true
		else:
			queue.append(raw)
	var admitted: Array = dock_state["admitted"]
	if admitted.has(member_id):
		admitted.erase(member_id)
		changed = true
	dock_state["admitted"] = admitted
	dock_state["queue"] = queue
	_docks[dock_id] = dock_state
	if changed:
		queue_operation_count += 1
	return changed


func release(dock_id: String, member_id: String) -> bool:
	if not _authority_enabled:
		return false
	var dock_state: Dictionary = _docks.get(dock_id, {})
	if dock_state.is_empty():
		return false
	var admitted: Array = dock_state["admitted"]
	if not admitted.has(member_id):
		return false
	admitted.erase(member_id)
	dock_state["admitted"] = admitted
	_docks[dock_id] = dock_state
	queue_operation_count += 1
	return true


func waiting_position(dock_id: String, member_id: String) -> Vector2:
	var dock_state: Dictionary = _docks.get(dock_id, {})
	if dock_state.is_empty():
		return Vector2.INF
	var index := -1
	for i in (dock_state["queue"] as Array).size():
		if dock_state["queue"][i].get("member_id") == member_id:
			index = i
			break
	if index < 0:
		return Vector2.INF
	var anchor := Vector2(float(dock_state["anchor"]["x"]), float(dock_state["anchor"]["y"]))
	var spacing := float(dock_state["waiting_spacing"])
	var side := -1.0 if index % 2 == 0 else 1.0
	var row := float(index / 2 + 1)
	return anchor + Vector2(side * spacing, row * spacing)


func queue_ids(dock_id: String) -> Array[String]:
	var result: Array[String] = []
	var dock_state: Dictionary = _docks.get(dock_id, {})
	for raw in dock_state.get("queue", []):
		result.append(str(raw["member_id"]))
	return result


func admitted_ids(dock_id: String) -> Array[String]:
	var result: Array[String] = []
	var dock_state: Dictionary = _docks.get(dock_id, {})
	for id in dock_state.get("admitted", []):
		result.append(str(id))
	return result


func snapshot_state() -> Dictionary:
	var docks: Array = []
	var ids := _docks.keys()
	ids.sort()
	for id in ids:
		docks.append((_docks[id] as Dictionary).duplicate(true))
	return {"version": VERSION, "docks": docks}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if int(state.get("version", -1)) != VERSION or not state.get("docks") is Array or state["docks"].size() > MAX_DOCKS:
		return false
	var planned: Dictionary = {}
	for raw in state["docks"]:
		if not raw is Dictionary:
			return false
		var row: Dictionary = raw.duplicate(true)
		var id := str(row.get("dock_id", ""))
		var sector_id := str(row.get("sector_id", ""))
		var capacity := int(row.get("capacity", 0))
		if not SectorIds.valid(id) or not SectorIds.valid(sector_id) or capacity <= 0 or capacity > MAX_CAPACITY or planned.has(id):
			return false
		if not row.get("anchor") is Dictionary or not row.get("queue") is Array or not row.get("admitted") is Array:
			return false
		if row["queue"].size() > MAX_QUEUE_SIZE or row["admitted"].size() > capacity:
			return false
		planned[id] = row
	_docks = planned
	return true


func telemetry() -> Dictionary:
	return {
		"dock_requests": request_count,
		"dock_admissions": admission_count,
		"dock_queue_operations": queue_operation_count,
		"dock_queue_max": queue_max_observed,
	}
