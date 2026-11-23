class_name InventoryState
extends RefCounted

const PRG02 := preload("res://src/simulation/progression/prg02_progression_state.gd")
const PRG03 := preload("res://src/simulation/progression/prg03_progression_state.gd")
const PRG04 := preload("res://src/simulation/progression/prg04_quest_state.gd")
const PRG05 := preload("res://src/simulation/progression/prg05_economy_state.gd")

const VERSION := 5
const MAX_QUANTITY := 2147483647
const MAX_ITEMS := 128
const MAX_EQUIPMENT_SLOTS := 16
const MAX_SOCKETS := 16
const MAX_PRESETS := 16
const MAX_TRANSACTIONS := 128
const SLOT_TYPES := ["weapon", "structure", "sail", "figurehead", "crew", "trainer", "pet"]
const GEM_CATEGORIES := ["ship_gem", "pet_gem"]
const OP_TRANSFER := "inventory_transfer"
const OP_EQUIP := "inventory_equip"
const OP_UNEQUIP := "inventory_unequip"
const OP_SOCKET_INSERT := "inventory_socket_insert"
const OP_SOCKET_UPGRADE := "inventory_socket_upgrade"
const OP_PRESET_APPLY := "inventory_preset_apply"
const OP_CRAFT := PRG02.OP_CRAFT
const OP_SALVAGE := PRG02.OP_SALVAGE
const OP_UPGRADE := PRG02.OP_UPGRADE
const OP_CORE_INSERT := PRG02.OP_CORE_INSERT
const OP_CORE_REMOVE := PRG02.OP_CORE_REMOVE
const OP_CORE_REPLACE := PRG02.OP_CORE_REPLACE
const OP_TROPHY_UNLOCK := PRG02.OP_TROPHY_UNLOCK
const OP_SKILL_SPEND := PRG03.OP_SKILL_SPEND
const OP_RESPEC := PRG03.OP_RESPEC
const OP_GATE_COMPLETE := PRG03.OP_GATE_COMPLETE
const OP_CHALLENGE_EVENT := PRG03.OP_CHALLENGE_EVENT
const OP_QUEST_ACCEPT := PRG04.OP_ACCEPT
const OP_QUEST_TURN_IN := PRG04.OP_TURN_IN
const OP_MARKET_BUY := PRG05.OP_BUY
const OP_MARKET_SELL := PRG05.OP_SELL

var _catalog: Dictionary = {}
var _containers: Dictionary = {}
var _equipment: Dictionary = {}
var _sockets: Dictionary = {}
var _presets: Dictionary = {}
var _transactions: Dictionary = {}
var _combat_locked: Dictionary = {}
var _safe_state: Dictionary = {}
var _prg02
var _pending_prg02_state: Dictionary = {}
var _prg03
var _pending_prg03_state: Dictionary = {}
var _prg04
var _pending_prg04_state: Dictionary = {}
var _prg05
var _pending_prg05_state: Dictionary = {}

func bind_owner(owner_id: String, max_slots: int = 64, max_weight: float = 1000000.0) -> bool:
	if not SectorIds.valid(owner_id) or max_slots <= 0 or max_slots > MAX_ITEMS or not is_finite(max_weight) or max_weight < 0.0 or _containers.has(owner_id):
		return false
	_containers[owner_id] = {"max_slots": max_slots, "max_weight": max_weight, "items": {}}
	_equipment[owner_id] = {}
	_sockets[owner_id] = {}
	_presets[owner_id] = {}
	if _prg02 != null and not _prg02.bind_owner(owner_id):
		return false
	if _prg03 != null and not _prg03.bind_owner(owner_id):
		return false
	if _prg04 != null and not _prg04.bind_owner(owner_id):
		return false
	if _prg05 != null and not _prg05.bind_owner(owner_id):
		return false
	return true

func reassign_owner(from_id: String, to_id: String) -> bool:
	if not _containers.has(from_id) or _containers.has(to_id) or not SectorIds.valid(to_id):
		return false
	_containers[to_id] = _containers[from_id]
	_containers.erase(from_id)
	_equipment[to_id] = _equipment.get(from_id, {})
	_equipment.erase(from_id)
	_sockets[to_id] = _sockets.get(from_id, {})
	_sockets.erase(from_id)
	_presets[to_id] = _presets.get(from_id, {})
	_presets.erase(from_id)
	if _prg02 != null and not _prg02.reassign_owner(from_id, to_id):
		return false
	if _prg03 != null and not _prg03.reassign_owner(from_id, to_id):
		return false
	if _prg04 != null and not _prg04.reassign_owner(from_id, to_id):
		return false
	if _prg05 != null and not _prg05.reassign_owner(from_id, to_id):
		return false
	return true

func register_item_definition(definition: ItemDefinition) -> bool:
	if definition == null or not definition.valid():
		return false
	return register_item_spec(definition.stable_id, definition.item_category, definition.stack_limit, definition.equip_slot, definition.weight, definition.stat_modifiers, definition.core_type, definition.core_unique)

