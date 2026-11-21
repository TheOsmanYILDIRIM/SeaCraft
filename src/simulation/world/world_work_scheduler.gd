class_name WorldWorkScheduler
extends RefCounted

const VERSION := 1
const MAX_NEAR_DECISIONS_PER_TICK := 8
const MAX_MID_UPDATES_PER_TICK := 6
const MAX_FAR_UPDATES_PER_TICK := 8
const MAX_PATH_JOBS_PER_TICK := 4
const MAX_SPAWN_JOBS_PER_TICK := 4
const MAX_PENDING_JOBS := 512
const MAX_WAIT_TICKS := 240

var _authority_enabled := true
var _current_tick := 0
var _sequence := 0
var _queues := {"near": [], "mid": [], "far": [], "path": [], "spawn": []}
var _index := {"near": {}, "mid": {}, "far": {}, "path": {}, "spawn": {}}
var _max_pending_observed := 0
var _starvation_count := 0
var _processed := {"near": 0, "mid": 0, "far": 0, "path": 0, "spawn": 0}
var _max_processed_tick := {"near": 0, "mid": 0, "far": 0, "path": 0, "spawn": 0}


func _init(authority_enabled: bool = true) -> void:
	_authority_enabled = authority_enabled


func enqueue(kind: String, stable_id: String, goal_id: String, due_tick: int) -> bool:
	if not _authority_enabled or kind not in _queues or not SectorIds.valid(stable_id) or due_tick < 0:
		return false
	if not goal_id.is_empty() and not SectorIds.valid(goal_id):
		return false
	var key := stable_id
	var by_id: Dictionary = _index[kind]
	if by_id.has(key):
		var row: Dictionary = by_id[key]
		# Coalesce compatible work; explicit new goals replace payload but preserve age.
		row["goal_id"] = goal_id
		row["due_tick"] = mini(int(row["due_tick"]), due_tick)
		by_id[key] = row
		_index[kind] = by_id
		_rebuild_queue(kind)
		return true
	if pending_count() >= MAX_PENDING_JOBS:
		return false
	var new_row := {
		"stable_id": stable_id,
		"goal_id": goal_id,
		"due_tick": due_tick,
		"enqueued_tick": _current_tick,
		"sequence": _sequence,
	}
	_sequence += 1
	var queue: Array = _queues[kind]
	queue.append(new_row)
	_queues[kind] = queue
	by_id[key] = new_row
	_index[kind] = by_id
	_max_pending_observed = maxi(_max_pending_observed, pending_count())
	return true


func advance_tick(tick: int) -> Dictionary:
	if not _authority_enabled or tick < _current_tick:
		return {}
	_current_tick = tick
	var result := {}
	for kind in ["near", "mid", "far", "path", "spawn"]:
		var rows := _drain(kind, _budget(kind))
		result[kind] = rows
		_processed[kind] = int(_processed[kind]) + rows.size()
		_max_processed_tick[kind] = maxi(int(_max_processed_tick[kind]), rows.size())
	_update_starvation()
	return result


func pending_count() -> int:
	var total := 0
	for kind in _queues:
		total += (_queues[kind] as Array).size()
	return total


func snapshot_state() -> Dictionary:
	var queues := {}
	for kind in _queues:
		var rows: Array = []
		for raw in _queues[kind]:
			rows.append((raw as Dictionary).duplicate(true))
		rows.sort_custom(_job_before)
		queues[kind] = rows
	return {
		"version": VERSION,
		"current_tick": _current_tick,
		"sequence": _sequence,
		"queues": queues,
	}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 4 or int(state.get("version", -1)) != VERSION:
		return false
	if not _integer(state.get("current_tick")) or int(state["current_tick"]) < 0:
		return false
	if not _integer(state.get("sequence")) or int(state["sequence"]) < 0:
		return false
	var queues: Variant = state.get("queues")
	if not queues is Dictionary or queues.size() != 5:
		return false
	var planned_queues := {"near": [], "mid": [], "far": [], "path": [], "spawn": []}
	var planned_index := {"near": {}, "mid": {}, "far": {}, "path": {}, "spawn": {}}
	var total := 0
	for kind in planned_queues:
		var raw_rows: Variant = queues.get(kind)
		if not raw_rows is Array:
			return false
		var planned_rows: Array = planned_queues[kind]
		var planned_by_id: Dictionary = planned_index[kind]
		for raw in raw_rows:
			if not _valid_job(raw):
				return false
			var row: Dictionary = (raw as Dictionary).duplicate(true)
			if planned_by_id.has(row["stable_id"]):
				return false
			planned_rows.append(row)
			planned_by_id[row["stable_id"]] = row
			total += 1
			if total > MAX_PENDING_JOBS:
				return false
		planned_queues[kind] = planned_rows
		planned_index[kind] = planned_by_id
	_current_tick = int(state["current_tick"])
	_sequence = int(state["sequence"])
	_queues = planned_queues
	_index = planned_index
	_max_pending_observed = total
	_starvation_count = 0
	_processed = {"near": 0, "mid": 0, "far": 0, "path": 0, "spawn": 0}
	_max_processed_tick = {"near": 0, "mid": 0, "far": 0, "path": 0, "spawn": 0}
	return true


