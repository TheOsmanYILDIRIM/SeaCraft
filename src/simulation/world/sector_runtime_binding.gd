class_name SectorRuntimeBinding
extends RefCounted

var _combat: CombatAuthority
var _loot: LootAuthority
var _world_objects: WorldObjectAuthority
var _brains: Array[NpcBrain] = []


func _init(combat: CombatAuthority = null, loot: LootAuthority = null,
		world_objects: WorldObjectAuthority = null, brains: Array[NpcBrain] = []) -> void:
	_combat = combat
	_loot = loot
	_world_objects = world_objects
	_brains = brains


func can_rebind(runtime: SectorRuntime, transferred_entity_id: String) -> bool:
	return runtime != null and SectorIds.valid(transferred_entity_id)


func rebind_sector(runtime: SectorRuntime, transferred_entity_id: String) -> bool:
	if not can_rebind(runtime, transferred_entity_id):
		return false
	if _combat != null and not _combat.rebind_sector(runtime, transferred_entity_id):
		return false
	if _loot != null and not _loot.rebind_sector(runtime):
		return false
	if _world_objects != null and not _world_objects.rebind_sector(runtime):
		return false
	for brain in _brains:
		if brain != null and not brain.rebind_sector(runtime, _combat):
			return false
	return true
