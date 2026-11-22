extends "res://tests/fixtures/vertical_slice/vertical_slice_scenario.gd"

const P := preload("res://src/network/session_protocol.gd")
const HIDDEN_TARGET := "entity.net03_hidden"
const HIDDEN_DROP := "drop.net03_hidden"
const OBSERVATION_TICKS := 24

var _host: SessionHost
var _peer_id := 0
var _case := ""
var _stop_path := ""
var _boot_ms := 0
var _moves := 0
var _rejects: Dictionary = {}
var _pre_attack_combat: Dictionary = {}
var _pre_attack_loot: Dictionary = {}
var _pre_attack_ids: Array[String] = []
var _ai_hold := 0
var _repair_pending := false
var _disconnect_checked := false
var _claimed_quantity := 0


func start_case(port: int, test_case: String, stop_path: String) -> void:
	_case = test_case
	_stop_path = stop_path
	_boot_ms = Time.get_ticks_msec()
	_save_directory = "user://net03-%s-%d" % [_case, OS.get_process_id()]
	if not _create_initial_runtime():
		_abort("VS-04 runtime initialization")
		return
	_host = SessionHost.new()
	_host.name = "Session"
	get_parent().add_child(_host)
	_host.peer_ready.connect(_on_peer_ready)
	_host.intent_applied.connect(_on_intent_applied)
	_host.intent_rejected.connect(_on_intent_rejected)
	if not _host.configure_player_motors({PLAYER: _player_motor}) or _host.start(port) != OK:
		_abort("ENet host startup")
		return
	if not _host.bind_gameplay_authority(_combat, _loot):
		_abort("authority binding")
		return
	_loot.drop_claimed.connect(_on_claim)
	set_physics_process(true)
	print("NET03_HOST_READY case=%s" % _case)


func _on_peer_ready(peer_id: int, player_id: String) -> void:
	if _peer_id != 0 or player_id != PLAYER:
		_abort("unexpected player mapping")
		return
	_peer_id = peer_id
	if not _host.spawn_network_entity(PLAYER, "player", FoundationSector.ID, _player_motor.capture_save_motion(),
			"", _player_motor, &"capture_save_motion") or not _host.spawn_network_entity(
			NPC, "npc", FoundationSector.ID, npc_snapshot(), "", self, &"npc_snapshot"):
		_abort("VS-04 entity spawn")
		return
	if _case == "full":
		if not _host.spawn_network_entity(HIDDEN_TARGET, "npc", FoundationSector.OUTER_ID, {}) or not _host.spawn_network_entity(HIDDEN_DROP, "loot", FoundationSector.OUTER_ID, {}):
			_abort("out-of-interest fixture spawn")
			return
	_pre_attack_combat = _combat.snapshot_state()
	_pre_attack_loot = _loot.snapshot_state()
	_pre_attack_ids = _host.network_entity_registry().entity_ids()


func npc_snapshot() -> Dictionary:
	var state := _npc_motor.capture_save_motion()
	state["hull_ratio"] = _combat.hull(NPC) / 100.0
	state["alive"] = _combat.is_alive(NPC)
	state["ai_state_id"] = _brain.state_id()
	state["ai_intent_id"] = _brain.intent_id()
	return state


func _on_intent_applied(_sender: int, player_id: String, kind: String, _sequence: int) -> void:
	if player_id != PLAYER:
		_abort("unmapped actor")
		return
	match kind:
		GameplayCommand.MOVE_TO_WORLD_POSITION:
			if _moves == 0 and _case == "full":
				if int(_rejects.get(P.REJECT_UNSUPPORTED_INTENT, 0)) != 9 or int(_rejects.get(P.REJECT_AOI, 0)) != 3 or int(_rejects.get(P.REJECT_FORBIDDEN_IDENTITY, 0)) != 1 or int(_rejects.get(P.REJECT_MALFORMED_PAYLOAD, 0)) != 2:
					_abort("negative intent coverage")
					return
				if _combat.snapshot_state() != _pre_attack_combat or _loot.snapshot_state() != _pre_attack_loot or _host.network_entity_registry().entity_ids() != _pre_attack_ids:
					_abort("rejected outcome changed authority")
					return
				print("NET03_AUTHORITY_REJECTION_OK")
			# Match VS-04 fixed progression: patrol while making the opening
			# move; pause AI while lining up each broadside.
			for _i in MAX_MOVE_FRAMES:
				_step_frame(_moves == 0, true)
				if not _player_motor.has_target():
					break
			if _player_motor.has_target():
				_abort("authoritative movement did not arrive")
				return
			_moves += 1
		P.SELECT_COMBAT_TARGET:
			pass
		P.FIRE_WEAPON:
			_accepted_fires += 1
			if _accepted_fires == 1:
				if _combat.hull(NPC) <= 0.0 or _combat.hull(NPC) >= 100.0:
					_abort("first accepted shot did not cause nonlethal damage")
			elif _accepted_fires == 2:
				if _combat.hull(NPC) > 35.0 or not _advance_until_state(NpcBrain.State.RETREAT, 120):
					_abort("real AI did not retreat after critical damage")
					return
				_ai_hold = OBSERVATION_TICKS
				_repair_pending = true
			elif _combat.is_alive(NPC):
				_step_frame(false, true)


