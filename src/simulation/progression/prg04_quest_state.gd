class_name Prg04QuestState
extends RefCounted

const VERSION := 1
const JOURNAL_VERSION := 1
const MAX_OWNERS := 32
const MAX_QUESTS := 128
const MAX_EVENTS := 512
const MAX_PROGRESS := 2147483647
const MAX_PARTY_MEMBERS := 4

const STATUS_ACTIVE := "active"
const STATUS_COMPLETABLE := "completable"
const STATUS_COMPLETED := "completed"
const STATUS_FAILED := "failed"
const STORED_STATUSES := [STATUS_ACTIVE, STATUS_COMPLETABLE, STATUS_COMPLETED, STATUS_FAILED]

const OP_ACCEPT := "quest_accept"
const OP_TURN_IN := "quest_turn_in"
const OPERATIONS := [OP_ACCEPT, OP_TURN_IN]

var _inventory
var _quests: Dictionary = {}
var _npc_refs: Dictionary = {}
var _region_refs: Dictionary = {}
var _sector_refs: Dictionary = {}
var _owners: Dictionary = {}
var _contexts: Dictionary = {}
var _party_members: Dictionary = {}

func _init(inventory = null) -> void:
	_inventory = inventory

static func supports_operation(operation: String) -> bool:
	return operation in OPERATIONS

func bind_owner(owner_id: String) -> bool:
	if _inventory == null or not SectorIds.valid(owner_id):
		return false
	if not _owners.has(owner_id):
		if _owners.size() >= MAX_OWNERS:
			return false
		_owners[owner_id] = _empty_owner()
	return true

func reassign_owner(from_id: String, to_id: String) -> bool:
	if not SectorIds.valid(from_id) or not SectorIds.valid(to_id) or _owners.has(to_id):
		return false
	if _owners.has(from_id):
		_owners[to_id] = _owners[from_id]
		_owners.erase(from_id)
	if _contexts.has(from_id):
		_contexts[to_id] = _contexts[from_id]
		_contexts.erase(from_id)
	if _party_members.has(from_id):
		_party_members[to_id] = _party_members[from_id]
		_party_members.erase(from_id)
	return true

func register_npc_ref(npc_id: String) -> bool:
	return _register_ref(_npc_refs, npc_id)

func register_region_ref(region_id: String) -> bool:
	return _register_ref(_region_refs, region_id)

func register_sector_ref(sector_id: String) -> bool:
	return _register_ref(_sector_refs, sector_id)

func register_quest(definition: QuestDefinition) -> bool:
	if definition == null or not definition.valid() or _quests.size() >= MAX_QUESTS or _quests.has(definition.stable_id):
		return false
	_quests[definition.stable_id] = definition
	return true

func has_quest(quest_id: String) -> bool:
	return _quests.has(quest_id)

func validate_catalog() -> String:
	for quest_id in _quests:
		var definition := _quests[quest_id] as QuestDefinition
		if not _npc_refs.has(definition.start_npc_id) or not _npc_refs.has(definition.turn_in_npc_id):
			return "missing_npc_reference"
		for prerequisite in definition.prerequisite_quest_ids:
			if not _quests.has(prerequisite):
				return "missing_quest_prerequisite"
		for gate_id in definition.prerequisite_gate_ids:
			if not _inventory.has_progression_gate(str(gate_id)):
				return "missing_gate_reference"
		if not definition.required_rank_id.is_empty() and not _inventory.has_progression_rank(definition.required_rank_id):
			return "missing_rank_reference"
		for region_id in definition.region_ids:
			if not _region_refs.has(region_id):
				return "missing_region_reference"
		for sector_id in definition.sector_ids:
			if not _sector_refs.has(sector_id):
				return "missing_sector_reference"
		for objective in definition.objectives:
			var region_id := str(objective["region_id"])
			if not region_id.is_empty() and not _region_refs.has(region_id):
				return "missing_objective_region"
		for reward in definition.reward_items:
			if not _inventory.has_item_spec(str(reward["item_id"])):
				return "missing_reward_item"
		for gate_id in definition.reward_gate_ids:
			if not _inventory.has_progression_gate(str(gate_id)):
				return "missing_reward_gate"
	var colors: Dictionary = {}
	for quest_id in _sorted_keys(_quests):
		if _visit_quest(str(quest_id), colors):
			return "quest_cycle"
	for owner_id in _owners:
		var owner: Dictionary = _owners[owner_id]
		for quest_id in owner["quests"]:
			if not _quests.has(quest_id):
				return "unknown_saved_quest"
	return ""

