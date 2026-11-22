extends Node

const P := preload("res://src/network/session_protocol.gd")
const PLAYER := FoundationSector.PLAYER
const NPC := "entity.vs02_sc03"
const ITEM := "item.vs03_salvage_scrap"
const HIDDEN_TARGET := "entity.net03_hidden"
const HIDDEN_DROP := "drop.net03_hidden"

var _client: SessionClient
var _case := ""
var _reply: Dictionary = {}
var _states: Array[int] = []
var _fires := 0
var _failed := false


func start_case(port: int, test_case: String) -> void:
	_case = test_case
	_client = SessionClient.new()
	_client.name = "Session"
	get_parent().add_child(_client)
	_client.command_accepted.connect(_on_accept)
	_client.command_rejected.connect(_on_reject)
	if _client.join("127.0.0.1", port) != OK:
		_abort("could not join loopback")
		return
	_run.call_deferred()


func _on_accept(sequence: int) -> void:
	_reply[sequence] = ""


func _on_reject(sequence: int, reason: String) -> void:
	_reply[sequence] = reason


func _process(_delta: float) -> void:
	if _client == null or _client.state() != SessionClient.STATE_READY:
		return
	var npc := _proxy(NPC)
	if npc != null and npc.aoi_visible and npc.ai_state_id >= 0 and (_states.is_empty() or _states.back() != npc.ai_state_id):
		_states.append(npc.ai_state_id)