func register_item_spec(item_id: String, category: String, stack_limit: int, equip_slot: String = "", weight: float = 0.0, modifiers: Array[Dictionary] = [], core_type: String = "", core_unique: bool = false) -> bool:
	if not SectorIds.valid(item_id) or category.is_empty() or stack_limit <= 0 or stack_limit > MAX_QUANTITY or not is_finite(weight) or weight < 0.0:
		return false
	if not equip_slot.is_empty() and equip_slot not in SLOT_TYPES:
		return false
	if category == "core":
		if not equip_slot.is_empty() or core_type.is_empty() or core_type.length() > 64 or not SectorIds.valid("core_type." + core_type):
			return false
	elif not core_type.is_empty() or core_unique:
		return false
	if _catalog.has(item_id):
		return false
	for modifier in modifiers:
		if not _valid_modifier(modifier):
			return false
	_catalog[item_id] = {"category": category, "stack_limit": stack_limit, "equip_slot": equip_slot, "weight": weight, "modifiers": modifiers.duplicate(true), "core_type": core_type, "core_unique": core_unique}
	return true

func has_item_spec(item_id: String) -> bool:
	return _catalog.has(item_id)

func has_owner(owner_id: String) -> bool:
	return _containers.has(owner_id)

func item_spec(item_id: String) -> Dictionary:
	return (_catalog.get(item_id, {}) as Dictionary).duplicate(true)

func can_apply_item_deltas(owner_id: String, deltas: Dictionary) -> bool:
	if not _containers.has(owner_id) or deltas.size() > MAX_ITEMS:
		return false
	var clone := _containers.duplicate(true)
	return _apply_deltas_to(clone, owner_id, deltas)

func apply_item_deltas_atomic(owner_id: String, deltas: Dictionary) -> bool:
	if not _containers.has(owner_id) or deltas.size() > MAX_ITEMS:
		return false
	var clone := _containers.duplicate(true)
	if not _apply_deltas_to(clone, owner_id, deltas):
		return false
	_containers = clone
	return true

func item_equipped(owner_id: String, item_id: String) -> bool:
	var slots: Dictionary = _equipment.get(owner_id, {})
	return slots.values().has(item_id)

func configure_prg02(streams: SeedStreams) -> bool:
	if streams == null or _prg02 != null:
		return false
	_prg02 = PRG02.new(self, streams)
	for owner_id in _containers:
		if not _prg02.bind_owner(str(owner_id)):
			_prg02 = null
			return false
	if not _pending_prg02_state.is_empty():
		if not _prg02.restore_state(_pending_prg02_state):
			_prg02 = null
			return false
		_pending_prg02_state.clear()
	return true

func register_recipe_definition(definition: RecipeDefinition) -> bool:
	return _prg02 != null and _prg02.register_recipe(definition)

func register_salvage_definition(definition: SalvageTable) -> bool:
	return _prg02 != null and _prg02.register_salvage_table(definition)

func register_upgrade_definition(definition: ShipUpgradeDefinition) -> bool:
	return _prg02 != null and _prg02.register_upgrade(definition)

func register_trophy_definition(definition: TrophyDefinition) -> bool:
	return _prg02 != null and _prg02.register_trophy(definition)

func validate_prg02_catalog() -> String:
	return _prg02.validate_catalog() if _prg02 != null else "progression_unavailable"

func configure_prg02_core_slot(owner_id: String, slot_id: String, slot_type: String, allowed_core_type: String) -> bool:
	return _prg02 != null and _prg02.configure_core_slot(owner_id, slot_id, slot_type, allowed_core_type)

func prg02_state_snapshot() -> Dictionary:
	return _prg02.snapshot_state() if _prg02 != null else PRG02.empty_state()

func configure_prg03() -> bool:
	if _prg03 != null:
		return false
	_prg03 = PRG03.new(self)
	for owner_id in _containers:
		if not _prg03.bind_owner(str(owner_id)):
			_prg03 = null
			return false
	if not _pending_prg03_state.is_empty():
		if not _prg03.restore_state(_pending_prg03_state):
			_prg03 = null
			return false
		_pending_prg03_state.clear()
	return true

func register_rank_definition(definition: ProgressionRankDefinition) -> bool:
	return _prg03 != null and _prg03.register_rank(definition)

func register_skill_definition(definition: ProgressionSkillDefinition) -> bool:
	return _prg03 != null and _prg03.register_skill(definition)

func register_gate_definition(definition: ProgressionGateDefinition) -> bool:
	return _prg03 != null and _prg03.register_gate(definition)

func register_challenge_definition(definition: LocalChallengeDefinition) -> bool:
	return _prg03 != null and _prg03.register_challenge(definition)

func validate_prg03_catalog() -> String:
	return _prg03.validate_catalog() if _prg03 != null else "progression_unavailable"

