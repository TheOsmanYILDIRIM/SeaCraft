extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const HOST_SCRIPT := preload("res://src/network/session_host.gd")
const CLIENT_SCRIPT := preload("res://src/network/session_client.gd")
const MOTOR_SCRIPT := preload("res://src/simulation/movement/ship_motor.gd")

const SECTOR := "sector.net02"
const BASELINE_IDS := [
	"player.alpha", "player.beta", "npc.alpha", "npc.shared",
	"monster.beta", "loot.shared", "npc.remote",
]

var _mode := ""
var _label := ""
var _port := 0
var _stop_file := ""
var _started_ms := 0
var _scenario_started_ms := 0
var _stage := 0
var _host: SessionHost
var _client: SessionClient
var _alpha: ShipMotor
var _beta: ShipMotor
var _ready_peers: Dictionary = {}
var _mutation_rejections := 0
var _mutation_verified := false
var _baseline_printed := false
var _snapshot_printed := false
var _aoi_printed := false
var _combat_printed := false
var _loot_printed := false
var _late_printed := false
var _despawn_printed := false
var _mutation_sent := false
var _mutation_client_rejects := 0


func _ready() -> void:
	_started_ms = Time.get_ticks_msec()
	var args := _parse_args(OS.get_cmdline_user_args())
	_mode = str(args.get("mode", ""))
	_label = str(args.get("label", ""))
	_port = int(args.get("port", "0"))
	_stop_file = str(args.get("stop-file", ""))
	if not PROTOCOL.valid_port(_port):
		_fail("invalid port")
		return
	if _mode == "host":
		_start_host()
	elif _mode == "client" and _label in ["A", "B"]:
		_start_client()
	else:
		_fail("invalid mode/label")


func _process(_delta: float) -> void:
	var now := Time.get_ticks_msec()
	if now - _started_ms > 40000:
		_fail("timeout")
		return
	if _mode == "host":
		_process_host(now)
	else:
		_process_client()


func _start_host() -> void:
	_host = HOST_SCRIPT.new()
	_host.name = "Session"
	add_child(_host, true)
	_alpha = MOTOR_SCRIPT.new()
	_alpha.name = "PlayerAlpha"
	_alpha.authority_enabled = true
	_alpha.global_position = Vector2(0.0, 0.0)
	_alpha.set_physics_process(false)
	add_child(_alpha)
	_beta = MOTOR_SCRIPT.new()
	_beta.name = "PlayerBeta"
	_beta.authority_enabled = true
	_beta.global_position = Vector2(900.0, 0.0)
	_beta.set_physics_process(false)
	add_child(_beta)
	if not _host.configure_player_motors({"player.beta": _beta, "player.alpha": _alpha}):
		_fail("player configuration failed")
		return
	_host.peer_ready.connect(_on_host_peer_ready)
	_host.intent_rejected.connect(_on_host_intent_rejected)
	var error := _host.start(_port)
	if error != OK:
		_fail("host start failed: %s" % error_string(error))
		return
	print("NET02_HOST_READY port=%d" % _port)


func _start_client() -> void:
	_client = CLIENT_SCRIPT.new()
	_client.name = "Session"
	add_child(_client, true)
	_client.session_ready.connect(_on_client_ready)
	_client.session_rejected.connect(_on_client_rejected)
	_client.command_rejected.connect(_on_client_command_rejected)
	var error := _client.join("127.0.0.1", _port)
	if error != OK:
		_fail("client join failed: %s" % error_string(error))


func _on_host_peer_ready(peer_id: int, player_id: String) -> void:
	_ready_peers[peer_id] = player_id
	print("NET02_HOST_PEER_READY peer=%d player=%s" % [peer_id, player_id])
	if _ready_peers.size() == 2 and _scenario_started_ms == 0:
		_scenario_started_ms = Time.get_ticks_msec()


