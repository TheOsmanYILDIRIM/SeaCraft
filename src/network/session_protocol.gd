class_name SessionProtocol
extends RefCounted

const DATA_VERSIONS := preload("res://src/data/contracts/data_contract_versions.gd")
const CONTENT_MANIFEST := preload("res://src/data/registry/content_manifest.gd")
const COMMANDS := preload("res://src/simulation/commands/gameplay_command.gd")

const PROTOCOL_VERSION: int = 1
const CHANNEL_CONTROL: int = 0
const CHANNEL_GAMEPLAY: int = 1
const CHANNEL_SNAPSHOT: int = 2
const CHANNEL_COUNT: int = 3
const MAX_PEERS: int = 4
const MIN_PORT: int = 1024
const MAX_PORT: int = 65535
const MAX_SEQUENCE: int = 2147483647
const MAX_CONTAINER_ITEMS: int = 16
const MAX_CONTAINERS: int = 32
const MAX_DEPTH: int = 4
const MAX_STRING_LENGTH: int = 128
const MAX_ABS_NUMBER: float = 1.0e9

const REJECT_PROTOCOL_MISMATCH := "protocol mismatch"
const REJECT_SCHEMA_MISMATCH := "schema/version mismatch"
const REJECT_CONTENT_VERSION_MISMATCH := "content version mismatch"
const REJECT_CONTENT_HASH_MISMATCH := "content hash mismatch"
const REJECT_MALFORMED_HANDSHAKE := "malformed handshake"
const REJECT_SERVER_FULL := "server full"
const REJECT_PRE_HANDSHAKE := "pre-handshake intent"
const REJECT_FORBIDDEN_IDENTITY := "forbidden identity field"
const REJECT_SEQUENCE := "invalid sequence"
const REJECT_REPLAY := "sequence replay"
const REJECT_MALFORMED_ENVELOPE := "malformed envelope"
const REJECT_MALFORMED_PAYLOAD := "malformed payload"
const REJECT_UNSUPPORTED_INTENT := "unsupported intent"
const REJECT_AUTHORITY_COMMAND := "authority command rejected"

const FORBIDDEN_IDENTITY_FIELDS := [
	"player_id", "peer_id", "entity_id", "owner_id", "authority_id",
]
const HANDSHAKE_KEYS := [
	"protocol_version",
	"schema_version",
	"content_version",
	"rng_stream_version",
	"content_manifest_algorithm",
	"content_hash",
	"manifest_entry_count",
]
const ENVELOPE_KEYS := ["protocol_version", "client_sequence", "intent_type", "payload"]
const NETWORK_INTENTS := [
	COMMANDS.MOVE_TO_WORLD_POSITION,
	COMMANDS.SELECT_WORLD_POSITION,
	COMMANDS.CANCEL,
	COMMANDS.TARGET_CYCLE,
]


static func compatibility_stamp() -> Dictionary:
	var versions: Dictionary = DATA_VERSIONS.compatibility_stamp()
	var manifest: Dictionary = CONTENT_MANIFEST.metadata()
	return {
		"protocol_version": PROTOCOL_VERSION,
		"schema_version": int(versions["schema_version"]),
		"content_version": str(versions["content_version"]),
		"rng_stream_version": int(versions["rng_stream_version"]),
		"content_manifest_algorithm": str(manifest["algorithm"]),
		"content_hash": str(manifest["hash"]),
		"manifest_entry_count": int(manifest["entry_count"]),
	}


static func channel_policy() -> Dictionary:
	return {
		"control": {"channel": CHANNEL_CONTROL, "mode": "reliable"},
		"gameplay_intent": {"channel": CHANNEL_GAMEPLAY, "mode": "reliable"},
		"snapshot_reserved": {"channel": CHANNEL_SNAPSHOT, "mode": "unreliable_ordered"},
	}


static func client_hello(overrides: Dictionary = {}) -> Dictionary:
	var hello := compatibility_stamp().duplicate(true)
	for key in overrides:
		if hello.has(key):
			hello[key] = overrides[key]
	return hello


