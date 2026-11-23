extends Node2D

const BOOT_MARKER := "SeaCraft bootstrap ready"

const CHECKPOINT_INTERVAL_MS := 20000
const PRACTICE_TARGET := "entity.vs02_sc03"
const PRACTICE_POSITION := Vector2(-520, 260)
const NPC_TUNING := preload("res://src/data/ai/vs02_sc03_tuning.tres")
const NPC_ROLE := preload("res://src/data/ai/roles/trader.tres")
const VS03_LOOT_TABLE := preload("res://src/data/loot/vs03_sc03_loot_table.tres")
const VS03_LOOT_ITEM := preload("res://src/data/items/vs03_salvage_scrap.tres")
const PLAYER_SHIP_DEF := preload("res://src/data/content/ship_foundation_player.tres")
const PRACTICE_SHIP_DEF := preload("res://src/data/content/ship_vs02_practice.tres")
const PRACTICE_CANNON := preload("res://src/data/content/weapon_vs01_practice_cannon.tres")
const ROUND_AMMO_PROFILE := preload("res://src/data/content/ammo_core_round.tres")
const EMBER_AMMO_PROFILE := preload("res://src/data/content/ammo_core_ember.tres")
const HARPOON_PROFILE := preload("res://src/data/content/harpoon_core02_debug.tres")
const PILOT_MARKET_ID := "market.haven.salvage"

var _combat: CombatAuthority
var _relations := FactionRelationResolver.new(true)
var _fleet_coordinator := FleetCoordinator.new(true)
var _dock_authority := DockAuthority.new(true)
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
var _map_overlay: SectorMapOverlay
var _map_button: Button
var _world_map_open := false
var _market_panel: Prg05MarketPanel
var _market_button: Button
var _market_open := false
var _market_transaction_sequence := 0
var _sector_geometry: Node2D
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

const ANDROID_TRACE := preload("res://src/presentation/input/android_input_trace.gd")
var _diag_physics_left := 0
var _diag_physics_origin := Vector2.ZERO

@onready var _ship_motor: ShipMotor = $ShipMotor


func _ready() -> void:
	if ANDROID_TRACE.enabled():
		ANDROID_TRACE.attach(self)
	if ContentManifest.current_hash().is_empty():
		_block_boot({"status": "content_registry_unavailable"})
		return
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
	var brains: Array[NpcBrain] = []
	if _npc_brain != null:
		brains.append(_npc_brain)
	if not _world.bind_runtime(SectorRuntimeBinding.new(_combat, _loot, _world_objects, brains)):
		_block_boot({"status": "sector_runtime_binding_failed"})
		return
	_setup_map_ui()
	_setup_market_ui()
	_setup_visual_pilot()
	ANDROID_TRACE.record("bootstrap", "world ready")
	($InputController as GameplayInputController).ui_hit_test = _ui_captures_touch
	print(BOOT_MARKER)


const VISUAL_PILOT := preload("res://src/presentation/ship/visual_pilot.gd")
var _pilot_water: Polygon2D
var _pilot_water_enabled := false
var _pilot_comparison: Sprite2D


func _setup_visual_pilot() -> void:
	var player_marker: Polygon2D = $BoatMarker
	if VISUAL_PILOT.mount_atlas(player_marker, "SC-02", 104.0) != null:
		player_marker.color.a = 0.0
	if _practice_marker != null and VISUAL_PILOT.mount_atlas(_practice_marker, "SC-03", 132.0) != null:
		# Keep the marker node and its child target ring/visibility contract.
		_practice_marker.color.a = 0.0
	_pilot_comparison = VISUAL_PILOT.mount_atlas(self, "SC-07", 120.0)
	if _pilot_comparison != null:
		_pilot_comparison.frame = 2
		_pilot_comparison.set_process(false)
		_pilot_comparison.visible = active_sector().sector_id == FoundationSector.ID
		_pilot_comparison.position = _ship_motor.position + Vector2(190.0, 75.0)
	var button := Button.new()
	button.name = "PilotWaterButton"
	button.text = "Deniz: mevcut"
	button.size = Vector2(170.0, 48.0)
	$UI.add_child(button)
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	button.offset_left = -85.0
	button.offset_right = 85.0
	button.offset_top = 24.0
	button.offset_bottom = 72.0
	button.pressed.connect(func() -> void:
		_pilot_water_enabled = not _pilot_water_enabled
		_apply_pilot_water()
		button.text = "Deniz: 2D önizleme" if _pilot_water_enabled else "Deniz: mevcut"
	)


