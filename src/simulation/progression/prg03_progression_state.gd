class_name Prg03ProgressionState
extends RefCounted

const VERSION := 1
const MAX_XP := 2147483647
const MAX_OWNERS := 32
const MAX_EVENTS := 256
const MAX_DEFINITIONS := 128
const MAX_SKILLS := 128
const MAX_GATES := 128
const MAX_CHALLENGES := 128

const OP_SKILL_SPEND := "progression_skill_spend"
const OP_RESPEC := "progression_respec"
const OP_GATE_COMPLETE := "progression_gate_complete"
const OP_CHALLENGE_EVENT := "progression_challenge_event"
const OPERATIONS := [OP_SKILL_SPEND, OP_RESPEC, OP_GATE_COMPLETE, OP_CHALLENGE_EVENT]

var _inventory
var _ranks: Dictionary = {}
var _skills: Dictionary = {}
var _gates: Dictionary = {}
var _challenges: Dictionary = {}
var _owners: Dictionary = {}

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
	return true

func register_rank(definition: ProgressionRankDefinition) -> bool:
	if definition == null or not definition.valid() or _definition_count() >= MAX_DEFINITIONS or _ranks.has(definition.stable_id):
		return false
	_ranks[definition.stable_id] = definition
	return true

func register_skill(definition: ProgressionSkillDefinition) -> bool:
	if definition == null or not definition.valid() or _definition_count() >= MAX_DEFINITIONS or _skills.has(definition.stable_id):
		return false
	_skills[definition.stable_id] = definition
	return true

func register_gate(definition: ProgressionGateDefinition) -> bool:
	if definition == null or not definition.valid() or _definition_count() >= MAX_DEFINITIONS or _gates.has(definition.stable_id):
		return false
	for row in definition.rewards:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_gates[definition.stable_id] = definition
	return true

func register_challenge(definition: LocalChallengeDefinition) -> bool:
	if definition == null or not definition.valid() or _definition_count() >= MAX_DEFINITIONS or _challenges.has(definition.stable_id):
		return false
	for row in definition.rewards:
		if not _inventory.has_item_spec(str(row["item_id"])):
			return false
	_challenges[definition.stable_id] = definition
	return true

func validate_catalog() -> String:
	var rank_rows: Array[ProgressionRankDefinition] = []
	var thresholds: Dictionary = {}
	var modifier_sources: Dictionary = {}
	for rank_id in _ranks:
		var rank := _ranks[rank_id] as ProgressionRankDefinition
		if thresholds.has(rank.xp_threshold):
			return "duplicate_rank_threshold"
		thresholds[rank.xp_threshold] = true
		if not rank.prerequisite_gate_id.is_empty() and not _gates.has(rank.prerequisite_gate_id):
			return "missing_rank_gate"
		for row in rank.modifiers:
			var source_id := str(row["source_id"])
			if modifier_sources.has(source_id):
				return "duplicate_modifier_source"
			modifier_sources[source_id] = true
		rank_rows.append(rank)
	rank_rows.sort_custom(func(a: ProgressionRankDefinition, b: ProgressionRankDefinition): return a.xp_threshold < b.xp_threshold)
	if not rank_rows.is_empty() and rank_rows[0].xp_threshold != 0:
		return "unreachable_rank"
	for skill_id in _skills:
		var skill := _skills[skill_id] as ProgressionSkillDefinition
		for prerequisite in skill.prerequisite_ids:
			if not _skills.has(prerequisite):
				return "missing_skill_prerequisite"
		if not skill.gate_id.is_empty() and not _gates.has(skill.gate_id):
			return "missing_skill_gate"
		for row in skill.modifiers:
			var source_id := str(row["source_id"])
			if modifier_sources.has(source_id):
				return "duplicate_modifier_source"
			modifier_sources[source_id] = true
	var skill_colors: Dictionary = {}
	for skill_id in _sorted_keys(_skills):
		if _visit_skill(str(skill_id), skill_colors):
			return "skill_cycle"
	for skill_id in _skills:
		var skill := _skills[skill_id] as ProgressionSkillDefinition
		for prerequisite in skill.prerequisite_ids:
			if (_skills[prerequisite] as ProgressionSkillDefinition).tier >= skill.tier:
				return "skill_tier_regression"
	for gate_id in _gates:
		var gate := _gates[gate_id] as ProgressionGateDefinition
		for prerequisite in gate.prerequisite_gate_ids:
			if not _gates.has(prerequisite):
				return "missing_gate_prerequisite"
		if not gate.required_rank_id.is_empty() and not _ranks.has(gate.required_rank_id):
			return "missing_gate_rank"
	var gate_colors: Dictionary = {}
	for gate_id in _sorted_keys(_gates):
		if _visit_gate(str(gate_id), gate_colors):
			return "gate_cycle"
	return ""

