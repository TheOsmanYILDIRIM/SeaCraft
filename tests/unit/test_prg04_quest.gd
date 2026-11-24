extends GutTest

const PLAYER := "entity.player"
const PARTY := "entity.party.two"
const NPC_START := "npc.harbor.start"
const NPC_TURN := "npc.harbor.turnin"
const NPC_OTHER := "npc.harbor.other"
const REGION := "region.foundation"
const REGION_OTHER := "region.outer"
const SECTOR := "sector.foundation"
const SECTOR_OTHER := "sector.outer"
const ITEM := "item.scrap"
const TARGET := "entity.target"
const SOURCE := "item.trade.goods"
const RANK_0 := "rank.deckhand"
const RANK_1 := "rank.officer"
const GATE := "gate.quest.license"

func _item(id: String, limit: int = 20) -> ItemDefinition:
	var definition := ItemDefinition.new()
	definition.stable_id = id
	definition.display_name = id
	definition.item_category = "material"
	definition.stack_limit = limit
	return definition

func _rank(id: String, threshold: int, points: int = 0) -> ProgressionRankDefinition:
	var definition := ProgressionRankDefinition.new()
	definition.stable_id = id
	definition.xp_threshold = threshold
	definition.skill_point_grant = points
	definition.label = id
	return definition

func _gate(id: String, required_rank: String = "") -> ProgressionGateDefinition:
	var definition := ProgressionGateDefinition.new()
	definition.stable_id = id
	definition.gate_type = "license"
	definition.required_rank_id = required_rank
	return definition

func _objective(kind: String, target: String = TARGET, source: String = "", required: int = 1, region: String = REGION, id: String = "objective.main") -> Dictionary:
	return {
		"objective_id": id,
		"objective_type": kind,
		"target_id": target,
		"source_id": source,
		"required_value": required,
		"region_id": region,
	}

func _quest(id: String, kind: String = "kill", target: String = TARGET, source: String = "", required: int = 1) -> QuestDefinition:
	var definition := QuestDefinition.new()
	definition.stable_id = id
	definition.quest_type = "story"
	definition.tags = PackedStringArray(["tag.prg04"])
	definition.start_npc_id = NPC_START
	definition.turn_in_npc_id = NPC_TURN
	definition.region_ids = PackedStringArray([REGION])
	definition.sector_ids = PackedStringArray([SECTOR])
	definition.objectives = [_objective(kind, target, source, required)]
	definition.reward_items = [{"item_id": ITEM, "quantity": 1}]
	definition.xp_reward = 10
	definition.version_key = "version.prg04.v1"
	definition.title = id
	definition.description = "PRG-04 fixture"
	return definition

func _state(item_limit: int = 20) -> InventoryState:
	var inventory := InventoryState.new()
	assert_true(inventory.bind_owner(PLAYER, 8, 100.0))
	assert_true(inventory.register_item_definition(_item(ITEM, item_limit)))
	assert_true(inventory.configure_prg02(SeedStreams.new(20261122)))
	assert_true(inventory.configure_prg03())
	assert_true(inventory.register_rank_definition(_rank(RANK_0, 0)))
	assert_true(inventory.register_rank_definition(_rank(RANK_1, 100)))
	assert_true(inventory.register_gate_definition(_gate(GATE, RANK_1)))
	assert_true(inventory.configure_prg04())
	for npc in [NPC_START, NPC_TURN, NPC_OTHER]:
		assert_true(inventory.register_quest_npc_ref(npc))
	for region in [REGION, REGION_OTHER]:
		assert_true(inventory.register_quest_region_ref(region))
	for sector in [SECTOR, SECTOR_OTHER]:
		assert_true(inventory.register_quest_sector_ref(sector))
	assert_true(inventory.set_quest_authoritative_context(PLAYER, SECTOR, REGION, PackedStringArray([NPC_START, NPC_TURN]), 100))
	return inventory

func _event(event_id: String, kind: String, target: String = TARGET, source: String = "", quantity: int = 1, tick: int = 101, outcome: String = "", actor: String = PLAYER, region: String = REGION, sector: String = SECTOR) -> Dictionary:
	return {
		"event_id": event_id,
		"actor_id": actor,
		"objective_type": kind,
		"target_id": target,
		"source_id": source,
		"quantity": quantity,
		"sector_id": sector,
		"region_id": region,
		"tick": tick,
		"outcome": outcome,
	}

func _accept(inventory: InventoryState, quest_id: String, txn: String = "txn.quest.accept") -> Dictionary:
	return inventory.execute_transaction(PLAYER, txn, InventoryState.OP_QUEST_ACCEPT, {"quest_id": quest_id, "npc_id": NPC_START})