func _run() -> void:
	if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_READY, "handshake"):
		return
	if _client.assigned_player_id() != PLAYER:
		_abort("unexpected READY mapping")
		return
	print("NET03_CLIENT_READY case=%s player=%s" % [_case, PLAYER])
	if not await _wait(func() -> bool: return _visible(PLAYER) and _visible(NPC) and _proxy(NPC).ai_state_id == NpcBrain.State.PATROL, "baseline"):
		return
	if _case == "full" and not await _attack_cases():
		return
	var opening_position := _position(PLAYER)
	var opening_npc := _position(NPC)
	var replay_sequence := _client.next_sequence()
	if not await _move(opening_position + Vector2(80.0, 0.0)):
		return
	if not await _wait(func() -> bool: return _position(NPC).distance_to(opening_npc) > 1.0, "real host patrol displacement"):
		return
	if _case == "full":
		if not await _raw(replay_sequence, GameplayCommand.MOVE_TO_WORLD_POSITION, {"world_x": 0.0, "world_y": 0.0}, P.REJECT_REPLAY):
			return
		print("NET03_REMOTE_MOVE_OK")
	if not await _intent(P.SELECT_COMBAT_TARGET, {"target_id": NPC}):
		return
	if not await _intent(P.FIRE_WEAPON, {"target_id": NPC}, "out_of_range"):
		return
	if _case == "full":
		print("NET03_REMOTE_TARGET_OK")
	if not await _broadside() or not await _fire_and_observe():
		return
	if _case == "disconnect":
		var link := multiplayer.multiplayer_peer as ENetMultiplayerPeer
		if link == null:
			_abort("expected real ENet transport")
			return
		link.disconnect_peer(1, false)
		if not await _wait(func() -> bool: return _client.state() == SessionClient.STATE_DISCONNECTED, "graceful disconnect"):
			return
		print("NET03_CLIENT_DISCONNECT_EXIT")
		get_tree().quit(0)
		return
	if not await _intent(P.FIRE_WEAPON, {"target_id": NPC}, "reloading"):
		return
	print("NET03_REMOTE_FIRE_OK")
	if not await _wait(func() -> bool: return _states.has(NpcBrain.State.ALERT), "alert mirror"):
		return
	if not await _broadside() or not await _fire_and_observe():
		return
	if not await _wait(func() -> bool: return _states.has(NpcBrain.State.RESUME), "retreat / repair / resume mirror"):
		return
	var expected: Array[int] = [NpcBrain.State.PATROL, NpcBrain.State.ALERT, NpcBrain.State.RETREAT, NpcBrain.State.REPAIR, NpcBrain.State.RESUME]
	if _states != expected or not get_parent().find_children("*", "ShipMotor", true, false).is_empty():
		_abort("AI semantic order or presentation-only invariant")
		return
	print("NET03_AI_PARITY_OK client_decisions=0")
	if not await _broadside():
		return
	for _volley in 3:
		if not await _fire_and_observe():
			return
		if not _proxy(NPC).alive:
			break
	if _proxy(NPC).alive or _proxy(NPC).hull_ratio != 0.0:
		_abort("authoritative sunk mirror not observed")
		return
	if not await _wait(func() -> bool: return _count("ship_sunk") == 1 and _count("drop_created") == 1, "sunk and drop events"):
		return
	var created := _event("drop_created")
	var drop_id := str(created["source_id"])
	if not await _wait(func() -> bool: return _visible(drop_id), "drop proxy"):
		return
	if _count("hull_damaged") != _fires or str(_event("ship_sunk").get("target_id")) != NPC:
		_abort("invalid combat mirror events")
		return
	print("NET03_COMBAT_REPLICATION_OK")
	# Approach within the real pickup envelope, not the drop's exact center:
	# a loot point may be closer to the sector boundary than the ship's hull.
	var drop_position := _position(drop_id)
	var pickup_approach := drop_position.move_toward(_position(PLAYER), LootAuthority.PICKUP_RADIUS * 0.5)
	if not await _move(pickup_approach):
		return
	if _position(PLAYER).distance_to(drop_position) > LootAuthority.PICKUP_RADIUS:
		_abort("authoritative pickup approach is out of range")
		return
	if not await _intent(P.PICKUP_LOOT, {"drop_id": drop_id}):
		return
	if not await _wait(func() -> bool: return _proxy(drop_id) == null and _count("drop_claimed") == 1, "loot reward event and despawn"):
		return
	if not await _intent(P.PICKUP_LOOT, {"drop_id": drop_id}, "already_claimed"):
		return
	var claimed := _event("drop_claimed")
	var reward: Dictionary = claimed["payload"]
	if str(claimed["source_id"]) != drop_id or reward["item_id"] != ITEM or int(reward["quantity"]) <= 0:
		_abort("invalid replicated reward")
		return
	print("NET03_LOOT_CLAIM_ONCE_OK")
	var npc := _proxy(NPC)
	print("NET03_CLIENT_DIGEST %s" % JSON.stringify({
		"player": _client.assigned_player_id(), "npc": npc.entity_id, "sector": npc.sector_id, "seed": 424242,
		"transitions": _states, "sunk": _count("ship_sunk"), "drops": _count("drop_created"),
		"claims": _count("drop_claimed"), "fires": _fires, "hull": npc.hull_ratio * 100.0,
		"reward": int(reward["quantity"]), "item": str(reward["item_id"]), "drop": drop_id,
	}))
	_client.close_session()
	get_tree().quit(0)


func _attack_cases() -> bool:
	var bad := [
		"set_hull", "damage_entity", "sink_entity", "spawn_loot", "create_loot",
		"claim_result", "set_inventory", "grant_item", "despawn_entity",
	]
	for kind: String in bad:
		if not await _raw(_client.next_sequence(), kind, {"target_id": NPC}, P.REJECT_UNSUPPORTED_INTENT):
			return false
	if not await _raw(_client.next_sequence(), P.FIRE_WEAPON, {"target_id": NPC, "player_id": "entity.spoof"}, P.REJECT_FORBIDDEN_IDENTITY):
		return false
	if not await _raw(_client.next_sequence(), P.FIRE_WEAPON, {"target_id": NPC, "heading": 0.0}, P.REJECT_MALFORMED_PAYLOAD):
		return false
	if not await _raw(_client.next_sequence(), P.PICKUP_LOOT, {"drop_id": HIDDEN_DROP, "quantity": 42}, P.REJECT_MALFORMED_PAYLOAD):
		return false
	if not await _intent(P.SELECT_COMBAT_TARGET, {"target_id": HIDDEN_TARGET}, P.REJECT_AOI):
		return false
	if not await _intent(P.FIRE_WEAPON, {"target_id": HIDDEN_TARGET}, P.REJECT_AOI):
		return false
	return await _intent(P.PICKUP_LOOT, {"drop_id": HIDDEN_DROP}, P.REJECT_AOI)