func _process_host(now: int) -> void:
	if _scenario_started_ms > 0:
		var elapsed := now - _scenario_started_ms
		if _stage == 0 and elapsed >= 100:
			if not _spawn_baseline():
				_fail("baseline spawn failed")
				return
			_stage = 1
			print("NET02_HOST_BASELINE_SPAWN_OK")
		elif _stage == 1 and elapsed >= 600:
			if not _host.update_network_entity_state("npc.shared", {"x": 460.0, "hull_ratio": 0.8}):
				_fail("shared state update failed")
				return
			if not _host.emit_network_event("hull_damaged", "monster.beta", "npc.shared", {"amount": 20.0, "remaining_hull": 80.0}):
				_fail("combat event failed")
				return
			if not _host.emit_network_event("drop_created", "loot.shared", "", {"item_id": "item.scrap", "quantity": 2, "sector_id": SECTOR}):
				_fail("loot event failed")
				return
			_stage = 2
			print("NET02_HOST_STATE_EVENTS_OK")
		elif _stage == 2 and elapsed >= 1100:
			if not _host.spawn_network_entity("npc.late", "npc", SECTOR, _state(500.0, 0.0, 1.0)):
				_fail("late spawn failed")
				return
			_stage = 3
			print("NET02_HOST_LATE_SPAWN_OK id=npc.late")
		elif _stage == 3 and elapsed >= 1700:
			if not _host.despawn_network_entity("loot.shared"):
				_fail("despawn failed")
				return
			_stage = 4
			print("NET02_HOST_DESPAWN_OK id=loot.shared")
	if not _stop_file.is_empty() and FileAccess.file_exists(_stop_file):
		if not _mutation_verified:
			_fail("client mutation rejection was not verified")
			return
		var telemetry := _host.network_replication_telemetry()
		print("NET02_HOST_METRICS peers=2 spawned=%d despawned=%d snapshots_sent=%d max_entities=%d max_snapshot_bytes=%d interval_ticks=%d stale_ignored=%d interpolation_max_samples=%d combat_events=%d loot_events=%d rejected_client_mutations=%d" % [
			int(telemetry.get("spawned", 0)),
			int(telemetry.get("despawned", 0)),
			int(telemetry.get("snapshots_sent", 0)),
			PROTOCOL.MAX_SNAPSHOT_ENTITIES,
			int(telemetry.get("max_payload_bytes", 0)),
			PROTOCOL.SNAPSHOT_INTERVAL_TICKS,
			int(telemetry.get("stale_snapshots", 0)),
			PROTOCOL.MAX_INTERPOLATION_SAMPLES,
			int(telemetry.get("combat_events", 0)),
			int(telemetry.get("loot_events", 0)),
			_mutation_rejections,
		])
		_host.stop()
		print("NET02_HOST_CLEAN_EXIT_OK")
		get_tree().quit(0)


func _spawn_baseline() -> bool:
	return (
		_host.spawn_network_entity("player.alpha", "player", SECTOR, _state(0.0, 0.0, 1.0), "", _alpha, &"capture_save_motion")
		and _host.spawn_network_entity("player.beta", "player", SECTOR, _state(900.0, 0.0, 1.0), "", _beta, &"capture_save_motion")
		and _host.spawn_network_entity("npc.alpha", "npc", SECTOR, _state(100.0, 0.0, 1.0))
		and _host.spawn_network_entity("npc.shared", "npc", SECTOR, _state(450.0, 0.0, 1.0))
		and _host.spawn_network_entity("monster.beta", "monster", SECTOR, _state(800.0, 0.0, 1.0))
		and _host.spawn_network_entity("loot.shared", "loot", SECTOR, _state(450.0, 20.0, 1.0))
		and _host.spawn_network_entity("npc.remote", "npc", "sector.other", _state(0.0, 0.0, 1.0))
	)


func _on_host_intent_rejected(_peer_id: int, _sequence: int, reason: String) -> void:
	if reason != PROTOCOL.REJECT_UNSUPPORTED_INTENT:
		return
	_mutation_rejections += 1
	if _mutation_rejections < 2 or _mutation_verified:
		return
	var row := _host.network_entity_registry().state_row("npc.shared")
	if row.is_empty() or not is_equal_approx(float(row["hull_ratio"]), 0.8) or _host.network_entity_registry().has_entity("npc.malicious"):
		_fail("malicious mutation changed authority state")
		return
	_mutation_verified = true
	print("NET02_HOST_MUTATION_UNCHANGED_OK rejects=%d" % _mutation_rejections)


func _on_client_ready(player_id: String) -> void:
	var expected := "player.alpha" if _label == "A" else "player.beta"
	if player_id != expected:
		_fail("unexpected mapping label=%s player=%s" % [_label, player_id])
		return
	print("NET02_CLIENT_READY label=%s player=%s" % [_label, player_id])


func _on_client_rejected(reason: String) -> void:
	_fail("unexpected client rejection: %s" % reason)


