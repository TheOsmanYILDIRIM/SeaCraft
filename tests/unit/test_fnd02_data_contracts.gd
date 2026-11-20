extends GutTest

const REGISTRY_SCRIPT := preload("res://src/data/registry/definition_registry.gd")
const SHIP_SCRIPT := preload("res://src/data/definitions/ship_definition.gd")
const RUNTIME_STATE_SCRIPT := preload("res://src/simulation/state/entity_runtime_state.gd")
const MODIFIER_PIPELINE := preload("res://src/simulation/stats/stat_modifier_pipeline.gd")
const SEED_STREAMS := preload("res://src/simulation/random/seed_streams.gd")
const DTO_CONTRACT := preload("res://src/data/contracts/dto_contract.gd")
const VERSION_CONTRACT := preload("res://src/data/contracts/data_contract_versions.gd")

const VALID_INDEX := "res://tests/fixtures/content/index"
const DUPLICATE_INDEX := "res://tests/fixtures/content/index_duplicate"
const MISSING_REFERENCE_INDEX := "res://tests/fixtures/content/index_missing_reference"


func test_duplicate_stable_id_is_rejected() -> void:
	var registry = REGISTRY_SCRIPT.new()
	var result: Error = registry.build_from_index_directory(DUPLICATE_INDEX)
	assert_ne(result, OK)
	assert_true(registry.last_error.contains("duplicate stable ID"))


func test_missing_reference_is_rejected() -> void:
	var registry = REGISTRY_SCRIPT.new()
	var result: Error = registry.build_from_index_directory(MISSING_REFERENCE_INDEX)
	assert_ne(result, OK)
	assert_true(registry.last_error.contains("missing reference"))


func test_typed_resources_parse_and_load_lazily_from_registry() -> void:
	var registry = REGISTRY_SCRIPT.new()
	assert_eq(registry.build_from_index_directory(VALID_INDEX), OK)
	assert_eq(registry.indexed_count(), 5)

	for stable_id in [
		"ship.test_sloop",
		"weapon.test_cannon",
		"item.test_scrap",
		"faction.neutral",
		"sector.test_harbor",
	]:
		var definition = registry.load_definition(stable_id)
		assert_not_null(definition)
		assert_eq(definition.stable_id, stable_id)

	var ship = registry.load_definition("ship.test_sloop")
	assert_eq(ship.get_script(), SHIP_SCRIPT)
	assert_eq(ship.visual_profile_id, "visual.placeholder.ship.sloop")


