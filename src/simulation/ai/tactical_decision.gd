class_name TacticalDecision
extends RefCounted

const NONE := "none"
const ACQUIRE_TARGET := "acquire_target"
const MANEUVER := "maneuver"
const FIRE := "fire"
const BOARD := "board"
const RETREAT := "retreat"
const REPAIR := "repair"
const SUPPORT := "call_support"

const CLOSE_RANGE := "close_range"
const HOLD_RANGE := "hold_range"
const OPEN_RANGE := "open_range"
const ALIGN_BROADSIDE := "align_broadside"
const RETREAT_MANEUVER := "retreat"
const REPAIR_WINDOW := "repair_window"

const BAND_FAR := "far"
const BAND_HOLD := "hold"
const BAND_CLOSE := "close"


static func evaluate(context: Dictionary, decision_sequence: int) -> Dictionary:
	if decision_sequence < 0 or not DtoContract.is_primitive_safe(context):
		return {}
	var actor: Variant = context.get("actor")
	var rules: Variant = context.get("rules")
	var tuning: Variant = context.get("tuning")
	var role: Variant = context.get("role")
	var targets: Variant = context.get("targets")
	if not actor is Dictionary or not rules is Dictionary or not tuning is Dictionary or not role is Dictionary or not targets is Array:
		return {}
	if not _valid_actor(actor) or not _valid_tuning(tuning):
		return {}
	var tick := int(context.get("simulation_tick", -1))
	if tick < 0:
		return {}
	var previous: Dictionary = context.get("previous", {}) if context.get("previous", {}) is Dictionary else {}
	var preferred_target := str(previous.get("last_target_id", ""))
	var target := _pick_target(targets, preferred_target)
	var escape := _best_escape(context.get("escape_candidates", []), float(tuning["max_threat"]))
	var support_score := _support_score(context, actor, role)
	var support_requested := support_score >= float(tuning["support_score_threshold"]) and tick >= int(previous.get("next_support_tick", 0))
	if target.is_empty():
		var repair_score := _repair_score(actor, context)
		var intent := REPAIR if repair_score >= float(tuning["repair_score_threshold"]) else (SUPPORT if support_requested else NONE)
		var result := _base_result(tick, decision_sequence, intent, "", "", "", 0, Vector2(float(actor["x"]), float(actor["y"])))
		result["repair_score"] = repair_score
		result["support_score"] = support_score
		result["support_requested"] = support_requested
		result["retreat_score"] = 0.0
		result["boarding_score"] = 0.0
		result["score"] = maxf(repair_score, support_score)
		result["reason"] = "repair_window" if intent == REPAIR else ("support_disadvantage" if intent == SUPPORT else "no_tactical_target")
		return result if DtoContract.is_primitive_safe(result) else {}

	var actor_position := Vector2(float(actor["x"]), float(actor["y"]))
	var target_position := Vector2(float(target["x"]), float(target["y"]))
	if not actor_position.is_finite() or not target_position.is_finite() or actor_position == target_position:
		return {}
	var weapon: Dictionary = actor.get("weapon", {})
	var has_cannon := not weapon.is_empty() and str(target.get("target_class", "")) == TargetingService.SHIP
	var distance := actor_position.distance_to(target_position)
	var target_value := _target_value(target)
	var ammo_choice := _best_ammo(actor, target, weapon, tuning, role, target_value)
	var expected_hit := float(ammo_choice.get("expected_hit", 0.0))
	var expected_dps := float(ammo_choice.get("expected_dps", 0.0))
	var selected_ammo := str(ammo_choice.get("ammo_id", ""))
	var expected_damage := float(ammo_choice.get("expected_damage", 0.0))

	var span := maxf(0.0, float(weapon.get("max_range", 0.0)) - float(weapon.get("min_range", 0.0)))
	var preferred_min := float(weapon.get("min_range", 0.0)) + span * float(tuning["preferred_min_ratio"])
	var preferred_max := float(weapon.get("min_range", 0.0)) + span * float(tuning["preferred_max_ratio"])
	var hysteresis := span * float(tuning["range_hysteresis_ratio"])
	var range_band := _range_band(distance, preferred_min, preferred_max, hysteresis, str(previous.get("range_band", "")))
	var offset := target_position - actor_position
	var current_side := CombatAuthority.broadside(float(actor["heading"]), offset, float(weapon.get("broadside_half_arc_degrees", 35.0))) if has_cannon else 0
	var desired_side := _desired_side(float(actor["heading"]), offset.angle(), int(weapon.get("mounted_side", 0)), current_side, int(previous.get("desired_side", 0)))
	var broadside_valid := current_side != 0 and (int(weapon.get("mounted_side", 0)) == 0 or int(weapon.get("mounted_side", 0)) == current_side)
	var maneuver_id := HOLD_RANGE
	if range_band == BAND_FAR:
		maneuver_id = CLOSE_RANGE
	elif range_band == BAND_CLOSE:
		maneuver_id = OPEN_RANGE
	elif not broadside_valid:
		maneuver_id = ALIGN_BROADSIDE
	var destination := _maneuver_destination(actor_position, target_position, float(actor["heading"]), maneuver_id, desired_side, preferred_min, preferred_max, float(tuning["tactical_steering_distance"]))

	var safe_restricted := bool(actor.get("safe_zone", false)) or bool(target.get("safe_zone", false))
	var line_clear := bool(target.get("line_of_fire_clear", false))
	var reload_ready := bool(actor.get("reload_ready", false))
	var locked := str(actor.get("locked_target_id", "")) == str(target["entity_id"])
	var ammo_ready := bool(ammo_choice.get("available", not bool(actor.get("requires_ammo", false))))
	var fire_allowed := has_cannon and range_band == BAND_HOLD and broadside_valid and line_clear and reload_ready and locked and ammo_ready and not safe_restricted

	var retreat_score := _retreat_score(actor, target, context, role, expected_dps, escape)
	var repair_score := _repair_score(actor, context)
	var boarding_score := _boarding_score(actor, target, rules, context, role, target_value, safe_restricted)
	var fight_score := _fight_score(actor, target, context, role, expected_dps)
	var intent := MANEUVER
	var reason := maneuver_id
	var score := fight_score

	if retreat_score >= float(tuning["retreat_score_threshold"]) and retreat_score > fight_score and not escape.is_empty():
		intent = RETREAT
		maneuver_id = RETREAT_MANEUVER
		destination = Vector2(float(escape["x"]), float(escape["y"]))
		reason = "retreat_outlook"
		score = retreat_score
	elif repair_score >= float(tuning["repair_score_threshold"]) and int(context.get("nearby_hostile_count", 0)) == 0:
		intent = REPAIR
		maneuver_id = REPAIR_WINDOW
		destination = actor_position
		reason = "repair_window"
		score = repair_score
	elif boarding_score >= float(tuning["boarding_score_threshold"]):
		intent = BOARD
		maneuver_id = HOLD_RANGE
		destination = actor_position
		reason = "boarding_advantage"
		score = boarding_score
	elif str(actor.get("locked_target_id", "")) != str(target["entity_id"]):
		intent = ACQUIRE_TARGET
		reason = "target_lock_required"
	elif bool(actor.get("requires_ammo", false)) and selected_ammo != str(actor.get("selected_ammo_id", "")):
		intent = MANEUVER
		reason = "ammo_switch_required"
	elif fire_allowed:
		intent = FIRE
		reason = "broadside_fire_ready"
	elif support_requested and maneuver_id == HOLD_RANGE:
		intent = SUPPORT
		reason = "support_disadvantage"
		score = maxf(score, support_score)

	var result := _base_result(tick, decision_sequence, intent, str(target["entity_id"]), maneuver_id, selected_ammo, desired_side, destination)
	result["expected_hit"] = expected_hit
	result["expected_damage"] = expected_damage
	result["expected_dps"] = expected_dps
	result["score"] = score
	result["boarding_score"] = boarding_score
	result["retreat_score"] = retreat_score
	result["repair_score"] = repair_score
	result["support_score"] = support_score
	result["support_requested"] = support_requested
	result["fire_allowed"] = fire_allowed
	result["range_band"] = range_band
	result["desired_range"] = (preferred_min + preferred_max) * 0.5
	result["line_of_fire_clear"] = line_clear
	result["friendly_blocker_id"] = str(target.get("friendly_blocker_id", ""))
	result["reason"] = reason
	result["target_value"] = target_value
	result["factors"] = {
		"fight_score": fight_score,
		"safe_restricted": safe_restricted,
		"broadside_valid": broadside_valid,
		"current_side": current_side,
		"reload_ready": reload_ready,
		"ammo_score": float(ammo_choice.get("utility", 0.0)),
		"ammo_stock": int(ammo_choice.get("stock", 0)),
		"ammo_resistance": float(ammo_choice.get("resistance", 0.0)),
		"nearby_hostiles": int(context.get("nearby_hostile_count", 0)),
		"nearby_allies": int(context.get("nearby_ally_count", 0)),
		"escape_id": str(escape.get("escape_id", "")),
		"escape_score": float(escape.get("score", 0.0)),
	}
	return result if DtoContract.is_primitive_safe(result) else {}


