class_name UtilityDecision
extends RefCounted

const PATROL_TO_WAYPOINT := 0
const INVESTIGATE_THREAT := 1
const RETREAT_TO_SAFE_POINT := 2
const REPAIR := 3
const RESUME_PATROL := 4
const PROTECT_ALLY := 5

const SCORE_LIMIT := 100.0


static func evaluate(snapshot: Dictionary, memory: Dictionary, role: Dictionary, context: Dictionary,
		decision_sequence: int) -> Dictionary:
	if not _inputs_valid(snapshot, memory, role, context, decision_sequence):
		return {}
	var tick := int(snapshot["simulation_tick"])
	var hull_ratio := clampf(float(snapshot["observer_hull_ratio"]), 0.0, 1.0)
	var max_threat := maxf(1.0, float(context["max_threat"]))
	var perception_radius := maxf(1.0, float(context["perception_radius"]))
	var entries: Array = memory["entries"]
	var target_options: Array[Dictionary] = []
	for raw in entries:
		var entry: Dictionary = raw
		var target_score := _target_feature(entry, tick, max_threat, perception_radius, int(memory["expiry_ticks"]))
		target_options.append({
			"target_id": str(entry["stable_id"]),
			"feature": target_score,
			"threat": float(entry["threat"]) / max_threat,
		})
	target_options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["feature"]), float(b["feature"])):
			return float(a["feature"]) > float(b["feature"])
		return str(a["target_id"]) < str(b["target_id"])
	)
	var hostile_feature := float(target_options[0]["feature"]) if not target_options.is_empty() else 0.0
	var protected_threatened := bool(context.get("protected_ally_threatened", false))
	var allow_repair := bool(context.get("allow_repair", false))
	var candidates: Array[Dictionary] = []
	var patrol_score := float(role["patrol_travel"]) * (1.0 - minf(1.0, hostile_feature))
	candidates.append(_candidate(PATROL_TO_WAYPOINT, "", patrol_score, {
		"patrol_weight": float(role["patrol_travel"]),
		"hostile_feature": hostile_feature,
	}))
	for target_option in target_options:
		var target_id := str(target_option["target_id"])
		var target_feature := float(target_option["feature"])
		var threat_feature := float(target_option["threat"])
		var investigate_score := float(role["pursue_aggression"]) * (0.35 + target_feature)
		candidates.append(_candidate(INVESTIGATE_THREAT, target_id, investigate_score, {
			"aggression_weight": float(role["pursue_aggression"]),
			"target_feature": target_feature,
		}))
		var protect_score := float(role["investigate_protect"]) * (0.35 + target_feature) * (1.0 if protected_threatened else 0.15)
		candidates.append(_candidate(PROTECT_ALLY, target_id, protect_score, {
			"protect_weight": float(role["investigate_protect"]),
			"protected_ally_threatened": protected_threatened,
			"target_feature": target_feature,
		}))
		var damage_pressure := 0.35 + (1.0 - hull_ratio) * 1.65
		var retreat_score := float(role["avoid_threat"]) * maxf(threat_feature, target_feature * 0.35) * damage_pressure
		candidates.append(_candidate(RETREAT_TO_SAFE_POINT, target_id, retreat_score, {
			"avoid_weight": float(role["avoid_threat"]),
			"threat_feature": threat_feature,
			"hull_pressure": 1.0 - hull_ratio,
		}))
	if allow_repair and hull_ratio < 1.0:
		var repair_score := float(role["repair_safety"]) * (1.0 - hull_ratio) * (1.0 - minf(1.0, hostile_feature))
		candidates.append(_candidate(REPAIR, "", repair_score, {
			"repair_weight": float(role["repair_safety"]),
			"hull_pressure": 1.0 - hull_ratio,
		}))
	candidates.sort_custom(_decision_before)
	var chosen: Dictionary = candidates[0].duplicate(true)
	var previous: Dictionary = memory["hysteresis"]
	var previous_candidate := _find_previous(candidates, int(previous["intent_id"]), str(previous["target_id"]))
	if not previous_candidate.is_empty() and _should_hold(chosen, previous_candidate, previous, role, tick):
		chosen = previous_candidate.duplicate(true)
		chosen["score"] = clampf(float(chosen["score"]) + float(role["hold_bonus"]), 0.0, SCORE_LIMIT)
		chosen["reason_debug"]["hysteresis_hold"] = true
	else:
		chosen["reason_debug"]["hysteresis_hold"] = false
	var hold_until := tick + int(role["minimum_decision_hold_ticks"])
	var result := {
		"selected_intent_id": int(chosen["intent_id"]),
		"selected_target_id": str(chosen["target_id"]),
		"score": float(chosen["score"]),
		"reason_debug": chosen["reason_debug"].duplicate(true),
		"decision_tick": tick,
		"decision_sequence": decision_sequence,
		"hysteresis_state": {
			"intent_id": int(chosen["intent_id"]),
			"target_id": str(chosen["target_id"]),
			"score": float(chosen["score"]),
			"hold_until_tick": hold_until,
		},
	}
	return result if DtoContract.is_primitive_safe(result) else {}


