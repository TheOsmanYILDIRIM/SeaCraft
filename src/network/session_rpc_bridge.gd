class_name SessionRpcBridge
extends Node

signal client_hello_received(peer_id: int, hello: Dictionary)
signal client_intent_received(peer_id: int, envelope: Dictionary)
signal handshake_accepted(payload: Dictionary)
signal handshake_rejected(reason: String)
signal command_accepted(sequence: int)
signal command_rejected(sequence: int, reason: String)
signal replication_snapshot_received(snapshot: Dictionary)
signal replication_event_received(event: Dictionary)
signal baseline_chunk_received(chunk: Dictionary)
signal baseline_ready_received(payload: Dictionary)
signal transaction_result_received(transaction_id: String, result: Dictionary)
signal market_snapshot_received(snapshot: Dictionary)


func send_client_hello(hello: Dictionary) -> void:
	rpc_id(1, "_rpc_client_hello", hello)


func send_client_intent(envelope: Dictionary) -> void:
	rpc_id(1, "_rpc_client_intent", envelope)


func send_handshake_accept(peer_id: int, payload: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_handshake_accept", payload)


func send_handshake_reject(peer_id: int, reason: String) -> void:
	rpc_id(peer_id, "_rpc_handshake_reject", reason)


func send_command_accept(peer_id: int, sequence: int) -> void:
	rpc_id(peer_id, "_rpc_command_accept", sequence)


func send_command_reject(peer_id: int, sequence: int, reason: String) -> void:
	rpc_id(peer_id, "_rpc_command_reject", sequence, reason)


func send_baseline_chunk(peer_id: int, chunk: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_baseline_chunk", chunk)


func send_baseline_ready(peer_id: int, payload: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_baseline_ready", payload)


func send_transaction_result(peer_id: int, transaction_id: String, result: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_transaction_result", transaction_id, result)


func send_snapshot(peer_id: int, snapshot: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_replication_snapshot", snapshot)


func send_replication_event(peer_id: int, event: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_replication_event", event)


@rpc("any_peer", "call_remote", "reliable", 0)
func _rpc_client_hello(hello: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender > 0:
		client_hello_received.emit(sender, hello)


@rpc("any_peer", "call_remote", "reliable", 1)
func _rpc_client_intent(envelope: Dictionary) -> void:
	var sender := multiplayer.get_remote_sender_id()
	if sender > 0:
		client_intent_received.emit(sender, envelope)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_handshake_accept(payload: Dictionary) -> void:
	handshake_accepted.emit(payload)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_handshake_reject(reason: String) -> void:
	handshake_rejected.emit(reason)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_command_accept(sequence: int) -> void:
	command_accepted.emit(sequence)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_command_reject(sequence: int, reason: String) -> void:
	command_rejected.emit(sequence, reason)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_baseline_chunk(chunk: Dictionary) -> void:
	baseline_chunk_received.emit(chunk)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_baseline_ready(payload: Dictionary) -> void:
	baseline_ready_received.emit(payload)


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_transaction_result(transaction_id: String, result: Dictionary) -> void:
	transaction_result_received.emit(transaction_id, result)


@rpc("authority", "call_remote", "unreliable_ordered", 2)
func _rpc_replication_snapshot(snapshot: Dictionary) -> void:
	replication_snapshot_received.emit(snapshot)


@rpc("authority", "call_remote", "reliable", 1)
func _rpc_replication_event(event: Dictionary) -> void:
	replication_event_received.emit(event)


func send_market_snapshot(peer_id: int, snapshot: Dictionary) -> void:
	rpc_id(peer_id, "_rpc_market_snapshot", snapshot)


@rpc("authority", "call_remote", "reliable", 0)
func _rpc_market_snapshot(snapshot: Dictionary) -> void:
	market_snapshot_received.emit(snapshot)
