extends Node2D

const BOOT_MARKER := "SeaCraft bootstrap ready"

const CHECKPOINT_INTERVAL_MS := 20000
const PRACTICE_TARGET := "entity.vs01_practice_ship"
const PRACTICE_POSITION := Vector2(-240, 150)

var _combat: CombatAuthority
var _practice_marker: Polygon2D
var _target_ring: Line2D
var _fire_control: CombatFireButton

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
	print(BOOT_MARKER)


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	if _combat != null:
		_combat.advance_tick()
	var position_now := _ship_motor.global_position
	_world.active().move_entity(FoundationSector.PLAYER, position_now)
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
		push_error("VS-01 practice target placement failed")
		return
	if not _combat.register(FoundationSector.PLAYER, "faction.player", 100.0, cannon) or not _combat.register(PRACTICE_TARGET, "faction.practice_hostile", 75.0, null, 4.0, 0.05):
		push_error("VS-01 combat roster setup failed")
		return
	_practice_marker = Polygon2D.new()
	_practice_marker.position = PRACTICE_POSITION
	_practice_marker.polygon = PackedVector2Array([Vector2(-18, 12), Vector2(20, 0), Vector2(-18, -12)])
	_practice_marker.color = Color(0.9, 0.48, 0.33)
	add_child(_practice_marker)
	_target_ring = Line2D.new()
	_target_ring.width = 3.5
	_target_ring.default_color = Color(1.0, 0.9, 0.2)
	for i in range(25):
		_target_ring.add_point(Vector2.from_angle(TAU * float(i) / 24.0) * 27.0)
	_target_ring.hide()
	_practice_marker.add_child(_target_ring)

	var input: GameplayInputController = $InputController
	input.combat_target_at = _target_at
	_fire_control = CombatFireButton.new()
	_fire_control.text = "ATEŞ"
	_fire_control.add_theme_font_size_override("font_size", 42)
	_fire_control.size = Vector2(224.0, 132.0)
	_fire_control.mouse_filter = Control.MOUSE_FILTER_STOP
	_fire_control.focus_mode = Control.FOCUS_NONE
	_fire_control.touch_captured.connect(input.reset_touch)
	_fire_control.pressed.connect(_on_fire_pressed)
	$UI.add_child(_fire_control)
	get_viewport().size_changed.connect(_layout_fire_control)
	_layout_fire_control()
	_combat.ship_sunk.connect(_on_ship_sunk)
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


func _on_fire_pressed() -> void:
	var input: GameplayInputController = $InputController
	input.emit_fire_intent(_combat.locked_target(FoundationSector.PLAYER))


func _on_ship_sunk(id: String, _sequence: int) -> void:
	if id == PRACTICE_TARGET:
		_practice_marker.hide()


func _refresh_combat_indicator() -> void:
	if _target_ring == null:
		return
	var locked := _combat.locked_target(FoundationSector.PLAYER) == PRACTICE_TARGET
	_target_ring.visible = locked
	_fire_control.disabled = not locked


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
	var dto := _save_service.create_snapshot(sector, FoundationSector.PLAYER, _ship_motor, _streams, SaveSnapshot.LOCAL, _session_id)
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
