extends GutTest

const BOOT := preload("res://src/presentation/bootstrap.tscn")
const A := "sector.alpha"
const B := "sector.beta"
const ENTITY_ID := "entity.probe"
const ENTRY := "anchor.entry"
const GATE := "gate.alpha_beta"
const A_PATH := "res://not_loaded_alpha.tres"
const B_PATH := "res://not_loaded_beta.tres"

var _loads: Array[String]


func before_each() -> void:
	_loads = []


func test_bootstrap_is_deterministic() -> void:
	var first := BOOT.instantiate()
	var second := BOOT.instantiate()
	first.set("_save_service", SaveService.new("user://seacraft-fnd05-determinism-test"))
	second.set("_save_service", SaveService.new("user://seacraft-fnd05-determinism-test"))
	add_child_autofree(first)
	add_child_autofree(second)
	assert_not_null(first.active_sector())
	assert_eq(first.active_sector().sector_id, FoundationSector.ID)
	assert_eq(first.get_node("ShipMotor").position, second.get_node("ShipMotor").position)
	assert_eq(first.get_node("ShipMotor").position, Vector2(-240, 0))
	assert_eq(first.active_sector().entity_position(FoundationSector.PLAYER), Vector2(-240, 0))


func test_typed_sector_resource_loads() -> void:
	var definition := _fixture()
	assert_not_null(definition)
	assert_eq(definition.definition_type(), "sector")
	assert_true(definition.navigation_fixture is SectorNavigationFixture)
	assert_true(definition.spawn_anchors[0] is SectorAnchor)


func test_runtime_does_not_modify_definition() -> void:
	var definition := _fixture()
	var runtime := SectorRuntime.build(definition)
	assert_true(runtime.register_entity(ENTITY_ID, Vector2(-200, 0)))
	assert_true(runtime.move_entity(ENTITY_ID, Vector2(-210, 0)))
	runtime.anchor(FoundationSector.ENTRY).position = Vector2.ZERO
	assert_eq(definition.spawn_anchors[0].position, Vector2(-240, 0))
	assert_eq(runtime.anchor(FoundationSector.ENTRY).position, Vector2(-240, 0))
	assert_eq(SectorRuntime.build(definition).entity_position(ENTITY_ID), Vector2.INF)


func test_bad_stable_ids_rejected() -> void:
	for id in ["", "sector..id", "sector./file", "sector.Mixed", "sector."]:
		assert_false(SectorIds.valid(id))
	var definition := _fixture()
	definition.stable_id = "sector/invalid"
	assert_null(SectorRuntime.build(definition))


func test_duplicate_sector() -> void:
	var rows := _rows()
	rows.append(rows[0])
	assert_eq(SectorGraph.new().configure(rows, [_edge()], A), "duplicate_sector")


func test_unknown_source() -> void:
	var edge := _edge()
	edge.from_sector = "sector.missing"
	assert_eq(SectorGraph.new().configure(_rows(), [edge], A), "unknown_sector")


func test_unknown_destination() -> void:
	var edge := _edge()
	edge.to_sector = "sector.missing"
	assert_eq(SectorGraph.new().configure(_rows(), [edge], A), "invalid_destination")


func test_disconnected_sector() -> void:
	assert_eq(SectorGraph.new().configure(_rows(), [], A), "disconnected_sector")


func test_duplicate_gate() -> void:
	assert_eq(SectorGraph.new().configure(_rows(), [_edge(), _edge()], A), "duplicate_gate")


func test_invalid_transition() -> void:
	var gate := _edge()
	gate.activation_radius = INF
	assert_eq(SectorGraph.new().configure(_rows(), [gate], A), "invalid_transition")
	gate.activation_radius = 32.0
	gate.to_sector = A
	assert_eq(SectorGraph.new().configure(_rows(), [gate], A), "invalid_transition")


func test_duplicate_anchor() -> void:
	var definition := _fixture()
	definition.spawn_anchors.append(definition.spawn_anchors[0])
	assert_null(SectorRuntime.build(definition))


