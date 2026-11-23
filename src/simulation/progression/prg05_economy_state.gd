class_name Prg05EconomyState
extends RefCounted

# Host/offline authority. Client payloads can request buy/sell only.
const VERSION := 2
const LEGACY_VERSION := 1
const OP_BUY := "economy_market_buy"
const OP_SELL := "economy_market_sell"
const MAX_CURRENCY := 2147483647
const MAX_EVENTS := 256
const MAX_QUANTITY := 10000
const MAX_BOUNTIES := 32
const MAX_COMPANIES := 16
const MAX_COMPANY_MEMBERS := 8
const MAX_CREW_WAGE := 100000

var _inventory
var _owners: Dictionary = {}
var _diplomatic_owners: Dictionary = {}
var _factions: Dictionary = {}
var _markets: Dictionary = {}
var _outposts: Dictionary = {}
# Immutable server-registered content, re-registered from data after loading.
# Accepted claims and sightings persist in the existing event/credit ledger.
var _bounty_contracts: Dictionary = {}
# A company organizes player owners; crew equipment stays in PRG-01 inventory.
var _companies: Dictionary = {}
var _events: Dictionary = {}
var _relations := FactionRelationResolver.new()
var _authority := true

func _init(inventory = null, authority_enabled: bool = true) -> void:
	_inventory = inventory
	_authority = authority_enabled
	_relations = FactionRelationResolver.new(authority_enabled)

static func supports_operation(operation: String) -> bool:
	return operation in [OP_BUY, OP_SELL]

func bind_owner(id: String) -> bool:
	if not _authority or _inventory == null or not _inventory.has_owner(id):
		return false
	if not _owners.has(id):
		if _owners.size() >= 32:
			return false
		_owners[id] = {"balance": 0, "reputation": {}, "credits": {}, "pvp": {}}
	return true

func reassign_owner(a: String, b: String) -> bool:
	if not _authority or not SectorIds.valid(b) or _owners.has(b):
		return false
	if _owners.has(a):
		_owners[b] = _owners[a]
		_owners.erase(a)
	if _diplomatic_owners.has(a):
		_diplomatic_owners.erase(a)
		_diplomatic_owners[b] = true
	for company_id in _companies:
		var row: Dictionary = _companies[company_id]
		var members: Dictionary = row["members"]
		if members.has(a):
			members[b] = (members[a] as Dictionary).duplicate(true)
			members.erase(a)
			if row["captain"] == a:
				row["captain"] = b
			row["members"] = members
			_companies[company_id] = row
	return true

# The trusted host explicitly enables diplomacy only for player-owned actors.
# NPC inventory accounts never acquire a reputation override implicitly.
func enable_player_diplomacy(owner: String) -> bool:
	if not _authority or not _owners.has(owner):
		return false
	_diplomatic_owners[owner] = true
	return true

func actor_disposition(owner: String, faction: String) -> String:
	if not _diplomatic_owners.has(owner) or not _factions.has(faction):
		return FactionRelationResolver.NEUTRAL
	return disposition(owner, faction)

func register_faction(id: String) -> bool:
	if not _authority or not SectorIds.valid(id) or _factions.has(id) or _factions.size() >= 64:
		return false
	_factions[id] = true
	return true

func set_relation_authoritative(a: String, b: String, relation: String) -> bool:
	return _factions.has(a) and _factions.has(b) and _relations.set_relation(a, b, relation)

func faction_relation(a: String, b: String) -> String:
	return _relations.relation(a, b) if _factions.has(a) and _factions.has(b) else FactionRelationResolver.NEUTRAL

func register_market(id: String, faction: String, item: String, sector: String, price: int, stock: int, capacity: int) -> bool:
	if not _authority or not SectorIds.valid(id) or not SectorIds.valid(sector) or not _factions.has(faction) or _markets.has(id) or _markets.size() >= 64:
		return false
	if _inventory == null or not _inventory.has_item_spec(item) or price <= 0 or price > 1000000 or capacity <= 0 or capacity > MAX_QUANTITY or stock < 0 or stock > capacity:
		return false
	_markets[id] = {"faction": faction, "item": item, "sector": sector, "price": price, "stock": stock, "capacity": capacity, "disruption": 0}
	return true

