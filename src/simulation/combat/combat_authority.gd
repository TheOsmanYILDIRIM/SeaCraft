class_name CombatAuthority
extends RefCounted

signal ship_sunk(entity_id: String, sequence_id: int)
signal monster_defeated(entity_id: String, sequence_id: int)
signal wreck_destroyed(entity_id: String, sequence_id: int)
signal hull_damaged(target_entity_id: String, attacker_entity_id: String, amount: float, remaining_hull: float, sequence_id: int)

const FIRE := "fire_weapon"
const HARPOON := "fire_harpoon"
const SELECT := "select_combat_target"
const MAX_RELOAD_SECONDS := 3600.0
const MAX_MONSTERS_PER_SECTOR := 16
const AMMO_SELECT := "select_ammo"
const REPAIR := "repair_hull"
const BOARD := "board_ship"
const ACTION := "use_action_item"
const BOARD_RANGE := 120.0
const BOARD_THRESHOLD := 0.45
const BOARD_COOLDOWN := 240

var _enabled := true
var _inventory: LootAuthority
var _ammo_profiles: Dictionary = {}
var _status_actors: Dictionary = {}

var _sector: SectorRuntime
var _streams: SeedStreams
var _targeting := TargetingService.new()
var _roster: Dictionary = {}
var _tick := 0
var _sequence := 0
var _tick_rate: int


func _init(sector: SectorRuntime, streams: SeedStreams, tick_rate: int = 60, enabled: bool = true) -> void:
	_sector = sector
	_streams = streams
	_tick_rate = clampi(tick_rate, 1, 1000)
	_enabled = enabled


# Configuration is copied at registration; no Resource loading, sorting or copying on fire.
func register(id: String, faction: String, max_hull: float, weapon: WeaponDefinition = null,
		defense: float = 0.0, dodge: float = 0.0, selectable: bool = true,
		attack_modifiers: Dictionary = {}, mounted_side: int = 0,
		target_class: String = TargetingService.SHIP) -> bool:
	if _sector == null or not SectorIds.valid(id) or not SectorIds.valid(faction) or _roster.has(id) or not TargetingService.target_class_valid(target_class):
		return false
	if not _sector.entity_position(id).is_finite() or not CoreCombatRules.bounded(max_hull, 0.000001, CoreCombatRules.MAX_VALUE):
		return false
	if not CoreCombatRules.bounded(defense, 0.0, CoreCombatRules.MAX_VALUE) or not probability(dodge) or absi(mounted_side) > 1:
		return false
	var ship := CombatantState.new()
	ship.faction_id = faction
	ship.sector_id = _sector.sector_id
	ship.last_position = _sector.entity_position(id)
	ship.target_class = target_class
	ship.max_hull = max_hull
	ship.hull = max_hull
	ship.defense = defense
	ship.dodge = dodge
	ship.selectable = selectable
	if weapon != null:
		if not _valid_weapon(weapon) or not _valid_modifiers(attack_modifiers):
			return false
		var normal := CoreCombatRules.base_damage(weapon, null, attack_modifiers)
		if not is_finite(normal):
			return false
		ship.normal_damage = normal
		ship.attack_modifiers = attack_modifiers.duplicate(true)
		ship.battery = WeaponBattery.new()
		ship.battery.weapon = weapon.duplicate() as WeaponDefinition
		ship.battery.mounted_side = mounted_side
		ship.battery.reload_ticks = maxi(1, ceili(weapon.reload_seconds * _tick_rate))
	_roster[id] = ship
	return true


func register_dormant(id: String, faction: String, max_hull: float, sector_id: String, position: Vector2,
		target_class: String = TargetingService.SHIP) -> bool:
	if not SectorIds.valid(id) or not SectorIds.valid(faction) or not SectorIds.valid(sector_id) or _roster.has(id):
		return false
	if not TargetingService.target_class_valid(target_class) or not position.is_finite() or not CoreCombatRules.bounded(max_hull, 0.000001, CoreCombatRules.MAX_VALUE):
		return false
	var actor := CombatantState.new()
	actor.faction_id = faction
	actor.sector_id = sector_id
	actor.last_position = position
	actor.target_class = target_class
	actor.max_hull = max_hull
	actor.hull = max_hull
	_roster[id] = actor
	return true


func rebind_sector(sector: SectorRuntime, transferred_entity_id: String) -> bool:
	if sector == null or not SectorIds.valid(transferred_entity_id):
		return false
	if _sector != null:
		for id in _roster:
			var actor: CombatantState = _roster[id]
			if actor.sector_id == _sector.sector_id:
				var old_position := _sector.entity_position(id)
				if old_position.is_finite():
					actor.last_position = old_position
	var transferred: CombatantState = _roster.get(transferred_entity_id)
	if transferred != null:
		var transferred_position := sector.entity_position(transferred_entity_id)
		if not transferred_position.is_finite():
			return false
		transferred.sector_id = sector.sector_id
		transferred.last_position = transferred_position
	_sector = sector
	for id in _roster:
		var actor: CombatantState = _roster[id]
		if actor.sector_id != _sector.sector_id:
			continue
		var current := _sector.entity_position(id)
		if not current.is_finite():
			if not actor.last_position.is_finite() or not _sector.bounds.has_point(actor.last_position) or not _sector.register_entity(id, actor.last_position):
				return false
		else:
			actor.last_position = current
	for actor: CombatantState in _roster.values():
		if actor.locked_id.is_empty():
			continue
		var target: CombatantState = _roster.get(actor.locked_id)
		if target == null or target.sector_id != actor.sector_id:
			actor.locked_id = ""
	return true