func test_invalid_entry_reference() -> void:
	var edge := _edge()
	edge.entry_anchor = "anchor.absent"
	assert_eq(SectorGraph.new().configure(_rows(), [edge], A), "invalid_spawn_reference")


func test_navigation_path_clears_coast() -> void:
	var nav := SectorRuntime.build(_fixture()).navigation
	var from := Vector2(-240, 0)
	var goal := Vector2(240, 0)
	assert_false(nav.direct_clear(from, goal))
	var route := nav.path(from, goal)
	assert_gte(route.size(), 4)
	if route.size() < 4:
		return
	assert_eq(route[0], from)
	assert_eq(route[-1], goal)
	for index in range(1, route.size()):
		assert_true(nav.direct_clear(route[index - 1], route[index]))
	assert_eq(nav.path(from, goal), route)
	assert_eq(nav.search_count, 1)


func test_inaccessible_routes_return_empty() -> void:
	var definition := _fixture()
	var nav := SectorRuntime.build(definition).navigation
	assert_true(nav.path(Vector2(-240, 0), Vector2.ZERO).is_empty())
	assert_true(nav.path(Vector2(-240, 0), Vector2(NAN, INF)).is_empty())
	definition.navigation_fixture.waypoints = PackedVector2Array()
	assert_true(SectorRuntime.build(definition).navigation.path(Vector2(-240, 0), Vector2(240, 0)).is_empty())


func test_open_water_avoids_astar() -> void:
	var nav := SectorRuntime.build(_fixture()).navigation
	assert_eq(nav.path(Vector2(-240, 0), Vector2(-200, 0)).size(), 2)
	assert_eq(nav.search_count, 0)


func test_spatial_nearby_query() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = ["entity.stale"]
	assert_true(hash.insert(ENTITY_ID, Vector2(10, 10)))
	hash.query_radius(Vector2.ZERO, 15.0, hits)
	assert_eq(hits, [ENTITY_ID])
	hash.query_radius(Vector2.ZERO, 10.0, hits)
	assert_true(hits.is_empty())


func test_spatial_move() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = []
	hash.insert(ENTITY_ID, Vector2.ZERO)
	assert_true(hash.move(ENTITY_ID, Vector2(256, 0)))
	assert_eq(hash.query_radius(Vector2.ZERO, 12.0, hits), 0)
	hash.query_radius(Vector2(256, 0), 12.0, hits)
	assert_eq(hits, [ENTITY_ID])


func test_spatial_remove() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = []
	hash.insert(ENTITY_ID, Vector2.ZERO)
	assert_true(hash.remove(ENTITY_ID))
	assert_false(hash.remove(ENTITY_ID))
	assert_eq(hash.query_radius(Vector2.ZERO, 8.0, hits), 0)
	assert_true(hits.is_empty())


func test_spatial_negative_coordinates() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = []
	hash.insert(ENTITY_ID, Vector2(-129, -129))
	hash.query_radius(Vector2(-128, -128), 2.0, hits)
	assert_eq(hits, [ENTITY_ID])


func test_spatial_no_duplicates_or_nonfinite_values() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = []
	assert_false(hash.insert(ENTITY_ID, Vector2(NAN, 0)))
	assert_true(hash.insert(ENTITY_ID, Vector2.ZERO))
	assert_false(hash.insert(ENTITY_ID, Vector2(128, 0)))
	assert_false(hash.move(ENTITY_ID, Vector2(INF, 0)))
	hash.query_radius(Vector2.ZERO, 200.0, hits)
	assert_eq(hits, [ENTITY_ID])
	hash.query_radius(Vector2.ZERO, INF, hits)
	assert_true(hits.is_empty())


