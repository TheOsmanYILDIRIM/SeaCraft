extends SceneTree

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const HOST_SCRIPT := preload("res://src/network/session_host.gd")
const CLIENT_SCRIPT := preload("res://src/network/session_client.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const MOTOR_SCRIPT := preload("res://src/simulation/movement/ship_motor.gd")

var _mode := ""
var _scenario := ""
var _port := 0
var _stop_file := ""
var _started_ms := 0
var _finish_at_ms := 0
var _client: SessionClient
var _host: SessionHost
var _alpha: ShipMotor
var _beta: ShipMotor
var _security_stage := 0
var _prehandshake_sent := false
var _host_authority_printed := false


func _initialize() -> void:
	_started_ms = Time.get_ticks_msec()
	var args := _parse_args(OS.get_cmdline_user_args())
	_mode = str(args.get("mode", ""))
	_scenario = str(args.get("scenario", ""))
	_port = int(args.get("port", "0"))
	_stop_file = str(args.get("stop-file", ""))
	if not PROTOCOL.valid_port(_port):
		_fail("invalid port")
		return
	if _mode == "host":
		_start_host()
	elif _mode == "client":
		_start_client()
	else:
		_fail("invalid mode")


func _process(_delta: float) -> bool:
	var now := Time.get_ticks_msec()
	if now - _started_ms > 30000:
		_fail("timeout")
		return true
	if _finish_at_ms > 0 and now >= _finish_at_ms:
		quit(0)
		return true
	if _mode == "host" and not _stop_file.is_empty() and FileAccess.file_exists(_stop_file):
		if not _host_authority_printed:
			_fail("host never applied valid move")
			return true
		_host.stop()
		print("NET01_HOST_CLEAN_EXIT_OK")
		quit(0)
	return false


func _start_host() -> void:
	_host = HOST_SCRIPT.new()
	_host.name = "Session"
	root.add_child(_host)
	_alpha = MOTOR_SCRIPT.new()
	_alpha.name = "PlayerAlpha"
	_alpha.authority_enabled = true
	_alpha.set_physics_process(false)
	root.add_child(_alpha)
	_beta = MOTOR_SCRIPT.new()
	_beta.name = "PlayerBeta"
	_beta.authority_enabled = true
	_beta.set_physics_process(false)
	root.add_child(_beta)
	if not _host.configure_player_motors({"player.beta": _beta, "player.alpha": _alpha}):
		_fail("player configuration failed")
		return
	_host.intent_applied.connect(_on_host_intent_applied)
	var error := _host.start(_port)
	if error != OK:
		_fail("host start failed: %s" % error_string(error))
		return
	print("NET01_HOST_READY port=%d" % _port)


func _start_client() -> void:
	_client = CLIENT_SCRIPT.new()
	_client.name = "Session"
	if _scenario == "prehandshake":
		_client.set_auto_handshake(false)
	root.add_child(_client)
	_client.connection_state_changed.connect(_on_client_state_changed)
	_client.session_ready.connect(_on_client_ready)
	_client.session_rejected.connect(_on_client_rejected)
	_client.command_accepted.connect(_on_command_accepted)
	_client.command_rejected.connect(_on_command_rejected)
	var overrides: Dictionary = {}
	if _scenario == "protocol_mismatch":
		overrides["protocol_version"] = PROTOCOL.PROTOCOL_VERSION + 1
	elif _scenario == "content_mismatch":
		overrides["content_hash"] = "0".repeat(64)
	var error := _client.join("127.0.0.1", _port, overrides)
	if error != OK:
		_fail("client join failed: %s" % error_string(error))


func _on_client_state_changed(state: String) -> void:
	if _scenario == "prehandshake" and state == CLIENT_SCRIPT.STATE_CONNECTED and not _prehandshake_sent:
		_prehandshake_sent = true
		var envelope := PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 8.0, "world_y": 9.0})
		var bridge := _client.get_node("RpcBridge") as SessionRpcBridge
		bridge.send_client_intent(envelope)