func advance_tick() -> void:
	_tick = mini(_tick + 1, CoreCombatRules.MAX_CLOCK)
	if _status_actors.is_empty():
		return
	for actor_id in _status_actors.keys():
		var ship: CombatantState = _roster[actor_id]
		for id in ship.statuses.keys():
			if int(ship.statuses[id]["expires"]) <= _tick:
				ship.statuses.erase(id)
		if ship.statuses.is_empty():
			_status_actors.erase(actor_id)


func acquire(attacker_id: String, point: Vector2, radius: float) -> String:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		return ""
	return _targeting.acquire(_sector, point, radius, attacker_id, attacker.faction_id, _roster)


func acquisition_inspected() -> int:
	return _targeting.last_inspected


func select(attacker_id: String, target_id: String) -> bool:
	var attacker: CombatantState = _roster.get(attacker_id)
	if not _enabled or attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		return false
	if not TargetingService.rejection(_sector, attacker_id, attacker.faction_id, target_id, _roster).is_empty():
		return false
	attacker.locked_id = target_id
	return true


func clear_target(attacker_id: String) -> void:
	var attacker: CombatantState = _roster.get(attacker_id)
	if _enabled and attacker != null:
		attacker.locked_id = ""


func locked_target(attacker_id: String) -> String:
	var attacker: CombatantState = _roster.get(attacker_id)
	if attacker == null or attacker.sunk() or not _sector.entity_position(attacker_id).is_finite():
		clear_target(attacker_id)
		return ""
	if not TargetingService.rejection(_sector, attacker_id, attacker.faction_id, attacker.locked_id, _roster).is_empty():
		attacker.locked_id = ""
	return attacker.locked_id


func hull(id: String) -> float:
	var ship: CombatantState = _roster.get(id)
	return ship.hull if ship != null else 0.0


func has_combatant(id: String) -> bool:
	return _roster.has(id)


func target_class(id: String) -> String:
	var actor: CombatantState = _roster.get(id)
	return actor.target_class if actor != null else ""


func target_snapshot(id: String) -> Dictionary:
	var actor: CombatantState = _roster.get(id)
	if actor == null or _sector == null:
		return {}
	var position := _sector.entity_position(id) if actor.sector_id == _sector.sector_id else actor.last_position
	return {
		"entity_id": id,
		"target_class": actor.target_class,
		"hull": actor.hull,
		"max_hull": actor.max_hull,
		"x": position.x,
		"y": position.y,
		"selectable": actor.selectable,
	}


func sequence_id() -> int:
	return _sequence


func register_monster(id: String, definition: MonsterDefinition, anchor_id: String) -> bool:
	if definition == null or not definition.valid() or _sector == null or _roster.has(id) or not SectorIds.valid(id):
		return false
	var count := 0
	for actor: CombatantState in _roster.values():
		if actor.sector_id == _sector.sector_id and actor.target_class == TargetingService.MONSTER:
			count += 1
	if count >= MAX_MONSTERS_PER_SECTOR:
		return false
	var anchor := _sector.anchor(anchor_id)
	if anchor == null or anchor.category != "monster_territory" or not _sector.navigation.accessible(anchor.position):
		return false
	if not _sector.register_entity(id, anchor.position):
		return false
	if not register(id, definition.faction_id, definition.max_health, null, 0.0, 0.0, true, {}, 0, TargetingService.MONSTER):
		_sector.remove_entity(id)
		return false
	var monster: CombatantState = _roster[id]
	monster.resistances = definition.elemental_resistances.duplicate(true)
	monster.territory_anchor_id = anchor_id
	monster.territory_center = anchor.position
	monster.territory_radius = definition.territory_radius
	return true


func mount_harpoon(id: String, profile: HarpoonProfile) -> bool:
	var actor: CombatantState = _roster.get(id)
	if actor == null or actor.harpoon != null or profile == null or not profile.valid():
		return false
	actor.harpoon = profile.duplicate() as HarpoonProfile
	return actor.harpoon != null


func update_monster_position(id: String, requested_position: Vector2) -> bool:
	var monster: CombatantState = _roster.get(id)
	if monster == null or monster.target_class != TargetingService.MONSTER or monster.sunk() or not requested_position.is_finite() or monster.territory_radius <= 0.0:
		return false
	var offset := requested_position - monster.territory_center
	var bounded := requested_position
	if offset.length() > monster.territory_radius:
		bounded = monster.territory_center + offset.normalized() * monster.territory_radius
	if _sector.navigation == null or not _sector.navigation.accessible(bounded):
		return false
	var moved := _sector.move_entity(id, bounded)
	if moved:
		monster.last_position = bounded
	return moved