func grant_xp_authoritative(owner_id: String, event_id: String, source: String, amount: int) -> Dictionary:
	var result := {"accepted": false, "reason": "", "duplicate": false, "total_xp": 0}
	if not _ensure_owner(owner_id) or not SectorIds.valid(event_id) or source.is_empty() or source.length() > 64 or amount <= 0:
		result["reason"] = "invalid_xp_event"
		return result
	var owner: Dictionary = _owners[owner_id]
	var events: Dictionary = owner["xp_events"]
	var fingerprint := (source + "|" + str(amount)).sha256_text()
	if events.has(event_id):
		var row: Dictionary = events[event_id]
		if str(row["fingerprint"]) != fingerprint:
			result["reason"] = "xp_event_conflict"
			result["total_xp"] = int(owner["total_xp"])
			return result
		result["accepted"] = true
		result["duplicate"] = true
		result["total_xp"] = int(owner["total_xp"])
		return result
	if events.size() >= MAX_EVENTS or amount > MAX_XP - int(owner["total_xp"]):
		result["reason"] = "xp_overflow" if amount > MAX_XP - int(owner["total_xp"]) else "xp_ledger_full"
		result["total_xp"] = int(owner["total_xp"])
		return result
	owner["total_xp"] = int(owner["total_xp"]) + amount
	events[event_id] = {"source": source, "amount": amount, "fingerprint": fingerprint}
	owner["xp_events"] = events
	_owners[owner_id] = owner
	result["accepted"] = true
	result["total_xp"] = int(owner["total_xp"])
	return result

func execute(actor_id: String, operation: String, payload: Dictionary) -> Dictionary:
	if not supports_operation(operation) or not _ensure_owner(actor_id):
		return _reject(operation, "progression_unavailable")
	var catalog_error := validate_catalog()
	if not catalog_error.is_empty():
		return _reject(operation, catalog_error)
	match operation:
		OP_SKILL_SPEND:
			return _skill_spend(actor_id, payload)
		OP_RESPEC:
			return _respec(actor_id, payload)
		OP_GATE_COMPLETE:
			return _gate_complete(actor_id, payload)
		OP_CHALLENGE_EVENT:
			return _challenge_event(actor_id, payload)
	return _reject(operation, "unsupported_operation")

func total_xp(owner_id: String) -> int:
	return int((_owners.get(owner_id, {}) as Dictionary).get("total_xp", 0))

func current_rank_id(owner_id: String) -> String:
	var xp := total_xp(owner_id)
	var best_id := ""
	var best_threshold := -1
	for rank_id in _ranks:
		var rank := _ranks[rank_id] as ProgressionRankDefinition
		if rank.xp_threshold <= xp and rank.xp_threshold >= best_threshold:
			if rank.prerequisite_gate_id.is_empty() or gate_completed(owner_id, rank.prerequisite_gate_id):
				best_id = str(rank_id)
				best_threshold = rank.xp_threshold
	return best_id