func _process_client() -> void:
	if _client == null or _client.state() != CLIENT_SCRIPT.STATE_READY:
		return
	var registry := _client.network_entity_registry()
	if registry == null:
		return
	if not _baseline_printed and _has_all(registry.entity_ids(), BASELINE_IDS):
		_baseline_printed = true
		print("NET02_CLIENT_BASELINE_OK label=%s count=%d" % [_label, registry.active_count()])
	if _baseline_printed and not _snapshot_printed and _client.last_snapshot_sequence() > 0:
		var shared := registry.proxy("npc.shared")
		if shared != null:
			var state := shared.authoritative_state()
			if is_equal_approx(float(state.get("x", 0.0)), 460.0) and is_equal_approx(float(state.get("hull_ratio", 1.0)), 0.8):
				_snapshot_printed = true
				print("NET02_CLIENT_SNAPSHOT_OK label=%s sequence=%d x=%.1f hull=%.2f" % [
					_label, _client.last_snapshot_sequence(), float(state["x"]), float(state["hull_ratio"]),
				])
	if not _aoi_printed:
		var visible := _client.visible_network_entity_ids()
		var expected_visible: Array[String] = (
			["loot.shared", "npc.alpha", "npc.shared", "player.alpha"]
			if _label == "A"
			else ["loot.shared", "monster.beta", "npc.shared", "player.beta"]
		)
		expected_visible.sort()
		if visible == expected_visible:
			_aoi_printed = true
			print("NET02_CLIENT_AOI_OK label=%s visible=%s" % [_label, str(visible)])
	var event_types := _client.network_event_types()
	if not _combat_printed and event_types.has("hull_damaged"):
		_combat_printed = true
		print("NET02_CLIENT_COMBAT_EVENT_OK label=%s" % _label)
	if not _loot_printed and event_types.has("drop_created"):
		_loot_printed = true
		print("NET02_CLIENT_LOOT_EVENT_OK label=%s" % _label)
	if not _late_printed and registry.has_entity("npc.late") and _client.visible_network_entity_ids().has("npc.late"):
		_late_printed = true
		print("NET02_CLIENT_LATE_SPAWN_OK label=%s id=npc.late" % _label)
	if _late_printed and not _despawn_printed and not registry.has_entity("loot.shared"):
		_despawn_printed = true
		print("NET02_CLIENT_DESPAWN_OK label=%s id=loot.shared" % _label)
	var common_done := _baseline_printed and _snapshot_printed and _aoi_printed and _combat_printed and _loot_printed and _late_printed and _despawn_printed
	if _label == "A" and common_done and not _mutation_sent:
		_mutation_sent = true
		var bridge := _client.get_node("RpcBridge") as SessionRpcBridge
		bridge.send_client_intent(PROTOCOL.make_envelope(100, "spawn_entity", {"kind": "npc"}))
		bridge.send_client_intent(PROTOCOL.make_envelope(101, "set_hull", {"value": 0.0}))
	if _label == "A" and common_done and _mutation_client_rejects >= 2:
		print("NET02_CLIENT_MUTATION_REJECT_OK label=A")
		_finish_client()
	elif _label == "B" and common_done:
		_finish_client()


func _on_client_command_rejected(_sequence: int, reason: String) -> void:
	if _label == "A" and reason == PROTOCOL.REJECT_UNSUPPORTED_INTENT:
		_mutation_client_rejects += 1


func _finish_client() -> void:
	var telemetry := _client.network_replication_telemetry()
	print("NET02_CLIENT_METRICS label=%s snapshots_received=%d max_snapshot_bytes=%d stale_ignored=%d interpolation_max_samples=%d combat_events=%d loot_events=%d" % [
		_label,
		int(telemetry.get("snapshots_received", 0)),
		int(telemetry.get("max_payload_bytes", 0)),
		int(telemetry.get("stale_snapshots", 0)),
		int(telemetry.get("interpolation_max_samples", 0)),
		int(telemetry.get("combat_events", 0)),
		int(telemetry.get("loot_events", 0)),
	])
	print("NET02_CLIENT_COMPLETE label=%s" % _label)
	_client.close_session()
	get_tree().quit(0)


func _fail(message: String) -> void:
	printerr("NET02_PROCESS_FAILURE: %s" % message)
	if _host != null:
		_host.stop()
	if _client != null:
		_client.close_session()
	get_tree().quit(1)


func _state(x: float, y: float, hull_ratio: float) -> Dictionary:
	return {"x": x, "y": y, "heading": 0.0, "hull_ratio": hull_ratio, "alive": true}


func _has_all(values: Array[String], expected: Array) -> bool:
	for value in expected:
		if not values.has(str(value)):
			return false
	return true


func _parse_args(args: PackedStringArray) -> Dictionary:
	var result: Dictionary = {}
	for raw in args:
		var arg := str(raw)
		if not arg.begins_with("--") or not arg.contains("="):
			continue
		var separator := arg.find("=")
		result[arg.substr(2, separator - 2)] = arg.substr(separator + 1)
	return result