func retire_destroyed(id: String) -> bool:
	var target: CombatantState = _roster.get(id)
	if target == null or not target.sunk() or target.target_class not in [TargetingService.MONSTER, TargetingService.WRECK]:
		return false
	_status_actors.erase(id)
	_roster.erase(id)
	if _sector.entity_position(id).is_finite():
		_sector.remove_entity(id)
	return true


func faction_id(id: String) -> String:
	var ship: CombatantState = _roster.get(id)
	return ship.faction_id if ship != null else ""


func is_alive(id: String) -> bool:
	var ship: CombatantState = _roster.get(id)
	return ship != null and not ship.sunk() and _sector != null and ship.sector_id == _sector.sector_id and _sector.entity_position(id).is_finite()


func hostile(observer_id: String, other_id: String) -> bool:
	if observer_id == other_id:
		return false
	var observer: CombatantState = _roster.get(observer_id)
	var other: CombatantState = _roster.get(other_id)
	return observer != null and other != null and not other.sunk() and observer.faction_id != other.faction_id


func hull_ratio(id: String) -> float:
	var ship: CombatantState = _roster.get(id)
	if ship == null or not is_finite(ship.max_hull) or ship.max_hull <= 0.0:
		return 0.0
	return clampf(ship.hull / ship.max_hull, 0.0, 1.0)


# Configuration entrypoints are used by the trusted world adapter, never by intents.
func attach_inventory(inventory: LootAuthority) -> bool:
	if inventory == null or _inventory != null:
		return false
	_inventory = inventory
	return true


func register_ammo(profile: AmmoProfile) -> bool:
	if profile == null or not profile.valid() or not CoreCombatRules.element_valid(profile.element_id) or (not profile.status_id.is_empty() and not CoreCombatRules.STATUSES.has(profile.status_id)) or _ammo_profiles.has(profile.stable_id) or _ammo_profiles.size() >= 16:
		return false
	_ammo_profiles[profile.stable_id] = profile.duplicate() as AmmoProfile
	return true


func mount_ammo(id: String, ids: PackedStringArray) -> bool:
	var actor: CombatantState = _roster.get(id)
	if actor == null or actor.battery == null or not actor.ammo_damage.is_empty() or ids.is_empty() or ids.size() > 16:
		return false
	var computed: Dictionary = {}
	for ammo_id in ids:
		var profile: AmmoProfile = _ammo_profiles.get(ammo_id)
		if profile == null or computed.has(ammo_id):
			return false
		var damage := CoreCombatRules.base_damage(actor.battery.weapon, profile, actor.attack_modifiers)
		if not is_finite(damage):
			return false
		computed[ammo_id] = damage
	actor.ammo_damage = computed
	actor.selected_ammo = ids[0]
	return true


func configure_defense(id: String, critical_prevention: float, resistance: Dictionary, boarding_power: float, boarding_protection: float) -> bool:
	var actor: CombatantState = _roster.get(id)
	if actor == null or not probability(critical_prevention) or not CoreCombatRules.valid_resistances(resistance) or not CoreCombatRules.bounded(boarding_power, 0.0, 10000.0) or not CoreCombatRules.bounded(boarding_protection, 0.0, 10000.0):
		return false
	actor.crit_prevention = critical_prevention
	actor.resistances = resistance.duplicate(true)
	actor.boarding_power = boarding_power
	actor.boarding_protection = boarding_protection
	return true


func configure_repair(id: String, amount: float, interval_ticks: int, item_id: String, ai_controlled: bool = false) -> bool:
	var actor: CombatantState = _roster.get(id)
	if actor == null or not CoreCombatRules.bounded(amount, 0.000001, actor.max_hull) or interval_ticks <= 0 or interval_ticks > CoreCombatRules.MAX_DURATION or not SectorIds.valid(item_id):
		return false
	if actor.repair_interval != 0:
		return actor.repair_amount == amount and actor.repair_interval == interval_ticks and actor.repair_item == item_id and actor.repair_is_ai == ai_controlled
	actor.repair_amount = amount
	actor.repair_interval = interval_ticks
	actor.repair_item = item_id
	actor.repair_is_ai = ai_controlled
	return true


static func intent(kind: String, id: String = "") -> Dictionary:
	return {"domain": GameplayCommand.DOMAIN_GAMEPLAY, "type": kind, "id": id}


func transact(actor_id: String, command: Dictionary) -> Dictionary:
	return _transact(actor_id, command, _tick, false)


# AI is a trusted local authority adapter. Scheduler time is not accepted from player intents.
func _ai_repair(actor_id: String, decision_tick: int) -> Dictionary:
	return _transact(actor_id, intent(REPAIR), decision_tick, true)


