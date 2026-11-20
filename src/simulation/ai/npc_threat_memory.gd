class_name NpcThreatMemory
extends RefCounted

var attacker_id: String = ""
var value: int = 0
var last_threat_tick: int = -1
var last_decay_tick: int = 0
var last_known_position: Vector2 = Vector2.ZERO


func record(attacker: String, damage: float, position: Vector2, simulation_tick: int,
		max_threat: int, threat_per_damage: float) -> bool:
	if not SectorIds.valid(attacker) or not is_finite(damage) or damage <= 0.0 or not position.is_finite():
		return false
	if simulation_tick < 0 or max_threat <= 0 or not is_finite(threat_per_damage) or threat_per_damage <= 0.0:
		return false
	var added := maxi(1, roundi(damage * threat_per_damage))
	if value == 0 or attacker_id == attacker:
		attacker_id = attacker
		value = clampi(value + added, 0, max_threat)
	elif added > value or (added == value and attacker < attacker_id):
		attacker_id = attacker
		value = mini(added, max_threat)
	else:
		return false
	last_threat_tick = simulation_tick
	last_decay_tick = simulation_tick
	last_known_position = position
	return true


func decay_to(simulation_tick: int, interval_ticks: int, amount: int) -> void:
	if value <= 0 or simulation_tick <= last_decay_tick or interval_ticks <= 0 or amount <= 0:
		return
	var intervals := floori(float(simulation_tick - last_decay_tick) / float(interval_ticks))
	if intervals <= 0:
		return
	value = maxi(0, value - intervals * amount)
	last_decay_tick += intervals * interval_ticks


func clear() -> void:
	attacker_id = ""
	value = 0
	last_threat_tick = -1
	last_decay_tick = 0
	last_known_position = Vector2.ZERO