func grant_xp_authoritative(owner_id: String, event_id: String, source: String, amount: int) -> Dictionary:
	return _prg03.grant_xp_authoritative(owner_id, event_id, source, amount) if _prg03 != null else {"accepted": false, "reason": "progression_unavailable", "duplicate": false, "total_xp": 0}

func prg03_state_snapshot() -> Dictionary:
	return _prg03.snapshot_state() if _prg03 != null else PRG03.empty_state()

func restore_prg03_state(value: Variant) -> bool:
	return _prg03 != null and _prg03.restore_state(value)

func has_progression_rank(rank_id: String) -> bool:
	return _prg03 != null and _prg03.has_rank_definition(rank_id)

func has_progression_gate(gate_id: String) -> bool:
	return _prg03 != null and _prg03.has_gate_definition(gate_id)

func progression_gate_completed(owner_id: String, gate_id: String) -> bool:
	return _prg03 != null and _prg03.gate_completed(owner_id, gate_id)

func progression_rank_satisfies(owner_id: String, rank_id: String) -> bool:
	return _prg03 != null and _prg03.rank_satisfies(owner_id, rank_id)

func complete_progression_gate_authoritative(owner_id: String, gate_id: String) -> Dictionary:
	return _prg03.complete_gate_authoritative(owner_id, gate_id) if _prg03 != null else {"accepted": false, "reason": "progression_unavailable", "operation": OP_GATE_COMPLETE}

func configure_prg04() -> bool:
	if _prg04 != null:
		return false
	_prg04 = PRG04.new(self)
	for owner_id in _containers:
		if not _prg04.bind_owner(str(owner_id)):
			_prg04 = null
			return false
	if not _pending_prg04_state.is_empty():
		if not _prg04.restore_state(_pending_prg04_state):
			_prg04 = null
			return false
		_pending_prg04_state.clear()
	return true

func register_quest_definition(definition: QuestDefinition) -> bool:
	return _prg04 != null and _prg04.register_quest(definition)

func register_quest_npc_ref(npc_id: String) -> bool:
	return _prg04 != null and _prg04.register_npc_ref(npc_id)

func register_quest_region_ref(region_id: String) -> bool:
	return _prg04 != null and _prg04.register_region_ref(region_id)

func register_quest_sector_ref(sector_id: String) -> bool:
	return _prg04 != null and _prg04.register_sector_ref(sector_id)

func validate_prg04_catalog() -> String:
	return _prg04.validate_catalog() if _prg04 != null else "quest_unavailable"

func set_quest_authoritative_context(owner_id: String, sector_id: String, region_id: String, nearby_npc_ids: PackedStringArray, tick: int) -> bool:
	return _prg04 != null and _prg04.set_authoritative_context(owner_id, sector_id, region_id, nearby_npc_ids, tick)

func set_quest_eligible_party_members(owner_id: String, members: PackedStringArray) -> bool:
	return _prg04 != null and _prg04.set_eligible_party_members(owner_id, members)

func apply_quest_objective_event_authoritative(owner_id: String, event: Dictionary) -> Dictionary:
	return _prg04.apply_objective_event_authoritative(owner_id, event) if _prg04 != null else {"accepted": false, "reason": "quest_unavailable"}

func advance_quest_tick_authoritative(owner_id: String, tick: int) -> Dictionary:
	return _prg04.advance_tick_authoritative(owner_id, tick) if _prg04 != null else {"accepted": false, "reason": "quest_unavailable", "failed_quests": []}

func quest_status(owner_id: String, quest_id: String) -> String:
	return _prg04.quest_status(owner_id, quest_id) if _prg04 != null else "locked"

func quest_journal_snapshot(owner_id: String) -> Dictionary:
	return _prg04.journal_snapshot(owner_id) if _prg04 != null else PRG04.empty_journal(owner_id)

func prg04_state_snapshot() -> Dictionary:
	return _prg04.snapshot_state() if _prg04 != null else PRG04.empty_state()

static func empty_quest_journal_snapshot(owner_id: String) -> Dictionary:
	return PRG04.empty_journal(owner_id)

static func validate_quest_journal_snapshot(value: Variant) -> bool:
	return PRG04.validate_journal(value)

func configure_prg05() -> bool:
	if _prg05 != null:
		return false
	_prg05 = PRG05.new(self)
	for owner_id in _containers:
		if not _prg05.bind_owner(str(owner_id)):
			_prg05 = null
			return false
	if not _pending_prg05_state.is_empty():
		if not _prg05.restore_state(_pending_prg05_state):
			_prg05 = null
			return false
		_pending_prg05_state.clear()
	return true

func enable_economy_diplomacy(owner_id: String) -> bool:
	return _prg05 != null and _prg05.enable_player_diplomacy(owner_id)

