class_name Ai03ConvoyFixture
extends RefCounted


static func build(index: int, sector_id: String) -> Dictionary:
	if index < 0 or index > 99 or not SectorIds.valid(sector_id):
		return {}
	var suffix := "c%02d" % index
	var fleet_id := "fleet.ai03.convoy.%s" % suffix
	var leader := "entity.ai03.merchant.%s" % suffix
	var escort_a := "entity.ai03.escort.%s.a" % suffix
	var escort_b := "entity.ai03.escort.%s.b" % suffix
	var scout := "entity.ai03.scout.%s" % suffix
	var cargo := WorldJob.cargo_mission("mission.ai03.cargo.%s" % suffix, "item.ai03.cargo.%s" % suffix, 12, "anchor.ai03.origin.%s" % suffix, "anchor.ai03.destination.%s" % suffix, WorldJob.READY)
	var job := WorldJob.create("job.ai03.trade.%s" % suffix, WorldJob.TRADE, fleet_id, "anchor.ai03.origin.%s" % suffix, "anchor.ai03.destination.%s" % suffix, sector_id, WorldJob.TRAVEL, "", cargo)
	return {
		"fleet_id": fleet_id,
		"leader_id": leader,
		"sector_id": sector_id,
		"formation_type": FleetCoordinator.COLUMN,
		"members": [
			{"member_id": leader, "role": FleetCoordinator.MERCHANT, "alive": true, "available": true, "sector_id": sector_id, "preferred_distance": 0.0},
			{"member_id": escort_a, "role": FleetCoordinator.ESCORT, "alive": true, "available": true, "sector_id": sector_id, "preferred_distance": 120.0},
			{"member_id": escort_b, "role": FleetCoordinator.ESCORT, "alive": true, "available": true, "sector_id": sector_id, "preferred_distance": 120.0},
			{"member_id": scout, "role": FleetCoordinator.SCOUT, "alive": true, "available": true, "sector_id": sector_id, "preferred_distance": 140.0},
		],
		"world_job": job,
	}
