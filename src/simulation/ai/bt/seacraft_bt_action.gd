class_name SeaCraftBtAction
extends ActionLeaf

var action_kind: String = ""
var handler: Callable
var timeout_ticks: int = 0
var current_tick: int = 0
var timed_out: bool = false
var interrupted: bool = false

var _started_tick: int = -1
var _restored_started_tick: int = -1


func configure(callback: Callable, timeout: int) -> bool:
	if not callback.is_valid() or timeout <= 0 or timeout > CoreCombatRules.MAX_DURATION:
		return false
	handler = callback
	timeout_ticks = timeout
	return true


func before_run(_actor: Node, _blackboard: Blackboard) -> void:
	interrupted = false
	timed_out = false
	if _started_tick < 0:
		_started_tick = _restored_started_tick if _restored_started_tick >= 0 else current_tick
		_restored_started_tick = -1


func tick(_actor: Node, _blackboard: Blackboard) -> int:
	if not handler.is_valid() or action_kind.is_empty() or current_tick < 0:
		return FAILURE
	if _started_tick < 0:
		_started_tick = current_tick
	if current_tick - _started_tick >= timeout_ticks:
		timed_out = true
		return FAILURE
	var response: Variant = handler.call(action_kind, current_tick)
	if not response is int or int(response) not in [SUCCESS, FAILURE, RUNNING]:
		return FAILURE
	return int(response)


func interrupt(actor: Node, blackboard: Blackboard) -> void:
	interrupted = true
	if handler.is_valid():
		handler.call("interrupt:%s" % action_kind, current_tick)
	_started_tick = -1
	_restored_started_tick = -1
	super(actor, blackboard)


func after_run(_actor: Node, _blackboard: Blackboard) -> void:
	_started_tick = -1
	_restored_started_tick = -1


func started_tick() -> int:
	return _started_tick


func restore_started_tick(value: int) -> bool:
	if value < -1:
		return false
	_restored_started_tick = value
	return true
