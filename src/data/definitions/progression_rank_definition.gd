class_name ProgressionRankDefinition
extends BaseDefinition

const MAX_XP := 2147483647
const MAX_SKILL_POINTS := 64
const MAX_MODIFIERS := 16

@export var xp_threshold: int = 0
@export var skill_point_grant: int = 0
@export var prerequisite_gate_id: String = ""
@export var modifiers: Array[Dictionary] = []
@export var label: String = ""

func definition_type() -> String:
	return "progression_rank"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or xp_threshold < 0 or xp_threshold > MAX_XP:
		return false
	if skill_point_grant < 0 or skill_point_grant > MAX_SKILL_POINTS or label.length() > 64:
		return false
	if not prerequisite_gate_id.is_empty() and not SectorIds.valid(prerequisite_gate_id):
		return false
	if modifiers.size() > MAX_MODIFIERS:
		return false
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
	if not prerequisite_gate_id.is_empty():
		refs.append(prerequisite_gate_id)
	return refs