func market_cargo_spec(id: String) -> Dictionary:
	if not _markets.has(id):
		return {}
	var row: Dictionary = _markets[id]
	return {"item": str(row["item"]), "sector": str(row["sector"])}

func has_event(event_id: String) -> bool:
	return SectorIds.valid(event_id) and _events.has(event_id)



# These are host-local orchestration operations, not LAN client intents.
# A company organizes ship owners while PRG-01 remains the sole truth for
# equipped crew items and PRG-05 remains the sole currency ledger.
func company_for_owner(owner: String) -> String:
	for company_id in _companies:
		if (_companies[company_id]["members"] as Dictionary).has(owner):
			return str(company_id)
	return ""


func found_company_authoritative(company_id: String, captain: String) -> bool:
	if not _authority or not SectorIds.valid(company_id) or not _owners.has(captain):
		return false
	if _companies.has(company_id) or _companies.size() >= MAX_COMPANIES or not company_for_owner(captain).is_empty():
		return false
	_companies[company_id] = {"captain": captain,
		"members": {captain: {"rank": "captain", "wage": 0}},
		"last_payroll_tick": -1}
	return true


func enlist_company_member_authoritative(company_id: String, captain: String,
		member: String, rank: String = "sailor") -> bool:
	if not _authority or not _companies.has(company_id) or not _owners.has(member):
		return false
	if rank not in ["officer", "sailor"] or not company_for_owner(member).is_empty():
		return false
	var company: Dictionary = _companies[company_id]
	var members: Dictionary = company["members"]
	if company["captain"] != captain or members.size() >= MAX_COMPANY_MEMBERS:
		return false
	members[member] = {"rank": rank, "wage": 0}
	return true


func set_company_crew_wage_authoritative(company_id: String, captain: String,
		member: String, wage: int) -> bool:
	if not _authority or not _companies.has(company_id) or wage < 0 or wage > MAX_CREW_WAGE:
		return false
	var company: Dictionary = _companies[company_id]
	var members: Dictionary = company["members"]
	if company["captain"] != captain or not members.has(member):
		return false
	var worker: Dictionary = members[member]
	worker["wage"] = wage
	return true


func company_roster(company_id: String) -> Dictionary:
	if not _companies.has(company_id) or _inventory == null:
		return {}
	var company: Dictionary = _companies[company_id]
	var members: Dictionary = company["members"]
	var roster: Array = []
	var owner_ids := members.keys()
	owner_ids.sort()
	for owner in owner_ids:
		var row: Dictionary = members[owner]
		var equipped: Dictionary = _inventory.equipment_snapshot(str(owner))
		roster.append({"owner_id": str(owner), "rank": str(row["rank"]),
			"wage": int(row["wage"]), "crew_item_id": str(equipped.get("crew", ""))})
	return {"company_id": company_id, "captain": str(company["captain"]),
		"last_payroll_tick": int(company["last_payroll_tick"]),
		"members": roster}


