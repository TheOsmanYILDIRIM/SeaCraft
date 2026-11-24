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
const PILOT_MARKET_ANCHOR := "anchor.haven_center"
const PILOT_MARKET_RADIUS := 128.0
const PILOT_BOUNTY_ID := "bounty.foundation.practice"
const PILOT_BOUNTY_REWARD := 80
const PILOT_CONVOY_ID := "entity.haven.supply_convoy"
const PILOT_CONVOY_FLEET := "fleet.haven.supply_convoy"
const PILOT_CONVOY_JOB := "job.haven.supply_convoy.v1"
const PILOT_CONVOY_CARGO := 4
const LAN_REMOTE_PLAYER_ID := "player.lan.guest"
const LAN_GUEST_MAX_SLOTS := 64
const LAN_GUEST_MAX_WEIGHT := 1000000.0

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
var _bounty_bridge: Prg05BountyCombatBridge
var _economy_world: WorldSimulationAuthority
var _economy_runner: Prg05EconomyWorldRunner
var _market_anchor: SectorAnchor
var _mode_button: Button
var _surface_sprite: Sprite2D
var _lan_host: ProductionLanHost
var _lan_remote_motor: ShipMotor
var _lan_saved_state: Dictionary = {}
var _lan_menu: PanelContainer
var _lan_button: Button
var _lan_status: Label
var _lan_travel: Button
var _lan_start: Button
var _lan_join: Button
var _lan_permission_pending := false
var _lan_permission_epoch := 0
var _lan_marker: Polygon2D
const LAN_GAME_PORT := 17350
const LAN_DISCOVERY_PORT := 17351
var _lan_game_port := LAN_GAME_PORT
var _lan_discovery_port := LAN_DISCOVERY_PORT
var _lan_advertised_address := "255.255.255.255"
var _lan_route := PackedVector2Array()
var _lan_route_index := 0
var _lan_route_sector := ""
var _lan_route_deadline := 0
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
var _save_owner_kind := SaveSnapshot.LOCAL
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
			var owner_kind := str(dto["ownership"]["kind"])
			if owner_kind not in [SaveSnapshot.LOCAL, SaveSnapshot.HOST]:
				_block_boot({"status": "unsupported_owner"})
				return
			_save_owner_kind = owner_kind
			_session_id = str(dto["ownership"]["session_id"])
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
	_setup_lan_ui()
	_setup_mode_ui()
	_refresh_mode_presentation()
	ANDROID_TRACE.record("bootstrap", "world ready")
	($InputController as GameplayInputController).ui_hit_test = _ui_captures_touch
	print("SEACRAFT_CONTENT_MANIFEST %s %d" % [ContentManifest.current_hash(), ContentManifest.current_entry_count()])
	print(BOOT_MARKER)


const VISUAL_PILOT := preload("res://src/presentation/ship/visual_pilot.gd")
var _pilot_water: Polygon2D
var _pilot_water_enabled := false
var _pilot_comparison: Sprite2D


