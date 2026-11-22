extends GutTest

const P := preload("res://src/network/session_protocol.gd")
const D := preload("res://src/network/lan_discovery_protocol.gd")
const DC := preload("res://src/network/lan_discovery_client.gd")
const PG := preload("res://src/network/lan_permission_gate.gd")
const LEDGER := preload("res://src/network/host_transaction_ledger.gd")
const REGISTRY := preload("res://src/network/network_entity_registry.gd")


func _beacon(session_id: String = "session.r0123456789abcdef0123456789abcdef") -> Dictionary:
	return D.make_beacon(session_id, "CI Host", 24680, 1, 4)


func _spawn(entity_id: String, x: float = 1.0) -> Dictionary:
	return P.spawn_payload(entity_id, "npc", "sector.net04", "", 1, 1, 9, {
		"x": x, "y": 2.0, "heading": 0.0, "hull_ratio": 0.75, "alive": true,
	})


func test_net04_discovery_protocol_encode_decode_and_exact_shape() -> void:
	var beacon := _beacon()
	var packet := D.encode_beacon(beacon)
	assert_gt(packet.size(), 0)
	assert_lte(packet.size(), D.MAX_PACKET_BYTES)
	assert_eq(D.parse_packet(packet), beacon)
	assert_true(D.compatible(beacon))
	var extra := beacon.duplicate(true)
	extra["resume_token"] = "secret"
	assert_true(D.encode_beacon(extra).is_empty())
	assert_true(D.parse_packet("{}".to_utf8_buffer()).is_empty())
	var oversized := PackedByteArray()
	oversized.resize(D.MAX_PACKET_BYTES + 1)
	assert_true(D.parse_packet(oversized).is_empty())
	print("NET04_DISCOVERY_PROTOCOL_OK")


func test_net04_discovery_fuzz_fixed_seed_2000_packets() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261122
	for _index in 2000:
		var length := rng.randi_range(0, D.MAX_PACKET_BYTES + 64)
		var packet := PackedByteArray()
		packet.resize(length)
		for byte_index in length:
			packet[byte_index] = rng.randi_range(0, 255)
		assert_true(D.parse_packet(packet).is_empty())
	var duplicate := '{"magic":"SEACRAFT_LAN","magic":"SEACRAFT_LAN"}'.to_utf8_buffer()
	assert_true(D.parse_packet(duplicate).is_empty())
	var invalid_utf8 := PackedByteArray([0xff, 0xfe, 0xfd])
	assert_true(D.parse_packet(invalid_utf8).is_empty())
	print("NET04_DISCOVERY_FUZZ_OK count=2000 seed=20261122")


func test_net04_discovery_ttl_dedupe_and_rate_budget() -> void:
	var client := DC.new()
	var packet := D.encode_beacon(_beacon())
	assert_true(client.ingest_packet(packet, "127.0.0.1", 1000))
	assert_true(client.ingest_packet(packet, "127.0.0.1", 1100))
	assert_eq(client.sessions().size(), 1)
	assert_eq(client.expire(3600), 0)
	assert_eq(client.expire(3601), 1)
	assert_eq(client.sessions().size(), 0)
	var accepted := 0
	for index in 24:
		if client.ingest_packet(packet, "10.0.0.2", 5000 + index):
			accepted += 1
	assert_lte(accepted, D.SOURCE_PACKETS_PER_SECOND)
	print("NET04_DISCOVERY_TTL_OK ttl_ms=%d max_visible=%d" % [D.TTL_MS, D.MAX_VISIBLE_SESSIONS])


func test_net04_reconnect_token_handshake_contract() -> void:
	var token := Crypto.new().generate_random_bytes(16).hex_encode()
	assert_true(P.valid_resume_token(token))
	var hello := P.client_hello({"session_id": "session.r0123456789abcdef0123456789abcdef", "resume_token": token})
	assert_eq(P.validate_handshake(hello), "")
	assert_eq(P.validate_handshake(P.client_hello({"session_id": hello["session_id"], "resume_token": "short"})), "")
	var host_source := FileAccess.get_file_as_string("res://src/network/session_host.gd")
	assert_true(host_source.contains("PROTOCOL.REJECT_TOKEN_MALFORMED"))
	var packet_text := D.encode_beacon(_beacon()).get_string_from_utf8()
	assert_false(packet_text.contains(token))
	assert_false(packet_text.contains("resume_token"))
	print("NET04_RECONNECT_TOKEN_OK entropy_bits=128")


func test_net04_reconnect_sequence_and_rotation_contract() -> void:
	assert_eq(P.validate_sequence(41, 40), "")
	assert_eq(P.validate_sequence(40, 40), P.REJECT_REPLAY)
	var source := FileAccess.get_file_as_string("res://src/network/session_host.gd")
	assert_true(source.contains("RECONNECT_GRACE_MS := 30000"))
	assert_true(source.contains("_reservations"))
	assert_true(source.contains("_consumed_tokens"))
	assert_true(source.contains("_new_token()"))
	assert_true(source.contains("resume_last_sequence + 1"))
	print("NET04_RECONNECT_SEQUENCE_OK grace_ms=30000")


