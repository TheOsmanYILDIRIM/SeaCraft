class_name VerticalSliceScenario
extends Node

const SCENARIO_ID := "scenario.vs04.offline_first_playable.v1"
const MASTER_SEED := 424242
const PLAYER := FoundationSector.PLAYER
const NPC := "entity.vs02_sc03"
const NPC_START := Vector2(-520.0, 260.0)
const FIXED_DELTA := 1.0 / 60.0
const MAX_MOVE_FRAMES := 720
const MAX_AI_FRAMES := 1800

const NPC_TUNING := preload("res://src/data/ai/vs02_sc03_tuning.tres")
const LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")
const LOOT_ITEM := preload("res://src/data/items/vs03_salvage_scrap.tres")

var _authority: RefCounted
var _world: SectorWorld
var _streams: SeedStreams
var _player_motor: ShipMotor
var _npc_motor: ShipMotor
var _camera: GameplayCamera
var _combat: CombatAuthority
var _brain: NpcBrain
var _scheduler: AiDecisionScheduler
var _loot: LootAuthority
var _save_service: SaveService

var _save_directory := ""
var _phase := "new"
var _failure := ""
var _transitions: Array[int] = []
var _sunk_events := 0
var _drop_events := 0
var _pickup_events := 0
var _accepted_fires := 0
var _last_drop_id := ""
var _last_sunk_sequence := 0
var _spawn_count := 0
var _checkpoint_usec := 0
var _query_count := 0
var _targeting_inspected := 0
var _max_threat_observed := 0
var _perception_queries := 0
var _decision_count_before_reload := 0
var _pre_reload_ids: Dictionary = {}
var _post_reload_ids: Dictionary = {}
var _saved_rng: Dictionary = {}
var _saved_loot: Dictionary = {}
var _saved_inventory: Dictionary = {}
var _saved_player_checkpoint_motion: Dictionary = {}
var _initial_player_position := Vector2.ZERO
var _initial_npc_position := Vector2.ZERO
var _patrol_position := Vector2.ZERO
var _player_after_first_move := Vector2.ZERO
var _post_load_position := Vector2.ZERO
var _camera_position := Vector2.ZERO
var _reload_rejection := ""
var _range_rejection := ""
var _duplicate_sunk_blocked := false
var _duplicate_drop_blocked := false
var _duplicate_pickup_blocked := false
var _checkpoint_replayed := false
var _fresh_runtime := false
var _post_load_continued := false
var _presentation_unchanged := false
var _full_result: Dictionary = {}


func _ready() -> void:
	set_process(false)
	set_physics_process(false)


func _exit_tree() -> void:
	_remove_save_files()


