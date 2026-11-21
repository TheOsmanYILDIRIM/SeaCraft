class_name AiBtRunner
extends RefCounted

const ACTION_DESTINATION := "destination"
const ACTION_WAIT_OBSERVE := "wait_observe"
const ACTION_STOP := "stop"
const ACTION_REPAIR := "repair"
const ACTION_TARGET := "target"
const VALID_ACTIONS := [
	ACTION_DESTINATION,
	ACTION_WAIT_OBSERVE,
	ACTION_STOP,
	ACTION_REPAIR,
	ACTION_TARGET,
]

var tick_count: int = 0
var success_count: int = 0
var failure_count: int = 0
var timeout_count: int = 0
var interrupt_count: int = 0

var _tree: BeehaveTree
var _leaf: SeaCraftBtAction
var _actor: Node
var _handler: Callable
var _current_intent_id: int = -1
var _current_action_kind: String = ""
var _last_status: int = -1
var _pending_restore: Dictionary = {}


func configure(actor: Node, handler: Callable) -> bool:
	if actor == null or not handler.is_valid() or not actor.is_inside_tree():
		return false
	if _tree != null:
		return false
	_actor = actor
	_handler = handler
	_tree = BeehaveTree.new()
	_tree.name = "SeaCraftAiBeehaveTree"
	_tree.actor = actor
	_tree.process_thread = BeehaveTree.ProcessThread.MANUAL
	# Keep the upstream Beehave tree detached. Manual scheduler ticks exercise the
	# real Beehave lifecycle without enabling its editor/debugger scene hooks.
	return _tree.process_thread == BeehaveTree.ProcessThread.MANUAL and not _tree.is_inside_tree() and not _tree.is_processing() and not _tree.is_physics_processing()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and _tree != null:
		_tree.free()
		_tree = null
		_leaf = null


func tick_intent(intent_id: int, simulation_tick: int, timeout_ticks: int) -> int:
	return tick_action_kind(_action_for_intent(intent_id), intent_id, simulation_tick, timeout_ticks)


func tick_action_kind(action_kind: String, semantic_intent_id: int, simulation_tick: int, timeout_ticks: int) -> int:
	if _tree == null or action_kind not in VALID_ACTIONS or semantic_intent_id < 0 or simulation_tick < 0:
		return BeehaveNode.FAILURE
	if timeout_ticks <= 0 or timeout_ticks > CoreCombatRules.MAX_DURATION:
		return BeehaveNode.FAILURE
	if _leaf == null or _current_intent_id != semantic_intent_id or _current_action_kind != action_kind:
		_replace_leaf(action_kind, semantic_intent_id, timeout_ticks)
	if _leaf == null:
		return BeehaveNode.FAILURE
	_leaf.current_tick = simulation_tick
	if not _pending_restore.is_empty() and int(_pending_restore.get("intent_id", -2)) == semantic_intent_id:
		_leaf.restore_started_tick(int(_pending_restore.get("started_tick", -1)))
		_pending_restore.clear()
	tick_count += 1
	_last_status = _tree.tick()
	match _last_status:
		BeehaveNode.SUCCESS:
			success_count += 1
		BeehaveNode.FAILURE:
			failure_count += 1
			if _leaf.timed_out:
				timeout_count += 1
	return _last_status


func interrupt() -> void:
	if _tree == null or _leaf == null:
		return
	if _tree.status == BeehaveNode.RUNNING:
		interrupt_count += 1
	_tree.interrupt()
	_current_intent_id = -1
	_current_action_kind = ""
	_last_status = -1


func reset() -> void:
	interrupt()
	_pending_restore.clear()


func persistence_state() -> Dictionary:
	if not _pending_restore.is_empty():
		return _pending_restore.duplicate(true)
	return {
		"intent_id": _current_intent_id,
		"action_kind": _current_action_kind,
		"started_tick": _leaf.started_tick() if _leaf != null else -1,
		"last_status": _last_status,
	}


func restore_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 4 or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if not _integer(state.get("intent_id")) or int(state["intent_id"]) < -1:
		return false
	if not state.get("action_kind") is String or (not str(state["action_kind"]).is_empty() and str(state["action_kind"]) not in VALID_ACTIONS):
		return false
	if not _integer(state.get("started_tick")) or int(state["started_tick"]) < -1:
		return false
	if not _integer(state.get("last_status")) or int(state["last_status"]) not in [-1, BeehaveNode.SUCCESS, BeehaveNode.FAILURE, BeehaveNode.RUNNING]:
		return false
	_pending_restore = state.duplicate(true)
	_current_intent_id = -1
	_current_action_kind = ""
	_last_status = int(state["last_status"])
	return true


func telemetry() -> Dictionary:
	return {
		"tree_tick_count": tick_count,
		"success_count": success_count,
		"failure_count": failure_count,
		"timeout_count": timeout_count,
		"interrupt_count": interrupt_count,
		"last_status": _last_status,
		"manual_process_thread": _tree != null and _tree.process_thread == BeehaveTree.ProcessThread.MANUAL,
		"idle_processing": _tree != null and _tree.is_processing(),
		"physics_processing": _tree != null and _tree.is_physics_processing(),
	}


func _replace_leaf(action_kind: String, intent_id: int, timeout_ticks: int) -> void:
	if _leaf != null:
		if _tree.status == BeehaveNode.RUNNING:
			interrupt_count += 1
			_tree.interrupt()
		_tree.remove_child(_leaf)
		_leaf.free()
		_leaf = null
	_leaf = _make_leaf(action_kind)
	if _leaf == null or not _leaf.configure(_handler, timeout_ticks):
		if _leaf != null:
			_leaf.free()
			_leaf = null
		return
	_tree.add_child(_leaf)
	_current_intent_id = intent_id
	_current_action_kind = action_kind
	_tree.status = -1
	_tree.last_tick = -1


func _make_leaf(action_kind: String) -> SeaCraftBtAction:
	match action_kind:
		ACTION_DESTINATION:
			return BtDestinationAction.new()
		ACTION_WAIT_OBSERVE:
			return BtWaitObserveAction.new()
		ACTION_STOP:
			return BtStopAction.new()
		ACTION_REPAIR:
			return BtRepairAction.new()
		ACTION_TARGET:
			return BtTargetAction.new()
		_:
			return null


static func _action_for_intent(intent_id: int) -> String:
	match intent_id:
		0, 2, 4:
			return ACTION_DESTINATION
		1, 5:
			return ACTION_TARGET
		3:
			return ACTION_REPAIR
		_:
			return ACTION_STOP


static func _integer(value: Variant) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
