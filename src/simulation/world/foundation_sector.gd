class_name FoundationSector
extends RefCounted

const ID := "sector.foundation"
const OUTER_ID := "sector.outer_reach"
const HAVEN_ID := "sector.safe_haven"
const ENTRY := "anchor.player"
const FOUNDATION_GATE := "anchor.foundation_east"
const OUTER_WEST := "anchor.outer_west"
const OUTER_EAST := "anchor.outer_east"
const HAVEN_WEST := "anchor.haven_west"
const PLAYER := "entity.player"
const PATH := "res://src/data/world/sector_foundation.tres"
const OUTER_PATH := "res://src/data/world/sector_outer_reach.tres"
const HAVEN_PATH := "res://src/data/world/sector_safe_haven.tres"
const GATE_FOUNDATION_OUTER := "gate.foundation_outer"
const GATE_OUTER_FOUNDATION := "gate.outer_foundation"
const GATE_OUTER_HAVEN := "gate.outer_haven"
const GATE_HAVEN_OUTER := "gate.haven_outer"
const COAST_LAYER := 2
const SHIP_LAYER := 4


static func graph() -> SectorGraph:
	var catalog := SectorGraph.new()
	var result := catalog.configure([
		{"id": ID, "path": PATH, "anchors": PackedStringArray([ENTRY, FOUNDATION_GATE, "anchor.foundation_chest", "anchor.foundation_wreck", "anchor.foundation_monster"]),
			"map_node_position": Vector2(0, 0), "label_id": "label.foundation", "map_layer": 0, "safe_haven": false, "hazard_tag": "hazard.calm"},
		{"id": OUTER_ID, "path": OUTER_PATH, "anchors": PackedStringArray([OUTER_WEST, OUTER_EAST, "anchor.outer_chest", "anchor.outer_wreck", "anchor.outer_monster"]),
			"map_node_position": Vector2(180, 40), "label_id": "label.outer_reach", "map_layer": 0, "safe_haven": false, "hazard_tag": "hazard.storm_lane"},
		{"id": HAVEN_ID, "path": HAVEN_PATH, "anchors": PackedStringArray([HAVEN_WEST, "anchor.haven_center"]),
			"map_node_position": Vector2(340, -20), "label_id": "label.safe_haven", "map_layer": 0, "safe_haven": true, "hazard_tag": "hazard.safe"},
	], [
		_gate(GATE_FOUNDATION_OUTER, ID, OUTER_ID, FOUNDATION_GATE, OUTER_WEST),
		_gate(GATE_OUTER_FOUNDATION, OUTER_ID, ID, OUTER_WEST, FOUNDATION_GATE),
		_gate(GATE_OUTER_HAVEN, OUTER_ID, HAVEN_ID, OUTER_EAST, HAVEN_WEST),
		_gate(GATE_HAVEN_OUTER, HAVEN_ID, OUTER_ID, HAVEN_WEST, OUTER_EAST),
	], ID)
	assert(result.is_empty())
	return catalog


static func _gate(id: String, from_sector: String, to_sector: String, exit_anchor: String, entry_anchor: String) -> SectorGate:
	var edge := SectorGate.new()
	edge.stable_id = id
	edge.from_sector = from_sector
	edge.to_sector = to_sector
	edge.exit_anchor = exit_anchor
	edge.entry_anchor = entry_anchor
	edge.activation_radius = 64.0
	return edge
