extends Node2D

const BOOT_MARKER := "SeaCraft bootstrap ready"

const CHECKPOINT_INTERVAL_MS := 20000
const PRACTICE_TARGET := "entity.vs02_sc03"
const PRACTICE_POSITION := Vector2(-520, 260)
const NPC_TUNING := preload("res://src/data/ai/vs02_sc03_tuning.tres")
const VS03_LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")
const VS03_LOOT_ITEM := preload("res://src/data/items/vs03_salvage_scrap.tres")

var _combat: CombatAuthority
var _practice_marker: Polygon2D
var _target_ring: Line2D
var _fire_control: CombatFireButton
var _npc_motor: ShipMotor
var _npc_brain: NpcBrain
var _npc_presenter: NpcStatePresenter
var _ai_scheduler := AiDecisionScheduler.new(8)
var _last_npc_sequence := -1
var _loot: LootAuthority
var _world_objects: WorldObjectAuthority
var _loot_marker: Polygon2D
var _pickup_control: LootPickupButton
var _harpoon_control: CombatFireButton
var _nearby_drop_id := ""
var _pending_loot_state: Dictionary = {}
var _pending_combat: Dictionary = {}
var _core_buttons: Array[CombatFireButton] = []
const ROUND_AMMO := "ammo.core_round"
const EMBER_AMMO := "ammo.core_ember"
const CORE_STOCK := {CoreCombatRules.ROUND: 40, CoreCombatRules.EMBER: 20, CoreCombatRules.STOWED: 8}
const NPC_STOCK := {CoreCombatRules.NPC_REPAIR: 24}

var _authority := RefCounted.new()
var _world: SectorWorld
var _streams := SeedStreams.new()
var _save_service := SaveService.new()
var _session_id := ""
var _last_attempt_ms := 0
var _last_position := Vector2.ZERO
var _last_velocity := Vector2.ZERO
var _last_heading := 0.0
var _observed_target := false
var save_status: Dictionary = {}

@onready var _ship_motor: ShipMotor = $ShipMotor


func _ready() -> void:
	_world = SectorWorld.new(FoundationSector.graph(), _authority)
	save_status = _save_service.load()
	match save_status["status"]:
		SaveService.MISSING:
			if not _world.activate_initial(_authority, FoundationSector.ID, FoundationSector.ENTRY, FoundationSector.PLAYER):
				_block_boot({"status": "missing_initial_sector"})
				return
			var anchor := _world.active().anchor(FoundationSector.ENTRY)
			_ship_motor.global_position = anchor.position
			_ship_motor.rotation = anchor.heading
			_ship_motor.cancel_target()
		SaveService.OK_STATUS, SaveService.RECOVERED:
			var dto: Dictionary = save_status["snapshot"]
			if dto["ownership"]["kind"] != SaveSnapshot.LOCAL:
				_block_boot({"status": "unsupported_owner"})
				return
			var error := SaveSnapshot.restore(dto, _world, _authority, FoundationSector.PLAYER, _ship_motor, _streams)
			if not error.is_empty():
				_block_boot({"status": error})
				return
			_session_id = dto["ownership"]["session_id"]
			_pending_loot_state = SaveSnapshot.loot_state(dto)
			_pending_combat = SaveSnapshot.authoritative_state(dto)
			if save_status["status"] == SaveService.RECOVERED:
				_save_service.mark_dirty()
				push_warning("SeaCraft restored a backup checkpoint")
		_:
			_block_boot(save_status)
			return
	_last_position = _ship_motor.global_position
	_last_velocity = _ship_motor.velocity
	_last_heading = _ship_motor.rotation
	_observed_target = _ship_motor.has_target()
	_last_attempt_ms = Time.get_ticks_msec()
	_ship_motor.collision_layer = FoundationSector.SHIP_LAYER
	_ship_motor.collision_mask = FoundationSector.COAST_LAYER
	_ship_motor.process_physics_priority = -1
	_build_sector_geometry(_world.active())
	_setup_combat(_world.active())
	if _fire_control == null:
		_block_boot({"status": "combat_setup_failed"})
		return
	print(BOOT_MARKER)


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	if _combat != null:
		_combat.advance_tick()
	var position_now := _ship_motor.global_position
	_world.active().move_entity(FoundationSector.PLAYER, position_now)
	if _npc_motor != null and _combat != null and _combat.is_alive(PRACTICE_TARGET):
		_world.active().move_entity(PRACTICE_TARGET, _npc_motor.global_position)
	if _npc_brain != null:
		_ai_scheduler.advance_physics_tick()
		_refresh_npc_state()
	if _loot != null:
		_refresh_loot_control()
	if position_now != _last_position or _ship_motor.velocity != _last_velocity or _ship_motor.rotation != _last_heading or _ship_motor.has_target() != _observed_target:
		_save_service.mark_dirty()
	_last_position = position_now
	_last_velocity = _ship_motor.velocity
	_last_heading = _ship_motor.rotation
	_observed_target = _ship_motor.has_target()