func economy_actor_disposition(owner_id: String, faction_id: String) -> String:
	return _prg05.actor_disposition(owner_id, faction_id) if _prg05 != null else FactionRelationResolver.NEUTRAL

func register_economy_faction(id: String) -> bool:
	return _prg05 != null and _prg05.register_faction(id)

func register_economy_market(id: String, faction: String, item: String, sector: String, price: int, stock: int, capacity: int) -> bool:
	return _prg05 != null and _prg05.register_market(id, faction, item, sector, price, stock, capacity)

func register_economy_outpost(id: String, faction: String) -> bool:
	return _prg05 != null and _prg05.register_outpost(id, faction)

func set_economy_faction_relation(a: String, b: String, relation: String) -> bool:
	return _prg05 != null and _prg05.set_relation_authoritative(a, b, relation)

func economy_faction_relation(a: String, b: String) -> String:
	return _prg05.faction_relation(a, b) if _prg05 != null else FactionRelationResolver.NEUTRAL

func adjust_economy_reputation_authoritative(owner: String, faction: String, event: String, amount: int) -> Dictionary:
	return _prg05.adjust_reputation_authoritative(owner, faction, event, amount) if _prg05 != null else {"accepted": false}

func grant_economy_currency_authoritative(owner: String, event: String, amount: int) -> Dictionary:
	return _prg05.grant_currency_authoritative(owner, event, amount) if _prg05 != null else {"accepted": false}

func record_economy_convoy_loss_authoritative(event: String, market: String, amount: int) -> Dictionary:
	return _prg05.convoy_loss_authoritative(event, market, amount) if _prg05 != null else {"accepted": false}

func capture_economy_outpost_authoritative(event: String, outpost: String, faction: String) -> Dictionary:
	return _prg05.capture_outpost_authoritative(event, outpost, faction) if _prg05 != null else {"accepted": false}

func record_economy_pvp_kill_authoritative(event: String, killer: String, victim: String, reward: int) -> Dictionary:
	return _prg05.pvp_kill_authoritative(event, killer, victim, reward) if _prg05 != null else {"accepted": false}

func economy_quote(owner: String, market: String) -> Dictionary:
	return _prg05.quote(owner, market) if _prg05 != null else {}

func economy_balance(owner: String) -> int:
	return _prg05.balance(owner) if _prg05 != null else 0

func economy_outpost_owner(outpost: String) -> String:
	return _prg05.outpost_owner(outpost) if _prg05 != null else ""

func progression_view(owner_id: String) -> Dictionary:
	if _prg03 == null:
		return {}
	return {
		"total_xp": _prg03.total_xp(owner_id),
		"rank_id": _prg03.current_rank_id(owner_id),
		"available_skill_points": _prg03.available_skill_points(owner_id),
		"challenges": _prg03.challenge_snapshot(owner_id),
	}

func quantity(owner_id: String, item_id: String) -> int:
	var container: Dictionary = _containers.get(owner_id, {})
	if container.is_empty():
		return 0
	return int((container["items"] as Dictionary).get(item_id, 0))

func quantities_snapshot(owner_id: String) -> Dictionary:
	var container: Dictionary = _containers.get(owner_id, {})
	return (container.get("items", {}) as Dictionary).duplicate(true) if not container.is_empty() else {}

func restore_quantities(owner_id: String, quantities: Dictionary) -> bool:
	if not _containers.has(owner_id) or quantities.size() > MAX_ITEMS:
		return false
	var next: Dictionary = {}
	for item_id in quantities:
		if not item_id is String or not _catalog.has(item_id) or not _integer(quantities[item_id]):
			return false
		var value := int(quantities[item_id])
		if value < 0 or value > int((_catalog[item_id] as Dictionary)["stack_limit"]):
			return false
		if value > 0:
			next[item_id] = value
	var probe: Dictionary = (_containers[owner_id] as Dictionary).duplicate(true)
	probe["items"] = next
	if not _container_within_limits(probe):
		return false
	_containers[owner_id] = probe
	return true

func can_add(owner_id: String, item_id: String, amount: int) -> bool:
	if not _containers.has(owner_id) or not _catalog.has(item_id) or amount <= 0:
		return false
	var clone := _containers.duplicate(true)
	return _add_to(clone, owner_id, item_id, amount)

func grant_authoritative(owner_id: String, item_id: String, amount: int) -> bool:
	var clone := _containers.duplicate(true)
	if not _add_to(clone, owner_id, item_id, amount):
		return false
	_containers = clone
	return true

func consume_authoritative(owner_id: String, item_id: String, amount: int) -> bool:
	var clone := _containers.duplicate(true)
	if not _remove_from(clone, owner_id, item_id, amount):
		return false
	_containers = clone
	return true