func set_authoritative_context(owner_id: String, sector_id: String, region_id: String, nearby_npc_ids: PackedStringArray, tick: int) -> bool:
	if not _ensure_owner(owner_id) or not _sector_refs.has(sector_id) or not _region_refs.has(region_id) or tick < 0:
		return false
	if nearby_npc_ids.size() > 32:
		return false
	var nearby: Dictionary = {}
	for npc_id in nearby_npc_ids:
		if not _npc_refs.has(npc_id) or nearby.has(npc_id):
			return false
		nearby[npc_id] = true
	_contexts[owner_id] = {"sector_id": sector_id, "region_id": region_id, "nearby_npcs": nearby, "tick": tick}
	return true

func set_eligible_party_members(owner_id: String, members: PackedStringArray) -> bool:
	if not _ensure_owner(owner_id) or members.size() > MAX_PARTY_MEMBERS:
		return false
	var values: Dictionary = {}
	for member_id in members:
		if not SectorIds.valid(member_id) or member_id == owner_id or values.has(member_id):
			return false
		values[member_id] = true
	_party_members[owner_id] = values
	return true

func advance_tick_authoritative(owner_id: String, tick: int) -> Dictionary:
	var result := {"accepted": false, "reason": "invalid_tick", "failed_quests": []}
	if not _ensure_owner(owner_id) or tick < 0:
		return result
	var context: Dictionary = _contexts.get(owner_id, {})
	if context.is_empty() or tick < int(context.get("tick", 0)):
		return result
	context["tick"] = tick
	_contexts[owner_id] = context
	var owner: Dictionary = _owners[owner_id]
	var quests: Dictionary = owner["quests"]
	var failed: Array[String] = []
	for quest_id in quests:
		var instance: Dictionary = quests[quest_id]
		if str(instance["status"]) not in [STATUS_ACTIVE, STATUS_COMPLETABLE]:
			continue
		var deadline := int(instance["deadline_tick"])
		if deadline >= 0 and tick > deadline:
			instance["status"] = STATUS_FAILED
			instance["last_tick"] = tick
			quests[quest_id] = instance
			failed.append(str(quest_id))
	owner["quests"] = quests
	_owners[owner_id] = owner
	result["accepted"] = true
	result["reason"] = ""
	result["failed_quests"] = failed
	return result

func execute(actor_id: String, operation: String, payload: Dictionary) -> Dictionary:
	if not supports_operation(operation) or not _ensure_owner(actor_id):
		return _reject(operation, "quest_unavailable")
	var catalog_error := validate_catalog()
	if not catalog_error.is_empty():
		return _reject(operation, catalog_error)
	match operation:
		OP_ACCEPT:
			return _accept(actor_id, payload)
		OP_TURN_IN:
			return _turn_in(actor_id, payload)
	return _reject(operation, "unsupported_operation")

