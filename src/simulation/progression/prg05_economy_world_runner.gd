class_name Prg05EconomyWorldRunner
extends RefCounted

# Server orchestration: one AI-04 scheduler drain -> FAR travel/encounters
# -> existing host-owned PRG-05 convoy bridge. Other work is returned to caller.
const MAX_CONVOYS := 64
var _world: WorldSimulationAuthority
var _inventory: InventoryState
var _bridge: Prg05ConvoyBridge
var _enabled := true
var _bound: Dictionary = {}
var _settled: Dictionary = {}
var _last_tick := -1


func _init(world: WorldSimulationAuthority, inventory: InventoryState,
		bridge: Prg05ConvoyBridge, enabled: bool = true) -> void:
	_world = world
	_inventory = inventory
	_bridge = bridge
	_enabled = enabled


func bind_far_convoy(merchant_id: String, market_id: String, due_tick: int = 0) -> bool:
	if not _enabled or _world == null or _inventory == null or _bridge == null:
		return false
	if not SectorIds.valid(merchant_id) or not SectorIds.valid(market_id):
		return false
	if _bound.has(merchant_id):
		return str(_bound[merchant_id]) == market_id
	if _bound.size() >= MAX_CONVOYS or not _bridge.bind_far_convoy(_world, merchant_id, market_id):
		return false
	var state := FarFieldEntityState.project(_world.record(merchant_id))
	var job: Dictionary = state.get("world_job", {})
	if not WorldJob.valid(job):
		return false
	var event_id := "event.prg05.convoy.%s" % str(job["job_id"])
	var already_settled := _inventory.economy_event_applied(event_id)
	if not already_settled and not _world.queue_far_update(merchant_id, due_tick):
		return false
	_bound[merchant_id] = market_id
	if already_settled:
		_settled[merchant_id] = true
	return true


func advance_tick(tick: int, hazards: Dictionary = {}) -> Dictionary:
	if not _enabled or _world == null or _inventory == null or _bridge == null or tick < 0 or tick <= _last_tick:
		return {}
	var work := _world.advance_scheduler(tick)
	if work.is_empty():
		return {}
	_last_tick = tick
	var advanced: Array = []
	var errors: Array = []
	for raw in work.get("far", []):
		if not raw is Dictionary:
			continue
		var entity_id := str(raw.get("stable_id", ""))
		var current := FarFieldEntityState.project(_world.record(entity_id))
		if current.is_empty() or str(current["lod"]) != SimulationLOD.FAR:
			errors.append({"entity_id": entity_id, "reason": "invalid_far_record"})
			continue
		var elapsed := maxi(0, tick - int(current["last_simulation_tick"]))
		var outcome := _world.advance_entity(entity_id, elapsed, hazards)
		if outcome.is_empty():
			_world.queue_far_update(entity_id, tick + WorldSimulationAuthority.FAR_INTERVAL_TICKS)
			errors.append({"entity_id": entity_id, "reason": "travel_deferred"})
			continue
		advanced.append(entity_id)
		var updated := FarFieldEntityState.project(_world.record(entity_id))
		var job: Dictionary = updated.get("world_job", {})
		if bool(updated.get("alive", false)) and (job.is_empty() or not bool(job.get("completed", false))):
			_world.queue_far_update(entity_id, tick + WorldSimulationAuthority.FAR_INTERVAL_TICKS)
	# Combat first: a merchant sunk on this tick must not also deliver.
	var encounters := _world.process_far_encounters()
	var settlements: Array = []
	var ids := _bound.keys()
	ids.sort()
	for merchant_id in ids:
		if _settled.has(merchant_id):
			continue
		var settlement := _bridge.settle_far_convoy(_world, str(merchant_id), tick)
		if bool(settlement.get("accepted", false)):
			_settled[merchant_id] = true
			settlements.append({"merchant_id": merchant_id, "result": settlement.duplicate(true)})
		elif str(settlement.get("reason", "")) != "convoy_in_transit":
			errors.append({"entity_id": merchant_id, "reason": str(settlement.get("reason", "unknown"))})
	return {"tick": tick, "work": work, "advanced": advanced, "encounters": encounters,
		"settlements": settlements, "errors": errors}


func is_settled(merchant_id: String) -> bool:
	return _settled.has(merchant_id)
