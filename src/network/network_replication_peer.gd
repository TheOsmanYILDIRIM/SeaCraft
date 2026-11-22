class_name NetworkReplicationPeer
extends Node

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const REGISTRY_SCRIPT := preload("res://src/network/network_entity_registry.gd")
const PROXY_SCRIPT := preload("res://src/network/network_entity_proxy.gd")

signal entity_spawned(entity_id: String, entity_kind: String)
signal entity_despawned(entity_id: String)
signal snapshot_applied(sequence: int, entity_count: int)
signal semantic_event_received(event: Dictionary)
signal baseline_complete(baseline_id: String, resume_sequence: int)

var _registry: NetworkEntityRegistry = REGISTRY_SCRIPT.new()
var _bridge: SessionRpcBridge
var _root: Node2D
var _spawner: MultiplayerSpawner
var _host_enabled: bool = false
var _peer_to_player: Dictionary = {}
var _sources: Dictionary = {}
var _server_tick: int = 0
var _snapshot_sequence: int = 0
var _lifecycle_sequence: int = 0
var _event_sequence: int = 0
var _last_snapshot_sequence: int = -1
var _last_event_sequence: int = -1
var _seen_event_ids: Dictionary = {}
var _event_history: Array[Dictionary] = []
var _baseline_chunks: Dictionary = {}
var _baseline_header: Dictionary = {}
var _telemetry := {
	"spawned": 0,
	"despawned": 0,
	"snapshots_sent": 0,
	"snapshots_received": 0,
	"snapshot_entities": 0,
	"payload_bytes": 0,
	"max_payload_bytes": 0,
	"stale_snapshots": 0,
	"budget_rejections": 0,
	"snapshot_interval_ticks": PROTOCOL.SNAPSHOT_INTERVAL_TICKS,
	"interpolation_max_samples": 0,
	"combat_events": 0,
	"loot_events": 0,
	"rejected_events": 0,
}


func _ready() -> void:
	_root = Node2D.new()
	_root.name = "ReplicatedEntities"
	add_child(_root, true)
	_spawner = MultiplayerSpawner.new()
	_spawner.name = "EntitySpawner"
	add_child(_spawner, true)
	_spawner.spawn_path = NodePath("../ReplicatedEntities")
	_spawner.spawn_limit = PROTOCOL.MAX_REPLICATED_ENTITIES
	_spawner.spawn_function = Callable(self, "_spawn_proxy")
	_spawner.spawned.connect(_on_remote_spawned)
	_spawner.despawned.connect(_on_remote_despawned)


func configure_bridge(bridge: SessionRpcBridge) -> void:
	if _bridge == bridge:
		return
	_bridge = bridge
	if _bridge == null:
		return
	if not _bridge.replication_snapshot_received.is_connected(_on_replication_snapshot):
		_bridge.replication_snapshot_received.connect(_on_replication_snapshot)
	if not _bridge.replication_event_received.is_connected(_on_replication_event):
		_bridge.replication_event_received.connect(_on_replication_event)


func set_host_enabled(enabled: bool) -> void:
	_host_enabled = enabled


func registry() -> NetworkEntityRegistry:
	return _registry


func telemetry() -> Dictionary:
	return _telemetry.duplicate(true)


func last_snapshot_sequence() -> int:
	return _last_snapshot_sequence


func event_history() -> Array[Dictionary]:
	return _event_history.duplicate(true)


func event_types() -> Array[String]:
	var result: Array[String] = []
	for event in _event_history:
		result.append(str(event["event_type"]))
	return result


func server_tick() -> int:
	return _server_tick


func snapshot_sequence() -> int:
	return _snapshot_sequence


func event_sequence() -> int:
	return _event_sequence


