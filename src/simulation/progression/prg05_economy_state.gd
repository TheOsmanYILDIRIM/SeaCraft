class_name Prg05EconomyState
extends RefCounted

# Host/offline authority. Client payloads can request buy/sell only.
const VERSION := 1
const OP_BUY := "economy_market_buy"
const OP_SELL := "economy_market_sell"
const MAX_CURRENCY := 2147483647
const MAX_EVENTS := 256
const MAX_QUANTITY := 10000

var _inventory
var _owners: Dictionary = {}
var _factions: Dictionary = {}
var _markets: Dictionary = {}
var _outposts: Dictionary = {}
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
	return true

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
		"outposts": _outposts.duplicate(true), "events": _events.duplicate(true), "relations": _relations.snapshot_state()}

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
	return true

static func empty_state() -> Dictionary:
	return {"version": VERSION, "owners": {}, "markets": {}, "outposts": {}, "events": {},
		"relations": {"version": FactionRelationResolver.VERSION, "relations": []}}

static func validate_state(value: Variant) -> bool:
	if not value is Dictionary or not DtoContract.is_primitive_safe(value):
		return false
	var data: Dictionary = value
	if data.size() != 6 or data.get("version") != VERSION or not data.get("owners") is Dictionary or not data.get("markets") is Dictionary or not data.get("outposts") is Dictionary or not data.get("events") is Dictionary:
		return false
	if data["owners"].size() > 32 or data["markets"].size() > 64 or data["outposts"].size() > 64 or data["events"].size() > MAX_EVENTS:
		return false
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
	var probe := FactionRelationResolver.new()
	return probe.restore_state(data.get("relations"))

static func _int_between(value: Variant, lo: int, hi: int) -> bool:
	return _bounded(value, lo, hi)

static func _bounded(value: Variant, lo: int, hi: int) -> bool:
	return typeof(value) == TYPE_INT and int(value) >= lo and int(value) <= hi

func _existing(event: String, fp: String) -> Dictionary:
	if not _events.has(event):
		return {}
	var entry: Dictionary = _events[event]
	if entry["fingerprint"] != fp.sha256_text():
		return {"accepted": false, "reason": "event_conflict"}
	return (entry["result"] as Dictionary).duplicate(true)

func _remember(event: String, fp: String, result: Dictionary) -> void:
	_events[event] = {"fingerprint": fp.sha256_text(), "result": result.duplicate(true)}