func configure_socket(owner_id: String, socket_id: String, socket_kind: String, max_level: int = 5) -> bool:
	if not _sockets.has(owner_id) or not SectorIds.valid(socket_id) or socket_kind not in GEM_CATEGORIES or max_level <= 0 or max_level > 32:
		return false
	var owner_sockets: Dictionary = _sockets[owner_id]
	if owner_sockets.has(socket_id) or owner_sockets.size() >= MAX_SOCKETS:
		return false
	owner_sockets[socket_id] = {"kind": socket_kind, "gem_id": "", "level": 0, "max_level": max_level}
	return true

func save_preset(owner_id: String, preset_id: String, slots: Dictionary) -> bool:
	if not _presets.has(owner_id) or not SectorIds.valid(preset_id) or slots.size() > MAX_EQUIPMENT_SLOTS:
		return false
	var normalized: Dictionary = {}
	for slot in slots:
		if not slot is String or slot not in SLOT_TYPES:
			return false
		var item_id := str(slots[slot])
		if not item_id.is_empty() and (not _catalog.has(item_id) or not _compatible_slot(item_id, str(slot))):
			return false
		normalized[slot] = item_id
	var owner_presets: Dictionary = _presets[owner_id]
	if not owner_presets.has(preset_id) and owner_presets.size() >= MAX_PRESETS:
		return false
	owner_presets[preset_id] = normalized
	return true

func set_preset_context(owner_id: String, in_combat: bool, safe_state: bool) -> bool:
	if not _containers.has(owner_id):
		return false
	_combat_locked[owner_id] = in_combat
	_safe_state[owner_id] = safe_state
	return true

func execute_transaction(actor_id: String, transaction_id: String, operation: String, payload: Dictionary) -> Dictionary:
	var base := {"accepted": false, "reason": "", "operation": operation}
	if not SectorIds.valid(actor_id) or not _valid_transaction_id(transaction_id) or not DtoContract.is_primitive_safe(payload):
		base["reason"] = "invalid_transaction"
		return base
	var fingerprint := (operation + "|" + JSON.stringify(_canonical(payload))).sha256_text()
	var key := actor_id + "|" + transaction_id
	if _transactions.has(key):
		var row: Dictionary = _transactions[key]
		if row["operation"] != operation or row["fingerprint"] != fingerprint:
			base["reason"] = "transaction_conflict"
			return base
		return (row["result"] as Dictionary).duplicate(true)
	if _transactions.size() >= MAX_TRANSACTIONS:
		base["reason"] = "transaction_ledger_full"
		return base
	var result := _execute_uncached(actor_id, operation, payload)
	_transactions[key] = {"actor_id": actor_id, "transaction_id": transaction_id, "operation": operation, "fingerprint": fingerprint, "result": result.duplicate(true)}
	return result

func equipment_snapshot(owner_id: String) -> Dictionary:
	return (_equipment.get(owner_id, {}) as Dictionary).duplicate(true)

func socket_snapshot(owner_id: String) -> Dictionary:
	return (_sockets.get(owner_id, {}) as Dictionary).duplicate(true)

func progression_snapshot() -> Dictionary:
	return {
		"version": VERSION,
		"equipment": _equipment.duplicate(true),
		"sockets": _sockets.duplicate(true),
		"presets": _presets.duplicate(true),
		"transactions": _transactions.duplicate(true),
		"prg02": _prg02.snapshot_state() if _prg02 != null else PRG02.empty_state(),
		"prg03": _prg03.snapshot_state() if _prg03 != null else PRG03.empty_state(),
		"prg04": _prg04.snapshot_state() if _prg04 != null else PRG04.empty_state(),
		"prg05": _prg05.snapshot_state() if _prg05 != null else PRG05.empty_state(),
	}

func restore_progression(value: Variant) -> bool:
	if not validate_progression_state(value, _catalog):
		return false
	var source: Dictionary = value
	var state := source.duplicate(true)
	var source_version := int(state.get("version", 0))
	if source_version == 1:
		state["prg02"] = PRG02.empty_state()
		state["prg03"] = PRG03.empty_state()
		state["prg04"] = PRG04.empty_state()
		state["version"] = VERSION
	elif source_version == 2:
		state["prg03"] = PRG03.empty_state()
		state["prg04"] = PRG04.empty_state()
		state["version"] = VERSION
	elif source_version == 3:
		state["prg04"] = PRG04.empty_state()
		state["version"] = VERSION
	if source_version <= 4:
		state["prg05"] = PRG05.empty_state()
		state["version"] = VERSION
	var prg02_state: Dictionary = state["prg02"]
	if _prg02 != null:
		if not _prg02.restore_state(prg02_state):
			return false
	else:
		_pending_prg02_state = prg02_state.duplicate(true)
	var prg03_state: Dictionary = state["prg03"]
	if _prg03 != null:
		if not _prg03.restore_state(prg03_state):
			return false
	else:
		_pending_prg03_state = prg03_state.duplicate(true)
	var prg04_state: Dictionary = state["prg04"]
	if _prg04 != null:
		if not _prg04.restore_state(prg04_state):
			return false
	else:
		_pending_prg04_state = prg04_state.duplicate(true)
	var prg05_state: Dictionary = state["prg05"]
	if _prg05 != null:
		if not _prg05.restore_state(prg05_state):
			return false
	else:
		_pending_prg05_state = prg05_state.duplicate(true)
	for owner_id in state["equipment"]:
		if not _containers.has(owner_id):
			return false
	_equipment = (state["equipment"] as Dictionary).duplicate(true)
	_sockets = (state["sockets"] as Dictionary).duplicate(true)
	_presets = (state["presets"] as Dictionary).duplicate(true)
	_transactions = (state["transactions"] as Dictionary).duplicate(true)
	return true