static func _candidate(intent_id: int, target_id: String, raw_score: float, factors: Dictionary) -> Dictionary:
	var score := clampf(raw_score, 0.0, SCORE_LIMIT) if is_finite(raw_score) else 0.0
	return {"intent_id": intent_id, "target_id": target_id, "score": score, "reason_debug": factors.duplicate(true)}


static func _target_feature(entry: Dictionary, tick: int, max_threat: float, radius: float, expiry: int) -> float:
	var threat := clampf(float(entry["threat"]) / max_threat, 0.0, 1.0)
	var seen_age := maxi(0, tick - int(entry["last_seen_tick"]))
	var recency := 1.0 - clampf(float(seen_age) / float(maxi(1, expiry)), 0.0, 1.0)
	var proximity := 1.0 - clampf(float(entry["distance"]) / radius, 0.0, 1.0)
	return clampf(threat * 0.55 + recency * 0.25 + proximity * 0.20, 0.0, 1.0)


static func _decision_before(left: Dictionary, right: Dictionary) -> bool:
	if not is_equal_approx(float(left["score"]), float(right["score"])):
		return float(left["score"]) > float(right["score"])
	if int(left["intent_id"]) != int(right["intent_id"]):
		return int(left["intent_id"]) < int(right["intent_id"])
	return str(left["target_id"]) < str(right["target_id"])


static func _find_previous(candidates: Array[Dictionary], intent_id: int, target_id: String) -> Dictionary:
	for candidate in candidates:
		if int(candidate["intent_id"]) == intent_id and str(candidate["target_id"]) == target_id:
			return candidate
	return {}


static func _should_hold(chosen: Dictionary, previous_candidate: Dictionary, previous: Dictionary,
		role: Dictionary, tick: int) -> bool:
	if int(chosen["intent_id"]) == int(previous_candidate["intent_id"]) and str(chosen["target_id"]) == str(previous_candidate["target_id"]):
		return false
	if tick < int(previous["hold_until_tick"]):
		return true
	var previous_with_bonus := float(previous_candidate["score"]) + float(role["hold_bonus"])
	return float(chosen["score"]) < previous_with_bonus + float(role["switch_threshold"])


static func _inputs_valid(snapshot: Dictionary, memory: Dictionary, role: Dictionary, context: Dictionary,
		decision_sequence: int) -> bool:
	if decision_sequence <= 0 or not DtoContract.is_primitive_safe(snapshot) or not DtoContract.is_primitive_safe(memory):
		return false
	if not DtoContract.is_primitive_safe(role) or not DtoContract.is_primitive_safe(context):
		return false
	if not snapshot.get("candidates") is Array or not memory.get("entries") is Array or not memory.get("hysteresis") is Dictionary:
		return false
	for key in ["patrol_travel", "avoid_threat", "investigate_protect", "pursue_aggression", "repair_safety", "switch_threshold", "hold_bonus"]:
		if typeof(role.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(role[key])) or float(role[key]) < 0.0:
			return false
	if typeof(role.get("minimum_decision_hold_ticks")) not in [TYPE_INT, TYPE_FLOAT] or int(role["minimum_decision_hold_ticks"]) < 0:
		return false
	for key in ["max_threat", "perception_radius"]:
		if typeof(context.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(context[key])) or float(context[key]) <= 0.0:
			return false
	return true
