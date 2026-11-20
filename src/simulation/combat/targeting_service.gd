class_name TargetingService
extends RefCounted

const SHIP := "ship"
const MONSTER := "monster"
const WRECK := "wreck"
const PICKUP := "pickup"
const CANNON := "cannon"
const HARPOON := "harpoon"
const TARGET_CLASSES := [SHIP, MONSTER, WRECK, PICKUP]

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


static func target_class_valid(value: String) -> bool:
	return value in TARGET_CLASSES


static func weapon_rejection(weapon_kind: String, target_class: String) -> String:
	if not target_class_valid(target_class):
		return "invalid_target_class"
	match weapon_kind:
		CANNON:
			return "" if target_class == SHIP else "wrong_target_class"
		HARPOON:
			return "" if target_class in [MONSTER, WRECK] else "wrong_target_class"
		_:
			return "invalid_weapon_class"


static func rejection(sector: SectorRuntime, attacker: String, faction: String, id: String, roster: Dictionary) -> String:
	var target: CombatantState = roster.get(id)
	if target == null or not sector.entity_position(id).is_finite():
		return "invalid_target"
	if not target_class_valid(target.target_class):
		return "invalid_target_class"
	if target.sunk():
		return "sunk_target"
	if id == attacker:
		return "friendly_target"
	if target.target_class != WRECK and target.faction_id == faction:
		return "friendly_target"
	if not target.selectable:
		return "invalid_target"
	return ""
