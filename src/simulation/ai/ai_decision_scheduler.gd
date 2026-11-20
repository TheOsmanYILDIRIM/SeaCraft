class_name AiDecisionScheduler
extends RefCounted

var decision_count: int = 0

var _physics_tick: int = 0
var _max_decisions_per_tick: int = 8
var _brains: Array[NpcBrain] = []
var _intervals: PackedInt32Array = PackedInt32Array()
var _next_due: PackedInt64Array = PackedInt64Array()
var _cursor: int = 0


func _init(max_decisions_per_tick: int = 8) -> void:
	_max_decisions_per_tick = clampi(max_decisions_per_tick, 1, 1024)


func register_brain(brain: NpcBrain, interval_ticks: int, stagger_offset: int = 0) -> bool:
	if brain == null or interval_ticks <= 1 or stagger_offset < 0 or stagger_offset >= interval_ticks:
		return false
	if _brains.has(brain):
		return false
	_brains.append(brain)
	_intervals.append(interval_ticks)
	_next_due.append(_physics_tick + 1 + stagger_offset)
	return true


func advance_physics_tick() -> int:
	_physics_tick += 1
	if _brains.is_empty():
		return 0
	var ran := 0
	var size := _brains.size()
	var last_index := _cursor
	for offset in size:
		if ran >= _max_decisions_per_tick:
			break
		var index := (_cursor + offset) % size
		if _physics_tick < _next_due[index]:
			continue
		if _brains[index].decision_tick(_physics_tick):
			decision_count += 1
		ran += 1
		_next_due[index] = _physics_tick + _intervals[index]
		last_index = index
	_cursor = (last_index + 1) % size
	return ran


func current_tick() -> int:
	return _physics_tick


func brain_count() -> int:
	return _brains.size()


func snapshot_state() -> Dictionary:
	return {"physics_tick": _physics_tick, "decision_count": decision_count}


func restore_state(value: Variant) -> bool:
	if not _brains.is_empty() or not value is Dictionary or value.size() != 2:
		return false
	var state: Dictionary = value
	if not _integer(state.get("physics_tick")) or int(state["physics_tick"]) < 0:
		return false
	if not _integer(state.get("decision_count")) or int(state["decision_count"]) < 0:
		return false
	_physics_tick = int(state["physics_tick"])
	decision_count = int(state["decision_count"])
	_cursor = 0
	return true


static func _integer(value_in: Variant) -> bool:
	if typeof(value_in) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value_in)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