func test_spatial_query_inspects_only_local_candidates() -> void:
	var hash := SectorSpatialHash.new()
	var hits: Array[String] = []
	for i in 512:
		hash.insert("entity.ship_%d" % i, Vector2((i + 1) * 256, 0))
	hash.insert(ENTITY_ID, Vector2.ZERO)
	assert_eq(hash.query_radius(Vector2.ZERO, 20.0, hits), 1)
	assert_eq(hits, [ENTITY_ID])


func test_transition_authority_and_proximity() -> void:
	var authority := RefCounted.new()
	var stranger := RefCounted.new()
	var world := SectorWorld.new(_graph(), authority, _load_sector)
	assert_false(world.activate_initial(stranger, A, ENTRY, ENTITY_ID))
	assert_true(world.activate_initial(authority, A, ENTRY, ENTITY_ID))
	var unauthorized := world.request_transition(stranger, ENTITY_ID, GATE)
	assert_false(unauthorized["accepted"])
	assert_eq(unauthorized["reason"], "not_authorized")
	world.active().move_entity(ENTITY_ID, Vector2(-400, 0))
	assert_true(world.can_transition(authority, ENTITY_ID, GATE).is_empty())
	world.active().move_entity(ENTITY_ID, Vector2(-240, 0))
	var target := world.can_transition(authority, ENTITY_ID, GATE)
	assert_eq(target, {"sector_id": B, "entry_anchor_id": ENTRY})
	var accepted := world.request_transition(authority, ENTITY_ID, GATE)
	assert_true(accepted["accepted"])
	assert_eq(accepted["to_sector"], B)
	assert_eq(accepted["entry_anchor"], ENTRY)
	assert_eq(world.active().sector_id, B)
	assert_false(world.leave(stranger))
	assert_true(world.leave(authority))
	assert_null(world.active())


func test_inactive_sector_has_no_runtime_and_old_releases() -> void:
	var authority := RefCounted.new()
	var world := SectorWorld.new(_graph(), authority, _load_sector)
	assert_true(world.activate_initial(authority, A, ENTRY, ENTITY_ID))
	assert_eq(_loads, [A_PATH])
	var old: WeakRef = weakref(world.active())
	assert_true(world.request_transition(authority, ENTITY_ID, GATE)["accepted"])
	assert_eq(_loads, [A_PATH, B_PATH])
	assert_null(old.get_ref())


func test_failed_destination_preserves_active_runtime() -> void:
	var authority := RefCounted.new()
	var broken_loader := func(path: String) -> SectorDefinition:
		return _load_sector(path) if path == A_PATH else null
	var world := SectorWorld.new(_graph(), authority, broken_loader)
	assert_true(world.activate_initial(authority, A, ENTRY, ENTITY_ID))
	var original := world.active()
	var rejected := world.request_transition(authority, ENTITY_ID, GATE)
	assert_false(rejected["accepted"])
	assert_eq(rejected["reason"], "destination_runtime_invalid")
	assert_true(world.active() == original)


func test_graph_validation_does_not_load_definitions() -> void:
	var graph := _graph()
	assert_eq(graph.definition_path(B), B_PATH)
	assert_false(ResourceLoader.exists(B_PATH))
	assert_eq(_loads.size(), 0)


func test_hazard_cost_determinism_and_cache_invalidation() -> void:
	var nav := SectorRuntime.build(_fixture()).navigation
	var start := Vector2(-240, 0)
	var goal := Vector2(240, 0)
	assert_eq(SectorNavigation.hazard_weight(2.0, 1.0, 3.0, 4.0), 11.0)
	assert_eq(SectorNavigation.hazard_weight(NAN, 1.0, 3.0, 4.0), 0.0)
	var route := nav.path(start, goal)
	assert_gte(route.size(), 4)
	if route.size() < 4:
		return
	var start_side := 0 if route[1].y < 0.0 else 2
	assert_true(nav.set_hazard_cost(start_side, 100.0, 0.0, 0.0, 0.0))
	var changed := nav.path(start, goal)
	assert_gt(changed.size(), 1)
	if changed.size() > 1:
		assert_lt(changed[1].y * route[1].y, 0.0)
	assert_eq(nav.search_count, 2)