static func validate_progression_state(value: Variant, catalog: Dictionary = {}) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var state: Dictionary = value
	var version := int(state.get("version", 0))
	if version == 1:
		if state.size() != 5:
			return false
	elif version == 2:
		if state.size() != 6 or not PRG02.validate_state(state.get("prg02")):
			return false
	elif version == 3:
		if state.size() != 7 or not PRG02.validate_state(state.get("prg02")) or not PRG03.validate_state(state.get("prg03")):
			return false
	elif version == 4:
		if state.size() != 8 or not PRG02.validate_state(state.get("prg02")) or not PRG03.validate_state(state.get("prg03")) or not PRG04.validate_state(state.get("prg04")):
			return false
	elif version == VERSION:
		if state.size() != 9 or not PRG02.validate_state(state.get("prg02")) or not PRG03.validate_state(state.get("prg03")) or not PRG04.validate_state(state.get("prg04")) or not PRG05.validate_state(state.get("prg05")):
			return false
	else:
		return false
	for key in ["equipment", "sockets", "presets", "transactions"]:
		if not state.get(key) is Dictionary:
			return false
	if state["transactions"].size() > MAX_TRANSACTIONS:
		return false
	for owner_id in state["equipment"]:
		if not owner_id is String or not SectorIds.valid(owner_id):
			return false
		var slots: Variant = state["equipment"][owner_id]
		if not slots is Dictionary or slots.size() > MAX_EQUIPMENT_SLOTS:
			return false
		for slot in slots:
			if slot not in SLOT_TYPES or not slots[slot] is String or (not catalog.is_empty() and not catalog.has(slots[slot])):
				return false
	for owner_id in state["sockets"]:
		if not owner_id is String or not SectorIds.valid(owner_id) or not state["sockets"][owner_id] is Dictionary or state["sockets"][owner_id].size() > MAX_SOCKETS:
			return false
	for owner_id in state["presets"]:
		if not owner_id is String or not SectorIds.valid(owner_id) or not state["presets"][owner_id] is Dictionary or state["presets"][owner_id].size() > MAX_PRESETS:
			return false
	return true

func stat_value(owner_id: String, stat_id: String, base_value: float) -> float:
	var by_id: Dictionary = {}
	var slots: Dictionary = _equipment.get(owner_id, {})
	for slot in slots:
		_append_modifiers(by_id, str(slots[slot]), stat_id, "equip." + str(slot))
	var socket_rows: Dictionary = _sockets.get(owner_id, {})
	for socket_id in socket_rows:
		var row: Dictionary = socket_rows[socket_id]
		var gem_id := str(row.get("gem_id", ""))
		if not gem_id.is_empty():
			_append_modifiers(by_id, gem_id, stat_id, "socket." + str(socket_id))
	if _prg02 != null:
		_prg02.append_stat_modifiers(owner_id, stat_id, by_id)
	if _prg03 != null:
		_prg03.append_stat_modifiers(owner_id, stat_id, by_id)
	return StatModifierPipeline.apply_from_dictionary(base_value, by_id)

