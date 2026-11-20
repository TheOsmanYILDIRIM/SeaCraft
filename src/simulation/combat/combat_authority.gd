class_name CombatAuthority
extends RefCounted

signal ship_sunk(entity_id: String, sequence_id: int)

const FIRE := "fire_weapon"
const SELECT := "select_combat_target"
const MAX_RELOAD_SECONDS := 3600.0

var _sector: SectorRuntime
var _streams: SeedStreams
var _targeting := TargetingService.new()
var _roster: Dictionary = {}
var _tick := 0
var _sequence := 0
var _tick_rate: int


func _init(sector: SectorRuntime, streams: SeedStreams, tick_rate: int = 60) -> void:
	_sector = sector
	_streams = streams
	_tick_rate = clampi(tick_rate, 1, 1000)


# Configuration is copied at registration; no Resource loading, sorting or copying on fire.
func register(id: String, faction: String, max_hull: float, weapon: WeaponDefinition = null,
		defense: float = 0.0, dodge: float = 0.0, selectable: bool = true,
		attack_modifiers: Dictionary = {}, mounted_side: int = 0) -> bool:
	if _sector == null or not SectorIds.valid(id) or not SectorIds.valid(faction) or _roster.has(id):
		return false
	if not _sector.entity_position(id).is_finite() or not is_finite(max_hull) or max_hull <= 0.0:
		return false
	if not is_finite(defense) or defense < 0.0 or not probability(dodge) or absi(mounted_side) > 1:
		return false
	var ship := CombatantState.new()
	ship.faction_id = faction
	ship.max_hull = max_hull
	ship.hull = max_hull
	ship.defense = defense
	ship.dodge = dodge
	ship.selectable = selectable
	if weapon != null:
		if not _valid_weapon(weapon) or not _valid_modifiers(attack_modifiers):
			return false
		var critical_base := weapon.base_damage * weapon.crit_multiplier
		if not is_finite(critical_base):
			return false
		var normal := StatModifierPipeline.apply_from_dictionary(weapon.base_damage, attack_modifiers)
		var critical := StatModifierPipeline.apply_from_dictionary(critical_base, attack_modifiers)
		if not is_finite(normal) or not is_finite(critical):
			return false
		ship.normal_damage = maxf(0.0, normal)
		ship.critical_damage = maxf(0.0, critical)
		ship.battery = WeaponBattery.new()
		ship.battery.weapon = weapon.duplicate() as WeaponDefinition
		ship.battery.mounted_side = mounted_side
		ship.battery.reload_ticks = maxi(1, ceili(weapon.reload_seconds * _tick_rate))
	_roster[id] = ship
	return true


func advance_tick() -> void:
	_tick += 1


func acquire(attacker_id: String, point: Vector2, radius: float) -> String:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		return ""
	return _targeting.acquire(_sector, point, radius, attacker_id, attacker.faction_id, _roster)


func acquisition_inspected() -> int:
	return _targeting.last_inspected


func select(attacker_id: String, target_id: String) -> bool:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		return false
	if not TargetingService.rejection(_sector, attacker_id, attacker.faction_id, target_id, _roster).is_empty():
		return false
	attacker.locked_id = target_id
	return true


func clear_target(attacker_id: String) -> void:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker != null:
		attacker.locked_id = ""


func locked_target(attacker_id: String) -> String:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		clear_target(attacker_id)
		return ""
	if not TargetingService.rejection(_sector, attacker_id, attacker.faction_id, attacker.locked_id, _roster).is_empty():
		attacker.locked_id = ""
	return attacker.locked_id


func hull(id: String) -> float:
	var ship: CombatantState = _roster.get(id)
	return ship.hull if ship != null else 0.0