func _apply_pilot_water() -> void:
	if is_instance_valid(_pilot_water):
		_pilot_water.material = VISUAL_PILOT.water_material() if _pilot_water_enabled else null


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	if _combat != null:
		_combat.advance_tick()
	var position_now := _ship_motor.global_position
	if _diag_physics_left > 0:
		ANDROID_TRACE.record("physics", "frame=%s pos=%s displacement=%s velocity=%s target=%s collisions=%s" % [
			Engine.get_physics_frames(), position_now, position_now - _diag_physics_origin,
			_ship_motor.velocity, _ship_motor.has_target(), _ship_motor.get_slide_collision_count()])
		_diag_physics_left -= 1
	_world.active().move_entity(FoundationSector.PLAYER, position_now)
	if _map_overlay != null:
		_map_overlay.set_player_world_position(position_now)
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
		if active_sector() == null:
			ANDROID_TRACE.record("bootstrap", "command blocked: no active sector")
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
	var accepted := _ship_motor.apply_authoritative_command(command)
	if ANDROID_TRACE.enabled() and command.get("type") == GameplayCommand.MOVE_TO_WORLD_POSITION:
		_diag_physics_origin = _ship_motor.global_position
		ANDROID_TRACE.record("ShipMotor", "accepted=%s authority=%s physics_enabled=%s pos=%s target=%s" % [
			accepted, _ship_motor.authority_enabled, _ship_motor.is_physics_processing(),
			_diag_physics_origin, _ship_motor.has_target()])
		_diag_physics_left = 12
	if accepted:
		_save_service.mark_dirty()