static func expected_damage_and_dps(weapon: Dictionary, ammo: Dictionary, target: Dictionary) -> Dictionary:
	if weapon.is_empty() or target.is_empty():
		return {"expected_hit": 0.0, "expected_damage": 0.0, "expected_dps": 0.0}
	var hit := CoreCombatRules.hit_chance(float(weapon.get("accuracy", 0.0)), float(target.get("dodge", 0.0)))
	var crit := clampf(float(weapon.get("crit_chance", 0.0)) * (1.0 - float(target.get("crit_prevention", 0.0))), 0.0, 1.0)
	var base := float(ammo.get("base_damage", weapon.get("normal_damage", 0.0)))
	var element := str(ammo.get("element_id", CoreCombatRules.NEUTRAL))
	var resistance := float((target.get("resistances", {}) as Dictionary).get(element, 0.0)) if element != CoreCombatRules.NEUTRAL else 0.0
	var hull := float(target.get("hull", target.get("max_hull", CoreCombatRules.MAX_VALUE)))
	var normal := CoreCombatRules.damage(base, 1.0, resistance, float(target.get("defense", 0.0)), float(weapon.get("defense_penetration", 0.0)), hull)
	var critical := CoreCombatRules.damage(base, float(weapon.get("crit_multiplier", 1.0)), resistance, float(target.get("defense", 0.0)), float(weapon.get("defense_penetration", 0.0)), hull)
	var expected := hit * ((1.0 - crit) * float(normal["applied"]) + crit * float(critical["applied"]))
	var reload := maxf(0.000001, float(weapon.get("reload_seconds", 1.0)))
	return {"expected_hit": hit, "expected_damage": expected, "expected_dps": expected / reload, "resistance": resistance}


