class_name ProgressionSkillDefinition
extends BaseDefinition

const MAX_PREREQUISITES := 16
const MAX_MODIFIERS := 16

@export var prerequisite_ids: PackedStringArray = PackedStringArray()
@export var tier: int = 1
@export var point_cost: int = 1
@export var max_rank: int = 1
@export var gate_id: String = ""
@export var modifiers: Array[Dictionary] = []

func definition_type() -> String:
	return "progression_skill"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or tier <= 0 or tier > 64 or point_cost <= 0 or point_cost > 64 or max_rank <= 0 or max_rank > 8:
		return false
	if prerequisite_ids.size() > MAX_PREREQUISITES or modifiers.size() > MAX_MODIFIERS:
		return false
	if not gate_id.is_empty() and not SectorIds.valid(gate_id):
		return false
	var seen: Dictionary = {}
	for prerequisite in prerequisite_ids:
		if not SectorIds.valid(prerequisite) or prerequisite == stable_id or seen.has(prerequisite):
			return false
		seen[prerequisite] = true
	var sources: Dictionary = {}
	for row in modifiers:
		if not ShipUpgradeDefinition._valid_modifier(row):
			return false
		var source_id := str(row["source_id"])
		if sources.has(source_id):
			return false
		sources[source_id] = true
	return true

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for prerequisite in prerequisite_ids:
		if not refs.has(prerequisite):
			refs.append(prerequisite)
	if not gate_id.is_empty() and not refs.has(gate_id):
		refs.append(gate_id)
	refs.sort()
	return refs
