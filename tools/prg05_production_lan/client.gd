extends Node

const GUEST := "player.lan.guest"
const HOST_PLAYER := FoundationSector.PLAYER
const MARKET := "market.haven.salvage"
const TXN := "txn.prg05.production.market"

var _client: SessionClient
var _discovery: LanDiscoveryClient
var _game_port := 0
var _discovery_port := 0
var _work := ""
var _failed := false
var _first_result: Dictionary = {}


func start_case(game_port: int, discovery_port: int, work: String) -> void:
	_game_port = game_port
	_discovery_port = discovery_port
	_work = work
	_run.call_deferred()


func _run() -> void:
	_discovery = LanDiscoveryClient.new()
	if _discovery.start(_discovery_port, "127.0.0.1") != OK:
		_abort("discovery bind")
		return
	if not await _wait(func() -> bool:
		_discovery.poll()
		return not _discovery.compatible_sessions().is_empty(), "production discovery"):
		return
	var row: Dictionary = _discovery.compatible_sessions()[0]
	if int(row.get("game_port", 0)) != _game_port or str(row.get("address", "")) != "127.0.0.1":
		_abort("discovery endpoint")
		return
	var bootstrap := Node.new()
	bootstrap.name = "Bootstrap"
	add_child(bootstrap)
	var lan_session := Node.new()
	lan_session.name = "LanSession"
	bootstrap.add_child(lan_session)
	_client = SessionClient.new()
	_client.name = "Session"
	lan_session.add_child(_client, true)
	if _client.join("127.0.0.1", _game_port) != OK:
		_abort("join")
		return
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "initial baseline"):
		return
	if _client.assigned_player_id() != GUEST:
		_abort("guest identity")
		return
	var registry := _client.network_entity_registry()
	if registry == null or registry.proxy(GUEST) == null or registry.proxy(HOST_PLAYER) == null:
		_abort("production replicated players")
		return
	var sequence := _client.next_sequence()
	if not _client.send_intent(InventoryState.OP_MARKET_BUY,
			{"market_id": MARKET, "quantity": 1, "transaction_id": TXN}):
		_abort("first market intent")
		return
	if not await _wait(func() -> bool:
		return _client.accepted_sequences().has(sequence) and not _client.transaction_result(TXN).is_empty(),
		"first market result"):
		return
	_first_result = _client.transaction_result(TXN)
	if not bool(_first_result.get("accepted", false)) or int(_first_result.get("stock", -1)) != 7:
		_abort("first market rejected " + str(_first_result))
		return
	print("PRG05_PRODUCTION_LAN_CLIENT_TRADE_OK stock=7 player=%s" % GUEST)
	_touch("client_trade_done")
	_client.close_session()
	if not await _wait(func() -> bool: return FileAccess.file_exists(_work + "/host_restarted"), "host restart"):
		return
	if _client.join("127.0.0.1", _game_port) != OK:
		_abort("fresh rejoin")
		return
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "reloaded baseline"):
		return
	if _client.assigned_player_id() != GUEST:
		_abort("reloaded guest identity")
		return
	var retry_sequence := _client.next_sequence()
	if not _client.send_intent(InventoryState.OP_MARKET_BUY,
			{"market_id": MARKET, "quantity": 1, "transaction_id": TXN}):
		_abort("cached market retry")
		return
	if not await _wait(func() -> bool:
		return _client.accepted_sequences().has(retry_sequence) and not _client.transaction_result(TXN).is_empty(),
		"cached market result"):
		return
	var replay := _client.transaction_result(TXN)
	if not bool(replay.get("accepted", false)) or int(replay.get("stock", -1)) != int(_first_result.get("stock", -2)) \
			or int(replay.get("balance", -1)) != int(_first_result.get("balance", -2)):
		_abort("cached result changed " + str(replay))
		return
	print("PRG05_PRODUCTION_LAN_CLIENT_REPLAY_OK stock=%d balance=%d" % [
		int(replay.get("stock", -1)), int(replay.get("balance", -1))])
	_touch("client_retry_done")
	_client.close_session()
	_discovery.stop()
	get_tree().quit(0)


func _wait(check: Callable, stage: String, timeout_ms: int = 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not _failed and Time.get_ticks_msec() < deadline:
		if check.call() == true:
			return true
		await get_tree().process_frame
	if not _failed:
		_abort("stage timeout: %s state=%s rejection=%s" % [
			stage, _client.state() if _client != null else "none",
			_client.rejection_reason() if _client != null else "none"])
	return false


func _touch(name: String) -> void:
	var file := FileAccess.open(_work + "/" + name, FileAccess.WRITE)
	if file != null:
		file.store_string("ok\n")


func _abort(reason: String) -> void:
	_failed = true
	push_error("PRG05_PRODUCTION_LAN_FAILURE: client " + reason)
	if _client != null:
		_client.close_session()
	if _discovery != null:
		_discovery.stop()
	get_tree().quit(1)