func settle_company_payroll_authoritative(event_id: String, company_id: String, tick: int) -> Dictionary:
	var fingerprint := "company_payroll|%s|%d" % [company_id, tick]
	var cached := _existing(event_id, fingerprint)
	if not cached.is_empty():
		return cached
	if not _authority or not SectorIds.valid(event_id) or not _companies.has(company_id):
		return {"accepted": false, "reason": "company_unavailable"}
	if tick < 0 or tick > MAX_CURRENCY or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_payroll"}
	var company: Dictionary = _companies[company_id]
	if tick <= int(company["last_payroll_tick"]):
		return {"accepted": false, "reason": "payroll_already_settled"}
	var captain := str(company["captain"])
	if not _owners.has(captain) or _inventory == null:
		return {"accepted": false, "reason": "captain_unavailable"}
	var total := 0
	var crew_count := 0
	var members: Dictionary = company["members"]
	for member in members:
		var equipped: Dictionary = _inventory.equipment_snapshot(str(member))
		var crew_id := str(equipped.get("crew", ""))
		if crew_id.is_empty():
			continue
		# Crew truth comes from the existing typed inventory/equipment system.
		var item_spec: Dictionary = _inventory.item_spec(crew_id)
		if item_spec.is_empty() or str(item_spec.get("equip_slot", "")) != "crew":
			return {"accepted": false, "reason": "invalid_crew_equipment"}
		crew_count += 1
		total += int((members[member] as Dictionary)["wage"])
	if crew_count == 0:
		return {"accepted": false, "reason": "no_crew_equipped"}
	if total > balance(captain):
		return {"accepted": false, "reason": "insufficient_company_funds"}
	(_owners[captain] as Dictionary)["balance"] = balance(captain) - total
	company["last_payroll_tick"] = tick
	var result := {"accepted": true, "type": "company_payroll", "company_id": company_id,
		"captain_id": captain, "paid": total, "crew_count": crew_count,
		"balance": balance(captain), "tick": tick}
	_remember(event_id, fingerprint, result)
	return result


func register_bounty_contract(bounty_id: String, faction_id: String, target_id: String,
		reward: int, deadline_tick: int) -> bool:
	if not _authority or not SectorIds.valid(bounty_id) or bounty_id.length() > 54:
		return false
	if _bounty_contracts.has(bounty_id) or _bounty_contracts.size() >= MAX_BOUNTIES:
		return false
	if not _factions.has(faction_id) or not SectorIds.valid(target_id) or reward <= 0 or reward > 1000000 or deadline_tick < 0 or deadline_tick > MAX_CURRENCY:
		return false
	_bounty_contracts[bounty_id] = {"faction_id": faction_id, "target_id": target_id,
		"reward": reward, "deadline_tick": deadline_tick}
	return true


func bounty_contract(bounty_id: String) -> Dictionary:
	return (_bounty_contracts.get(bounty_id, {}) as Dictionary).duplicate(true)


func bounty_board(owner: String, tick: int) -> Array:
	var rows: Array = []
	if not _owners.has(owner) or tick < 0:
		return rows
	var ids := _bounty_contracts.keys()
	ids.sort()
	for id in ids:
		var contract: Dictionary = _bounty_contracts[id]
		var event_id := "event.prg05.bounty.%s" % id
		rows.append({"bounty_id": id, "faction_id": contract["faction_id"],
			"target_id": contract["target_id"], "reward": contract["reward"],
			"expired": int(contract["deadline_tick"]) > 0 and tick > int(contract["deadline_tick"]),
			"claimed": _events.has(event_id)})
	return rows


# Trusted combat or world-domain proof only; not exposed as a LAN intent.
func claim_bounty_authoritative(owner: String, bounty_id: String, defeated_target: String,
		kill_sequence: int, tick: int) -> Dictionary:
	if not _authority or not _bounty_contracts.has(bounty_id) or not _owners.has(owner):
		return {"accepted": false, "reason": "bounty_unavailable"}
	var contract: Dictionary = _bounty_contracts[bounty_id]
	var event_id := "event.prg05.bounty.%s" % bounty_id
	var fingerprint := "claim|%s|%s|%s|%d" % [owner, bounty_id, defeated_target, kill_sequence]
	var cached := _existing(event_id, fingerprint)
	if not cached.is_empty():
		return cached
	if defeated_target != str(contract["target_id"]) or kill_sequence <= 0 or tick < 0:
		return {"accepted": false, "reason": "invalid_bounty_proof"}
	if int(contract["deadline_tick"]) > 0 and tick > int(contract["deadline_tick"]):
		return {"accepted": false, "reason": "bounty_expired"}
	if disposition(owner, str(contract["faction_id"])) == FactionRelationResolver.HOSTILE:
		return {"accepted": false, "reason": "hostile_bounty_board"}
	if _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "event_limit"}
	var payment := grant_currency_authoritative(owner, "credit.%s" % event_id, int(contract["reward"]))
	if not bool(payment.get("accepted", false)):
		return {"accepted": false, "reason": "bounty_payment_rejected"}
	var result := {"accepted": true, "type": "bounty_claim", "owner_id": owner,
		"bounty_id": bounty_id, "reward": int(contract["reward"])}
	_remember(event_id, fingerprint, result)
	return result