func _on_intent_rejected(_sender: int, _sequence: int, reason: String) -> void:
	_rejects[reason] = int(_rejects.get(reason, 0)) + 1
	if reason == "reloading" and _accepted_fires == 1:
		if not _advance_until_state(NpcBrain.State.ALERT, 120):
			_abort("real AI did not alert after first damage")


func _on_claim(drop_id: String, item_id: String, quantity: int) -> void:
	if drop_id != _last_drop_id or item_id != LOOT_ITEM.stable_id or quantity <= 0:
		_abort("unexpected authoritative reward")
		return
	_pickup_events += 1
	_claimed_quantity += quantity


func _physics_process(_delta: float) -> void:
	if Time.get_ticks_msec() - _boot_ms > 50000:
		_abort("host timeout")
		return
	if _ai_hold > 0:
		_ai_hold -= 1
		if _ai_hold == 0:
			if _repair_pending:
				if not _advance_until_state(NpcBrain.State.REPAIR, MAX_AI_FRAMES):
					_abort("real AI did not reach repair")
					return
				_repair_pending = false
				_ai_hold = OBSERVATION_TICKS
			elif not _advance_until_state(NpcBrain.State.RESUME, MAX_AI_FRAMES):
				_abort("real AI did not resume patrol")
				return
	if _case == "disconnect" and _peer_id > 1 and _host.mapped_player_id(_peer_id).is_empty() and not _disconnect_checked:
		if not _verify_disconnect():
			_abort("combat disconnect invariant")
			return
		_disconnect_checked = true
		print("NET03_DISCONNECT_COMBAT_OK")
	if not FileAccess.file_exists(_stop_path):
		return
	if _case == "full":
		if not _print_digest():
			_abort("final host ledger or coverage invariant")
			return
	elif not _disconnect_checked:
		_abort("driver ended before remote disconnect cleanup")
		return
	_host.stop()
	_clear_runtime_nodes()
	print("NET03_HOST_CLEAN_EXIT case=%s" % _case)
	get_tree().quit(0)


func _verify_disconnect() -> bool:
	var hull_before := _combat.hull(NPC)
	var loot_before := _loot.snapshot_state()
	var decisions_before := _brain.decision_count
	var player_before := _world.active().entity_position(PLAYER)
	if _accepted_fires != 1 or not (hull_before > 0.0 and hull_before < 100.0):
		return false
	if not _advance_until_state(NpcBrain.State.ALERT, 120):
		return false
	var session := _host.snapshot()
	return (_brain.decision_count > decisions_before and _combat.hull(NPC) == hull_before
		and _loot.snapshot_state() == loot_before and _sunk_events == 0 and _drop_events == 0 and _pickup_events == 0
		and _host.network_entity_registry().authority_owned(PLAYER)
		and _world.active().entity_position(PLAYER) == player_before and player_before.is_finite()
		and (session["peer_to_player"] as Dictionary).is_empty()
		and (session["peer_states"] as Dictionary).is_empty()
		and (session["last_sequence"] as Dictionary).is_empty())


func _print_digest() -> bool:
	var expected: Array[int] = [NpcBrain.State.PATROL, NpcBrain.State.ALERT, NpcBrain.State.RETREAT, NpcBrain.State.REPAIR, NpcBrain.State.RESUME]
	var final_reward := _loot.inventory_quantity(LOOT_ITEM.stable_id)
	var loot_state := _loot.snapshot_state()
	if (_moves < 8 or _transitions != expected or _brain.decision_count <= 0
			or _sunk_events != 1 or _drop_events != 1 or _pickup_events != 1 or _combat.is_alive(NPC)
			or final_reward <= 0 or final_reward != _claimed_quantity or _loot.has_drop(_last_drop_id)
			or _host.network_entity_registry().has_entity(_last_drop_id)
			or (loot_state["claimed_ids"] as Array) != [_last_drop_id]
			or int(_rejects.get("already_claimed", 0)) != 1
			or int(_rejects.get(P.REJECT_REPLAY, 0)) != 1
			or int(_rejects.get("out_of_range", 0)) != 1 or int(_rejects.get("reloading", 0)) != 1):
		return false
	print("NET03_HOST_AI_ONLY_OK decisions=%d" % _brain.decision_count)
	print("NET03_HOST_DIGEST %s" % JSON.stringify({
		"player": PLAYER, "npc": NPC, "sector": FoundationSector.ID, "seed": MASTER_SEED,
		"transitions": _transitions, "sunk": _sunk_events, "drops": _drop_events,
		"claims": _pickup_events, "fires": _accepted_fires, "hull": _combat.hull(NPC),
		"reward": final_reward, "item": LOOT_ITEM.stable_id, "drop": _last_drop_id,
	}))
	return true


func _abort(reason: String) -> void:
	push_error("NET03_PROCESS_FAILURE: host %s" % reason)
	get_tree().quit(1)