func run_full() -> Dictionary:
	if not _full_result.is_empty():
		return _full_result.duplicate(true)
	_save_directory = "user://vs04-%s" % get_instance_id()
	_remove_save_files()
	_set_phase("offline_boot")
	if not _create_initial_runtime():
		return _fail("offline_runtime_create_failed")
	_initial_player_position = _player_motor.global_position
	_initial_npc_position = _npc_motor.global_position

	_set_phase("movement_camera_sector")
	if not _move_player_to(_initial_player_position + Vector2(80.0, 0.0), true):
		return _fail("initial_player_move_failed")
	_player_after_first_move = _player_motor.global_position
	_camera.recenter()
	_camera_position = _camera.global_position
	_patrol_position = _npc_motor.global_position
	if _patrol_position.distance_to(_initial_npc_position) <= 1.0 or _brain.state_id() != NpcBrain.State.PATROL:
		return _fail("npc_patrol_not_observed")
	var presentation_before := _authoritative_probe()
	_camera.pan_world_delta(Vector2(24.0, -12.0))
	_camera.zoom_by(1.1)
	_presentation_unchanged = presentation_before == _authoritative_probe()
	_camera.recenter()
	if not _presentation_unchanged:
		return _fail("presentation_mutated_authority")

	_set_phase("targeting_first_damage")
	if not _target_npc():
		return _fail("initial_target_acquisition_failed")
	var range_attempt := _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
	_range_rejection = str(range_attempt["reason"])
	if _range_rejection != "out_of_range":
		return _fail("range_guard_not_exercised_%s" % _range_rejection)
	if not _position_player_for_broadside():
		return _fail("first_broadside_position_failed")
	if not _target_npc():
		return _fail("target_acquisition_failed")
	var first := _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
	if not first["accepted"] or not first["hit"] or first["applied_hull_damage"] <= 0.0:
		return _fail("first_fire_failed")
	_accepted_fires += 1
	var immediate := _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
	_reload_rejection = str(immediate["reason"])
	if _reload_rejection != "reloading":
		return _fail("reload_guard_not_exercised")
	if not _advance_until_state(NpcBrain.State.ALERT, 120):
		return _fail("alert_not_observed")
	_max_threat_observed = maxi(_max_threat_observed, _brain.threat_score())
	_perception_queries = int(_brain.telemetry()["perception_query_count"])
	if _max_threat_observed <= 0 or _perception_queries <= 0:
		return _fail("threat_or_perception_not_observed")

	_set_phase("retreat_repair_resume")
	if not _position_player_for_broadside():
		return _fail("second_broadside_position_failed")
	if not _target_npc():
		return _fail("second_target_acquisition_failed")
	var second := _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
	if not second["accepted"] or second["remaining_hull"] > 35.0:
		return _fail("critical_damage_not_reached")
	_accepted_fires += 1
	if not _advance_until_state(NpcBrain.State.RETREAT, 120):
		return _fail("retreat_not_observed")
	if not _advance_until_state(NpcBrain.State.REPAIR, MAX_AI_FRAMES):
		return _fail("repair_not_observed")
	if not _advance_until_state(NpcBrain.State.RESUME, MAX_AI_FRAMES):
		return _fail("resume_not_observed")

	_set_phase("final_combat_sunk_loot")
	if not _position_player_for_broadside():
		return _fail("final_broadside_position_failed")
	if not _target_npc():
		return _fail("final_target_acquisition_failed")
	var sink_result: Dictionary = {}
	for volley in 3:
		sink_result = _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
		if not sink_result["accepted"]:
			return _fail("final_fire_failed_%s_%s" % [volley, sink_result["reason"]])
		_accepted_fires += 1
		if sink_result["sunk"]:
			break
		_step_frame(false, true)
	if not sink_result.get("sunk", false) or _sunk_events != 1 or _drop_events != 1:
		return _fail("single_sunk_drop_not_observed")
	if _last_drop_id.is_empty() or not _loot.has_drop(_last_drop_id):
		return _fail("loot_drop_missing")

	_set_phase("pickup")
	var drop_before := _loot.drop_snapshot(_last_drop_id)
	var drop_position := Vector2(float(drop_before["x"]), float(drop_before["y"]))
	if not _move_player_within(drop_position, LootAuthority.PICKUP_RADIUS * 0.75, false):
		return _fail("pickup_move_failed")
	var nearest := _loot.nearest_pickup(PLAYER)
	_query_count = _loot.last_query_inspected()
	if nearest != _last_drop_id:
		return _fail("bounded_pickup_query_failed")
	var picked := _loot.pickup(PLAYER, LootAuthority.pickup_intent(_last_drop_id))
	if not picked["accepted"]:
		return _fail("pickup_failed")
	_pickup_events += 1
	if _loot.inventory_quantity(LOOT_ITEM.stable_id) <= 0:
		return _fail("inventory_not_updated")

	_set_phase("checkpoint")
	var authority_state := {
		"scenario_id": SCENARIO_ID,
		"phase": "post_pickup",
		"npc_motion": _npc_motor.capture_save_motion(),
		"combat": _combat.snapshot_state(),
		"npc_ai": _brain.persistence_state(),
		"scheduler": _scheduler.snapshot_state(),
	}
	var snapshot := _save_service.create_snapshot(
		_world.active(), PLAYER, _player_motor, _streams, SaveSnapshot.LOCAL, "", _loot.snapshot_state(), authority_state)
	if snapshot.is_empty():
		return _fail("checkpoint_capture_failed")
	var player_data: Dictionary = snapshot["player"]
	_saved_player_checkpoint_motion = (player_data["motion"] as Dictionary).duplicate(true)
	var start := Time.get_ticks_usec()
	var saved := _save_service.save(snapshot)
	_checkpoint_usec = Time.get_ticks_usec() - start
	if saved["status"] != SaveService.OK_STATUS:
		return _fail("checkpoint_save_failed_%s" % saved["status"])
	var loaded := _save_service.load()
	if loaded["status"] != SaveService.OK_STATUS:
		return _fail("checkpoint_load_failed_%s" % loaded["status"])
	_saved_rng = _streams.snapshot_state()
	_saved_loot = _loot.snapshot_state()
	_saved_inventory = (_saved_loot["inventory"] as Dictionary).duplicate(true)
	_decision_count_before_reload = _brain.decision_count
	_pre_reload_ids = _runtime_ids()
	_clear_runtime_nodes()
	var loaded_snapshot: Dictionary = loaded["snapshot"]
	if not _rehydrate(loaded_snapshot):
		return _fail("rehydration_failed")
	_post_reload_ids = _runtime_ids()
	_fresh_runtime = _runtime_ids_differ()

	if _streams.snapshot_state() != _saved_rng:
		return _fail("rng_restore_mismatch")
	if _loot.snapshot_state() != _saved_loot:
		return _fail("loot_restore_mismatch")
	if _loot.snapshot_state()["inventory"] != _saved_inventory:
		return _fail("inventory_restore_mismatch")
	if _combat.hull(NPC) != 0.0 or _brain.persistence_state()["sunk"] != true:
		return _fail("npc_authority_restore_mismatch")
	_checkpoint_replayed = true
	print("VS04_CHECKPOINT_REPLAY_OK scenario=%s checkpoint_us=%s" % [SCENARIO_ID, _checkpoint_usec])

	_set_phase("post_load_duplicate_guards")
	var sunk_before := _sunk_events
	var rng_before := _streams.snapshot_state()
	var combat_duplicate := _combat.fire(PLAYER, _player_motor.current_heading(), CombatAuthority.fire_intent(NPC))
	_duplicate_sunk_blocked = not combat_duplicate["accepted"] and _sunk_events == sunk_before
	var duplicate_drop := _loot.on_ship_sunk(NPC, _last_sunk_sequence, _npc_motor.global_position)
	_duplicate_drop_blocked = duplicate_drop.is_empty() and _streams.snapshot_state() == rng_before
	var quantity_before := _loot.inventory_quantity(LOOT_ITEM.stable_id)
	var duplicate_pickup := _loot.pickup(PLAYER, LootAuthority.pickup_intent(_last_drop_id))
	_duplicate_pickup_blocked = duplicate_pickup["reason"] == "already_claimed" and _loot.inventory_quantity(LOOT_ITEM.stable_id) == quantity_before
	if not _duplicate_sunk_blocked or not _duplicate_drop_blocked or not _duplicate_pickup_blocked:
		return _fail("duplicate_guard_failed")

	_set_phase("post_load_continue")
	var checkpoint_position := Vector2(
		float(_saved_player_checkpoint_motion["x"]), float(_saved_player_checkpoint_motion["y"]))
	var continue_target := checkpoint_position + Vector2(32.0, 0.0)
	if not _move_player_to(continue_target, false):
		return _fail("post_load_movement_failed")
	_post_load_position = _player_motor.global_position
	_camera.recenter()
	_camera_position = _camera.global_position
	_post_load_continued = _post_load_position.distance_to(checkpoint_position) > 1.0
	if not _post_load_continued:
		return _fail("post_load_did_not_continue")

	_set_phase("complete")
	print("VS04_SCENARIO_COMPLETE scenario=%s decisions=%s spawns=%s sector_count=1 entity_count=2 pickup_query=%s" % [
		SCENARIO_ID, _decision_count_before_reload, _spawn_count, _query_count])
	return _finish(true)


