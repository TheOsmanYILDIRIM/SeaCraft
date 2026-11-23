class_name Prg05ConvoyBridge
extends RefCounted

# Authoritative adapter between AI-03 fleet world jobs and PRG-05 market state.
# Call bind_convoy after host fleet registration, then settle on trusted world events.
# Never accept a client-selected market, outcome, quantity or event ID.
var _economy: InventoryState
var _fleets: FleetCoordinator
var _authority_enabled := true
var _routes: Dictionary = {}


func _init(economy: InventoryState, fleets: FleetCoordinator, authority_enabled: bool = true) -> void:
	_economy = economy
	_fleets = fleets
	_authority_enabled = authority_enabled


func bind_convoy(fleet_id: String, market_id: String) -> bool:
	if not _authority_enabled or _economy == null or _fleets == null or not SectorIds.valid(fleet_id):
		return false
	var fleet := _fleets.fleet_snapshot(fleet_id)
	var job: Dictionary = fleet.get("world_job", {})
	var spec := _economy.economy_market_cargo_spec(market_id)
	if not WorldJob.valid(job) or job["job_type"] != WorldJob.TRADE or spec.is_empty():
		return false
	if str(job["owner_id"]) != fleet_id or str(job["route_sector_id"]) != str(spec["sector"]):
		return false
	var cargo: Dictionary = job["cargo_mission"]
	if cargo.is_empty() or str(cargo["cargo_definition_id"]) != str(spec["item"]):
		return false
	var amount := int(cargo["quantity"])
	if amount <= 0 or amount > Prg05EconomyState.MAX_QUANTITY:
		return false
	var job_id := str(job["job_id"])
	if _routes.has(fleet_id):
		return _routes[fleet_id] == {"market_id": market_id, "job_id": job_id,
			"cargo_id": str(cargo["cargo_definition_id"]), "quantity": amount,
			"origin_id": str(cargo["origin_id"]), "destination_id": str(cargo["destination_id"])}
	_routes[fleet_id] = {"market_id": market_id, "job_id": job_id,
		"cargo_id": str(cargo["cargo_definition_id"]), "quantity": amount,
		"origin_id": str(cargo["origin_id"]), "destination_id": str(cargo["destination_id"])}
	return true


func settle(fleet_id: String, tick: int) -> Dictionary:
	if not _authority_enabled or _economy == null or _fleets == null or tick < 0 or not _routes.has(fleet_id):
		return {"accepted": false, "reason": "unbound_convoy"}
	var binding: Dictionary = _routes[fleet_id]
	var fleet := _fleets.fleet_snapshot(fleet_id)
	var job: Dictionary = fleet.get("world_job", {})
	if not WorldJob.valid(job) or str(job["job_id"]) != str(binding["job_id"]) or str(job["owner_id"]) != fleet_id:
		return {"accepted": false, "reason": "job_changed"}
	var cargo: Dictionary = job["cargo_mission"]
	if cargo.is_empty() or str(cargo["cargo_definition_id"]) != str(binding["cargo_id"]) or int(cargo["quantity"]) != int(binding["quantity"]) or str(cargo["origin_id"]) != str(binding["origin_id"]) or str(cargo["destination_id"]) != str(binding["destination_id"]):
		return {"accepted": false, "reason": "cargo_changed"}
	var merchant_found := false
	var merchant_alive := false
	for member in fleet.get("members", []):
		if member is Dictionary and member.get("role") == FleetCoordinator.MERCHANT:
			merchant_found = true
			merchant_alive = merchant_alive or bool(member.get("alive", false))
	if not merchant_found:
		return {"accepted": false, "reason": "merchant_missing"}
	var event_id := "event.prg05.convoy.%s" % str(binding["job_id"])
	var event_type := "trade_delivered" if bool(job["completed"]) and merchant_alive else "convoy_lost"
	if merchant_alive and not bool(job["completed"]):
		return {"accepted": false, "reason": "convoy_in_transit"}
	if not merchant_alive and bool(job["completed"]):
		return {"accepted": false, "reason": "ambiguous_convoy_outcome"}
	var event := WorldJob.economy_event(job, event_id, event_type, tick)
	if event.is_empty():
		return {"accepted": false, "reason": "invalid_world_event"}
	var result: Dictionary
	if event_type == "convoy_lost":
		result = _economy.record_economy_convoy_loss_authoritative(event_id, str(binding["market_id"]), int(binding["quantity"]))
	else:
		result = _economy.record_economy_convoy_delivery_authoritative(event_id, str(binding["market_id"]), int(binding["quantity"]))
	if result.get("accepted", false):
		result["event"] = event
	return result

