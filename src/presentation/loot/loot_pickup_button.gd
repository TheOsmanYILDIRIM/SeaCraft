class_name LootPickupButton
extends Button

signal touch_captured


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		touch_captured.emit()
		accept_event()
