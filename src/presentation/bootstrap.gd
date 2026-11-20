extends Node

const BOOT_MARKER := "SeaCraft bootstrap ready"


func _ready() -> void:
	print(BOOT_MARKER)
