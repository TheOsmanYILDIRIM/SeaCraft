extends Node

const BETA := "player.beta"
const NPC := "entity.net04_current"

var _client: SessionClient
var _work := ""
var _failed := false


func start_case(game_port: int, _discovery_port: int, work: String) -> void:
	_work = work
	_client = SessionClient.new()
	_client.name = "Session"
	get_parent().add_child(_client, true)
	if _client.join("127.0.0.1", game_port) != OK:
		_abort("join")
		return
	_run.call_deferred()


func _run() -> void:
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "late baseline"):
		return
	if _client.assigned_player_id() != BETA:
		_abort("reserved player reused")
		return
	for entity_id in _client.network_entity_registry().entity_ids():
		if str(entity_id).begins_with("drop."):
			_abort("claimed drop replayed")
			return
	var npc := _client.network_entity_registry().proxy(NPC)
	if npc == null:
		_abort("current npc missing")
		return
	var state := npc.authoritative_state()
	if not is_equal_approx(float(state.get("x", 0.0)), 321.0) or not is_equal_approx(float(state.get("hull_ratio", 0.0)), 0.5):
		_abort("late join stale world")
		return
	if _client.network_event_types().has("drop_claimed"):
		_abort("historical event replay")
		return
	print("NET04_LATE_JOIN_PROCESS_OK player=%s current_x=321.0 claimed_drop_absent=1" % BETA)
	_touch(_work + "/b_done")
	_client.close_session()
	get_tree().quit(0)


func _wait(check: Callable, stage: String) -> bool:
	var deadline := Time.get_ticks_msec() + 8000
	while not _failed and Time.get_ticks_msec() < deadline:
		if check.call() == true:
			return true
		await get_tree().process_frame
	if not _failed:
		_abort("stage timeout: %s" % stage)
	return false


func _touch(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("ok\n")


func _abort(reason: String) -> void:
	_failed = true
	push_error("NET04_PROCESS_FAILURE: client_b %s" % reason)
	get_tree().quit(1)
