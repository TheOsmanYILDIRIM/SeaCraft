class_name NpcThreatMemory
extends MemoryBlackboard

# Compatibility adapter for legacy VS-02 call sites. AI-01 uses
# MemoryBlackboard as the single authoritative memory implementation.


func record(attacker: String, damage: float, position: Vector2, simulation_tick: int,
		max_threat: int, threat_per_damage: float) -> bool:
	return record_damage(attacker, damage, position, simulation_tick, max_threat, threat_per_damage)


func decay_to(simulation_tick: int, interval_ticks: int, amount: int) -> void:
	var empty_snapshot := {
		"observer_stable_id": "entity.compat",
		"simulation_tick": simulation_tick,
		"sector_id": "sector.compat",
		"observer_position": {"x": 0.0, "y": 0.0},
		"observer_hull_ratio": 1.0,
		"candidate_count": 0,
		"inspected_count": 0,
		"candidates": [],
	}
	advance(empty_snapshot, simulation_tick, interval_ticks, amount)
