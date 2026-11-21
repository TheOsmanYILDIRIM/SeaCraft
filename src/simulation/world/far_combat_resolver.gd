class_name FarCombatResolver
extends RefCounted

const VERSION := 1
const MAX_PARTICIPANTS := 8
const MAX_RESOLUTION_STEPS := 4
const MIN_RETREAT_HULL := 0.18


static func resolve(participants: Array, elapsed_coarse_ticks: int, master_seed: int,
		event_sequence: int, max_steps: int = MAX_RESOLUTION_STEPS) -> Dictionary:
	if elapsed_coarse_ticks < 0 or event_sequence < 0 or max_steps <= 0 or max_steps > MAX_RESOLUTION_STEPS:
		return {}
	if participants.size() < 2 or participants.size() > MAX_PARTICIPANTS:
		return {}
	var states: Array = []
	var ids: Dictionary = {}
	for raw in participants:
		if not _valid_participant(raw):
			return {}
		var row: Dictionary = (raw as Dictionary).duplicate(true)
		if ids.has(row["instance_id"]):
			return {}
		ids[row["instance_id"]] = true
		states.append(row)
	states.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["instance_id"]) < str(b["instance_id"]))
	var steps := mini(elapsed_coarse_ticks, max_steps)
	var sequence := event_sequence
	var events: Array = []
	for _step in steps:
		var active_factions := _active_factions(states)
		if active_factions.size() <= 1:
			break
		var attack_order := states.duplicate(true)
		for attacker in attack_order:
			if not bool(attacker["alive"]) or not bool(attacker["hostile"]) or str(attacker["status"]) in ["retreat", "sunk", "disabled"]:
				continue
			var target_index := _target_index(states, str(attacker["faction_id"]))
			if target_index < 0:
				continue
			var target: Dictionary = states[target_index]
			var rng := RandomNumberGenerator.new()
			rng.seed = SeedStreams.derive_stream_seed(master_seed, "far_combat.v1.%s.%s.%d" % [attacker["instance_id"], target["instance_id"], sequence])
			var attack_strength := float(attacker["strength"])
			var defense_strength := float(target["strength"])
			var ratio := attack_strength / maxf(1.0, attack_strength + defense_strength)
			var damage := clampf((0.07 + ratio * 0.22) * (0.85 + rng.randf() * 0.3), 0.02, 0.30)
			target["hull_ratio"] = maxf(0.0, float(target["hull_ratio"]) - damage)
			sequence += 1
			if float(target["hull_ratio"]) <= 0.0:
				target["alive"] = false
				target["status"] = "sunk"
			elif float(target["hull_ratio"]) <= MIN_RETREAT_HULL:
				target["status"] = "retreat"
			else:
				target["status"] = "engaged"
			states[target_index] = target
			events.append({
				"type": "far_combat_step",
				"attacker_id": attacker["instance_id"],
				"target_id": target["instance_id"],
				"sequence": sequence - 1,
				"damage_milli": int(round(damage * 1000.0)),
				"target_status": target["status"],
			})
	var factions := _active_factions(states)
	var winner := str(factions[0]) if factions.size() == 1 else ""
	var sunk: Array = []
	var retreated: Array = []
	for row in states:
		if str(row["status"]) == "sunk":
			sunk.append(row["instance_id"])
		elif str(row["status"]) == "retreat":
			retreated.append(row["instance_id"])
	return {
		"version": VERSION,
		"participants": states,
		"winner_faction_id": winner,
		"sunk_ids": sunk,
		"retreated_ids": retreated,
		"events": events,
		"next_event_sequence": sequence,
		"resolution_steps": steps,
	}


static func participant_from_far(state: Dictionary) -> Dictionary:
	if not FarFieldEntityState.valid_projection(state):
		return {}
	var combat: Dictionary = state["combat"]
	return {
		"instance_id": state["instance_id"],
		"faction_id": state["faction_id"],
		"hull_ratio": state["hull_ratio"],
		"strength": combat["strength"],
		"role": state["role"],
		"fleet_id": state["fleet_id"],
		"hostile": combat["hostile"],
		"alive": state["alive"],
		"status": combat["status"],
	}


static func _target_index(states: Array, attacker_faction: String) -> int:
	var best := -1
	for index in states.size():
		var candidate: Dictionary = states[index]
		if not bool(candidate["alive"]) or str(candidate["faction_id"]) == attacker_faction or str(candidate["status"]) in ["retreat", "sunk", "disabled"]:
			continue
		if best < 0:
			best = index
			continue
		var current: Dictionary = states[best]
		var candidate_hull := float(candidate["hull_ratio"])
		var current_hull := float(current["hull_ratio"])
		if candidate_hull < current_hull - 0.000001 or (is_equal_approx(candidate_hull, current_hull) and str(candidate["instance_id"]) < str(current["instance_id"])):
			best = index
	return best


static func _active_factions(states: Array) -> Array:
	var seen: Dictionary = {}
	for row in states:
		if bool(row["alive"]) and str(row["status"]) not in ["retreat", "sunk", "disabled"]:
			seen[str(row["faction_id"])] = true
	var result: Array = seen.keys()
	result.sort()
	return result


static func _valid_participant(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var row: Dictionary = value
	if row.size() != 9:
		return false
	for key in ["instance_id", "faction_id"]:
		if not row.get(key) is String or not SectorIds.valid(row[key]):
			return false
	if not row.get("fleet_id") is String or (not row["fleet_id"].is_empty() and not SectorIds.valid(row["fleet_id"])):
		return false
	if not row.get("role") is String or row["role"].is_empty() or row["role"].length() > 32:
		return false
	if not _finite(row.get("hull_ratio")) or float(row["hull_ratio"]) < 0.0 or float(row["hull_ratio"]) > 1.0:
		return false
	if not _finite(row.get("strength")) or float(row["strength"]) < 0.0 or float(row["strength"]) > 1000000.0:
		return false
	if not row.get("alive") is bool or not row.get("hostile") is bool or str(row.get("status", "")) not in ["idle", "engaged", "retreat", "disabled", "sunk"]:
		return false
	return true


static func _finite(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value))
