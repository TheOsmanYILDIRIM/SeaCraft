class_name LanDiscoveryClient
extends RefCounted

var _socket: PacketPeerUDP
var _permission := LanPermissionGate.new()
var _sessions: Dictionary = {}
var _active := false
var _window_started_ms := 0
var _global_count := 0
var _source_counts: Dictionary = {}


func set_permission_gate(gate: LanPermissionGate) -> void:
	if gate != null and not _active:
		_permission = gate


func start(discovery_port: int, bind_address: String = "0.0.0.0") -> Error:
	if _active or not SessionProtocol.valid_port(discovery_port) or bind_address.is_empty():
		return ERR_INVALID_PARAMETER
	if not _permission.can_open_lan_socket():
		return ERR_UNAUTHORIZED
	_socket = PacketPeerUDP.new()
	var error := _socket.bind(discovery_port, bind_address)
	if error != OK:
		_socket = null
		return error
	_active = true
	_window_started_ms = Time.get_ticks_msec()
	return OK


func poll(now_ms: int = -1) -> int:
	if not _active or _socket == null:
		return 0
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	_reset_budget_if_needed(now)
	var processed := 0
	while processed < LanDiscoveryProtocol.MAX_PACKETS_PER_FRAME and _socket.get_available_packet_count() > 0:
		var packet := _socket.get_packet()
		var source := _socket.get_packet_ip()
		processed += 1
		if not _allow_source(source):
			continue
		var beacon := LanDiscoveryProtocol.parse_packet(packet)
		if beacon.is_empty():
			continue
		var session_id := str(beacon["session_id"])
		if not _sessions.has(session_id) and _sessions.size() >= LanDiscoveryProtocol.MAX_VISIBLE_SESSIONS:
			continue
		var row := beacon.duplicate(true)
		row["address"] = source
		row["compatible"] = LanDiscoveryProtocol.compatible(beacon)
		row["last_seen_ms"] = now
		_sessions[session_id] = row
	expire(now)
	return processed


func expire(now_ms: int = -1) -> int:
	var now := Time.get_ticks_msec() if now_ms < 0 else now_ms
	var removed := 0
	for session_id in _sessions.keys():
		var row: Dictionary = _sessions[session_id]
		if now - int(row["last_seen_ms"]) > LanDiscoveryProtocol.TTL_MS:
			_sessions.erase(session_id)
			removed += 1
	return removed


func sessions() -> Array[Dictionary]:
	var ids := _sessions.keys()
	ids.sort()
	var result: Array[Dictionary] = []
	for session_id in ids:
		result.append((_sessions[session_id] as Dictionary).duplicate(true))
	return result


func compatible_sessions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row in sessions():
		if bool(row.get("compatible", false)):
			result.append(row)
	return result


func stop() -> void:
	if _socket != null:
		_socket.close()
	_socket = null
	_sessions.clear()
	_source_counts.clear()
	_active = false


func is_active() -> bool:
	return _active


func _reset_budget_if_needed(now_ms: int) -> void:
	if now_ms - _window_started_ms >= 1000:
		_window_started_ms = now_ms
		_global_count = 0
		_source_counts.clear()


func _allow_source(source: String) -> bool:
	if _global_count >= LanDiscoveryProtocol.GLOBAL_PACKETS_PER_SECOND:
		return false
	var count := int(_source_counts.get(source, 0))
	if count >= LanDiscoveryProtocol.SOURCE_PACKETS_PER_SECOND:
		return false
	_global_count += 1
	_source_counts[source] = count + 1
	return true
