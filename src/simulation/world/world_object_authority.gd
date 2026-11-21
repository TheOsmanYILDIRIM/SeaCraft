class_name WorldObjectAuthority
extends RefCounted

const CHEST := "chest"
const GLITTER := "glitter"
const WRECK := "wreck"
const ARCHETYPES := [CHEST, GLITTER, WRECK]
const PICKUP_RADIUS := 96.0
const MAX_WORLD_OBJECTS_PER_SECTOR := 64
const MAX_WRECKS_PER_SECTOR := 16
const MAX_SLOT := 4095
const WRECK_FACTION := "faction.world_wreck"

var _sector: SectorRuntime
var _loot: LootAuthority
var _combat: CombatAuthority
var _table: LootTable
var _inventory_owner: String
var _authority_enabled := true
var _objects: Dictionary = {}
var _claimed: Dictionary = {}
var _processed_spawns: Dictionary = {}
var _query_candidates: Array[String] = []
var _last_query_inspected := 0


func _init(sector: SectorRuntime, loot: LootAuthority, combat: CombatAuthority, table: LootTable,
		inventory_owner: String, authority_enabled: bool = true) -> void:
	_sector = sector
	_loot = loot
	_combat = combat
	_table = table
	_inventory_owner = inventory_owner
	_authority_enabled = authority_enabled


static func stable_spawn_id(sector_id: String, anchor_id: String, archetype: String, slot: int) -> String:
	if not SectorIds.valid(sector_id) or not SectorIds.valid(anchor_id) or archetype not in ARCHETYPES or slot < 0 or slot > MAX_SLOT:
		return ""
	var seed := "%s|%s|%s|%d" % [sector_id, anchor_id, archetype, slot]
	return "world.id_%s" % seed.sha256_text().substr(0, 32)


func rebind_sector(sector: SectorRuntime) -> bool:
	if sector == null:
		return false
	_sector = sector
	for id in _objects:
		var object: Dictionary = _objects[id]
		if object["sector_id"] != _sector.sector_id:
			continue
		var position := Vector2(float(object["x"]), float(object["y"]))
		if not _sector.entity_position(id).is_finite() and not _sector.register_entity(id, position):
			return false
		if object["archetype"] == WRECK and _combat != null and not _combat.has_combatant(id):
			if not _combat.register(id, WRECK_FACTION, float(object["max_health"]), null, 0.0, 0.0, true, {}, 0, TargetingService.WRECK):
				return false
	return true


func spawn(archetype: String, anchor_id: String, slot: int, max_health: float = 40.0) -> Dictionary:
	if not _authority_enabled or _sector == null or _loot == null or _table == null or not _table.valid():
		return {}
	if archetype not in ARCHETYPES or slot < 0 or slot > MAX_SLOT:
		return {}
	var sector_objects := 0
	for current: Dictionary in _objects.values():
		if current["sector_id"] == _sector.sector_id:
			sector_objects += 1
	if sector_objects >= MAX_WORLD_OBJECTS_PER_SECTOR:
		return {}
	var anchor := _sector.anchor(anchor_id)
	if anchor == null or anchor.category != archetype or _sector.navigation == null or not _sector.navigation.accessible(anchor.position):
		return {}
	var id := stable_spawn_id(_sector.sector_id, anchor_id, archetype, slot)
	if id.is_empty() or _processed_spawns.has(id) or _objects.has(id) or _claimed.has(id):
		return {}
	if archetype == WRECK:
		var wrecks := 0
		for current: Dictionary in _objects.values():
			if current["sector_id"] == _sector.sector_id and current["archetype"] == WRECK:
				wrecks += 1
		if wrecks >= MAX_WRECKS_PER_SECTOR or not CoreCombatRules.bounded(max_health, 0.000001, CoreCombatRules.MAX_VALUE):
			return {}
	if not _sector.register_entity(id, anchor.position):
		return {}
	if archetype == WRECK:
		if _combat == null or not _combat.register(id, WRECK_FACTION, max_health, null, 0.0, 0.0, true, {}, 0, TargetingService.WRECK):
			_sector.remove_entity(id)
			return {}
	var object := {
		"entity_id": id,
		"sector_id": _sector.sector_id,
		"anchor_id": anchor_id,
		"archetype": archetype,
		"slot": slot,
		"x": anchor.position.x,
		"y": anchor.position.y,
		"max_health": max_health if archetype == WRECK else 0.0,
	}
	_objects[id] = object
	_processed_spawns[id] = true
	return object.duplicate(true)