static func validate_handshake(value: Variant) -> String:
	if not value is Dictionary:
		return REJECT_MALFORMED_HANDSHAKE
	var hello: Dictionary = value
	if not _has_exact_keys(hello, HANDSHAKE_KEYS):
		return REJECT_MALFORMED_HANDSHAKE
	if not _is_int(hello["protocol_version"]) or not _is_int(hello["schema_version"]) or not _is_int(hello["rng_stream_version"]) or not _is_int(hello["manifest_entry_count"]):
		return REJECT_MALFORMED_HANDSHAKE
	if not hello["content_version"] is String or not hello["content_manifest_algorithm"] is String or not hello["content_hash"] is String:
		return REJECT_MALFORMED_HANDSHAKE
	if str(hello["content_hash"]).length() != 64 or str(hello["content_manifest_algorithm"]).is_empty() or str(hello["content_version"]).is_empty():
		return REJECT_MALFORMED_HANDSHAKE
	if int(hello["manifest_entry_count"]) < 0:
		return REJECT_MALFORMED_HANDSHAKE
	var expected := compatibility_stamp()
	if int(hello["protocol_version"]) != int(expected["protocol_version"]):
		return REJECT_PROTOCOL_MISMATCH
	if int(hello["schema_version"]) != int(expected["schema_version"]) or int(hello["rng_stream_version"]) != int(expected["rng_stream_version"]):
		return REJECT_SCHEMA_MISMATCH
	if str(hello["content_version"]) != str(expected["content_version"]):
		return REJECT_CONTENT_VERSION_MISMATCH
	if str(hello["content_manifest_algorithm"]) != str(expected["content_manifest_algorithm"]) or str(hello["content_hash"]) != str(expected["content_hash"]) or int(hello["manifest_entry_count"]) != int(expected["manifest_entry_count"]):
		return REJECT_CONTENT_HASH_MISMATCH
	return ""


static func make_envelope(client_sequence: int, intent_type: String, payload: Dictionary) -> Dictionary:
	return {
		"protocol_version": PROTOCOL_VERSION,
		"client_sequence": client_sequence,
		"intent_type": intent_type,
		"payload": payload.duplicate(true),
	}


static func validate_envelope(value: Variant) -> String:
	if _contains_forbidden_identity(value, 0):
		return REJECT_FORBIDDEN_IDENTITY
	if not value is Dictionary:
		return REJECT_MALFORMED_ENVELOPE
	var envelope: Dictionary = value
	if not _has_exact_keys(envelope, ENVELOPE_KEYS):
		return REJECT_MALFORMED_ENVELOPE
	if not _is_int(envelope["protocol_version"]) or int(envelope["protocol_version"]) != PROTOCOL_VERSION:
		return REJECT_PROTOCOL_MISMATCH
	if not _is_int(envelope["client_sequence"]) or int(envelope["client_sequence"]) < 0 or int(envelope["client_sequence"]) > MAX_SEQUENCE:
		return REJECT_SEQUENCE
	if not envelope["intent_type"] is String:
		return REJECT_MALFORMED_ENVELOPE
	var intent_type := str(envelope["intent_type"])
	if intent_type.length() > MAX_STRING_LENGTH or not NETWORK_INTENTS.has(intent_type):
		return REJECT_UNSUPPORTED_INTENT
	if not envelope["payload"] is Dictionary:
		return REJECT_MALFORMED_PAYLOAD
	var payload: Dictionary = envelope["payload"]
	var state := {"containers": 0}
	if not _primitive_safe(payload, 0, state):
		return REJECT_MALFORMED_PAYLOAD
	return _validate_intent_payload(intent_type, payload)


static func validate_sequence(sequence_value: Variant, last_sequence: int) -> String:
	if not _is_int(sequence_value):
		return REJECT_SEQUENCE
	var sequence := int(sequence_value)
	if sequence < 0 or sequence > MAX_SEQUENCE:
		return REJECT_SEQUENCE
	if sequence <= last_sequence:
		return REJECT_REPLAY
	return ""


static func payload_for_command(command: Dictionary) -> Dictionary:
	if str(command.get("domain", "")) != COMMANDS.DOMAIN_GAMEPLAY:
		return {}
	match str(command.get("type", "")):
		COMMANDS.MOVE_TO_WORLD_POSITION, COMMANDS.SELECT_WORLD_POSITION:
			if not command.has("world_x") or not command.has("world_y"):
				return {}
			return {"world_x": command["world_x"], "world_y": command["world_y"]}
		COMMANDS.CANCEL:
			return {}
		COMMANDS.TARGET_CYCLE:
			if not command.has("direction"):
				return {}
			return {"direction": command["direction"]}
		_:
			return {}


static func command_to_envelope(command: Dictionary, client_sequence: int) -> Dictionary:
	if str(command.get("domain", "")) != COMMANDS.DOMAIN_GAMEPLAY:
		return {}
	var intent_type := str(command.get("type", ""))
	if not NETWORK_INTENTS.has(intent_type):
		return {}
	var payload := payload_for_command(command)
	if validate_envelope(make_envelope(client_sequence, intent_type, payload)) != "":
		return {}
	return make_envelope(client_sequence, intent_type, payload)


