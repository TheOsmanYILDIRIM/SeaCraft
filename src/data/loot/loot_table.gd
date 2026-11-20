class_name LootTable
extends Resource

@export var stable_id: String = ""
@export var entries: Array[LootTableEntry] = []


func valid() -> bool:
	if not SectorIds.valid(stable_id) or entries.is_empty() or entries.size() > 64:
		return false
	var total := 0
	for entry in entries:
		if entry == null or not entry.valid():
			return false
		total += entry.weight
		if total > 2147483647:
			return false
	return total > 0


func roll(streams: SeedStreams) -> Dictionary:
	if streams == null or not valid():
		return {}
	var total := 0
	for entry in entries:
		total += entry.weight
	var roll_value := streams.next_int(SeedStreams.STREAM_LOOT, 1, total)
	var cursor := 0
	for entry in entries:
		cursor += entry.weight
		if roll_value <= cursor:
			var quantity := streams.next_int(SeedStreams.STREAM_LOOT, entry.min_quantity, entry.max_quantity)
			return {"item_id": entry.item_id, "quantity": quantity}
	return {}
