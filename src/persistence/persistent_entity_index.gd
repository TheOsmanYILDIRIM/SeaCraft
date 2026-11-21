class_name PersistentEntityIndex
extends RefCounted

const VERSION := 1
const MAX_ENTITIES := 2048
const MAX_SECTORS := 32
const MAX_INVENTORY_ITEMS := 128
const MAX_COOLDOWNS := 32
const MAX_CONTENT_REFS := 32


static func build(records: Array, registry: DefinitionRegistry) -> Dictionary:
	var ordered: Array = []
	for raw in records:
		if not raw is Dictionary:
			return {}
		ordered.append((raw as Dictionary).duplicate(true))
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a.get("instance_id", "")) < str(b.get("instance_id", "")))
	var result := {"version": VERSION, "records": ordered}
	return result if validate(result, registry).is_empty() else {}


static func validate(value: Variant, registry: DefinitionRegistry) -> String:
	if registry == null:
		return "content_registry_unavailable"
	if not value is Dictionary or value.size() != 2 or int(value.get("version", -1)) != VERSION:
		return "invalid_entity_index"
	var records: Variant = value.get("records")
	if not records is Array or records.size() > MAX_ENTITIES:
		return "invalid_entity_index"
	var seen: Dictionary = {}
	var sectors: Dictionary = {}
	var previous := ""
	for raw in records:
		if not raw is Dictionary:
			return "invalid_entity_index"
		var record: Dictionary = raw
		if record.size() != 12:
			return "invalid_entity_index"
		var instance_id: Variant = record.get("instance_id")
		var definition_id: Variant = record.get("definition_id")
		var entity_kind: Variant = record.get("entity_kind")
		var sector_id: Variant = record.get("sector_id")
		if not instance_id is String or not SectorIds.valid(instance_id) or seen.has(instance_id):
			return "duplicate_entity_id" if seen.has(instance_id) else "invalid_entity_index"
		if not previous.is_empty() and instance_id < previous:
			return "invalid_entity_order"
		if not definition_id is String or not registry.has_id(definition_id):
			return "unknown_content"
		if not entity_kind is String or entity_kind.is_empty() or entity_kind.length() > 32:
			return "invalid_entity_index"
		if not sector_id is String or not registry.matches_type(sector_id, "sector"):
			return "unknown_sector"
		sectors[sector_id] = true
		if sectors.size() > MAX_SECTORS:
			return "entity_sector_limit"
		var position: Variant = record.get("position")
		if not _vector(position):
			return "invalid_entity_position"
		var motion: Variant = record.get("motion")
		if not motion is Dictionary or motion.size() != 3:
			return "invalid_entity_motion"
		for key in ["heading", "vx", "vy"]:
			if not _finite_number(motion.get(key)):
				return "invalid_entity_motion"
		if not _finite_number(record.get("health")) or float(record["health"]) < 0.0 or float(record["health"]) > CoreCombatRules.MAX_VALUE:
			return "invalid_entity_health"
		if not record.get("alive") is bool:
			return "invalid_entity_index"
		if not _route_valid(record.get("route")):
			return "invalid_route_goal"
		if not _cooldowns_valid(record.get("cooldowns")):
			return "invalid_cooldown"
		if not _inventory_valid(record.get("inventory"), registry):
			return "unknown_content"
		if not _payload_valid(record.get("payload"), registry):
			return "unknown_content"
		seen[instance_id] = true
		previous = instance_id
	return ""


static func _vector(value: Variant) -> bool:
	return value is Dictionary and value.size() == 2 and _finite_number(value.get("x")) and _finite_number(value.get("y"))


static func _route_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > 8:
		return false
	if value.has("goal") and not _vector(value["goal"]):
		return false
	for key in ["patrol_index", "intent_id", "next_waypoint"]:
		if value.has(key) and (not _integer(value[key]) or int(value[key]) < 0):
			return false
	if value.has("goal_id") and (not value["goal_id"] is String or (not value["goal_id"].is_empty() and not SectorIds.valid(value["goal_id"]))):
		return false
	return true


static func _cooldowns_valid(value: Variant) -> bool:
	if not value is Dictionary or value.size() > MAX_COOLDOWNS:
		return false
	for key in value:
		if not key is String or key.length() > 64 or not _integer(value[key]) or int(value[key]) < 0:
			return false
	return true


static func _inventory_valid(value: Variant, registry: DefinitionRegistry) -> bool:
	if not value is Dictionary or value.size() > MAX_INVENTORY_ITEMS:
		return false
	for item_id in value:
		if not item_id is String or not registry.matches_type(item_id, "item"):
			return false
		if not _integer(value[item_id]) or int(value[item_id]) < 0:
			return false
	return true


static func _payload_valid(value: Variant, registry: DefinitionRegistry) -> bool:
	if not value is Dictionary or value.size() > 8:
		return false
	var refs: Variant = value.get("content_refs", [])
	if not refs is Array or refs.size() > MAX_CONTENT_REFS:
		return false
	if value.has(FarFieldEntityState.PAYLOAD_KEY):
		var ai04: Variant = value[FarFieldEntityState.PAYLOAD_KEY]
		if not FarFieldEntityState.valid_semantic(ai04):
			return false
		var semantic: Dictionary = ai04
		var faction_id := str(semantic["faction_id"])
		if not faction_id.is_empty() and not registry.matches_type(faction_id, "faction"):
			return false
		var travel: Dictionary = semantic["travel"]
		var destination_id := str(travel["destination_id"])
		if not destination_id.is_empty() and not registry.matches_type(destination_id, "sector"):
			return false
		for route_sector_id in travel["route"]:
			if not registry.matches_type(str(route_sector_id), "sector"):
				return false
	var seen: Dictionary = {}
	for content_id in refs:
		if not content_id is String or not registry.has_id(content_id) or seen.has(content_id):
			return false
		seen[content_id] = true
	return true


static func _finite_number(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and absf(float(value)) <= 1.0e9


static func _integer(value: Variant) -> bool:
	return _finite_number(value) and float(value) == floorf(float(value))
