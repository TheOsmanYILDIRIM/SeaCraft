class_name WorldJob
extends RefCounted

const VERSION := 1
const PATROL := "patrol"
const TRADE := "trade"
const SALVAGE := "salvage"
const ESCORT := "escort"
const DOCK := "dock"
const TYPES := [PATROL, TRADE, SALVAGE, ESCORT, DOCK]

const READY := "ready"
const TRAVEL := "travel"
const QUEUE := "dock_queue"
const SERVICE := "dock_service"
const APPROACH := "approach"
const CLAIM := "claim"
const COMPLETE := "complete"


static func create(job_id: String, job_type: String, owner_id: String, origin_id: String,
		destination_id: String, route_sector_id: String, phase: String = READY,
		target_id: String = "", cargo_mission: Dictionary = {}) -> Dictionary:
	if not SectorIds.valid(job_id) or job_type not in TYPES or not SectorIds.valid(owner_id):
		return {}
	for id in [origin_id, destination_id, route_sector_id, target_id]:
		if not id.is_empty() and not SectorIds.valid(id):
			return {}
	if not cargo_mission.is_empty() and not valid_cargo_mission(cargo_mission):
		return {}
	var job := {
		"version": VERSION,
		"job_id": job_id,
		"job_type": job_type,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"route_sector_id": route_sector_id,
		"phase": phase,
		"owner_id": owner_id,
		"target_id": target_id,
		"cargo_mission": cargo_mission.duplicate(true),
		"progress": 0.0,
		"claimant_id": "",
		"completed": phase == COMPLETE,
	}
	return job if valid(job) else {}


static func cargo_mission(mission_id: String, cargo_definition_id: String, quantity: int,
		origin_id: String, destination_id: String, phase: String = READY) -> Dictionary:
	if not SectorIds.valid(mission_id) or not SectorIds.valid(cargo_definition_id) or quantity <= 0:
		return {}
	if not SectorIds.valid(origin_id) or not SectorIds.valid(destination_id) or phase.is_empty():
		return {}
	return {
		"mission_id": mission_id,
		"cargo_definition_id": cargo_definition_id,
		"quantity": quantity,
		"origin_id": origin_id,
		"destination_id": destination_id,
		"phase": phase,
	}


static func with_phase(job: Dictionary, phase: String, progress: float) -> Dictionary:
	if not valid(job) or phase.is_empty() or not is_finite(progress) or progress < 0.0 or progress > 1.0:
		return {}
	var result := job.duplicate(true)
	result["phase"] = phase
	result["progress"] = progress
	result["completed"] = phase == COMPLETE
	if not result["cargo_mission"].is_empty():
		result["cargo_mission"]["phase"] = phase
	return result if valid(result) else {}


static func claim_salvage(job: Dictionary, claimant_id: String) -> Dictionary:
	if not valid(job) or job["job_type"] != SALVAGE or not SectorIds.valid(claimant_id):
		return {}
	var existing := str(job.get("claimant_id", ""))
	if not existing.is_empty() and existing != claimant_id:
		return {}
	var result := job.duplicate(true)
	result["claimant_id"] = claimant_id
	result["phase"] = CLAIM
	return result


static func economy_event(job: Dictionary, event_id: String, event_type: String, tick: int) -> Dictionary:
	if not valid(job) or not SectorIds.valid(event_id) or event_type not in ["trade_delivered", "convoy_lost", "salvage_delivered"] or tick < 0:
		return {}
	return {
		"event_id": event_id,
		"event_type": event_type,
		"job_id": job["job_id"],
		"owner_id": job["owner_id"],
		"tick": tick,
	}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var job: Dictionary = value
	if int(job.get("version", -1)) != VERSION or not SectorIds.valid(str(job.get("job_id", ""))):
		return false
	if str(job.get("job_type", "")) not in TYPES or not SectorIds.valid(str(job.get("owner_id", ""))):
		return false
	for key in ["origin_id", "destination_id", "route_sector_id", "target_id", "claimant_id"]:
		var id: Variant = job.get(key, "")
		if not id is String or (not id.is_empty() and not SectorIds.valid(id)):
			return false
	if not job.get("phase") is String or str(job["phase"]).is_empty():
		return false
	if typeof(job.get("progress")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(job["progress"])) or float(job["progress"]) < 0.0 or float(job["progress"]) > 1.0:
		return false
	if not job.get("completed") is bool or not job.get("cargo_mission") is Dictionary:
		return false
	return job["cargo_mission"].is_empty() or valid_cargo_mission(job["cargo_mission"])


static func valid_cargo_mission(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var mission: Dictionary = value
	for key in ["mission_id", "cargo_definition_id", "origin_id", "destination_id"]:
		if not mission.get(key) is String or not SectorIds.valid(mission[key]):
			return false
	if typeof(mission.get("quantity")) not in [TYPE_INT, TYPE_FLOAT] or int(mission["quantity"]) <= 0 or float(mission["quantity"]) != float(int(mission["quantity"])):
		return false
	return mission.get("phase") is String and not str(mission["phase"]).is_empty()
