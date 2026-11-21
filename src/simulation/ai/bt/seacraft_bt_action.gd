class_name SeaCraftBtAction
extends ActionLeaf

var action_kind: String = ""
var timeout_ticks: int = 0
var _handler_target: WeakRef
var _handler_method: StringName = &""
var current_tick: int = 0
var timed_out: bool = false
var interrupted: bool = false

var _started_tick: int = -1
var _restored_started_tick: int = -1


func configure(callback: Callable, timeout: int) -> bool:
	if not callback.is_valid():
		return false
	var target := callback.get_object()
	var method := callback.get_method()
	if target == null or method == StringName():
		return false
	return configure_target(weakref(target), method, timeout)


func configure_target(target: WeakRef, method: StringName, timeout: int) -> bool:
	if target == null or target.get_ref() == null or method == StringName():
		return false
	if timeout <= 0 or timeout > CoreCombatRules.MAX_DURATION:
		return false
	_handler_target = target
	_handler_method = method
	timeout_ticks = timeout
	return true


func before_run(_actor: Node, _blackboard: Blackboard) -> void:
	interrupted = false
	timed_out = false
	if _started_tick < 0:
		_started_tick = _restored_started_tick if _restored_started_tick >= 0 else current_tick
		_restored_started_tick = -1


func tick(_actor: Node, _blackboard: Blackboard) -> int:
	var target := _handler_target.get_ref() if _handler_target != null else null
	if target == null or _handler_method == StringName() or action_kind.is_empty() or current_tick < 0:
		return FAILURE
	if _started_tick < 0:
		_started_tick = current_tick
	if current_tick - _started_tick >= timeout_ticks:
		timed_out = true
		return FAILURE
	var response: Variant = target.call(_handler_method, action_kind, current_tick)
	if not response is int or int(response) not in [SUCCESS, FAILURE, RUNNING]:
		return FAILURE
	return int(response)


func interrupt(_actor: Node, _blackboard: Blackboard) -> void:
	interrupted = true
	var target := _handler_target.get_ref() if _handler_target != null else null
	if target != null and _handler_method != StringName():
		target.call(_handler_method, "interrupt:%s" % action_kind, current_tick)
	_started_tick = -1
	_restored_started_tick = -1
	# Do not call BeehaveNode.interrupt(): upstream's debugger message helper
	# assumes an active editor debugger. SeaCraft runs this detached/manual tree
	# in headless authority as well as exported runtime.


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