func apply_objective_event_authoritative(owner_id: String, event: Dictionary) -> Dictionary:
	var base := {"accepted": false, "reason": "invalid_objective_event", "duplicate": false, "progressed": 0, "completed": [], "failed": []}
	if not _ensure_owner(owner_id) or not _valid_event(event):
		return base
	var context: Dictionary = _contexts.get(owner_id, {})
	if context.is_empty() or str(event["sector_id"]) != str(context["sector_id"]) or str(event["region_id"]) != str(context["region_id"]):
		base["reason"] = "authority_context_mismatch"
		return base
	if int(event["tick"]) < int(context["tick"]):
		base["reason"] = "stale_objective_event"
		return base
	var owner: Dictionary = _owners[owner_id]
	var event_id := str(event["event_id"])
	var events: Dictionary = owner["objective_events"]
	var fingerprint := JSON.stringify(_canonical(event)).sha256_text()
	if events.has(event_id):
		if str(events[event_id]) != fingerprint:
			base["reason"] = "objective_event_conflict"
			return base
		base["accepted"] = true
		base["reason"] = ""
		base["duplicate"] = true
		return base
	if events.size() >= MAX_EVENTS:
		base["reason"] = "objective_event_ledger_full"
		return base
	var quests: Dictionary = owner["quests"]
	var next_quests := quests.duplicate(true)
	var progressed := 0
	var completed: Array[String] = []
	var failed: Array[String] = []
	var actor_allowed_somewhere := false
	for quest_id in _sorted_keys(quests):
		var instance: Dictionary = next_quests[quest_id]
		if str(instance["status"]) != STATUS_ACTIVE or not _quests.has(quest_id):
			continue
		var definition := _quests[quest_id] as QuestDefinition
		if not _actor_eligible(owner_id, str(event["actor_id"]), definition.party_share_policy):
			continue
		actor_allowed_somewhere = true
		if not _quest_event_context_matches(definition, event):
			continue
		var objective_index := _matching_objective_index(definition, instance, event)
		if objective_index < 0:
			continue
		var objective: Dictionary = definition.objectives[objective_index]
		if str(objective["objective_type"]) == "escort" and str(event["outcome"]) == "failure":
			instance["status"] = STATUS_FAILED
			instance["last_tick"] = int(event["tick"])
			next_quests[quest_id] = instance
			failed.append(str(quest_id))
			continue
		if str(objective["objective_type"]) in ["capture", "escort"] and str(event["outcome"]) != "success":
			continue
		var amount := int(event["quantity"])
		var progress: Dictionary = instance["progress"]
		var objective_id := str(objective["objective_id"])
		var current := int(progress.get(objective_id, 0))
		var required := int(objective["required_value"])
		if current >= required:
			continue
		var next_value := mini(required, current + amount)
		if next_value <= current:
			continue
		progress[objective_id] = next_value
		instance["progress"] = progress
		instance["last_tick"] = int(event["tick"])
		progressed += next_value - current
		if _all_objectives_complete(definition, instance):
			instance["status"] = STATUS_COMPLETABLE
			completed.append(str(quest_id))
		next_quests[quest_id] = instance
	if progressed == 0 and failed.is_empty():
		base["reason"] = "authority_mismatch" if not actor_allowed_somewhere else "no_matching_objective"
		return base
	events[event_id] = fingerprint
	owner["objective_events"] = events
	owner["quests"] = next_quests
	_owners[owner_id] = owner
	context["tick"] = int(event["tick"])
	_contexts[owner_id] = context
	base["accepted"] = true
	base["reason"] = ""
	base["progressed"] = progressed
	base["completed"] = completed
	base["failed"] = failed
	return base

func quest_status(owner_id: String, quest_id: String) -> String:
	if not _owners.has(owner_id):
		return "locked"
	var quests: Dictionary = (_owners[owner_id] as Dictionary)["quests"]
	if quests.has(quest_id):
		return str((quests[quest_id] as Dictionary)["status"])
	return "available" if availability_reason(owner_id, quest_id).is_empty() else "locked"

func quest_completed(owner_id: String, quest_id: String) -> bool:
	return quest_status(owner_id, quest_id) == STATUS_COMPLETED