func available_skill_points(owner_id: String) -> int:
	if not _ensure_owner(owner_id):
		return 0
	var earned := 0
	var xp := total_xp(owner_id)
	for rank_id in _ranks:
		var rank := _ranks[rank_id] as ProgressionRankDefinition
		if rank.xp_threshold <= xp:
			earned += rank.skill_point_grant
	var spent := 0
	var ranks: Dictionary = (_owners[owner_id] as Dictionary)["skill_ranks"]
	for skill_id in ranks:
		if _skills.has(skill_id):
			spent += int(ranks[skill_id]) * (_skills[skill_id] as ProgressionSkillDefinition).point_cost
	return maxi(0, earned - spent)

func skill_rank(owner_id: String, skill_id: String) -> int:
	if not _owners.has(owner_id):
		return 0
	return int(((_owners[owner_id] as Dictionary)["skill_ranks"] as Dictionary).get(skill_id, 0))

func gate_completed(owner_id: String, gate_id: String) -> bool:
	if not _owners.has(owner_id):
		return false
	return bool(((_owners[owner_id] as Dictionary)["completed_gates"] as Dictionary).get(gate_id, false))

func challenge_snapshot(owner_id: String) -> Dictionary:
	if not _owners.has(owner_id):
		return {}
	return (((_owners[owner_id] as Dictionary)["challenges"]) as Dictionary).duplicate(true)

func append_stat_modifiers(owner_id: String, stat_id: String, target: Dictionary) -> void:
	if not _ensure_owner(owner_id):
		return
	var rank_id := current_rank_id(owner_id)
	if not rank_id.is_empty() and _ranks.has(rank_id):
		for row in (_ranks[rank_id] as ProgressionRankDefinition).modifiers:
			_append_modifier(target, row, stat_id, str(row["source_id"]))
	var ranks: Dictionary = (_owners[owner_id] as Dictionary)["skill_ranks"]
	for skill_id in _sorted_keys(ranks):
		if not _skills.has(skill_id):
			continue
		var learned := int(ranks[skill_id])
		for row in (_skills[skill_id] as ProgressionSkillDefinition).modifiers:
			for level in range(learned):
				_append_modifier(target, row, stat_id, "%s.r%d" % [str(row["source_id"]), level + 1])

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
		var row: Dictionary = owners[owner_id]
		if row.size() != 5:
			return false
		if not row.get("total_xp") is int or int(row["total_xp"]) < 0 or int(row["total_xp"]) > MAX_XP:
			return false
		for key in ["xp_events", "skill_ranks", "completed_gates", "challenges"]:
			if not row.get(key) is Dictionary:
				return false
		if row["xp_events"].size() > MAX_EVENTS or row["skill_ranks"].size() > MAX_SKILLS or row["completed_gates"].size() > MAX_GATES or row["challenges"].size() > MAX_CHALLENGES:
			return false
		for event_id in row["xp_events"]:
			if not event_id is String or not SectorIds.valid(event_id) or not row["xp_events"][event_id] is Dictionary:
				return false
			var event: Dictionary = row["xp_events"][event_id]
			if event.size() != 3 or not event.get("source") is String or not event.get("amount") is int or not event.get("fingerprint") is String:
				return false
			if str(event["source"]).is_empty() or int(event["amount"]) <= 0 or str(event["fingerprint"]).length() != 64:
				return false
		for skill_id in row["skill_ranks"]:
			if not skill_id is String or not SectorIds.valid(skill_id) or not row["skill_ranks"][skill_id] is int or int(row["skill_ranks"][skill_id]) <= 0 or int(row["skill_ranks"][skill_id]) > 8:
				return false
		for gate_id in row["completed_gates"]:
			if not gate_id is String or not SectorIds.valid(gate_id) or row["completed_gates"][gate_id] != true:
				return false
		for challenge_id in row["challenges"]:
			if not challenge_id is String or not SectorIds.valid(challenge_id) or not row["challenges"][challenge_id] is Dictionary:
				return false
			var challenge: Dictionary = row["challenges"][challenge_id]
			if challenge.size() != 4 or not challenge.get("version_key") is String or not challenge.get("progress") is int or not challenge.get("rewarded") is bool or not challenge.get("events") is Dictionary:
				return false
			if not SectorIds.valid(str(challenge["version_key"])) or int(challenge["progress"]) < 0 or int(challenge["progress"]) > LocalChallengeDefinition.MAX_TARGET or challenge["events"].size() > MAX_EVENTS:
				return false
			for event_id in challenge["events"]:
				if not event_id is String or not SectorIds.valid(event_id) or challenge["events"][event_id] != true:
					return false
	return true