func test_runtime_rejects_nonfinite_state() -> void:
	var runtime := SectorRuntime.build(_fixture())
	assert_false(runtime.register_entity(ENTITY_ID, Vector2(INF, 0)))
	assert_true(runtime.register_entity(ENTITY_ID, Vector2(-240, 0)))
	assert_false(runtime.move_entity(ENTITY_ID, Vector2(NAN, 0)))
	assert_false(runtime.move_entity(ENTITY_ID, Vector2(2000, 0)))
	assert_eq(runtime.entity_position(ENTITY_ID), Vector2(-240, 0))
	assert_true(runtime.remove_entity(ENTITY_ID))
	assert_eq(runtime.entity_position(ENTITY_ID), Vector2.INF)


func test_runtime_and_world_have_no_network_or_presentation_dependencies() -> void:
	for file in ["sector_world.gd", "sector_runtime.gd", "sector_navigation.gd", "sector_graph.gd", "sector_spatial_hash.gd"]:
		var source := FileAccess.get_file_as_string("res://src/simulation/world/" + file)
		assert_false(source.is_empty())
		for forbidden in ["MultiplayerAPI", "ENet", "@rpc", "res://src/presentation", "_physics_process"]:
			assert_false(source.contains(forbidden), file + ": " + forbidden)


func test_ship_motor_cannot_cross_fixture_coast() -> void:
	var boot := BOOT.instantiate()
	add_child_autofree(boot)
	var ship: ShipMotor = boot.get_node("ShipMotor")
	ship.set_physics_process(false)
	await get_tree().physics_frame
	assert_true(ship.set_target_world_position(Vector2(260, 0)))
	for i in 480:
		ship.step_authoritative(1.0 / 60.0)
	assert_gt(ship.position.x, -100.0)
	assert_lte(ship.position.x, -48.0)
	assert_true(ship.position.is_finite())