func telemetry() -> Dictionary:
	return {
		"current_tick": _current_tick,
		"pending_jobs": pending_count(),
		"max_pending_jobs": _max_pending_observed,
		"starvation_count": _starvation_count,
		"near_processed": int(_processed["near"]),
		"mid_processed": int(_processed["mid"]),
		"far_processed": int(_processed["far"]),
		"path_processed": int(_processed["path"]),
		"spawn_processed": int(_processed["spawn"]),
		"max_near_decisions_per_tick": int(_max_processed_tick["near"]),
		"max_mid_updates_per_tick": int(_max_processed_tick["mid"]),
		"max_far_updates_per_tick": int(_max_processed_tick["far"]),
		"max_path_jobs_per_tick": int(_max_processed_tick["path"]),
		"max_spawn_jobs_per_tick": int(_max_processed_tick["spawn"]),
	}


func _drain(kind: String, budget: int) -> Array:
	var queue: Array = _queues[kind]
	queue.sort_custom(_job_before)
	var result: Array = []
	var remaining: Array = []
	for raw in queue:
		var row: Dictionary = raw
		if result.size() < budget and int(row["due_tick"]) <= _current_tick:
			result.append(row.duplicate(true))
			(_index[kind] as Dictionary).erase(row["stable_id"])
		else:
			remaining.append(row)
	_queues[kind] = remaining
	return result


func _rebuild_queue(kind: String) -> void:
	var rows: Array = []
	for row in (_index[kind] as Dictionary).values():
		rows.append(row)
	rows.sort_custom(_job_before)
	_queues[kind] = rows


func _update_starvation() -> void:
	var count := 0
	for kind in _queues:
		for raw in _queues[kind]:
			if _current_tick - int(raw["enqueued_tick"]) > MAX_WAIT_TICKS:
				count += 1
	_starvation_count = count


static func _job_before(a: Dictionary, b: Dictionary) -> bool:
	if int(a["due_tick"]) != int(b["due_tick"]):
		return int(a["due_tick"]) < int(b["due_tick"])
	if int(a["enqueued_tick"]) != int(b["enqueued_tick"]):
		return int(a["enqueued_tick"]) < int(b["enqueued_tick"])
	if str(a["stable_id"]) != str(b["stable_id"]):
		return str(a["stable_id"]) < str(b["stable_id"])
	return int(a["sequence"]) < int(b["sequence"])


static func _valid_job(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5:
		return false
	var row: Dictionary = value
	if not row.get("stable_id") is String or not SectorIds.valid(row["stable_id"]):
		return false
	if not row.get("goal_id") is String or (not row["goal_id"].is_empty() and not SectorIds.valid(row["goal_id"])):
		return false
	for key in ["due_tick", "enqueued_tick", "sequence"]:
		if not _integer(row.get(key)) or int(row[key]) < 0:
			return false
	return true


static func _budget(kind: String) -> int:
	match kind:
		"near": return MAX_NEAR_DECISIONS_PER_TICK
		"mid": return MAX_MID_UPDATES_PER_TICK
		"far": return MAX_FAR_UPDATES_PER_TICK
		"path": return MAX_PATH_JOBS_PER_TICK
		"spawn": return MAX_SPAWN_JOBS_PER_TICK
	return 0


static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= 2147483647.0