func deterministic_digest() -> Dictionary:
	var result := run_full()
	var result_transitions: Array = result.get("transitions", [])
	var result_inventory: Dictionary = result.get("inventory", {})
	var result_rng: Dictionary = result.get("rng", {})
	var result_loot: Dictionary = result.get("loot", {})
	return {
		"scenario_id": result.get("scenario_id", ""),
		"completed": result.get("completed", false),
		"transitions": result_transitions.duplicate(true),
		"sunk_events": result.get("sunk_events", 0),
		"drop_events": result.get("drop_events", 0),
		"pickup_events": result.get("pickup_events", 0),
		"accepted_fires": result.get("accepted_fires", 0),
		"inventory": result_inventory.duplicate(true),
		"rng": result_rng.duplicate(true),
		"loot": result_loot.duplicate(true),
		"post_load_x": result.get("post_load_x", 0.0),
		"post_load_y": result.get("post_load_y", 0.0),
	}


func reset_scenario() -> void:
	_clear_runtime_nodes()
	_remove_save_files()
	_phase = "reset"
	_failure = ""
	_transitions.clear()
	_sunk_events = 0
	_drop_events = 0
	_pickup_events = 0
	_accepted_fires = 0
	_last_drop_id = ""
	_last_sunk_sequence = 0
	_spawn_count = 0
	_checkpoint_usec = 0
	_query_count = 0
	_targeting_inspected = 0
	_max_threat_observed = 0
	_perception_queries = 0
	_decision_count_before_reload = 0
	_pre_reload_ids.clear()
	_post_reload_ids.clear()
	_saved_rng.clear()
	_saved_loot.clear()
	_saved_inventory.clear()
	_saved_player_checkpoint_motion.clear()
	_full_result.clear()