func _setup_combat(sector: SectorRuntime) -> void:
	_combat = CombatAuthority.new(sector, _streams, Engine.physics_ticks_per_second)
	if _pending_combat.has("relations"):
		if not _relations.restore_state(_pending_combat["relations"]):
			return
	else:
		_relations.set_relation((PLAYER_SHIP_DEF as ShipDefinition).faction_id, (PRACTICE_SHIP_DEF as ShipDefinition).faction_id, FactionRelationResolver.HOSTILE)
	if not _combat.bind_relation_resolver(_relations):
		return
	var cannon := PRACTICE_CANNON as WeaponDefinition
	var practice_active := sector.sector_id == FoundationSector.ID
	var practice_position := sector.entity_position(PRACTICE_TARGET)
	if practice_active and not practice_position.is_finite():
		if not sector.navigation.accessible(PRACTICE_POSITION) or not sector.register_entity(PRACTICE_TARGET, PRACTICE_POSITION):
			push_error("VS-02 NPC placement failed")
			return
		practice_position = PRACTICE_POSITION
	if not _combat.register(FoundationSector.PLAYER, (PLAYER_SHIP_DEF as ShipDefinition).faction_id, (PLAYER_SHIP_DEF as ShipDefinition).base_hull_hp, cannon):
		push_error("VS-02 player combat roster setup failed")
		return
	if practice_active:
		if not _combat.register(PRACTICE_TARGET, (PRACTICE_SHIP_DEF as ShipDefinition).faction_id, (PRACTICE_SHIP_DEF as ShipDefinition).base_hull_hp, cannon, 4.0, 0.05):
			push_error("VS-02 combat roster setup failed")
			return
	elif not _combat.register_dormant(PRACTICE_TARGET, (PRACTICE_SHIP_DEF as ShipDefinition).faction_id, (PRACTICE_SHIP_DEF as ShipDefinition).base_hull_hp, FoundationSector.ID, PRACTICE_POSITION):
		push_error("VS-02 dormant combat roster setup failed")
		return

	_npc_motor = ShipMotor.new()
	_npc_motor.name = "Vs02NpcMotor"
	_npc_motor.collision_layer = FoundationSector.SHIP_LAYER
	_npc_motor.collision_mask = FoundationSector.COAST_LAYER
	_npc_motor.process_physics_priority = -1
	add_child(_npc_motor)
	_npc_motor.global_position = practice_position if practice_position.is_finite() else PRACTICE_POSITION

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
	_npc_brain = NpcBrain.create(PRACTICE_TARGET, sector, _combat, _npc_motor, NPC_TUNING as NpcAiTuning, true, NPC_ROLE as NpcRoleProfile)
	if _npc_brain == null:
		push_error("VS-02 AI setup failed")
		return

	var input: GameplayInputController = $InputController
	input.combat_target_at = _target_at
	_loot = LootAuthority.new(sector, _streams, VS03_LOOT_TABLE as LootTable, VS03_LOOT_ITEM as ItemDefinition, true)
	if not _loot.bind_inventory_owner(FoundationSector.PLAYER, CORE_STOCK) or not _loot.reserve_inventory_item(PRACTICE_TARGET, CoreCombatRules.NPC_REPAIR):
		return
	if not _loot.inventory_state().configure_prg02(_streams):
		push_error("PRG-02 progression authority setup failed")
		return
	if not _loot.inventory_state().configure_prg03():
		push_error("PRG-03 progression authority setup failed")
		return
	if not _loot.inventory_state().configure_prg04():
		push_error("PRG-04 quest authority setup failed")
		return
	if not _loot.inventory_state().configure_prg05():
		push_error("PRG-05 economy setup failed")
		return
	# Register the canonical pilot factions before restoring reputation saves.
	if not _loot.inventory_state().register_economy_faction((PLAYER_SHIP_DEF as ShipDefinition).faction_id) or not _loot.inventory_state().register_economy_faction((PRACTICE_SHIP_DEF as ShipDefinition).faction_id):
		push_error("PRG-05 faction registration failed")
		return
	if not _loot.inventory_state().register_economy_market(PILOT_MARKET_ID, (PLAYER_SHIP_DEF as ShipDefinition).faction_id,
			(VS03_LOOT_ITEM as ItemDefinition).stable_id, FoundationSector.HAVEN_ID, 10, 8, 20):
		push_error("PRG-05 pilot market registration failed")
		return
	if not _loot.restore_state(_pending_loot_state if not _pending_loot_state.is_empty() else SaveSnapshot.empty_loot_state()):
		push_error("VS-03 loot restore failed")
		return
	if _pending_combat.has("progression") and not _loot.inventory_state().restore_progression(_pending_combat["progression"]):
		push_error("Progression restore failed")
		return
	_loot.initialize_missing_stock(CORE_STOCK)
	_loot.initialize_missing_stock(NPC_STOCK)
	if not _loot.inventory_state().enable_economy_diplomacy(FoundationSector.PLAYER) or not _combat.bind_economy_authority(_loot.inventory_state()):
		push_error("PRG-05 combat diplomacy integration failed")
		return
	if not _combat.attach_inventory(_loot) or not _combat.register_ammo(ROUND_AMMO_PROFILE as AmmoProfile) or not _combat.register_ammo(EMBER_AMMO_PROFILE as AmmoProfile):
		return
	if not _combat.mount_ammo(FoundationSector.PLAYER, PackedStringArray([ROUND_AMMO, EMBER_AMMO])) or not _combat.configure_repair(FoundationSector.PLAYER, 20.0, 180, CoreCombatRules.STOWED):
		return
	if not _combat.mount_harpoon(FoundationSector.PLAYER, HARPOON_PROFILE as HarpoonProfile):
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
		if not ShipMotor.valid_save_motion(motion):
			return
		if practice_active and not sector.move_entity(PRACTICE_TARGET, Vector2(motion["x"], motion["y"])):
			return
		_npc_motor.restore_save_motion(motion)
	if _pending_combat.has("npc_ai") and not _npc_brain.restore_state(_pending_combat["npc_ai"]):
		return
	if _pending_combat.has("scheduler") and not _ai_scheduler.restore_state(_pending_combat["scheduler"]):
		return
	if _pending_combat.has("fleet") and not _fleet_coordinator.restore_state(_pending_combat["fleet"]):
		return
	if _pending_combat.has("docks") and not _dock_authority.restore_state(_pending_combat["docks"]):
		return
	if not _ai_scheduler.register_brain(_npc_brain, (NPC_TUNING as NpcAiTuning).decision_interval_ticks, 0):
		return
	if _combat.hull(PRACTICE_TARGET) <= 0.0:
		_npc_brain.mark_sunk()
	_sync_sector_local_presentation()
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
	_show_core_feedback(button, label, bool(result["success"]))
	if result["accepted"]:
		_save_service.mark_dirty()