static func persistent_state(decision: Dictionary, previous: Dictionary, support_cooldown_ticks: int) -> Dictionary:
	var next_support := int(previous.get("next_support_tick", 0))
	if bool(decision.get("support_requested", false)):
		next_support = int(decision.get("decision_tick", 0)) + maxi(1, support_cooldown_ticks)
	return {
		"range_band": str(decision.get("range_band", previous.get("range_band", ""))),
		"desired_side": int(decision.get("desired_side", previous.get("desired_side", 0))),
		"next_support_tick": next_support,
		"last_intent": str(decision.get("tactical_intent", previous.get("last_intent", NONE))),
		"last_target_id": str(decision.get("target_id", previous.get("last_target_id", ""))),
	}


static func valid_persistent_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 5 or not DtoContract.is_primitive_safe(value):
		return false
	if str(value.get("range_band", "")) not in ["", BAND_FAR, BAND_HOLD, BAND_CLOSE]:
		return false
	if int(value.get("desired_side", 0)) not in [-1, 0, 1]:
		return false
	if typeof(value.get("next_support_tick")) not in [TYPE_INT, TYPE_FLOAT] or int(value["next_support_tick"]) < 0:
		return false
	if not value.get("last_intent") is String or not value.get("last_target_id") is String:
		return false
	var target_id := str(value["last_target_id"])
	return target_id.is_empty() or SectorIds.valid(target_id)


static func _base_result(tick: int, sequence: int, intent: String, target_id: String, maneuver_id: String,
		ammo_id: String, desired_side: int, destination: Vector2) -> Dictionary:
	return {
		"tactical_intent": intent,
		"target_id": target_id,
		"maneuver_id": maneuver_id,
		"selected_ammo_id": ammo_id,
		"desired_side": desired_side,
		"destination": {"x": destination.x, "y": destination.y},
		"expected_hit": 0.0,
		"expected_damage": 0.0,
		"expected_dps": 0.0,
		"score": 0.0,
		"boarding_score": 0.0,
		"retreat_score": 0.0,
		"repair_score": 0.0,
		"support_score": 0.0,
		"support_requested": false,
		"fire_allowed": false,
		"range_band": "",
		"desired_range": 0.0,
		"line_of_fire_clear": false,
		"friendly_blocker_id": "",
		"reason": "",
		"target_value": 0.0,
		"factors": {},
		"decision_tick": tick,
		"decision_sequence": sequence,
	}