func _on_gameplay_command(command: Dictionary) -> void:
	if active_sector() == null or command.get("domain") != GameplayCommand.DOMAIN_GAMEPLAY:
		return
	if _combat != null:
		match command.get("type"):
			CombatAuthority.SELECT:
				var target_id: String = command["target_id"]
				if target_id.is_empty():
					_combat.clear_target(FoundationSector.PLAYER)
				else:
					_combat.select(FoundationSector.PLAYER, target_id)
				_refresh_combat_indicator()
				return
			CombatAuthority.FIRE:
				var result := _combat.fire(FoundationSector.PLAYER, _ship_motor.current_heading(), command)
				if result["accepted"]:
					# The encounter stream belongs to the existing FND-06 checkpoint.
					_save_service.mark_dirty()
				_refresh_combat_indicator()
				return
			CombatAuthority.HARPOON:
				var result := _combat.harpoon(FoundationSector.PLAYER, command)
				if result["accepted"]:
					_save_service.mark_dirty()
				_refresh_combat_indicator()
				return
			GameplayCommand.CANCEL:
				_combat.clear_target(FoundationSector.PLAYER)
				_refresh_combat_indicator()
	if _ship_motor.apply_authoritative_command(command):
		_save_service.mark_dirty()


func _setup_combat(sector: SectorRuntime) -> void:
	_combat = CombatAuthority.new(sector, _streams, Engine.physics_ticks_per_second)
	var cannon := WeaponDefinition.new()
	cannon.stable_id = "weapon.vs01_practice_cannon"
	cannon.base_damage = 25.0
	cannon.min_range_meters = 35.0
	cannon.range_meters = 360.0
	cannon.reload_seconds = 1.25
	cannon.accuracy = 0.92
	cannon.crit_chance = 0.15
	if not sector.navigation.accessible(PRACTICE_POSITION) or not sector.register_entity(PRACTICE_TARGET, PRACTICE_POSITION):
		push_error("VS-02 NPC placement failed")
		return
	if not _combat.register(FoundationSector.PLAYER, "faction.player", 100.0, cannon) or not _combat.register(PRACTICE_TARGET, "faction.practice_hostile", 75.0, null, 4.0, 0.05):
		push_error("VS-02 combat roster setup failed")
		return

	_npc_motor = ShipMotor.new()
	_npc_motor.name = "Vs02NpcMotor"
	_npc_motor.collision_layer = FoundationSector.SHIP_LAYER
	_npc_motor.collision_mask = FoundationSector.COAST_LAYER
	_npc_motor.process_physics_priority = -1
	add_child(_npc_motor)
	_npc_motor.global_position = PRACTICE_POSITION

	_practice_marker = Polygon2D.new()
	_practice_marker.polygon = PackedVector2Array([
		Vector2(-22, 14), Vector2(17, 11), Vector2(27, 0), Vector2(17, -11), Vector2(-22, -14), Vector2(-14, 0),
	])
	_practice_marker.color = Color(0.78, 0.42, 0.28)
	_npc_motor.add_child(_practice_marker)

	_target_ring = Line2D.new()
	_target_ring.width = 3.5
	_target_ring.default_color = Color(1.0, 0.9, 0.2)
	for i in range(25):
		_target_ring.add_point(Vector2.from_angle(TAU * float(i) / 24.0) * 31.0)
	_target_ring.hide()
	_practice_marker.add_child(_target_ring)

	_npc_presenter = NpcStatePresenter.new()
	_npc_motor.add_child(_npc_presenter)
	_npc_brain = NpcBrain.create(PRACTICE_TARGET, sector, _combat, _npc_motor, NPC_TUNING as NpcAiTuning, true)
	if _npc_brain == null:
		push_error("VS-02 AI setup failed")
		return

	var input: GameplayInputController = $InputController
	input.combat_target_at = _target_at
	_loot = LootAuthority.new(sector, _streams, VS03_LOOT_TABLE as LootTable, VS03_LOOT_ITEM as ItemDefinition, true)
	if not _loot.bind_inventory_owner(FoundationSector.PLAYER, CORE_STOCK) or not _loot.reserve_inventory_item(PRACTICE_TARGET, CoreCombatRules.NPC_REPAIR):
		return
	if not _loot.restore_state(_pending_loot_state if not _pending_loot_state.is_empty() else SaveSnapshot.empty_loot_state()):
		push_error("VS-03 loot restore failed")
		return
	_loot.initialize_missing_stock(CORE_STOCK)
	_loot.initialize_missing_stock(NPC_STOCK)
	if not _combat.attach_inventory(_loot) or not _combat.register_ammo(CoreCombatRules.ammo(ROUND_AMMO, CoreCombatRules.ROUND, CoreCombatRules.NEUTRAL, 1.0)) or not _combat.register_ammo(CoreCombatRules.ammo(EMBER_AMMO, CoreCombatRules.EMBER, CoreCombatRules.FIRE, 1.15, "status.scorched")):
		return
	if not _combat.mount_ammo(FoundationSector.PLAYER, PackedStringArray([ROUND_AMMO, EMBER_AMMO])) or not _combat.configure_repair(FoundationSector.PLAYER, 20.0, 180, CoreCombatRules.STOWED):
		return
	var harpoon := HarpoonProfile.new()
	harpoon.stable_id = "harpoon.core02_debug"
	harpoon.display_name = "Debug Harpoon"
	harpoon.base_damage = 18.0
	harpoon.range_meters = 320.0
	harpoon.reload_seconds = 1.25
	harpoon.element_id = CoreCombatRules.NEUTRAL
	if not _combat.mount_harpoon(FoundationSector.PLAYER, harpoon):
		return
	_world_objects = WorldObjectAuthority.new(sector, _loot, _combat, VS03_LOOT_TABLE as LootTable, FoundationSector.PLAYER, true)
	if _pending_combat.has("world") and not _world_objects.restore_state(_pending_combat["world"]):
		return
	if not _combat.configure_defense(FoundationSector.PLAYER, 0.15, {}, 8.0, 8.0) or not _combat.configure_defense(PRACTICE_TARGET, 0.1, {CoreCombatRules.FIRE: -0.2}, 0.0, 6.0):
		return
	if _pending_combat.has("combat") and not _combat.restore_state(_pending_combat["combat"]):
		return
	if _pending_combat.has("npc_motion"):
		var motion: Variant = _pending_combat["npc_motion"]
		if not ShipMotor.valid_save_motion(motion) or not sector.move_entity(PRACTICE_TARGET, Vector2(motion["x"], motion["y"])):
			return
		_npc_motor.restore_save_motion(motion)
	if _pending_combat.has("npc_ai") and not _npc_brain.restore_state(_pending_combat["npc_ai"]):
		return
	if _pending_combat.has("scheduler") and not _ai_scheduler.restore_state(_pending_combat["scheduler"]):
		return
	if not _ai_scheduler.register_brain(_npc_brain, (NPC_TUNING as NpcAiTuning).decision_interval_ticks, 0):
		return
	if not _combat.is_alive(PRACTICE_TARGET):
		_npc_brain.mark_sunk()
		_npc_motor.set_physics_process(false)
		_practice_marker.hide()
		_npc_presenter.hide()
	_loot.drop_created.connect(_on_loot_drop_created)
	_loot.drop_claimed.connect(_on_loot_drop_claimed)

	_loot_marker = Polygon2D.new()
	_loot_marker.polygon = PackedVector2Array([Vector2(0, -14), Vector2(14, 0), Vector2(0, 14), Vector2(-14, 0)])
	_loot_marker.color = Color(0.86, 0.72, 0.26)
	_loot_marker.hide()
	add_child(_loot_marker)
	_sync_loot_marker_from_state()

	_fire_control = CombatFireButton.new()
	_fire_control.text = "ATEŞ"
	_fire_control.add_theme_font_size_override("font_size", 42)
	_fire_control.size = Vector2(224.0, 132.0)
	_fire_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_fire_control.focus_mode = Control.FOCUS_NONE
	_fire_control.touch_captured.connect(input.reset_touch)
	_fire_control.pressed.connect(_on_fire_pressed)
	$UI.add_child(_fire_control)
	_harpoon_control = CombatFireButton.new()
	_harpoon_control.text = "ZIPKIN"
	_harpoon_control.add_theme_font_size_override("font_size", 36)
	_harpoon_control.size = Vector2(224.0, 132.0)
	_harpoon_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_harpoon_control.focus_mode = Control.FOCUS_NONE
	_harpoon_control.touch_captured.connect(input.reset_touch)
	_harpoon_control.pressed.connect(_on_harpoon_pressed)
	$UI.add_child(_harpoon_control)
	_pickup_control = LootPickupButton.new()
	_pickup_control.text = "TOPLA"
	_pickup_control.add_theme_font_size_override("font_size", 38)
	_pickup_control.size = Vector2(224.0, 132.0)
	_pickup_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_pickup_control.focus_mode = Control.FOCUS_NONE
	_pickup_control.touch_captured.connect(input.reset_touch)
	_pickup_control.pressed.connect(_on_pickup_pressed)
	_pickup_control.hide()
	$UI.add_child(_pickup_control)
	for spec: Array in [["YUVARLAK", CombatAuthority.AMMO_SELECT, ROUND_AMMO], ["KOR", CombatAuthority.AMMO_SELECT, EMBER_AMMO], ["ONAR", CombatAuthority.REPAIR, ""], ["BORDALA", CombatAuthority.BOARD, ""], ["TAKVİYE", CombatAuthority.ACTION, CoreCombatRules.ACTION]]:
		var button := CombatFireButton.new()
		button.text = spec[0]
		button.size = Vector2(126, 64)
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_filter = Control.MOUSE_FILTER_STOP
		button.touch_captured.connect(input.reset_touch)
		button.pressed.connect(_on_core_pressed.bind(button, str(spec[0]), str(spec[1]), str(spec[2])))
		$UI.add_child(button)
		_core_buttons.append(button)
	get_viewport().size_changed.connect(_layout_fire_control)
	_layout_fire_control()
	_combat.hull_damaged.connect(_on_hull_damaged)
	_combat.ship_sunk.connect(_on_ship_sunk)
	_refresh_npc_state()
	_refresh_combat_indicator()


