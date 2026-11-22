class_name TrophyDefinition
extends BaseDefinition

const MAX_REWARDS := 16
const MAX_PREREQUISITES := 16
const MAX_MODIFIERS := 16
const MAX_QUANTITY := 2147483647

@export var prerequisite_ids: PackedStringArray = PackedStringArray()
@export var event_key: String = ""
@export var rewards: Array[Dictionary] = []
@export var modifiers: Array[Dictionary] = []
@export var tag: String = ""

func definition_type() -> String:
	return "trophy"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or not SectorIds.valid(event_key) or tag.length() > 64:
		return false
	if prerequisite_ids.size() > MAX_PREREQUISITES or rewards.size() > MAX_REWARDS or modifiers.size() > MAX_MODIFIERS:
		return false
	var seen_prereq: Dictionary = {}
	for requirement in prerequisite_ids:
		if not SectorIds.valid(requirement) or requirement == stable_id or seen_prereq.has(requirement):
			return false
		seen_prereq[requirement] = true
	if not _valid_rewards(rewards):
		return false
	var seen_sources: Dictionary = {}
	for row in modifiers:
		if not ShipUpgradeDefinition._valid_modifier(row):
			return false
		var source_id := str(row["source_id"])
		if seen_sources.has(source_id):
			return false
		seen_sources[source_id] = true
	return true

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for requirement in prerequisite_ids:
		_append_unique(refs, requirement)
	for row in rewards:
		_append_unique(refs, str(row.get("item_id", "")))
	refs.sort()
	return refs

static func _valid_rewards(rows: Array[Dictionary]) -> bool:
	var seen: Dictionary = {}
	for row in rows:
		if row.size() != 2 or not row.get("item_id") is String or not row.get("quantity") is int:
			return false
		var item_id := str(row["item_id"])
		var quantity := int(row["quantity"])
		if not SectorIds.valid(item_id) or quantity <= 0 or quantity > MAX_QUANTITY or seen.has(item_id):
			return false
		seen[item_id] = true
	return true

static func _append_unique(values: PackedStringArray, value: String) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)