func record_intel_authoritative(owner: String, event_id: String, sector_id: String,
		subject_id: String, tick: int) -> Dictionary:
	var fingerprint := "intel|%s|%s|%s|%d" % [owner, sector_id, subject_id, tick]
	var cached := _existing(event_id, fingerprint)
	if not cached.is_empty():
		return cached
	if not _authority or not _owners.has(owner) or not SectorIds.valid(event_id):
		return {"accepted": false, "reason": "intel_unavailable"}
	if not SectorIds.valid(sector_id) or not SectorIds.valid(subject_id) or tick < 0 or tick > MAX_CURRENCY or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_intel"}
	var result := {"accepted": true, "type": "intel", "owner_id": owner,
		"sector_id": sector_id, "subject_id": subject_id, "tick": tick}
	_remember(event_id, fingerprint, result)
	return result


func intel_reports(owner: String) -> Array:
	var rows: Array = []
	if not _owners.has(owner):
		return rows
	var ids := _events.keys()
	ids.sort()
	for event_id in ids:
		var result: Dictionary = _events[event_id]["result"]
		if str(result.get("type", "")) == "intel" and result.get("owner_id") == owner:
			var detached := result.duplicate(true)
			detached["event_id"] = event_id
			rows.append(detached)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["tick"]) != int(b["tick"]):
			return int(a["tick"]) > int(b["tick"])
		return str(a["event_id"]) < str(b["event_id"]))
	return rows.slice(0, 32)


func register_outpost(id: String, faction: String) -> bool:
	if not _authority or not SectorIds.valid(id) or not _factions.has(faction) or _outposts.has(id) or _outposts.size() >= 64:
		return false
	_outposts[id] = faction
	return true

func outpost_owner(id: String) -> String:
	return str(_outposts.get(id, ""))

func balance(id: String) -> int:
	return int((_owners.get(id, {}) as Dictionary).get("balance", 0))

func reputation(id: String, faction: String) -> int:
	return int(((_owners.get(id, {}) as Dictionary).get("reputation", {}) as Dictionary).get(faction, 0))

func disposition(id: String, faction: String) -> String:
	var rep := reputation(id, faction)
	if rep <= -250:
		return FactionRelationResolver.HOSTILE
	if rep >= 250:
		return FactionRelationResolver.FRIENDLY
	return FactionRelationResolver.NEUTRAL

func quote(owner: String, id: String) -> Dictionary:
	if not _owners.has(owner) or not _markets.has(id):
		return {}
	var row: Dictionary = _markets[id]
	var scarcity := (int(row["capacity"]) - int(row["stock"])) * 30 / int(row["capacity"])
	var multiplier := 100 + scarcity + int(row["disruption"]) * 10
	var rep_adjust := clampi(reputation(owner, str(row["faction"])) / 20, -20, 20)
	var price := maxi(1, ceili(float(int(row["price"]) * multiplier * (100 - rep_adjust)) / 10000.0))
	return {"item": row["item"], "stock": int(row["stock"]), "buy": price, "sell": maxi(1, price / 2), "disposition": disposition(owner, str(row["faction"]))}