func _execute_uncached(actor_id: String, operation: String, payload: Dictionary) -> Dictionary:
	var result := {"accepted": false, "reason": "", "operation": operation}
	if PRG05.supports_operation(operation):
		if _prg05 == null:
			result["reason"] = "economy_unavailable"
			return result
		return _prg05.execute(actor_id, operation, payload)
	if PRG04.supports_operation(operation):
		if _prg04 == null:
			result["reason"] = "quest_unavailable"
			return result
		return _prg04.execute(actor_id, operation, payload)
	if PRG03.supports_operation(operation):
		if _prg03 == null:
			result["reason"] = "progression_unavailable"
			return result
		return _prg03.execute(actor_id, operation, payload)
	if PRG02.supports_operation(operation):
		if _prg02 == null:
			result["reason"] = "progression_unavailable"
			return result
		return _prg02.execute(actor_id, operation, payload)
	match operation:
		OP_TRANSFER:
			if not _exact(payload, ["source_container", "target_container", "item_id", "quantity"]):
				result["reason"] = "malformed_payload"
				return result
			var source := str(payload["source_container"])
			var target := str(payload["target_container"])
			var item_id := str(payload["item_id"])
			var amount := int(payload["quantity"]) if _integer(payload["quantity"]) else 0
			if actor_id != source:
				result["reason"] = "authority_mismatch"
				return result
			var clone := _containers.duplicate(true)
			if not _remove_from(clone, source, item_id, amount) or not _add_to(clone, target, item_id, amount):
				result["reason"] = "transfer_rejected"
				return result
			_containers = clone
		OP_EQUIP:
			if not _exact(payload, ["slot", "item_id"]):
				result["reason"] = "malformed_payload"
				return result
			if not _equip_atomic(actor_id, str(payload["slot"]), str(payload["item_id"])):
				result["reason"] = "equip_rejected"
				return result
		OP_UNEQUIP:
			if not _exact(payload, ["slot"]):
				result["reason"] = "malformed_payload"
				return result
			if not _unequip_atomic(actor_id, str(payload["slot"])):
				result["reason"] = "unequip_rejected"
				return result
		OP_SOCKET_INSERT:
			if not _exact(payload, ["socket_id", "item_id"]) or not _socket_insert_atomic(actor_id, str(payload["socket_id"]), str(payload["item_id"])):
				result["reason"] = "socket_rejected"
				return result
		OP_SOCKET_UPGRADE:
			if not _exact(payload, ["socket_id", "cost_item_id", "cost_quantity"]) or not _socket_upgrade_atomic(actor_id, str(payload["socket_id"]), str(payload["cost_item_id"]), int(payload["cost_quantity"]) if _integer(payload["cost_quantity"]) else 0):
				result["reason"] = "upgrade_rejected"
				return result
		OP_PRESET_APPLY:
			if not _exact(payload, ["preset_id"]):
				result["reason"] = "malformed_payload"
				return result
			if bool(_combat_locked.get(actor_id, false)) or not bool(_safe_state.get(actor_id, false)):
				result["reason"] = "preset_restricted"
				return result
			if not _preset_apply_atomic(actor_id, str(payload["preset_id"])):
				result["reason"] = "preset_rejected"
				return result
		_:
			result["reason"] = "unsupported_operation"
			return result
	result["accepted"] = true
	result["reason"] = ""
	return result

func _equip_atomic(owner_id: String, slot: String, item_id: String) -> bool:
	if not _containers.has(owner_id) or slot not in SLOT_TYPES or not _catalog.has(item_id) or not _compatible_slot(item_id, slot) or quantity(owner_id, item_id) <= 0:
		return false
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment.get(owner_id, {})
	var previous := str(slots.get(slot, ""))
	if not previous.is_empty() and not _add_to(containers, owner_id, previous, 1):
		return false
	if not _remove_from(containers, owner_id, item_id, 1):
		return false
	slots[slot] = item_id
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _unequip_atomic(owner_id: String, slot: String) -> bool:
	if not _equipment.has(owner_id) or slot not in SLOT_TYPES:
		return false
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment[owner_id]
	var previous := str(slots.get(slot, ""))
	if previous.is_empty() or not _add_to(containers, owner_id, previous, 1):
		return false
	slots.erase(slot)
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _socket_insert_atomic(owner_id: String, socket_id: String, item_id: String) -> bool:
	if not _sockets.has(owner_id) or not _catalog.has(item_id):
		return false
	var sockets := _sockets.duplicate(true)
	var rows: Dictionary = sockets[owner_id]
	if not rows.has(socket_id):
		return false
	var row: Dictionary = rows[socket_id]
	if not str(row.get("gem_id", "")).is_empty() or str((_catalog[item_id] as Dictionary)["category"]) != str(row["kind"]):
		return false
	var containers := _containers.duplicate(true)
	if not _remove_from(containers, owner_id, item_id, 1):
		return false
	row["gem_id"] = item_id
	row["level"] = 1
	rows[socket_id] = row
	sockets[owner_id] = rows
	_containers = containers
	_sockets = sockets
	return true

func _socket_upgrade_atomic(owner_id: String, socket_id: String, cost_item_id: String, cost_quantity: int) -> bool:
	if cost_quantity <= 0 or not _sockets.has(owner_id):
		return false
	var sockets := _sockets.duplicate(true)
	var rows: Dictionary = sockets[owner_id]
	if not rows.has(socket_id):
		return false
	var row: Dictionary = rows[socket_id]
	if str(row.get("gem_id", "")).is_empty() or int(row["level"]) >= int(row["max_level"]):
		return false
	var containers := _containers.duplicate(true)
	if not _remove_from(containers, owner_id, cost_item_id, cost_quantity):
		return false
	row["level"] = int(row["level"]) + 1
	rows[socket_id] = row
	sockets[owner_id] = rows
	_containers = containers
	_sockets = sockets
	return true

