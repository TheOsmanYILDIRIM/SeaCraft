extends GutTest

const PLAYER := "entity.player"
const SCRAP := "item.scrap"
const RANK_0 := "rank.deckhand"
const RANK_1 := "rank.officer"
const RANK_2 := "rank.captain"
const SKILL_ROOT := "skill.rigging"
const SKILL_CHILD := "skill.command"
const GATE_LICENSE := "gate.license.officer"
const CHALLENGE := "challenge.local.sail"
const VERSION_1 := "version.prg03.v1"
const VERSION_2 := "version.prg03.v2"

func _item(id: String, limit: int = 20) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.stable_id = id
	definition.display_name = id
	definition.item_category = "material"
	definition.stack_limit = limit
	return definition

func _rank(id: String, threshold: int, points: int, modifier_value: float = 0.0) -> ProgressionRankDefinition:
	var definition := ProgressionRankDefinition.new()
	definition.stable_id = id
	definition.xp_threshold = threshold
	definition.skill_point_grant = points
	definition.label = id
	if modifier_value != 0.0:
		definition.modifiers = [{
			"source_id": "modifier." + id,
			"stat": "speed",
			"operation": "flat",
			"value": modifier_value,
			"priority": 0,
		}]
	return definition

func _skill(id: String, tier: int, cost: int, max_rank: int, prerequisites: PackedStringArray = PackedStringArray(), gate_id: String = "", modifier_value: float = 0.0) -> ProgressionSkillDefinition:
	var definition := ProgressionSkillDefinition.new()
	definition.stable_id = id
	definition.tier = tier
	definition.point_cost = cost
	definition.max_rank = max_rank
	definition.prerequisite_ids = prerequisites
	definition.gate_id = gate_id
	if modifier_value != 0.0:
		definition.modifiers = [{
			"source_id": "modifier." + id,
			"stat": "speed",
			"operation": "flat",
			"value": modifier_value,
			"priority": tier,
		}]
	return definition

func _gate(id: String, prerequisites: PackedStringArray = PackedStringArray(), required_rank: String = "", xp_reward: int = 0) -> ProgressionGateDefinition:
	var definition := ProgressionGateDefinition.new()
	definition.stable_id = id
	definition.gate_type = "license"
	definition.prerequisite_gate_ids = prerequisites
	definition.required_rank_id = required_rank
	definition.xp_reward = xp_reward
	return definition

func _challenge(version_key: String = VERSION_1, recurrence: String = "version") -> LocalChallengeDefinition:
	var definition := LocalChallengeDefinition.new()
	definition.stable_id = CHALLENGE
	definition.version_key = version_key
	definition.objective_type = "counter"
	definition.target_value = 2
	definition.rewards = [{"item_id": SCRAP, "quantity": 1}]
	definition.xp_reward = 50
	definition.recurrence_policy = recurrence
	return definition

func _state(scrap_limit: int = 20) -> InventoryState:
	var inventory := InventoryState.new()
	assert_true(inventory.bind_owner(PLAYER, 8, 100.0))
	assert_true(inventory.register_item_definition(_item(SCRAP, scrap_limit)))
	assert_true(inventory.configure_prg02(SeedStreams.new(20261122)))
	assert_true(inventory.configure_prg03())
	return inventory

func _register_standard(inventory: InventoryState, challenge_version: String = VERSION_1) -> void:
	assert_true(inventory.register_rank_definition(_rank(RANK_0, 0, 0)))
	assert_true(inventory.register_rank_definition(_rank(RANK_1, 100, 2, 1.0)))
	assert_true(inventory.register_rank_definition(_rank(RANK_2, 250, 2)))
	assert_true(inventory.register_gate_definition(_gate(GATE_LICENSE, PackedStringArray(), RANK_1, 10)))
	assert_true(inventory.register_skill_definition(_skill(SKILL_ROOT, 1, 1, 2, PackedStringArray(), "", 2.0)))
	assert_true(inventory.register_skill_definition(_skill(SKILL_CHILD, 2, 2, 1, PackedStringArray([SKILL_ROOT]), GATE_LICENSE, 3.0)))
	assert_true(inventory.register_challenge_definition(_challenge(challenge_version)))
	assert_eq(inventory.validate_prg03_catalog(), "")

