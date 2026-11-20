class_name SeedStreams
extends RefCounted

const STREAM_WORLD: String = "world"
const STREAM_ENCOUNTER: String = "encounter"
const STREAM_LOOT: String = "loot"
const STREAM_NAMES := [STREAM_WORLD, STREAM_ENCOUNTER, STREAM_LOOT]

const SEED_MODULUS: int = 2147483647
const SEED_MULTIPLIER: int = 131

var _master_seed: int = 1
var _rng_by_stream: Dictionary = {}


func _init(master_seed: int = 1) -> void:
	reset(master_seed)


func reset(master_seed: int) -> void:
	_master_seed = master_seed
	_rng_by_stream.clear()
	for stream_name in STREAM_NAMES:
		var rng := RandomNumberGenerator.new()
		rng.seed = derive_stream_seed(master_seed, stream_name)
		_rng_by_stream[stream_name] = rng


static func derive_stream_seed(master_seed: int, stream_name: String) -> int:
	var derived := posmod(master_seed, SEED_MODULUS)
	if derived == 0:
		derived = 1
	for byte in stream_name.to_utf8_buffer():
		derived = int((derived * SEED_MULTIPLIER + int(byte) + 17) % SEED_MODULUS)
		if derived == 0:
			derived = 1
	return derived


func next_int(stream_name: String, minimum: int, maximum: int) -> int:
	var rng := _get_stream(stream_name)
	if rng == null:
		return minimum
	return rng.randi_range(minimum, maximum)


func next_float(stream_name: String) -> float:
	var rng := _get_stream(stream_name)
	if rng == null:
		return 0.0
	return rng.randf()


func snapshot_state() -> Dictionary:
	var streams: Dictionary = {}
	for stream_name in STREAM_NAMES:
		var rng := _rng_by_stream[stream_name] as RandomNumberGenerator
		streams[stream_name] = {
			"derived_seed": derive_stream_seed(_master_seed, stream_name),
			"state": rng.state,
		}

	return {
		"schema_version": DataContractVersions.SCHEMA_VERSION,
		"rng_stream_version": DataContractVersions.RNG_STREAM_VERSION,
		"master_seed": _master_seed,
		"streams": streams,
	}


func restore_state(snapshot: Dictionary) -> bool:
	if not DtoContract.is_primitive_safe(snapshot):
		return false
	if int(snapshot.get("schema_version", -1)) != DataContractVersions.SCHEMA_VERSION:
		return false
	if int(snapshot.get("rng_stream_version", -1)) != DataContractVersions.RNG_STREAM_VERSION:
		return false

	var streams: Dictionary = snapshot.get("streams", {})
	var master_seed := int(snapshot.get("master_seed", 0))
	reset(master_seed)

	for stream_name in STREAM_NAMES:
		if not streams.has(stream_name):
			return false
		var stream_state: Dictionary = streams[stream_name]
		var expected_seed := derive_stream_seed(master_seed, stream_name)
		if int(stream_state.get("derived_seed", -1)) != expected_seed:
			return false
		var rng := _rng_by_stream[stream_name] as RandomNumberGenerator
		rng.state = int(stream_state.get("state", 0))
	return true


func _get_stream(stream_name: String) -> RandomNumberGenerator:
	if not _rng_by_stream.has(stream_name):
		push_error("Unknown RNG stream: %s" % stream_name)
		return null
	return _rng_by_stream[stream_name] as RandomNumberGenerator