func execute(owner: String, operation: String, payload: Dictionary) -> Dictionary:
	var result := {"accepted": false, "reason": "economy_unavailable", "operation": operation}
	if not _authority or not _owners.has(owner) or not supports_operation(operation):
		return result
	if payload.size() != 2 or not payload.get("market_id") is String or not _int_between(payload.get("quantity"), 1, MAX_QUANTITY):
		result["reason"] = "malformed_payload"
		return result
	var id := str(payload["market_id"])
	var amount := int(payload["quantity"])
	var info := quote(owner, id)
	if info.is_empty():
		result["reason"] = "market_unavailable"
		return result
	if info["disposition"] == FactionRelationResolver.HOSTILE:
		result["reason"] = "hostile_market"
		return result
	var row: Dictionary = _markets[id]
	var unit := int(info["buy"] if operation == OP_BUY else info["sell"])
	var cost := unit * amount
	var previous := balance(owner)
	var delta := amount if operation == OP_BUY else -amount
	if operation == OP_BUY and (amount > int(row["stock"]) or cost > previous):
		result["reason"] = "insufficient_stock_or_funds"
		return result
	if operation == OP_SELL and (amount > int(row["capacity"]) - int(row["stock"]) or cost > MAX_CURRENCY - previous):
		result["reason"] = "market_full_or_overflow"
		return result
	var item_delta := {str(row["item"]): delta}
	if not _inventory.can_apply_item_deltas(owner, item_delta) or not _inventory.apply_item_deltas_atomic(owner, item_delta):
		result["reason"] = "inventory_rejected"
		return result
	(_owners[owner] as Dictionary)["balance"] = previous - cost if operation == OP_BUY else previous + cost
	row["stock"] = int(row["stock"]) - delta
	_markets[id] = row
	return {"accepted": true, "reason": "", "operation": operation, "quantity": amount,
		"unit_price": unit, "balance": balance(owner), "stock": int(row["stock"])}

func grant_currency_authoritative(owner: String, event: String, amount: int) -> Dictionary:
	if not _authority or not _owners.has(owner) or not SectorIds.valid(event) or amount <= 0 or amount > MAX_CURRENCY:
		return {"accepted": false, "reason": "invalid_currency"}
	var data: Dictionary = _owners[owner]
	var credits: Dictionary = data["credits"]
	if credits.has(event):
		if int(credits[event]) != amount:
			return {"accepted": false, "reason": "event_conflict"}
		return {"accepted": true, "duplicate": true, "balance": balance(owner)}
	if credits.size() >= 128 or amount > MAX_CURRENCY - balance(owner):
		return {"accepted": false, "reason": "credit_limit"}
	credits[event] = amount
	data["balance"] = int(data["balance"]) + amount
	return {"accepted": true, "duplicate": false, "balance": balance(owner)}

func adjust_reputation_authoritative(owner: String, faction: String, event: String, delta: int) -> Dictionary:
	var fp := "rep|%s|%s|%d" % [owner, faction, delta]
	var cached := _existing(event, fp)
	if not cached.is_empty():
		return cached
	if not _authority or not _owners.has(owner) or not _factions.has(faction) or not SectorIds.valid(event) or delta == 0 or absi(delta) > 1000 or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_reputation"}
	var reps: Dictionary = (_owners[owner] as Dictionary)["reputation"]
	reps[faction] = clampi(int(reps.get(faction, 0)) + delta, -1000, 1000)
	var result := {"accepted": true, "score": int(reps[faction]), "disposition": disposition(owner, faction)}
	_remember(event, fp, result)
	return result

func convoy_loss_authoritative(event: String, market_id: String, loss: int) -> Dictionary:
	var fp := "convoy|%s|%d" % [market_id, loss]
	var cached := _existing(event, fp)
	if not cached.is_empty():
		return cached
	if not _authority or not SectorIds.valid(event) or not _markets.has(market_id) or loss <= 0 or loss > MAX_QUANTITY or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_convoy"}
	var row: Dictionary = _markets[market_id]
	row["stock"] = maxi(0, int(row["stock"]) - loss)
	row["disruption"] = mini(5, int(row["disruption"]) + 1)
	var result := {"accepted": true, "stock": int(row["stock"])}
	_remember(event, fp, result)
	return result

