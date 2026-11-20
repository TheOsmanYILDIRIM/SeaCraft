extends GutTest

const SCENARIO_SCRIPT := preload("res://tests/fixtures/vertical_slice/vertical_slice_scenario.gd")
const ITEM_ID := "item.vs03_salvage_scrap"


func _scenario() -> VerticalSliceScenario:
	var scenario := SCENARIO_SCRIPT.new() as VerticalSliceScenario
	add_child_autofree(scenario)
	return scenario


func _run() -> Dictionary:
	var scenario := _scenario()
	var result := scenario.run_full()
	assert_true(result["completed"], "VS-04 stopped at %s: %s" % [result["phase"], result["failure"]])
	return result


func test_scenario_id_is_stable_and_net03_reusable() -> void:
	assert_eq(VerticalSliceScenario.SCENARIO_ID, "scenario.vs04.offline_first_playable.v1")
	assert_true(SectorIds.valid(VerticalSliceScenario.SCENARIO_ID))


func test_full_offline_vertical_slice_completes() -> void:
	var result := _run()
	assert_true(result["offline"])
	assert_eq(result["phase"], "complete")


func test_deterministic_start_spawns_player_in_foundation_sector() -> void:
	var result := _run()
	assert_eq(result["sector_id"], FoundationSector.ID)
	assert_lt(Vector2(result["initial_player_x"], result["initial_player_y"]).distance_to(Vector2(-240.0, 0.0)), 0.001)


func test_player_movement_updates_real_sector_state() -> void:
	var result := _run()
	assert_gt(result["player_first_move_distance"], 1.0)
	assert_true(result["post_load_continued"])


func test_camera_follows_player_without_authority_mutation() -> void:
	var result := _run()
	assert_true(result["presentation_unchanged"])
	assert_lt(result["camera_error"], 0.001)


func test_npc_patrol_moves_through_real_ship_motor() -> void:
	var result := _run()
	assert_gt(result["npc_patrol_distance"], 1.0)


func test_real_ai_transition_trace_reaches_resume() -> void:
	var result := _run()
	var transitions: Array = result["transitions"]
	for state in [NpcBrain.State.PATROL, NpcBrain.State.ALERT, NpcBrain.State.RETREAT, NpcBrain.State.REPAIR, NpcBrain.State.RESUME]:
		assert_true(transitions.has(state), "missing AI state %s in %s" % [state, transitions])


func test_threat_and_perception_use_vs02_path() -> void:
	var result := _run()
	assert_gt(result["max_threat"], 0)
	assert_gt(result["perception_queries"], 0)
	assert_gt(result["decision_count"], 0)


func test_targeting_service_is_exercised_and_bounded() -> void:
	var result := _run()
	assert_gt(result["targeting_inspected"], 0)
	assert_lt(result["targeting_inspected"], 10)


func test_combat_range_reload_hit_and_damage_are_not_bypassed() -> void:
	var result := _run()
	assert_eq(result["range_rejection"], "out_of_range")
	assert_eq(result["reload_rejection"], "reloading")
	assert_gte(result["accepted_fires"], 5)


func test_ship_sunk_occurs_exactly_once() -> void:
	var result := _run()
	assert_eq(result["sunk_events"], 1)


func test_authoritative_loot_drop_occurs_exactly_once() -> void:
	var result := _run()
	assert_eq(result["drop_events"], 1)
	assert_true(SectorIds.valid(result["last_drop_id"]))


func test_authoritative_pickup_occurs_exactly_once() -> void:
	var result := _run()
	assert_eq(result["pickup_events"], 1)
	var inventory: Dictionary = result["inventory"]
	assert_gt(int(inventory.get(ITEM_ID, 0)), 0)


func test_checkpoint_is_saved_loaded_and_replayed() -> void:
	var result := _run()
	assert_true(result["checkpoint_replayed"])
	assert_gte(result["checkpoint_usec"], 0)


func test_reload_uses_fresh_runtime_objects() -> void:
	var result := _run()
	assert_true(result["fresh_runtime"])


func test_reload_blocks_duplicate_npc_death() -> void:
	var result := _run()
	assert_true(result["duplicate_sunk_blocked"])
	assert_eq(result["sunk_events"], 1)


func test_reload_blocks_duplicate_drop() -> void:
	var result := _run()
	assert_true(result["duplicate_drop_blocked"])
	assert_eq(result["drop_events"], 1)


func test_reload_blocks_duplicate_pickup_reward() -> void:
	var result := _run()
	assert_true(result["duplicate_pickup_blocked"])
	assert_eq(result["pickup_events"], 1)


func test_inventory_rng_and_ledgers_are_consistent_after_reload() -> void:
	var result := _run()
	var loot: Dictionary = result["loot"]
	var inventory: Dictionary = result["inventory"]
	assert_eq(loot["drops"].size(), 0)
	assert_eq(loot["claimed_ids"].size(), 1)
	assert_eq(loot["processed_events"].size(), 1)
	assert_gt(int(inventory.get(ITEM_ID, 0)), 0)
	var rng: Dictionary = result["rng"]
	var stream_states: Dictionary = rng["streams"]
	assert_eq(stream_states.size(), SeedStreams.STREAM_NAMES.size())


func test_post_load_flow_continues_with_real_movement() -> void:
	var result := _run()
	assert_true(result["post_load_continued"])
	assert_true(is_finite(float(result["post_load_x"])))
	assert_true(is_finite(float(result["post_load_y"])))


func test_same_seed_checkpoint_replay_is_deterministic() -> void:
	var first := _scenario()
	var first_digest := first.deterministic_digest()
	var second := _scenario()
	var second_digest := second.deterministic_digest()
	assert_eq(second_digest, first_digest)


func test_scenario_reset_clears_runtime_state() -> void:
	var scenario := _scenario()
	var result := scenario.run_full()
	assert_true(result["completed"], result["failure"])
	scenario.reset_scenario()
	assert_true(scenario.stale_state_empty())


func test_short_headless_soak_has_no_stale_or_rng_drift() -> void:
	var expected: Dictionary = {}
	for _run_index in 3:
		var scenario := _scenario()
		var digest := scenario.deterministic_digest()
		assert_true(digest["completed"])
		if expected.is_empty():
			expected = digest
		else:
			assert_eq(digest, expected)
		scenario.reset_scenario()
		assert_true(scenario.stale_state_empty())
	print("VS04_SOAK_OK scenario=%s runs=3" % VerticalSliceScenario.SCENARIO_ID)


func test_offline_network_separation_remains_clean() -> void:
	var forbidden := ["HTTPRequest", "HTTPClient", "WebSocketPeer", "ENetMultiplayerPeer", "MultiplayerAPI", "@rpc", "rpc("]
	for path in [
		"res://tests/fixtures/vertical_slice/vertical_slice_scenario.gd",
		"res://src/simulation/combat/combat_authority.gd",
		"res://src/simulation/ai/npc_brain.gd",
		"res://src/simulation/loot/loot_authority.gd",
		"res://src/simulation/movement/ship_motor.gd",
	]:
		var source := FileAccess.get_file_as_string(path)
		for token in forbidden:
			assert_false(source.contains(token), "%s contains %s" % [path, token])


func test_presentation_camera_has_no_authoritative_service_dependency() -> void:
	var source := FileAccess.get_file_as_string("res://src/presentation/camera/gameplay_camera.gd")
	for token in ["CombatAuthority", "LootAuthority", "SaveService", "SectorWorld", "NpcBrain"]:
		assert_false(source.contains(token), token)
	var result := _run()
	assert_true(result["presentation_unchanged"])