func pickup(actor: String, entity_id: String) -> Dictionary:
	var result := {"accepted": false, "reason": "", "entity_id": entity_id, "item_id": "", "quantity": 0}
	if not _authority_enabled:
		result["reason"] = "authority_disabled"
		return result
	if _claimed.has(entity_id):
		result["reason"] = "already_claimed"
		return result
	var object: Dictionary = _objects.get(entity_id, {})
	if object.is_empty():
		result["reason"] = "object_not_found"
		return result
	if object.get("sector_id") != _sector.sector_id:
		result["reason"] = "wrong_sector"
		return result
	if object["archetype"] not in [CHEST, GLITTER]:
		result["reason"] = "not_pickup"
		return result
	var actor_position := _sector.entity_position(actor)
	var object_position := Vector2(object["x"], object["y"])
	if not actor_position.is_finite() or actor_position.distance_to(object_position) > PICKUP_RADIUS:
		result["reason"] = "out_of_range"
		return result
	var reward := _loot.grant_from_table(actor, "claim.%s" % entity_id, _table)
	if not reward["accepted"]:
		result["reason"] = reward["reason"]
		return result
	_claimed[entity_id] = true
	_objects.erase(entity_id)
	_sector.remove_entity(entity_id)
	result["accepted"] = true
	result["item_id"] = reward["item_id"]
	result["quantity"] = reward["quantity"]
	return result


func on_wreck_destroyed(actor: String, entity_id: String, sequence_id: int) -> Dictionary:
	var result := {"accepted": false, "reason": "", "entity_id": entity_id, "item_id": "", "quantity": 0}
	if not _authority_enabled:
		result["reason"] = "authority_disabled"
		return result
	if _claimed.has(entity_id):
		result["reason"] = "already_claimed"
		return result
	var object: Dictionary = _objects.get(entity_id, {})
	if object.is_empty() or object.get("archetype") != WRECK:
		result["reason"] = "object_not_found"
		return result
	if object.get("sector_id") != _sector.sector_id:
		result["reason"] = "wrong_sector"
		return result
	if sequence_id <= 0 or _combat == null or _combat.is_alive(entity_id):
		result["reason"] = "wreck_not_destroyed"
		return result
	var reward := _loot.grant_from_table(actor, "destroy.%s.seq_%d" % [entity_id, sequence_id], _table)
	if not reward["accepted"]:
		result["reason"] = reward["reason"]
		return result
	_claimed[entity_id] = true
	_objects.erase(entity_id)
	_combat.retire_destroyed(entity_id)
	result["accepted"] = true
	result["item_id"] = reward["item_id"]
	result["quantity"] = reward["quantity"]
	return result


func nearest_pickup(actor: String) -> String:
	_last_query_inspected = 0
	if _sector == null:
		return ""
	var center := _sector.entity_position(actor)
	if not center.is_finite():
		return ""
	_last_query_inspected = _sector.spatial.query_radius(center, PICKUP_RADIUS, _query_candidates)
	var best := ""
	var best_distance := INF
	for id in _query_candidates:
		var object: Dictionary = _objects.get(id, {})
		if object.is_empty() or object["archetype"] not in [CHEST, GLITTER]:
			continue
		var distance := center.distance_squared_to(Vector2(object["x"], object["y"]))
		if distance < best_distance or (is_equal_approx(distance, best_distance) and (best.is_empty() or id < best)):
			best = id
			best_distance = distance
	return best


func snapshot_state() -> Dictionary:
	var objects: Array = []
	var ids := _objects.keys()
	ids.sort()
	for id in ids:
		objects.append((_objects[id] as Dictionary).duplicate(true))
	var claimed_ids := _claimed.keys()
	claimed_ids.sort()
	var processed := _processed_spawns.keys()
	processed.sort()
	return {"objects": objects, "claimed_ids": claimed_ids, "processed_spawns": processed}