func _setup_visual_pilot() -> void:
	var player_marker: Polygon2D = $BoatMarker
	_surface_sprite = VISUAL_PILOT.mount_atlas(player_marker, "SC-02", 104.0)
	if _surface_sprite != null:
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
		_pilot_water.material = VISUAL_PILOT.water_material() if _pilot_water_enabled and active_sector() != null and active_sector().mode == 0 else null


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	if _combat != null:
		_combat.advance_tick()
		_advance_background_economy()
	var position_now := _ship_motor.global_position
	if _diag_physics_left > 0:
		ANDROID_TRACE.record("physics", "frame=%s pos=%s displacement=%s velocity=%s target=%s collisions=%s" % [
			Engine.get_physics_frames(), position_now, position_now - _diag_physics_origin,
			_ship_motor.velocity, _ship_motor.has_target(), _ship_motor.get_slide_collision_count()])
		_diag_physics_left -= 1
	_world.active().move_entity(FoundationSector.PLAYER, position_now)
	_refresh_market_access()
	_refresh_mode_button()
	_advance_lan_route()
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
	if command.get("type") in [GameplayCommand.MOVE_TO_WORLD_POSITION, GameplayCommand.CANCEL]:
		_lan_route.clear()
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
	elif not _combat.register_dormant(PRACTICE_TARGET, (PRACTICE_SHIP_DEF as ShipDefinition).faction_id,
			(PRACTICE_SHIP_DEF as ShipDefinition).base_hull_hp, FoundationSector.ID, PRACTICE_POSITION,
			TargetingService.SHIP, cannon, 4.0, 0.05):
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
		push_error("VS-03 loot inventory authority setup failed")
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
	if _saved_lan_guest_required() and not _loot.inventory_state().has_owner(LAN_REMOTE_PLAYER_ID):
		if not _loot.inventory_state().bind_owner(LAN_REMOTE_PLAYER_ID, LAN_GUEST_MAX_SLOTS, LAN_GUEST_MAX_WEIGHT):
			push_error("PRG-05 LAN guest owner restore setup failed")
			return
	# Register the canonical pilot factions before restoring reputation saves.
	if not _loot.inventory_state().register_economy_faction((PLAYER_SHIP_DEF as ShipDefinition).faction_id) or not _loot.inventory_state().register_economy_faction((PRACTICE_SHIP_DEF as ShipDefinition).faction_id):
		push_error("PRG-05 faction registration failed")
		return
	if not _loot.inventory_state().register_economy_market(PILOT_MARKET_ID, (PLAYER_SHIP_DEF as ShipDefinition).faction_id,
			(VS03_LOOT_ITEM as ItemDefinition).stable_id, FoundationSector.HAVEN_ID, 10, 8, 20):
		push_error("PRG-05 pilot market registration failed")
		return
	if not _loot.inventory_state().register_economy_bounty(PILOT_BOUNTY_ID,
			(PLAYER_SHIP_DEF as ShipDefinition).faction_id, PRACTICE_TARGET, PILOT_BOUNTY_REWARD):
		push_error("PRG-05 pilot bounty registration failed")
		return
	if not _loot.restore_state(_pending_loot_state if not _pending_loot_state.is_empty() else SaveSnapshot.empty_loot_state()):
		push_error("VS-03 loot restore failed")
		return
	if _pending_combat.has("progression") and not _loot.inventory_state().restore_progression(_pending_combat["progression"]):
		push_error("Progression restore failed")
		return
	if not _restore_lan_guest_inventory(_loot.inventory_state()):
		push_error("PRG-05 LAN guest restore failed")
		return
	_loot.initialize_missing_stock(CORE_STOCK)
	_loot.initialize_missing_stock(NPC_STOCK)
	if not _loot.inventory_state().enable_economy_diplomacy(FoundationSector.PLAYER) or not _combat.bind_economy_authority(_loot.inventory_state()):
		push_error("PRG-05 combat diplomacy integration failed")
		return
	if not _combat.attach_inventory(_loot) or not _combat.register_ammo(ROUND_AMMO_PROFILE as AmmoProfile) or not _combat.register_ammo(EMBER_AMMO_PROFILE as AmmoProfile):
		push_error("CORE combat inventory/ammo authority setup failed")
		return
	if not _combat.mount_ammo(FoundationSector.PLAYER, PackedStringArray([ROUND_AMMO, EMBER_AMMO])) or not _combat.configure_repair(FoundationSector.PLAYER, 20.0, 180, CoreCombatRules.STOWED):
		push_error("CORE combat loadout/repair setup failed")
		return
	if not _combat.mount_harpoon(FoundationSector.PLAYER, HARPOON_PROFILE as HarpoonProfile):
		push_error("CORE-02 harpoon setup failed")
		return
	_world_objects = WorldObjectAuthority.new(sector, _loot, _combat, VS03_LOOT_TABLE as LootTable, FoundationSector.PLAYER, true)
	if _pending_combat.has("world") and not _world_objects.restore_state(_pending_combat["world"]):
		push_error("CORE-02 world object restore failed")
		return
	if not _combat.configure_defense(FoundationSector.PLAYER, 0.15, {}, 8.0, 8.0) or not _combat.configure_defense(PRACTICE_TARGET, 0.1, {CoreCombatRules.FIRE: -0.2}, 0.0, 6.0):
		push_error("CORE combat defense setup failed")
		return
	if _pending_combat.has("combat") and not _combat.restore_state(_pending_combat["combat"]):
		push_error("CORE combat restore failed")
		return
	_bounty_bridge = Prg05BountyCombatBridge.new(_combat, _loot.inventory_state(), true)
	if not _bounty_bridge.bind_bounty(PILOT_BOUNTY_ID, PRACTICE_TARGET):
		push_error("PRG-05 pilot bounty binding failed")
		return
	_bounty_bridge.bounty_awarded.connect(_on_bounty_awarded)
	if not _setup_background_economy():
		push_error("PRG-05 background economy setup failed")
		return
	if _pending_combat.has("npc_motion"):
		var motion: Variant = _pending_combat["npc_motion"]
		if not ShipMotor.valid_save_motion(motion):
			push_error("VS-02 NPC motion restore validation failed")
			return
		if practice_active and not sector.move_entity(PRACTICE_TARGET, Vector2(motion["x"], motion["y"])):
			push_error("VS-02 NPC motion sector restore failed")
			return
		_npc_motor.restore_save_motion(motion)
	if _pending_combat.has("npc_ai") and not _npc_brain.restore_state(_pending_combat["npc_ai"]):
		push_error("AI-01 NPC state restore failed")
		return
	if _pending_combat.has("scheduler") and not _ai_scheduler.restore_state(_pending_combat["scheduler"]):
		push_error("AI-01 scheduler restore failed")
		return
	if _pending_combat.has("fleet") and not _fleet_coordinator.restore_state(_pending_combat["fleet"]):
		push_error("AI-03 fleet restore failed")
		return
	if _pending_combat.has("docks") and not _dock_authority.restore_state(_pending_combat["docks"]):
		push_error("AI-03 dock restore failed")
		return
	if not _ai_scheduler.register_brain(_npc_brain, (NPC_TUNING as NpcAiTuning).decision_interval_ticks, 0):
		push_error("AI-01 scheduler brain registration failed")
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