func test_definition_and_runtime_state_are_separate() -> void:
	var ship = ResourceLoader.load(
		"res://tests/fixtures/content/definitions/ship_test_sloop.tres",
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	var runtime_state = RUNTIME_STATE_SCRIPT.new(
		"entity.player.1",
		"ship.test_sloop",
		"sector.test_harbor"
	)
	runtime_state.current_hp = 25.0
	runtime_state.position_x = 14.0
	runtime_state.position_y = -3.0
	runtime_state.inventory = {"item.test_scrap": 4}

	assert_true(ship is Resource)
	assert_false(runtime_state is Resource)
	assert_eq(ship.base_hull_hp, 120.0)
	assert_eq(runtime_state.current_hp, 25.0)

	var definition_properties := _property_names(ship)
	assert_false(definition_properties.has("current_hp"))
	assert_false(definition_properties.has("position_x"))
	assert_false(definition_properties.has("inventory"))

	assert_true(DTO_CONTRACT.is_primitive_safe(runtime_state.to_dto()))


func test_modifier_order_is_deterministic_across_dictionary_iteration_order() -> void:
	var first := {
		"z_mul": {"operation": "multiply", "value": 1.5, "priority": 0},
		"a_flat": {"operation": "flat", "value": 20.0, "priority": 0},
	}
	var second := {
		"a_flat": {"operation": "flat", "value": 20.0, "priority": 0},
		"z_mul": {"operation": "multiply", "value": 1.5, "priority": 0},
	}

	var first_result: float = MODIFIER_PIPELINE.apply_from_dictionary(100.0, first)
	var second_result: float = MODIFIER_PIPELINE.apply_from_dictionary(100.0, second)
	assert_eq(first_result, 180.0)
	assert_eq(second_result, first_result)


func test_same_master_seed_and_stream_reproduce_same_sequence() -> void:
	var first = SEED_STREAMS.new(987654321)
	var second = SEED_STREAMS.new(987654321)

	for index in range(20):
		assert_eq(
			first.next_int(SEED_STREAMS.STREAM_LOOT, 0, 1000000),
			second.next_int(SEED_STREAMS.STREAM_LOOT, 0, 1000000),
			"loot draw %d should match" % index
		)


func test_named_rng_streams_are_independent() -> void:
	var baseline = SEED_STREAMS.new(424242)
	var disturbed = SEED_STREAMS.new(424242)

	var baseline_encounter: Array[int] = []
	for index in range(12):
		baseline_encounter.append(
			baseline.next_int(SEED_STREAMS.STREAM_ENCOUNTER, 0, 1000000)
		)

	for index in range(50):
		disturbed.next_int(SEED_STREAMS.STREAM_LOOT, 0, 1000000)

	var disturbed_encounter: Array[int] = []
	for index in range(12):
		disturbed_encounter.append(
			disturbed.next_int(SEED_STREAMS.STREAM_ENCOUNTER, 0, 1000000)
		)

	assert_eq(disturbed_encounter, baseline_encounter)
	assert_ne(
		SEED_STREAMS.derive_stream_seed(424242, SEED_STREAMS.STREAM_WORLD),
		SEED_STREAMS.derive_stream_seed(424242, SEED_STREAMS.STREAM_LOOT)
	)


func test_rng_snapshot_is_primitive_safe_and_restorable() -> void:
	var source = SEED_STREAMS.new(12345)
	for index in range(7):
		source.next_int(SEED_STREAMS.STREAM_WORLD, 0, 1000)
		source.next_int(SEED_STREAMS.STREAM_LOOT, 0, 1000)

	var snapshot: Dictionary = source.snapshot_state()
	assert_true(DTO_CONTRACT.is_primitive_safe(snapshot))

	var restored = SEED_STREAMS.new(1)
	assert_true(restored.restore_state(snapshot))
	for index in range(10):
		assert_eq(
			source.next_int(SEED_STREAMS.STREAM_WORLD, 0, 1000000),
			restored.next_int(SEED_STREAMS.STREAM_WORLD, 0, 1000000)
		)


func test_dto_contract_rejects_godot_runtime_objects() -> void:
	var valid_dto := {
		"definition_id": "ship.test_sloop",
		"schema_version": VERSION_CONTRACT.SCHEMA_VERSION,
		"alive": true,
		"position": [12.5, -7.0],
		"inventory": {"item.test_scrap": 2},
	}
	assert_true(DTO_CONTRACT.is_primitive_safe(valid_dto))
	assert_true(DTO_CONTRACT.is_stable_id("ship.test_sloop"))

	assert_false(DTO_CONTRACT.is_primitive_safe(Resource.new()))
	var runtime_node := Node.new()
	assert_false(DTO_CONTRACT.is_primitive_safe(runtime_node))
	runtime_node.free()
	assert_false(DTO_CONTRACT.is_primitive_safe(RID()))
	assert_false(DTO_CONTRACT.is_primitive_safe(Callable(self, "_dummy_callable")))


func test_schema_and_content_versions_are_distinct_contract_fields() -> void:
	var stamp: Dictionary = VERSION_CONTRACT.compatibility_stamp()
	assert_eq(stamp["schema_version"], 1)
	assert_eq(stamp["content_version"], "fnd02-fixture-1")
	assert_ne(str(stamp["schema_version"]), stamp["content_version"])
	assert_true(DTO_CONTRACT.is_primitive_safe(stamp))


func _property_names(object: Object) -> PackedStringArray:
	var names := PackedStringArray()
	for property in object.get_property_list():
		names.append(str(property.get("name", "")))
	return names


func _dummy_callable() -> void:
	pass
