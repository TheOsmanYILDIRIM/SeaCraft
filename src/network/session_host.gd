class_name SessionHost
extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const RPC_BRIDGE := preload("res://src/network/session_rpc_bridge.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const REPLICATION := preload("res://src/network/network_replication_peer.gd")
const LEDGER := preload("res://src/network/host_transaction_ledger.gd")

const STATE_CONNECTED := "connected"
const STATE_HANDSHAKING := "handshaking"
const STATE_BASELINING := "baselining"
const STATE_READY := "ready"
const RECONNECT_GRACE_MS := 30000
const MAX_TOKEN_HISTORY := 64
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
var _inventory_state: InventoryState
var _market_access_guard: Prg05MarketAccessGuard
var _player_motors: Dictionary = {}
var _player_ids: Array[String] = []
var _peer_states: Dictionary = {}
var _peer_to_player: Dictionary = {}
var _last_sequence: Dictionary = {}
var _session_id := ""
var _active_token_digests: Dictionary = {}
var _reservations: Dictionary = {}
var _consumed_tokens: Dictionary = {}
var _expired_tokens: Dictionary = {}
var _pending_baselines: Dictionary = {}
var _ledger: HostTransactionLedger = LEDGER.new()
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
	if not LanPermissionGate.new().can_open_lan_socket():
		return ERR_UNAUTHORIZED
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(port, PROTOCOL.MAX_PEERS + 1, PROTOCOL.CHANNEL_COUNT)
	if error != OK:
		_peer = null
		return error
	multiplayer.multiplayer_peer = _peer
	_replication.set_host_enabled(true)
	_session_id = _new_stable_random("session")
	if _session_id.is_empty():
		_peer.close()
		_peer = null
		multiplayer.multiplayer_peer = null
		return ERR_CANT_CREATE
	_running = true
	_listen_port = port
	return OK


func stop() -> void:
	if _loot_authority != null:
		_loot_authority.drop_created.disconnect(_on_gameplay_drop_created)
		_loot_authority.drop_claimed.disconnect(_on_gameplay_drop_claimed)
	_combat_authority = null
	_loot_authority = null
	_inventory_state = null
	_market_access_guard = null
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
	_active_token_digests.clear()
	_reservations.clear()
	_consumed_tokens.clear()
	_expired_tokens.clear()
	_pending_baselines.clear()
	_session_id = ""
	_ledger = LEDGER.new()


func is_running() -> bool:
	return _running


func session_id() -> String:
	return _session_id


func transaction_ledger_snapshot() -> Dictionary:
	return _ledger.snapshot_state()


func restore_transaction_ledger(value: Variant) -> bool:
	return not _running and _ledger.restore_state(value)


func reservation_count() -> int:
	_cleanup_reservations()
	return _reservations.size()


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
		"session_id": _session_id,
		"reservation_count": _reservations.size(),
		"transaction_watermark": _ledger.commit_sequence(),
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


func _process(_delta: float) -> void:
	if _running:
		_cleanup_reservations()


func _on_peer_disconnected(peer_id: int) -> void:
	var player_id := str(_peer_to_player.get(peer_id, ""))
	if not player_id.is_empty() and _active_token_digests.has(player_id):
		var digest := str(_active_token_digests[player_id])
		_reservations[digest] = {
			"session_id": _session_id,
			"player_id": player_id,
			"token_digest": digest,
			"expires_at": Time.get_ticks_msec() + RECONNECT_GRACE_MS,
			"last_sequence": int(_last_sequence.get(peer_id, -1)),
			"transaction_watermark": _ledger.commit_sequence(),
		}
		_active_token_digests.erase(player_id)
	_peer_states.erase(peer_id)
	_peer_to_player.erase(peer_id)
	_last_sequence.erase(peer_id)
	_pending_baselines.erase(peer_id)
	if _replication != null:
		_replication.remove_peer(peer_id)


func _on_client_hello(peer_id: int, hello: Dictionary) -> void:
	if not _peer_states.has(peer_id):
		_peer_states[peer_id] = STATE_CONNECTED
	_peer_states[peer_id] = STATE_HANDSHAKING
	peer_state_changed.emit(peer_id, STATE_HANDSHAKING)
	_cleanup_reservations()
	var reason := PROTOCOL.validate_handshake(hello)
	var player_id := ""
	var resume_last_sequence := -1
	var resume_session := str(hello.get("session_id", ""))
	var resume_token := str(hello.get("resume_token", ""))
	if reason.is_empty() and not resume_session.is_empty():
		if resume_session != _session_id:
			reason = PROTOCOL.REJECT_SESSION_MISMATCH
		elif not PROTOCOL.valid_resume_token(resume_token):
			reason = PROTOCOL.REJECT_TOKEN_MALFORMED
		else:
			var digest := resume_token.sha256_text()
			if _reservations.has(digest):
				var reservation: Dictionary = _reservations[digest]
				player_id = str(reservation["player_id"])
				resume_last_sequence = int(reservation["last_sequence"])
				_reservations.erase(digest)
				_remember_token(_consumed_tokens, digest)
			elif _expired_tokens.has(digest):
				reason = PROTOCOL.REJECT_TOKEN_EXPIRED
			elif _consumed_tokens.has(digest):
				reason = PROTOCOL.REJECT_TOKEN_CONSUMED
			else:
				reason = PROTOCOL.REJECT_TOKEN_UNKNOWN
	if reason.is_empty() and player_id.is_empty():
		var unavailable: Array[String] = []
		for value in _peer_to_player.values():
			unavailable.append(str(value))
		for reservation_value in _reservations.values():
			var reserved: Dictionary = reservation_value
			var reserved_id := str(reserved["player_id"])
			if not unavailable.has(reserved_id):
				unavailable.append(reserved_id)
		player_id = PROTOCOL.next_available_player_id(_player_ids, unavailable)
		if player_id.is_empty():
			reason = PROTOCOL.REJECT_SERVER_FULL
	if reason.is_empty():
		_peer_to_player[peer_id] = player_id
		_last_sequence[peer_id] = resume_last_sequence
		_peer_states[peer_id] = STATE_BASELINING
		if not _replication.set_peer_player(peer_id, player_id):
			reason = PROTOCOL.REJECT_AUTHORITY_COMMAND
		else:
			var raw_token := _new_token()
			var digest := raw_token.sha256_text()
			_active_token_digests[player_id] = digest
			var baseline_id := _new_stable_random("baseline")
			var resume_sequence := resume_last_sequence + 1
			_pending_baselines[peer_id] = baseline_id
			_bridge.send_handshake_accept(peer_id, {
				"protocol_version": PROTOCOL.PROTOCOL_VERSION,
				"player_id": player_id,
				"session_id": _session_id,
				"resume_token": raw_token,
				"resume_sequence": resume_sequence,
				"quest_snapshot": _inventory_state.quest_journal_snapshot(player_id) if _inventory_state != null else InventoryState.empty_quest_journal_snapshot(player_id),
			})
			peer_state_changed.emit(peer_id, STATE_BASELINING)
			var chunks := _replication.build_baseline_chunks(peer_id, baseline_id, _session_id, player_id, resume_sequence)
			if chunks.is_empty():
				reason = PROTOCOL.REJECT_MALFORMED_BASELINE
			else:
				for chunk in chunks:
					_bridge.send_baseline_chunk(peer_id, chunk)
				return
	if not player_id.is_empty():
		_peer_to_player.erase(peer_id)
		_last_sequence.erase(peer_id)
		_active_token_digests.erase(player_id)
		_replication.remove_peer(peer_id)
	_peer_states[peer_id] = STATE_REJECTED
	_telemetry["rejected_handshakes"] = int(_telemetry["rejected_handshakes"]) + 1
	_bridge.send_handshake_reject(peer_id, reason)
	peer_state_changed.emit(peer_id, STATE_REJECTED)


func _on_client_intent(peer_id: int, envelope: Dictionary) -> void:
	var sequence := -1
	if envelope.has("client_sequence") and typeof(envelope["client_sequence"]) == TYPE_INT:
		sequence = int(envelope["client_sequence"])
	var reason := PROTOCOL.validate_envelope(envelope)
	if not reason.is_empty():
		_reject_intent(peer_id, sequence, reason)
		return
	sequence = int(envelope["client_sequence"])
	var state := str(_peer_states.get(peer_id, ""))
	var intent_type := str(envelope["intent_type"])
	if state == STATE_BASELINING and intent_type == PROTOCOL.BASELINE_ACK:
		reason = PROTOCOL.validate_sequence(sequence, int(_last_sequence.get(peer_id, -1)))
		if not reason.is_empty():
			_reject_intent(peer_id, sequence, reason)
			return
		var baseline_id := str((envelope["payload"] as Dictionary)["baseline_id"])
		if baseline_id != str(_pending_baselines.get(peer_id, "")):
			_reject_intent(peer_id, sequence, PROTOCOL.REJECT_MALFORMED_BASELINE)
			return
		_pending_baselines.erase(peer_id)
		_peer_states[peer_id] = STATE_READY
		_telemetry["ready"] = int(_telemetry["ready"]) + 1
		_bridge.send_baseline_ready(peer_id, {"baseline_id": baseline_id, "next_sequence": sequence})
		peer_state_changed.emit(peer_id, STATE_READY)
		peer_ready.emit(peer_id, str(_peer_to_player[peer_id]))
		return
	if state != STATE_READY:
		_reject_intent(peer_id, sequence, PROTOCOL.REJECT_PRE_HANDSHAKE)
		return
	reason = PROTOCOL.validate_sequence(sequence, int(_last_sequence.get(peer_id, -1)))
	if not reason.is_empty():
		_reject_intent(peer_id, sequence, reason)
		return
	var player_id := str(_peer_to_player.get(peer_id, ""))
	if player_id.is_empty() or not _player_motors.has(player_id):
		_reject_intent(peer_id, sequence, PROTOCOL.REJECT_AUTHORITY_COMMAND)
		return
	if intent_type in PROTOCOL.AUTHORITY_INTENTS:
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


func bind_progression_authority(inventory: InventoryState) -> bool:
	if not _running or inventory == null or _inventory_state != null:
		return false
	_inventory_state = inventory
	return true


# Called only by the trusted host after authoritative simulation setup.
# When unbound, LAN market purchases fail closed (other progression is unaffected).
func bind_market_access_authority(guard: Prg05MarketAccessGuard) -> bool:
	if not _running or _inventory_state == null or guard == null or _market_access_guard != null:
		return false
	if not guard.is_bound_to(_inventory_state):
		return false
	_market_access_guard = guard
	return true


func _execute_gameplay_intent(peer_id: int, player_id: String, intent_type: String, payload: Dictionary) -> String:
	if intent_type in PROTOCOL.PROGRESSION_INTENTS:
		if _inventory_state == null:
			return PROTOCOL.REJECT_AUTHORITY_COMMAND
		var transaction_id := str(payload["transaction_id"])
		var operation_payload := payload.duplicate(true)
		operation_payload.erase("transaction_id")
		var fingerprint := LEDGER.fingerprint(intent_type, operation_payload)
		var lookup := _ledger.inspect(player_id, transaction_id, intent_type, fingerprint)
		var status := str(lookup["status"])
		if status == LEDGER.STATUS_CONFLICT:
			return PROTOCOL.REJECT_TRANSACTION_CONFLICT
		if status == LEDGER.STATUS_FULL:
			return PROTOCOL.REJECT_TRANSACTION_LEDGER_FULL
		if status == LEDGER.STATUS_CACHED:
			_bridge.send_transaction_result(peer_id, transaction_id, lookup["result"])
			return ""
		# Strict market location proof is evaluated AFTER cached-ACK retrieval
		# (so a player who leaves the harbor can still receive a lost ACK),
		# but BEFORE any new transaction or ledger mutation.
		if intent_type in [InventoryState.OP_MARKET_BUY, InventoryState.OP_MARKET_SELL]:
			var motor := _player_motors.get(player_id) as ShipMotor
			if _market_access_guard == null or not _market_access_guard.allows(player_id, str(operation_payload["market_id"]), motor):
				return PROTOCOL.REJECT_AUTHORITY_COMMAND
		var result := _inventory_state.execute_transaction(player_id, transaction_id, intent_type, operation_payload)
		if not _ledger.commit(player_id, transaction_id, intent_type, fingerprint, result):
			return PROTOCOL.REJECT_TRANSACTION_CONFLICT
		_bridge.send_transaction_result(peer_id, transaction_id, result)
		return ""
	if _combat_authority == null or _loot_authority == null:
		return PROTOCOL.REJECT_AUTHORITY_COMMAND
	if intent_type == PROTOCOL.PICKUP_LOOT:
		var drop_id := str(payload["drop_id"])
		var transaction_id := str(payload["transaction_id"])
		var operation_payload := {"drop_id": drop_id}
		var fingerprint := LEDGER.fingerprint(PROTOCOL.PICKUP_LOOT, operation_payload)
		var lookup := _ledger.inspect(player_id, transaction_id, PROTOCOL.PICKUP_LOOT, fingerprint)
		var status := str(lookup["status"])
		if status == LEDGER.STATUS_CONFLICT:
			return PROTOCOL.REJECT_TRANSACTION_CONFLICT
		if status == LEDGER.STATUS_FULL:
			return PROTOCOL.REJECT_TRANSACTION_LEDGER_FULL
		if status == LEDGER.STATUS_CACHED:
			_bridge.send_transaction_result(peer_id, transaction_id, lookup["result"])
			return ""
		var visible := _replication.is_visible_to_peer(peer_id, drop_id, "loot")
		if not visible and not _loot_authority.claimed_by_inventory_owner(player_id, drop_id):
			return PROTOCOL.REJECT_AOI
		var pickup := _loot_authority.pickup(player_id, LootAuthority.pickup_intent(drop_id))
		if not bool(pickup["accepted"]):
			return str(pickup["reason"])
		var result := {
			"accepted": true,
			"drop_id": drop_id,
			"item_id": str(pickup["item_id"]),
			"quantity": int(pickup["quantity"]),
		}
		if not _ledger.commit(player_id, transaction_id, PROTOCOL.PICKUP_LOOT, fingerprint, result):
			return PROTOCOL.REJECT_TRANSACTION_CONFLICT
		_bridge.send_transaction_result(peer_id, transaction_id, result)
		return ""
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


func _new_token() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	return bytes.hex_encode() if bytes.size() == 16 else ""


func _new_stable_random(prefix: String) -> String:
	var token := _new_token()
	return ("%s.r%s" % [prefix, token]) if not token.is_empty() else ""


func _cleanup_reservations() -> void:
	var now := Time.get_ticks_msec()
	for digest in _reservations.keys():
		var reservation: Dictionary = _reservations[digest]
		if now >= int(reservation["expires_at"]):
			_reservations.erase(digest)
			_remember_token(_expired_tokens, str(digest))


func _remember_token(store: Dictionary, digest: String) -> void:
	store[digest] = Time.get_ticks_msec()
	if store.size() <= MAX_TOKEN_HISTORY:
		return
	var rows: Array = []
	for key in store:
		rows.append({"key": key, "at": int(store[key])})
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["at"]) < int(b["at"]))
	while store.size() > MAX_TOKEN_HISTORY:
		store.erase(str(rows.pop_front()["key"]))


func _on_gameplay_drop_created(drop: Dictionary) -> void:
	spawn_network_entity(str(drop["drop_id"]), "loot", str(drop["sector_id"]),
		{"x": drop["x"], "y": drop["y"]}, str(drop["item_id"]))


func _on_gameplay_drop_claimed(drop_id: String, _item_id: String, _quantity: int) -> void:
	despawn_network_entity(drop_id)


# Detached, targeted read-only market view. Never accepts client prices/identity.
func send_market_snapshot(peer_id: int, player_id: String, snapshot: Dictionary) -> bool:
	if not _running or peer_state(peer_id) != STATE_READY or mapped_player_id(peer_id) != player_id:
		return false
	if not PROTOCOL.primitive_safe(snapshot):
		return false
	_bridge.send_market_snapshot(peer_id, snapshot)
	return true
