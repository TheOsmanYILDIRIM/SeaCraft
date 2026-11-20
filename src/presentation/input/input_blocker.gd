extends ColorRect


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP


func _gui_input(event: InputEvent) -> void:
	if (
		event is InputEventMouseButton
		or event is InputEventMouseMotion
		or event is InputEventScreenTouch
		or event is InputEventScreenDrag
	):
		accept_event()
