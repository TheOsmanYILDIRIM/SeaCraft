extends Node2D

const BOOT_MARKER := "SeaCraft bootstrap ready"

const CHECKPOINT_INTERVAL_MS := 20000

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
	print(BOOT_MARKER)


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	var position_now := _ship_motor.global_position
	_world.active().move_entity(FoundationSector.PLAYER, position_now)
	if position_now != _last_position or _ship_motor.velocity != _last_velocity or _ship_motor.rotation != _last_heading or _ship_motor.has_target() != _observed_target:
		_save_service.mark_dirty()
	_last_position = position_now
	_last_velocity = _ship_motor.velocity
	_last_heading = _ship_motor.rotation
	_observed_target = _ship_motor.has_target()


func _on_gameplay_command(command: Dictionary) -> void:
	if active_sector() != null and _ship_motor.apply_authoritative_command(command):
		_save_service.mark_dirty()


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
