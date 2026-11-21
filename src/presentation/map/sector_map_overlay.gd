class_name SectorMapOverlay
extends Control

enum Mode { MINIMAP, WORLD }

var _mode := Mode.MINIMAP
var _world_snapshot: Dictionary = {}
var _sector_snapshot: Dictionary = {}
var _active_sector_id := ""
var _player_world := Vector2.ZERO
var _pan := Vector2.ZERO
var _zoom := 1.0
var _touch := TouchGestureInterpreter.new()


func configure_world(snapshot: Dictionary, active_sector_id: String) -> void:
	_world_snapshot = snapshot.duplicate(true)
	_active_sector_id = active_sector_id
	_mode = Mode.WORLD
	queue_redraw()


func configure_minimap(snapshot: Dictionary, player_world: Vector2) -> void:
	_sector_snapshot = snapshot.duplicate(true)
	_player_world = player_world
	_mode = Mode.MINIMAP
	queue_redraw()


func set_player_world_position(value: Vector2) -> void:
	if value.is_finite():
		_player_world = value
		queue_redraw()


func set_world_view(open: bool) -> void:
	_mode = Mode.WORLD if open else Mode.MINIMAP
	_pan = Vector2.ZERO
	_zoom = 1.0
	_touch.reset()
	queue_redraw()


func apply_pan(delta: Vector2) -> bool:
	if _mode != Mode.WORLD or not delta.is_finite():
		return false
	_pan += delta
	queue_redraw()
	return true


func apply_zoom(factor: float) -> bool:
	if _mode != Mode.WORLD or not is_finite(factor) or factor <= 0.0:
		return false
	_zoom = clampf(_zoom * factor, 0.5, 4.0)
	queue_redraw()
	return true


func view_state() -> Dictionary:
	return {"mode": _mode, "pan_x": _pan.x, "pan_y": _pan.y, "zoom": _zoom}


func _gui_input(event: InputEvent) -> void:
	if event == null or not visible:
		return
	var consumed := false
	if _mode == Mode.WORLD and event is InputEventScreenTouch:
		var gestures := _touch.press(event.index, event.position) if event.pressed else _touch.release(event.index, event.position)
		for gesture: Dictionary in gestures:
			if gesture["kind"] == "pan":
				apply_pan(Vector2(gesture["delta_x"], gesture["delta_y"]))
			elif gesture["kind"] == "zoom":
				apply_zoom(float(gesture["factor"]))
		consumed = true
	elif _mode == Mode.WORLD and event is InputEventScreenDrag:
		for gesture: Dictionary in _touch.drag(event.index, event.position):
			if gesture["kind"] == "pan":
				apply_pan(Vector2(gesture["delta_x"], gesture["delta_y"]))
			elif gesture["kind"] == "zoom":
				apply_zoom(float(gesture["factor"]))
		consumed = true
	elif _mode == Mode.WORLD and event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_MIDDLE) != 0:
		consumed = apply_pan(event.relative)
	elif _mode == Mode.WORLD and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			consumed = apply_zoom(1.1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			consumed = apply_zoom(1.0 / 1.1)
	elif event is InputEventScreenTouch or event is InputEventMouseButton:
		consumed = true
	if consumed:
		accept_event()


func _draw() -> void:
	if _mode == Mode.WORLD:
		_draw_world()
	else:
		_draw_minimap()


func _draw_world() -> void:
	var nodes: Dictionary = {}
	for raw in _world_snapshot.get("sectors", []):
		var row: Dictionary = raw
		nodes[row["sector_id"]] = Vector2(float(row["map_x"]), float(row["map_y"])) * _zoom + _pan + size * 0.5
	for raw in _world_snapshot.get("connections", []):
		var edge: Dictionary = raw
		if nodes.has(edge["from_sector"]) and nodes.has(edge["to_sector"]):
			draw_line(nodes[edge["from_sector"]], nodes[edge["to_sector"]], Color(0.55, 0.6, 0.65), 2.0)
	for raw in _world_snapshot.get("sectors", []):
		var row: Dictionary = raw
		var point: Vector2 = nodes[row["sector_id"]]
		var radius := 10.0 if row["sector_id"] == _active_sector_id else 7.0
		draw_circle(point, radius, Color(0.85, 0.9, 1.0))
		if bool(row.get("safe_haven", false)):
			draw_arc(point, radius + 5.0, 0.0, TAU, 20, Color(0.55, 1.0, 0.7), 2.0)


func _draw_minimap() -> void:
	var b: Dictionary = _sector_snapshot.get("bounds", {})
	if b.size() != 4:
		return
	var world_bounds := Rect2(float(b["x"]), float(b["y"]), float(b["w"]), float(b["h"]))
	var map_rect := Rect2(Vector2(6, 6), (size - Vector2(12, 12)).max(Vector2(1, 1)))
	draw_rect(map_rect, Color(0.05, 0.07, 0.1, 0.75), true)
	var player := MinimapTransform.world_to_map(_player_world, world_bounds, map_rect, true)
	if player.is_finite():
		draw_circle(player, 4.0, Color(1.0, 1.0, 1.0))
	for raw in _sector_snapshot.get("gates", []):
		var gate: Dictionary = raw
		var p := MinimapTransform.world_to_map(Vector2(float(gate["x"]), float(gate["y"])), world_bounds, map_rect, true)
		if p.is_finite():
			draw_circle(p, 3.0, Color(0.7, 0.85, 1.0))
	for raw in _sector_snapshot.get("safe_zones", []):
		var zone: Dictionary = raw
		var center := MinimapTransform.world_to_map(Vector2(float(zone["x"]), float(zone["y"])), world_bounds, map_rect, true)
		if center.is_finite():
			var edge := MinimapTransform.world_to_map(Vector2(float(zone["x"]) + float(zone["radius"]), float(zone["y"])), world_bounds, map_rect, true)
			draw_arc(center, absf(edge.x - center.x), 0.0, TAU, 24, Color(0.4, 1.0, 0.65), 1.5)