static func _pick_target(targets: Array, preferred_id: String) -> Dictionary:
	if not preferred_id.is_empty():
		for raw in targets:
			if raw is Dictionary and str(raw.get("entity_id", "")) == preferred_id:
				return raw
	for raw in targets:
		if raw is Dictionary and bool(raw.get("alive", false)) and bool(raw.get("selectable", false)):
			return raw
	return {}


static func _target_value(target: Dictionary) -> float:
	var hull_ratio := clampf(float(target.get("hull_ratio", 1.0)), 0.0, 1.0)
	var threat := clampf(float(target.get("threat_ratio", 0.0)), 0.0, 1.0)
	var class_weight := 0.25 if str(target.get("target_class", "")) == TargetingService.SHIP else 0.1
	return clampf(0.25 + class_weight + threat * 0.30 + (1.0 - hull_ratio) * 0.20, 0.0, 1.0)


static func _best_ammo(actor: Dictionary, target: Dictionary, weapon: Dictionary, tuning: Dictionary, role: Dictionary, target_value: float) -> Dictionary:
	if weapon.is_empty():
		return {}
	var requires_ammo := bool(actor.get("requires_ammo", false))
	var candidates: Array = actor.get("ammo_candidates", [])
	if not requires_ammo:
		var neutral := {"ammo_id": "", "element_id": CoreCombatRules.NEUTRAL, "base_damage": float(weapon.get("normal_damage", 0.0)), "stock": 2147483647, "available": true}
		var estimate := expected_damage_and_dps(weapon, neutral, target)
		neutral.merge(estimate, true)
		neutral["utility"] = float(estimate["expected_dps"])
		neutral["resistance"] = float(estimate.get("resistance", 0.0))
		return neutral
	var best: Dictionary = {}
	var best_score := -INF
	var reserve := maxi(1, int(tuning["ammo_reserve_stock"]))
	var conservation := float(role.get("ammo_conservation", 1.0))
	for raw in candidates:
		if not raw is Dictionary or not bool(raw.get("available", false)) or int(raw.get("stock", 0)) <= 0:
			continue
		var estimate := expected_damage_and_dps(weapon, raw, target)
		var scarcity := clampf(float(reserve - int(raw.get("stock", 0))) / float(reserve), 0.0, 1.0)
		var reserve_penalty := scarcity * float(tuning["ammo_scarcity_penalty"]) * conservation * (1.0 - target_value * 0.75)
		var resistance := float(estimate.get("resistance", 0.0))
		var elemental := clampf(-resistance, -1.0, 1.0) * maxf(1.0, float(estimate["expected_dps"]) * 0.25)
		var switch_penalty := float(tuning["ammo_switch_penalty"]) if str(raw.get("ammo_id", "")) != str(actor.get("selected_ammo_id", "")) else 0.0
		var status_utility := 0.05 * float(estimate["expected_dps"]) if not str(raw.get("status_id", "")).is_empty() else 0.0
		var score := float(estimate["expected_dps"]) + elemental + status_utility - reserve_penalty * maxf(1.0, float(estimate["expected_dps"])) - switch_penalty
		var id := str(raw.get("ammo_id", ""))
		if score > best_score or (is_equal_approx(score, best_score) and (best.is_empty() or id < str(best["ammo_id"]))):
			best_score = score
			best = raw.duplicate(true)
			best.merge(estimate, true)
			best["utility"] = score
			best["resistance"] = resistance
	return best


static func _range_band(distance: float, preferred_min: float, preferred_max: float, hysteresis: float, previous: String) -> String:
	if previous == BAND_FAR and distance > preferred_max - hysteresis:
		return BAND_FAR
	if previous == BAND_CLOSE and distance < preferred_min + hysteresis:
		return BAND_CLOSE
	if distance > preferred_max:
		return BAND_FAR
	if distance < preferred_min:
		return BAND_CLOSE
	return BAND_HOLD


