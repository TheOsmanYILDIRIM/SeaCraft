extends Node2D

const BOOT_MARKER := "SeaCraft bootstrap ready"

var _world: SectorWorld
@onready var _ship_motor: ShipMotor = $ShipMotor


func _ready() -> void:
	var authority := RefCounted.new()
	_world = SectorWorld.new(FoundationSector.graph(), authority)
	if not _world.activate_initial(authority, FoundationSector.ID, FoundationSector.ENTRY, FoundationSector.PLAYER):
		push_error("SeaCraft foundation sector failed to load")
		set_physics_process(false)
		_ship_motor.set_physics_process(false)
		return
	var sector := _world.active()
	var anchor := sector.anchor(FoundationSector.ENTRY)
	_ship_motor.global_position = anchor.position
	_ship_motor.rotation = anchor.heading
	_ship_motor.cancel_target()
	_ship_motor.collision_layer = FoundationSector.SHIP_LAYER
	_ship_motor.collision_mask = FoundationSector.COAST_LAYER
	_ship_motor.process_physics_priority = -1
	_build_sector_geometry(sector)
	print(BOOT_MARKER)


func active_sector() -> SectorRuntime:
	return _world.active() if _world != null else null


func _physics_process(_delta: float) -> void:
	_world.active().move_entity(FoundationSector.PLAYER, _ship_motor.global_position)


func _on_gameplay_command(command: Dictionary) -> void:
	if active_sector() != null:
		_ship_motor.apply_authoritative_command(command)


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
