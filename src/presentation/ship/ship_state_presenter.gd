class_name ShipStatePresenter
extends Polygon2D

@export var simulation_target_path: NodePath

var _simulation_target: Node2D


func _ready() -> void:
	_simulation_target = get_node_or_null(simulation_target_path) as Node2D
	_sync_from_simulation()


func _process(_delta: float) -> void:
	_sync_from_simulation()


func _sync_from_simulation() -> void:
	if _simulation_target == null:
		return
	global_position = _simulation_target.global_position
	global_rotation = _simulation_target.global_rotation