static func to_gameplay_command(envelope: Dictionary) -> Dictionary:
	if validate_envelope(envelope) != "":
		return {}
	var payload: Dictionary = envelope["payload"]
	match str(envelope["intent_type"]):
		COMMANDS.MOVE_TO_WORLD_POSITION:
			return COMMANDS.move_to_world_position(Vector2(float(payload["world_x"]), float(payload["world_y"])))
		COMMANDS.SELECT_WORLD_POSITION:
			return COMMANDS.select_world_position(Vector2(float(payload["world_x"]), float(payload["world_y"])))
		COMMANDS.CANCEL:
			return COMMANDS.cancel()
		COMMANDS.TARGET_CYCLE:
			return COMMANDS.target_cycle(int(payload["direction"]))
		_:
			return {}


static func next_available_player_id(player_ids: Array[String], mapped_ids: Array[String]) -> String:
	var ordered := player_ids.duplicate()
	ordered.sort()
	for player_id in ordered:
		if not mapped_ids.has(player_id):
			return player_id
	return ""


static func valid_ipv4(address: String) -> bool:
	if address.is_empty() or address.length() > 15:
		return false
	var parts := address.split(".", false)
	if parts.size() != 4:
		return false
	for part in parts:
		var text := str(part)
		if text.is_empty() or not text.is_valid_int():
			return false
		if text.length() > 1 and text.begins_with("0"):
			return false
		var octet := int(text)
		if octet < 0 or octet > 255:
			return false
	return true


static func valid_port(port: int) -> bool:
	return port >= MIN_PORT and port <= MAX_PORT


static func _validate_intent_payload(intent_type: String, payload: Dictionary) -> String:
	match intent_type:
		COMMANDS.MOVE_TO_WORLD_POSITION, COMMANDS.SELECT_WORLD_POSITION:
			if not _has_exact_keys(payload, ["world_x", "world_y"]):
				return REJECT_MALFORMED_PAYLOAD
			if not _is_number(payload["world_x"]) or not _is_number(payload["world_y"]):
				return REJECT_MALFORMED_PAYLOAD
			var x := float(payload["world_x"])
			var y := float(payload["world_y"])
			if not is_finite(x) or not is_finite(y) or absf(x) > MAX_ABS_NUMBER or absf(y) > MAX_ABS_NUMBER:
				return REJECT_MALFORMED_PAYLOAD
		COMMANDS.CANCEL:
			if not payload.is_empty():
				return REJECT_MALFORMED_PAYLOAD
		COMMANDS.TARGET_CYCLE:
			if not _has_exact_keys(payload, ["direction"]) or not _is_int(payload["direction"]):
				return REJECT_MALFORMED_PAYLOAD
			if abs(int(payload["direction"])) != 1:
				return REJECT_MALFORMED_PAYLOAD
		_:
			return REJECT_UNSUPPORTED_INTENT
	return ""


static func _primitive_safe(value: Variant, depth: int, state: Dictionary) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT:
			return true
		TYPE_FLOAT:
			return is_finite(float(value)) and absf(float(value)) <= MAX_ABS_NUMBER
		TYPE_STRING:
			return str(value).length() <= MAX_STRING_LENGTH
		TYPE_ARRAY:
			var array: Array = value
			if array.size() > MAX_CONTAINER_ITEMS:
				return false
			state["containers"] = int(state["containers"]) + 1
			if int(state["containers"]) > MAX_CONTAINERS:
				return false
			for item in array:
				if not _primitive_safe(item, depth + 1, state):
					return false
			return true
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value
			if dictionary.size() > MAX_CONTAINER_ITEMS:
				return false
			state["containers"] = int(state["containers"]) + 1
			if int(state["containers"]) > MAX_CONTAINERS:
				return false
			for key in dictionary:
				if not key is String or str(key).length() > MAX_STRING_LENGTH:
					return false
				if not _primitive_safe(dictionary[key], depth + 1, state):
					return false
			return true
		_:
			return false


static func _contains_forbidden_identity(value: Variant, depth: int) -> bool:
	if depth > MAX_DEPTH + 1:
		return false
	if value is Dictionary:
		var dictionary: Dictionary = value
		for key in dictionary:
			if key is String and FORBIDDEN_IDENTITY_FIELDS.has(str(key)):
				return true
			if _contains_forbidden_identity(dictionary[key], depth + 1):
				return true
	elif value is Array:
		for item in value:
			if _contains_forbidden_identity(item, depth + 1):
				return true
	return false


static func _has_exact_keys(dictionary: Dictionary, keys: Array) -> bool:
	if dictionary.size() != keys.size():
		return false
	for key in keys:
		if not dictionary.has(key):
			return false
	return true


static func _is_number(value: Variant) -> bool:
	return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT


static func _is_int(value: Variant) -> bool:
	return typeof(value) == TYPE_INT
