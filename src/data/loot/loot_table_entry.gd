class_name LootTableEntry
extends Resource

@export var item_id: String = ""
@export var min_quantity: int = 1
@export var max_quantity: int = 1
@export var weight: int = 1


func valid() -> bool:
	return SectorIds.valid(item_id) and min_quantity > 0 and max_quantity >= min_quantity and max_quantity <= 1000000 and weight > 0 and weight <= 1000000
