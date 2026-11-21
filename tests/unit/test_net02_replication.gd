extends GutTest

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const REGISTRY := preload("res://src/network/network_entity_registry.gd")
const PROXY := preload("res://src/network/network_entity_proxy.gd")
const REPLICATION := preload("res://src/network/network_replication_peer.gd")


func test_net02_entity_registry_stable_id_generation_and_idempotency() -> void:
	var registry := REGISTRY.new()
	var payload := _spawn("npc.alpha", "npc", "sector.net02", 0.0, 0.0, 1)
	assert_true(registry.register_authority(payload))
	assert_false(registry.register_authority(payload))
	assert_eq(registry.active_count(), 1)
	assert_eq(registry.generation("npc.alpha"), 1)
	assert_eq(registry.next_generation("npc.alpha"), 2)
	assert_false(registry.remove("npc.alpha", 2))
	assert_true(registry.remove("npc.alpha", 1))
	assert_eq(registry.active_count(), 0)
	print("NET02_ENTITY_REGISTRY_OK")


func test_net02_spawn_dto_is_primitive_bounded_and_host_only() -> void:
	var payload := _spawn("loot.alpha", "loot", "sector.net02", 3.0, 4.0, 1)
	assert_eq(PROTOCOL.validate_spawn_payload(payload), "")
	var unknown := payload.duplicate(true)
	unknown["entity_kind"] = "unknown"
	assert_eq(PROTOCOL.validate_spawn_payload(unknown), PROTOCOL.REJECT_UNKNOWN_ENTITY_KIND)
	var object_payload := payload.duplicate(true)
	var forbidden := Node.new()
	object_payload["definition_id"] = forbidden
	assert_eq(PROTOCOL.validate_spawn_payload(object_payload), PROTOCOL.REJECT_MALFORMED_SPAWN)
	forbidden.free()
	var peer := REPLICATION.new()
	assert_false(peer.spawn_authoritative("npc.client", "npc", "sector.net02", _state(0.0, 0.0)))
	peer.free()
	var source := FileAccess.get_file_as_string("res://src/network/network_replication_peer.gd")
	assert_true(source.contains("MultiplayerSpawner.new()"))
	assert_true(source.contains("spawn_function"))
	assert_true(source.contains("spawn_path"))
	print("NET02_HOST_SPAWN_OK")


func test_net02_snapshot_order_rejects_stale_and_duplicate_sequences() -> void:
	var peer := REPLICATION.new()
	var registry := peer.registry()
	var proxy := PROXY.new()
	var payload := _spawn("npc.shared", "npc", "sector.net02", 1.0, 2.0, 1)
	assert_true(proxy.configure_spawn(payload))
	assert_true(registry.register_mirror(payload, proxy))
	var sequences := [10, 12, 11, 12, 13]
	var expected := [true, true, false, false, true]
	for index in sequences.size():
		var sequence := int(sequences[index])
		var row := _row("npc.shared", "npc", "sector.net02", float(sequence), 2.0, 1.0, true)
		var accepted := peer.consume_snapshot(PROTOCOL.make_snapshot(sequence, sequence * 3, "sector.net02", [row]))
		assert_eq(accepted, bool(expected[index]))
	assert_eq(peer.last_snapshot_sequence(), 13)
	assert_eq(proxy.authoritative_state()["sequence"], 13)
	assert_eq(proxy.authoritative_state()["x"], 13.0)
	assert_eq(peer.telemetry()["stale_snapshots"], 2)
	peer.free()
	proxy.free()
	print("NET02_SNAPSHOT_ORDER_OK")