# This authored pilot is a distinct abstract FAR cargo convoy; the existing
# practice NPC and player remain owned by the local combat/movement runtime.
# AI-04 owns the only convoy record, scheduler and travel progress.
func _setup_background_economy() -> bool:
	var inventory := _loot.inventory_state()
	_economy_world = WorldSimulationAuthority.new(ContentManifest.registry(), FoundationSector.graph(),
		SeedStreams.derive_stream_seed(int(_streams.snapshot_state()["master_seed"]), "ai04.world.v1"), true)
	var tick := _combat.simulation_tick()
	if _pending_combat.has("ai04_world"):
		if not _economy_world.restore_state(_pending_combat["ai04_world"]):
			return false
		if int(_pending_combat["ai04_world"]["current_tick"]) > tick:
			return false
	else:
		var item_id := (VS03_LOOT_ITEM as ItemDefinition).stable_id
		var cargo := WorldJob.cargo_mission("mission.haven.supply", item_id,
			PILOT_CONVOY_CARGO, FoundationSector.FOUNDATION_GATE, FoundationSector.HAVEN_ID)
		var job := WorldJob.create(PILOT_CONVOY_JOB, WorldJob.TRADE, PILOT_CONVOY_FLEET,
			FoundationSector.FOUNDATION_GATE, FoundationSector.HAVEN_ID, FoundationSector.ID,
			WorldJob.TRAVEL, "", cargo)
		var base := {
			"instance_id": PILOT_CONVOY_ID, "definition_id": (PLAYER_SHIP_DEF as ShipDefinition).stable_id,
			"entity_kind": "npc_ship", "sector_id": FoundationSector.ID,
			"position": {"x": 520.0, "y": 0.0},
			"motion": {"heading": 0.0, "vx": 0.0, "vy": 0.0},
			"health": 100.0, "alive": true, "route": {}, "cooldowns": {},
			"inventory": {item_id: PILOT_CONVOY_CARGO}, "payload": {"content_refs": []},
		}
		var semantic := FarFieldEntityState.default_semantic(SimulationLOD.FAR,
			(PLAYER_SHIP_DEF as ShipDefinition).faction_id, PILOT_CONVOY_FLEET, "merchant",
			job, FoundationSector.HAVEN_ID, 0.001, "low")
		semantic["last_simulation_tick"] = tick
		semantic["next_due_tick"] = tick + WorldSimulationAuthority.FAR_INTERVAL_TICKS
		if not _economy_world.register_record(FarFieldEntityState.attach(base, semantic)):
			return false
	_economy_runner = Prg05EconomyWorldRunner.new(_economy_world, inventory,
		Prg05ConvoyBridge.new(inventory, _fleet_coordinator, true), true)
	return _economy_runner.bind_far_convoy(PILOT_CONVOY_ID, PILOT_MARKET_ID, tick + WorldSimulationAuthority.FAR_INTERVAL_TICKS)


func _advance_background_economy() -> void:
	if _economy_runner == null or _economy_runner.is_settled(PILOT_CONVOY_ID):
		return
	var tick := _combat.simulation_tick()
	if tick % WorldSimulationAuthority.FAR_INTERVAL_TICKS != 0:
		return
	var batch := _economy_runner.advance_tick(tick)
	if not batch.get("advanced", []).is_empty() or not batch.get("settlements", []).is_empty():
		_save_service.mark_dirty()
	if _market_open and not batch.get("settlements", []).is_empty():
		_refresh_market_quote()


func _on_bounty_awarded(result: Dictionary) -> void:
	if result.get("owner_id") != FoundationSector.PLAYER:
		return
	_save_service.mark_dirty()
	if _market_open:
		_refresh_market_quote()


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
	_refresh_lan_ui()
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
		var lan_state := _capture_lan_state()
		if not lan_state.is_empty():
			authority_state["lan"] = lan_state
	if _economy_world != null:
		var economy_world_state := _economy_world.snapshot_state()
		if economy_world_state.is_empty():
			save_status = {"status": "economy_world_snapshot_failed"}
			return
		authority_state["ai04_world"] = economy_world_state
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
	var dto := _save_service.create_snapshot(sector, FoundationSector.PLAYER, _ship_motor, _streams, _save_owner_kind, _session_id, loot_state, authority_state)
	save_status = _save_service.save_if_dirty(dto)



func request_sector_transition(gate_id: String) -> Dictionary:
	if _lan_host != null and _lan_host.is_running():
		return {"accepted": false, "reason": "lan_host_sector_locked", "from_sector": active_sector().sector_id if active_sector() != null else "", "to_sector": "", "gate_id": gate_id, "entry_anchor": ""}
	if _world == null or active_sector() == null:
		return {"accepted": false, "reason": "no_active_sector", "from_sector": "", "to_sector": "", "gate_id": gate_id, "entry_anchor": ""}
	_world.active().move_entity(FoundationSector.PLAYER, _ship_motor.global_position)
	var result := _world.request_transition(_authority, FoundationSector.PLAYER, gate_id)
	if not result["accepted"]:
		return result
	_lan_route.clear()
	_ship_motor.global_position = _world.active().entity_position(FoundationSector.PLAYER)
	_ship_motor.cancel_target()
	_build_sector_geometry(_world.active())
	_sync_sector_local_presentation()
	_refresh_mode_presentation()
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