func _show_core_feedback(button: CombatFireButton, label: String, success: bool) -> void:
	var token := Time.get_ticks_msec()
	button.set_meta("feedback_token", token)
	button.text = label + (" ✓" if success else " ×")
	await get_tree().create_timer(0.75).timeout
	if is_instance_valid(button) and int(button.get_meta("feedback_token", -1)) == token:
		button.text = label


func _ui_captures_touch(screen_position: Vector2) -> bool:
	# Keep the debug copy button reachable without giving its entire layer world-input ownership.
	if ANDROID_TRACE.enabled():
		var button: Button = ANDROID_TRACE.copy_button
		if is_instance_valid(button) and button.is_visible_in_tree() and button.get_global_rect().has_point(screen_position):
			ANDROID_TRACE.record("ui_hit", "path=%s" % button.get_path())
			return true
	return _control_tree_captures_touch($UI, screen_position)


func _control_tree_captures_touch(node: Node, screen_position: Vector2) -> bool:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			# Local `visible` is not enough: a visible child under a hidden
			# panel still reports visible=true. Hidden UI subtrees must not block
			# gameplay touch, pan or zoom.
			if not control.is_visible_in_tree():
				continue
			if control.mouse_filter != Control.MOUSE_FILTER_IGNORE and control.get_global_rect().has_point(screen_position):
				if ANDROID_TRACE.enabled():
					ANDROID_TRACE.record("ui_hit", "path=%s rect=%s filter=%s" % [control.get_path(), control.get_global_rect(), control.mouse_filter])
				return true
		if _control_tree_captures_touch(child, screen_position):
			return true
	return false


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
	ANDROID_TRACE.record("bootstrap", "boot blocked: %s" % reason.get("status", "unknown"))
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
	var authority_state: Dictionary = {"sector_world": _world.snapshot_state(FoundationSector.PLAYER)}
	if _loot != null:
		authority_state["progression"] = _loot.inventory_state().progression_snapshot()
	if _combat != null and _npc_brain != null:
		var combat_state := _combat.snapshot_state()
		var npc_state := _npc_brain.persistence_state()
		authority_state.merge({
			"combat": combat_state,
			"npc_motion": _npc_motor.capture_save_motion(),
			"npc_ai": npc_state,
			"scheduler": _ai_scheduler.snapshot_state(),
			"fleet": _fleet_coordinator.snapshot_state(),
			"docks": _dock_authority.snapshot_state(),
			"relations": _relations.snapshot_state(),
			"world": _world_objects.snapshot_state() if _world_objects != null else {"objects": [], "claimed_ids": [], "processed_spawns": []},
		}, true)
		var entity_index := _capture_entity_index(combat_state, npc_state, loot_state)
		if entity_index.is_empty():
			save_status = {"status": "entity_index_failed"}
			return
		authority_state["entity_index"] = entity_index
	var dto := _save_service.create_snapshot(sector, FoundationSector.PLAYER, _ship_motor, _streams, SaveSnapshot.LOCAL, _session_id, loot_state, authority_state)
	save_status = _save_service.save_if_dirty(dto)



