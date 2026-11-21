extends GutTest

const PROTOCOL := preload("res://src/network/session_protocol.gd")
const HOST := preload("res://src/network/session_host.gd")
const CLIENT := preload("res://src/network/session_client.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")
const MOTOR := preload("res://src/simulation/movement/ship_motor.gd")
const DATA_VERSIONS := preload("res://src/data/contracts/data_contract_versions.gd")
const CONTENT_MANIFEST := preload("res://src/data/registry/content_manifest.gd")


func test_net01_protocol_stamp_channel_policy_and_ipv4_contract() -> void:
	var stamp := PROTOCOL.compatibility_stamp()
	var versions := DATA_VERSIONS.compatibility_stamp()
	var manifest := CONTENT_MANIFEST.metadata()
	assert_eq(stamp.size(), 7)
	assert_eq(stamp["protocol_version"], PROTOCOL.PROTOCOL_VERSION)
	assert_eq(stamp["schema_version"], versions["schema_version"])
	assert_eq(stamp["content_version"], versions["content_version"])
	assert_eq(stamp["rng_stream_version"], versions["rng_stream_version"])
	assert_eq(stamp["content_manifest_algorithm"], manifest["algorithm"])
	assert_eq(stamp["content_hash"], manifest["hash"])
	assert_eq(stamp["manifest_entry_count"], manifest["entry_count"])
	assert_eq(PROTOCOL.channel_policy()["control"]["mode"], "reliable")
	assert_eq(PROTOCOL.channel_policy()["gameplay_intent"]["mode"], "reliable")
	assert_eq(PROTOCOL.channel_policy()["snapshot_reserved"]["mode"], "unreliable_ordered")
	assert_true(PROTOCOL.valid_ipv4("127.0.0.1"))
	assert_false(PROTOCOL.valid_ipv4("localhost"))
	assert_false(PROTOCOL.valid_ipv4("01.2.3.4"))
	assert_true(PROTOCOL.valid_port(24680))
	print("NET01_PROTOCOL_CONTRACT_OK")


func test_net01_handshake_exact_shape_matches_canonical_sources() -> void:
	var hello := PROTOCOL.client_hello()
	assert_eq(PROTOCOL.validate_handshake(hello), "")
	for forbidden in PROTOCOL.FORBIDDEN_IDENTITY_FIELDS:
		assert_false(hello.has(forbidden))
	var extra := hello.duplicate(true)
	extra["player_id"] = "spoof"
	assert_eq(PROTOCOL.validate_handshake(extra), PROTOCOL.REJECT_MALFORMED_HANDSHAKE)
	print("NET01_HANDSHAKE_OK")


func test_net01_protocol_mismatch_is_deterministic() -> void:
	var hello := PROTOCOL.client_hello({"protocol_version": PROTOCOL.PROTOCOL_VERSION + 1})
	assert_eq(PROTOCOL.validate_handshake(hello), PROTOCOL.REJECT_PROTOCOL_MISMATCH)
	print("NET01_PROTOCOL_MISMATCH_OK")


func test_net01_content_and_schema_mismatches_are_deterministic() -> void:
	var wrong_schema := PROTOCOL.client_hello({"schema_version": int(DATA_VERSIONS.SCHEMA_VERSION) + 1})
	assert_eq(PROTOCOL.validate_handshake(wrong_schema), PROTOCOL.REJECT_SCHEMA_MISMATCH)
	var wrong_version := PROTOCOL.client_hello({"content_version": "wrong-content"})
	assert_eq(PROTOCOL.validate_handshake(wrong_version), PROTOCOL.REJECT_CONTENT_VERSION_MISMATCH)
	var wrong_hash := PROTOCOL.client_hello({"content_hash": "0".repeat(64)})
	assert_eq(PROTOCOL.validate_handshake(wrong_hash), PROTOCOL.REJECT_CONTENT_HASH_MISMATCH)
	var wrong_algorithm := PROTOCOL.client_hello({"content_manifest_algorithm": "not-sha256"})
	assert_eq(PROTOCOL.validate_handshake(wrong_algorithm), PROTOCOL.REJECT_CONTENT_HASH_MISMATCH)
	var wrong_count := PROTOCOL.client_hello({"manifest_entry_count": int(CONTENT_MANIFEST.current_entry_count()) + 1})
	assert_eq(PROTOCOL.validate_handshake(wrong_count), PROTOCOL.REJECT_CONTENT_HASH_MISMATCH)
	print("NET01_CONTENT_MISMATCH_OK")


func test_net01_envelope_allowlist_and_payload_bounds_reject_malformed_values() -> void:
	var move := PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 12.5, "world_y": -7.0})
	assert_eq(PROTOCOL.validate_envelope(move), "")
	assert_eq(PROTOCOL.validate_envelope(PROTOCOL.make_envelope(0, COMMANDS.CAMERA_PAN, {})), PROTOCOL.REJECT_UNSUPPORTED_INTENT)
	assert_eq(PROTOCOL.validate_envelope(PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": INF, "world_y": 0.0})), PROTOCOL.REJECT_MALFORMED_PAYLOAD)
	assert_eq(PROTOCOL.validate_envelope(PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 1.0, "world_y": 2.0, "note": "x".repeat(PROTOCOL.MAX_STRING_LENGTH + 1)})), PROTOCOL.REJECT_MALFORMED_PAYLOAD)
	assert_eq(PROTOCOL.validate_envelope(PROTOCOL.make_envelope(0, COMMANDS.TARGET_CYCLE, {"direction": 0})), PROTOCOL.REJECT_MALFORMED_PAYLOAD)
	assert_eq(PROTOCOL.validate_envelope(PROTOCOL.make_envelope(0, COMMANDS.CANCEL, {"extra": true})), PROTOCOL.REJECT_MALFORMED_PAYLOAD)


