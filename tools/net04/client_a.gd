extends Node

const PLAYER := FoundationSector.PLAYER
const NPC := "entity.net04_current"
const TXN := "txn.net04.lost_ack"
const MARKET := "market.net04.economy"
const MARKET_TXN := "txn.net04.market_buy"

var _client: SessionClient
var _discovery: LanDiscoveryClient
var _work := ""
var _game_port := 0
var _discovery_port := 0
var _failed := false


func start_case(game_port: int, discovery_port: int, work: String) -> void:
	_game_port = game_port
	_discovery_port = discovery_port
	_work = work
	_discovery = LanDiscoveryClient.new()
	if _discovery.start(discovery_port, "127.0.0.1") != OK:
		_abort("discovery bind")
		return
	_run.call_deferred()


func _process(_delta: float) -> void:
	if _discovery != null:
		_discovery.poll()


func _run() -> void:
	if not await _wait(func() -> bool: return not _discovery.compatible_sessions().is_empty(), "discovery"):
		return
	var row: Dictionary = _discovery.compatible_sessions()[0]
	if int(row["game_port"]) != _game_port or str(row["address"]) != "127.0.0.1":
		_abort("discovery endpoint")
		return
	var discovered_session := str(row["session_id"])
	print("NET04_A_DISCOVERED session=%s game_port=%d" % [discovered_session, _game_port])
	_client = SessionClient.new()
	_client.name = "Session"
	get_parent().add_child(_client, true)
	if _client.join("127.0.0.1", _game_port) != OK:
		_abort("fresh join")
		return
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "fresh baseline"):
		return
	if _client.assigned_player_id() != PLAYER or _client.resume_session_id() != discovered_session:
		_abort("fresh identity")
		return
	var drop_id := _drop_id()
	if drop_id.is_empty() or _proxy(NPC) == null:
		_abort("fresh baseline truth")
		return
	print("NET04_A_BASELINE_READY player=%s drop=%s" % [PLAYER, drop_id])
	var market_sequence := _client.next_sequence()
	if not _client.send_intent(InventoryState.OP_MARKET_BUY, {"market_id": MARKET, "quantity": 1, "transaction_id": MARKET_TXN}):
		_abort("market send")
		return
	if not await _wait(func() -> bool: return _client.accepted_sequences().has(market_sequence) and not _client.transaction_result(MARKET_TXN).is_empty(), "market purchase"):
		return
	var market_result := _client.transaction_result(MARKET_TXN)
	if not bool(market_result.get("accepted", false)) or int(market_result.get("stock", -1)) != 7:
		_abort("market purchase result")
		return
	if not _client.send_intent(SessionProtocol.PICKUP_LOOT, {"drop_id": drop_id, "transaction_id": TXN}):
		_abort("transaction send")
		return
	# The authoritative mutation is observed through the replicated despawn, but
	# the command ACK is intentionally not used before transport loss.
	if not await _wait(func() -> bool: return FileAccess.file_exists(_work + "/commit") and _proxy(drop_id) == null, "authoritative commit"):
		return
	var link := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if link == null:
		_abort("missing ENet")
		return
	link.disconnect_peer(1, false)
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_DISCONNECTED, "disconnect reservation"):
		return
	_touch(_work + "/a_disconnected")
	print("NET04_A_ACK_LOSS_DISCONNECT")
	if not await _wait(func() -> bool: return FileAccess.file_exists(_work + "/b_done"), "late join client"):
		return
	if not _client.can_resume() or _client.resume("127.0.0.1", _game_port) != OK:
		_abort("resume start")
		return
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "resume baseline"):
		return
	if _client.assigned_player_id() != PLAYER or _drop_id() != "":
		_abort("resume identity or stale drop")
		return
	var npc := _proxy(NPC)
	if npc == null:
		_abort("resume npc")
		return
	var npc_state := npc.authoritative_state()
	if not is_equal_approx(float(npc_state.get("x", 0.0)), 321.0) or not is_equal_approx(float(npc_state.get("hull_ratio", 0.0)), 0.5):
		_abort("resume current world")
		return
	if _client.network_event_types().has("drop_claimed"):
		_abort("historical event replay")
		return
	var retry_sequence := _client.next_sequence()
	if not _client.send_intent(SessionProtocol.PICKUP_LOOT, {"drop_id": drop_id, "transaction_id": TXN}):
		_abort("transaction retry")
		return
	if not await _wait(func() -> bool: return _client.accepted_sequences().has(retry_sequence) and not _client.transaction_result(TXN).is_empty(), "cached transaction result"):
		return
	var result := _client.transaction_result(TXN)
	if int(result.get("quantity", 0)) <= 0 or _client.network_event_types().has("drop_claimed"):
		_abort("duplicate reward or missing cached result")
		return
	var market_retry_sequence := _client.next_sequence()
	if not _client.send_intent(InventoryState.OP_MARKET_BUY, {"market_id": MARKET, "quantity": 1, "transaction_id": MARKET_TXN}):
		_abort("market reconnect retry")
		return
	if not await _wait(func() -> bool: return _client.accepted_sequences().has(market_retry_sequence) and not _client.transaction_result(MARKET_TXN).is_empty(), "market cached result"):
		return
	if _client.transaction_result(MARKET_TXN) != market_result:
		_abort("market replay result changed")
		return
	print("PRG05_LAN_MARKET_RECONNECT_OK")
	print("NET04_TRANSACTION_IDEMPOTENCY_OK transaction=%s quantity=%d" % [TXN, int(result["quantity"])])
	print("NET04_RECONNECT_PROCESS_OK player=%s next_sequence=%d" % [PLAYER, _client.next_sequence()])
	_touch(_work + "/a_done")
	if not await _wait(func() -> bool: return _discovery.sessions().is_empty(), "discovery ttl expiry", 9000):
		return
	print("NET04_DISCOVERY_PROCESS_OK ttl_expired=1 separate_ports=1")
	print("NET04_PROCESS_INTEGRATION_OK")
	_discovery.stop()
	get_tree().quit(0)


func _drop_id() -> String:
	if _client == null or _client.network_entity_registry() == null:
		return ""
	for entity_id in _client.network_entity_registry().entity_ids():
		if str(entity_id).begins_with("drop."):
			return str(entity_id)
	return ""


func _proxy(entity_id: String) -> NetworkEntityProxy:
	return _client.network_entity_registry().proxy(entity_id) if _client != null and _client.network_entity_registry() != null else null


func _wait(check: Callable, stage: String, timeout_ms: int = 8000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
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
	push_error("NET04_PROCESS_FAILURE: client_a %s" % reason)
	get_tree().quit(1)