func convoy_delivery_authoritative(event: String, market_id: String, amount: int) -> Dictionary:
	var fp := "convoy_delivery|%s|%d" % [market_id, amount]
	var cached := _existing(event, fp)
	if not cached.is_empty():
		return cached
	if not _authority or not SectorIds.valid(event) or not _markets.has(market_id) or amount <= 0 or amount > MAX_QUANTITY or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_convoy"}
	var row: Dictionary = _markets[market_id]
	var delivered := mini(amount, int(row["capacity"]) - int(row["stock"]))
	row["stock"] = int(row["stock"]) + delivered
	row["disruption"] = maxi(0, int(row["disruption"]) - 1)
	var result := {"accepted": true, "stock": int(row["stock"]), "delivered": delivered}
	_remember(event, fp, result)
	return result

func capture_outpost_authoritative(event: String, outpost: String, faction: String) -> Dictionary:
	var fp := "outpost|%s|%s" % [outpost, faction]
	var cached := _existing(event, fp)
	if not cached.is_empty():
		return cached
	if not _authority or not SectorIds.valid(event) or not _outposts.has(outpost) or not _factions.has(faction) or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_outpost"}
	_outposts[outpost] = faction
	var result := {"accepted": true, "owner": faction}
	_remember(event, fp, result)
	return result

func pvp_kill_authoritative(event: String, killer: String, victim: String, reward_base: int) -> Dictionary:
	var fp := "pvp|%s|%s|%d" % [killer, victim, reward_base]
	var cached := _existing(event, fp)
	if not cached.is_empty():
		return cached
	if not _authority or not SectorIds.valid(event) or killer == victim or not _owners.has(killer) or not _owners.has(victim) or reward_base <= 0 or reward_base > 1000000 or _events.size() >= MAX_EVENTS:
		return {"accepted": false, "reason": "invalid_pvp"}
	var data: Dictionary = _owners[killer]
	var pairs: Dictionary = data["pvp"]
	var repeats := int(pairs.get(victim, 0))
	var reward := reward_base / (repeats + 1)
	if reward > MAX_CURRENCY - balance(killer):
		return {"accepted": false, "reason": "balance_overflow"}
	data["balance"] = int(data["balance"]) + reward
	pairs[victim] = mini(10000, repeats + 1)
	var result := {"accepted": true, "reward": reward, "repeats": repeats}
	_remember(event, fp, result)
	return result

func snapshot_state() -> Dictionary:
	return {"version": VERSION, "owners": _owners.duplicate(true), "markets": _markets.duplicate(true),
		"outposts": _outposts.duplicate(true), "events": _events.duplicate(true),
		"companies": _companies.duplicate(true), "relations": _relations.snapshot_state()}

func restore_state(value: Variant) -> bool:
	if not _authority or not validate_state(value) or _inventory == null:
		return false
	var data: Dictionary = value
	for owner in data["owners"]:
		if not _inventory.has_owner(str(owner)):
			return false
	for market in data["markets"]:
		if not _markets.has(market):
			return false
		var local: Dictionary = _markets[market]
		var saved: Dictionary = data["markets"][market]
		for key in ["faction", "item", "sector", "price", "capacity"]:
			if local[key] != saved[key]:
				return false
	for outpost in data["outposts"]:
		if not _outposts.has(outpost) or not _factions.has(str(data["outposts"][outpost])):
			return false
	for owner in data["owners"]:
		for faction in data["owners"][owner]["reputation"]:
			if not _factions.has(faction):
				return false
	if not _relations.restore_state(data["relations"]):
		return false
	for owner in data["owners"]:
		_owners[owner] = (data["owners"][owner] as Dictionary).duplicate(true)
	_markets = (data["markets"] as Dictionary).duplicate(true) if not data["markets"].is_empty() else _markets
	_outposts = (data["outposts"] as Dictionary).duplicate(true) if not data["outposts"].is_empty() else _outposts
	_events = (data["events"] as Dictionary).duplicate(true)
	# JSON restores integral DTO numbers as floats; canonicalize known
	# authoritative result fields so cached lost-ACK/event replays preserve
	# their original integer types across save/load.
	for event_id in _events:
		var entry: Dictionary = _events[event_id]
		var result: Dictionary = entry["result"]
		match str(result.get("type", "")):
			"company_payroll":
				for key in ["paid", "crew_count", "balance", "tick"]:
					result[key] = int(result[key])
			"bounty_claim":
				result["reward"] = int(result["reward"])
			"intel":
				result["tick"] = int(result["tick"])
	_companies = (data.get("companies", {}) as Dictionary).duplicate(true)
	return true