func _transact(actor_id: String, command: Dictionary, now: int, ai: bool) -> Dictionary:
	var result := {"accepted": false, "reason": "", "sequence_id": 0, "success": false, "amount": 0.0, "reward_id": ""}
	if not _enabled:
		return _reject(result, "authority_disabled")
	if command.size() not in [3, 4] or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY or not command.get("type") is String or not command.get("id") is String or (command.size() == 4 and (command.get("type") != ACTION or not command.get("target_id") is String)):
		return _reject(result, "malformed_command")
	if not is_alive(actor_id):
		return _reject(result, "invalid_actor")
	if not _clock_available(now):
		return _reject(result, "clock_exhausted")
	var actor: CombatantState = _roster[actor_id]
	var id: String = command["id"]
	var kind: String = command["type"]
	var item := ""
	var cooldown := 0
	var amount := 0.0
	var success := true
	var status := ""
	var recipient_id := actor_id
	var recipient := actor
	match kind:
		AMMO_SELECT:
			if not actor.ammo_damage.has(id):
				return _reject(result, "invalid_ammo")
			var profile: AmmoProfile = _ammo_profiles[id]
			if not _can_pay(actor_id, profile.item_id):
				return _reject(result, "insufficient_resource")
			actor.selected_ammo = id
			result["accepted"] = true
			result["success"] = true
			return result
		REPAIR:
			if not id.is_empty() or actor.repair_interval == 0 or ai != actor.repair_is_ai:
				return _reject(result, "repair_not_configured")
			if not ai and actor.damage_tick >= 0 and now < actor.damage_tick + 120:
				return _reject(result, "repair_interrupted")
			amount = minf(actor.repair_amount, actor.max_hull - actor.hull)
			if amount <= 0.0:
				return _reject(result, "full_hull")
			item = actor.repair_item
			cooldown = actor.repair_interval
		BOARD:
			var reason := TargetingService.rejection(_sector, actor_id, actor.faction_id, id, _roster)
			if not reason.is_empty():
				return _reject(result, reason)
			if _sector.entity_position(actor_id).distance_to(_sector.entity_position(id)) > BOARD_RANGE:
				return _reject(result, "out_of_range")
			if hull_ratio(id) > BOARD_THRESHOLD:
				return _reject(result, "hull_threshold")
			var target: CombatantState = _roster[id]
			success = actor.boarding_power > target.boarding_protection
			item = CoreCombatRules.STOWED
			cooldown = BOARD_COOLDOWN
		ACTION:
			var profile: Dictionary = CoreCombatRules.ACTIONS.get(id, {})
			if profile.is_empty():
				return _reject(result, "invalid_action")
			var requested_target: String = command.get("target_id", "")
			match str(profile["target"]):
				"self":
					if not requested_target.is_empty() and requested_target != actor_id:
						return _reject(result, "invalid_action_target")
				"hostile":
					var reason := TargetingService.rejection(_sector, actor_id, actor.faction_id, requested_target, _roster)
					if not reason.is_empty():
						return _reject(result, reason)
					if _sector.entity_position(actor_id).distance_to(_sector.entity_position(requested_target)) > float(profile["range"]):
						return _reject(result, "out_of_range")
					recipient_id = requested_target
					recipient = _roster[requested_target]
					var safe_reason := _hostile_damage_rejection(actor_id, requested_target)
					if not safe_reason.is_empty():
						return _reject(result, safe_reason)
				_:
					return _reject(result, "invalid_action")
			status = profile["status"]
			item = profile["item_id"]
			cooldown = profile["cooldown"]
		_:
			return _reject(result, "unknown_intent")
	var key := id if kind == ACTION else kind
	if now < int(actor.ready.get(key, 0)):
		return _reject(result, "cooldown")
	if not _pay(actor_id, item):
		return _reject(result, "insufficient_resource")
	actor.ready[key] = now + cooldown
	if amount > 0.0:
		actor.hull = minf(actor.max_hull, actor.hull + amount)
	if not status.is_empty():
		_apply_status(recipient_id, recipient, status, actor_id)
	_sequence += 1
	result["accepted"] = true
	result["sequence_id"] = _sequence
	result["success"] = success
	result["amount"] = amount
	if kind == BOARD and success:
		result["reward_id"] = "reward.boarding_salvage"
	return result


func _hostile_damage_rejection(attacker_id: String, target_id: String) -> String:
	if _sector == null:
		return "invalid_sector"
	if _sector.entity_in_safe_zone(attacker_id) or _sector.entity_in_safe_zone(target_id):
		return "safe_zone"
	return ""


func _can_pay(actor_id: String, item: String) -> bool:
	return item.is_empty() or (_inventory != null and _inventory.can_consume(actor_id, item, 1))


func _pay(actor_id: String, item: String) -> bool:
	return item.is_empty() or (_inventory != null and _inventory.consume(actor_id, item, 1))


func _clock_available(now: int) -> bool:
	return now >= 0 and now <= CoreCombatRules.MAX_CLOCK - CoreCombatRules.MAX_DURATION and _sequence < CoreCombatRules.MAX_CLOCK


