class_name RecipeDefinition
extends BaseDefinition

const MAX_ENTRIES := 16
const MAX_CRAFT_COUNT := 1000000
const MAX_QUANTITY := 2147483647

@export var inputs: Array[Dictionary] = []
@export var outputs: Array[Dictionary] = []
@export var prerequisite_ids: PackedStringArray = PackedStringArray()
@export var max_craft_count: int = 1
@export var category: String = "general"
@export var tag: String = ""

func definition_type() -> String:
	return "recipe"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or inputs.is_empty() or outputs.is_empty():
		return false
	if inputs.size() > MAX_ENTRIES or outputs.size() > MAX_ENTRIES:
		return false
	if max_craft_count <= 0 or max_craft_count > MAX_CRAFT_COUNT:
		return false
	if category.is_empty() or category.length() > 64 or tag.length() > 64:
		return false
	if not _valid_quantity_rows(inputs) or not _valid_quantity_rows(outputs):
		return false
	var seen_prereq: Dictionary = {}
	for requirement in prerequisite_ids:
		if not SectorIds.valid(requirement) or requirement == stable_id or seen_prereq.has(requirement):
			return false
		seen_prereq[requirement] = true
	return true

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for row in inputs:
		_append_unique(refs, str(row.get("item_id", "")))
	for row in outputs:
		_append_unique(refs, str(row.get("item_id", "")))
	for requirement in prerequisite_ids:
		_append_unique(refs, requirement)
	refs.sort()
	return refs

static func _valid_quantity_rows(rows: Array[Dictionary]) -> bool:
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