func _target_at(world_position: Vector2) -> String:
	var zoom: float = $GameplayCamera.zoom.x
	var radius := clampf(36.0 / maxf(zoom, 0.01), 24.0, 96.0)
	return _combat.acquire(FoundationSector.PLAYER, world_position, radius)


func _layout_fire_control() -> void:
	var safe := get_viewport_rect()
	if OS.has_feature("android"):
		var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		var pixels := window.intersection(DisplayServer.get_display_safe_area())
		if pixels.has_area():
			pixels.position -= window.position
			safe = safe.intersection(SafeAreaMath.display_safe_area_to_logical(Rect2(pixels), Vector2(1280, 720), Vector2(window.size)))
	_fire_control.position = safe.end - _fire_control.size - Vector2(36.0, 36.0)
	if _harpoon_control != null:
		_harpoon_control.position = Vector2(_fire_control.position.x - _harpoon_control.size.x - 28.0, _fire_control.position.y)
	if _pickup_control != null:
		var right_edge := _harpoon_control.position.x if _harpoon_control != null else _fire_control.position.x
		_pickup_control.position = Vector2(right_edge - _pickup_control.size.x - 28.0, _fire_control.position.y)
	for index in _core_buttons.size():
		var button := _core_buttons[index]
		button.position = Vector2(safe.position.x + 24.0 + float(index % 2) * 134.0, safe.end.y - 32.0 - (floorf(float(index) * 0.5) + 1.0) * 70.0)


