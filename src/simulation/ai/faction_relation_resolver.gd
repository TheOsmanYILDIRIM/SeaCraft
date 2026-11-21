class_name FactionRelationResolver
extends RefCounted

const VERSION := 1
const FRIENDLY := "friendly"
const NEUTRAL := "neutral"
const HOSTILE := "hostile"
const MAX_RELATIONS := 256

var _authority_enabled := true
var _relations: Dictionary = {}


func _init(authority_enabled: bool = true) -> void:
	_authority_enabled = authority_enabled


func set_relation(faction_a: String, faction_b: String, value: String) -> bool:
	if not _authority_enabled or not SectorIds.valid(faction_a) or not SectorIds.valid(faction_b):
		return false
	if value not in [FRIENDLY, NEUTRAL, HOSTILE]:
		return false
	if faction_a == faction_b:
		return value == FRIENDLY
	var key := _key(faction_a, faction_b)
	if value == NEUTRAL:
		_relations.erase(key)
		return true
	if not _relations.has(key) and _relations.size() >= MAX_RELATIONS:
		return false
	_relations[key] = {"a": min(faction_a, faction_b), "b": max(faction_a, faction_b), "relation": value}
	return true


func relation(faction_a: String, faction_b: String) -> String:
	if not SectorIds.valid(faction_a) or not SectorIds.valid(faction_b):
		return NEUTRAL
	if faction_a == faction_b:
		return FRIENDLY
	var entry: Dictionary = _relations.get(_key(faction_a, faction_b), {})
	return str(entry.get("relation", NEUTRAL))


func hostile(faction_a: String, faction_b: String) -> bool:
	return relation(faction_a, faction_b) == HOSTILE


func snapshot_state() -> Dictionary:
	var rows: Array = []
	var keys := _relations.keys()
	keys.sort()
	for key in keys:
		rows.append((_relations[key] as Dictionary).duplicate(true))
	return {"version": VERSION, "relations": rows}


func restore_state(value: Variant) -> bool:
	if not _authority_enabled or not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if int(state.get("version", -1)) != VERSION or not state.get("relations") is Array:
		return false
	if state["relations"].size() > MAX_RELATIONS:
		return false
	var planned: Dictionary = {}
	for raw in state["relations"]:
		if not raw is Dictionary:
			return false
		var row: Dictionary = raw
		var a := str(row.get("a", ""))
		var b := str(row.get("b", ""))
		var rel := str(row.get("relation", ""))
		if not SectorIds.valid(a) or not SectorIds.valid(b) or a == b or rel not in [FRIENDLY, HOSTILE]:
			return false
		var key := _key(a, b)
		if planned.has(key):
			return false
		planned[key] = {"a": min(a, b), "b": max(a, b), "relation": rel}
	_relations = planned
	return true


static func _key(a: String, b: String) -> String:
	return "%s|%s" % [min(a, b), max(a, b)]