static func validate_content_refs(value: Variant, registry: DefinitionRegistry) -> bool:
	if registry == null or not validate_state(value):
		return false
	var owners: Dictionary = (value as Dictionary)["owners"]
	for owner_id in owners:
		var row: Dictionary = owners[owner_id]
		for skill_id in row["skill_ranks"]:
			if not registry.matches_type(str(skill_id), "progression_skill"):
				return false
		for gate_id in row["completed_gates"]:
			if not registry.matches_type(str(gate_id), "progression_gate"):
				return false
		for challenge_id in row["challenges"]:
			if not registry.matches_type(str(challenge_id), "local_challenge"):
				return false
	return true

func _skill_spend(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["skill_id"]):
		return _reject(OP_SKILL_SPEND, "malformed_payload")
	var skill_id := str(payload["skill_id"])
	if not _skills.has(skill_id):
		return _reject(OP_SKILL_SPEND, "invalid_skill")
	var definition := _skills[skill_id] as ProgressionSkillDefinition
	var owner: Dictionary = _owners[owner_id]
	var ranks: Dictionary = owner["skill_ranks"]
	var current := int(ranks.get(skill_id, 0))
	if current >= definition.max_rank:
		return _reject(OP_SKILL_SPEND, "max_rank")
	for prerequisite in definition.prerequisite_ids:
		if int(ranks.get(prerequisite, 0)) <= 0:
			return _reject(OP_SKILL_SPEND, "prerequisite_missing")
	if not definition.gate_id.is_empty() and not gate_completed(owner_id, definition.gate_id):
		return _reject(OP_SKILL_SPEND, "gate_locked")
	if available_skill_points(owner_id) < definition.point_cost:
		return _reject(OP_SKILL_SPEND, "insufficient_points")
	ranks[skill_id] = current + 1
	owner["skill_ranks"] = ranks
	_owners[owner_id] = owner
	return {"accepted": true, "reason": "", "operation": OP_SKILL_SPEND, "skill_id": skill_id, "rank": current + 1, "points": available_skill_points(owner_id)}

func _respec(owner_id: String, payload: Dictionary) -> Dictionary:
	if not payload.is_empty():
		return _reject(OP_RESPEC, "malformed_payload")
	var owner: Dictionary = _owners[owner_id]
	var refunded := 0
	var ranks: Dictionary = owner["skill_ranks"]
	for skill_id in ranks:
		if _skills.has(skill_id):
			refunded += int(ranks[skill_id]) * (_skills[skill_id] as ProgressionSkillDefinition).point_cost
	owner["skill_ranks"] = {}
	_owners[owner_id] = owner
	return {"accepted": true, "reason": "", "operation": OP_RESPEC, "refunded_points": refunded, "points": available_skill_points(owner_id)}