func request_sector_transition(gate_id: String) -> Dictionary:
	if _world == null or active_sector() == null:
		return {"accepted": false, "reason": "no_active_sector", "from_sector": "", "to_sector": "", "gate_id": gate_id, "entry_anchor": ""}
	_world.active().move_entity(FoundationSector.PLAYER, _ship_motor.global_position)
	var result := _world.request_transition(_authority, FoundationSector.PLAYER, gate_id)
	if not result["accepted"]:
		return result
	_ship_motor.global_position = _world.active().entity_position(FoundationSector.PLAYER)
	_ship_motor.cancel_target()
	_build_sector_geometry(_world.active())
	_sync_sector_local_presentation()
	if _map_overlay != null:
		_map_overlay.configure_minimap(_world.active().presentation_snapshot(), _ship_motor.global_position)
	_save_service.mark_dirty()
	request_checkpoint()
	_refresh_market_access()
	return result


func _sync_sector_local_presentation() -> void:
	if _npc_motor == null or _combat == null:
		return
	var active_now := _combat.is_alive(PRACTICE_TARGET)
	_npc_motor.set_physics_process(active_now)
	if active_now:
		var position := _world.active().entity_position(PRACTICE_TARGET)
		if position.is_finite():
			_npc_motor.global_position = position
		_practice_marker.show()
		_npc_presenter.show()
	else:
		_practice_marker.hide()
		_npc_presenter.hide()



func _setup_market_ui() -> void:
	_market_panel = Prg05MarketPanel.new()
	_market_panel.name = "Prg05MarketPanel"
	_market_panel.hide()
	_market_panel.market_intent_requested.connect(_on_market_intent)
	_market_panel.close_requested.connect(_toggle_market)
	$UI.add_child(_market_panel)
	_market_button = Button.new()
	_market_button.name = "Prg05MarketButton"
	_market_button.text = "PAZAR"
	_market_button.size = Vector2(150, 64)
	_market_button.focus_mode = Control.FOCUS_NONE
	_market_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_market_button.pressed.connect(_toggle_market)
	$UI.add_child(_market_button)
	get_viewport().size_changed.connect(_layout_market_ui)
	_layout_market_ui()
	_refresh_market_access()


func _layout_market_ui() -> void:
	if _market_button == null or _market_panel == null:
		return
	var bounds := get_viewport_rect()
	var safe_margin := 24.0
	_market_button.position = Vector2(maxf(safe_margin, bounds.size.x - _market_button.size.x - safe_margin), 98.0)
	_market_panel.size = Vector2(minf(730.0, maxf(320.0, bounds.size.x - 2.0 * safe_margin)),
		minf(490.0, maxf(350.0, bounds.size.y - 2.0 * safe_margin)))
	_market_panel.position = (bounds.size - _market_panel.size) * 0.5


func _refresh_market_access() -> void:
	if _market_button == null or _market_panel == null:
		return
	var at_haven := active_sector() != null and active_sector().sector_id == FoundationSector.HAVEN_ID
	_market_button.disabled = not at_haven
	if not at_haven and _market_open:
		_market_open = false
		_market_panel.hide()
		_market_button.text = "PAZAR"
		($InputController as GameplayInputController).set_world_input_blocked(_world_map_open or _market_open)
	if _market_open:
		_refresh_market_quote()


func _toggle_market() -> void:
	if _market_panel == null or _market_button == null:
		return
	if not _market_open and (active_sector() == null or active_sector().sector_id != FoundationSector.HAVEN_ID):
		return
	if not _market_open and _world_map_open:
		_toggle_world_map()
	_market_open = not _market_open
	_market_panel.visible = _market_open
	_market_button.text = "KAPAT" if _market_open else "PAZAR"
	($InputController as GameplayInputController).set_world_input_blocked(_world_map_open or _market_open)
	if _market_open:
		_refresh_market_quote()