func _apply_status(actor_id: String, actor: CombatantState, id: String, source: String) -> void:
	_status_actors[actor_id] = true
	var profile: Dictionary = CoreCombatRules.STATUSES[id]
	var previous: Dictionary = actor.statuses.get(id, {})
	actor.statuses[id] = {"stacks": mini(int(previous.get("stacks", 0)) + 1, int(profile["max_stacks"])), "expires": _tick + int(profile["duration"]), "source": source}


func snapshot_state() -> Dictionary:
	var combatants: Array = []
	var ids: Array = _roster.keys()
	ids.sort()
	for id_value in ids:
		var id: String = id_value
		var ship: CombatantState = _roster[id]
		var battery: Dictionary = {}
		if ship.battery != null:
			battery = {
				"ready_tick": ship.battery.ready_tick,
				"last_side": ship.battery.last_side,
			}
		var position := _sector.entity_position(id) if ship.sector_id == _sector.sector_id else ship.last_position
		if position.is_finite():
			ship.last_position = position
		combatants.append({
			"entity_id": id,
			"sector_id": ship.sector_id,
			"hull": ship.hull,
			"locked_id": ship.locked_id,
			"battery": battery,
			"position": {"x": position.x, "y": position.y},
			"core": {"selected_ammo": ship.selected_ammo, "statuses": ship.statuses.duplicate(true), "ready": ship.ready.duplicate(true), "damage_tick": ship.damage_tick, "harpoon_ready_tick": ship.harpoon_ready_tick},
		})
	return {"tick": _tick, "sequence": _sequence, "combatants": combatants}


