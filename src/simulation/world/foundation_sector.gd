class_name FoundationSector
extends RefCounted

const ID := "sector.foundation"
const ENTRY := "anchor.player"
const PLAYER := "entity.player"
const PATH := "res://src/data/world/sector_foundation.tres"
const COAST_LAYER := 2
const SHIP_LAYER := 4


static func graph() -> SectorGraph:
	var catalog := SectorGraph.new()
	var result := catalog.configure([
		{"id": ID, "path": PATH, "anchors": PackedStringArray([ENTRY])},
	], [], ID)
	assert(result.is_empty())
	return catalog