func test_prg03_definition_schema_dag_cycle_missing_refs_and_thresholds() -> void:
	for definition_type in ["progression_rank", "progression_skill", "progression_gate", "local_challenge"]:
		assert_true(DefinitionRegistry.VALID_DEFINITION_TYPES.has(definition_type))
	var invalid_rank := _rank("rank.invalid", -1, 0)
	assert_false(invalid_rank.valid())
	var duplicate_threshold := _state()
	assert_true(duplicate_threshold.register_rank_definition(_rank("rank.a", 0, 0)))
	assert_true(duplicate_threshold.register_rank_definition(_rank("rank.b", 0, 1)))
	assert_eq(duplicate_threshold.validate_prg03_catalog(), "duplicate_rank_threshold")
	var missing := _state()
	assert_true(missing.register_skill_definition(_skill("skill.missing.child", 2, 1, 1, PackedStringArray(["skill.missing.root"]))))
	assert_eq(missing.validate_prg03_catalog(), "missing_skill_prerequisite")
	var cycle := _state()
	assert_true(cycle.register_skill_definition(_skill("skill.cycle.a", 2, 1, 1, PackedStringArray(["skill.cycle.b"]))))
	assert_true(cycle.register_skill_definition(_skill("skill.cycle.b", 1, 1, 1, PackedStringArray(["skill.cycle.a"]))))
	assert_eq(cycle.validate_prg03_catalog(), "skill_cycle")
	print("PRG03_SKILL_DAG_OK")
	print("PRG03_RANK_VALIDATION_OK")

func test_prg03_xp_positive_boundaries_duplicate_conflict_and_overflow() -> void:
	var inventory := _state()
	_register_standard(inventory)
	var rejected := inventory.grant_xp_authoritative(PLAYER, "event.xp.zero", "combat", 0)
	assert_false(rejected["accepted"])
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 0)
	var first := inventory.grant_xp_authoritative(PLAYER, "event.xp.first", "combat", 100)
	assert_true(first["accepted"])
	assert_eq(first["total_xp"], 100)
	var duplicate := inventory.grant_xp_authoritative(PLAYER, "event.xp.first", "combat", 100)
	assert_true(duplicate["accepted"])
	assert_true(duplicate["duplicate"])
	assert_eq(duplicate["total_xp"], 100)
	var conflict := inventory.grant_xp_authoritative(PLAYER, "event.xp.first", "combat", 101)
	assert_false(conflict["accepted"])
	assert_eq(conflict["reason"], "xp_event_conflict")
	var maxed := _state()
	var max_result := maxed.grant_xp_authoritative(PLAYER, "event.xp.max", "fixture", Prg03ProgressionState.MAX_XP)
	assert_true(max_result["accepted"])
	var overflow := maxed.grant_xp_authoritative(PLAYER, "event.xp.overflow", "fixture", 1)
	assert_false(overflow["accepted"])
	assert_eq(overflow["reason"], "xp_overflow")
	print("PRG03_XP_LEDGER_OK")
	print("PRG03_XP_OVERFLOW_OK")

func test_prg03_rank_multi_level_and_derived_one_time_points() -> void:
	var inventory := _state()
	_register_standard(inventory)
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.multilevel", "fixture", 300)["accepted"])
	var view := inventory.progression_view(PLAYER)
	assert_eq(view["rank_id"], RANK_2)
	assert_eq(view["available_skill_points"], 4)
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.multilevel", "fixture", 300)["duplicate"])
	assert_eq(inventory.progression_view(PLAYER)["available_skill_points"], 4)
	print("PRG03_RANK_THRESHOLD_OK")
	print("PRG03_POINT_GRANT_ONCE_OK")

func test_prg03_skill_spend_atomic_gate_points_duplicate_and_lost_ack() -> void:
	var inventory := _state()
	_register_standard(inventory)
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.skills", "fixture", 300)["accepted"])
	var child_early := inventory.execute_transaction(PLAYER, "txn.prg03.child.early", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_CHILD})
	assert_false(child_early["accepted"])
	assert_eq(child_early["reason"], "prerequisite_missing")
	var payload := {"skill_id": SKILL_ROOT}
	var first := inventory.execute_transaction(PLAYER, "txn.prg03.skill.retry", InventoryState.OP_SKILL_SPEND, payload)
	assert_true(first["accepted"])
	assert_eq(first["rank"], 1)
	assert_eq(inventory.progression_view(PLAYER)["available_skill_points"], 3)
	var retry := inventory.execute_transaction(PLAYER, "txn.prg03.skill.retry", InventoryState.OP_SKILL_SPEND, payload)
	assert_eq(retry, first)
	assert_eq(inventory.progression_view(PLAYER)["available_skill_points"], 3)
	var conflict := inventory.execute_transaction(PLAYER, "txn.prg03.skill.retry", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_CHILD})
	assert_eq(conflict["reason"], "transaction_conflict")
	var child_locked := inventory.execute_transaction(PLAYER, "txn.prg03.child.locked", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_CHILD})
	assert_false(child_locked["accepted"])
	assert_eq(child_locked["reason"], "gate_locked")
	var gate := inventory.execute_transaction(PLAYER, "txn.prg03.gate.for.skill", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE_LICENSE})
	assert_true(gate["accepted"])
	var child := inventory.execute_transaction(PLAYER, "txn.prg03.child.ok", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_CHILD})
	assert_true(child["accepted"])
	assert_eq(inventory.progression_view(PLAYER)["available_skill_points"], 1)
	print("PRG03_SKILL_TRANSACTION_OK")
	print("PRG03_LOST_ACK_IDEMPOTENCY_OK")

