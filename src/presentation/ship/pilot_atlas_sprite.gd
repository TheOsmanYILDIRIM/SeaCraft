extends Sprite2D
## Presentation-only: world +X is east, +Y is south. The atlas pivot is centered.

var _heading_source: Node2D


static func frame_for_heading(heading: float) -> int:
	return posmod(roundi(heading / (PI / 4.0)) + 2, 8)


func bind_heading(source: Node2D) -> void:
	_heading_source = source
	_process(0.0)


func _process(_delta: float) -> void:
	if is_instance_valid(_heading_source):
		global_rotation = 0.0
		frame = frame_for_heading(_heading_source.global_rotation)