func restore_state(value: Variant) -> bool:
	if not value is Dictionary or value.size() != 3:
		return false
	var state: Dictionary = value
	if not _state_integer(state.get("tick")) or int(state["tick"]) < 0:
		return false
	if not _state_integer(state.get("sequence")) or int(state["sequence"]) < 0:
		return false
	var raw_combatants: Variant = state.get("combatants")
	if not raw_combatants is Array or raw_combatants.size() != _roster.size():
		return false
	var planned: Dictionary = {}
	for raw in raw_combatants:
		if not raw is Dictionary or raw.size() not in [4, 5, 6, 7] or (raw.size() >= 5 and not raw.has("core")):
			return false
		var entry: Dictionary = raw
		var raw_id: Variant = entry.get("entity_id")
		if not raw_id is String or not SectorIds.valid(raw_id) or not _roster.has(raw_id) or planned.has(raw_id):
			return false
		var ship: CombatantState = _roster[raw_id]
		var restored_sector: Variant = entry.get("sector_id", ship.sector_id if not ship.sector_id.is_empty() else _sector.sector_id)
		if not restored_sector is String or not SectorIds.valid(restored_sector):
			return false
		if typeof(entry.get("hull")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var restored_hull := float(entry["hull"])
		if not is_finite(restored_hull) or restored_hull < 0.0 or restored_hull > ship.max_hull:
			return false
		var raw_lock: Variant = entry.get("locked_id")
		if not raw_lock is String or (not raw_lock.is_empty() and not SectorIds.valid(raw_lock)):
			return false
		var raw_battery: Variant = entry.get("battery")
		if not raw_battery is Dictionary:
			return false
		if ship.battery == null:
			if not raw_battery.is_empty():
				return false
		else:
			if raw_battery.size() != 2 or not _state_integer(raw_battery.get("ready_tick")) or int(raw_battery["ready_tick"]) < 0:
				return false
			if not _state_integer(raw_battery.get("last_side")) or absi(int(raw_battery["last_side"])) > 1:
				return false
		var raw_position: Variant = entry.get("position", {"x": _sector.entity_position(raw_id).x, "y": _sector.entity_position(raw_id).y})
		if not raw_position is Dictionary or raw_position.size() != 2 or typeof(raw_position.get("x")) not in [TYPE_INT, TYPE_FLOAT] or typeof(raw_position.get("y")) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		var restored_position := Vector2(float(raw_position["x"]), float(raw_position["y"]))
		if not restored_position.is_finite() or (restored_sector == _sector.sector_id and not _sector.bounds.has_point(restored_position)):
			return false
		var core: Variant = entry.get("core", {"selected_ammo": ship.selected_ammo, "statuses": {}, "ready": {}, "damage_tick": -1})
		if not _valid_core_state(core, ship, int(state["tick"])):
			return false
		planned[raw_id] = {
			"hull": restored_hull,
			"sector_id": restored_sector,
			"locked_id": raw_lock,
			"battery": raw_battery.duplicate(true),
			"position": restored_position,
			"core": core.duplicate(true),
		}
	if planned.size() != _roster.size():
		return false
	for id in planned:
		var lock_id: String = planned[id]["locked_id"]
		if lock_id.is_empty():
			continue
		if not planned.has(lock_id):
			return false
		var source: CombatantState = _roster[id]
		var target: CombatantState = _roster[lock_id]
		if source.faction_id == target.faction_id or planned[id]["sector_id"] != planned[lock_id]["sector_id"] or float(planned[lock_id]["hull"]) <= 0.0:
			return false
	_status_actors.clear()
	for id in planned:
		var ship: CombatantState = _roster[id]
		var entry: Dictionary = planned[id]
		ship.hull = entry["hull"]
		ship.sector_id = entry["sector_id"]
		ship.last_position = entry["position"]
		ship.locked_id = entry["locked_id"]
		var core: Dictionary = entry["core"]
		ship.selected_ammo = core["selected_ammo"]
		ship.statuses = core["statuses"]
		for status: Dictionary in ship.statuses.values():
			status["stacks"] = int(status["stacks"])
			status["expires"] = int(status["expires"])
		if not ship.statuses.is_empty():
			_status_actors[id] = true
		ship.ready = core["ready"]
		for key in ship.ready:
			ship.ready[key] = int(ship.ready[key])
		ship.damage_tick = int(core["damage_tick"])
		ship.harpoon_ready_tick = int(core.get("harpoon_ready_tick", 0))
		if ship.sector_id == _sector.sector_id:
			var current_position := _sector.entity_position(id)
			if current_position.is_finite():
				if not _sector.move_entity(id, entry["position"]):
					return false
			elif not _sector.register_entity(id, entry["position"]):
				return false
		if ship.battery != null:
			var battery_state: Dictionary = entry["battery"]
			ship.battery.ready_tick = int(battery_state["ready_tick"])
			ship.battery.last_side = int(battery_state["last_side"])
	_tick = int(state["tick"])
	_sequence = int(state["sequence"])
	return true


# attacker_id and heading come from the authority-owned actor, never from the intent.
# An accepted volley uses exactly two encounter rolls, including misses and guaranteed hits.
func _valid_core_state(value: Variant, ship: CombatantState, tick: int) -> bool:
	if not value is Dictionary or value.size() not in [4, 5]:
		return false
	var harpoon_ready: Variant = value.get("harpoon_ready_tick", 0)
	if not _state_integer(harpoon_ready) or int(harpoon_ready) < 0:
		return false
	var selected: Variant = value.get("selected_ammo")
	if not selected is String or (not ship.ammo_damage.is_empty() and not ship.ammo_damage.has(selected)) or (ship.ammo_damage.is_empty() and not selected.is_empty()):
		return false
	var damage_tick: Variant = value.get("damage_tick")
	if not _state_integer(damage_tick) or int(damage_tick) < -1 or int(damage_tick) > tick:
		return false
	var ready: Variant = value.get("ready")
	var statuses: Variant = value.get("statuses")
	if not ready is Dictionary or ready.size() > 4 or not statuses is Dictionary or statuses.size() > CoreCombatRules.STATUSES.size():
		return false
	for key in ready:
		if key not in [REPAIR, BOARD] and not CoreCombatRules.ACTIONS.has(key):
			return false
		if not _state_integer(ready[key]) or int(ready[key]) < 0:
			return false
	for id in statuses:
		var entry: Variant = statuses[id]
		if not CoreCombatRules.STATUSES.has(id) or not entry is Dictionary or entry.size() != 3:
			return false
		if not entry.get("source") is String or not _roster.has(entry["source"]):
			return false
		if not _state_integer(entry.get("stacks")) or int(entry["stacks"]) < 1 or int(entry["stacks"]) > int(CoreCombatRules.STATUSES[id]["max_stacks"]):
			return false
		if not _state_integer(entry.get("expires")) or int(entry["expires"]) <= tick or int(entry["expires"]) > tick + int(CoreCombatRules.STATUSES[id]["duration"]):
			return false
	return true


func fire(attacker_id: String, heading: float, command: Dictionary) -> Dictionary:
	var target_value: Variant = command.get("target_id")
	var target_id := str(target_value) if target_value is String else ""
	var result := CombatTransaction.dto(attacker_id, target_id)
	if not _enabled:
		return _reject(result, "authority_disabled")
	if not _clock_available(_tick):
		return _reject(result, "clock_exhausted")
	if command.size() != 3 or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY or command.get("type") != FIRE or not target_value is String or not SectorIds.valid(target_id) or not is_finite(heading):
		return _reject(result, "malformed_command")
	var attacker: CombatantState = _roster.get(attacker_id)
	var origin := _sector.entity_position(attacker_id) if _sector != null else Vector2.INF
	if attacker == null or attacker.battery == null or not origin.is_finite() or _streams == null:
		return _reject(result, "invalid_attacker")
	if attacker.sunk():
		return _reject(result, "sunk_attacker")
	var battery := attacker.battery
	var weapon := battery.weapon
	result["weapon_id"] = weapon.stable_id
	var reason := TargetingService.rejection(_sector, attacker_id, attacker.faction_id, target_id, _roster)
	if not reason.is_empty():
		return _reject(result, reason)
	var target: CombatantState = _roster[target_id]
	reason = TargetingService.weapon_rejection(TargetingService.CANNON, target.target_class)
	if not reason.is_empty():
		return _reject(result, reason)
	result["remaining_hull"] = target.hull
	if attacker.locked_id != target_id:
		return _reject(result, "target_not_locked")
	var offset := _sector.entity_position(target_id) - origin
	var distance := offset.length()
	if not is_finite(distance):
		return _reject(result, "out_of_range")
	result["distance"] = distance
	if distance < weapon.min_range_meters or distance > weapon.range_meters:
		return _reject(result, "out_of_range")
	var side := broadside(heading, offset, weapon.broadside_half_arc_degrees)
	result["side"] = side
	if side == 0 or (battery.mounted_side != 0 and battery.mounted_side != side):
		return _reject(result, "invalid_arc")
	if _tick < battery.ready_tick:
		return _reject(result, "reloading")
	var safe_reason := _hostile_damage_rejection(attacker_id, target_id)
	if not safe_reason.is_empty():
		return _reject(result, safe_reason)

	var ammo: AmmoProfile = _ammo_profiles.get(attacker.selected_ammo)
	var normal := attacker.normal_damage
	var element := CoreCombatRules.NEUTRAL
	if not attacker.ammo_damage.is_empty():
		if ammo == null or not attacker.ammo_damage.has(attacker.selected_ammo):
			return _reject(result, "invalid_ammo")
		normal = float(attacker.ammo_damage[attacker.selected_ammo])
		element = ammo.element_id
		if not _pay(attacker_id, ammo.item_id):
			return _reject(result, "insufficient_resource")
		result["ammo_id"] = ammo.stable_id
	var hit := _roll_passes(_streams.next_float(SeedStreams.STREAM_ENCOUNTER), CoreCombatRules.hit_chance(weapon.accuracy, target.dodge))
	var crit_roll := _streams.next_float(SeedStreams.STREAM_ENCOUNTER)
	var crit := hit and _roll_passes(crit_roll, weapon.crit_chance * (1.0 - target.crit_prevention))
	var resistance := float(target.resistances.get(element, 0.0)) if element != CoreCombatRules.NEUTRAL else 0.0
	var defense := target.defense + (5.0 if target.statuses.has("status.braced") else 0.0)
	var damage := CoreCombatRules.damage(normal if hit else 0.0, weapon.crit_multiplier if crit else 1.0, resistance, defense, weapon.defense_penetration, target.hull)
	var raw: float = damage["raw"]
	var prevented: float = damage["prevented"]
	var applied: float = damage["applied"]
	target.hull = maxf(0.0, target.hull - applied)
	battery.ready_tick = _tick + battery.reload_ticks
	battery.last_side = side
	_sequence += 1
	result["accepted"] = true
	result["sequence_id"] = _sequence
	result["hit"] = hit
	result["crit"] = crit
	result["raw_damage"] = raw
	result["prevented_damage"] = prevented
	result["applied_hull_damage"] = applied
	result["remaining_hull"] = target.hull
	result["sunk"] = target.sunk()
	if applied > 0.0:
		target.damage_tick = _tick
		if ammo != null and not ammo.status_id.is_empty() and not target.sunk():
			_apply_status(target_id, target, ammo.status_id, attacker_id)
	if target.sunk():
		for ship: CombatantState in _roster.values():
			if ship.locked_id == target_id:
				ship.locked_id = ""
	var sequence: int = result["sequence_id"]
	if applied > 0.0:
		hull_damaged.emit(target_id, attacker_id, applied, float(result["remaining_hull"]), sequence)
	if result["sunk"]:
		ship_sunk.emit(target_id, sequence)
	return result


func harpoon(attacker_id: String, command: Dictionary) -> Dictionary:
	var target_value: Variant = command.get("target_id")
	var target_id := str(target_value) if target_value is String else ""
	var result := {"accepted": false, "reason": "", "sequence_id": 0, "attacker_id": attacker_id, "target_id": target_id,
		"profile_id": "", "element_id": "", "applied_damage": 0.0, "remaining_hull": 0.0, "destroyed": false}
	if not _enabled:
		return _reject(result, "authority_disabled")
	if not _clock_available(_tick):
		return _reject(result, "clock_exhausted")
	if command.size() != 3 or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY or command.get("type") != HARPOON or not target_value is String or not SectorIds.valid(target_id):
		return _reject(result, "malformed_command")
	var attacker: CombatantState = _roster.get(attacker_id)
	var origin := _sector.entity_position(attacker_id) if _sector != null else Vector2.INF
	if attacker == null or attacker.harpoon == null or not origin.is_finite():
		return _reject(result, "invalid_attacker")
	if attacker.sunk():
		return _reject(result, "sunk_attacker")
	var profile := attacker.harpoon
	result["profile_id"] = profile.stable_id
	result["element_id"] = profile.element_id
	var reason := TargetingService.rejection(_sector, attacker_id, attacker.faction_id, target_id, _roster)
	if not reason.is_empty():
		return _reject(result, reason)
	var target: CombatantState = _roster[target_id]
	reason = TargetingService.weapon_rejection(TargetingService.HARPOON, target.target_class)
	if not reason.is_empty() or not profile.accepts(target.target_class):
		return _reject(result, "wrong_target_class" if reason.is_empty() else reason)
	if attacker.locked_id != target_id:
		return _reject(result, "target_not_locked")
	var target_position := _sector.entity_position(target_id)
	var distance := origin.distance_to(target_position)
	if not is_finite(distance) or distance > profile.range_meters:
		return _reject(result, "out_of_range")
	if _tick < attacker.harpoon_ready_tick:
		return _reject(result, "reloading")
	var safe_reason := _hostile_damage_rejection(attacker_id, target_id)
	if not safe_reason.is_empty():
		return _reject(result, safe_reason)
	if not _can_pay(attacker_id, profile.item_id):
		return _reject(result, "insufficient_resource")
	var resistance := float(target.resistances.get(profile.element_id, 0.0)) if profile.element_id != CoreCombatRules.NEUTRAL else 0.0
	var damage := CoreCombatRules.damage(profile.base_damage, 1.0, resistance, target.defense, 0.0, target.hull)
	var applied: float = damage["applied"]
	if not _pay(attacker_id, profile.item_id):
		return _reject(result, "insufficient_resource")
	target.hull = maxf(0.0, target.hull - applied)
	attacker.harpoon_ready_tick = _tick + maxi(1, ceili(profile.reload_seconds * _tick_rate))
	_sequence += 1
	result["accepted"] = true
	result["sequence_id"] = _sequence
	result["applied_damage"] = applied
	result["remaining_hull"] = target.hull
	result["destroyed"] = target.sunk()
	if applied > 0.0:
		target.damage_tick = _tick
		hull_damaged.emit(target_id, attacker_id, applied, target.hull, _sequence)
	if target.sunk():
		for actor: CombatantState in _roster.values():
			if actor.locked_id == target_id:
				actor.locked_id = ""
		match target.target_class:
			TargetingService.MONSTER:
				monster_defeated.emit(target_id, _sequence)
			TargetingService.WRECK:
				wreck_destroyed.emit(target_id, _sequence)
	return result


static func harpoon_intent(target_id: String) -> Dictionary:
	return {"domain": GameplayCommand.DOMAIN_GAMEPLAY, "type": HARPOON, "target_id": target_id}


static func fire_intent(target_id: String) -> Dictionary:
	return {"domain": GameplayCommand.DOMAIN_GAMEPLAY, "type": FIRE, "target_id": target_id}


static func broadside(heading: float, offset: Vector2, half_arc_degrees: float) -> int:
	if not is_finite(heading) or not offset.is_finite() or offset == Vector2.ZERO or not is_finite(half_arc_degrees) or half_arc_degrees <= 0.0 or half_arc_degrees >= 90.0:
		return 0
	var bearing := offset.angle()
	var difference := ShipMotor.signed_angular_difference(heading, bearing)
	if absf(absf(difference) - PI * 0.5) > deg_to_rad(half_arc_degrees) + 0.000001:
		return 0
	return ShipMotor.side_for_heading(heading, bearing)


static func probability(value: float) -> bool:
	return is_finite(value) and value >= 0.0 and value <= 1.0


static func _roll_passes(roll: float, chance: float) -> bool:
	return chance >= 1.0 or roll < chance


static func _reject(result: Dictionary, reason: String) -> Dictionary:
	result["reason"] = reason
	return result


static func _valid_weapon(weapon: WeaponDefinition) -> bool:
	return (SectorIds.valid(weapon.stable_id) and CoreCombatRules.bounded(weapon.base_damage, 0.0, CoreCombatRules.MAX_VALUE)
		and is_finite(weapon.min_range_meters) and weapon.min_range_meters >= 0.0
		and is_finite(weapon.range_meters) and weapon.range_meters >= weapon.min_range_meters
		and is_finite(weapon.reload_seconds) and weapon.reload_seconds > 0.0 and weapon.reload_seconds <= MAX_RELOAD_SECONDS
		and CoreCombatRules.bounded(weapon.accuracy, 0.0, 4.0) and probability(weapon.crit_chance)
		and CoreCombatRules.bounded(weapon.crit_multiplier, 1.0, 8.0)
		and is_finite(weapon.broadside_half_arc_degrees) and weapon.broadside_half_arc_degrees > 0.0 and weapon.broadside_half_arc_degrees < 90.0
		and is_finite(weapon.defense_penetration) and weapon.defense_penetration >= 0.0)


static func _valid_modifiers(modifiers: Dictionary) -> bool:
	if modifiers.size() > 32:
		return false
	for id in modifiers:
		if not id is String or not SectorIds.valid(id):
			return false
		var entry: Variant = modifiers[id]
		if not entry is Dictionary or not StatModifierPipeline.PHASE_ORDER.has(entry.get("operation")):
			return false
		var amount: Variant = entry.get("value")
		if (not amount is float and not amount is int) or not CoreCombatRules.bounded(float(amount), -1000000.0, 1000000.0) or not entry.get("priority", 0) is int:
			return false
	return true


static func _state_integer(value_in: Variant) -> bool:
	if typeof(value_in) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value_in)
	return is_finite(number) and number == floorf(number) and absf(number) <= 2147483647.0
