class_name Prg05BountyCombatBridge
extends RefCounted

# Uses only CombatAuthority's actual lethal-damage + sunk event pair.
# Client-supplied damage/kill proofs never reach this adapter.
const MAX_BOUND_BOUNTIES := 32
var _combat: CombatAuthority
var _economy: InventoryState
var _authority_enabled := true
var _by_target: Dictionary = {}
var _lethal: Dictionary = {}
var _results: Array = []


func _init(combat: CombatAuthority, economy: InventoryState, authority_enabled: bool = true) -> void:
	_combat = combat
	_economy = economy
	_authority_enabled = authority_enabled
	if _authority_enabled and _combat != null:
		_combat.hull_damaged.connect(_on_hull_damaged)
		_combat.ship_sunk.connect(_on_ship_sunk)


func bind_bounty(bounty_id: String, target_id: String) -> bool:
	if not _authority_enabled or _combat == null or _economy == null or not SectorIds.valid(bounty_id):
		return false
	var contract := _economy.economy_bounty_contract(bounty_id)
	if contract.is_empty() or contract.get("target_id") != target_id:
		return false
	var all: Array = []
	for ids in _by_target.values():
		all.append_array(ids)
	if all.has(bounty_id):
		return (_by_target.get(target_id, []) as Array).has(bounty_id)
	if all.size() >= MAX_BOUND_BOUNTIES:
		return false
	var ids: Array = (_by_target.get(target_id, []) as Array).duplicate()
	ids.append(bounty_id)
	ids.sort()
	_by_target[target_id] = ids
	return true


func outcomes_snapshot() -> Array:
	return _results.duplicate(true)


func _on_hull_damaged(target_id: String, attacker_id: String, applied: float,
		remaining_hull: float, sequence: int) -> void:
	if not _authority_enabled or applied <= 0.0 or remaining_hull > 0.0 or sequence <= 0:
		return
	if not _by_target.has(target_id):
		return
	_lethal[target_id] = {"attacker_id": attacker_id, "sequence": sequence}


func _on_ship_sunk(target_id: String, sequence: int) -> void:
	if not _authority_enabled or _combat == null or _economy == null or not _lethal.has(target_id):
		return
	var proof: Dictionary = _lethal[target_id]
	_lethal.erase(target_id)
	if int(proof["sequence"]) != sequence:
		return
	for bounty_id in _by_target.get(target_id, []):
		var result := _economy.claim_economy_bounty_authoritative(str(proof["attacker_id"]),
			str(bounty_id), target_id, sequence, _combat.simulation_tick())
		if bool(result.get("accepted", false)):
			_results.append(result.duplicate(true))
