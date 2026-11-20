extends Node

const BOOT_MARKER := "SeaCraft bootstrap ready"

@onready var _ship_motor: ShipMotor = $ShipMotor


func _ready() -> void:
	print(BOOT_MARKER)


func _on_gameplay_command(command: Dictionary) -> void:
	_ship_motor.apply_authoritative_command(command)