func test_net02_interpolation_buffer_is_bounded_to_four_samples() -> void:
	var proxy := PROXY.new()
	var payload := _spawn("player.alpha", "player", "sector.net02", 0.0, 0.0, 1)
	assert_true(proxy.configure_spawn(payload))
	for sequence in range(1, 8):
		assert_true(proxy.apply_snapshot(
			_row("player.alpha", "player", "sector.net02", float(sequence), 0.0, 1.0, true),
			sequence, sequence * 3
		))
	assert_eq(proxy.sample_count(), PROTOCOL.MAX_INTERPOLATION_SAMPLES)
	assert_eq(proxy.authoritative_state()["sequence"], 7)
	assert_eq(proxy.interpolated_position(0.5), Vector2(6.5, 0.0))
	proxy.free()
	print("NET02_INTERPOLATION_OK")


func test_net02_aoi_visibility_uses_authoritative_sector_and_radius() -> void:
	var registry := REGISTRY.new()
	assert_true(registry.register_authority(_spawn("player.alpha", "player", "sector.net02", 0.0, 0.0, 1)))
	assert_true(registry.register_authority(_spawn("npc.near", "npc", "sector.net02", 100.0, 0.0, 1)))
	assert_true(registry.register_authority(_spawn("monster.far", "monster", "sector.net02", 900.0, 0.0, 1)))
	assert_true(registry.register_authority(_spawn("loot.other", "loot", "sector.other", 0.0, 0.0, 1)))
	var visible := registry.visible_ids("sector.net02", Vector2.ZERO, PROTOCOL.AOI_RADIUS, "player.alpha")
	assert_true(visible.has("player.alpha"))
	assert_true(visible.has("npc.near"))
	assert_false(visible.has("monster.far"))
	assert_false(visible.has("loot.other"))
	print("NET02_AOI_OK")


func test_net02_combat_events_are_reliable_contract_and_idempotent() -> void:
	var peer := REPLICATION.new()
	var event := PROTOCOL.make_semantic_event(1, "event.combat.s1", "hull_damaged", "npc.alpha", "player.alpha", {
		"amount": 10.0, "remaining_hull": 90.0,
	})
	assert_eq(PROTOCOL.validate_semantic_event(event), "")
	assert_true(peer.consume_semantic_event(event))
	assert_false(peer.consume_semantic_event(event))
	assert_eq(peer.event_history().size(), 1)
	var bridge := FileAccess.get_file_as_string("res://src/network/session_rpc_bridge.gd")
	assert_true(bridge.contains('@rpc("authority", "call_remote", "reliable", 1)'))
	peer.free()
	print("NET02_COMBAT_EVENT_OK")


func test_net02_loot_events_are_idempotent_and_primitive_safe() -> void:
	var peer := REPLICATION.new()
	var event := PROTOCOL.make_semantic_event(1, "event.loot.s1", "drop_created", "drop.alpha", "", {
		"item_id": "item.scrap", "quantity": 2, "sector_id": "sector.net02",
	})
	assert_eq(PROTOCOL.validate_semantic_event(event), "")
	assert_true(peer.consume_semantic_event(event))
	assert_false(peer.consume_semantic_event(event))
	assert_eq(peer.event_types(), ["drop_created"])
	peer.free()
	print("NET02_LOOT_EVENT_OK")


func test_net02_client_outcome_mutations_have_no_authority_rpc() -> void:
	for mutation in ["spawn_entity", "despawn_entity", "set_hull", "set_position", "set_npc_state", "create_loot", "claim_result"]:
		var envelope := PROTOCOL.make_envelope(0, mutation, {})
		assert_eq(PROTOCOL.validate_envelope(envelope), PROTOCOL.REJECT_UNSUPPORTED_INTENT)
	var bridge := FileAccess.get_file_as_string("res://src/network/session_rpc_bridge.gd")
	for forbidden in ["_rpc_spawn_entity", "_rpc_set_hull", "_rpc_set_position", "_rpc_create_loot"]:
		assert_false(bridge.contains(forbidden))
	assert_eq(bridge.count('@rpc("any_peer"'), 2)
	print("NET02_CLIENT_MUTATION_REJECT_OK")


