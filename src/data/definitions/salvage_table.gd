class_name SalvageTable
extends BaseDefinition

const MAX_ENTRIES := 32
const MAX_QUANTITY := 1000000
const MAX_TOTAL_WEIGHT := 2147483647

@export var source_item_ids: PackedStringArray = PackedStringArray()
@export var source_categories: PackedStringArray = PackedStringArray()
@export var consume_quantity: int = 1
@export var entries: Array[Dictionary] = []
@export var tag: String = ""

func definition_type() -> String:
	return "salvage_table"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or consume_quantity <= 0 or consume_quantity > MAX_QUANTITY:
		return false
	if source_item_ids.is_empty() and source_categories.is_empty():
		return false
	if entries.is_empty() or entries.size() > MAX_ENTRIES or tag.length() > 64:
		return false
	var seen_sources: Dictionary = {}
	for item_id in source_item_ids:
		if not SectorIds.valid(item_id) or seen_sources.has(item_id):
			return false
		seen_sources[item_id] = true
	var seen_categories: Dictionary = {}
	for category in source_categories:
		if category.is_empty() or category.length() > 64 or seen_categories.has(category):
			return false
		seen_categories[category] = true
	var total_weight := 0
	for row in entries:
		if row.size() != 4 or not row.get("item_id") is String:
			return false
		if not row.get("min_quantity") is int or not row.get("max_quantity") is int or not row.get("weight") is int:
			return false
		var item_id := str(row["item_id"])
		var minimum := int(row["min_quantity"])
		var maximum := int(row["max_quantity"])
		var weight := int(row["weight"])
		if not SectorIds.valid(item_id) or minimum <= 0 or maximum < minimum or maximum > MAX_QUANTITY:
			return false
		if weight <= 0 or weight > MAX_QUANTITY:
			return false
		if total_weight > MAX_TOTAL_WEIGHT - weight:
			return false
		total_weight += weight
	return total_weight > 0

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for item_id in source_item_ids:
		if not refs.has(item_id):
			refs.append(item_id)
	for row in entries:
		var item_id := str(row.get("item_id", ""))
		if not item_id.is_empty() and not refs.has(item_id):
			refs.append(item_id)
	refs.sort()
	return refs
