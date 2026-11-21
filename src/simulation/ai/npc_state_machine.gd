class_name NpcStateMachine
extends RefCounted

const PATROL := 0
const ALERT := 1
const RETREAT := 2
const REPAIR := 3
const RESUME := 4

const _ALLOWED := {
	PATROL: [ALERT, RETREAT],
	ALERT: [PATROL, RETREAT],
	RETREAT: [REPAIR, ALERT],
	REPAIR: [RETREAT, ALERT, RESUME],
	RESUME: [PATROL, ALERT, RETREAT],
}


static func transition(previous_state: int, next_state: int, reason: String, simulation_tick: int) -> Dictionary:
	if previous_state < PATROL or previous_state > RESUME or next_state < PATROL or next_state > RESUME:
		return {}
	if simulation_tick < 0 or reason.is_empty() or reason.length() > 128:
		return {}
	if previous_state == next_state:
		return {
			"accepted": true,
			"changed": false,
			"previous_state": previous_state,
			"next_state": next_state,
			"reason": reason,
			"tick": simulation_tick,
		}
	var allowed: Array = _ALLOWED.get(previous_state, [])
	if not allowed.has(next_state):
		return {
			"accepted": false,
			"changed": false,
			"previous_state": previous_state,
			"next_state": next_state,
			"reason": reason,
			"tick": simulation_tick,
		}
	return {
		"accepted": true,
		"changed": true,
		"previous_state": previous_state,
		"next_state": next_state,
		"reason": reason,
		"tick": simulation_tick,
	}