func availability_reason(owner_id: String, quest_id: String) -> String:
	if not _ensure_owner(owner_id) or not _quests.has(quest_id):
		return "unknown_quest"
	var definition := _quests[quest_id] as QuestDefinition
	var context: Dictionary = _contexts.get(owner_id, {})
	if context.is_empty():
		return "missing_authority_context"
	if not _definition_context_matches(definition, context):
		return "region_locked"
	for prerequisite in definition.prerequisite_quest_ids:
		if not quest_completed(owner_id, str(prerequisite)):
			return "quest_prerequisite_missing"
	for gate_id in definition.prerequisite_gate_ids:
		if not _inventory.progression_gate_completed(owner_id, str(gate_id)):
			return "gate_locked"
	if not definition.required_rank_id.is_empty() and not _inventory.progression_rank_satisfies(owner_id, definition.required_rank_id):
		return "rank_locked"
	var quests: Dictionary = (_owners[owner_id] as Dictionary)["quests"]
	if not quests.has(quest_id):
		return ""
	var instance: Dictionary = quests[quest_id]
	var status := str(instance["status"])
	if status in [STATUS_ACTIVE, STATUS_COMPLETABLE]:
		return "already_active"
	if status == STATUS_COMPLETED:
		if definition.repeatability_policy == "once":
			return "already_completed"
		if definition.repeatability_policy == "version" and str(instance["completed_version"]) == definition.version_key:
			return "already_completed_version"
	return ""

func journal_snapshot(owner_id: String) -> Dictionary:
	if not _owners.has(owner_id):
		return empty_journal(owner_id)
	var result := empty_journal(owner_id)
	var groups: Dictionary = result["groups"]
	var owner: Dictionary = _owners[owner_id]
	var instances: Dictionary = owner["quests"]
	for quest_id in _sorted_keys(_quests):
		var definition := _quests[quest_id] as QuestDefinition
		var status := quest_status(owner_id, str(quest_id))
		if status == "locked":
			continue
		var instance: Dictionary = instances.get(quest_id, {})
		var row := _journal_row(owner_id, definition, instance, status)
		match status:
			"available":
				(groups["available"] as Array).append(row)
			STATUS_ACTIVE:
				(groups["active"] as Array).append(row)
			STATUS_COMPLETABLE:
				(groups["completable"] as Array).append(row)
			STATUS_COMPLETED:
				(groups["completed"] as Array).append(row)
			STATUS_FAILED:
				(groups["failed"] as Array).append(row)
	result["groups"] = groups
	return result

func snapshot_state() -> Dictionary:
	return {"version": VERSION, "owners": _owners.duplicate(true)}

func restore_state(value: Variant) -> bool:
	if not validate_state(value):
		return false
	var state: Dictionary = value
	for owner_id in state["owners"]:
		if not _inventory.has_owner(str(owner_id)):
			return false
	_owners = (state["owners"] as Dictionary).duplicate(true)
	return true

static func empty_state() -> Dictionary:
	return {"version": VERSION, "owners": {}}

static func empty_journal(owner_id: String = "entity.player") -> Dictionary:
	return {
		"version": JOURNAL_VERSION,
		"owner_id": owner_id,
		"groups": {"available": [], "active": [], "completable": [], "completed": [], "failed": []},
	}

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 2 or int(state.get("version", 0)) != VERSION or not state.get("owners") is Dictionary:
		return false
	var owners: Dictionary = state["owners"]
	if owners.size() > MAX_OWNERS:
		return false
	for owner_id in owners:
		if not owner_id is String or not SectorIds.valid(owner_id) or not owners[owner_id] is Dictionary:
			return false
		var owner: Dictionary = owners[owner_id]
		if owner.size() != 3 or not owner.get("quests") is Dictionary or not owner.get("objective_events") is Dictionary or not owner.get("cycles") is Dictionary:
			return false
		if owner["quests"].size() > MAX_QUESTS or owner["objective_events"].size() > MAX_EVENTS or owner["cycles"].size() > MAX_QUESTS:
			return false
		for event_id in owner["objective_events"]:
			if not event_id is String or not SectorIds.valid(event_id) or not owner["objective_events"][event_id] is String or str(owner["objective_events"][event_id]).length() != 64:
				return false
		for quest_id in owner["cycles"]:
			if not quest_id is String or not SectorIds.valid(quest_id) or not _integer(owner["cycles"][quest_id]) or int(owner["cycles"][quest_id]) <= 0:
				return false
		for quest_id in owner["quests"]:
			if not quest_id is String or not SectorIds.valid(quest_id) or not _valid_instance(owner["quests"][quest_id]):
				return false
	return true