func test_prg04_definition_schema_refs_cycles_regions_and_registry_type() -> void:
	assert_true(DefinitionRegistry.VALID_DEFINITION_TYPES.has("quest"))
	var good := _quest("quest.schema.good")
	assert_true(good.valid())
	var bad := _quest("quest.schema.bad")
	bad.objectives = [{"objective_id": "objective.bad", "objective_type": "kill"}]
	assert_false(bad.valid())
	var missing_npc := InventoryState.new()
	assert_true(missing_npc.bind_owner(PLAYER))
	assert_true(missing_npc.register_item_definition(_item(ITEM)))
	assert_true(missing_npc.configure_prg02(SeedStreams.new(1)))
	assert_true(missing_npc.configure_prg03())
	assert_true(missing_npc.register_rank_definition(_rank(RANK_0, 0)))
	assert_true(missing_npc.register_rank_definition(_rank(RANK_1, 100)))
	assert_true(missing_npc.register_gate_definition(_gate(GATE, RANK_1)))
	assert_true(missing_npc.configure_prg04())
	assert_true(missing_npc.register_quest_region_ref(REGION))
	assert_true(missing_npc.register_quest_sector_ref(SECTOR))
	assert_true(missing_npc.register_quest_definition(good))
	assert_eq(missing_npc.validate_prg04_catalog(), "missing_npc_reference")
	var cycle := _state()
	var a := _quest("quest.chain.a")
	var b := _quest("quest.chain.b")
	a.prerequisite_quest_ids = PackedStringArray([b.stable_id])
	b.prerequisite_quest_ids = PackedStringArray([a.stable_id])
	assert_true(cycle.register_quest_definition(a))
	assert_true(cycle.register_quest_definition(b))
	assert_eq(cycle.validate_prg04_catalog(), "quest_cycle")
	var missing_region := _state()
	var r := _quest("quest.region.missing")
	r.region_ids = PackedStringArray(["region.unknown"])
	assert_true(missing_region.register_quest_definition(r))
	assert_eq(missing_region.validate_prg04_catalog(), "missing_region_reference")
	print("PRG04_SCHEMA_OK")
	print("PRG04_REFERENCE_VALIDATION_OK")
	print("PRG04_CHAIN_CYCLE_OK")
	print("PRG04_REGION_VALIDATION_OK")

func test_prg04_prerequisite_gate_rank_and_npc_authority() -> void:
	var inventory := _state()
	var quest := _quest("quest.prereq")
	quest.prerequisite_gate_ids = PackedStringArray([GATE])
	quest.required_rank_id = RANK_1
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	var locked := _accept(inventory, quest.stable_id, "txn.quest.prereq.locked")
	assert_false(locked["accepted"])
	assert_eq(locked["reason"], "gate_locked")
	assert_true(inventory.grant_xp_authoritative(PLAYER, "event.xp.prg04.rank", "fixture", 100)["accepted"])
	assert_true(inventory.execute_transaction(PLAYER, "txn.quest.gate", InventoryState.OP_GATE_COMPLETE, {"gate_id": GATE})["accepted"])
	var wrong_npc := inventory.execute_transaction(PLAYER, "txn.quest.prereq.wrongnpc", InventoryState.OP_QUEST_ACCEPT, {"quest_id": quest.stable_id, "npc_id": NPC_TURN})
	assert_false(wrong_npc["accepted"])
	var accepted := _accept(inventory, quest.stable_id, "txn.quest.prereq.ok")
	assert_true(accepted["accepted"])
	print("PRG04_PREREQUISITE_GATE_RANK_OK")
	print("PRG04_NPC_INTERACTION_AUTHORITY_OK")

