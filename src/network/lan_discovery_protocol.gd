class_name LanDiscoveryProtocol
extends RefCounted

const MAGIC := "SEACRAFT_LAN"
const DISCOVERY_VERSION := 1
const MAX_PACKET_BYTES := 512
const MAX_HOST_NAME_BYTES := 32
const MAX_VISIBLE_SESSIONS := 16
const MAX_PACKETS_PER_FRAME := 8
const BEACON_INTERVAL_MS := 500
const TTL_MS := 2500
const GLOBAL_PACKETS_PER_SECOND := 64
const SOURCE_PACKETS_PER_SECOND := 16

const KEYS := [
	"magic", "discovery_version", "protocol_version", "schema_version", "content_version",
	"rng_stream_version", "content_manifest_algorithm", "content_hash", "manifest_entry_count",
	"session_id", "host_name", "game_port", "player_count", "max_players",
]


static func sanitize_host_name(value: String) -> String:
	var out := ""
	for index in value.length():
		var code := value.unicode_at(index)
		if (code >= 48 and code <= 57) or (code >= 65 and code <= 90) or (code >= 97 and code <= 122) or code in [32, 45, 46, 95]:
			out += char(code)
		if out.to_utf8_buffer().size() >= MAX_HOST_NAME_BYTES:
			while out.to_utf8_buffer().size() > MAX_HOST_NAME_BYTES:
				out = out.left(out.length() - 1)
			break
	out = out.strip_edges()
	return out if not out.is_empty() else "SeaCraft"


static func make_beacon(session_id: String, host_name: String, game_port: int, player_count: int, max_players: int) -> Dictionary:
	var stamp := SessionProtocol.compatibility_stamp()
	return {
		"magic": MAGIC,
		"discovery_version": DISCOVERY_VERSION,
		"protocol_version": int(stamp["protocol_version"]),
		"schema_version": int(stamp["schema_version"]),
		"content_version": str(stamp["content_version"]),
		"rng_stream_version": int(stamp["rng_stream_version"]),
		"content_manifest_algorithm": str(stamp["content_manifest_algorithm"]),
		"content_hash": str(stamp["content_hash"]),
		"manifest_entry_count": int(stamp["manifest_entry_count"]),
		"session_id": session_id,
		"host_name": sanitize_host_name(host_name),
		"game_port": game_port,
		"player_count": player_count,
		"max_players": max_players,
	}


static func encode_beacon(beacon: Dictionary) -> PackedByteArray:
	if not validate_beacon(beacon):
		return PackedByteArray()
	var data := JSON.stringify(beacon).to_utf8_buffer()
	return data if data.size() <= MAX_PACKET_BYTES else PackedByteArray()


static func parse_packet(packet: PackedByteArray) -> Dictionary:
	if packet.is_empty() or packet.size() > MAX_PACKET_BYTES:
		return {}
	var text := packet.get_string_from_utf8()
	if text.to_utf8_buffer() != packet:
		return {}
	for key in KEYS:
		if text.count('"' + key + '"') != 1:
			return {}
	var value: Variant = JSON.parse_string(text)
	if not value is Dictionary:
		return {}
	var beacon: Dictionary = value
	if not _has_exact_keys(beacon):
		return {}
	for key in ["discovery_version", "protocol_version", "schema_version", "rng_stream_version", "manifest_entry_count", "game_port", "player_count", "max_players"]:
		var normalized: Variant = _normalized_int(beacon[key])
		if normalized == null:
			return {}
		beacon[key] = int(normalized)
	if not validate_beacon(beacon):
		return {}
	return beacon


static func validate_beacon(beacon: Dictionary) -> bool:
	if not _has_exact_keys(beacon):
		return false
	for key in ["magic", "content_version", "content_manifest_algorithm", "content_hash", "session_id", "host_name"]:
		if not beacon[key] is String:
			return false
	for key in ["discovery_version", "protocol_version", "schema_version", "rng_stream_version", "manifest_entry_count", "game_port", "player_count", "max_players"]:
		if not beacon[key] is int:
			return false
	if beacon["magic"] != MAGIC or int(beacon["discovery_version"]) != DISCOVERY_VERSION:
		return false
	if not SessionProtocol.valid_port(int(beacon["game_port"])):
		return false
	if not str(beacon["session_id"]).begins_with("session.") or not SectorIds.valid(str(beacon["session_id"])):
		return false
	var host_name := str(beacon["host_name"])
	if host_name.is_empty() or host_name != sanitize_host_name(host_name) or host_name.to_utf8_buffer().size() > MAX_HOST_NAME_BYTES:
		return false
	var hash := str(beacon["content_hash"])
	if hash.length() != 64 or not _is_lower_hex(hash):
		return false
	if str(beacon["content_version"]).is_empty() or str(beacon["content_version"]).length() > SessionProtocol.MAX_STRING_LENGTH:
		return false
	if str(beacon["content_manifest_algorithm"]).is_empty() or str(beacon["content_manifest_algorithm"]).length() > 32:
		return false
	var player_count := int(beacon["player_count"])
	var max_players := int(beacon["max_players"])
	if player_count < 0 or max_players <= 0 or max_players > SessionProtocol.MAX_PEERS or player_count > max_players:
		return false
	if int(beacon["manifest_entry_count"]) < 0:
		return false
	return SessionProtocol.primitive_safe(beacon)


static func compatible(beacon: Dictionary) -> bool:
	if not validate_beacon(beacon):
		return false
	var stamp := SessionProtocol.compatibility_stamp()
	return (
		int(beacon["protocol_version"]) == int(stamp["protocol_version"])
		and int(beacon["schema_version"]) == int(stamp["schema_version"])
		and str(beacon["content_version"]) == str(stamp["content_version"])
		and int(beacon["rng_stream_version"]) == int(stamp["rng_stream_version"])
		and str(beacon["content_manifest_algorithm"]) == str(stamp["content_manifest_algorithm"])
		and str(beacon["content_hash"]) == str(stamp["content_hash"])
		and int(beacon["manifest_entry_count"]) == int(stamp["manifest_entry_count"])
	)


static func _has_exact_keys(value: Dictionary) -> bool:
	if value.size() != KEYS.size():
		return false
	for key in KEYS:
		if not value.has(key):
			return false
	return true


static func _normalized_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float:
		var number := float(value)
		if is_finite(number) and number == floor(number) and absf(number) <= float(SessionProtocol.MAX_SEQUENCE):
			return int(number)
	return null


static func _is_lower_hex(value: String) -> bool:
	for index in value.length():
		var code := value.unicode_at(index)
		if not ((code >= 48 and code <= 57) or (code >= 97 and code <= 102)):
			return false
	return true