func _preset_apply_atomic(owner_id: String, preset_id: String) -> bool:
	var owner_presets: Dictionary = _presets.get(owner_id, {})
	if not owner_presets.has(preset_id):
		return false
	var target: Dictionary = owner_presets[preset_id]
	var containers := _containers.duplicate(true)
	var equipment := _equipment.duplicate(true)
	var slots: Dictionary = equipment.get(owner_id, {})
	for slot in target:
		var current := str(slots.get(slot, ""))
		var desired := str(target[slot])
		if current == desired:
			continue
		if not current.is_empty() and not _add_to(containers, owner_id, current, 1):
			return false
		if desired.is_empty():
			slots.erase(slot)
		else:
			if not _compatible_slot(desired, str(slot)) or not _remove_from(containers, owner_id, desired, 1):
				return false
			slots[slot] = desired
	equipment[owner_id] = slots
	_containers = containers
	_equipment = equipment
	return true

func _compatible_slot(item_id: String, slot: String) -> bool:
	if not _catalog.has(item_id):
		return false
	var spec: Dictionary = _catalog[item_id]
	var category := str(spec["category"])
	var required := str(spec["equip_slot"])
	if category == "companion":
		category = "pet"
	return required == slot or (required.is_empty() and category == slot)

func _add_to(containers: Dictionary, owner_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or not containers.has(owner_id) or not _catalog.has(item_id):
		return false
	var container: Dictionary = containers[owner_id]
	var items: Dictionary = container["items"]
	var current := int(items.get(item_id, 0))
	var limit := int((_catalog[item_id] as Dictionary)["stack_limit"])
	if current > limit - amount:
		return false
	items[item_id] = current + amount
	container["items"] = items
	if not _container_within_limits(container):
		return false
	containers[owner_id] = container
	return true

func _remove_from(containers: Dictionary, owner_id: String, item_id: String, amount: int) -> bool:
	if amount <= 0 or not containers.has(owner_id):
		return false
	var container: Dictionary = containers[owner_id]
	var items: Dictionary = container["items"]
	var current := int(items.get(item_id, 0))
	if current < amount:
		return false
	var next := current - amount
	if next == 0:
		items.erase(item_id)
	else:
		items[item_id] = next
	container["items"] = items
	containers[owner_id] = container
	return true

func _apply_deltas_to(containers: Dictionary, owner_id: String, deltas: Dictionary) -> bool:
	if not containers.has(owner_id):
		return false
	var keys: Array = deltas.keys()
	keys.sort()
	for item_id in keys:
		if not item_id is String or not _catalog.has(item_id) or not _integer(deltas[item_id]):
			return false
		var amount := int(deltas[item_id])
		if amount < 0 and not _remove_from(containers, owner_id, item_id, -amount):
			return false
	for item_id in keys:
		var amount := int(deltas[item_id])
		if amount > 0 and not _add_to(containers, owner_id, item_id, amount):
			return false
	return true

func _container_within_limits(container: Dictionary) -> bool:
	var items: Dictionary = container["items"]
	if items.size() > int(container["max_slots"]):
		return false
	var weight := 0.0
	for item_id in items:
		if not _catalog.has(item_id):
			return false
		weight += float((_catalog[item_id] as Dictionary)["weight"]) * int(items[item_id])
	return weight <= float(container["max_weight"]) + 0.0001

func _append_modifiers(by_id: Dictionary, item_id: String, stat_id: String, source_prefix: String) -> void:
	if not _catalog.has(item_id):
		return
	var modifiers: Array = (_catalog[item_id] as Dictionary)["modifiers"]
	for index in modifiers.size():
		var row: Dictionary = modifiers[index]
		if str(row.get("stat", "")) != stat_id:
			continue
		var id := "%s.%s.%d" % [source_prefix, item_id, index]
		if not by_id.has(id):
			by_id[id] = {"operation": row["operation"], "value": row["value"], "priority": row.get("priority", 0)}

static func _valid_modifier(row: Dictionary) -> bool:
	return row.size() >= 3 and row.get("stat") is String and not str(row["stat"]).is_empty() and row.get("operation") in StatModifierPipeline.PHASE_ORDER and typeof(row.get("value")) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(row["value"]))

static func _valid_transaction_id(value: String) -> bool:
	return value.begins_with("txn.") and value.length() <= 96 and SectorIds.valid(value)

static func _integer(value: Variant) -> bool:
	return typeof(value) in [TYPE_INT, TYPE_FLOAT] and is_finite(float(value)) and float(value) == floorf(float(value)) and absf(float(value)) <= float(MAX_QUANTITY)

static func _exact(value: Dictionary, keys: Array) -> bool:
	if value.size() != keys.size():
		return false
	for key in keys:
		if not value.has(key):
			return false
	return true

static func _canonical(value: Variant) -> Variant:
	if value is Dictionary:
		var result := {}
		var keys: Array = value.keys()
		keys.sort()
		for key in keys:
			result[key] = _canonical(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(_canonical(item))
		return result
	return value
