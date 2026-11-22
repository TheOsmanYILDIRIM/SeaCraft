class_name ProgressionGateDefinition
extends BaseDefinition

const GATE_TYPES := ["license", "test", "milestone", "rank"]
const MAX_PREREQUISITES := 16
const MAX_REWARDS := 16
const MAX_XP_REWARD := 1000000

@export var gate_type: String = "license"
@export var prerequisite_gate_ids: PackedStringArray = PackedStringArray()
@export var required_rank_id: String = ""
@export var rewards: Array[Dictionary] = []
@export var xp_reward: int = 0

func definition_type() -> String:
	return "progression_gate"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or gate_type not in GATE_TYPES:
		return false
	if prerequisite_gate_ids.size() > MAX_PREREQUISITES or rewards.size() > MAX_REWARDS:
		return false
	if xp_reward < 0 or xp_reward > MAX_XP_REWARD:
		return false
	if not required_rank_id.is_empty() and not SectorIds.valid(required_rank_id):
		return false
	var seen: Dictionary = {}
	for prerequisite in prerequisite_gate_ids:
		if not SectorIds.valid(prerequisite) or prerequisite == stable_id or seen.has(prerequisite):
			return false
		seen[prerequisite] = true
	return _valid_rewards(rewards)

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for prerequisite in prerequisite_gate_ids:
		if not refs.has(prerequisite):
			refs.append(prerequisite)
	if not required_rank_id.is_empty() and not refs.has(required_rank_id):
		refs.append(required_rank_id)
	for row in rewards:
		var item_id := str(row.get("item_id", ""))
		if not refs.has(item_id):
			refs.append(item_id)
	refs.sort()
	return refs

static func _valid_rewards(rows: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for row in rows:
		if row.size() != 2 or not row.get("item_id") is String or not row.get("quantity") is int:
			return false
		var item_id := str(row["item_id"])
		var quantity := int(row["quantity"])
		if not SectorIds.valid(item_id) or quantity <= 0 or quantity > 2147483647 or seen.has(item_id):
			return false
		seen[item_id] = true
	return true