func _saved_lan_guest_required() -> bool:
	var lan: Variant = _pending_combat.get("lan", {})
	if lan is Dictionary and not (lan as Dictionary).is_empty():
		return true
	var progression: Variant = _pending_combat.get("progression", {})
	if not progression is Dictionary:
		return false
	var equipment: Variant = (progression as Dictionary).get("equipment", {})
	if equipment is Dictionary and (equipment as Dictionary).has(LAN_REMOTE_PLAYER_ID):
		return true
	var prg05: Variant = (progression as Dictionary).get("prg05", {})
	var owners: Variant = (prg05 as Dictionary).get("owners", {}) if prg05 is Dictionary else {}
	return owners is Dictionary and (owners as Dictionary).has(LAN_REMOTE_PLAYER_ID)


static func _valid_lan_save_state(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var state: Dictionary = value
	if state.size() != 6:
		return false
	var raw_version: Variant = state.get("version")
	if typeof(raw_version) not in [TYPE_INT, TYPE_FLOAT] or not is_finite(float(raw_version)) \
			or float(raw_version) != floorf(float(raw_version)) or int(raw_version) != 1:
		return false
	if state.get("guest_id") != LAN_REMOTE_PLAYER_ID or not state.get("sector_id") is String \
			or not SectorIds.valid(str(state["sector_id"])):
		return false
	if not ShipMotor.valid_save_motion(state.get("motion")) or not state.get("quantities") is Dictionary \
			or not state.get("transaction_ledger") is Dictionary:
		return false
	return true


func _restore_lan_guest_inventory(inventory: InventoryState) -> bool:
	var raw: Variant = _pending_combat.get("lan", {})
	if raw is Dictionary and (raw as Dictionary).is_empty():
		return true
	if not _valid_lan_save_state(raw):
		return false
	var state: Dictionary = raw
	if not inventory.has_owner(LAN_REMOTE_PLAYER_ID):
		if not inventory.bind_owner(LAN_REMOTE_PLAYER_ID, LAN_GUEST_MAX_SLOTS, LAN_GUEST_MAX_WEIGHT):
			return false
	if not inventory.restore_quantities(LAN_REMOTE_PLAYER_ID, state["quantities"]):
		return false
	_lan_saved_state = state.duplicate(true)
	return true


func _capture_lan_state() -> Dictionary:
	if _loot == null:
		return {}
	var inventory := _loot.inventory_state()
	if not inventory.has_owner(LAN_REMOTE_PLAYER_ID):
		return {}
	var motion: Dictionary = {}
	var sector_id := ""
	if _lan_remote_motor != null and is_instance_valid(_lan_remote_motor):
		motion = _lan_remote_motor.capture_save_motion()
		sector_id = active_sector().sector_id if active_sector() != null else ""
	elif _valid_lan_save_state(_lan_saved_state):
		motion = (_lan_saved_state["motion"] as Dictionary).duplicate(true)
		sector_id = str(_lan_saved_state["sector_id"])
	else:
		return {}
	var ledger := {"version": 1, "commit_sequence": 0, "entries": []}
	if _lan_host != null and _lan_host.is_running():
		ledger = _lan_host.transaction_ledger_snapshot()
	elif _valid_lan_save_state(_lan_saved_state):
		ledger = (_lan_saved_state["transaction_ledger"] as Dictionary).duplicate(true)
	return {
		"version": 1,
		"guest_id": LAN_REMOTE_PLAYER_ID,
		"sector_id": sector_id,
		"motion": motion,
		"quantities": inventory.quantities_snapshot(LAN_REMOTE_PLAYER_ID),
		"transaction_ledger": ledger,
	}


func _ensure_lan_remote_motor() -> bool:
	if _lan_remote_motor != null and is_instance_valid(_lan_remote_motor):
		return true
	var sector := active_sector()
	if sector == null or sector.sector_id != FoundationSector.HAVEN_ID or _market_anchor == null or _loot == null:
		return false
	var inventory := _loot.inventory_state()
	if not inventory.has_owner(LAN_REMOTE_PLAYER_ID) \
			and not inventory.bind_owner(LAN_REMOTE_PLAYER_ID, LAN_GUEST_MAX_SLOTS, LAN_GUEST_MAX_WEIGHT):
		return false
	var spawn_position := _market_anchor.position + Vector2(48.0, 0.0)
	var saved_motion: Dictionary = {}
	if _valid_lan_save_state(_lan_saved_state) and str(_lan_saved_state["sector_id"]) == sector.sector_id:
		saved_motion = (_lan_saved_state["motion"] as Dictionary).duplicate(true)
		spawn_position = Vector2(float(saved_motion["x"]), float(saved_motion["y"]))
	if not spawn_position.is_finite() or not sector.bounds.has_point(spawn_position) or not sector.navigation.accessible(spawn_position):
		spawn_position = _market_anchor.position
	var indexed := sector.entity_position(LAN_REMOTE_PLAYER_ID)
	if indexed.is_finite():
		if not sector.move_entity(LAN_REMOTE_PLAYER_ID, spawn_position):
			return false
	elif not sector.register_entity(LAN_REMOTE_PLAYER_ID, spawn_position):
		return false
	var motor := ShipMotor.new()
	motor.name = "LanGuestMotor"
	motor.movement_profile = _ship_motor.movement_profile
	motor.authority_enabled = true
	motor.collision_layer = FoundationSector.SHIP_LAYER
	motor.collision_mask = FoundationSector.COAST_LAYER
	motor.process_physics_priority = -1
	add_child(motor)
	motor.global_position = spawn_position
	if not saved_motion.is_empty() and not motor.restore_save_motion(saved_motion):
		motor.queue_free()
		return false
	if not sector.move_entity(LAN_REMOTE_PLAYER_ID, motor.global_position):
		motor.queue_free()
		return false
	_lan_remote_motor = motor
	return true


func start_lan_host(game_port: int, discovery_port: int = 0, advertised_address: String = "255.255.255.255") -> Dictionary:
	if not LanPermissionGate.new().can_open_lan_socket():
		return {"accepted": false, "reason": LanPermissionGate.RESULT_DENIED}
	if _lan_host != null and _lan_host.is_running():
		return {"accepted": false, "reason": "already_running"}
	if active_sector() == null or active_sector().sector_id != FoundationSector.HAVEN_ID or _market_anchor == null:
		return {"accepted": false, "reason": "market_sector_required"}
	if not _ensure_lan_remote_motor():
		return {"accepted": false, "reason": "guest_authority_setup_failed"}
	var inventory := _loot.inventory_state()
	if not inventory.enable_economy_diplomacy(LAN_REMOTE_PLAYER_ID):
		return {"accepted": false, "reason": "guest_diplomacy_setup_failed"}
	var host := ProductionLanHost.new()
	host.name = "LanSession"
	host.authority_mutated.connect(_on_lan_authority_mutated)
	add_child(host)
	var saved_ledger: Dictionary = {}
	if _valid_lan_save_state(_lan_saved_state):
		saved_ledger = (_lan_saved_state["transaction_ledger"] as Dictionary).duplicate(true)
	var result := host.start_host(game_port, discovery_port, advertised_address,
		FoundationSector.PLAYER, _ship_motor, LAN_REMOTE_PLAYER_ID, _lan_remote_motor,
		active_sector(), _combat, _loot, inventory, PILOT_MARKET_ID, _market_anchor.position,
		PILOT_MARKET_RADIUS, saved_ledger, (PLAYER_SHIP_DEF as ShipDefinition).stable_id)
	if not bool(result.get("accepted", false)):
		host.queue_free()
		return result
	_lan_host = host
	_save_owner_kind = SaveSnapshot.HOST
	_session_id = str(result["session_id"])
	_lan_saved_state = _capture_lan_state()
	_save_service.mark_dirty()
	return result


func stop_lan_host() -> bool:
	if _lan_host == null or not _lan_host.is_running():
		return false
	_lan_saved_state = _capture_lan_state()
	_lan_host.stop_host()
	_lan_host.queue_free()
	_lan_host = null
	_save_service.mark_dirty()
	return true


func lan_host_snapshot() -> Dictionary:
	return _lan_host.snapshot() if _lan_host != null else {"running": false}


func lan_remote_player_id() -> String:
	return LAN_REMOTE_PLAYER_ID


func _on_lan_authority_mutated(_intent_type: String) -> void:
	_save_service.mark_dirty()
	if _market_open:
		_refresh_market_quote()


func _setup_lan_ui() -> void:
	_lan_button = Button.new()
	_lan_button.name = "LanMenuButton"
	_lan_button.text = "LAN"
	_lan_button.size = Vector2(150, 64)
	_lan_button.focus_mode = Control.FOCUS_NONE
	$UI.add_child(_lan_button)
	_lan_menu = PanelContainer.new()
	_lan_menu.name = "LanMenu"
	$UI.add_child(_lan_menu)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_lan_menu.add_child(column)
	_lan_status = Label.new()
	_lan_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_status.add_theme_font_size_override("font_size", 22)
	_lan_status.custom_minimum_size.y = 100
	column.add_child(_lan_status)
	_lan_travel = _lan_action(column, "Limana git / geç", _lan_travel_pressed)
	_lan_start = _lan_action(column, "Oda oluştur", _lan_start_pressed)
	_lan_join = _lan_action(column, "Odaya katıl", _lan_join_pressed)
	_lan_action(column, "Kapat", _toggle_lan_menu)
	_lan_button.pressed.connect(_toggle_lan_menu)
	_lan_menu.hide()
	get_viewport().size_changed.connect(_layout_lan_ui)
	_layout_lan_ui()


func _lan_action(column: VBoxContainer, caption: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 64)
	button.add_theme_font_size_override("font_size", 22)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	column.add_child(button)
	return button


func _layout_lan_ui() -> void:
	var safe := get_viewport_rect()
	if OS.has_feature("android"):
		var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		var pixels := window.intersection(DisplayServer.get_display_safe_area())
		if pixels.has_area():
			pixels.position -= window.position
			safe = safe.intersection(SafeAreaMath.display_safe_area_to_logical(Rect2(pixels), Vector2(1280, 720), Vector2(window.size)))
	_lan_button.position = Vector2(safe.end.x - 174, safe.position.y + 174)
	_lan_menu.size = Vector2(minf(640, safe.size.x - 48), 410)
	_lan_menu.position = safe.get_center() - _lan_menu.size * 0.5


func _toggle_lan_menu() -> void:
	if not _lan_menu.visible:
		if _market_open:
			_toggle_market()
		if _world_map_open:
			_toggle_world_map()
	if _lan_menu.visible:
		_lan_permission_epoch += 1
	_lan_menu.visible = not _lan_menu.visible
	($InputController as GameplayInputController).set_world_input_blocked(_lan_menu.visible)
	_refresh_lan_ui()


func _refresh_lan_ui() -> void:
	if _lan_menu == null or active_sector() == null:
		return
	var running := bool(lan_host_snapshot().get("running", false))
	_lan_button.text = "LAN • AÇIK" if running else "LAN"
	if _lan_marker != null:
		var connected: Dictionary = lan_host_snapshot().get("peer_to_player", {})
		_lan_marker.visible = running and not connected.is_empty()
		if running and is_instance_valid(_lan_remote_motor):
			_lan_marker.global_position = _lan_remote_motor.global_position
			_lan_marker.rotation = _lan_remote_motor.rotation
	if not _lan_menu.visible:
		return
	var haven := active_sector().sector_id == FoundationSector.HAVEN_ID
	_lan_travel.disabled = _lan_permission_pending or running or (haven and _can_access_market())
	_lan_start.disabled = _lan_permission_pending or (not running and not _can_access_market())
	_lan_start.text = "Odayı kapat" if running else "Oda oluştur"
	_lan_join.disabled = _lan_permission_pending or running or active_sector().mode != 0
	if running:
		var peers: Dictionary = lan_host_snapshot().get("peer_to_player", {})
		var addresses := PackedStringArray()
		for address in IP.get_local_addresses():
			if SessionProtocol.valid_ipv4(address) and not address.begins_with("127."):
				addresses.append(address)
		_lan_status.text = "Oda açık • %d/2 oyuncu\nIP: %s • Port: %d" % [1 + peers.size(), ", ".join(addresses), _lan_game_port]
	elif not _lan_status.has_meta("error"):
		_lan_status.text = "Aynı Wi-Fi ağına bağlanın. Oda açmak için Güvenli Liman pazarına yaklaşın." if not _can_access_market() else "Güvenli Liman • Oda oluşturabilir veya başka odaya katılabilirsiniz."


func _lan_travel_pressed() -> void:
	if _lan_status.has_meta("error"):
		_lan_status.remove_meta("error")
	var sector := active_sector()
	var anchor_id := "anchor.haven_center"
	var gate_id := ""
	match sector.sector_id:
		FoundationSector.ID:
			anchor_id = FoundationSector.FOUNDATION_GATE
			gate_id = FoundationSector.GATE_FOUNDATION_OUTER
		FoundationSector.OUTER_ID:
			anchor_id = FoundationSector.OUTER_EAST
			gate_id = FoundationSector.GATE_OUTER_HAVEN
		FoundationSector.DEEP_ID:
			anchor_id = FoundationSector.DEEP_ENTRY
			gate_id = FoundationSector.GATE_DEEP_HAVEN
	var anchor := sector.anchor(anchor_id)
	if anchor == null:
		return
	if not gate_id.is_empty() and _ship_motor.global_position.distance_to(anchor.position) <= 64.0:
		var result := request_sector_transition(gate_id)
		if not result.get("accepted", false):
			_lan_status.text = str(result.get("reason", "Geçiş reddedildi"))
			_lan_status.set_meta("error", true)
		return
	# Use the existing bounded visibility-graph route rather than steering
	# straight into the island between the player and the eastern gate.
	var route := sector.navigation.path(_ship_motor.global_position, anchor.position)
	if route.size() < 2:
		_lan_status.text = "Güvenli rota bulunamadı. Açık denize çıkıp yeniden deneyin."
		_lan_status.set_meta("error", true)
		return
	_lan_route = route
	_lan_route_index = 1
	_lan_route_sector = sector.sector_id
	_lan_route_deadline = Time.get_ticks_msec() + 180000
	_ship_motor.apply_authoritative_command(GameplayCommand.move_to_world_position(_lan_route[_lan_route_index]))
	_toggle_lan_menu()


func _advance_lan_route() -> void:
	if _lan_route.is_empty():
		return
	if active_sector().sector_id != _lan_route_sector or Time.get_ticks_msec() > _lan_route_deadline:
		_lan_route.clear()
		return
	if _ship_motor.has_target():
		return
	_lan_route_index += 1
	if _lan_route_index >= _lan_route.size():
		_lan_route.clear()
		return
	_ship_motor.apply_authoritative_command(GameplayCommand.move_to_world_position(_lan_route[_lan_route_index]))


func _lan_start_pressed() -> void:
	if _lan_permission_pending:
		return
	if lan_host_snapshot().get("running", false):
		stop_lan_host()
		request_checkpoint()
		_refresh_lan_ui()
		return
	if not _can_access_market():
		return
	_lan_route.clear()
	_lan_permission_pending = true
	var epoch := _lan_permission_epoch
	var gate := LanPermissionGate.new()
	var permission: String = await gate.request_and_wait(get_tree(), func() -> void:
		_lan_status.text = "Android yerel ağ izni bekleniyor…"
		_lan_status.set_meta("error", true)
		_refresh_lan_ui()
	)
	_lan_permission_pending = false
	if epoch != _lan_permission_epoch:
		_lan_status.remove_meta("error")
		_refresh_lan_ui()
		return
	if permission != LanPermissionGate.RESULT_ALLOWED:
		_lan_status.text = LanPermissionGate.user_message(permission)
		_lan_status.set_meta("error", true)
		_refresh_lan_ui()
		return
	if not _can_access_market():
		_lan_status.remove_meta("error")
		_refresh_lan_ui()
		return
	var result := start_lan_host(_lan_game_port, _lan_discovery_port, _lan_advertised_address)
	if not result.get("accepted", false):
		_lan_status.text = "Oda açılamadı: " + str(result.get("reason", ""))
		_lan_status.set_meta("error", true)
		return
	if _lan_status.has_meta("error"):
		_lan_status.remove_meta("error")
	# Pilot guests receive a single persisted, authority-owned starting grant.
	var grant := _loot.inventory_state().grant_economy_currency_authoritative(LAN_REMOTE_PLAYER_ID, "event.lan.pilot.starting_credit", 1000)
	if not grant.get("accepted", false):
		push_warning("LAN starting credit: " + str(grant.get("reason", "")))
	if _lan_marker == null:
		_lan_marker = Polygon2D.new()
		_lan_marker.polygon = PackedVector2Array([Vector2(-18, 12), Vector2(20, 0), Vector2(-18, -12)])
		_lan_marker.color = Color(0.3, 0.85, 0.9)
		add_child(_lan_marker)
	request_checkpoint()
	_refresh_lan_ui()


func _lan_join_pressed() -> void:
	if _lan_permission_pending:
		return
	if lan_host_snapshot().get("running", false):
		return
	if active_sector().mode != 0:
		_lan_status.text = "LAN için önce yüzeye çıkın."
		_lan_status.set_meta("error", true)
		return
	# Persist only the local world before leaving it. Guest scene has no save service.
	_flush_checkpoint()
	if _save_service.is_dirty():
		_lan_status.text = "Yerel kayıt tamamlanamadı. Önce kaydı doğrulayın."
		_lan_status.set_meta("error", true)
		return
	get_tree().change_scene_to_file("res://src/presentation/lan_guest.tscn")


func _setup_mode_ui() -> void:
	_mode_button = Button.new()
	_mode_button.name = "Prg06ModeButton"
	_mode_button.size = Vector2(150, 64)
	_mode_button.focus_mode = Control.FOCUS_NONE
	_mode_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_mode_button.pressed.connect(_mode_pressed)
	$UI.add_child(_mode_button)
	get_viewport().size_changed.connect(_layout_mode_ui)
	_layout_mode_ui()
	_refresh_mode_button()


func _layout_mode_ui() -> void:
	if is_instance_valid(_mode_button) and is_instance_valid(_lan_button):
		_mode_button.position = _lan_button.position + Vector2(0, 78)


func _mode_gate() -> String:
	if active_sector() == null:
		return ""
	match active_sector().sector_id:
		FoundationSector.HAVEN_ID:
			return FoundationSector.GATE_HAVEN_DEEP
		FoundationSector.DEEP_ID:
			return FoundationSector.GATE_DEEP_HAVEN
	return ""


func _refresh_mode_button() -> void:
	if not is_instance_valid(_mode_button):
		return
	var gate := _mode_gate()
	_mode_button.visible = not gate.is_empty() and not _world_map_open and not _market_open and not _lan_menu.visible
	if gate.is_empty():
		return
	var anchor := active_sector().anchor(FoundationSector.HAVEN_DIVE if active_sector().mode == 0 else FoundationSector.DEEP_ENTRY)
	var nearby := anchor != null and _ship_motor.global_position.distance_to(anchor.position) <= 64.0
	_mode_button.text = ("DAL" if active_sector().mode == 0 else "YÜZEYE ÇIK") if nearby else "KAPIYA GİT"
	_mode_button.disabled = bool(lan_host_snapshot().get("running", false)) or _lan_permission_pending


func _mode_pressed() -> void:
	var gate := _mode_gate()
	if gate.is_empty() or bool(lan_host_snapshot().get("running", false)) or _lan_permission_pending:
		return
	var anchor := active_sector().anchor(FoundationSector.HAVEN_DIVE if active_sector().mode == 0 else FoundationSector.DEEP_ENTRY)
	if anchor == null:
		return
	if _ship_motor.global_position.distance_to(anchor.position) > 64.0:
		_on_gameplay_command(GameplayCommand.move_to_world_position(anchor.position))
	else:
		request_sector_transition(gate)


func _refresh_mode_presentation() -> void:
	if active_sector() == null:
		return
	var submerged := active_sector().mode == 1
	var marker: Polygon2D = $BoatMarker
	if is_instance_valid(_surface_sprite):
		_surface_sprite.visible = not submerged
	marker.polygon = PackedVector2Array([-28, 0, -18, -9, 16, -9, 29, 0, 16, 9, -18, 9]) if submerged else PackedVector2Array([-18, 12, 20, 0, -18, -12])
	marker.color = Color(0.38, 0.65, 0.8) if submerged else Color(0.72, 0.8, 0.86, 0.0 if is_instance_valid(_surface_sprite) else 1.0)
	_apply_pilot_water()
	_refresh_mode_button()


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


func _can_access_market() -> bool:
	var sector := active_sector()
	return sector != null and sector.sector_id == FoundationSector.HAVEN_ID and _market_anchor != null \
		and _ship_motor != null and _ship_motor.authority_enabled \
		and sector.entity_within_interaction_range(FoundationSector.PLAYER,
			_ship_motor.global_position, _market_anchor.position, PILOT_MARKET_RADIUS)


func _refresh_market_access() -> void:
	if _market_button == null or _market_panel == null:
		return
	var allowed := _can_access_market()
	if not allowed and _market_open:
		_market_open = false
		_market_panel.hide()
		($InputController as GameplayInputController).set_world_input_blocked(_world_map_open)
	_market_button.disabled = not allowed
	var next_text := "KAPAT" if _market_open else ("PAZAR" if allowed else "PAZAR UZAK")
	if _market_button.text != next_text:
		_market_button.text = next_text


func _toggle_market() -> void:
	if _lan_menu != null and _lan_menu.visible:
		return
	if _market_panel == null or _market_button == null:
		return
	if not _market_open and not _can_access_market():
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
	_market_panel.consume_bounty_board(inventory.economy_bounty_board(FoundationSector.PLAYER, _combat.simulation_tick()))
	_market_panel.consume_convoy_status(_economy_runner != null and _economy_runner.is_settled(PILOT_CONVOY_ID))


# Each namespaced ID segment must start with an ASCII letter, even when
# a random nonce begins with a digit. Never accept an empty nonce.
static func local_market_transaction_id(nonce: PackedByteArray) -> String:
	return "txn.market.ui.r%s" % nonce.hex_encode() if nonce.size() == 16 else ""


func _on_market_intent(operation: String, payload: Dictionary) -> void:
	# Offline/local host adapter. Never trust the panel for stock, price or identity.
	if not _market_open or _loot == null or not _can_access_market():
		return
	if operation not in [InventoryState.OP_MARKET_BUY, InventoryState.OP_MARKET_SELL]:
		return
	if payload.size() != 2 or payload.get("market_id") != PILOT_MARKET_ID or typeof(payload.get("quantity")) != TYPE_INT:
		return
	var quantity := int(payload["quantity"])
	if quantity < 1 or quantity > Prg05MarketPanel.MAX_ORDER:
		return
	# New local intent IDs cannot collide with a persisted transaction after restart.
	var transaction_id := local_market_transaction_id(Crypto.new().generate_random_bytes(16))
	if transaction_id.is_empty():
		_market_panel.show_result({"accepted": false, "reason": "transaction_id_unavailable"})
		return
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
	if _lan_menu != null and _lan_menu.visible:
		return
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
	_add_rectangle(geometry, sector.bounds, Color(0.025, 0.055, 0.13) if sector.mode == 1 else Color(0.035, 0.095, 0.115))
	_pilot_water = geometry.get_child(0) as Polygon2D
	_apply_pilot_water()
	_market_anchor = sector.anchor(PILOT_MARKET_ANCHOR) if sector.sector_id == FoundationSector.HAVEN_ID else null
	if _market_anchor != null:
		var market_ring := Line2D.new()
		market_ring.name = "MarketRange"
		market_ring.position = _market_anchor.position
		market_ring.width = 2.0
		market_ring.default_color = Color(0.65, 0.8, 0.45, 0.7)
		for index in range(65):
			market_ring.add_point(Vector2.from_angle(TAU * float(index) / 64.0) * PILOT_MARKET_RADIUS)
		geometry.add_child(market_ring)
		var market_label := Label.new()
		market_label.text = "PAZAR"
		market_label.position = _market_anchor.position + Vector2(-26.0, -20.0)
		market_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		geometry.add_child(market_label)
	var mode_anchor := sector.anchor(FoundationSector.HAVEN_DIVE if sector.mode == 0 else FoundationSector.DEEP_ENTRY)
	if mode_anchor != null:
		var ring := Line2D.new()
		ring.position = mode_anchor.position
		ring.width = 2.0
		ring.default_color = Color(0.3, 0.8, 1.0)
		for index in range(33):
			ring.add_point(Vector2.from_angle(TAU * float(index) / 32.0) * 64.0)
		geometry.add_child(ring)
		var label := Label.new()
		label.text = "DALIŞ NOKTASI" if sector.mode == 0 else "YÜZEYE ÇIKIŞ"
		label.position = mode_anchor.position + Vector2(-65, -28)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		geometry.add_child(label)
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
