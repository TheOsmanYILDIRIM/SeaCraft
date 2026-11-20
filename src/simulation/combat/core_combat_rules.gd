class_name CoreCombatRules
extends RefCounted

const NEUTRAL := "element.neutral"
const FIRE := "element.fire"
const MAX_VALUE := 1000000000.0
const MAX_CLOCK := 2147483647
const MAX_DURATION := 3600000
const STOWED := "item.vs03_salvage_scrap"
const ROUND := "item.core_round"
const EMBER := "item.core_ember"
const ACTION := "action.brace"
const STATUSES := {
	"status.braced": {"max_stacks": 1, "duration": 120},
	"status.scorched": {"max_stacks": 3, "duration": 180},
}
const ACTIONS := {
	ACTION: {"item_id": STOWED, "cooldown": 180, "target": "self", "status": "status.braced"},
}


static func element_valid(id: String) -> bool:
	return id == NEUTRAL or id == FIRE


static func bounded(value: float, low: float, high: float) -> bool:
	return is_finite(value) and value >= low and value <= high


static func base_damage(weapon: WeaponDefinition, ammo: AmmoProfile, mods: Dictionary) -> float:
	var base := weapon.base_damage
	if ammo != null:
		base = maxf(0.0, base + ammo.damage_add) * ammo.damage_scale
	var modified := StatModifierPipeline.apply_from_dictionary(base, mods)
	return clampf(modified, 0.0, MAX_VALUE / 16.0) if is_finite(modified) else NAN


static func hit_chance(accuracy: float, dodge: float) -> float:
	return clampf(accuracy * (1.0 - dodge), 0.0, 1.0)


static func damage(base: float, crit_scale: float, resistance: float, defense: float, penetration: float, hull: float) -> Dictionary:
	var raw := clampf(base * crit_scale * (1.0 - resistance), 0.0, MAX_VALUE)
	var prevented := minf(raw, maxf(0.0, defense - penetration))
	return {"raw": raw, "prevented": prevented, "applied": minf(hull, raw - prevented)}


static func valid_resistances(values: Dictionary) -> bool:
	for id in values:
		if id != FIRE or typeof(values[id]) not in [TYPE_INT, TYPE_FLOAT] or not bounded(float(values[id]), -1.0, 1.0):
			return false
	return true


static func ammo(id: String, item: String, element: String, scale: float, status: String = "") -> AmmoProfile:
	var profile := AmmoProfile.new()
	profile.stable_id = id
	profile.item_id = item
	profile.element_id = element
	profile.damage_scale = scale
	profile.status_id = status
	return profile