func _on_client_ready(player_id: String) -> void:
	if _scenario != "success_security":
		_fail("unexpected ready for %s" % _scenario)
		return
	if player_id != "player.alpha":
		_fail("unexpected player mapping: %s" % player_id)
		return
	print("NET01_PROCESS_HANDSHAKE_OK")
	print("NET01_PROCESS_PEER_MAPPING_OK")
	if not _client.send_intent(COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 321.0, "world_y": -45.0}):
		_fail("valid move send failed")


func _on_client_rejected(reason: String) -> void:
	if _scenario == "protocol_mismatch" and reason == PROTOCOL.REJECT_PROTOCOL_MISMATCH:
		print("NET01_PROCESS_PROTOCOL_MISMATCH_OK")
		_finish_client()
		return
	if _scenario == "content_mismatch" and reason == PROTOCOL.REJECT_CONTENT_HASH_MISMATCH:
		print("NET01_PROCESS_CONTENT_MISMATCH_OK")
		_finish_client()
		return
	_fail("unexpected handshake rejection: %s" % reason)


func _on_command_accepted(sequence: int) -> void:
	if _scenario != "success_security" or sequence != 0 or _security_stage != 0:
		_fail("unexpected command accept sequence=%d stage=%d" % [sequence, _security_stage])
		return
	print("NET01_PROCESS_INTENT_AUTHORITY_OK")
	_security_stage = 1
	var replay := PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 999.0, "world_y": 999.0})
	var bridge := _client.get_node("RpcBridge") as SessionRpcBridge
	bridge.send_client_intent(replay)


func _on_command_rejected(sequence: int, reason: String) -> void:
	if _scenario == "prehandshake":
		if reason != PROTOCOL.REJECT_PRE_HANDSHAKE:
			_fail("prehandshake wrong reject: %s" % reason)
			return
		print("NET01_PROCESS_PREHANDSHAKE_OK")
		_finish_client()
		return
	if _scenario != "success_security":
		_fail("unexpected command rejection: %s" % reason)
		return
	var bridge := _client.get_node("RpcBridge") as SessionRpcBridge
	if _security_stage == 1:
		if sequence != 0 or reason != PROTOCOL.REJECT_REPLAY:
			_fail("replay wrong reject: %s" % reason)
			return
		print("NET01_PROCESS_REPLAY_OK")
		_security_stage = 2
		var spoof := PROTOCOL.make_envelope(1, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 700.0, "world_y": 700.0})
		spoof["player_id"] = "player.beta"
		bridge.send_client_intent(spoof)
		return
	if _security_stage == 2:
		if reason != PROTOCOL.REJECT_FORBIDDEN_IDENTITY:
			_fail("spoof wrong reject: %s" % reason)
			return
		print("NET01_PROCESS_SPOOF_OK")
		_security_stage = 3
		var malformed := PROTOCOL.make_envelope(1, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 1.0, "world_y": 2.0, "note": "x".repeat(PROTOCOL.MAX_STRING_LENGTH + 1)})
		bridge.send_client_intent(malformed)
		return
	if _security_stage == 3:
		if reason != PROTOCOL.REJECT_MALFORMED_PAYLOAD:
			_fail("malformed wrong reject: %s" % reason)
			return
		print("NET01_PROCESS_MALFORMED_OK")
		_security_stage = 4
		_finish_client()
		return
	_fail("unexpected security stage")


func _on_host_intent_applied(peer_id: int, player_id: String, intent_type: String, sequence: int) -> void:
	if _host_authority_printed or intent_type != COMMANDS.MOVE_TO_WORLD_POSITION:
		return
	_host_authority_printed = true
	var target := _alpha.target_world_position()
	print("NET01_HOST_AUTHORITY_APPLIED peer=%d player=%s sequence=%d target=(%.1f,%.1f) beta_has_target=%s" % [
		peer_id, player_id, sequence, target.x, target.y, str(_beta.has_target()).to_lower(),
	])


func _finish_client() -> void:
	_client.disconnect()
	_finish_at_ms = Time.get_ticks_msec() + 200


func _fail(message: String) -> void:
	printerr("NET01_PROCESS_FAILURE: %s" % message)
	if _host != null:
		_host.stop()
	if _client != null:
		_client.disconnect()
	quit(1)


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for raw in args:
		var arg := str(raw)
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var separator := arg.find("=")
		result[arg.substr(2, separator - 2)] = arg.substr(separator + 1)
	return result