func _on_core_pressed(button: CombatFireButton, label: String, kind: String, id: String) -> void:
	var target := _combat.locked_target(FoundationSector.PLAYER) if kind == CombatAuthority.BOARD else id
	var result := _combat.transact(FoundationSector.PLAYER, CombatAuthority.intent(kind, target))
	button.text = label + (" ✓" if result["success"] else " ×")
	if result["accepted"]:
		_save_service.mark_dirty()


func _on_fire_pressed() -> void:
	var input: GameplayInputController = $InputController
	input.emit_fire_intent(_combat.locked_target(FoundationSector.PLAYER))


func _on_harpoon_pressed() -> void:
	if _combat == null:
		return
	_on_gameplay_command(CombatAuthority.harpoon_intent(_combat.locked_target(FoundationSector.PLAYER)))


func _on_hull_damaged(target_id: String, attacker_id: String, amount: float, _remaining_hull: float, sequence_id: int) -> void:
	if target_id == PRACTICE_TARGET and _npc_brain != null:
		_npc_brain.record_combat_damage(attacker_id, amount, sequence_id, _ai_scheduler.current_tick())


func _on_ship_sunk(id: String, sequence: int) -> void:
	if id == PRACTICE_TARGET:
		if _loot != null and _npc_motor != null:
			var drop := _loot.on_ship_sunk(id, sequence, _npc_motor.global_position)
			if not drop.is_empty():
				_save_service.mark_dirty()
		if _npc_brain != null:
			_npc_brain.mark_sunk()
		if _npc_motor != null:
			_npc_motor.cancel_target()
			_npc_motor.set_physics_process(false)
		if _practice_marker != null:
			_practice_marker.hide()
		if _npc_presenter != null:
			_npc_presenter.hide()


