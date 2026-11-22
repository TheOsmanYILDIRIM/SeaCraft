class_name QuestDefinition
extends BaseDefinition

const QUEST_TYPES := ["story", "bounty", "damage", "capture", "collect", "acquire", "timed", "escort", "salvage", "trade"]
const OBJECTIVE_TYPES := ["kill", "damage", "capture", "collect", "acquire", "timed", "escort", "salvage", "trade"]
const REPEATABILITY_POLICIES := ["once", "version", "repeatable"]
const PARTY_SHARE_POLICIES := ["owner_only", "eligible_party", "shared_progress", "shared_completion"]
const MAX_OBJECTIVES := 32
const MAX_REWARDS := 16
const MAX_REFERENCES := 32
const MAX_REQUIRED_VALUE := 1000000000
const MAX_XP_REWARD := 1000000
const MAX_TIME_LIMIT_TICKS := 2147483647

@export var quest_type: String = "story"
@export var tags: PackedStringArray = PackedStringArray()
@export var start_npc_id: String = ""
@export var turn_in_npc_id: String = ""
@export var prerequisite_quest_ids: PackedStringArray = PackedStringArray()
@export var prerequisite_gate_ids: PackedStringArray = PackedStringArray()
@export var required_rank_id: String = ""
@export var region_ids: PackedStringArray = PackedStringArray()
@export var sector_ids: PackedStringArray = PackedStringArray()
@export var objectives: Array[Dictionary] = []
@export var reward_items: Array[Dictionary] = []
@export var xp_reward: int = 0
@export var reward_gate_ids: PackedStringArray = PackedStringArray()
@export var reward_event_refs: PackedStringArray = PackedStringArray()
@export var time_limit_ticks: int = 0
@export var version_key: String = "version.default"
@export var repeatability_policy: String = "once"
@export var party_share_policy: String = "owner_only"
@export var ordered_objectives: bool = false
@export var title: String = ""
@export_multiline var description: String = ""

func definition_type() -> String:
	return "quest"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or quest_type not in QUEST_TYPES:
		return false
	if start_npc_id.is_empty() or turn_in_npc_id.is_empty() or not SectorIds.valid(start_npc_id) or not SectorIds.valid(turn_in_npc_id):
		return false
	if not required_rank_id.is_empty() and not SectorIds.valid(required_rank_id):
		return false
	if not SectorIds.valid(version_key) or repeatability_policy not in REPEATABILITY_POLICIES or party_share_policy not in PARTY_SHARE_POLICIES:
		return false
	if objectives.is_empty() or objectives.size() > MAX_OBJECTIVES or reward_items.size() > MAX_REWARDS:
		return false
	if xp_reward < 0 or xp_reward > MAX_XP_REWARD or time_limit_ticks < 0 or time_limit_ticks > MAX_TIME_LIMIT_TICKS:
		return false
	if title.is_empty() or title.length() > 128 or description.length() > 2048:
		return false
	if tags.size() > MAX_REFERENCES or prerequisite_quest_ids.size() > MAX_REFERENCES or prerequisite_gate_ids.size() > MAX_REFERENCES or region_ids.size() > MAX_REFERENCES or sector_ids.size() > MAX_REFERENCES or reward_gate_ids.size() > MAX_REFERENCES or reward_event_refs.size() > MAX_REFERENCES:
		return false
	for collection in [tags, prerequisite_quest_ids, prerequisite_gate_ids, region_ids, sector_ids, reward_gate_ids, reward_event_refs]:
		if not _valid_unique_ids(collection):
			return false
	if prerequisite_quest_ids.has(stable_id):
		return false
	var objective_ids: Dictionary = {}
	for row in objectives:
		if not _valid_objective(row, objective_ids):
			return false
	if not ProgressionGateDefinition._valid_rewards(reward_items):
		return false
	return true

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	_append_ref(refs, start_npc_id)
	_append_ref(refs, turn_in_npc_id)
	for value in prerequisite_quest_ids:
		_append_ref(refs, value)
	for value in prerequisite_gate_ids:
		_append_ref(refs, value)
	_append_ref(refs, required_rank_id)
	for value in region_ids:
		_append_ref(refs, value)
	for value in sector_ids:
		_append_ref(refs, value)
	for objective in objectives:
		_append_ref(refs, str(objective.get("target_id", "")))
		_append_ref(refs, str(objective.get("source_id", "")))
		_append_ref(refs, str(objective.get("region_id", "")))
	for reward in reward_items:
		_append_ref(refs, str(reward.get("item_id", "")))
	for value in reward_gate_ids:
		_append_ref(refs, value)
	for value in reward_event_refs:
		_append_ref(refs, value)
	refs.sort()
	return refs

static func _valid_objective(row: Dictionary, seen: Dictionary) -> bool:
	var keys := ["objective_id", "objective_type", "target_id", "source_id", "required_value", "region_id"]
	if row.size() != keys.size():
		return false
	for key in keys:
		if not row.has(key):
			return false
	if not row["objective_id"] is String or not row["objective_type"] is String or not row["target_id"] is String or not row["source_id"] is String or not row["region_id"] is String or not row["required_value"] is int:
		return false
	var objective_id := str(row["objective_id"])
	var objective_type := str(row["objective_type"])
	var target_id := str(row["target_id"])
	var source_id := str(row["source_id"])
	var region_id := str(row["region_id"])
	var required_value := int(row["required_value"])
	if not SectorIds.valid(objective_id) or seen.has(objective_id) or objective_type not in OBJECTIVE_TYPES:
		return false
	if required_value <= 0 or required_value > MAX_REQUIRED_VALUE:
		return false
	for value in [target_id, source_id, region_id]:
		if not str(value).is_empty() and not SectorIds.valid(str(value)):
			return false
	if objective_type in ["kill", "damage", "capture", "escort"] and target_id.is_empty():
		return false
	if objective_type == "trade" and (target_id.is_empty() or source_id.is_empty()):
		return false
	seen[objective_id] = true
	return true

static func _valid_unique_ids(values: PackedStringArray) -> bool:
	var seen: Dictionary = {}
	for raw in values:
		var value := str(raw)
		if value.is_empty() or not SectorIds.valid(value) or seen.has(value):
			return false
		seen[value] = true
	return true

static func _append_ref(refs: PackedStringArray, value: String) -> void:
	if not value.is_empty() and not refs.has(value):
		refs.append(value)