func stale_state_empty() -> bool:
	return _world == null and _combat == null and _brain == null and _loot == null and _player_motor == null and _npc_motor == null


func _create_initial_runtime() -> bool:
	_authority = RefCounted.new()
	_world = SectorWorld.new(FoundationSector.graph(), _authority)
	_streams = SeedStreams.new(MASTER_SEED)
	if not _world.activate_initial(_authority, FoundationSector.ID, FoundationSector.ENTRY, PLAYER):
		return false
	_player_motor = _new_motor(_world.active().entity_position(PLAYER))
	_npc_motor = _new_motor(NPC_START)
	if _player_motor == null or _npc_motor == null:
		return false
	if not _world.active().register_entity(NPC, NPC_START):
		return false
	_spawn_count += 2
	return _wire_runtime(false, {}, SaveSnapshot.empty_loot_state())


func _rehydrate(dto: Dictionary) -> bool:
	var authority_state := SaveSnapshot.authoritative_state(dto)
	if authority_state.get("scenario_id", "") != SCENARIO_ID or authority_state.get("phase", "") != "post_pickup":
		return false
	_authority = RefCounted.new()
	_world = SectorWorld.new(FoundationSector.graph(), _authority)
	_streams = SeedStreams.new(1)
	_player_motor = _new_motor(Vector2.ZERO)
	if _player_motor == null:
		return false
	var error := SaveSnapshot.restore(dto, _world, _authority, PLAYER, _player_motor, _streams)
	if not error.is_empty():
		return false
	var npc_motion_value: Variant = authority_state.get("npc_motion")
	if not ShipMotor.valid_save_motion(npc_motion_value):
		return false
	var npc_motion: Dictionary = npc_motion_value
	_npc_motor = _new_motor(Vector2(float(npc_motion["x"]), float(npc_motion["y"])))
	if _npc_motor == null or not _npc_motor.restore_save_motion(npc_motion):
		return false
	if not _world.active().register_entity(NPC, _npc_motor.global_position):
		return false
	_spawn_count += 2
	return _wire_runtime(true, authority_state, SaveSnapshot.loot_state(dto))