func build_baseline_chunks(peer_id: int, baseline_id: String, session_id: String, player_id: String, resume_sequence: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not _host_enabled or str(_peer_to_player.get(peer_id, "")) != player_id:
		return result
	_refresh_all_sources()
	var own_row := _registry.state_row(player_id)
	var payloads: Array = []
	if not own_row.is_empty():
		var center := Vector2(float(own_row["x"]), float(own_row["y"]))
		var visible := _registry.visible_ids(str(own_row["sector_id"]), center, PROTOCOL.AOI_RADIUS, player_id)
		if visible.size() > PROTOCOL.MAX_REPLICATED_ENTITIES:
			return result
		for entity_id in visible:
			var payload := _registry.spawn_payload_for(entity_id, _snapshot_sequence)
			if payload.is_empty():
				return []
			payloads.append(payload)
	var chunk_count := maxi(1, int(ceil(float(payloads.size()) / float(PROTOCOL.BASELINE_CHUNK_ENTITIES))))
	for chunk_index in chunk_count:
		var begin := chunk_index * PROTOCOL.BASELINE_CHUNK_ENTITIES
		var end := mini(payloads.size(), begin + PROTOCOL.BASELINE_CHUNK_ENTITIES)
		var rows: Array = payloads.slice(begin, end)
		var chunk := PROTOCOL.make_baseline_chunk(
			baseline_id, session_id, player_id, _server_tick, _snapshot_sequence, _event_sequence,
			resume_sequence, chunk_index, chunk_count, rows
		)
		if PROTOCOL.validate_baseline_chunk(chunk) != "":
			return []
		result.append(chunk)
	return result


func consume_baseline_chunk(chunk: Dictionary) -> bool:
	if _host_enabled or PROTOCOL.validate_baseline_chunk(chunk) != "":
		return false
	var baseline_id := str(chunk["baseline_id"])
	if _baseline_header.is_empty():
		if int(chunk["chunk_index"]) != 0:
			return false
		_baseline_header = {
			"baseline_id": baseline_id,
			"session_id": str(chunk["session_id"]),
			"player_id": str(chunk["player_id"]),
			"server_tick": int(chunk["server_tick"]),
			"snapshot_sequence": int(chunk["snapshot_sequence"]),
			"event_sequence": int(chunk["event_sequence"]),
			"resume_sequence": int(chunk["resume_sequence"]),
			"chunk_count": int(chunk["chunk_count"]),
		}
	elif (
		baseline_id != str(_baseline_header["baseline_id"])
		or str(chunk["session_id"]) != str(_baseline_header["session_id"])
		or str(chunk["player_id"]) != str(_baseline_header["player_id"])
		or int(chunk["server_tick"]) != int(_baseline_header["server_tick"])
		or int(chunk["snapshot_sequence"]) != int(_baseline_header["snapshot_sequence"])
		or int(chunk["event_sequence"]) != int(_baseline_header["event_sequence"])
		or int(chunk["resume_sequence"]) != int(_baseline_header["resume_sequence"])
		or int(chunk["chunk_count"]) != int(_baseline_header["chunk_count"])
	):
		return false
	var index := int(chunk["chunk_index"])
	if _baseline_chunks.has(index):
		return true
	_baseline_chunks[index] = (chunk["entity_payloads"] as Array).duplicate(true)
	if _baseline_chunks.size() < int(_baseline_header["chunk_count"]):
		return true
	for expected in int(_baseline_header["chunk_count"]):
		if not _baseline_chunks.has(expected):
			return false
	var payloads: Array = []
	for chunk_index in int(_baseline_header["chunk_count"]):
		payloads.append_array(_baseline_chunks[chunk_index])
	if payloads.size() > PROTOCOL.MAX_REPLICATED_ENTITIES:
		return false
	var desired: Dictionary = {}
	for raw in payloads:
		var payload: Dictionary = raw
		var entity_id := str(payload["entity_id"])
		desired[entity_id] = true
		if _registry.has_entity(entity_id):
			var proxy := _registry.proxy(entity_id)
			if _registry.generation(entity_id) != int(payload["generation"]) or proxy == null:
				return false
			if not _registry.apply_snapshot_row(_row_from_spawn(payload), int(_baseline_header["snapshot_sequence"]), int(_baseline_header["server_tick"])):
				return false
		else:
			var node := _spawn_proxy(payload)
			if node == null:
				return false
			_root.add_child(node, true)
	for entity_id in _registry.entity_ids():
		if desired.has(entity_id):
			continue
		var proxy := _registry.proxy(entity_id)
		var generation := _registry.generation(entity_id)
		if _registry.remove(entity_id, generation) and proxy != null and is_instance_valid(proxy):
			proxy.queue_free()
	var visible: Array[String] = []
	for raw_id in desired.keys():
		visible.append(str(raw_id))
	visible.sort()
	_registry.set_proxy_visibility(visible)
	_last_snapshot_sequence = int(_baseline_header["snapshot_sequence"])
	_last_event_sequence = int(_baseline_header["event_sequence"])
	_seen_event_ids.clear()
	_event_history.clear()
	var completed_id := str(_baseline_header["baseline_id"])
	var resume := int(_baseline_header["resume_sequence"])
	_baseline_chunks.clear()
	_baseline_header.clear()
	baseline_complete.emit(completed_id, resume)
	return true


func _row_from_spawn(payload: Dictionary) -> Dictionary:
	return {
		"entity_id": str(payload["entity_id"]),
		"entity_kind": str(payload["entity_kind"]),
		"sector_id": str(payload["sector_id"]),
		"x": float(payload["x"]),
		"y": float(payload["y"]),
		"heading": float(payload["heading"]),
		"hull_ratio": float(payload["hull_ratio"]),
		"alive": bool(payload["alive"]),
	}


func set_peer_player(peer_id: int, player_id: String) -> bool:
	if not _host_enabled or peer_id <= 1 or not PROTOCOL.valid_stable_id(player_id):
		return false
	_peer_to_player[peer_id] = player_id
	return true


func remove_peer(peer_id: int) -> void:
	_peer_to_player.erase(peer_id)


func spawn_authoritative(entity_id: String, entity_kind: String, sector_id: String, initial_state: Dictionary,
		definition_id: String = "", source: Object = null, snapshot_method: StringName = &"", source_args: Array = []) -> bool:
	if not _host_enabled or _spawner == null or _registry.active_count() >= PROTOCOL.MAX_REPLICATED_ENTITIES:
		return false
	var generation := _registry.next_generation(entity_id)
	var lifecycle := PROTOCOL.next_sequence(_lifecycle_sequence)
	if generation <= 0 or lifecycle <= 0:
		return false
	var payload := PROTOCOL.spawn_payload(
		entity_id, entity_kind, sector_id, definition_id, generation, lifecycle,
		_snapshot_sequence, initial_state
	)
	if PROTOCOL.validate_spawn_payload(payload) != "" or not _registry.register_authority(payload):
		return false
	_lifecycle_sequence = lifecycle
	var spawned := _spawner.spawn(payload)
	if spawned == null:
		_registry.remove(entity_id, generation)
		return false
	if source != null and not str(snapshot_method).is_empty():
		bind_snapshot_source(entity_id, source, snapshot_method, source_args)
	_telemetry["spawned"] = int(_telemetry["spawned"]) + 1
	entity_spawned.emit(entity_id, entity_kind)
	return true


func despawn_authoritative(entity_id: String) -> bool:
	if not _host_enabled or not _registry.has_entity(entity_id) or not _registry.authority_owned(entity_id):
		return false
	var generation := _registry.generation(entity_id)
	var node := _registry.proxy(entity_id)
	if node == null or not is_instance_valid(node) or not _registry.remove(entity_id, generation):
		return false
	_sources.erase(entity_id)
	node.queue_free()
	_telemetry["despawned"] = int(_telemetry["despawned"]) + 1
	entity_despawned.emit(entity_id)
	return true


func update_authoritative_state(entity_id: String, changes: Dictionary) -> bool:
	return _host_enabled and _registry.update_authority_state(entity_id, changes)


func bind_snapshot_source(entity_id: String, source: Object, method: StringName, source_args: Array = []) -> bool:
	if not _host_enabled or source == null or str(method).is_empty() or not source.has_method(method) or not _registry.has_entity(entity_id):
		return false
	if not _sources.has(entity_id):
		_sources[entity_id] = []
	var adapters: Array = _sources[entity_id]
	adapters.append({"source": source, "method": method, "args": source_args.duplicate(true)})
	return true


func bind_combat_authority(authority: Object) -> bool:
	if not _host_enabled or authority == null:
		return false
	var bindings := {
		"hull_damaged": Callable(self, "_on_hull_damaged"),
		"ship_sunk": Callable(self, "_on_ship_sunk"),
		"monster_defeated": Callable(self, "_on_monster_defeated"),
		"wreck_destroyed": Callable(self, "_on_wreck_destroyed"),
	}
	var connected := false
	for signal_name in bindings:
		if authority.has_signal(signal_name):
			var callable: Callable = bindings[signal_name]
			if not authority.is_connected(signal_name, callable):
				authority.connect(signal_name, callable)
			connected = true
	return connected


func bind_loot_authority(authority: Object) -> bool:
	if not _host_enabled or authority == null:
		return false
	var bindings := {
		"drop_created": Callable(self, "_on_drop_created"),
		"drop_claimed": Callable(self, "_on_drop_claimed"),
	}
	var connected := false
	for signal_name in bindings:
		if authority.has_signal(signal_name):
			var callable: Callable = bindings[signal_name]
			if not authority.is_connected(signal_name, callable):
				authority.connect(signal_name, callable)
			connected = true
	return connected


func emit_semantic_event(event_type: String, source_id: String, target_id: String, payload: Dictionary) -> bool:
	if not _host_enabled or _bridge == null:
		return false
	var next_event := PROTOCOL.next_sequence(_event_sequence)
	if next_event <= 0:
		return false
	var event_id := "net.%s.s%d" % [event_type, next_event]
	var event := PROTOCOL.make_semantic_event(next_event, event_id, event_type, source_id, target_id, payload)
	if PROTOCOL.validate_semantic_event(event) != "":
		return false
	_event_sequence = next_event
	var peer_ids := _peer_to_player.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		_bridge.send_replication_event(int(raw_peer_id), event)
	_count_event(event_type)
	return true


func consume_snapshot(snapshot: Dictionary) -> bool:
	if _host_enabled:
		return false
	var reason := PROTOCOL.validate_snapshot(snapshot)
	if not reason.is_empty():
		if reason == PROTOCOL.REJECT_SNAPSHOT_BUDGET:
			_telemetry["budget_rejections"] = int(_telemetry["budget_rejections"]) + 1
		return false
	var sequence := int(snapshot["snapshot_sequence"])
	if sequence <= _last_snapshot_sequence:
		_telemetry["stale_snapshots"] = int(_telemetry["stale_snapshots"]) + 1
		return false
	var visible_ids: Array[String] = []
	var applied := 0
	for raw in snapshot["entity_rows"]:
		var row: Dictionary = raw
		var entity_id := str(row["entity_id"])
		if _registry.apply_snapshot_row(row, sequence, int(snapshot["server_tick"])):
			visible_ids.append(entity_id)
			applied += 1
	_registry.set_proxy_visibility(visible_ids)
	_last_snapshot_sequence = sequence
	var payload_bytes := PROTOCOL.snapshot_bytes(snapshot)
	_telemetry["snapshots_received"] = int(_telemetry["snapshots_received"]) + 1
	_telemetry["snapshot_entities"] = int(_telemetry["snapshot_entities"]) + snapshot["entity_rows"].size()
	_telemetry["payload_bytes"] = int(_telemetry["payload_bytes"]) + maxi(0, payload_bytes)
	_telemetry["max_payload_bytes"] = maxi(int(_telemetry["max_payload_bytes"]), payload_bytes)
	for entity_id in visible_ids:
		var node := _registry.proxy(entity_id)
		if node != null:
			_telemetry["interpolation_max_samples"] = maxi(
				int(_telemetry["interpolation_max_samples"]), node.sample_count()
			)
	snapshot_applied.emit(sequence, applied)
	return true


func consume_semantic_event(event: Dictionary) -> bool:
	if _host_enabled or PROTOCOL.validate_semantic_event(event) != "":
		_telemetry["rejected_events"] = int(_telemetry["rejected_events"]) + 1
		return false
	var sequence := int(event["event_sequence"])
	var event_id := str(event["event_id"])
	if sequence <= _last_event_sequence or _seen_event_ids.has(event_id):
		_telemetry["rejected_events"] = int(_telemetry["rejected_events"]) + 1
		return false
	_last_event_sequence = sequence
	_seen_event_ids[event_id] = true
	_event_history.append(event.duplicate(true))
	_count_event(str(event["event_type"]))
	semantic_event_received.emit(event.duplicate(true))
	return true


func visible_entity_ids() -> Array[String]:
	var result: Array[String] = []
	for entity_id in _registry.entity_ids():
		var node := _registry.proxy(entity_id)
		if node != null and is_instance_valid(node) and node.aoi_visible:
			result.append(entity_id)
	result.sort()
	return result


func reset_session() -> void:
	for entity_id in _registry.entity_ids():
		var node := _registry.proxy(entity_id)
		if node != null and is_instance_valid(node):
			if node.is_inside_tree():
				node.queue_free()
			else:
				node.free()
	_registry.clear()
	_peer_to_player.clear()
	_sources.clear()
	_seen_event_ids.clear()
	_event_history.clear()
	_last_snapshot_sequence = -1
	_last_event_sequence = -1
	_server_tick = 0
	_snapshot_sequence = 0
	_lifecycle_sequence = 0
	_event_sequence = 0


func _physics_process(_delta: float) -> void:
	if not _host_enabled or _bridge == null or multiplayer.multiplayer_peer == null or not multiplayer.is_server():
		return
	if _server_tick >= PROTOCOL.MAX_SEQUENCE:
		return
	_server_tick += 1
	if _server_tick % PROTOCOL.SNAPSHOT_INTERVAL_TICKS != 0 or _peer_to_player.is_empty():
		return
	_refresh_all_sources()
	var next_snapshot := PROTOCOL.next_sequence(_snapshot_sequence)
	if next_snapshot <= 0:
		return
	_snapshot_sequence = next_snapshot
	var peer_ids := _peer_to_player.keys()
	peer_ids.sort()
	for raw_peer_id in peer_ids:
		var peer_id := int(raw_peer_id)
		var snapshot := _build_snapshot(peer_id, next_snapshot)
		if snapshot.is_empty():
			continue
		var payload_bytes := PROTOCOL.snapshot_bytes(snapshot)
		_bridge.send_snapshot(peer_id, snapshot)
		_telemetry["snapshots_sent"] = int(_telemetry["snapshots_sent"]) + 1
		_telemetry["snapshot_entities"] = int(_telemetry["snapshot_entities"]) + snapshot["entity_rows"].size()
		_telemetry["payload_bytes"] = int(_telemetry["payload_bytes"]) + payload_bytes
		_telemetry["max_payload_bytes"] = maxi(int(_telemetry["max_payload_bytes"]), payload_bytes)


func is_visible_to_peer(peer_id: int, entity_id: String, required_kind: String = "") -> bool:
	if not _host_enabled or not _registry.authority_owned(entity_id):
		return false
	_refresh_all_sources()
	var snapshot := _build_snapshot(peer_id, _snapshot_sequence)
	for raw in snapshot.get("entity_rows", []):
		var row: Dictionary = raw
		if row["entity_id"] == entity_id:
			return required_kind.is_empty() or row["entity_kind"] == required_kind
	return false


func _build_snapshot(peer_id: int, sequence: int) -> Dictionary:
	var own_id := str(_peer_to_player.get(peer_id, ""))
	if own_id.is_empty() or not _registry.has_entity(own_id):
		return {}
	var own_row := _registry.state_row(own_id)
	var sector_id := str(own_row.get("sector_id", ""))
	var center := Vector2(float(own_row.get("x", INF)), float(own_row.get("y", INF)))
	if not center.is_finite():
		return {}
	var visible := _registry.visible_ids(sector_id, center, PROTOCOL.AOI_RADIUS, own_id)
	if visible.size() > PROTOCOL.MAX_SNAPSHOT_ENTITIES:
		_telemetry["budget_rejections"] = int(_telemetry["budget_rejections"]) + 1
		return {}
	var rows: Array = []
	for entity_id in visible:
		rows.append(_registry.state_row(entity_id))
	var snapshot := PROTOCOL.make_snapshot(sequence, _server_tick, sector_id, rows)
	var reason := PROTOCOL.validate_snapshot(snapshot)
	if not reason.is_empty():
		if reason == PROTOCOL.REJECT_SNAPSHOT_BUDGET:
			_telemetry["budget_rejections"] = int(_telemetry["budget_rejections"]) + 1
		return {}
	return snapshot


func _refresh_all_sources() -> void:
	var ids := _sources.keys()
	ids.sort()
	for raw_id in ids:
		var entity_id := str(raw_id)
		if not _registry.has_entity(entity_id):
			continue
		var changes: Dictionary = {}
		var adapters: Array = _sources[entity_id]
		for adapter_value in adapters:
			var adapter: Dictionary = adapter_value
			var source := adapter["source"] as Object
			if source == null or not is_instance_valid(source):
				continue
			var method: StringName = adapter["method"]
			var args: Array = adapter["args"]
			var result: Variant = source.callv(method, args)
			if result is Dictionary:
				_merge_source_state(changes, result)
		if not changes.is_empty():
			_registry.update_authority_state(entity_id, changes)


func _merge_source_state(changes: Dictionary, source_state: Dictionary) -> void:
	for key in ["sector_id", "x", "y", "heading", "hull_ratio", "alive", "ai_state_id", "ai_intent_id"]:
		if source_state.has(key):
			changes[key] = source_state[key]
	if source_state.has("hull") and source_state.has("max_hull"):
		var maximum := float(source_state["max_hull"])
		if is_finite(maximum) and maximum > 0.0:
			changes["hull_ratio"] = clampf(float(source_state["hull"]) / maximum, 0.0, 1.0)
			changes["alive"] = float(source_state["hull"]) > 0.0


func _spawn_proxy(data: Variant) -> Node:
	if not data is Dictionary:
		return null
	var payload: Dictionary = data
	if PROTOCOL.validate_spawn_payload(payload) != "":
		return null
	var proxy := PROXY_SCRIPT.new() as NetworkEntityProxy
	if proxy == null or not proxy.configure_spawn(payload):
		if proxy != null:
			proxy.free()
		return null
	proxy.name = "Entity_%d_%d" % [absi(str(payload["entity_id"]).hash()), int(payload["generation"])]
	var entity_id := str(payload["entity_id"])
	var generation := int(payload["generation"])
	if _host_enabled:
		if not _registry.attach_proxy(entity_id, generation, proxy):
			proxy.free()
			return null
		proxy.set_aoi_visible(true)
	else:
		if not _registry.register_mirror(payload, proxy):
			proxy.free()
			return null
	return proxy


func _on_remote_spawned(node: Node) -> void:
	var proxy := node as NetworkEntityProxy
	if proxy != null:
		_telemetry["spawned"] = int(_telemetry["spawned"]) + 1
		entity_spawned.emit(proxy.entity_id, proxy.entity_kind)


func _on_remote_despawned(node: Node) -> void:
	var proxy := node as NetworkEntityProxy
	if proxy == null:
		return
	if _registry.remove(proxy.entity_id, proxy.generation):
		_telemetry["despawned"] = int(_telemetry["despawned"]) + 1
		entity_despawned.emit(proxy.entity_id)


func _on_replication_snapshot(snapshot: Dictionary) -> void:
	consume_snapshot(snapshot)


func _on_replication_event(event: Dictionary) -> void:
	consume_semantic_event(event)


func _count_event(event_type: String) -> void:
	if event_type in ["hull_damaged", "ship_sunk", "monster_defeated", "wreck_destroyed"]:
		_telemetry["combat_events"] = int(_telemetry["combat_events"]) + 1
	elif event_type in ["drop_created", "drop_claimed"]:
		_telemetry["loot_events"] = int(_telemetry["loot_events"]) + 1


func _on_hull_damaged(target_entity_id: String, attacker_entity_id: String, amount: float, remaining_hull: float, sequence_id: int) -> void:
	emit_semantic_event("hull_damaged", attacker_entity_id, target_entity_id, {
		"amount": amount,
		"remaining_hull": remaining_hull,
		"authority_sequence": sequence_id,
	})


func _on_ship_sunk(entity_id: String, sequence_id: int) -> void:
	emit_semantic_event("ship_sunk", "", entity_id, {"authority_sequence": sequence_id})


func _on_monster_defeated(entity_id: String, sequence_id: int) -> void:
	emit_semantic_event("monster_defeated", "", entity_id, {"authority_sequence": sequence_id})


func _on_wreck_destroyed(entity_id: String, sequence_id: int) -> void:
	emit_semantic_event("wreck_destroyed", "", entity_id, {"authority_sequence": sequence_id})


func _on_drop_created(drop: Dictionary) -> void:
	var drop_id := str(drop.get("drop_id", ""))
	emit_semantic_event("drop_created", drop_id, "", {
		"item_id": str(drop.get("item_id", "")),
		"quantity": int(drop.get("quantity", 0)),
		"sector_id": str(drop.get("sector_id", "")),
	})


func _on_drop_claimed(drop_id: String, item_id: String, quantity: int) -> void:
	emit_semantic_event("drop_claimed", drop_id, "", {"item_id": item_id, "quantity": quantity})
