class_name FleetCommand
extends RefCounted

const FOLLOW_LEADER := "follow_leader"
const OCCUPY_SLOT := "occupy_slot"
const PROTECT_LEADER := "protect_leader"
const BREAK_FORMATION := "break_formation"
const REGROUP := "regroup"
const DOCK := "dock"
const ROUTE_JOB := "route_job"
const PATROL := "patrol"
const TRADE_ROUTE := "trade_route"
const SALVAGE_ROUTE := "salvage_route"
const SUPPORT_RESPONSE := "support_response"

const KINDS := [
	FOLLOW_LEADER, OCCUPY_SLOT, PROTECT_LEADER, BREAK_FORMATION, REGROUP,
	DOCK, ROUTE_JOB, PATROL, TRADE_ROUTE, SALVAGE_ROUTE, SUPPORT_RESPONSE,
]


static func create(fleet_id: String, commander_id: String, member_id: String, command_id: String,
		kind: String, target_goal_id: String, destination: Vector2, formation_slot: Dictionary,
		issued_tick: int, sequence: int, reason: String) -> Dictionary:
	if not SectorIds.valid(fleet_id) or not SectorIds.valid(commander_id) or not SectorIds.valid(member_id):
		return {}
	if not SectorIds.valid(command_id) or kind not in KINDS or issued_tick < 0 or sequence < 0:
		return {}
	if not target_goal_id.is_empty() and not SectorIds.valid(target_goal_id):
		return {}
	if reason.is_empty() or reason.length() > 128 or not DtoContract.is_primitive_safe(formation_slot):
		return {}
	var dest := {} if not destination.is_finite() else {"x": destination.x, "y": destination.y}
	var dto := {
		"fleet_id": fleet_id,
		"commander_id": commander_id,
		"member_id": member_id,
		"command_id": command_id,
		"kind": kind,
		"target_goal_id": target_goal_id,
		"destination": dest,
		"formation_slot": formation_slot.duplicate(true),
		"issued_tick": issued_tick,
		"sequence": sequence,
		"reason": reason,
	}
	return dto if valid(dto) else {}


static func valid(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var dto: Dictionary = value
	for key in ["fleet_id", "commander_id", "member_id", "command_id"]:
		if not dto.get(key) is String or not SectorIds.valid(dto[key]):
			return false
	if str(dto.get("kind", "")) not in KINDS:
		return false
	var goal: Variant = dto.get("target_goal_id", "")
	if not goal is String or (not goal.is_empty() and not SectorIds.valid(goal)):
		return false
	if not dto.get("destination") is Dictionary or not dto.get("formation_slot") is Dictionary:
		return false
	var dest: Dictionary = dto["destination"]
	if not dest.is_empty():
		if dest.size() != 2 or typeof(dest.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(dest.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(dest["x"])) or not is_finite(float(dest["y"])):
			return false
	for key in ["issued_tick", "sequence"]:
		if typeof(dto.get(key)) not in [TYPE_INT, TYPE_FLOAT] or int(dto[key]) < 0 or float(dto[key]) != float(int(dto[key])):
			return false
	return dto.get("reason") is String and not str(dto["reason"]).is_empty() and str(dto["reason"]).length() <= 128