func presentation_snapshot() -> Dictionary:
	return snapshot_state().duplicate(true)


func restore_state(value: Variant) -> bool:
	if not validate_state(value):
		return false
	for id in _objects:
		_sector.remove_entity(id)
	_objects.clear()
	_claimed.clear()
	_processed_spawns.clear()
	var state: Dictionary = value
	for id in state["claimed_ids"]:
		_claimed[id] = true
	for id in state["processed_spawns"]:
		_processed_spawns[id] = true
	for raw in state["objects"]:
		var object: Dictionary = raw.duplicate(true)
		object["slot"] = int(object["slot"])
		var id: String = object["entity_id"]
		if object["sector_id"] == _sector.sector_id and not _sector.register_entity(id, Vector2(float(object["x"]), float(object["y"]))):
			return false
		if object["archetype"] == WRECK:
			if _combat == null:
				return false
			if not _combat.has_combatant(id):
				if not _combat.register(id, WRECK_FACTION, float(object["max_health"]), null, 0.0, 0.0, true, {}, 0, TargetingService.WRECK):
					return false
			elif _combat.target_class(id) != TargetingService.WRECK:
				return false
		_objects[id] = object
	return true


func validate_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3 or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	if not state.get("objects") is Array or not state.get("claimed_ids") is Array or not state.get("processed_spawns") is Array:
		return false
	if state["objects"].size() > MAX_WORLD_OBJECTS_PER_SECTOR * 8 or state["claimed_ids"].size() > 512 or state["processed_spawns"].size() > 512:
		return false
	var claimed: Dictionary = {}
	for id in state["claimed_ids"]:
		if not id is String or not SectorIds.valid(id) or claimed.has(id):
			return false
		claimed[id] = true
	var processed: Dictionary = {}
	for id in state["processed_spawns"]:
		if not id is String or not SectorIds.valid(id) or processed.has(id):
			return false
		processed[id] = true
	var seen: Dictionary = {}
	var wrecks := 0
	for raw in state["objects"]:
		if not raw is Dictionary or raw.size() != 8:
			return false
		var object: Dictionary = raw
		var id: Variant = object.get("entity_id")
		var archetype: Variant = object.get("archetype")
		var anchor_id: Variant = object.get("anchor_id")
		if not id is String or not SectorIds.valid(id) or seen.has(id) or claimed.has(id) or not processed.has(id):
			return false
		if not archetype is String or archetype not in ARCHETYPES or not anchor_id is String or not SectorIds.valid(anchor_id):
			return false
		var object_sector: Variant = object.get("sector_id")
		if not object_sector is String or not SectorIds.valid(object_sector) or stable_spawn_id(object_sector, anchor_id, archetype, int(object.get("slot", -1))) != id:
			return false
		if object_sector == _sector.sector_id:
			var anchor := _sector.anchor(anchor_id)
			if anchor == null or anchor.category != archetype:
				return false
		if typeof(object.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(object.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var position := Vector2(float(object["x"]), float(object["y"]))
		if not position.is_finite() or (object.get("sector_id") == _sector.sector_id and not _sector.bounds.has_point(position)):
			return false
		if typeof(object.get("max_health")) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(object["max_health"])):
			return false
		if archetype == WRECK:
			wrecks += 1
			if not CoreCombatRules.bounded(float(object["max_health"]), 0.000001, CoreCombatRules.MAX_VALUE):
				return false
		elif float(object["max_health"]) != 0.0:
			return false
		seen[id] = true
	return wrecks <= MAX_WRECKS_PER_SECTOR


func has_object(entity_id: String) -> bool:
	return _objects.has(entity_id)


func is_claimed(entity_id: String) -> bool:
	return _claimed.has(entity_id)


func last_query_inspected() -> int:
	return _last_query_inspected


func set_authority_enabled(enabled: bool) -> void:
	_authority_enabled = enabled
