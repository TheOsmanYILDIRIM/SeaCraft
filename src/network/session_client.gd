class_name SessionClient
extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const RPC_BRIDGE := preload("res://src/network/session_rpc_bridge.gd")
const REPLICATION := preload("res://src/network/network_replication_peer.gd")

const STATE_DISCONNECTED := "disconnected"
const STATE_CONNECTING := "connecting"
const STATE_CONNECTED := "connected"
const STATE_HANDSHAKING := "handshaking"
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


func _ready() -> void:
	_bridge = RPC_BRIDGE.new()
	_bridge.name = "RpcBridge"
	add_child(_bridge)
	_bridge.handshake_accepted.connect(_on_handshake_accepted)
	_bridge.handshake_rejected.connect(_on_handshake_rejected)
	_bridge.command_accepted.connect(_on_command_accepted)
	_bridge.command_rejected.connect(_on_command_rejected)
	_replication = REPLICATION.new()
	_replication.name = "Replication"
	add_child(_replication, true)
	_replication.configure_bridge(_bridge)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)


func set_auto_handshake(enabled: bool) -> void:
	_auto_handshake = enabled


func join(address: String, port: int, hello_overrides: Dictionary = {}) -> Error:
	if _state != STATE_DISCONNECTED or not PROTOCOL.valid_ipv4(address) or not PROTOCOL.valid_port(port):
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(address, port, PROTOCOL.CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	_hello_overrides = hello_overrides.duplicate(true)
	_rejection_reason = ""
	_assigned_player_id = ""
	_next_sequence = 0
	_accepted_sequences.clear()
	_command_rejections.clear()
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
	if _state != STATE_HANDSHAKING or payload.size() != 2 or not payload.has("protocol_version") or not payload.has("player_id"):
		_rejection_reason = PROTOCOL.REJECT_MALFORMED_HANDSHAKE
		_set_state(STATE_REJECTED)
		session_rejected.emit(_rejection_reason)
		return
	if typeof(payload["protocol_version"]) != TYPE_INT or int(payload["protocol_version"]) != PROTOCOL.PROTOCOL_VERSION or not payload["player_id"] is String or str(payload["player_id"]).is_empty():
		_rejection_reason = PROTOCOL.REJECT_MALFORMED_HANDSHAKE
		_set_state(STATE_REJECTED)
		session_rejected.emit(_rejection_reason)
		return
	_assigned_player_id = str(payload["player_id"])
	_set_state(STATE_READY)
	session_ready.emit(_assigned_player_id)


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