func _broadside() -> bool:
	var target := _position(NPC)
	var firing := target + Vector2(0.0, -120.0 if target.y >= 0.0 else 120.0)
	firing.y = clampf(firing.y, -328.0, 328.0)
	var staging := firing + Vector2(-140.0 if firing.x - 140.0 >= -608.0 else 140.0, 0.0)
	if not await _move(staging) or not await _move(firing):
		return false
	return await _intent(P.SELECT_COMBAT_TARGET, {"target_id": NPC})


func _fire_and_observe() -> bool:
	var previous_hull := _proxy(NPC).hull_ratio
	if not await _intent(P.FIRE_WEAPON, {"target_id": NPC}):
		return false
	_fires += 1
	return await _wait(func() -> bool: return _visible(NPC) and _proxy(NPC).hull_ratio < previous_hull and _count("hull_damaged") >= _fires, "host damage mirror")


func _move(destination: Vector2) -> bool:
	var seq_before := _client.last_snapshot_sequence()
	if not await _intent(GameplayCommand.MOVE_TO_WORLD_POSITION, {"world_x": destination.x, "world_y": destination.y}):
		return false
	return await _wait(func() -> bool: return _client.last_snapshot_sequence() > seq_before and _position(PLAYER).distance_to(destination) <= 18.1, "authoritative arrival")


func _proxy(entity_id: String) -> NetworkEntityProxy:
	return _client.network_entity_registry().proxy(entity_id)


func _visible(entity_id: String) -> bool:
	var node := _proxy(entity_id)
	return node != null and node.aoi_visible


func _position(entity_id: String) -> Vector2:
	var node := _proxy(entity_id)
	if node == null:
		return Vector2.INF
	var state := node.authoritative_state()
	return Vector2(float(state["x"]), float(state["y"]))


func _count(kind: String) -> int:
	return _client.network_event_types().count(kind)


func _event(kind: String) -> Dictionary:
	for row: Dictionary in _client.network_events():
		if row["event_type"] == kind:
			return row
	return {}


func _intent(kind: String, payload: Dictionary, expected: String = "") -> bool:
	var sequence := _client.next_sequence()
	_reply.clear()
	if not _client.send_intent(kind, payload):
		_abort("local send rejected %s" % kind)
		return false
	return await _expect_reply(sequence, kind, expected)


func _raw(sequence: int, kind: String, payload: Dictionary, expected: String) -> bool:
	var bridge := _client.get_node("RpcBridge") as SessionRpcBridge
	_reply.clear()
	bridge.send_client_intent(P.make_envelope(sequence, kind, payload))
	return await _expect_reply(sequence, kind, expected)


func _expect_reply(sequence: int, kind: String, expected: String) -> bool:
	if not await _wait(func() -> bool: return _reply.has(sequence), "command reply %s" % kind):
		return false
	if _reply[sequence] != expected:
		_abort("%s sequence=%d expected '%s', got '%s'" % [kind, sequence, expected, _reply[sequence]])
		return false
	return true


func _wait(check: Callable, stage: String) -> bool:
	var deadline := Time.get_ticks_msec() + 7000
	while not _failed and Time.get_ticks_msec() < deadline:
		if check.call() == true:
			return true
		await get_tree().process_frame
	if not _failed:
		_abort("stage timeout: %s" % stage)
	return false


func _abort(reason: String) -> void:
	_failed = true
	push_error("NET03_PROCESS_FAILURE: client %s" % reason)
	get_tree().quit(1)
