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


func snapshot_state() -> Dictionary:
	return {
		"attacker_id": attacker_id,
		"value": value,
		"last_threat_tick": last_threat_tick,
		"last_decay_tick": last_decay_tick,
		"last_known_x": last_known_position.x,
		"last_known_y": last_known_position.y,
	}


func restore_state(state: Variant) -> bool:
	if not state is Dictionary or state.size() != 6:
		return false
	var dto: Dictionary = state
	var raw_attacker: Variant = dto.get("attacker_id")
	if not raw_attacker is String or (not raw_attacker.is_empty() and not SectorIds.valid(raw_attacker)):
		return false
	if not _integer(dto.get("value")) or int(dto["value"]) < 0:
		return false
	if not _integer(dto.get("last_threat_tick")) or int(dto["last_threat_tick"]) < -1:
		return false
	if not _integer(dto.get("last_decay_tick")) or int(dto["last_decay_tick"]) < 0:
		return false
	if typeof(dto.get("last_known_x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(dto.get("last_known_y")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var restored_position := Vector2(float(dto["last_known_x"]), float(dto["last_known_y"]))
	if not restored_position.is_finite():
		return false
	attacker_id = raw_attacker
	value = int(dto["value"])
	last_threat_tick = int(dto["last_threat_tick"])
	last_decay_tick = int(dto["last_decay_tick"])
	last_known_position = restored_position
	return true


func clear() -> void:
	attacker_id = ""
	value = 0
	last_threat_tick = -1
	last_decay_tick = 0
	last_known_position = Vector2.ZERO


static func _integer(value_in: Variant) -> bool:
	if typeof(value_in) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value_in)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
