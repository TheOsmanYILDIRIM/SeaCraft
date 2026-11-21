class_name SectorDefinition
extends BaseDefinition

@export var display_name: String = ""
@export var controlling_faction_id: String = ""
@export var label_id: String = ""
@export var bounds: Rect2
@export var navigation_fixture: SectorNavigationFixture
@export var spawn_anchors: Array[SectorAnchor] = []
@export var neighbor_ids: PackedStringArray
@export var transition_gates: Array[SectorGate] = []
@export var hazard_cost_profile_id: String = ""
@export_enum("surface", "sub") var layer: int = 0
@export var safe_haven: bool = false
@export var safe_zones: Array[SafeZoneDefinition] = []
@export var map_node_position: Vector2 = Vector2.ZERO
@export var map_layer: int = 0
@export var biome_tag: String = ""


func definition_type() -> String:
	return "sector"


func referenced_stable_ids() -> PackedStringArray:
	var refs := PackedStringArray()
	if not controlling_faction_id.is_empty():
		refs.append(controlling_faction_id)
	refs.append_array(neighbor_ids)
	for zone in safe_zones:
		if zone != null and SectorIds.valid(zone.stable_id):
			refs.append(zone.stable_id)
	return refs