# attacker_id and heading come from the authority-owned actor, never from the intent.
# An accepted volley uses exactly two encounter rolls, including misses and guaranteed hits.
func fire(attacker_id: String, heading: float, command: Dictionary) -> Dictionary:
	var target_value: Variant = command.get("target_id")
	var target_id := str(target_value) if target_value is String else ""
	var result := CombatTransaction.dto(attacker_id, target_id)
	if command.size() != 3 or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY or command.get("type") != FIRE or not target_value is String or not SectorIds.valid(target_id) or not is_finite(heading):
		return _reject(result, "malformed_command")
	var attacker: CombatantState = _roster.get(attacker_id)
	var origin := _sector.entity_position(attacker_id) if _sector != null else Vector2.INF
	if attacker == null or attacker.battery == null or not origin.is_finite() or _streams == null:
		return _reject(result, "invalid_attacker")
	if attacker.sunk():
		return _reject(result, "sunk_attacker")
	var battery := attacker.battery
	var weapon := battery.weapon
	result["weapon_id"] = weapon.stable_id
	var reason := TargetingService.rejection(_sector, attacker_id, attacker.faction_id, target_id, _roster)
	if not reason.is_empty():
		return _reject(result, reason)
	var target: CombatantState = _roster[target_id]
	result["remaining_hull"] = target.hull
	if attacker.locked_id != target_id:
		return _reject(result, "target_not_locked")
	var offset := _sector.entity_position(target_id) - origin
	var distance := offset.length()
	result["distance"] = distance
	if distance < weapon.min_range_meters or distance > weapon.range_meters:
		return _reject(result, "out_of_range")
	var side := broadside(heading, offset, weapon.broadside_half_arc_degrees)
	result["side"] = side
	if side == 0 or (battery.mounted_side != 0 and battery.mounted_side != side):
		return _reject(result, "invalid_arc")
	if _tick < battery.ready_tick:
		return _reject(result, "reloading")

	var hit := _roll_passes(_streams.next_float(SeedStreams.STREAM_ENCOUNTER), weapon.accuracy * (1.0 - target.dodge))
	var crit_roll := _streams.next_float(SeedStreams.STREAM_ENCOUNTER)
	var crit := hit and _roll_passes(crit_roll, weapon.crit_chance)
	var raw := (attacker.critical_damage if crit else attacker.normal_damage) if hit else 0.0
	var prevented := minf(raw, maxf(0.0, target.defense - weapon.defense_penetration))
	var applied := minf(target.hull, raw - prevented)
	target.hull = maxf(0.0, target.hull - applied)
	battery.ready_tick = _tick + battery.reload_ticks
	battery.last_side = side
	_sequence += 1
	result["accepted"] = true
	result["sequence_id"] = _sequence
	result["hit"] = hit
	result["crit"] = crit
	result["raw_damage"] = raw
	result["prevented_damage"] = prevented
	result["applied_hull_damage"] = applied
	result["remaining_hull"] = target.hull
	result["sunk"] = target.sunk()
	if target.sunk():
		attacker.locked_id = ""
		ship_sunk.emit(target_id, _sequence)
	return result


static func fire_intent(target_id: String) -> Dictionary:
	return {"domain": GameplayCommand.DOMAIN_GAMEPLAY, "type": FIRE, "target_id": target_id}


static func broadside(heading: float, offset: Vector2, half_arc_degrees: float) -> int:
	if not is_finite(heading) or not offset.is_finite() or offset == Vector2.ZERO or not is_finite(half_arc_degrees) or half_arc_degrees <= 0.0 or half_arc_degrees >= 90.0:
		return 0
	var bearing := offset.angle()
	var difference := ShipMotor.signed_angular_difference(heading, bearing)
	if absf(absf(difference) - PI * 0.5) > deg_to_rad(half_arc_degrees) + 0.000001:
		return 0
	return ShipMotor.side_for_heading(heading, bearing)


static func probability(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0


static func _roll_passes(roll: float, chance: float) -> bool:
	return chance >= 1.0 or roll < chance


static func _reject(result: Dictionary, reason: String) -> Dictionary:
	result["reason"] = reason
	return result


static func _valid_weapon(weapon: WeaponDefinition) -> bool:
	return (SectorIds.valid(weapon.stable_id) and is_finite(weapon.base_damage) and weapon.base_damage >= 0.0
		and is_finite(weapon.min_range_meters) and weapon.min_range_meters >= 0.0
		and is_finite(weapon.range_meters) and weapon.range_meters >= weapon.min_range_meters
		and is_finite(weapon.reload_seconds) and weapon.reload_seconds > 0.0 and weapon.reload_seconds <= MAX_RELOAD_SECONDS
		and probability(weapon.accuracy) and probability(weapon.crit_chance)
		and is_finite(weapon.crit_multiplier) and weapon.crit_multiplier >= 1.0
		and is_finite(weapon.broadside_half_arc_degrees) and weapon.broadside_half_arc_degrees > 0.0 and weapon.broadside_half_arc_degrees < 90.0
		and is_finite(weapon.defense_penetration) and weapon.defense_penetration >= 0.0)


static func _valid_modifiers(modifiers: Dictionary) -> bool:
	for id in modifiers:
		if not id is String or not SectorIds.valid(id):
			return false
		var entry: Variant = modifiers[id]
		if not entry is Dictionary or not StatModifierPipeline.PHASE_ORDER.has(entry.get("operation")):
			return false
		var amount: Variant = entry.get("value")
		if (not amount is float and not amount is int) or not is_finite(float(amount)) or not entry.get("priority", 0) is int:
			return false
	return true
