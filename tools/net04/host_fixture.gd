extends "res://tests/fixtures/vertical_slice/vertical_slice_scenario.gd"

const NPC := "entity.net04_current"
const BETA := "player.beta"

var _session: SessionHost
var _discovery: LanDiscoveryHost
var _beta: ShipMotor
var _work := ""
var _drop_id := ""
var _boot_ms := 0
var _ready_counts: Dictionary = {}


func start_case(game_port: int, discovery_port: int, work: String) -> void:
	_work = work
	_boot_ms = Time.get_ticks_msec()
	_save_directory = "user://net04-host-%d" % OS.get_process_id()
	if not _create_initial_runtime():
		_abort("runtime init")
		return
	_beta = ShipMotor.new()
	_beta.name = "Net04Beta"
	_beta.authority_enabled = true
	_beta.global_position = _player_motor.global_position + Vector2(32.0, 0.0)
	_beta.set_physics_process(false)
	add_child(_beta)
	_session = SessionHost.new()
	_session.name = "Session"
	get_parent().add_child(_session, true)
	_session.peer_ready.connect(_on_peer_ready)
	_session.intent_applied.connect(_on_intent_applied)
	if not _session.configure_player_motors({PLAYER: _player_motor, BETA: _beta}):
		_abort("player configuration")
		return
	if _session.start(game_port) != OK or not _session.bind_gameplay_authority(_combat, _loot):
		_abort("session start")
		return
	var player_state := _player_motor.capture_save_motion()
	var beta_state := player_state.duplicate(true)
	beta_state["x"] = float(player_state.get("x", 0.0)) + 32.0
	if not _session.spawn_network_entity(PLAYER, "player", FoundationSector.ID, player_state):
		_abort("alpha spawn")
		return
	if not _session.spawn_network_entity(BETA, "player", FoundationSector.ID, beta_state):
		_abort("beta spawn")
		return
	if not _session.spawn_network_entity(NPC, "npc", FoundationSector.ID, {"x": 140.0, "y": 0.0, "heading": 0.0, "hull_ratio": 1.0, "alive": true}):
		_abort("npc spawn")
		return
	var player_position := _world.active().entity_position(PLAYER)
	var drop := {}
	for sequence in range(900, 940):
		drop = _loot.on_ship_sunk("entity.net04_fixture", sequence, player_position)
		if not drop.is_empty():
			break
	if drop.is_empty():
		_abort("loot fixture")
		return
	_drop_id = str(drop["drop_id"])
	if not _session.spawn_network_entity(_drop_id, "loot", FoundationSector.ID, {"x": drop["x"], "y": drop["y"]}, str(drop["item_id"])):
		_abort("drop spawn")
		return
	_discovery = LanDiscoveryHost.new()
	if _discovery.start(game_port, discovery_port, _session.session_id(), "NET04 CI Host", 0, 2, "127.0.0.1") != OK:
		_abort("discovery start")
		return
	set_process(true)
	print("NET04_HOST_READY session=%s game_port=%d discovery_port=%d drop=%s" % [_session.session_id(), game_port, discovery_port, _drop_id])


func _process(_delta: float) -> void:
	if Time.get_ticks_msec() - _boot_ms > 45000:
		_abort("timeout")
		return
	if _discovery != null:
		_discovery.update_counts(_session.snapshot()["peer_to_player"].size(), 2)
		if _discovery.tick(Time.get_ticks_msec()) != OK:
			_abort("discovery send")
			return
	if FileAccess.file_exists(_work + "/a_done"):
		var ledger := _session.transaction_ledger_snapshot()
		var entries: Array = ledger["entries"]
		if entries.size() != 1 or int(ledger["commit_sequence"]) != 1:
			_abort("transaction ledger duplicate")
			return
		print("NET04_HOST_LEDGER_OK entries=1 commit_sequence=1 reservations=%d" % _session.reservation_count())
		_discovery.stop()
		_session.stop()
		_clear_runtime_nodes()
		print("NET04_HOST_CLEAN_EXIT")
		get_tree().quit(0)


func _on_peer_ready(_peer_id: int, player_id: String) -> void:
	_ready_counts[player_id] = int(_ready_counts.get(player_id, 0)) + 1
	if player_id == BETA:
		print("NET04_HOST_LATE_JOIN_READY player=%s" % player_id)
	elif player_id == PLAYER and int(_ready_counts[player_id]) >= 2:
		print("NET04_HOST_RESUME_READY player=%s count=%d" % [player_id, int(_ready_counts[player_id])])


func _on_intent_applied(_peer_id: int, player_id: String, kind: String, _sequence: int) -> void:
	if player_id != PLAYER or kind != SessionProtocol.PICKUP_LOOT:
		return
	if FileAccess.file_exists(_work + "/commit"):
		return
	if not _session.update_network_entity_state(NPC, {"x": 321.0, "hull_ratio": 0.5}):
		_abort("current world update")
		return
	_touch(_work + "/commit")
	print("NET04_HOST_TRANSACTION_COMMITTED player=%s" % player_id)


func _touch(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file != null:
		file.store_string("ok\n")


func _abort(reason: String) -> void:
	push_error("NET04_PROCESS_FAILURE: host %s" % reason)
	if _discovery != null:
		_discovery.stop()
	if _session != null:
		_session.stop()
	get_tree().quit(1)
