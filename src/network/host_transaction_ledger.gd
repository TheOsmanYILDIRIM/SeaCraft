class_name HostTransactionLedger
extends RefCounted

const MAX_ENTRIES := 128
const MAX_TRANSACTION_ID_LENGTH := 96
const OP_PICKUP_LOOT := "pickup_loot"
const OP_INVENTORY_TRANSFER := InventoryState.OP_TRANSFER
const OP_INVENTORY_EQUIP := InventoryState.OP_EQUIP
const OP_INVENTORY_UNEQUIP := InventoryState.OP_UNEQUIP
const OP_INVENTORY_SOCKET_INSERT := InventoryState.OP_SOCKET_INSERT
const OP_INVENTORY_SOCKET_UPGRADE := InventoryState.OP_SOCKET_UPGRADE
const OP_INVENTORY_PRESET_APPLY := InventoryState.OP_PRESET_APPLY
const STATUS_NEW := "new"
const STATUS_CACHED := "cached"
const STATUS_CONFLICT := "conflict"
const STATUS_FULL := "full"

var _entries: Dictionary = {}
var _commit_sequence := 0


func inspect(actor_id: String, transaction_id: String, operation: String, fingerprint: String) -> Dictionary:
	if not valid_transaction_id(transaction_id) or not SectorIds.valid(actor_id) or operation.is_empty() or fingerprint.length() != 64:
		return {"status": STATUS_CONFLICT, "result": {}}
	var key := _key(actor_id, transaction_id)
	if _entries.has(key):
		var entry: Dictionary = _entries[key]
		if str(entry["operation"]) != operation or str(entry["fingerprint"]) != fingerprint:
			return {"status": STATUS_CONFLICT, "result": {}}
		return {"status": STATUS_CACHED, "result": (entry["result"] as Dictionary).duplicate(true)}
	if _entries.size() >= MAX_ENTRIES:
		return {"status": STATUS_FULL, "result": {}}
	return {"status": STATUS_NEW, "result": {}}


func commit(actor_id: String, transaction_id: String, operation: String, fingerprint: String, result: Dictionary) -> bool:
	if inspect(actor_id, transaction_id, operation, fingerprint)["status"] != STATUS_NEW:
		return false
	if not SessionProtocol.primitive_safe(result) or result.size() > 8 or _commit_sequence >= SessionProtocol.MAX_SEQUENCE:
		return false
	_commit_sequence += 1
	_entries[_key(actor_id, transaction_id)] = {
		"actor_id": actor_id,
		"transaction_id": transaction_id,
		"operation": operation,
		"fingerprint": fingerprint,
		"result": result.duplicate(true),
		"commit_sequence": _commit_sequence,
	}
	return true


func snapshot_state() -> Dictionary:
	var keys := _entries.keys()
	keys.sort()
	var rows: Array = []
	for key in keys:
		rows.append((_entries[key] as Dictionary).duplicate(true))
	return {"version": 1, "commit_sequence": _commit_sequence, "entries": rows}


func restore_state(value: Variant) -> bool:
	if not value is Dictionary or not SessionProtocol.primitive_safe(value):
		return false
	var state: Dictionary = value
	if state.size() != 3 or int(state.get("version", 0)) != 1 or not state.get("entries") is Array:
		return false
	var sequence_value: Variant = state.get("commit_sequence")
	if not sequence_value is int or int(sequence_value) < 0 or int(sequence_value) > SessionProtocol.MAX_SEQUENCE:
		return false
	var rows: Array = state["entries"]
	if rows.size() > MAX_ENTRIES:
		return false
	var next: Dictionary = {}
	var max_sequence := 0
	for raw in rows:
		if not raw is Dictionary:
			return false
		var row: Dictionary = raw
		if row.size() != 6 or not valid_transaction_id(str(row.get("transaction_id", ""))) or not SectorIds.valid(str(row.get("actor_id", ""))):
			return false
		if not row.get("operation") is String or str(row["operation"]).is_empty() or not row.get("fingerprint") is String or str(row["fingerprint"]).length() != 64:
			return false
		if not row.get("result") is Dictionary or not row.get("commit_sequence") is int:
			return false
		var seq := int(row["commit_sequence"])
		if seq <= 0 or seq > int(sequence_value):
			return false
		var key := _key(str(row["actor_id"]), str(row["transaction_id"]))
		if next.has(key):
			return false
		next[key] = row.duplicate(true)
		max_sequence = maxi(max_sequence, seq)
	if max_sequence > int(sequence_value):
		return false
	_entries = next
	_commit_sequence = int(sequence_value)
	return true


func commit_sequence() -> int:
	return _commit_sequence


func size() -> int:
	return _entries.size()


static func valid_transaction_id(value: String) -> bool:
	return not value.is_empty() and value.length() <= MAX_TRANSACTION_ID_LENGTH and value.begins_with("txn.") and SectorIds.valid(value)


static func fingerprint(operation: String, payload: Dictionary) -> String:
	return (operation + "|" + JSON.stringify(payload)).sha256_text()


static func _key(actor_id: String, transaction_id: String) -> String:
	return actor_id + "|" + transaction_id
