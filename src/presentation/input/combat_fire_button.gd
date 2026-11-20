class_name CombatFireButton
extends Button

signal touch_captured

var _finger := -1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		accept_event()
		touch_captured.emit()
		if event.pressed and not event.canceled and not disabled and _finger == -1:
			_finger = event.index
		elif not event.pressed and event.index == _finger:
			_finger = -1
			if not event.canceled and not disabled and Rect2(Vector2.ZERO, size).has_point(event.position):
				pressed.emit()
	elif event is InputEventScreenDrag:
		accept_event()
		if event.index == _finger and not Rect2(Vector2.ZERO, size).has_point(event.position):
			_finger = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		_finger = -1