func _on_loot_drop_created(drop: Dictionary) -> void:
	if _loot_marker != null:
		_loot_marker.position = Vector2(drop["x"], drop["y"])
		_loot_marker.show()


func _on_loot_drop_claimed(_drop_id: String, _item_id: String, _quantity: int) -> void:
	if _loot_marker != null:
		_loot_marker.hide()
	_save_service.mark_dirty()


func _on_pickup_pressed() -> void:
	if _loot == null or _nearby_drop_id.is_empty():
		return
	var result: Dictionary
	if _loot.has_drop(_nearby_drop_id):
		result = _loot.pickup(FoundationSector.PLAYER, LootAuthority.pickup_intent(_nearby_drop_id))
	elif _world_objects != null and _world_objects.has_object(_nearby_drop_id):
		result = _world_objects.pickup(FoundationSector.PLAYER, _nearby_drop_id)
	else:
		return
	if result["accepted"]:
		_save_service.mark_dirty()
		_refresh_loot_control()


func _refresh_loot_control() -> void:
	if _pickup_control == null:
		return
	_nearby_drop_id = _loot.nearest_pickup(FoundationSector.PLAYER)
	if _nearby_drop_id.is_empty() and _world_objects != null:
		_nearby_drop_id = _world_objects.nearest_pickup(FoundationSector.PLAYER)
	_pickup_control.visible = not _nearby_drop_id.is_empty()
	_pickup_control.disabled = _nearby_drop_id.is_empty()


func _sync_loot_marker_from_state() -> void:
	if _loot == null or _loot_marker == null:
		return
	var state := _loot.snapshot_state()
	if state["drops"].is_empty():
		_loot_marker.hide()
		return
	var drop: Dictionary = state["drops"][0]
	_loot_marker.position = Vector2(drop["x"], drop["y"])
	_loot_marker.show()