func test_play01_bootstrap_routes_tap_around_fixture_coast() -> void:
	var boot := BOOT.instantiate()
	boot.set("_save_service", SaveService.new("user://play01-coast-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	add_child_autofree(boot)
	boot.set_process(false)
	boot.set_physics_process(false)
	var ship := boot.get_node("ShipMotor") as ShipMotor
	ship.set_physics_process(false)
	await get_tree().physics_frame
	var marker := boot.get_node("Play01Destination") as Line2D
	var route_line := boot.get_node("Play01Route") as Line2D
	var goal := Vector2(240, 0)
	boot._on_gameplay_command(GameplayCommand.move_to_world_position(Vector2.ZERO))
	assert_false(ship.has_target())
	boot._on_gameplay_command(GameplayCommand.move_to_world_position(goal))
	var planned: PackedVector2Array = boot.get("_helm_route")
	assert_gte(planned.size(), 4)
	if planned.size() < 4:
		return
	assert_eq(planned[0], Vector2(-240, 0))
	assert_eq(planned[-1], goal)
	assert_ne(ship.target_world_position(), goal)
	assert_eq(marker.global_position, goal)
	assert_true(route_line.visible)
	var max_collisions := 0
	for _i in 2400:
		ship.step_authoritative(1.0 / 60.0)
		max_collisions = maxi(max_collisions, ship.get_slide_collision_count())
		boot._advance_helm_route()
		if (boot.get("_helm_route") as PackedVector2Array).is_empty() and not ship.has_target():
			break
	boot._refresh_helm()
	assert_lte(ship.global_position.distance_to(goal), 18.1)
	assert_eq(max_collisions, 0)
	assert_true((boot.get("_helm_route") as PackedVector2Array).is_empty())
	assert_false(marker.visible)
	assert_false(route_line.visible)
	print("PLAY01_COAST_ROUTE_OK")


func test_play01_stuck_recovery_replans_then_bounded_abort() -> void:
	var boot := BOOT.instantiate()
	boot.set("_save_service", SaveService.new("user://play01-stuck-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	add_child_autofree(boot)
	boot.set_process(false)
	boot.set_physics_process(false)
	var ship := boot.get_node("ShipMotor") as ShipMotor
	ship.set_physics_process(false)
	await get_tree().physics_frame
	var goal := Vector2(240, 0)
	boot._on_gameplay_command(GameplayCommand.move_to_world_position(goal))
	assert_true(ship.has_target())
	assert_false((boot.get("_helm_route") as PackedVector2Array).is_empty())
	boot._recover_helm_route()
	assert_eq(int(boot.get("_helm_route_replans")), 1)
	assert_true(ship.has_target())
	boot._recover_helm_route()
	assert_eq(int(boot.get("_helm_route_replans")), 2)
	assert_true(ship.has_target())
	boot._recover_helm_route()
	assert_true((boot.get("_helm_route") as PackedVector2Array).is_empty())
	assert_false(ship.has_target())
	print("PLAY01_STUCK_RECOVERY_OK")



func _fixture() -> SectorDefinition:
	var definition := ResourceLoader.load(FoundationSector.PATH, "", ResourceLoader.CACHE_MODE_IGNORE) as SectorDefinition
	definition.spawn_anchors = [definition.spawn_anchors[0]]
	definition.neighbor_ids = PackedStringArray()
	definition.transition_gates = []
	definition.safe_haven = false
	definition.safe_zones = []
	definition.map_node_position = Vector2.ZERO
	definition.map_layer = 0
	definition.biome_tag = ""
	return definition


func _edge() -> SectorGate:
	var edge := SectorGate.new()
	edge.stable_id = GATE
	edge.from_sector = A
	edge.to_sector = B
	edge.exit_anchor = ENTRY
	edge.entry_anchor = ENTRY
	return edge


func _rows() -> Array[Dictionary]:
	return [
		{"id": A, "path": A_PATH, "anchors": PackedStringArray([ENTRY])},
		{"id": B, "path": B_PATH, "anchors": PackedStringArray([ENTRY])},
	]


func _graph() -> SectorGraph:
	var graph := SectorGraph.new()
	assert_eq(graph.configure(_rows(), [_edge()], A), "")
	return graph


func _load_sector(path: String) -> SectorDefinition:
	_loads.append(path)
	var definition := _fixture()
	definition.stable_id = A if path == A_PATH else B
	definition.spawn_anchors[0].stable_id = ENTRY
	definition.spawn_anchors[0].sector_id = definition.stable_id
	if path == A_PATH:
		definition.neighbor_ids = PackedStringArray([B])
		definition.transition_gates = [_edge()]
	return definition



func test_play01_boundary_clearance_margin_can_sail_back() -> void:
	var boot := BOOT.instantiate()
	boot.set("_save_service", SaveService.new("user://play01-edge-%d-%d" % [OS.get_process_id(), Time.get_ticks_usec()]))
	add_child_autofree(boot)
	boot.set_physics_process(false)
	var ship := boot.get_node("ShipMotor") as ShipMotor
	ship.set_physics_process(false)
	await get_tree().physics_frame
	ship.global_position = Vector2(-240, 346)
	ship.rotation = PI / 2.0
	ship.velocity = Vector2.ZERO
	var goal := Vector2(-240, 180)
	assert_false(boot.active_sector().navigation.accessible(ship.global_position))
	boot._on_gameplay_command(GameplayCommand.move_to_world_position(goal))
	assert_true(ship.has_target())
	for i in range(1800):
		ship.step_authoritative(1.0 / 60.0)
		boot._advance_helm_route()
		if not ship.has_target():
			break
	assert_true(boot.active_sector().navigation.accessible(ship.global_position))
	assert_lte(ship.global_position.distance_to(goal), 18.1)
	print("PLAY01_BOUNDARY_EGRESS_OK")
