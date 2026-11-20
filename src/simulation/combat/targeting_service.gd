class_name TargetingService
extends RefCounted

var _candidates: Array[String] = []
var last_inspected := 0


func acquire(sector: SectorRuntime, point: Vector2, radius: float, attacker: String, faction: String, roster: Dictionary) -> String:
	last_inspected = sector.spatial.query_radius(point, radius, _candidates)
	var best := ""
	var best_squared := INF
	for id in _candidates:
		if not rejection(sector, attacker, faction, id, roster).is_empty():
			continue
		var squared := point.distance_squared_to(sector.entity_position(id))
		if squared < best_squared or (squared == best_squared and id < best):
			best_squared = squared
			best = id
	return best


static func rejection(sector: SectorRuntime, attacker: String, faction: String, id: String, roster: Dictionary) -> String:
	var target: CombatantState = roster.get(id)
	if target == null or not sector.entity_position(id).is_finite():
		return "invalid_target"
	if target.sunk():
		return "sunk_target"
	if id == attacker or target.faction_id == faction:
		return "friendly_target"
	if not target.selectable:
		return "invalid_target"
	return ""
