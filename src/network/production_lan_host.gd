class_name ProductionLanHost
extends Node

signal authority_mutated(intent_type: String)

const MAX_PLAYERS := 2
const HOST_NAME := "SeaCraft LAN"

var _session: SessionHost
var _discovery: LanDiscoveryHost
var _sector: SectorRuntime
var _combat: CombatAuthority
var _inventory: InventoryState
var _host_id := ""
var _remote_id := ""
var _host_motor: ShipMotor
var _remote_motor: ShipMotor
var _definition_id := ""
var _discovery_error := OK
var _running := false


func start_host(game_port: int, discovery_port: int, advertised_address: String,
		host_id: String, host_motor: ShipMotor, remote_id: String, remote_motor: ShipMotor,
		sector: SectorRuntime, combat: CombatAuthority, loot: LootAuthority, inventory: InventoryState,
		market_id: String, market_center: Vector2, market_radius: float,
		ledger_state: Dictionary = {}, definition_id: String = "") -> Dictionary:
	if _running or sector == null or combat == null or loot == null or inventory == null:
		return {"accepted": false, "reason": "invalid_authority"}
	if not SectorIds.valid(host_id) or not SectorIds.valid(remote_id) or host_id == remote_id:
		return {"accepted": false, "reason": "invalid_players"}
	if host_motor == null or remote_motor == null or not host_motor.authority_enabled or not remote_motor.authority_enabled:
		return {"accepted": false, "reason": "invalid_motors"}
	if not sector.entity_position(host_id).is_finite() or not sector.entity_position(remote_id).is_finite():
		return {"accepted": false, "reason": "players_not_in_sector"}
	if not inventory.has_owner(host_id) or not inventory.has_owner(remote_id):
		return {"accepted": false, "reason": "inventory_owner_missing"}
	var market_spec := inventory.economy_market_cargo_spec(market_id)
	if market_spec.is_empty() or str(market_spec.get("sector", "")) != sector.sector_id:
		return {"accepted": false, "reason": "market_mismatch"}
	if not market_center.is_finite() or not sector.bounds.has_point(market_center):
		return {"accepted": false, "reason": "market_geometry_invalid"}

	_session = SessionHost.new()
	_session.name = "Session
	add_child(_session, true)
	if not ledger_state.is_empty() and not _session.restore_transaction_ledger(ledger_state):
		return _fail_start("invalid_transaction_ledger")
	if not _session.configure_player_motors({remote_id: remote_motor}):
		return _fail_start("player_configuration_failed")
	var start_error := _session.start(game_port)
	if start_error != OK:
		return _fail_start("session_start_failed", start_error)
	if not _session.bind_gameplay_authority(combat, loot) or not _session.bind_progression_authority(inventory):
		return _fail_start("authority_binding_failed")
	var guard := Prg05MarketAccessGuard.new(inventory)
	if not guard.bind_market(market_id, sector, market_center, market_radius) or not _session.bind_market_access_authority(guard):
		return _fail_start("market_authority_binding_failed")

	_sector = sector
	_combat = combat
	_inventory = inventory
	_host_id = host_id
	_remote_id = remote_id
	_host_motor = host_motor
	_remote_motor = remote_motor
	_definition_id = definition_id
	if not _session.spawn_network_entity(host_id, "player", sector.sector_id,
			_snapshot_entity(host_id, host_motor), definition_id, self, &"_snapshot_entity", [host_id, host_motor]):
		return _fail_start("host_replication_failed")
	if not _session.spawn_network_entity(remote_id, "player", sector.sector_id,
			_snapshot_entity(remote_id, remote_motor), definition_id, self, &"_snapshot_entity", [remote_id, remote_motor]):
		return _fail_start("guest_replication_failed")
	_session.intent_applied.connect(_on_intent_applied)

	_discovery_error = OK
	if discovery_port > 0:
		_discovery = LanDiscoveryHost.new()
		_discovery_error = _discovery.start(game_port, discovery_port, _session.session_id(), HOST_NAME,
			1, MAX_PLAYERS, advertised_address)
		if _discovery_error != OK:
			_discovery = null
	_running = true
	set_process(true)
	set_physics_process(true)
	return {
		"accepted": true,
		"reason": "",
		"session_id": _session.session_id(),
		"remote_player_id": remote_id,
		"discovery_active": _discovery != null and _discovery.is_active(),
		"discovery_error": _discovery_error,
	}


func stop_host() -> void:
	if _discovery != null:
		_discovery.stop()
	_discovery = null
	if _session != null:
		_session.stop()
		_session.queue_free()
	_session = null
	_running = false
	set_process(false)
	set_physics_process(false)


func is_running() -> bool:
	return _running and _session != null and _session.is_running()


func session_id() -> String:
	return _session.session_id() if _session != null and _session.is_running() else ""


func transaction_ledger_snapshot() -> Dictionary:
	return _session.transaction_ledger_snapshot() if _session != null else {"version": 1, "commit_sequence": 0, "entries": []}


func snapshot() -> Dictionary:
	if _session == null:
		return {"running": false}
	var state := _session.snapshot()
	state["discovery_active"] = _discovery != null and _discovery.is_active()
	state["discovery_error"] = _discovery_error
	state["remote_player_id"] = _remote_id
	return state


func _process(_delta: float) -> void:
	if not is_running() or _discovery == null:
		return
	var peers: Dictionary = _session.snapshot().get("peer_to_player", {})
	if not _discovery.update_counts(1 + peers.size(), MAX_PLAYERS):
		_discovery_error = ERR_INVALID_DATA
		_discovery.stop()
		_discovery = null
		return
	var error := _discovery.tick(Time.get_ticks_msec())
	if error != OK:
		_discovery_error = error
		_discovery.stop()
		_discovery = null


func _physics_process(_delta: float) -> void:
	if not is_running() or _sector == null or _remote_motor == null:
		return
	if _sector.move_entity(_remote_id, _remote_motor.global_position):
		return
	var indexed := _sector.entity_position(_remote_id)
	if indexed.is_finite():
		_remote_motor.global_position = indexed
		_remote_motor.cancel_target()


func _snapshot_entity(entity_id: String, motor: ShipMotor) -> Dictionary:
	if _sector == null or motor == null or not is_instance_valid(motor):
		return {}
	var state := motor.capture_save_motion()
	var result := {
		"sector_id": _sector.sector_id,
		"x": float(state["x"]),
		"y": float(state["y"]),
		"heading": float(state["heading"]),
		"hull_ratio": 1.0,
		"alive": true,
	}
	var combat_state := _combat.target_snapshot(entity_id) if _combat != null else {}
	if not combat_state.is_empty():
		var maximum := float(combat_state.get("max_hull", 0.0))
		var hull := float(combat_state.get("hull", 0.0))
		if maximum > 0.0 and is_finite(maximum) and is_finite(hull):
			result["hull_ratio"] = clampf(hull / maximum, 0.0, 1.0)
			result["alive"] = hull > 0.0
	return result


func _on_intent_applied(_peer_id: int, _player_id: String, intent_type: String, _sequence: int) -> void:
	authority_mutated.emit(intent_type)


func _fail_start(reason: String, error: int = FAILED) -> Dictionary:
	if _discovery != null:
		_discovery.stop()
	_discovery = null
	if _session != null:
		_session.stop()
		_session.queue_free()
	_session = null
	_running = false
	return {"accepted": false, "reason": reason, "error": error}
