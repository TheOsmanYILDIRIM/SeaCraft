class_name Prg05MarketAccessGuard
extends RefCounted

# Never trust player position, sector or store coordinates from an RPC.
# This guard binds trusted market definitions to the host's active sector and
# real server-owned ShipMotor; it is deliberately not a save/network DTO.
const MAX_MARKETS := 64
const MAX_RADIUS := 512.0
const MAX_POSITION_LAG := 64.0

var _inventory: InventoryState
var _markets: Dictionary = {}

func _init(inventory: InventoryState) -> void:
	_inventory = inventory

func is_bound_to(inventory: InventoryState) -> bool:
	return inventory != null and _inventory == inventory

func bind_market(market_id: String, sector: SectorRuntime, center: Vector2, radius: float = 128.0) -> bool:
	if _inventory == null or sector == null or not SectorIds.valid(market_id):
		return false
	if _markets.has(market_id) or _markets.size() >= MAX_MARKETS:
		return false
	if not is_finite(radius) or radius <= 0.0 or radius > MAX_RADIUS or not center.is_finite():
		return false
	if not sector.bounds.has_point(center):
		return false
	var market_spec := _inventory.economy_market_cargo_spec(market_id)
	if market_spec.is_empty() or str(market_spec["sector"]) != sector.sector_id:
		return false
	_markets[market_id] = {"sector": sector, "center": center, "radius": radius}
	return true

func allows(owner_id: String, market_id: String, motor: ShipMotor) -> bool:
	if _inventory == null or not _inventory.has_owner(owner_id) or not _markets.has(market_id):
		return false
	if motor == null or not is_instance_valid(motor) or not motor.authority_enabled:
		return false
	var binding: Dictionary = _markets[market_id]
	var sector: SectorRuntime = binding["sector"]
	if sector == null or str(_inventory.economy_market_cargo_spec(market_id).get("sector", "")) != sector.sector_id:
		return false
	var position := motor.global_position
	var indexed := sector.entity_position(owner_id)
	if not position.is_finite() or not indexed.is_finite() or not sector.bounds.has_point(position):
		return false
	if position.distance_squared_to(indexed) > MAX_POSITION_LAG * MAX_POSITION_LAG:
		return false
	var center: Vector2 = binding["center"]
	var radius := float(binding["radius"])
	return position.distance_squared_to(center) <= radius * radius
