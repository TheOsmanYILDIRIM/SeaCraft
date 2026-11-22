class_name LocalChallengeDefinition
extends BaseDefinition

const RECURRENCE_POLICIES := ["once", "version"]
const OBJECTIVE_TYPES := ["counter"]
const MAX_REWARDS := 16
const MAX_TARGET := 1000000
const MAX_XP_REWARD := 1000000

@export var version_key: String = "version.default"
@export var objective_type: String = "counter"
@export var target_value: int = 1
@export var rewards: Array[Dictionary] = []
@export var xp_reward: int = 0
@export var recurrence_policy: String = "once"

func definition_type() -> String:
	return "local_challenge"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or not SectorIds.valid(version_key):
		return false
	if objective_type not in OBJECTIVE_TYPES or recurrence_policy not in RECURRENCE_POLICIES:
		return false
	if target_value <= 0 or target_value > MAX_TARGET or xp_reward < 0 or xp_reward > MAX_XP_REWARD:
		return false
	if rewards.size() > MAX_REWARDS:
		return false
	return ProgressionGateDefinition._valid_rewards(rewards)

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for row in rewards:
		var item_id := str(row.get("item_id", ""))
		if not refs.has(item_id):
			refs.append(item_id)
	refs.sort()
	return refs