func _refresh_npc_state() -> void:
	if _npc_brain == null or _npc_presenter == null:
		return
	var snapshot := _npc_brain.snapshot()
	var sequence: int = snapshot["decision_sequence"]
	if sequence == _last_npc_sequence:
		return
	_last_npc_sequence = sequence
	_npc_presenter.apply_snapshot(snapshot)


func _refresh_combat_indicator() -> void:
	if _target_ring == null:
		return
	var locked_id := _combat.locked_target(FoundationSector.PLAYER)
	var locked := locked_id == PRACTICE_TARGET
	_target_ring.visible = locked
	_fire_control.disabled = locked_id.is_empty()
	if _harpoon_control != null:
		_harpoon_control.disabled = locked_id.is_empty() or TargetingService.weapon_rejection(TargetingService.HARPOON, _combat.target_class(locked_id)) != ""


func _block_boot(reason: Dictionary) -> void:
	save_status = reason
	push_warning("SeaCraft checkpoint unavailable: %s" % reason)
	set_process(false)
	set_physics_process(false)
	_ship_motor.set_physics_process(false)


func _process(_delta: float) -> void:
	if _save_service.is_dirty() and Time.get_ticks_msec() - _last_attempt_ms >= CHECKPOINT_INTERVAL_MS:
		_flush_checkpoint()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# App background is the last synchronous opportunity on Android.
		_flush_checkpoint()


# Explicit/manual, critical gameplay and committed sector transitions use this
# hook; defer snapshot and I/O out of the caller's physics or input callback.
func request_checkpoint() -> void:
	if active_sector() != null:
		_save_service.mark_dirty()
		_flush_checkpoint.call_deferred()


func _flush_checkpoint() -> void:
	var sector := active_sector()
	if sector == null or not _save_service.is_dirty():
		return
	_last_attempt_ms = Time.get_ticks_msec()
	var loot_state := _loot.snapshot_state() if _loot != null else SaveSnapshot.empty_loot_state()
	var authority_state: Dictionary = {}
	if _combat != null and _npc_brain != null:
		authority_state = {
			"combat": _combat.snapshot_state(),
			"npc_motion": _npc_motor.capture_save_motion(),
			"npc_ai": _npc_brain.persistence_state(),
			"scheduler": _ai_scheduler.snapshot_state(),
			"world": _world_objects.snapshot_state() if _world_objects != null else {"objects": [], "claimed_ids": [], "processed_spawns": []},
		}
	var dto := _save_service.create_snapshot(sector, FoundationSector.PLAYER, _ship_motor, _streams, SaveSnapshot.LOCAL, _session_id, loot_state, authority_state)
	save_status = _save_service.save_if_dirty(dto)



func _build_sector_geometry(sector: SectorRuntime) -> void:
	var geometry := Node2D.new()
	geometry.name = "ActiveSectorGeometry"
	geometry.z_index = -1
	add_child(geometry)
	_add_rectangle(geometry, sector.bounds, Color(0.035, 0.095, 0.115))
	for obstacle in sector.navigation.obstacle_rects():
		_add_rectangle(geometry, obstacle, Color(0.23, 0.26, 0.23))
		_add_coast(geometry, obstacle)
	var low := sector.bounds.position
	var high := sector.bounds.end
	var size_world := sector.bounds.size
	const WALL := 64.0
	_add_coast(geometry, Rect2(low.x - WALL, low.y - WALL, size_world.x + 2.0 * WALL, WALL))
	_add_coast(geometry, Rect2(low.x - WALL, high.y, size_world.x + 2.0 * WALL, WALL))
	_add_coast(geometry, Rect2(low.x - WALL, low.y, WALL, size_world.y))
	_add_coast(geometry, Rect2(high.x, low.y, WALL, size_world.y))


static func _add_rectangle(parent: Node2D, rect: Rect2, tint: Color) -> void:
	var polygon := Polygon2D.new()
	polygon.color = tint
	polygon.polygon = PackedVector2Array([
		rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y),
	])
	parent.add_child(polygon)


static func _add_coast(parent: Node2D, rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = FoundationSector.COAST_LAYER
	body.collision_mask = 0
	body.position = rect.get_center()
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	body.add_child(collider)
	parent.add_child(body)