func test_prg04_all_objective_semantics() -> void:
	var rows := [
		["kill", TARGET, "", ""],
		["damage", TARGET, "", ""],
		["capture", TARGET, "", "success"],
		["collect", "item.collect", "", ""],
		["acquire", "item.acquire", "", ""],
		["timed", "", "", ""],
		["escort", TARGET, "", "success"],
		["salvage", "wreck.target", "", ""],
		["trade", "npc.trade", SOURCE, ""],
	]
	for row in rows:
		var kind := str(row[0])
		var inventory := _state()
		var quest := _quest("quest.objective." + kind, kind, str(row[1]), str(row[2]), 1)
		assert_true(inventory.register_quest_definition(quest))
		assert_eq(inventory.validate_prg04_catalog(), "")
		assert_true(_accept(inventory, quest.stable_id, "txn.quest.accept." + kind)["accepted"])
		var result := inventory.apply_quest_objective_event_authoritative(PLAYER, _event("event.quest." + kind, kind, str(row[1]), str(row[2]), 1, 101, str(row[3])))
		assert_true(result["accepted"], kind + ": " + str(result))
		assert_eq(inventory.quest_status(PLAYER, quest.stable_id), Prg04QuestState.STATUS_COMPLETABLE)
	print("PRG04_OBJECTIVE_KILL_OK")
	print("PRG04_OBJECTIVE_DAMAGE_OK")
	print("PRG04_OBJECTIVE_CAPTURE_OK")
	print("PRG04_OBJECTIVE_COLLECT_OK")
	print("PRG04_OBJECTIVE_ACQUIRE_OK")
	print("PRG04_OBJECTIVE_TIMED_OK")
	print("PRG04_OBJECTIVE_ESCORT_OK")
	print("PRG04_OBJECTIVE_SALVAGE_OK")
	print("PRG04_OBJECTIVE_TRADE_OK")

func test_prg04_event_duplicate_conflict_wrong_filters_and_party_policy() -> void:
	var inventory := _state()
	var quest := _quest("quest.events", "kill", TARGET, "", 2)
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	assert_true(_accept(inventory, quest.stable_id)["accepted"])
	var first_event := _event("event.quest.same", "kill")
	var first := inventory.apply_quest_objective_event_authoritative(PLAYER, first_event)
	assert_true(first["accepted"])
	assert_eq(first["progressed"], 1)
	var before := inventory.prg04_state_snapshot()
	var duplicate := inventory.apply_quest_objective_event_authoritative(PLAYER, first_event)
	assert_true(duplicate["accepted"])
	assert_true(duplicate["duplicate"])
	assert_eq(inventory.prg04_state_snapshot(), before)
	var conflict_event := first_event.duplicate(true)
	conflict_event["quantity"] = 2
	var conflict := inventory.apply_quest_objective_event_authoritative(PLAYER, conflict_event)
	assert_false(conflict["accepted"])
	assert_eq(conflict["reason"], "objective_event_conflict")
	assert_eq(inventory.prg04_state_snapshot(), before)
	for bad_event in [
		_event("event.quest.wrong.target", "kill", "entity.wrong"),
		_event("event.quest.wrong.type", "damage", TARGET),
		_event("event.quest.wrong.region", "kill", TARGET, "", 1, 101, "", PLAYER, REGION_OTHER, SECTOR),
		_event("event.quest.spoof", "kill", TARGET, "", 1, 101, "", PARTY),
	]:
		var rejected := inventory.apply_quest_objective_event_authoritative(PLAYER, bad_event)
		assert_false(rejected["accepted"])
		assert_eq(inventory.prg04_state_snapshot(), before)
	assert_true(inventory.set_quest_eligible_party_members(PLAYER, PackedStringArray([PARTY])))
	quest.party_share_policy = "shared_progress"
	var shared := inventory.apply_quest_objective_event_authoritative(PLAYER, _event("event.quest.party.allowed", "kill", TARGET, "", 1, 102, "", PARTY))
	assert_true(shared["accepted"])
	assert_eq(inventory.quest_status(PLAYER, quest.stable_id), Prg04QuestState.STATUS_COMPLETABLE)
	print("PRG04_EVENT_IDEMPOTENCY_OK")
	print("PRG04_EVENT_CONFLICT_OK")
	print("PRG04_EVENT_FILTERS_OK")
	print("PRG04_PARTY_POLICY_OK")