# AI-04 far-world projection is authoritative even when no near FleetCoordinator
# instance exists. Bind only from the host's live WorldSimulationAuthority.
var _far_routes: Dictionary = {}


func bind_far_convoy(world: WorldSimulationAuthority, merchant_id: String, market_id: String) -> bool:
	if not _authority_enabled or _economy == null or world == null or not SectorIds.valid(merchant_id):
		return false
	var projection := FarFieldEntityState.project(world.record(merchant_id))
	var job: Dictionary = projection.get("world_job", {})
	var spec := _economy.economy_market_cargo_spec(market_id)
	if projection.is_empty() or str(projection["role"]) != FleetCoordinator.MERCHANT or not WorldJob.valid(job) or job["job_type"] != WorldJob.TRADE or spec.is_empty():
		return false
	if str(projection["fleet_id"]).is_empty() or str(job["owner_id"]) != str(projection["fleet_id"]):
		return false
	# The market must belong to the job's destination, not a client-supplied market.
	if str(job["destination_id"]) != str(spec["sector"]):
		return false
	var cargo: Dictionary = job["cargo_mission"]
	if cargo.is_empty() or str(cargo["cargo_definition_id"]) != str(spec["item"]):
		return false
	var amount := int(cargo["quantity"])
	if amount <= 0 or amount > Prg05EconomyState.MAX_QUANTITY:
		return false
	var binding := {
		"market_id": market_id,
		"fleet_id": str(projection["fleet_id"]),
		"job_id": str(job["job_id"]),
		"cargo_id": str(cargo["cargo_definition_id"]),
		"quantity": amount,
		"origin_id": str(cargo["origin_id"]),
		"destination_id": str(cargo["destination_id"]),
	}
	if _far_routes.has(merchant_id):
		return _far_routes[merchant_id] == binding
	_far_routes[merchant_id] = binding
	return true


func settle_far_convoy(world: WorldSimulationAuthority, merchant_id: String, tick: int) -> Dictionary:
	if not _authority_enabled or _economy == null or world == null or tick < 0 or not _far_routes.has(merchant_id):
		return {"accepted": false, "reason": "unbound_convoy"}
	var binding: Dictionary = _far_routes[merchant_id]
	var projection := FarFieldEntityState.project(world.record(merchant_id))
	var job: Dictionary = projection.get("world_job", {})
	if projection.is_empty() or str(projection["role"]) != FleetCoordinator.MERCHANT or str(projection["fleet_id"]) != str(binding["fleet_id"]) or not WorldJob.valid(job):
		return {"accepted": false, "reason": "job_changed"}
	if str(job["job_id"]) != str(binding["job_id"]) or str(job["owner_id"]) != str(binding["fleet_id"]) or str(job["destination_id"]) != str(_economy.economy_market_cargo_spec(str(binding["market_id"])).get("sector", "")):
		return {"accepted": false, "reason": "job_changed"}
	var cargo: Dictionary = job["cargo_mission"]
	if cargo.is_empty() or str(cargo["cargo_definition_id"]) != str(binding["cargo_id"]) or int(cargo["quantity"]) != int(binding["quantity"]) or str(cargo["origin_id"]) != str(binding["origin_id"]) or str(cargo["destination_id"]) != str(binding["destination_id"]):
		return {"accepted": false, "reason": "cargo_changed"}
	var alive := bool(projection["alive"]) and str(projection["combat"]["status"]) != "sunk"
	var completed := bool(job["completed"])
	if alive and not completed:
		return {"accepted": false, "reason": "convoy_in_transit"}
	if not alive and completed:
		return {"accepted": false, "reason": "ambiguous_convoy_outcome"}
	var event_type := "trade_delivered" if completed else "convoy_lost"
	var event_id := "event.prg05.convoy.%s" % str(binding["job_id"])
	var event := WorldJob.economy_event(job, event_id, event_type, tick)
	if event.is_empty():
		return {"accepted": false, "reason": "invalid_world_event"}
	var result: Dictionary
	if completed:
		result = _economy.record_economy_convoy_delivery_authoritative(event_id, str(binding["market_id"]), int(binding["quantity"]))
	else:
		result = _economy.record_economy_convoy_loss_authoritative(event_id, str(binding["market_id"]), int(binding["quantity"]))
	if result.get("accepted", false):
		result["event"] = event
	return result