func test_prg03_respec_refund_and_modifier_removal_are_atomic() -> void:
	var inventory := _state()
	_register_standard(inventory)
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.respec", "fixture", 300)["accepted"])
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg03.skill.root", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_ROOT})["accepted"])
	assert_almost_eq(inventory.stat_value(PLAYER, "speed", 100.0), 102.0, 0.001)
	var respec := inventory.execute_transaction(PLAYER, "txn.prg03.respec", InventoryState.OP_RESPEC, {})
	assert_true(respec["accepted"])
	assert_eq(respec["refunded_points"], 1)
	assert_eq(respec["points"], 4)
	assert_almost_eq(inventory.stat_value(PLAYER, "speed", 100.0), 100.0, 0.001)
	var retry := inventory.execute_transaction(PLAYER, "txn.prg03.respec", InventoryState.OP_RESPEC, {})
	assert_eq(retry, respec)
	assert_eq(inventory.progression_view(PLAYER)["available_skill_points"], 4)
	print("PRG03_RESPEC_ATOMIC_OK")
	print("PRG03_MODIFIER_PIPELINE_OK")

func test_prg03_gate_prerequisite_rank_and_completion_idempotency() -> void:
	var inventory := _state()
	_register_standard(inventory)
	var early := inventory.execute_transaction(PLAYER, "txn.prg03.gate.early", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE_LICENSE})
	assert_false(early["accepted"])
	assert_eq(early["reason"], "rank_locked")
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.gate", "fixture", 100)["accepted"])
	var first := inventory.execute_transaction(PLAYER, "txn.prg03.gate.ok", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE_LICENSE})
	assert_true(first["accepted"])
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 110)
	var retry := inventory.execute_transaction(PLAYER, "txn.prg03.gate.ok", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE_LICENSE})
	assert_eq(retry, first)
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 110)
	var second_tx := inventory.execute_transaction(PLAYER, "txn.prg03.gate.second", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE_LICENSE})
	assert_false(second_tx["accepted"])
	assert_eq(second_tx["reason"], "already_completed")
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 110)
	print("PRG03_GATE_API_OK")

