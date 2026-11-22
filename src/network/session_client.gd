class_name SessionClient
extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const RPC_BRIDGE := preload("res://src/network/session_rpc_bridge.gd")
const REPLICATION := preload("res://src/network/network_replication_peer.gd")

const STATE_DISCONNECTED := "disconnected"
const STATE_CONNECTING := "connecting"
const STATE_CONNECTED := "connected"
const STATE_HANDSHAKING := "handshaking"
const STATE_BASELINING := "baselining"
const STATE_READY := "ready"
const STATE_REJECTED := "rejected"

signal connection_state_changed(state: String)
signal session_ready(player_id: String)
signal session_rejected(reason: String)
signal command_accepted(sequence: int)
signal command_rejected(sequence: int, reason: String)

var _peer: ENetMultiplayerPeer
var _bridge: SessionRpcBridge
var _replication: NetworkReplicationPeer
var _state: String = STATE_DISCONNECTED
var _rejection_reason: String = ""
var _assigned_player_id: String = ""
var _next_sequence: int = 0
var _hello_overrides: Dictionary = {}
var _auto_handshake: bool = true
var _accepted_sequences: Array[int] = []
var _command_rejections: Array[Dictionary] = []
var _resume_session_id := ""
var _resume_token := ""
var _pending_baseline_id := ""
var _transaction_results: Dictionary = {}


func _ready() -> void:
	_bridge = RPC_BRIDGE.new()
	_bridge.name = "RpcBridge"
	add_child(_bridge)
	_bridge.handshake_accepted.connect(_on_handshake_accepted)
	_bridge.handshake_rejected.connect(_on_handshake_rejected)
	_bridge.command_accepted.connect(_on_command_accepted)
	_bridge.command_rejected.connect(_on_command_rejected)
	_bridge.baseline_chunk_received.connect(_on_baseline_chunk)
	_bridge.baseline_ready_received.connect(_on_baseline_ready)
	_bridge.transaction_result_received.connect(_on_transaction_result)
	_replication = REPLICATION.new()
	_replication.name = "Replication"
	add_child(_replication, true)
	_replication.configure_bridge(_bridge)
	_replication.baseline_complete.connect(_on_replication_baseline_complete)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func set_auto_handshake(enabled: bool) -> void:
	_auto_handshake = enabled


func join(address: String, port: int, hello_overrides: Dictionary = {}) -> Error:
	clear_resume_credentials()
	_hello_overrides = hello_overrides.duplicate(true)
	_hello_overrides["session_id"] = ""
	_hello_overrides["resume_token"] = ""
	return _connect(address, port)


func can_resume() -> bool:
	return _state == STATE_DISCONNECTED and not _resume_session_id.is_empty() and PROTOCOL.valid_resume_token(_resume_token)


func resume(address: String, port: int) -> Error:
	if not can_resume():
		return ERR_UNCONFIGURED
	_hello_overrides = {"session_id": _resume_session_id, "resume_token": _resume_token}
	return _connect(address, port)


func clear_resume_credentials() -> void:
	_resume_session_id = ""
	_resume_token = ""
	_pending_baseline_id = ""


func resume_session_id() -> String:
	return _resume_session_id


func transaction_result(transaction_id: String) -> Dictionary:
	return (_transaction_results.get(transaction_id, {}) as Dictionary).duplicate(true)


func _connect(address: String, port: int) -> Error:
	if _state != STATE_DISCONNECTED or not PROTOCOL.valid_ipv4(address) or not PROTOCOL.valid_port(port):
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, port, PROTOCOL.CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	_rejection_reason = ""
	_next_sequence = 0
	_accepted_sequences.clear()
	_command_rejections.clear()
	_transaction_results.clear()
	multiplayer.multiplayer_peer = _peer
	_set_state(STATE_CONNECTING)
	return OK


func begin_handshake() -> bool:
	if _state != STATE_CONNECTED:
		return false
	_set_state(STATE_HANDSHAKING)
	_bridge.send_client_hello(PROTOCOL.client_hello(_hello_overrides))
	return true


func send_intent(intent_type: String, payload: Dictionary) -> bool:
	if _state != STATE_READY or _next_sequence > PROTOCOL.MAX_SEQUENCE:
		return false
	var envelope := PROTOCOL.make_envelope(_next_sequence, intent_type, payload)
	if PROTOCOL.validate_envelope(envelope) != "":
		return false
	_bridge.send_client_intent(envelope)
	_next_sequence += 1
	return true


func send_command(command: Dictionary) -> bool:
	if _state != STATE_READY or _next_sequence > PROTOCOL.MAX_SEQUENCE:
		return false
	var envelope := PROTOCOL.command_to_envelope(command, _next_sequence)
	if envelope.is_empty():
		return false
	_bridge.send_client_intent(envelope)
	_next_sequence += 1
	return true


func close_session() -> void:
	if _peer != null:
		_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	if _replication != null:
		_replication.reset_session()
	_hello_overrides.clear()
	_assigned_player_id = ""
	_set_state(STATE_DISCONNECTED)


func state() -> String:
	return _state


func assigned_player_id() -> String:
	return _assigned_player_id


func rejection_reason() -> String:
	return _rejection_reason


func next_sequence() -> int:
	return _next_sequence


func accepted_sequences() -> Array[int]:
	return _accepted_sequences.duplicate()


