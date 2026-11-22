class_name ShipUpgradeDefinition
extends BaseDefinition

const MAX_COST_ROWS := 16
const MAX_PREREQUISITES := 16
const MAX_MODIFIERS := 16
const MAX_CORE_SLOTS := 16
const MAX_QUANTITY := 2147483647

@export var prerequisite_ids: PackedStringArray = PackedStringArray()
@export var costs: Array[Dictionary] = []
@export var tier: int = 1
@export var modifiers: Array[Dictionary] = []
@export var core_slots: Array[Dictionary] = []
@export var tag: String = ""

func definition_type() -> String:
	return "ship_upgrade"

func valid() -> bool:
	if not SectorIds.valid(stable_id) or tier <= 0 or tier > 64 or tag.length() > 64:
		return false
	if prerequisite_ids.size() > MAX_PREREQUISITES or costs.size() > MAX_COST_ROWS:
		return false
	if modifiers.size() > MAX_MODIFIERS or core_slots.size() > MAX_CORE_SLOTS:
		return false
	var seen_prereq: Dictionary = {}
	for requirement in prerequisite_ids:
		if not SectorIds.valid(requirement) or requirement == stable_id or seen_prereq.has(requirement):
			return false
		seen_prereq[requirement] = true
	if not _valid_costs(costs):
		return false
	var seen_sources: Dictionary = {}
	for row in modifiers:
		if not _valid_modifier(row):
			return false
		var source_id := str(row["source_id"])
		if seen_sources.has(source_id):
			return false
		seen_sources[source_id] = true
	var seen_slots: Dictionary = {}
	for row in core_slots:
		if row.size() != 3:
			return false
		if not row.get("slot_id") is String or not row.get("slot_type") is String or not row.get("allowed_core_type") is String:
			return false
		var slot_id := str(row["slot_id"])
		var slot_type := str(row["slot_type"])
		var allowed := str(row["allowed_core_type"])
		if not SectorIds.valid(slot_id) or slot_type.is_empty() or allowed.is_empty() or slot_type.length() > 64 or allowed.length() > 64:
			return false
		if seen_slots.has(slot_id):
			return false
		seen_slots[slot_id] = true
	return true

func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	for requirement in prerequisite_ids:
		_append_unique(refs, requirement)
	for row in costs:
		_append_unique(refs, str(row.get("item_id", "")))
	refs.sort()
	return refs

static func _valid_costs(rows: Array[Dictionary]) -> bool:
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

static func _valid_modifier(row: Dictionary) -> bool:
	if row.size() != 5 or not row.get("source_id") is String or not row.get("stat") is String:
		return false
	if not row.get("operation") is String or not row.get("priority") is int:
		return false
	if typeof(row.get("value")) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	return SectorIds.valid(str(row["source_id"])) and not str(row["stat"]).is_empty() and str(row["operation"]) in StatModifierPipeline.PHASE_ORDER and is_finite(float(row["value"]))

static func _append_unique(values: PackedStringArray, value: String) -> void:
	if not value.is_empty() and not values.has(value):
		values.append(value)