func test_net01_peer_mapping_slot_selection_is_stable_and_host_owned() -> void:
	var ids: Array[String] = ["player.charlie", "player.alpha", "player.bravo"]
	var mapped: Array[String] = ["player.alpha"]
	assert_eq(PROTOCOL.next_available_player_id(ids, mapped), "player.bravo")
	mapped.append("player.bravo")
	assert_eq(PROTOCOL.next_available_player_id(ids, mapped), "player.charlie")
	mapped.append("player.charlie")
	assert_eq(PROTOCOL.next_available_player_id(ids, mapped), "")
	var source := FileAccess.get_file_as_string("res://src/network/session_host.gd")
	assert_true(source.contains("multiplayer.get_remote_sender_id()") == false)
	var bridge_source := FileAccess.get_file_as_string("res://src/network/session_rpc_bridge.gd")
	assert_true(bridge_source.contains("multiplayer.get_remote_sender_id()"))
	print("NET01_PEER_MAPPING_OK")


func test_net01_valid_move_uses_existing_gameplay_command_and_ship_motor_authority() -> void:
	var envelope := PROTOCOL.make_envelope(0, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 321.0, "world_y": -45.0})
	var command := PROTOCOL.to_gameplay_command(envelope)
	assert_eq(command["domain"], COMMANDS.DOMAIN_GAMEPLAY)
	assert_eq(command["type"], COMMANDS.MOVE_TO_WORLD_POSITION)
	var motor := MOTOR.new()
	motor.authority_enabled = true
	assert_true(motor.apply_authoritative_command(command))
	assert_eq(motor.target_world_position(), Vector2(321.0, -45.0))
	motor.authority_enabled = false
	assert_false(motor.apply_authoritative_command(COMMANDS.move_to_world_position(Vector2(999.0, 999.0))))
	assert_eq(motor.target_world_position(), Vector2(321.0, -45.0))
	motor.free()
	print("NET01_INTENT_AUTHORITY_OK")


func test_net01_spoof_identity_fields_are_rejected_recursively() -> void:
	var top_level := PROTOCOL.make_envelope(1, COMMANDS.CANCEL, {})
	top_level["player_id"] = "player.other"
	assert_eq(PROTOCOL.validate_envelope(top_level), PROTOCOL.REJECT_FORBIDDEN_IDENTITY)
	var nested := PROTOCOL.make_envelope(1, COMMANDS.MOVE_TO_WORLD_POSITION, {"world_x": 1.0, "world_y": 2.0, "owner_id": "other"})
	assert_eq(PROTOCOL.validate_envelope(nested), PROTOCOL.REJECT_FORBIDDEN_IDENTITY)
	print("NET01_SPOOF_REJECTION_OK")


func test_net01_sequence_replay_negative_fraction_and_bounds_are_rejected() -> void:
	assert_eq(PROTOCOL.validate_sequence(0, -1), "")
	assert_eq(PROTOCOL.validate_sequence(0, 0), PROTOCOL.REJECT_REPLAY)
	assert_eq(PROTOCOL.validate_sequence(4, 5), PROTOCOL.REJECT_REPLAY)
	assert_eq(PROTOCOL.validate_sequence(-1, -1), PROTOCOL.REJECT_SEQUENCE)
	assert_eq(PROTOCOL.validate_sequence(1.0, -1), PROTOCOL.REJECT_SEQUENCE)
	assert_eq(PROTOCOL.validate_sequence(PROTOCOL.MAX_SEQUENCE + 1, -1), PROTOCOL.REJECT_SEQUENCE)
	print("NET01_REPLAY_REJECTION_OK")


func test_net01_offline_boot_and_network_boundary_remain_explicit() -> void:
	var project := FileAccess.get_file_as_string("res://project.godot")
	var bootstrap := FileAccess.get_file_as_string("res://src/presentation/bootstrap.gd")
	assert_false(project.contains("[autoload]"))
	for forbidden in ["ENetMultiplayerPeer", "MultiplayerAPI", "SceneMultiplayer", "@rpc", "rpc(", "multiplayer_peer"]:
		assert_false(bootstrap.contains(forbidden))
	for path in [
		"res://src/simulation/movement/ship_motor.gd",
		"res://src/simulation/commands/gameplay_command.gd",
		"res://src/data/contracts/data_contract_versions.gd",
		"res://src/persistence/save_service.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for forbidden in ["ENetMultiplayerPeer", "MultiplayerAPI", "SceneMultiplayer", "@rpc", "rpc(", "multiplayer_peer"]:
			assert_false(source.contains(forbidden), "%s must remain network-free" % path)
	var export_presets := FileAccess.get_file_as_string("res://export_presets.cfg")
	assert_true(export_presets.contains("permissions/internet=true"))
	var host_source := FileAccess.get_file_as_string("res://src/network/session_host.gd")
	assert_true(host_source.contains("ENetMultiplayerPeer"))
	assert_true(FileAccess.file_exists("res://src/network/session_client.gd"))
	print("NET01_OFFLINE_BOOT_OK")
