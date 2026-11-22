class_name SessionHost
extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const RPC_BRIDGE := preload("res://src/network/session_rpc_bridge.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const REPLICATION := preload("res://src/network/network_replication_peer.gd")

const STATE_CONNECTED := "connected"
const STATE_HANDSHAKING := "handshaking"
const STATE_READY := "ready"
const STATE_REJECTED := "rejected"

signal peer_state_changed(peer_id: int, state: String)
signal peer_ready(peer_id: int, player_id: String)
signal intent_applied(peer_id: int, player_id: String, intent_type: String, sequence: int)
signal intent_rejected(peer_id: int, sequence: int, reason: String)

var _peer: ENetMultiplayerPeer
var _bridge: SessionRpcBridge
var _replication: NetworkReplicationPeer
var _combat_authority: CombatAuthority
var _loot_authority: LootAuthority
var _player_motors: Dictionary = {}
var _player_ids: Array[String] = []
var _peer_states: Dictionary = {}
var _peer_to_player: Dictionary = {}
var _last_sequence: Dictionary = {}
var _running: bool = false
var _listen_port: int = 0
var _telemetry := {
	"connections": 0,
	"ready": 0,
	"rejected_handshakes": 0,
	"accepted_intents": 0,
	"rejected_intents": 0,
}


func _ready() -> void:
	_bridge = RPC_BRIDGE.new()
	_bridge.name = "RpcBridge"
	add_child(_bridge)
	_bridge.client_hello_received.connect(_on_client_hello)
	_bridge.client_intent_received.connect(_on_client_intent)
	_replication = REPLICATION.new()
	_replication.name = "Replication"
	add_child(_replication, true)
	_replication.configure_bridge(_bridge)
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func configure_player_motors(players: Dictionary) -> bool:
	if _running or not _peer_to_player.is_empty():
		return false
	var ids: Array[String] = []
	var validated: Dictionary = {}
	for raw_id in players:
		var player_id := str(raw_id)
		var motor: Variant = players[raw_id]
		if player_id.is_empty() or not motor is ShipMotor:
			return false
		ids.append(player_id)
		validated[player_id] = motor
	ids.sort()
	if ids.is_empty() or ids.size() > PROTOCOL.MAX_PEERS:
		return false
	_player_ids = ids
	_player_motors = validated
	return true


func start(port: int) -> Error:
	if _running or not PROTOCOL.valid_port(port) or _player_ids.is_empty():
		return ERR_INVALID_PARAMETER
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, PROTOCOL.MAX_PEERS + 1, PROTOCOL.CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	multiplayer.multiplayer_peer = _peer
	_replication.set_host_enabled(true)
	_running = true
	_listen_port = port
	return OK


func stop() -> void:
	if _loot_authority != null:
		_loot_authority.drop_created.disconnect(_on_gameplay_drop_created)
		_loot_authority.drop_claimed.disconnect(_on_gameplay_drop_claimed)
	_combat_authority = null
	_loot_authority = null
	if _peer != null:
		_peer.close()
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer = null
	_peer = null
	if _replication != null:
		_replication.set_host_enabled(false)
		_replication.reset_session()
	_running = false
	_listen_port = 0
	_peer_states.clear()
	_peer_to_player.clear()
	_last_sequence.clear()


func is_running() -> bool:
	return _running


func mapped_player_id(peer_id: int) -> String:
	return str(_peer_to_player.get(peer_id, ""))


func peer_state(peer_id: int) -> String:
	return str(_peer_states.get(peer_id, ""))


func snapshot() -> Dictionary:
	return {
		"running": _running,
		"port": _listen_port,
		"peer_states": _peer_states.duplicate(true),
		"peer_to_player": _peer_to_player.duplicate(true),
		"last_sequence": _last_sequence.duplicate(true),
	}


func telemetry() -> Dictionary:
	return _telemetry.duplicate(true)


func network_entity_registry() -> NetworkEntityRegistry:
	return _replication.registry() if _replication != null else null


func spawn_network_entity(entity_id: String, entity_kind: String, sector_id: String, initial_state: Dictionary,
		definition_id: String = "", source: Object = null, snapshot_method: StringName = &"", source_args: Array = []) -> bool:
	return _running and _replication != null and _replication.spawn_authoritative(
		entity_id, entity_kind, sector_id, initial_state, definition_id, source, snapshot_method, source_args
	)


func despawn_network_entity(entity_id: String) -> bool:
	return _running and _replication != null and _replication.despawn_authoritative(entity_id)


func update_network_entity_state(entity_id: String, changes: Dictionary) -> bool:
	return _running and _replication != null and _replication.update_authoritative_state(entity_id, changes)


func bind_network_snapshot_source(entity_id: String, source: Object, method: StringName, source_args: Array = []) -> bool:
	return _running and _replication != null and _replication.bind_snapshot_source(entity_id, source, method, source_args)


func bind_combat_replication(authority: Object) -> bool:
	return _running and _replication != null and _replication.bind_combat_authority(authority)


func bind_loot_replication(authority: Object) -> bool:
	return _running and _replication != null and _replication.bind_loot_authority(authority)


func emit_network_event(event_type: String, source_id: String, target_id: String, payload: Dictionary) -> bool:
	return _running and _replication != null and _replication.emit_semantic_event(event_type, source_id, target_id, payload)


func network_replication_telemetry() -> Dictionary:
	return _replication.telemetry() if _replication != null else {}


func _on_peer_connected(peer_id: int) -> void:
	_peer_states[peer_id] = STATE_CONNECTED
	_telemetry["connections"] = int(_telemetry["connections"]) + 1
	peer_state_changed.emit(peer_id, STATE_CONNECTED)


func _on_peer_disconnected(peer_id: int) -> void:
	_peer_states.erase(peer_id)
	_peer_to_player.erase(peer_id)
	_last_sequence.erase(peer_id)
	if _replication != null:
		_replication.remove_peer(peer_id)


func _on_client_hello(peer_id: int, hello: Dictionary) -> void:
	if not _peer_states.has(peer_id):
		_peer_states[peer_id] = STATE_CONNECTED
	_peer_states[peer_id] = STATE_HANDSHAKING
	peer_state_changed.emit(peer_id, STATE_HANDSHAKING)
	var reason := PROTOCOL.validate_handshake(hello)
	if reason.is_empty():
		var mapped_ids: Array[String] = []
		for value in _peer_to_player.values():
			mapped_ids.append(str(value))
		if _peer_to_player.size() >= PROTOCOL.MAX_PEERS:
			reason = PROTOCOL.REJECT_SERVER_FULL
		else:
			var player_id := PROTOCOL.next_available_player_id(_player_ids, mapped_ids)
			if player_id.is_empty():
				reason = PROTOCOL.REJECT_SERVER_FULL
			else:
				_peer_to_player[peer_id] = player_id
				_last_sequence[peer_id] = -1
				_peer_states[peer_id] = STATE_READY
				_replication.set_peer_player(peer_id, player_id)
				_telemetry["ready"] = int(_telemetry["ready"]) + 1
				_bridge.send_handshake_accept(peer_id, {
					"protocol_version": PROTOCOL.PROTOCOL_VERSION,
					"player_id": player_id,
				})
				peer_state_changed.emit(peer_id, STATE_READY)
				peer_ready.emit(peer_id, player_id)
				return
	_peer_states[peer_id] = STATE_REJECTED
	_telemetry["rejected_handshakes"] = int(_telemetry["rejected_handshakes"]) + 1
	_bridge.send_handshake_reject(peer_id, reason)
	peer_state_changed.emit(peer_id, STATE_REJECTED)


func _on_client_intent(peer_id: int, envelope: Dictionary) -> void:
	var sequence := -1
	if envelope.has("client_sequence") and typeof(envelope["client_sequence"]) == TYPE_INT:
		sequence = int(envelope["client_sequence"])
	if str(_peer_states.get(peer_id, "")) != STATE_READY:
		_reject_intent(peer_id, sequence, PROTOCOL.REJECT_PRE_HANDSHAKE)
		return
	var reason := PROTOCOL.validate_envelope(envelope)
	if not reason.is_empty():
		_reject_intent(peer_id, sequence, reason)
		return
	sequence = int(envelope["client_sequence"])
	reason = PROTOCOL.validate_sequence(sequence, int(_last_sequence.get(peer_id, -1)))
	if not reason.is_empty():
		_reject_intent(peer_id, sequence, reason)
		return
	var player_id := str(_peer_to_player.get(peer_id, ""))
	if player_id.is_empty() or not _player_motors.has(player_id):
		_reject_intent(peer_id, sequence, PROTOCOL.REJECT_AUTHORITY_COMMAND)
		return
	var intent_type := str(envelope["intent_type"])
	if intent_type in PROTOCOL.AUTHORITY_INTENTS:
		# Consume validated envelopes before executing, even when authority rejects them.
		_last_sequence[peer_id] = sequence
		var payload: Dictionary = envelope["payload"]
		reason = _execute_gameplay_intent(peer_id, player_id, intent_type, payload)
		if reason.is_empty():
			_accept_intent(peer_id, player_id, intent_type, sequence)
		else:
			_reject_intent(peer_id, sequence, reason)
		return
	var command := PROTOCOL.to_gameplay_command(envelope)
	if command.is_empty():
		_reject_intent(peer_id, sequence, PROTOCOL.REJECT_MALFORMED_PAYLOAD)
		return
	if intent_type == COMMANDS.MOVE_TO_WORLD_POSITION or intent_type == COMMANDS.CANCEL:
		var motor := _player_motors[player_id] as ShipMotor
		if motor == null or not motor.apply_authoritative_command(command):
			_reject_intent(peer_id, sequence, PROTOCOL.REJECT_AUTHORITY_COMMAND)
			return
	_last_sequence[peer_id] = sequence
	_accept_intent(peer_id, player_id, intent_type, sequence)


func _accept_intent(peer_id: int, player_id: String, intent_type: String, sequence: int) -> void:
	_telemetry["accepted_intents"] = int(_telemetry["accepted_intents"]) + 1
	_bridge.send_command_accept(peer_id, sequence)
	intent_applied.emit(peer_id, player_id, intent_type, sequence)


func _reject_intent(peer_id: int, sequence: int, reason: String) -> void:
	_telemetry["rejected_intents"] = int(_telemetry["rejected_intents"]) + 1
	_bridge.send_command_reject(peer_id, sequence, reason)
	intent_rejected.emit(peer_id, sequence, reason)


# The host supplies the same authority instances used by its simulation. A
# session with movement only remains valid and cannot run these intents.
func bind_gameplay_authority(combat: CombatAuthority, loot: LootAuthority) -> bool:
	if not _running or _combat_authority != null or combat == null or loot == null:
		return false
	if not bind_combat_replication(combat) or not bind_loot_replication(loot):
		return false
	_combat_authority = combat
	_loot_authority = loot
	loot.drop_created.connect(_on_gameplay_drop_created)
	loot.drop_claimed.connect(_on_gameplay_drop_claimed)
	return true


func _execute_gameplay_intent(peer_id: int, player_id: String, intent_type: String, payload: Dictionary) -> String:
	if _combat_authority == null or _loot_authority == null:
		return PROTOCOL.REJECT_AUTHORITY_COMMAND
	if intent_type == PROTOCOL.PICKUP_LOOT:
		var drop_id := str(payload["drop_id"])
		var visible := _replication.is_visible_to_peer(peer_id, drop_id, "loot")
		# Despawned claims may only reach the real idempotence guard for their
		# original inventory owner. Unknown and hidden drops remain opaque.
		if not visible and not _loot_authority.claimed_by_inventory_owner(player_id, drop_id):
			return PROTOCOL.REJECT_AOI
		var pickup := _loot_authority.pickup(player_id, LootAuthority.pickup_intent(drop_id))
		return "" if pickup["accepted"] else str(pickup["reason"])
	var target_id := str(payload["target_id"])
	if not _replication.is_visible_to_peer(peer_id, target_id):
		return PROTOCOL.REJECT_AOI
	if intent_type == PROTOCOL.SELECT_COMBAT_TARGET:
		return "" if _combat_authority.select(player_id, target_id) else PROTOCOL.REJECT_AUTHORITY_COMMAND
	if intent_type == PROTOCOL.FIRE_WEAPON:
		var motor := _player_motors.get(player_id) as ShipMotor
		if motor == null or not is_instance_valid(motor):
			return PROTOCOL.REJECT_AUTHORITY_COMMAND
		var shot := _combat_authority.fire(player_id, motor.current_heading(), CombatAuthority.fire_intent(target_id))
		return "" if shot["accepted"] else str(shot["reason"])
	return PROTOCOL.REJECT_UNSUPPORTED_INTENT


func _on_gameplay_drop_created(drop: Dictionary) -> void:
	spawn_network_entity(str(drop["drop_id"]), "loot", str(drop["sector_id"]),
		{"x": drop["x"], "y": drop["y"]}, str(drop["item_id"]))


func _on_gameplay_drop_claimed(drop_id: String, _item_id: String, _quantity: int) -> void:
	despawn_network_entity(drop_id)