func _refresh_market_quote() -> void:
	if _market_panel == null or _loot == null:
		return
	var inventory := _loot.inventory_state()
	_market_panel.consume_snapshot(PILOT_MARKET_ID, inventory.economy_quote(FoundationSector.PLAYER, PILOT_MARKET_ID),
		inventory.economy_balance(FoundationSector.PLAYER))


func _on_market_intent(operation: String, payload: Dictionary) -> void:
	# Offline/local host adapter. Never trust the panel for stock, price or identity.
	if not _market_open or _loot == null or active_sector() == null or active_sector().sector_id != FoundationSector.HAVEN_ID:
		return
	if operation not in [InventoryState.OP_MARKET_BUY, InventoryState.OP_MARKET_SELL]:
		return
	if payload.size() != 2 or payload.get("market_id") != PILOT_MARKET_ID or typeof(payload.get("quantity")) != TYPE_INT:
		return
	var quantity := int(payload["quantity"])
	if quantity < 1 or quantity > Prg05MarketPanel.MAX_ORDER:
		return
	_market_transaction_sequence += 1
	var transaction_id := "txn.market.ui.%d.%06d" % [int(Time.get_unix_time_from_system()), _market_transaction_sequence]
	var result := _loot.inventory_state().execute_transaction(FoundationSector.PLAYER, transaction_id, operation,
		{"market_id": PILOT_MARKET_ID, "quantity": quantity})
	if result.get("accepted", false):
		_save_service.mark_dirty()
	_refresh_market_quote()
	_market_panel.show_result(result)


func _setup_map_ui() -> void:
	_map_overlay = SectorMapOverlay.new()
	_map_overlay.name = "Core03MapOverlay"
	_map_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	$UI.add_child(_map_overlay)
	_map_overlay.configure_minimap(_world.active().presentation_snapshot(), _ship_motor.global_position)
	_map_button = Button.new()
	_map_button.name = "Core03MapButton"
	_map_button.text = "HARİTA"
	_map_button.focus_mode = Control.FOCUS_NONE
	_map_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_map_button.pressed.connect(_toggle_world_map)
	$UI.add_child(_map_button)
	get_viewport().size_changed.connect(_layout_map_ui)
	_layout_map_ui()


func _toggle_world_map() -> void:
	if _market_open:
		_market_open = false
		_market_panel.hide()
		_market_button.text = "PAZAR"
	_world_map_open = not _world_map_open
	var input: GameplayInputController = $InputController
	input.set_world_input_blocked(_world_map_open or _market_open)
	if _world_map_open:
		_map_overlay.configure_world(_world.world_graph_snapshot(), _world.active().sector_id)
	else:
		_map_overlay.configure_minimap(_world.active().presentation_snapshot(), _ship_motor.global_position)
	_map_overlay.set_world_view(_world_map_open)
	_map_button.text = "KAPAT" if _world_map_open else "HARİTA"
	_layout_map_ui()


func _layout_map_ui() -> void:
	if _map_overlay == null or _map_button == null:
		return
	var viewport_size := get_viewport_rect().size
	const SAFE_MARGIN := 24.0
	if _world_map_open:
		_map_overlay.position = Vector2(SAFE_MARGIN, SAFE_MARGIN)
		_map_overlay.size = (viewport_size - Vector2(SAFE_MARGIN * 2.0, SAFE_MARGIN * 2.0)).max(Vector2(160, 120))
	else:
		_map_overlay.position = Vector2(SAFE_MARGIN, SAFE_MARGIN)
		_map_overlay.size = Vector2(260, 150).min(viewport_size - Vector2(SAFE_MARGIN * 2.0, SAFE_MARGIN * 2.0))
	_map_button.size = Vector2(150, 58)
	_map_button.position = Vector2(maxf(SAFE_MARGIN, viewport_size.x - _map_button.size.x - SAFE_MARGIN), SAFE_MARGIN)