func _wire_runtime(restoring: bool, authority_state: Dictionary, loot_state: Dictionary) -> bool:
	_combat = CombatAuthority.new(_world.active(), _streams, 60)
	var weapon := _weapon()
	if not _combat.register(PLAYER, "faction.player", 100.0, weapon):
		return false
	if not _combat.register(NPC, "faction.hostile", 100.0):
		return false
	_loot = LootAuthority.new(_world.active(), _streams, LOOT_TABLE, LOOT_ITEM, true)
	var ammo_id := "ammo.vs04_round"
	var stock := {CoreCombatRules.ROUND: 16, CoreCombatRules.NPC_REPAIR: 24}
	if not _loot.bind_inventory_owner(PLAYER, {CoreCombatRules.ROUND: 16}) or not _loot.reserve_inventory_item(NPC, CoreCombatRules.NPC_REPAIR) or not _combat.attach_inventory(_loot):
		return false
	if restoring and not _loot.restore_state(loot_state):
		return false
	_loot.initialize_missing_stock(stock)
	if not _combat.register_ammo(CoreCombatRules.ammo(ammo_id, CoreCombatRules.ROUND, CoreCombatRules.NEUTRAL, 1.0)) or not _combat.mount_ammo(PLAYER, PackedStringArray([ammo_id])):
		return false
	if restoring and not _combat.restore_state(authority_state.get("combat")):
		return false

	_brain = NpcBrain.create(NPC, _world.active(), _combat, _npc_motor, NPC_TUNING, true)
	if _brain == null:
		return false
	if restoring and not _brain.restore_state(authority_state.get("npc_ai")):
		return false

	_scheduler = AiDecisionScheduler.new(8)
	if restoring and not _scheduler.restore_state(authority_state.get("scheduler")):
		return false
	if not _scheduler.register_brain(_brain, NPC_TUNING.decision_interval_ticks, 0):
		return false

	_save_service = SaveService.new(_save_directory)
	_camera = GameplayCamera.new()
	add_child(_camera)
	_camera.set_process(false)
	_camera.set_world_limits(_world.active().bounds)
	_camera.set_follow_target(_player_motor)
	_camera.recenter()

	_combat.hull_damaged.connect(_on_hull_damaged)
	_combat.ship_sunk.connect(_on_ship_sunk)
	_loot.drop_created.connect(_on_drop_created)
	_record_ai_state()
	return true


func _new_motor(position: Vector2) -> ShipMotor:
	var motor := ShipMotor.new()
	motor.set_physics_process(false)
	motor.global_position = position
	add_child(motor)
	return motor


func _weapon() -> WeaponDefinition:
	var weapon := WeaponDefinition.new()
	weapon.stable_id = "weapon.vs04_cannon"
	weapon.base_damage = 40.0
	weapon.min_range_meters = 0.0
	weapon.range_meters = 300.0
	weapon.reload_seconds = 0.01
	weapon.accuracy = 1.0
	weapon.crit_chance = 0.0
	weapon.crit_multiplier = 1.5
	weapon.broadside_half_arc_degrees = 85.0
	return weapon


func _position_player_for_broadside() -> bool:
	var npc_position := _world.active().entity_position(NPC)
	if not npc_position.is_finite():
		return false
	var bounds := _world.active().bounds
	var y_offset := -120.0 if npc_position.y >= bounds.get_center().y else 120.0
	var firing := npc_position + Vector2(0.0, y_offset)
	firing.y = clampf(firing.y, bounds.position.y + 32.0, bounds.end.y - 32.0)
	var staging := firing + Vector2(-140.0, 0.0)
	if staging.x < bounds.position.x + 32.0:
		staging = firing + Vector2(140.0, 0.0)
	if staging.x > bounds.end.x - 32.0:
		return false
	if not _move_player_to(staging, false) or not _move_player_to(firing, false):
		return false
	var offset := npc_position - _player_motor.global_position
	return CombatAuthority.broadside(_player_motor.current_heading(), offset, 85.0) != 0