func test_prg04_completion_atomic_reward_retry_and_rollback() -> void:
	var inventory := _state()
	var quest := _quest("quest.reward")
	quest.xp_reward = 25
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	assert_true(_accept(inventory, quest.stable_id)["accepted"])
	assert_true(inventory.apply_quest_objective_event_authoritative(PLAYER, _event("event.quest.reward", "kill"))["accepted"])
	var payload := {"quest_id": quest.stable_id, "npc_id": NPC_TURN}
	var first := inventory.execute_transaction(PLAYER, "txn.quest.reward.turnin", InventoryState.OP_QUEST_TURN_IN, payload)
	assert_true(first["accepted"])
	assert_eq(inventory.quantity(PLAYER, ITEM), 1)
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 25)
	assert_eq(inventory.quest_status(PLAYER, quest.stable_id), Prg04QuestState.STATUS_COMPLETED)
	var retry := inventory.execute_transaction(PLAYER, "txn.quest.reward.turnin", InventoryState.OP_QUEST_TURN_IN, payload)
	assert_eq(retry, first)
	assert_eq(inventory.quantity(PLAYER, ITEM), 1)
	assert_eq(inventory.progression_view(PLAYER)["total_xp"], 25)
	var rollback := _state()
	var rollback_quest := _quest("quest.reward.rollback")
	rollback_quest.reward_gate_ids = PackedStringArray([GATE])
	rollback_quest.xp_reward = 30
	assert_true(rollback.register_quest_definition(rollback_quest))
	assert_eq(rollback.validate_prg04_catalog(), "")
	assert_true(_accept(rollback, rollback_quest.stable_id, "txn.quest.rollback.accept")["accepted"])
	assert_true(rollback.apply_quest_objective_event_authoritative(PLAYER, _event("event.quest.rollback", "kill"))["accepted"])
	var failed := rollback.execute_transaction(PLAYER, "txn.quest.rollback.turnin", InventoryState.OP_QUEST_TURN_IN, {"quest_id": rollback_quest.stable_id, "npc_id": NPC_TURN})
	assert_false(failed["accepted"])
	assert_eq(failed["reason"], "reward_gate_failed")
	assert_eq(rollback.quantity(PLAYER, ITEM), 0)
	assert_eq(rollback.progression_view(PLAYER)["total_xp"], 0)
	assert_eq(rollback.quest_status(PLAYER, rollback_quest.stable_id), Prg04QuestState.STATUS_COMPLETABLE)
	print("PRG04_COMPLETION_TRANSITION_OK")
	print("PRG04_REWARD_ATOMIC_OK")
	print("PRG04_REWARD_ROLLBACK_OK")
	print("PRG04_REWARD_LOST_ACK_OK")

func test_prg04_timed_failure_save_load_v4_migration_and_corrupt_rejection() -> void:
	var inventory := _state()
	var quest := _quest("quest.persist", "timed", "", "", 10)
	quest.time_limit_ticks = 20
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	assert_true(_accept(inventory, quest.stable_id)["accepted"])
	assert_true(inventory.apply_quest_objective_event_authoritative(PLAYER, _event("event.quest.persist", "timed", "", "", 4, 104))["accepted"])
	var progression := inventory.progression_snapshot()
	assert_eq(progression["version"], InventoryState.VERSION)
	assert_true(InventoryState.validate_progression_state(progression))
	var restored := _state()
	assert_true(restored.register_quest_definition(_quest("quest.persist", "timed", "", "", 10)))
	assert_eq(restored.validate_prg04_catalog(), "")
	assert_true(restored.restore_progression(progression))
	assert_eq(restored.prg04_state_snapshot(), progression["prg04"])
	assert_true(restored.set_quest_authoritative_context(PLAYER, SECTOR, REGION, PackedStringArray([NPC_START, NPC_TURN]), 104))
	var timeout := restored.advance_quest_tick_authoritative(PLAYER, 121)
	assert_true(timeout["accepted"])
	assert_eq(restored.quest_status(PLAYER, quest.stable_id), Prg04QuestState.STATUS_FAILED)
	var legacy := progression.duplicate(true)
	legacy["version"] = 3
	legacy.erase("prg04")
	legacy.erase("prg05")
	assert_true(InventoryState.validate_progression_state(legacy))
	var migrated := _state()
	assert_true(migrated.restore_progression(legacy))
	assert_eq(migrated.prg04_state_snapshot(), Prg04QuestState.empty_state())
	var corrupt := progression.duplicate(true)
	corrupt["prg04"]["owners"][PLAYER]["quests"][quest.stable_id]["progress"]["objective.main"] = Prg04QuestState.MAX_PROGRESS + 1
	assert_false(InventoryState.validate_progression_state(corrupt))
	print("PRG04_PERSISTENCE_V4_OK")
	print("PRG04_MIGRATION_V3_OK")
	print("PRG04_CORRUPT_REJECTION_OK")
	print("PRG04_TIMED_RELOAD_OK")