func _gate_complete(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["gate_id"]):
		return _reject(OP_GATE_COMPLETE, "malformed_payload")
	var gate_id := str(payload["gate_id"])
	if not _gates.has(gate_id):
		return _reject(OP_GATE_COMPLETE, "invalid_gate")
	if gate_completed(owner_id, gate_id):
		return _reject(OP_GATE_COMPLETE, "already_completed")
	var definition := _gates[gate_id] as ProgressionGateDefinition
	for prerequisite in definition.prerequisite_gate_ids:
		if not gate_completed(owner_id, prerequisite):
			return _reject(OP_GATE_COMPLETE, "prerequisite_missing")
	if not definition.required_rank_id.is_empty():
		var required := _ranks[definition.required_rank_id] as ProgressionRankDefinition
		if total_xp(owner_id) < required.xp_threshold:
			return _reject(OP_GATE_COMPLETE, "rank_locked")
	var deltas := _reward_deltas(definition.rewards)
	if deltas == null or not _inventory.can_apply_item_deltas(owner_id, deltas):
		return _reject(OP_GATE_COMPLETE, "reward_capacity")
	if definition.xp_reward > 0 and not _can_grant_xp(owner_id, _gate_xp_event(gate_id), definition.xp_reward):
		return _reject(OP_GATE_COMPLETE, "xp_reward_rejected")
	if not deltas.is_empty() and not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_GATE_COMPLETE, "atomic_commit_failed")
	if definition.xp_reward > 0:
		var xp_result := grant_xp_authoritative(owner_id, _gate_xp_event(gate_id), "gate", definition.xp_reward)
		if not xp_result["accepted"]:
			return _reject(OP_GATE_COMPLETE, "xp_reward_rejected")
	var owner: Dictionary = _owners[owner_id]
	(owner["completed_gates"] as Dictionary)[gate_id] = true
	_owners[owner_id] = owner
	return {"accepted": true, "reason": "", "operation": OP_GATE_COMPLETE, "gate_id": gate_id}

func _challenge_event(owner_id: String, payload: Dictionary) -> Dictionary:
	if not _exact(payload, ["challenge_id", "event_id"]):
		return _reject(OP_CHALLENGE_EVENT, "malformed_payload")
	var challenge_id := str(payload["challenge_id"])
	var event_id := str(payload["event_id"])
	if not _challenges.has(challenge_id) or not SectorIds.valid(event_id):
		return _reject(OP_CHALLENGE_EVENT, "invalid_challenge")
	var definition := _challenges[challenge_id] as LocalChallengeDefinition
	var owner: Dictionary = _owners[owner_id]
	var challenges: Dictionary = owner["challenges"]
	var row: Dictionary = challenges.get(challenge_id, _empty_challenge(definition.version_key))
	if str(row["version_key"]) != definition.version_key:
		row = _empty_challenge(definition.version_key)
	if bool(row["rewarded"]) and definition.recurrence_policy == "once":
		return _reject(OP_CHALLENGE_EVENT, "already_completed")
	var events: Dictionary = row["events"]
	if events.has(event_id):
		return _reject(OP_CHALLENGE_EVENT, "challenge_event_processed")
	if events.size() >= MAX_EVENTS:
		return _reject(OP_CHALLENGE_EVENT, "challenge_ledger_full")
	var next_progress := mini(definition.target_value, int(row["progress"]) + 1)
	var completes := next_progress >= definition.target_value and not bool(row["rewarded"])
	var deltas: Dictionary = {}
	if completes:
		var candidate = _reward_deltas(definition.rewards)
		if candidate == null:
			return _reject(OP_CHALLENGE_EVENT, "invalid_reward")
		deltas = candidate
		if not _inventory.can_apply_item_deltas(owner_id, deltas):
			return _reject(OP_CHALLENGE_EVENT, "reward_capacity")
		if definition.xp_reward > 0 and not _can_grant_xp(owner_id, _challenge_xp_event(challenge_id, definition.version_key), definition.xp_reward):
			return _reject(OP_CHALLENGE_EVENT, "xp_reward_rejected")
	if completes and not deltas.is_empty() and not _inventory.apply_item_deltas_atomic(owner_id, deltas):
		return _reject(OP_CHALLENGE_EVENT, "atomic_commit_failed")
	if completes and definition.xp_reward > 0:
		var xp_result := grant_xp_authoritative(owner_id, _challenge_xp_event(challenge_id, definition.version_key), "challenge", definition.xp_reward)
		if not xp_result["accepted"]:
			return _reject(OP_CHALLENGE_EVENT, "xp_reward_rejected")
	row["progress"] = next_progress
	events[event_id] = true
	row["events"] = events
	if completes:
		row["rewarded"] = true
	challenges[challenge_id] = row
	owner = _owners[owner_id]
	owner["challenges"] = challenges
	_owners[owner_id] = owner
	return {"accepted": true, "reason": "", "operation": OP_CHALLENGE_EVENT, "challenge_id": challenge_id, "progress": next_progress, "completed": bool(row["rewarded"])}