func _target_npc() -> bool:
	var npc_position := _world.active().entity_position(NPC)
	var acquired := _combat.acquire(PLAYER, npc_position, 32.0)
	_targeting_inspected = maxi(_targeting_inspected, _combat.acquisition_inspected())
	return acquired == NPC and _combat.select(PLAYER, NPC)


func _move_player_to(target: Vector2, advance_ai: bool) -> bool:
	if not _player_motor.apply_authoritative_command(GameplayCommand.move_to_world_position(target)):
		return false
	for _frame in MAX_MOVE_FRAMES:
		_step_frame(advance_ai, true)
		if not _player_motor.has_target():
			return true
	return false


func _move_player_within(target: Vector2, radius: float, advance_ai: bool) -> bool:
	if not target.is_finite() or not is_finite(radius) or radius <= 0.0:
		return false
	if not _player_motor.apply_authoritative_command(GameplayCommand.move_to_world_position(target)):
		return false
	for _frame in MAX_MOVE_FRAMES:
		_step_frame(advance_ai, true)
		if _player_motor.global_position.distance_to(target) <= radius:
			_player_motor.apply_authoritative_command(GameplayCommand.cancel())
			return true
	return false


func _advance_until_state(state_id: int, max_frames: int) -> bool:
	if _brain.state_id() == state_id:
		return true
	for _frame in max_frames:
		_step_frame(true, false)
		if _brain.state_id() == state_id:
			return true
	return false


func _step_frame(advance_ai: bool, step_player: bool) -> void:
	_combat.advance_tick()
	if advance_ai:
		_scheduler.advance_physics_tick()
	if step_player:
		_player_motor.step_authoritative(FIXED_DELTA, false)
		_world.active().move_entity(PLAYER, _player_motor.global_position)
	if advance_ai and _combat.is_alive(NPC):
		_npc_motor.step_authoritative(FIXED_DELTA, false)
		_world.active().move_entity(NPC, _npc_motor.global_position)
	_record_ai_state()


func _record_ai_state() -> void:
	if _brain == null:
		return
	var state := _brain.state_id()
	if _transitions.is_empty() or _transitions.back() != state:
		_transitions.append(state)


func _on_hull_damaged(target_id: String, attacker_id: String, amount: float, _remaining: float, sequence_id: int) -> void:
	if target_id == NPC and _brain != null:
		_brain.record_combat_damage(attacker_id, amount, sequence_id, _scheduler.current_tick())
		_max_threat_observed = maxi(_max_threat_observed, _brain.threat_score())


func _on_ship_sunk(entity_id: String, sequence_id: int) -> void:
	if entity_id != NPC:
		return
	_sunk_events += 1
	_last_sunk_sequence = sequence_id
	if _brain != null:
		_brain.mark_sunk()
	var drop := _loot.on_ship_sunk(entity_id, sequence_id, _world.active().entity_position(entity_id))
	if not drop.is_empty():
		_last_drop_id = str(drop["drop_id"])


func _on_drop_created(drop: Dictionary) -> void:
	_drop_events += 1
	_last_drop_id = str(drop.get("drop_id", _last_drop_id))


func _authoritative_probe() -> Dictionary:
	return {
		"player_motion": _player_motor.capture_save_motion(),
		"player_sector_position": _world.active().entity_position(PLAYER),
		"npc_position": _world.active().entity_position(NPC),
		"npc_ai": _brain.persistence_state(),
		"combat": _combat.snapshot_state(),
		"loot": _loot.snapshot_state(),
		"rng": _streams.snapshot_state(),
	}


func _runtime_ids() -> Dictionary:
	return {
		"world": _world.get_instance_id(),
		"player_motor": _player_motor.get_instance_id(),
		"npc_motor": _npc_motor.get_instance_id(),
		"combat": _combat.get_instance_id(),
		"brain": _brain.get_instance_id(),
		"loot": _loot.get_instance_id(),
		"camera": _camera.get_instance_id(),
	}