static func validate_journal(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var journal: Dictionary = value
	if journal.size() != 3 or int(journal.get("version", 0)) != JOURNAL_VERSION or not journal.get("owner_id") is String or not SectorIds.valid(str(journal["owner_id"])) or not journal.get("groups") is Dictionary:
		return false
	var groups: Dictionary = journal["groups"]
	var expected := ["available", "active", "completable", "completed", "failed"]
	if groups.size() != expected.size():
		return false
	var seen: Dictionary = {}
	for group in expected:
		if not groups.has(group) or not groups[group] is Array or (groups[group] as Array).size() > MAX_QUESTS:
			return false
		for raw in groups[group]:
			if not raw is Dictionary:
				return false
			var row: Dictionary = raw
			var keys := ["quest_id", "status", "title", "description", "quest_type", "objectives", "reward_preview", "region_ids", "sector_ids", "remaining_ticks"]
			if row.size() != keys.size():
				return false
			for key in keys:
				if not row.has(key):
					return false
			if not row["quest_id"] is String or not SectorIds.valid(str(row["quest_id"])) or seen.has(row["quest_id"]):
				return false
			if not row["status"] is String:
				return false
			var expected_status: String = str({"available": "available", "active": STATUS_ACTIVE, "completable": STATUS_COMPLETABLE, "completed": STATUS_COMPLETED, "failed": STATUS_FAILED}[group])
			if str(row["status"]) != str(expected_status):
				return false
			if not row["objectives"] is Array or not row["reward_preview"] is Dictionary or not row["region_ids"] is Array or not row["sector_ids"] is Array or not _integer(row["remaining_ticks"]):
				return false
			seen[row["quest_id"]] = true
	return true

static func validate_content_refs(value: Variant, registry: DefinitionRegistry) -> bool:
	if registry == null or not validate_state(value):
		return false
	var owners: Dictionary = (value as Dictionary)["owners"]
	for owner_id in owners:
		var owner: Dictionary = owners[owner_id]
		for quest_id in owner["quests"]:
			if not registry.matches_type(str(quest_id), "quest"):
				return false
		for quest_id in owner["cycles"]:
			if not registry.matches_type(str(quest_id), "quest"):
				return false
	return true

func _accept(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["quest_id", "npc_id"]):
		return _reject(OP_ACCEPT, "malformed_payload")
	var quest_id := str(payload["quest_id"])
	var npc_id := str(payload["npc_id"])
	if not _quests.has(quest_id) or not _npc_interaction_valid(owner_id, npc_id):
		return _reject(OP_ACCEPT, "invalid_npc_interaction")
	var definition := _quests[quest_id] as QuestDefinition
	if npc_id != definition.start_npc_id:
		return _reject(OP_ACCEPT, "invalid_start_npc")
	var reason := availability_reason(owner_id, quest_id)
	if not reason.is_empty():
		return _reject(OP_ACCEPT, reason)
	var owner: Dictionary = _owners[owner_id]
	var cycles: Dictionary = owner["cycles"]
	var cycle := int(cycles.get(quest_id, 0)) + 1
	cycles[quest_id] = cycle
	var context: Dictionary = _contexts[owner_id]
	var quests: Dictionary = owner["quests"]
	quests[quest_id] = _new_instance(definition, cycle, int(context["tick"]))
	owner["cycles"] = cycles
	owner["quests"] = quests
	_owners[owner_id] = owner
	return {"accepted": true, "reason": "", "operation": OP_ACCEPT, "quest_id": quest_id, "status": STATUS_ACTIVE, "journal": journal_snapshot(owner_id)}

func _turn_in(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["quest_id", "npc_id"]):
		return _reject(OP_TURN_IN, "malformed_payload")
	var quest_id := str(payload["quest_id"])
	var npc_id := str(payload["npc_id"])
	if not _quests.has(quest_id) or not _npc_interaction_valid(owner_id, npc_id):
		return _reject(OP_TURN_IN, "invalid_npc_interaction")
	var definition := _quests[quest_id] as QuestDefinition
	if npc_id != definition.turn_in_npc_id:
		return _reject(OP_TURN_IN, "invalid_turn_in_npc")
	var owner: Dictionary = _owners[owner_id]
	var quests: Dictionary = owner["quests"]
	if not quests.has(quest_id):
		return _reject(OP_TURN_IN, "quest_not_active")
	var instance: Dictionary = quests[quest_id]
	if str(instance["status"]) != STATUS_COMPLETABLE or bool(instance["reward_claimed"]):
		return _reject(OP_TURN_IN, "quest_not_completable")
	var before_quantities: Dictionary = _inventory.quantities_snapshot(owner_id)
	var before_prg03: Dictionary = _inventory.prg03_state_snapshot()
	var reward_result := _apply_rewards(owner_id, definition, int(instance["cycle"]))
	if not bool(reward_result["accepted"]):
		var quantities_ok: bool = _inventory.restore_quantities(owner_id, before_quantities)
		var prg03_ok: bool = _inventory.restore_prg03_state(before_prg03)
		if not quantities_ok or not prg03_ok:
			return _reject(OP_TURN_IN, "reward_rollback_failed")
		return _reject(OP_TURN_IN, str(reward_result["reason"]))
	instance["status"] = STATUS_COMPLETED
	instance["reward_claimed"] = true
	instance["completed_version"] = definition.version_key
	instance["completed_tick"] = int((_contexts[owner_id] as Dictionary)["tick"])
	quests[quest_id] = instance
	owner["quests"] = quests
	_owners[owner_id] = owner
	return {
		"accepted": true,
		"reason": "",
		"operation": OP_TURN_IN,
		"quest_id": quest_id,
		"status": STATUS_COMPLETED,
		"reward": reward_result["reward"],
		"journal": journal_snapshot(owner_id),
	}

func _apply_rewards(owner_id: String, definition: QuestDefinition, cycle: int) -> Dictionary:
	var deltas: Dictionary = {}
	for reward in definition.reward_items:
		var item_id := str(reward["item_id"])
		deltas[item_id] = int(deltas.get(item_id, 0)) + int(reward["quantity"])
	if not deltas.is_empty() and not _inventory.can_apply_item_deltas(owner_id, deltas):
		return {"accepted": false, "reason": "reward_capacity", "reward": {}}
	if not deltas.is_empty() and not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return {"accepted": false, "reason": "reward_item_commit_failed", "reward": {}}
	if definition.xp_reward > 0:
		var xp_event := "event.xp.quest.%s.cycle%d" % [definition.stable_id, cycle]
		var xp_result: Dictionary = _inventory.grant_xp_authoritative(owner_id, xp_event, "quest", definition.xp_reward)
		if not bool(xp_result.get("accepted", false)):
			return {"accepted": false, "reason": "reward_xp_failed", "reward": {}}
	for gate_id in definition.reward_gate_ids:
		if _inventory.progression_gate_completed(owner_id, str(gate_id)):
			continue
		var gate_result: Dictionary = _inventory.complete_progression_gate_authoritative(owner_id, str(gate_id))
		if not bool(gate_result.get("accepted", false)):
			return {"accepted": false, "reason": "reward_gate_failed", "reward": {}}
	return {
		"accepted": true,
		"reason": "",
		"reward": {
			"items": definition.reward_items.duplicate(true),
			"xp": definition.xp_reward,
			"gates": Array(definition.reward_gate_ids),
			"event_refs": Array(definition.reward_event_refs),
		},
	}

func _matching_objective_index(definition: QuestDefinition, instance: Dictionary, event: Dictionary) -> int:
	var progress: Dictionary = instance["progress"]
	var first_incomplete := -1
	for index in definition.objectives.size():
		var objective: Dictionary = definition.objectives[index]
		if int(progress.get(str(objective["objective_id"]), 0)) < int(objective["required_value"]):
			first_incomplete = index
			break
	for index in definition.objectives.size():
		var objective: Dictionary = definition.objectives[index]
		if definition.ordered_objectives and index != first_incomplete:
			continue
		if int(progress.get(str(objective["objective_id"]), 0)) >= int(objective["required_value"]):
			continue
		if str(objective["objective_type"]) != str(event["objective_type"]):
			continue
		var target_id := str(objective["target_id"])
		var source_id := str(objective["source_id"])
		var region_id := str(objective["region_id"])
		if not target_id.is_empty() and target_id != str(event["target_id"]):
			continue
		if not source_id.is_empty() and source_id != str(event["source_id"]):
			continue
		if not region_id.is_empty() and region_id != str(event["region_id"]):
			continue
		return index
	return -1

func _all_objectives_complete(definition: QuestDefinition, instance: Dictionary) -> bool:
	var progress: Dictionary = instance["progress"]
	for objective in definition.objectives:
		if int(progress.get(str(objective["objective_id"]), 0)) < int(objective["required_value"]):
			return false
	return true

func _quest_event_context_matches(definition: QuestDefinition, event: Dictionary) -> bool:
	if not definition.sector_ids.is_empty() and not definition.sector_ids.has(str(event["sector_id"])):
		return false
	if not definition.region_ids.is_empty() and not definition.region_ids.has(str(event["region_id"])):
		return false
	return true

func _definition_context_matches(definition: QuestDefinition, context: Dictionary) -> bool:
	if not definition.sector_ids.is_empty() and not definition.sector_ids.has(str(context["sector_id"])):
		return false
	if not definition.region_ids.is_empty() and not definition.region_ids.has(str(context["region_id"])):
		return false
	return true

func _npc_interaction_valid(owner_id: String, npc_id: String) -> bool:
	if not _npc_refs.has(npc_id):
		return false
	var context: Dictionary = _contexts.get(owner_id, {})
	return not context.is_empty() and (context["nearby_npcs"] as Dictionary).has(npc_id)

func _actor_eligible(owner_id: String, actor_id: String, policy: String) -> bool:
	if actor_id == owner_id:
		return true
	if policy == "owner_only":
		return false
	return (_party_members.get(owner_id, {}) as Dictionary).has(actor_id)

func _journal_row(owner_id: String, definition: QuestDefinition, instance: Dictionary, status: String) -> Dictionary:
	var objective_rows: Array[Dictionary] = []
	var progress: Dictionary = instance.get("progress", {}) if not instance.is_empty() else {}
	for objective in definition.objectives:
		objective_rows.append({
			"objective_id": str(objective["objective_id"]),
			"objective_type": str(objective["objective_type"]),
			"current": int(progress.get(str(objective["objective_id"]), 0)),
			"required": int(objective["required_value"]),
			"target_id": str(objective["target_id"]),
			"region_id": str(objective["region_id"]),
		})
	var remaining := -1
	if not instance.is_empty() and int(instance.get("deadline_tick", -1)) >= 0:
		var context_tick := int((_contexts.get(owner_id, {}) as Dictionary).get("tick", int(instance.get("last_tick", 0))))
		remaining = maxi(0, int(instance["deadline_tick"]) - context_tick)
	return {
		"quest_id": definition.stable_id,
		"status": status,
		"title": definition.title,
		"description": definition.description,
		"quest_type": definition.quest_type,
		"objectives": objective_rows,
		"reward_preview": {"items": definition.reward_items.duplicate(true), "xp": definition.xp_reward, "gates": Array(definition.reward_gate_ids), "event_refs": Array(definition.reward_event_refs)},
		"region_ids": Array(definition.region_ids),
		"sector_ids": Array(definition.sector_ids),
		"remaining_ticks": remaining,
	}

func _new_instance(definition: QuestDefinition, cycle: int, tick: int) -> Dictionary:
	var progress: Dictionary = {}
	for objective in definition.objectives:
		progress[str(objective["objective_id"])] = 0
	return {
		"status": STATUS_ACTIVE,
		"progress": progress,
		"accepted_version": definition.version_key,
		"completed_version": "",
		"accepted_tick": tick,
		"completed_tick": -1,
		"deadline_tick": tick + definition.time_limit_ticks if definition.time_limit_ticks > 0 else -1,
		"last_tick": tick,
		"reward_claimed": false,
		"cycle": cycle,
	}

func _visit_quest(quest_id: String, colors: Dictionary) -> bool:
	var color := int(colors.get(quest_id, 0))
	if color == 1:
		return true
	if color == 2:
		return false
	colors[quest_id] = 1
	var definition := _quests[quest_id] as QuestDefinition
	for prerequisite in definition.prerequisite_quest_ids:
		if _quests.has(prerequisite) and _visit_quest(str(prerequisite), colors):
			return true
	colors[quest_id] = 2
	return false

static func _valid_event(event: Dictionary) -> bool:
	var keys := ["event_id", "actor_id", "objective_type", "target_id", "source_id", "quantity", "sector_id", "region_id", "tick", "outcome"]
	if not _exact(event, keys):
		return false
	for key in ["event_id", "actor_id", "objective_type", "target_id", "source_id", "sector_id", "region_id", "outcome"]:
		if not event[key] is String:
			return false
	if not SectorIds.valid(str(event["event_id"])) or not SectorIds.valid(str(event["actor_id"])) or str(event["objective_type"]) not in QuestDefinition.OBJECTIVE_TYPES:
		return false
	for key in ["target_id", "source_id"]:
		var value := str(event[key])
		if not value.is_empty() and not SectorIds.valid(value):
			return false
	for key in ["sector_id", "region_id"]:
		if str(event[key]).is_empty() or not SectorIds.valid(str(event[key])):
			return false
	if not _integer(event["quantity"]) or int(event["quantity"]) <= 0 or int(event["quantity"]) > MAX_PROGRESS:
		return false
	if not _integer(event["tick"]) or int(event["tick"]) < 0:
		return false
	if str(event["outcome"]) not in ["", "success", "failure"]:
		return false
	return true

static func _valid_instance(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var row: Dictionary = value
	var keys := ["status", "progress", "accepted_version", "completed_version", "accepted_tick", "completed_tick", "deadline_tick", "last_tick", "reward_claimed", "cycle"]
	if row.size() != keys.size():
		return false
	for key in keys:
		if not row.has(key):
			return false
	if not row["status"] is String or str(row["status"]) not in STORED_STATUSES or not row["progress"] is Dictionary or not row["accepted_version"] is String or not row["completed_version"] is String or not row["reward_claimed"] is bool:
		return false
	if not SectorIds.valid(str(row["accepted_version"])) or (not str(row["completed_version"]).is_empty() and not SectorIds.valid(str(row["completed_version"]))):
		return false
	for key in ["accepted_tick", "completed_tick", "deadline_tick", "last_tick", "cycle"]:
		if not _integer(row[key]):
			return false
	if int(row["accepted_tick"]) < 0 or int(row["completed_tick"]) < -1 or int(row["deadline_tick"]) < -1 or int(row["last_tick"]) < 0 or int(row["cycle"]) <= 0:
		return false
	if (row["progress"] as Dictionary).size() > QuestDefinition.MAX_OBJECTIVES:
		return false
	for objective_id in row["progress"]:
		if not objective_id is String or not SectorIds.valid(objective_id) or not _integer(row["progress"][objective_id]) or int(row["progress"][objective_id]) < 0 or int(row["progress"][objective_id]) > MAX_PROGRESS:
			return false
	return true

static func _register_ref(target: Dictionary, stable_id: String) -> bool:
	if not SectorIds.valid(stable_id) or target.has(stable_id):
		return false
	target[stable_id] = true
	return true

func _ensure_owner(owner_id: String) -> bool:
	return _owners.has(owner_id) or bind_owner(owner_id)

static func _empty_owner() -> Dictionary:
	return {"quests": {}, "objective_events": {}, "cycles": {}}

static func _reject(operation: String, reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "operation": operation}

static func _integer(value: Variant) -> bool:
	if typeof(value) == TYPE_INT:
		return true
	if typeof(value) != TYPE_FLOAT:
		return false
	var number := float(value)
	return is_finite(number) and floor(number) == number

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	return value

static func _sorted_keys(source: Dictionary) -> Array:
	var keys := source.keys()
	keys.sort()
	return keys