static func _desired_side(heading: float, target_bearing: float, mounted_side: int, current_side: int, previous_side: int) -> int:
	if mounted_side in [ShipMotor.SIDE_PORT, ShipMotor.SIDE_STARBOARD]:
		return mounted_side
	if current_side in [ShipMotor.SIDE_PORT, ShipMotor.SIDE_STARBOARD]:
		return current_side
	if previous_side in [ShipMotor.SIDE_PORT, ShipMotor.SIDE_STARBOARD]:
		return previous_side
	var starboard_heading := target_bearing - PI * 0.5
	var port_heading := target_bearing + PI * 0.5
	var starboard_turn := absf(ShipMotor.signed_angular_difference(heading, starboard_heading))
	var port_turn := absf(ShipMotor.signed_angular_difference(heading, port_heading))
	if is_equal_approx(starboard_turn, port_turn):
		return ShipMotor.SIDE_PORT
	return ShipMotor.SIDE_STARBOARD if starboard_turn < port_turn else ShipMotor.SIDE_PORT


static func _maneuver_destination(actor_position: Vector2, target_position: Vector2, heading: float, maneuver: String,
		desired_side: int, preferred_min: float, preferred_max: float, steering_distance: float) -> Vector2:
	var delta := target_position - actor_position
	var direction := delta.normalized()
	var desired_range := maxf(1.0, (preferred_min + preferred_max) * 0.5)
	match maneuver:
		CLOSE_RANGE:
			return target_position - direction * desired_range
		OPEN_RANGE:
			return actor_position - direction * steering_distance
		ALIGN_BROADSIDE:
			var target_bearing := delta.angle()
			var desired_heading := target_bearing - PI * 0.5 if desired_side == ShipMotor.SIDE_STARBOARD else target_bearing + PI * 0.5
			return actor_position + Vector2.from_angle(desired_heading) * steering_distance
		_:
			return actor_position


static func _retreat_score(actor: Dictionary, target: Dictionary, context: Dictionary, role: Dictionary, expected_dps: float, escape: Dictionary) -> float:
	if escape.is_empty():
		return 0.0
	var hull_pressure := 1.0 - clampf(float(actor.get("hull_ratio", 1.0)), 0.0, 1.0)
	var hostiles := float(context.get("nearby_hostile_count", 0))
	var allies := float(context.get("nearby_ally_count", 0))
	var numerical := clampf((hostiles - allies) / maxf(1.0, hostiles), 0.0, 1.0)
	var threat := clampf(float(target.get("threat_ratio", 0.0)), 0.0, 1.0)
	var target_hull := maxf(1.0, float(target.get("max_hull", 1.0)))
	var outlook := 1.0 - clampf(expected_dps / target_hull * 10.0, 0.0, 1.0)
	var ammo_pressure := 1.0 if bool(actor.get("requires_ammo", false)) and int(actor.get("available_ammo_count", 0)) == 0 else 0.0
	var escape_quality := clampf(float(escape.get("score", 0.0)), 0.0, 1.0)
	return clampf((hull_pressure * 0.35 + numerical * 0.20 + threat * 0.15 + outlook * 0.10 + ammo_pressure * 0.10 + escape_quality * 0.10) * float(role.get("tactical_retreat", 1.0)), 0.0, 2.0)


static func _repair_score(actor: Dictionary, context: Dictionary) -> float:
	if not bool(actor.get("repair_available", false)) or not bool(actor.get("repair_ready", false)):
		return 0.0
	var pressure := 1.0 - clampf(float(actor.get("hull_ratio", 1.0)), 0.0, 1.0)
	var danger := clampf(float(context.get("nearby_hostile_count", 0)) / 3.0, 0.0, 1.0)
	var safe_bonus := 0.25 if bool(actor.get("safe_zone", false)) else 0.0
	return clampf(pressure * (1.0 - danger) + safe_bonus, 0.0, 1.5)


static func _boarding_score(actor: Dictionary, target: Dictionary, rules: Dictionary, context: Dictionary, role: Dictionary, target_value: float, safe_restricted: bool) -> float:
	if safe_restricted or str(target.get("target_class", "")) != TargetingService.SHIP or not bool(actor.get("boarding_ready", false)):
		return 0.0
	if float(target.get("hull_ratio", 1.0)) > float(rules.get("board_threshold", 0.0)):
		return 0.0
	if float(target.get("distance", INF)) > float(rules.get("board_range", 0.0)):
		return 0.0
	var advantage := float(actor.get("boarding_power", 0.0)) - float(target.get("boarding_protection", 0.0))
	if advantage <= 0.0:
		return 0.0
	var hostiles := int(context.get("nearby_hostile_count", 0))
	var allies := int(context.get("nearby_ally_count", 0))
	if hostiles > allies + 1:
		return 0.0
	var hull := clampf(float(actor.get("hull_ratio", 1.0)), 0.0, 1.0)
	var advantage_norm := clampf(advantage / maxf(1.0, float(target.get("boarding_protection", 0.0)) + advantage), 0.0, 1.0)
	return clampf((target_value * 0.35 + advantage_norm * 0.35 + hull * 0.20 + 0.10) * float(role.get("tactical_boarding", 1.0)), 0.0, 2.0)


