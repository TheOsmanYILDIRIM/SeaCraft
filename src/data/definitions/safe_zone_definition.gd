class_name SafeZoneDefinition
extends BaseDefinition

@export var sector_id: String = ""
@export var center: Vector2 = Vector2.ZERO
@export var radius: float = 0.0


func definition_type() -> String:
	return "safe_zone"


func valid_for_sector(expected_sector_id: String) -> bool:
	return SectorIds.valid(stable_id) and SectorIds.valid(sector_id) and sector_id == expected_sector_id \
		and center.is_finite() and is_finite(radius) and radius > 0.0 and radius <= SectorSpatialHash.MAX_RADIUS
