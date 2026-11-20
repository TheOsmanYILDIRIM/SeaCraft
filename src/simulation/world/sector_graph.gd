class_name SectorGraph
extends RefCounted

var _sectors: Dictionary = {}
var _gates: Dictionary = {}
var _outgoing: Dictionary = {}
var _incoming: Dictionary = {}

# Cold path: catalog rows carry only IDs and lazy paths, never PackedScenes or sector resources.
# Input is authored content, not a command payload.
func configure(rows: Array[Dictionary], edges: Array[SectorGate], start_id: String) -> String:
	var sectors: Dictionary = {}
	var gates: Dictionary = {}
	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}
	for row in rows:
		var id: String = row.get("id", "")
		var path: String = row.get("path", "")
		if not SectorIds.valid(id) or not path.begins_with("res://") or not path.ends_with(".tres"):
			return "invalid_sector"
		if sectors.has(id):
			return "duplicate_sector"
		var anchors: Dictionary = {}
		for anchor: String in row.get("anchors", PackedStringArray()):
			if not SectorIds.valid(anchor):
				return "invalid_anchor"
			if anchors.has(anchor):
				return "duplicate_anchor"
			anchors[anchor] = true
		sectors[id] = {"path": path, "anchors": anchors}
		outgoing[id] = []
		incoming[id] = []
	if not sectors.has(start_id):
		return "unknown_sector"
	for edge in edges:
		if edge == null or not SectorIds.valid(edge.stable_id):
			return "invalid_transition"
		if gates.has(edge.stable_id):
			return "duplicate_gate"
		if not sectors.has(edge.from_sector):
			return "unknown_sector"
		if not sectors.has(edge.to_sector):
			return "invalid_destination"
		if edge.from_sector == edge.to_sector or not is_finite(edge.activation_radius) or edge.activation_radius <= 0.0:
			return "invalid_transition"
		if not sectors[edge.from_sector]["anchors"].has(edge.exit_anchor) or not sectors[edge.to_sector]["anchors"].has(edge.entry_anchor):
			return "invalid_spawn_reference"
		var snapshot := edge.duplicate() as SectorGate
		gates[edge.stable_id] = snapshot
		outgoing[edge.from_sector].append(snapshot)
		incoming[edge.to_sector].append(snapshot)
	var seen := {start_id: true}
	var frontier: Array[String] = [start_id]
	var cursor := 0
	while cursor < frontier.size():
		var current := frontier[cursor]
		cursor += 1
		for edge: SectorGate in outgoing[current]:
			if not seen.has(edge.to_sector):
				seen[edge.to_sector] = true
				frontier.append(edge.to_sector)
	if seen.size() != sectors.size():
		return "disconnected_sector"
	_sectors = sectors
	_gates = gates
	_outgoing = outgoing
	_incoming = incoming
	return ""


func definition_path(id: String) -> String:
	return _sectors[id]["path"] if _sectors.has(id) else ""


func gate(id: String) -> SectorGate:
	var edge: SectorGate = _gates.get(id)
	return edge.duplicate() as SectorGate if edge != null else null


func matches_definition(definition: SectorDefinition) -> bool:
	var id := definition.stable_id
	if not _sectors.has(id):
		return false
	var anchors: Dictionary = _sectors[id]["anchors"]
	if anchors.size() != definition.spawn_anchors.size():
		return false
	for anchor in definition.spawn_anchors:
		if anchor == null or not anchors.has(anchor.stable_id):
			return false
	var outbound: Array = _outgoing[id]
	var destinations: Dictionary = {}
	var local_gates: Dictionary = {}
	for edge: SectorGate in outbound:
		destinations[edge.to_sector] = true
	for edge in definition.transition_gates:
		if edge == null or local_gates.has(edge.stable_id):
			return false
		local_gates[edge.stable_id] = true
		var expected: SectorGate = _gates.get(edge.stable_id)
		if expected == null or expected.from_sector != id or edge.from_sector != id or edge.to_sector != expected.to_sector or edge.exit_anchor != expected.exit_anchor or edge.entry_anchor != expected.entry_anchor or edge.activation_radius != expected.activation_radius:
			return false
	if local_gates.size() != outbound.size():
		return false
	for neighbor in definition.neighbor_ids:
		if not destinations.erase(neighbor):
			return false
	return destinations.is_empty()
