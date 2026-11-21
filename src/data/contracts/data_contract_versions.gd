class_name DataContractVersions
extends RefCounted

const SCHEMA_VERSION: int = 2
const CONTENT_VERSION: String = "core04-registry-1"
const RNG_STREAM_VERSION: int = 1


static func compatibility_stamp() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"content_version": CONTENT_VERSION,
		"rng_stream_version": RNG_STREAM_VERSION,
	}