static func empty_state() -> Dictionary:
	return {"version": VERSION, "owners": {}, "markets": {}, "outposts": {}, "events": {},
		"companies": {}, "relations": {"version": FactionRelationResolver.VERSION, "relations": []}}

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var data: Dictionary = value
	var version := int(data.get("version", -1))
	if version not in [LEGACY_VERSION, VERSION] or data.size() != (6 if version == LEGACY_VERSION else 7):
		return false
	if not data.get("owners") is Dictionary or not data.get("markets") is Dictionary or not data.get("outposts") is Dictionary or not data.get("events") is Dictionary:
		return false
	if version == VERSION and not data.get("companies") is Dictionary:
		return false
	if data["owners"].size() > 32 or data["markets"].size() > 64 or data["outposts"].size() > 64 or data["events"].size() > MAX_EVENTS:
		return false
	var companies: Dictionary = data.get("companies", {})
	if companies.size() > MAX_COMPANIES:
		return false
	var seen_members: Dictionary = {}
	for company_id in companies:
		if not company_id is String or not SectorIds.valid(company_id) or not companies[company_id] is Dictionary:
			return false
		var company: Dictionary = companies[company_id]
		if company.size() != 3 or not company.get("captain") is String or not company.get("members") is Dictionary:
			return false
		if not _bounded(company.get("last_payroll_tick"), -1, MAX_CURRENCY):
			return false
		var members: Dictionary = company["members"]
		var captain: String = company["captain"]
		if members.is_empty() or members.size() > MAX_COMPANY_MEMBERS or not members.has(captain):
			return false
		for member in members:
			if not member is String or not SectorIds.valid(member) or not data["owners"].has(member) or seen_members.has(member):
				return false
			if not members[member] is Dictionary:
				return false
			var crew: Dictionary = members[member]
			if crew.size() != 2 or crew.get("rank") not in ["captain", "officer", "sailor"] or not _bounded(crew.get("wage"), 0, MAX_CREW_WAGE):
				return false
			if (str(member) == captain) != (crew["rank"] == "captain"):
				return false
			seen_members[member] = true
	for owner in data["owners"]:
		if not owner is String or not SectorIds.valid(owner) or not data["owners"][owner] is Dictionary:
			return false
		var row: Dictionary = data["owners"][owner]
		if row.size() != 4 or not _bounded(row.get("balance"), 0, MAX_CURRENCY) or not row.get("credits") is Dictionary or not row.get("reputation") is Dictionary or not row.get("pvp") is Dictionary:
			return false
		if row["credits"].size() > 128 or row["reputation"].size() > 64 or row["pvp"].size() > 32:
			return false
		for id in row["credits"]:
			if not id is String or not SectorIds.valid(id) or not _bounded(row["credits"][id], 1, MAX_CURRENCY):
				return false
		for id in row["reputation"]:
			if not id is String or not SectorIds.valid(id) or not _bounded(row["reputation"][id], -1000, 1000):
				return false
		for id in row["pvp"]:
			if not id is String or not SectorIds.valid(id) or not _bounded(row["pvp"][id], 1, 10000):
				return false
	for id in data["markets"]:
		if not id is String or not SectorIds.valid(id) or not data["markets"][id] is Dictionary:
			return false
		var row: Dictionary = data["markets"][id]
		if row.size() != 7 or not _bounded(row.get("price"), 1, 1000000) or not _bounded(row.get("capacity"), 1, MAX_QUANTITY) or not _bounded(row.get("stock"), 0, int(row["capacity"])) or not _bounded(row.get("disruption"), 0, 5):
			return false
		for key in ["faction", "item", "sector"]:
			if not row.get(key) is String or not SectorIds.valid(row[key]):
				return false
	for id in data["outposts"]:
		if not id is String or not SectorIds.valid(id) or not data["outposts"][id] is String or not SectorIds.valid(data["outposts"][id]):
			return false
	for id in data["events"]:
		if not id is String or not SectorIds.valid(id) or not data["events"][id] is Dictionary:
			return false
		var entry: Dictionary = data["events"][id]
		if entry.size() != 2 or not entry.get("fingerprint") is String or str(entry["fingerprint"]).length() != 64 or not entry.get("result") is Dictionary:
			return false
		var result: Dictionary = entry["result"]
		if str(result.get("type", "")) == "intel":
			if result.size() != 6 or result.get("accepted") != true or not _bounded(result.get("tick"), 0, MAX_CURRENCY):
				return false
			for key in ["owner_id", "sector_id", "subject_id"]:
				if not result.get(key) is String or not SectorIds.valid(result[key]):
					return false
		elif str(result.get("type", "")) == "company_payroll":
			if result.size() != 8 or result.get("accepted") != true or not _bounded(result.get("paid"), 0, MAX_CREW_WAGE * MAX_COMPANY_MEMBERS):
				return false
			for key in ["company_id", "captain_id"]:
				if not result.get(key) is String or not SectorIds.valid(result[key]):
					return false
			if not _bounded(result.get("crew_count"), 1, MAX_COMPANY_MEMBERS) or not _bounded(result.get("balance"), 0, MAX_CURRENCY) or not _bounded(result.get("tick"), 0, MAX_CURRENCY):
				return false
		elif str(result.get("type", "")) == "bounty_claim":
			if result.size() != 5 or result.get("accepted") != true or not _bounded(result.get("reward"), 1, 1000000):
				return false
			for key in ["owner_id", "bounty_id"]:
				if not result.get(key) is String or not SectorIds.valid(result[key]):
					return false
		elif str(result.get("type", "")) == "company_payroll":
			if result.size() != 8 or result.get("accepted") != true:
				return false
			for key in ["company_id", "captain_id"]:
				if not result.get(key) is String or not SectorIds.valid(result[key]):
					return false
			if not _bounded(result.get("paid"), 0, MAX_CURRENCY) or not _bounded(result.get("crew_count"), 1, MAX_COMPANY_MEMBERS) or not _bounded(result.get("balance"), 0, MAX_CURRENCY) or not _bounded(result.get("tick"), 0, MAX_CURRENCY):
				return false
	var probe := FactionRelationResolver.new()
	return probe.restore_state(data.get("relations"))

static func _int_between(value: Variant, lo: int, hi: int) -> bool:
	return _bounded(value, lo, hi)

static func _bounded(value: Variant, lo: int, hi: int) -> bool:
	if typeof(value) not in [TYPE_INT, TYPE_FLOAT]:
		return false
	var number := float(value)
	return is_finite(number) and number == floorf(number) and number >= float(lo) and number <= float(hi)

func _existing(event: String, fp: String) -> Dictionary:
	if not _events.has(event):
		return {}
	var entry: Dictionary = _events[event]
	if entry["fingerprint"] != fp.sha256_text():
		return {"accepted": false, "reason": "event_conflict"}
	return (entry["result"] as Dictionary).duplicate(true)

func _remember(event: String, fp: String, result: Dictionary) -> void:
	_events[event] = {"fingerprint": fp.sha256_text(), "result": result.duplicate(true)}