func test_prg04_protocol_v7_host_authority_spoof_replay_malformed_and_client_outcome_guard() -> void:
	assert_eq(SessionProtocol.PROTOCOL_VERSION, 8)
	var accept := SessionProtocol.make_envelope(1, SessionProtocol.QUEST_ACCEPT, {"transaction_id": "txn.net.quest.accept", "quest_id": "quest.net", "npc_id": NPC_START})
	var turnin := SessionProtocol.make_envelope(2, SessionProtocol.QUEST_TURN_IN, {"transaction_id": "txn.net.quest.turnin", "quest_id": "quest.net", "npc_id": NPC_TURN})
	assert_eq(SessionProtocol.validate_envelope(accept), "")
	assert_eq(SessionProtocol.validate_envelope(turnin), "")
	assert_true(SessionProtocol.PROGRESSION_INTENTS.has(SessionProtocol.QUEST_ACCEPT))
	assert_false(SessionProtocol.NETWORK_INTENTS.has("quest_objective_event"))
	var spoof := SessionProtocol.make_envelope(3, SessionProtocol.QUEST_ACCEPT, {"transaction_id": "txn.net.quest.spoof", "quest_id": "quest.net", "npc_id": NPC_START, "owner_id": PARTY})
	assert_eq(SessionProtocol.validate_envelope(spoof), SessionProtocol.REJECT_FORBIDDEN_IDENTITY)
	var malformed := SessionProtocol.make_envelope(4, SessionProtocol.QUEST_ACCEPT, {"transaction_id": "txn.net.quest.bad", "quest_id": "quest.net", "npc_id": NPC_START, "reward": 999})
	assert_eq(SessionProtocol.validate_envelope(malformed), SessionProtocol.REJECT_MALFORMED_PAYLOAD)
	assert_eq(SessionProtocol.validate_sequence(8, 8), SessionProtocol.REJECT_REPLAY)
	print("PRG04_LAN_HOST_AUTHORITY_OK")
	print("PRG04_LAN_SPOOF_REPLAY_MALFORMED_OK")
	print("PRG04_CLIENT_OUTCOME_GUARD_OK")

func test_prg04_detached_journal_mirror_reconnect_and_late_join_contract() -> void:
	var inventory := _state()
	var quest := _quest("quest.journal")
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	var available := inventory.quest_journal_snapshot(PLAYER)
	assert_true(InventoryState.validate_quest_journal_snapshot(available))
	assert_eq((available["groups"]["available"] as Array).size(), 1)
	assert_true(_accept(inventory, quest.stable_id)["accepted"])
	var active := inventory.quest_journal_snapshot(PLAYER)
	assert_true(InventoryState.validate_quest_journal_snapshot(active))
	assert_eq((active["groups"]["active"] as Array).size(), 1)
	var client := SessionClient.new()
	add_child_autofree(client)
	client.set("_state", SessionClient.STATE_HANDSHAKING)
	client.call("_on_handshake_accepted", {"protocol_version": 8, "player_id": PLAYER, "session_id": "session.prg04", "resume_token": "0123456789abcdef0123456789abcdef", "resume_sequence": 0, "quest_snapshot": active})
	assert_eq(client.quest_journal_snapshot(), active)
	var late := SessionClient.new()
	add_child_autofree(late)
	late.set("_state", SessionClient.STATE_HANDSHAKING)
	late.call("_on_handshake_accepted", {"protocol_version": 8, "player_id": PLAYER, "session_id": "session.prg04.late", "resume_token": "abcdef0123456789abcdef0123456789", "resume_sequence": 0, "quest_snapshot": active})
	assert_eq(late.quest_journal_snapshot(), active)
	print("PRG04_JOURNAL_DTO_OK")
	print("PRG04_RECONNECT_SNAPSHOT_OK")
	print("PRG04_LATE_JOIN_SNAPSHOT_OK")

func test_prg04_touch_journal_accept_turnin_track_timer_and_detached_state() -> void:
	var inventory := _state()
	var quest := _quest("quest.ui", "timed", "", "", 5)
	quest.time_limit_ticks = 50
	assert_true(inventory.register_quest_definition(quest))
	assert_eq(inventory.validate_prg04_catalog(), "")
	var snapshot := inventory.quest_journal_snapshot(PLAYER)
	var panel := QuestJournalPanel.new()
	add_child_autofree(panel)
	watch_signals(panel)
	assert_true(panel.consume_snapshot(snapshot))
	assert_true(panel.select_quest(quest.stable_id))
	assert_true(panel.track_selected())
	assert_eq(panel.tracked_quest_id(), quest.stable_id)
	assert_true(panel.request_accept("txn.ui.quest.accept", NPC_START))
	assert_signal_emitted(panel, "quest_intent_requested")
	var button := Button.new()
	add_child_autofree(button)
	QuestJournalPanel.apply_touch_target(button)
	assert_gte(button.custom_minimum_size.x, QuestJournalPanel.MIN_TOUCH_TARGET)
	assert_eq(QuestJournalPanel.ACCESSIBILITY_FONT_SCALE, 1.3)
	assert_eq(inventory.quest_status(PLAYER, quest.stable_id), "available")
	assert_eq(snapshot, inventory.quest_journal_snapshot(PLAYER))
	print("PRG04_TOUCH_UI_OK")
	print("PRG04_TRACKING_UI_OK")
	print("PRG04_DETACHED_UI_OK")
	print("PRG04_OFFLINE_FIRST_OK")