func command_rejections() -> Array[Dictionary]:
	return _command_rejections.duplicate(true)


func network_entity_registry() -> NetworkEntityRegistry:
	return _replication.registry() if _replication != null else null


func network_replication_telemetry() -> Dictionary:
	return _replication.telemetry() if _replication != null else {}


func visible_network_entity_ids() -> Array[String]:
	if _replication == null:
		return []
	return _replication.visible_entity_ids()


func network_events() -> Array[Dictionary]:
	if _replication == null:
		return []
	return _replication.event_history()


func network_event_types() -> Array[String]:
	if _replication == null:
		return []
	return _replication.event_types()


func last_snapshot_sequence() -> int:
	return _replication.last_snapshot_sequence() if _replication != null else -1


func _on_connected_to_server() -> void:
	_set_state(STATE_CONNECTED)
	if _auto_handshake:
		begin_handshake()


func _on_connection_failed() -> void:
	_rejection_reason = "connection failed"
	_set_state(STATE_REJECTED)
	session_rejected.emit(_rejection_reason)


func _on_server_disconnected() -> void:
	_peer = null
	if _state != STATE_REJECTED:
		_set_state(STATE_DISCONNECTED)


func _on_handshake_accepted(payload: Dictionary) -> void:
	if _state != STATE_HANDSHAKING or payload.size() != 5:
		_reject_local(PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
		return
	for key in ["protocol_version", "player_id", "session_id", "resume_token", "resume_sequence"]:
		if not payload.has(key):
			_reject_local(PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
			return
	if typeof(payload["protocol_version"]) != TYPE_INT or int(payload["protocol_version"]) != PROTOCOL.PROTOCOL_VERSION:
		_reject_local(PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
		return
	if not payload["player_id"] is String or not payload["session_id"] is String or not payload["resume_token"] is String or typeof(payload["resume_sequence"]) != TYPE_INT:
		_reject_local(PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
		return
	var player_id := str(payload["player_id"])
	var session_id := str(payload["session_id"])
	var token := str(payload["resume_token"])
	var resume_sequence := int(payload["resume_sequence"])
	if player_id.is_empty() or not SectorIds.valid(player_id) or not session_id.begins_with("session.") or not SectorIds.valid(session_id) or not PROTOCOL.valid_resume_token(token) or resume_sequence < 0:
		_reject_local(PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
		return
	_assigned_player_id = player_id
	_resume_session_id = session_id
	_resume_token = token
	_next_sequence = resume_sequence
	_set_state(STATE_BASELINING)


func _on_baseline_chunk(chunk: Dictionary) -> void:
	if _state != STATE_BASELINING:
		return
	if str(chunk.get("session_id", "")) != _resume_session_id or str(chunk.get("player_id", "")) != _assigned_player_id:
		_reject_local(PROTOCOL.REJECT_MALFORMED_BASELINE)
		return
	if not _replication.consume_baseline_chunk(chunk):
		_reject_local(PROTOCOL.REJECT_MALFORMED_BASELINE)


func _on_replication_baseline_complete(baseline_id: String, resume_sequence: int) -> void:
	if _state != STATE_BASELINING or resume_sequence != _next_sequence:
		_reject_local(PROTOCOL.REJECT_MALFORMED_BASELINE)
		return
	_pending_baseline_id = baseline_id
	var envelope := PROTOCOL.make_envelope(_next_sequence, PROTOCOL.BASELINE_ACK, {"baseline_id": baseline_id})
	if PROTOCOL.validate_envelope(envelope) != "":
		_reject_local(PROTOCOL.REJECT_MALFORMED_BASELINE)
		return
	_bridge.send_client_intent(envelope)


func _on_baseline_ready(payload: Dictionary) -> void:
	if _state != STATE_BASELINING or payload.size() != 2 or str(payload.get("baseline_id", "")) != _pending_baseline_id:
		_reject_local(PROTOCOL.REJECT_MALFORMED_BASELINE)
		return
	if typeof(payload.get("next_sequence")) != TYPE_INT or int(payload["next_sequence"]) != _next_sequence:
		_reject_local(PROTOCOL.REJECT_SEQUENCE)
		return
	_pending_baseline_id = ""
	_set_state(STATE_READY)
	session_ready.emit(_assigned_player_id)


func _on_transaction_result(transaction_id: String, result: Dictionary) -> void:
	if PROTOCOL.valid_transaction_id(transaction_id) and PROTOCOL.primitive_safe(result):
		_transaction_results[transaction_id] = result.duplicate(true)


func _reject_local(reason: String) -> void:
	_rejection_reason = reason
	_set_state(STATE_REJECTED)
	session_rejected.emit(reason)


func _on_handshake_rejected(reason: String) -> void:
	_rejection_reason = reason
	_set_state(STATE_REJECTED)
	session_rejected.emit(reason)


func _on_command_accepted(sequence: int) -> void:
	_accepted_sequences.append(sequence)
	command_accepted.emit(sequence)


func _on_command_rejected(sequence: int, reason: String) -> void:
	_command_rejections.append({"sequence": sequence, "reason": reason})
	command_rejected.emit(sequence, reason)


func _set_state(next_state: String) -> void:
	if _state == next_state:
		return
	_state = next_state
	connection_state_changed.emit(_state)