func _runtime_ids_differ() -> bool:
	for key in _pre_reload_ids:
		if _pre_reload_ids[key] == _post_reload_ids.get(key, _pre_reload_ids[key]):
			return false
	return true


func _clear_runtime_nodes() -> void:
	for node in [_camera, _player_motor, _npc_motor]:
		if node != null and is_instance_valid(node):
			node.free()
	_camera = null
	_player_motor = null
	_npc_motor = null
	_combat = null
	_brain = null
	_scheduler = null
	_loot = null
	_world = null
	_streams = null
	_authority = null
	_save_service = null


func _remove_save_files() -> void:
	if _save_directory.is_empty() or not DirAccess.dir_exists_absolute(_save_directory):
		return
	for name in [SaveService.PRIMARY, SaveService.TEMP, SaveService.BACKUP]:
		var path := _save_directory.path_join(name)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(_save_directory)


func _set_phase(value: String) -> void:
	_phase = value
	var decisions := _scheduler.decision_count if _scheduler != null else 0
	print("VS04 phase=%s scenario=%s decisions=%s spawns=%s" % [value, SCENARIO_ID, decisions, _spawn_count])


func _fail(reason: String) -> Dictionary:
	_failure = reason
	print("VS04_FAILURE scenario=%s phase=%s reason=%s" % [SCENARIO_ID, _phase, reason])
	return _finish(false)


func _finish(completed: bool) -> Dictionary:
	var inventory: Dictionary = _saved_inventory.duplicate(true)
	var rng: Dictionary = _saved_rng.duplicate(true)
	var loot_state: Dictionary = _saved_loot.duplicate(true)
	if _loot != null:
		var current_loot := _loot.snapshot_state()
		inventory = (current_loot["inventory"] as Dictionary).duplicate(true)
		loot_state = current_loot.duplicate(true)
	if _streams != null:
		rng = _streams.snapshot_state().duplicate(true)
	var camera_error := INF
	if _camera != null and _player_motor != null:
		camera_error = _camera.global_position.distance_to(_player_motor.global_position)
	_full_result = {
		"scenario_id": SCENARIO_ID,
		"completed": completed,
		"failure": _failure,
		"phase": _phase,
		"offline": true,
		"sector_id": _world.active().sector_id if _world != null and _world.active() != null else FoundationSector.ID,
		"initial_player_x": _initial_player_position.x,
		"initial_player_y": _initial_player_position.y,
		"player_first_move_distance": _initial_player_position.distance_to(_player_after_first_move),
		"npc_patrol_distance": _initial_npc_position.distance_to(_patrol_position),
		"transitions": _transitions.duplicate(),
		"max_threat": _max_threat_observed,
		"perception_queries": _perception_queries,
		"targeting_inspected": _targeting_inspected,
		"range_rejection": _range_rejection,
		"reload_rejection": _reload_rejection,
		"accepted_fires": _accepted_fires,
		"sunk_events": _sunk_events,
		"drop_events": _drop_events,
		"pickup_events": _pickup_events,
		"last_drop_id": _last_drop_id,
		"checkpoint_replayed": _checkpoint_replayed,
		"checkpoint_usec": _checkpoint_usec,
		"fresh_runtime": _fresh_runtime,
		"duplicate_sunk_blocked": _duplicate_sunk_blocked,
		"duplicate_drop_blocked": _duplicate_drop_blocked,
		"duplicate_pickup_blocked": _duplicate_pickup_blocked,
		"post_load_continued": _post_load_continued,
		"presentation_unchanged": _presentation_unchanged,
		"camera_error": camera_error,
		"pickup_query_count": _query_count,
		"decision_count": _decision_count_before_reload,
		"spawn_count": _spawn_count,
		"inventory": inventory,
		"rng": rng,
		"loot": loot_state,
		"post_load_x": _post_load_position.x,
		"post_load_y": _post_load_position.y,
	}
	return _full_result.duplicate(true)