func test_net04_late_join_baseline_exact_current_truth() -> void:
	var registry := REGISTRY.new()
	assert_true(registry.register_authority(_spawn("npc.current", 77.0)))
	var payload := registry.spawn_payload_for("npc.current", 9)
	assert_eq(float(payload["x"]), 77.0)
	var chunk := P.make_baseline_chunk(
		"baseline.r0123456789abcdef0123456789abcdef",
		"session.r0123456789abcdef0123456789abcdef",
		"player.alpha", 30, 9, 7, 4, 0, 1, [payload]
	)
	assert_eq(P.validate_baseline_chunk(chunk), "")
	assert_eq(chunk["snapshot_sequence"], 9)
	assert_eq(chunk["event_sequence"], 7)
	assert_eq(chunk["resume_sequence"], 4)
	var missing := chunk.duplicate(true)
	missing.erase("event_sequence")
	assert_eq(P.validate_baseline_chunk(missing), P.REJECT_MALFORMED_BASELINE)
	print("NET04_LATE_JOIN_BASELINE_OK entities=1 watermarks=1")


func test_net04_transaction_idempotency_and_conflict() -> void:
	var ledger := LEDGER.new()
	var payload := {"drop_id": "drop.entity_net04.seq_1"}
	var fp := LEDGER.fingerprint(P.PICKUP_LOOT, payload)
	assert_eq(ledger.inspect("player.alpha", "txn.net04.primary", P.PICKUP_LOOT, fp)["status"], LEDGER.STATUS_NEW)
	var result := {"accepted": true, "drop_id": payload["drop_id"], "item_id": "item.scrap", "quantity": 2}
	assert_true(ledger.commit("player.alpha", "txn.net04.primary", P.PICKUP_LOOT, fp, result))
	var cached := ledger.inspect("player.alpha", "txn.net04.primary", P.PICKUP_LOOT, fp)
	assert_eq(cached["status"], LEDGER.STATUS_CACHED)
	assert_eq(cached["result"], result)
	var other := LEDGER.fingerprint(P.PICKUP_LOOT, {"drop_id": "drop.other"})
	assert_eq(ledger.inspect("player.alpha", "txn.net04.primary", P.PICKUP_LOOT, other)["status"], LEDGER.STATUS_CONFLICT)
	assert_eq(ledger.size(), 1)
	print("NET04_TRANSACTION_IDEMPOTENCY_OK cached=1 conflict=1")


func test_net04_transaction_persistence_round_trip() -> void:
	var ledger := LEDGER.new()
	var payload := {"drop_id": "drop.entity_net04.seq_2"}
	var fp := LEDGER.fingerprint(P.PICKUP_LOOT, payload)
	var result := {"accepted": true, "drop_id": payload["drop_id"], "item_id": "item.scrap", "quantity": 1}
	assert_true(ledger.commit("player.alpha", "txn.net04.persist", P.PICKUP_LOOT, fp, result))
	var saved := ledger.snapshot_state()
	var restored := LEDGER.new()
	assert_true(restored.restore_state(saved))
	assert_eq(restored.snapshot_state(), saved)
	assert_eq(restored.inspect("player.alpha", "txn.net04.persist", P.PICKUP_LOOT, fp)["status"], LEDGER.STATUS_CACHED)
	print("NET04_TRANSACTION_PERSISTENCE_OK entries=1")


func test_net04_permission_fallback_and_runtime_api() -> void:
	assert_eq(PG.evaluate("Linux", PackedStringArray()), PG.RESULT_ALLOWED)
	assert_eq(PG.evaluate("Android", PackedStringArray()), PG.RESULT_REQUEST_REQUIRED)
	assert_eq(PG.evaluate("Android", PackedStringArray([PG.PERMISSION])), PG.RESULT_ALLOWED)
	var source := FileAccess.get_file_as_string("res://src/network/lan_permission_gate.gd")
	assert_true(source.contains("OS.request_permission(PERMISSION)"))
	assert_true(source.contains("OS.get_granted_permissions()"))
	print("NET04_PERMISSION_FALLBACK_OK permission=%s" % PG.PERMISSION)


func test_net04_offline_boot_and_manual_ipv4_remain_default() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var bootstrap := FileAccess.get_file_as_string("res://src/presentation/bootstrap.gd")
	assert_false(project.contains("[autoload]"))
	for forbidden in ["LanDiscoveryHost", "LanDiscoveryClient", "PacketPeerUDP", "request_from_user_action"]:
		assert_false(bootstrap.contains(forbidden))
	assert_true(P.valid_ipv4("127.0.0.1"))
	assert_false(P.valid_ipv4("localhost"))
	print("NET04_OFFLINE_BOOT_OK manual_ipv4=1 discovery_autostart=0")


func test_net04_static_security_and_network_boundary() -> void:
	var discovery := FileAccess.get_file_as_string("res://src/network/lan_discovery_protocol.gd")
	assert_false(discovery.contains('"resume_token":'))
	assert_false(discovery.contains("FileAccess"))
	for path in ["res://src/simulation/loot/loot_authority.gd", "res://src/persistence/save_service.gd", "res://src/data/contracts/data_contract_versions.gd"]:
		var source := FileAccess.get_file_as_string(path)
		assert_false(source.contains("PacketPeerUDP"))
		assert_false(source.contains("LanDiscovery"))
	var host := FileAccess.get_file_as_string("res://src/network/session_host.gd")
	assert_false(host.contains('print("resume_token'))
	print("NET04_NETWORK_BOUNDARY_OK")


func test_net04_protocol_mismatch_stays_deterministic_after_version_bump() -> void:
	assert_eq(P.PROTOCOL_VERSION, 3)
	assert_eq(P.validate_handshake(P.client_hello({"protocol_version": P.PROTOCOL_VERSION - 1})), P.REJECT_PROTOCOL_MISMATCH)
	var pickup := P.make_envelope(8, P.PICKUP_LOOT, {"drop_id": "drop.entity_net04.seq_8", "transaction_id": "txn.net04.t8"})
	assert_eq(P.validate_envelope(pickup), "")
	print("NET04_PROTOCOL_MISMATCH_OK version=3")