static func _support_score(context: Dictionary, actor: Dictionary, role: Dictionary) -> float:
	var hostiles := float(context.get("nearby_hostile_count", 0))
	var allies := float(context.get("nearby_ally_count", 0))
	var numerical := clampf((hostiles - allies) / maxf(1.0, hostiles), 0.0, 1.0)
	var hull_pressure := 1.0 - clampf(float(actor.get("hull_ratio", 1.0)), 0.0, 1.0)
	return clampf((numerical * 0.65 + hull_pressure * 0.35) * float(role.get("tactical_support", 1.0)), 0.0, 2.0)


static func _fight_score(actor: Dictionary, target: Dictionary, context: Dictionary, role: Dictionary, expected_dps: float) -> float:
	var self_hull := clampf(float(actor.get("hull_ratio", 1.0)), 0.0, 1.0)
	var target_hull := maxf(1.0, float(target.get("max_hull", 1.0)))
	var damage_outlook := clampf(expected_dps / target_hull * 10.0, 0.0, 1.0)
	var hostiles := float(context.get("nearby_hostile_count", 0))
	var allies := float(context.get("nearby_ally_count", 0))
	var support := clampf((allies + 1.0) / maxf(1.0, hostiles + 1.0), 0.0, 1.0)
	return clampf((self_hull * 0.45 + damage_outlook * 0.35 + support * 0.20) * float(role.get("tactical_fight", 1.0)), 0.0, 2.0)


static func _best_escape(raw_candidates: Variant, max_threat: float) -> Dictionary:
	if not raw_candidates is Array:
		return {}
	var best: Dictionary = {}
	var best_score := -INF
	for raw in raw_candidates:
		if not raw is Dictionary:
			continue
		var weighted := maxf(0.0, float(raw.get("weighted_path_cost", INF)))
		var geometric := maxf(0.0, float(raw.get("geometric_distance", INF)))
		var clearance := maxf(0.0, float(raw.get("enemy_clearance", 0.0)))
		if not is_finite(weighted) or not is_finite(geometric) or not is_finite(clearance):
			continue
		var hazard_ratio := clampf((weighted - geometric) / maxf(1.0, weighted), 0.0, 1.0)
		var distance_ratio := clampf(geometric / 1000.0, 0.0, 1.0)
		var clearance_score := clampf(clearance / 500.0, 0.0, 1.0)
		var safe_bonus := 0.25 if bool(raw.get("safe_zone", false)) else 0.0
		var score := clampf(0.55 * clearance_score + safe_bonus - 0.35 * hazard_ratio - 0.15 * distance_ratio, -1.0, 1.0)
		var id := str(raw.get("escape_id", ""))
		if score > best_score or (is_equal_approx(score, best_score) and (best.is_empty() or id < str(best.get("escape_id", "")))):
			best_score = score
			best = raw.duplicate(true)
			best["score"] = clampf((score + 1.0) * 0.5, 0.0, 1.0)
	return best


static func _valid_actor(actor: Dictionary) -> bool:
	for key in ["x", "y", "heading", "hull_ratio"]:
		if typeof(actor.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(actor[key])):
			return false
	return float(actor["hull_ratio"]) >= 0.0 and float(actor["hull_ratio"]) <= 1.0


static func _valid_tuning(tuning: Dictionary) -> bool:
	for key in ["preferred_min_ratio", "preferred_max_ratio", "range_hysteresis_ratio", "ammo_scarcity_penalty", "ammo_switch_penalty", "retreat_score_threshold", "repair_score_threshold", "boarding_score_threshold", "support_score_threshold", "tactical_steering_distance"]:
		if typeof(tuning.get(key)) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(tuning[key])):
			return false
	return float(tuning["preferred_min_ratio"]) >= 0.0 and float(tuning["preferred_max_ratio"]) <= 1.0 and float(tuning["preferred_min_ratio"]) < float(tuning["preferred_max_ratio"])
