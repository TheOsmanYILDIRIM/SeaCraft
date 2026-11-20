class_name CombatTransaction
extends RefCounted


static func dto(attacker: String, target: String) -> Dictionary:
	return {
		"accepted": false, "reason": "", "attacker_id": attacker, "target_id": target,
		"weapon_id": "", "side": 0, "distance": 0.0, "hit": false, "crit": false,
		"raw_damage": 0.0, "prevented_damage": 0.0, "applied_hull_damage": 0.0,
		"remaining_hull": 0.0, "sunk": false, "sequence_id": 0,
	}