func test_net02_snapshot_payload_and_entity_budget_are_explicit() -> void:
	var rows: Array = []
	for index in range(PROTOCOL.MAX_SNAPSHOT_ENTITIES + 1):
		rows.append(_row("npc.budget_%d" % index, "npc", "sector.net02", float(index), 0.0, 1.0, true))
	var over_entities := PROTOCOL.make_snapshot(1, 3, "sector.net02", rows)
	assert_eq(PROTOCOL.validate_snapshot(over_entities), PROTOCOL.REJECT_SNAPSHOT_BUDGET)
	var small := PROTOCOL.make_snapshot(2, 6, "sector.net02", [
		_row("npc.one", "npc", "sector.net02", 1.0, 2.0, 1.0, true),
	])
	assert_eq(PROTOCOL.validate_snapshot(small), "")
	assert_true(PROTOCOL.snapshot_bytes(small) > 0)
	assert_true(PROTOCOL.snapshot_bytes(small) <= PROTOCOL.MAX_SNAPSHOT_BYTES)
	assert_eq(PROTOCOL.SNAPSHOT_INTERVAL_TICKS, 3)
	print("NET02_BUDGET_OK")


func test_net02_snapshot_rows_are_deterministic_and_object_free() -> void:
	var unsorted := [
		_row("npc.zulu", "npc", "sector.net02", 1.0, 0.0, 1.0, true),
		_row("npc.alpha", "npc", "sector.net02", 2.0, 0.0, 1.0, true),
	]
	assert_eq(PROTOCOL.validate_snapshot(PROTOCOL.make_snapshot(1, 3, "sector.net02", unsorted)), PROTOCOL.REJECT_MALFORMED_SNAPSHOT)
	var forbidden := Node.new()
	var event := PROTOCOL.make_semantic_event(1, "event.bad.s1", "drop_created", "drop.alpha", "", {"node": forbidden})
	assert_eq(PROTOCOL.validate_semantic_event(event), PROTOCOL.REJECT_MALFORMED_EVENT)
	forbidden.free()


func test_net02_offline_network_boundary_and_snapshot_channel_are_explicit() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	assert_false(project.contains("[autoload]"))
	var bridge := FileAccess.get_file_as_string("res://src/network/session_rpc_bridge.gd")
	assert_true(bridge.contains('@rpc("authority", "call_remote", "unreliable_ordered", 2)'))
	var replication := FileAccess.get_file_as_string("res://src/network/network_replication_peer.gd")
	assert_true(replication.contains("MultiplayerSpawner"))
	assert_false(replication.contains("MultiplayerSynchronizer"))
	for path in [
		"res://src/simulation/movement/ship_motor.gd",
		"res://src/simulation/combat/combat_authority.gd",
		"res://src/simulation/loot/loot_authority.gd",
		"res://src/persistence/save_service.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["MultiplayerSpawner", "MultiplayerSynchronizer", "@rpc", "rpc(", "multiplayer_peer"]:
			assert_false(source.contains(forbidden), "%s must remain network-free" % path)


func _spawn(entity_id: String, kind: String, sector_id: String, x: float, y: float, generation: int) -> Dictionary:
	return PROTOCOL.spawn_payload(entity_id, kind, sector_id, "", generation, generation, 0, _state(x, y))


func _state(x: float, y: float, hull_ratio: float = 1.0, alive: bool = true) -> Dictionary:
	return {"x": x, "y": y, "heading": 0.0, "hull_ratio": hull_ratio, "alive": alive}


func _row(entity_id: String, kind: String, sector_id: String, x: float, y: float, hull_ratio: float, alive: bool) -> Dictionary:
	return {
		"entity_id": entity_id,
		"entity_kind": kind,
		"sector_id": sector_id,
		"x": x,
		"y": y,
		"heading": 0.0,
		"hull_ratio": hull_ratio,
		"alive": alive,
	}