func test_prg03_local_challenge_progress_reward_idempotency_and_version_reset() -> void:
	var inventory := _state()
	_register_standard(inventory, VERSION_1)
	var first := inventory.execute_transaction(PLAYER, "txn.prg03.challenge.one", InventoryState.OP_CHALLENGE_EVENT, {"challenge_id": CHALLENGE, "event_id": "event.challenge.one"})
	assert_true(first["accepted"])
	assert_false(first["completed"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 0)
	var second := inventory.execute_transaction(PLAYER, "txn.prg03.challenge.two", InventoryState.OP_CHALLENGE_EVENT, {"challenge_id": CHALLENGE, "event_id": "event.challenge.two"})
	print("PRG03_CHALLENGE_SECOND_RESULT=", second)
	assert_true(second["accepted"], str(second))
	assert_true(second["completed"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 1)
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 50)
	var duplicate_event := inventory.execute_transaction(PLAYER, "txn.prg03.challenge.dupe", InventoryState.OP_CHALLENGE_EVENT, {"challenge_id": CHALLENGE, "event_id": "event.challenge.two"})
	assert_false(duplicate_event["accepted"])
	assert_eq(inventory.quantity(PLAYER, SCRAP), 1)
	var saved_progression := inventory.progression_snapshot()
	var saved_quantities := inventory.quantities_snapshot(PLAYER)
	var rotated := _state()
	_register_standard(rotated, VERSION_2)
	assert_true(rotated.restore_quantities(PLAYER, saved_quantities))
	assert_true(rotated.restore_progression(saved_progression))
	var rotated_event := rotated.execute_transaction(PLAYER, "txn.prg03.challenge.rotated", InventoryState.OP_CHALLENGE_EVENT, {"challenge_id": CHALLENGE, "event_id": "event.challenge.vtwo.one"})
	assert_true(rotated_event["accepted"])
	assert_eq(rotated_event["progress"], 1)
	assert_false(rotated_event["completed"])
	assert_eq(rotated.quantity(PLAYER, SCRAP), 1)
	print("PRG03_CHALLENGE_LOCAL_OK")
	print("PRG03_CHALLENGE_VERSION_RESET_OK")

func test_prg03_persistence_v3_v2_migration_and_corrupt_rejection() -> void:
	var inventory := _state()
	_register_standard(inventory)
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.persist", "fixture", 300)["accepted"])
	assert_true(inventory.execute_transaction(PLAYER, "txn.prg03.persist.skill", InventoryState.OP_SKILL_SPEND, {"skill_id": SKILL_ROOT})["accepted"])
	var progression := inventory.progression_snapshot()
	assert_eq(progression["version"], InventoryState.VERSION)
	assert_true(InventoryState.validate_progression_state(progression))
	var restored := _state()
	_register_standard(restored)
	assert_true(restored.restore_progression(progression))
	assert_eq(restored.progression_snapshot(), progression)
	var legacy := progression.duplicate(true)
	legacy["version"] = 2
	legacy.erase("prg03")
	legacy.erase("prg04")
	assert_true(InventoryState.validate_progression_state(legacy))
	var migrated := _state()
	_register_standard(migrated)
	assert_true(migrated.restore_progression(legacy))
	assert_eq(migrated.progression_view(PLAYER)["total_xp"], 0)
	var corrupt := progression.duplicate(true)
	corrupt["prg03"]["owners"][PLAYER]["skill_ranks"][SKILL_ROOT] = 99
	assert_false(InventoryState.validate_progression_state(corrupt))
	print("PRG03_PERSISTENCE_MIGRATION_OK")

func test_prg03_protocol_v6_host_authority_spoof_replay_and_malformed_guards() -> void:
	assert_eq(SessionProtocol.PROTOCOL_VERSION, 7)
	var envelopes := [
		SessionProtocol.make_envelope(1, SessionProtocol.PROGRESSION_SKILL_SPEND, {"transaction_id":"txn.net.skill","skill_id":SKILL_ROOT}),
		SessionProtocol.make_envelope(2, SessionProtocol.PROGRESSION_RESPEC, {"transaction_id":"txn.net.respec"}),
		SessionProtocol.make_envelope(3, SessionProtocol.PROGRESSION_GATE_COMPLETE, {"transaction_id":"txn.net.gate","gate_id":GATE_LICENSE}),
		SessionProtocol.make_envelope(4, SessionProtocol.PROGRESSION_CHALLENGE_EVENT, {"transaction_id":"txn.net.challenge","challenge_id":CHALLENGE,"event_id":"event.net.challenge"}),
	]
	for envelope in envelopes:
		assert_eq(SessionProtocol.validate_envelope(envelope), "")
	var malformed := SessionProtocol.make_envelope(5, SessionProtocol.PROGRESSION_CHALLENGE_EVENT, {"transaction_id":"txn.net.bad","challenge_id":CHALLENGE,"event_id":"event.net.bad","xp_amount":999999})
	assert_eq(SessionProtocol.validate_envelope(malformed), SessionProtocol.REJECT_MALFORMED_PAYLOAD)
	var spoof := SessionProtocol.make_envelope(6, SessionProtocol.PROGRESSION_SKILL_SPEND, {"transaction_id":"txn.net.spoof","skill_id":SKILL_ROOT,"owner_id":PLAYER})
	assert_eq(SessionProtocol.validate_envelope(spoof), SessionProtocol.REJECT_FORBIDDEN_IDENTITY)
	assert_eq(SessionProtocol.validate_sequence(10, 10), SessionProtocol.REJECT_REPLAY)
	assert_false(SessionProtocol.NETWORK_INTENTS.has("progression_xp_grant"))
	print("PRG03_LAN_AUTHORITY_OK")
	print("PRG03_CLIENT_OUTCOME_GUARD_OK")

func test_prg03_touch_zoom_pan_intents_and_offline_contract() -> void:
	var panel := ProgressionPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	assert_true(panel.select_skill(SKILL_ROOT))
	assert_true(panel.select_gate(GATE_LICENSE))
	assert_true(panel.select_challenge(CHALLENGE))
	assert_true(panel.set_skill_view_transform(1.5, Vector2(40.0, -20.0)))
	var transform := panel.skill_view_transform()
	assert_eq(transform["zoom"], 1.5)
	assert_true(panel.request_skill_spend("txn.ui.prg03.skill"))
	assert_true(panel.request_respec("txn.ui.prg03.respec"))
	assert_true(panel.request_gate_complete("txn.ui.prg03.gate"))
	assert_true(panel.request_challenge_event("txn.ui.prg03.challenge", "event.ui.challenge"))
	assert_signal_emitted(panel, "progression_intent_requested")
	var button := Button.new()
	add_child_autofree(button)
	ProgressionPanel.apply_touch_target(button)
	assert_gte(button.custom_minimum_size.x, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_gte(button.custom_minimum_size.y, ProgressionPanel.MIN_TOUCH_TARGET)
	assert_eq(ProgressionPanel.ACCESSIBILITY_FONT_SCALE, 1.3)
	print("PRG03_TOUCH_UI_OK")
	print("PRG03_OFFLINE_META_OK")