func _can_grant_xp(owner_id: String, event_id: String, amount: int) -> bool:
	if not _ensure_owner(owner_id) or not SectorIds.valid(event_id) or amount <= 0:
		return false
	var owner: Dictionary = _owners[owner_id]
	var events: Dictionary = owner["xp_events"]
	return not events.has(event_id) and events.size() < MAX_EVENTS and amount <= MAX_XP - int(owner["total_xp"])

func _reward_deltas(rewards: Array[Dictionary]) -> Variant:
	var deltas: Dictionary = {}
	for row in rewards:
		var item_id := str(row["item_id"])
		var amount := int(row["quantity"])
		if not _inventory.has_item_spec(item_id) or amount <= 0:
			return null
		deltas[item_id] = int(deltas.get(item_id, 0)) + amount
	return deltas

func _visit_skill(skill_id: String, colors: Dictionary) -> bool:
	var color := int(colors.get(skill_id, 0))
	if color == 1:
		return true
	if color == 2:
		return false
	colors[skill_id] = 1
	for prerequisite in (_skills[skill_id] as ProgressionSkillDefinition).prerequisite_ids:
		if _visit_skill(prerequisite, colors):
			return true
	colors[skill_id] = 2
	return false

func _visit_gate(gate_id: String, colors: Dictionary) -> bool:
	var color := int(colors.get(gate_id, 0))
	if color == 1:
		return true
	if color == 2:
		return false
	colors[gate_id] = 1
	for prerequisite in (_gates[gate_id] as ProgressionGateDefinition).prerequisite_gate_ids:
		if _visit_gate(prerequisite, colors):
			return true
	colors[gate_id] = 2
	return false

func _append_modifier(target: Dictionary, row: Dictionary, stat_id: String, source_id: String) -> void:
	if str(row.get("stat", "")) != stat_id or target.has(source_id):
		return
	target[source_id] = {"operation": row["operation"], "value": row["value"], "priority": row.get("priority", 0)}

func _ensure_owner(owner_id: String) -> bool:
	return _owners.has(owner_id) or bind_owner(owner_id)

func _definition_count() -> int:
	return _ranks.size() + _skills.size() + _gates.size() + _challenges.size()

func _gate_xp_event(gate_id: String) -> String:
	return "event.xp." + gate_id

func _challenge_xp_event(challenge_id: String, version_key: String) -> String:
	return "event.xp." + challenge_id + "." + version_key

static func _empty_owner() -> Dictionary:
	return {"total_xp": 0, "xp_events": {}, "skill_ranks": {}, "completed_gates": {}, "challenges": {}}

static func _empty_challenge(version_key: String) -> Dictionary:
	return {"version_key": version_key, "progress": 0, "rewarded": false, "events": {}}

static func _reject(operation: String, reason: String) -> Dictionary:
	return {"accepted": false, "reason": reason, "operation": operation}

static func _exact(payload: Dictionary, keys: Array) -> bool:
	if payload.size() != keys.size():
		return false
	for key in keys:
		if not payload.has(key):
			return false
	return true

static func _sorted_keys(source: Dictionary) -> Array:
	var keys := source.keys()
	keys.sort()
	return keys
