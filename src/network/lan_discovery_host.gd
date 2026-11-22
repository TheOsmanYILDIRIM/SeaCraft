class_name LanDiscoveryHost
extends RefCounted

var _socket: PacketPeerUDP
var _permission := LanPermissionGate.new()
var _beacon: Dictionary = {}
var _destination := ""
var _discovery_port := 0
var _last_send_ms := -LanDiscoveryProtocol.BEACON_INTERVAL_MS
var _active := false


func set_permission_gate(gate: LanPermissionGate) -> void:
	if gate != null and not _active:
		_permission = gate


func start(game_port: int, discovery_port: int, session_id: String, host_name: String,
		player_count: int, max_players: int, destination: String = "255.255.255.255") -> Error:
	if _active or game_port == discovery_port or not SessionProtocol.valid_port(game_port) or not SessionProtocol.valid_port(discovery_port):
		return ERR_INVALID_PARAMETER
	if destination.is_empty() or not _permission.can_open_lan_socket():
		return ERR_UNAUTHORIZED
	_beacon = LanDiscoveryProtocol.make_beacon(session_id, host_name, game_port, player_count, max_players)
	if not LanDiscoveryProtocol.validate_beacon(_beacon):
		return ERR_INVALID_DATA
	_socket = PacketPeerUDP.new()
	_socket.set_broadcast_enabled(true)
	var error := _socket.set_dest_address(destination, discovery_port)
	if error != OK:
		_socket = null
		return error
	_destination = destination
	_discovery_port = discovery_port
	_last_send_ms = -LanDiscoveryProtocol.BEACON_INTERVAL_MS
	_active = true
	return OK


func update_counts(player_count: int, max_players: int) -> bool:
	if not _active:
		return false
	var next := _beacon.duplicate(true)
	next["player_count"] = player_count
	next["max_players"] = max_players
	if not LanDiscoveryProtocol.validate_beacon(next):
		return false
	_beacon = next
	return true


func tick(now_ms: int) -> Error:
	if not _active or _socket == null or now_ms < 0:
		return ERR_UNCONFIGURED
	if now_ms - _last_send_ms < LanDiscoveryProtocol.BEACON_INTERVAL_MS:
		return OK
	var packet := LanDiscoveryProtocol.encode_beacon(_beacon)
	if packet.is_empty():
		return ERR_INVALID_DATA
	var error := _socket.put_packet(packet)
	if error == OK:
		_last_send_ms = now_ms
	return error


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_beacon.clear()
	_active = false


func is_active() -> bool:
	return _active


func session_id() -> String:
	return str(_beacon.get("session_id", ""))