func _build_sector_geometry(sector: SectorRuntime) -> void:
	if _sector_geometry != null:
		_sector_geometry.queue_free()
	var geometry := Node2D.new()
	geometry.name = "ActiveSectorGeometry"
	geometry.z_index = -1
	_sector_geometry = geometry
	add_child(geometry)
	_add_rectangle(geometry, sector.bounds, Color(0.035, 0.095, 0.115))
	_pilot_water = geometry.get_child(0) as Polygon2D
	_apply_pilot_water()
	if is_instance_valid(_pilot_comparison):
		_pilot_comparison.visible = sector.sector_id == FoundationSector.ID
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


func _capture_entity_index(combat_state: Dictionary, npc_state: Dictionary, loot_state: Dictionary) -> Dictionary:
	var registry := ContentManifest.registry()
	if registry == null:
		return {}
	var combatants: Dictionary = {}
	for raw in combat_state.get("combatants", []):
		if raw is Dictionary and raw.get("entity_id") is String:
			combatants[raw["entity_id"]] = raw
	if not combatants.has(FoundationSector.PLAYER) or not combatants.has(PRACTICE_TARGET):
		return {}
	var player_combat: Dictionary = combatants[FoundationSector.PLAYER]
	var npc_combat: Dictionary = combatants[PRACTICE_TARGET]
	var player_motion := _ship_motor.capture_save_motion()
	var npc_motion := _npc_motor.capture_save_motion()
	var player_ready: Dictionary = player_combat.get("core", {}).get("ready", {})
	var player_cooldowns := {
		"cannon_ready_tick": int(player_combat.get("battery", {}).get("ready_tick", 0)),
		"harpoon_ready_tick": int(player_combat.get("core", {}).get("harpoon_ready_tick", 0)),
	}
	for key in player_ready:
		player_cooldowns[str(key)] = int(player_ready[key])
	var npc_cooldowns := {
		"next_repair_tick": maxi(0, int(npc_state.get("next_repair_tick", 0))),
		"last_decision_tick": maxi(0, int(npc_state.get("last_decision_tick", 0))),
	}
	var npc_destination: Dictionary = npc_state.get("destination", {"x": npc_motion["x"], "y": npc_motion["y"]})
	var records: Array = [
		{
			"instance_id": FoundationSector.PLAYER,
			"definition_id": (PLAYER_SHIP_DEF as ShipDefinition).stable_id,
			"entity_kind": "ship",
			"sector_id": str(player_combat["sector_id"]),
			"position": {"x": float(player_motion["x"]), "y": float(player_motion["y"])},
			"motion": {"heading": float(player_motion["heading"]), "vx": float(player_motion["vx"]), "vy": float(player_motion["vy"])},
			"health": float(player_combat["hull"]),
			"alive": float(player_combat["hull"]) > 0.0,
			"route": {},
			"cooldowns": player_cooldowns,
			"inventory": (loot_state.get("inventory", {}) as Dictionary).duplicate(true),
			"payload": {"content_refs": [PRACTICE_CANNON.stable_id, ROUND_AMMO_PROFILE.stable_id, EMBER_AMMO_PROFILE.stable_id, HARPOON_PROFILE.stable_id]},
		},
		{
			"instance_id": PRACTICE_TARGET,
			"definition_id": (PRACTICE_SHIP_DEF as ShipDefinition).stable_id,
			"entity_kind": "npc_ship",
			"sector_id": str(npc_combat["sector_id"]),
			"position": {"x": float(npc_combat["position"]["x"]), "y": float(npc_combat["position"]["y"])},
			"motion": {"heading": float(npc_motion["heading"]), "vx": float(npc_motion["vx"]), "vy": float(npc_motion["vy"])},
			"health": float(npc_combat["hull"]),
			"alive": float(npc_combat["hull"]) > 0.0 and not bool(npc_state.get("sunk", false)),
			"route": {"goal": npc_destination.duplicate(true), "patrol_index": int(npc_state["patrol_index"]), "intent_id": int(npc_state["intent_id"])},
			"cooldowns": npc_cooldowns,
			"inventory": {},
			"payload": {"content_refs": [(NPC_ROLE as NpcRoleProfile).stable_id]},
		},
	]
	return PersistentEntityIndex.build(records, registry)
