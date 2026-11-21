class_name SectorGraph
extends RefCounted

var _sectors: Dictionary = {}
var _gates: Dictionary = {}
var _outgoing: Dictionary = {}
var _incoming: Dictionary = {}


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
		var map_position: Variant = row.get("map_node_position", Vector2.ZERO)
		var label: Variant = row.get("label_id", id)
		var map_layer_value: Variant = row.get("map_layer", 0)
		var safe_value: Variant = row.get("safe_haven", false)
		var tag: Variant = row.get("hazard_tag", "")
		if not map_position is Vector2 or not map_position.is_finite() or not label is String or not SectorIds.valid(label):
			return "invalid_map_metadata"
		if typeof(map_layer_value) not in [TYPE_INT, TYPE_FLOAT] or float(map_layer_value) != float(int(map_layer_value)) or absi(int(map_layer_value)) > 8:
			return "invalid_map_metadata"
		if not safe_value is bool or not tag is String or tag.length() > 64:
			return "invalid_map_metadata"
		sectors[id] = {"path": path, "anchors": anchors, "map_node_position": map_position,
			"label_id": label, "map_layer": int(map_layer_value), "safe_haven": safe_value,
			"hazard_tag": tag, "authored_map": row.has("map_node_position")}
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


func presentation_snapshot() -> Dictionary:
	var sectors: Array = []
	var ids := _sectors.keys()
	ids.sort()
	for id in ids:
		var row: Dictionary = _sectors[id]
		var neighbors: Array[String] = []
		for edge: SectorGate in _outgoing[id]:
			neighbors.append(edge.to_sector)
		neighbors.sort()
		var p: Vector2 = row["map_node_position"]
		sectors.append({"sector_id": id, "map_x": p.x, "map_y": p.y, "label_id": row["label_id"],
			"layer": row["map_layer"], "neighbors": neighbors, "safe_haven": row["safe_haven"],
			"hazard_tag": row["hazard_tag"]})
	var connections: Array = []
	var gate_ids := _gates.keys()
	gate_ids.sort()
	for gate_id in gate_ids:
		var edge: SectorGate = _gates[gate_id]
		connections.append({"gate_id": gate_id, "from_sector": edge.from_sector, "to_sector": edge.to_sector})
	return {"sectors": sectors, "connections": connections}


func matches_definition(definition: SectorDefinition) -> bool:
	var id := definition.stable_id
	if not _sectors.has(id):
		return false
	var row: Dictionary = _sectors[id]
	var anchors: Dictionary = row["anchors"]
	if anchors.size() != definition.spawn_anchors.size():
		return false
	for anchor in definition.spawn_anchors:
		if anchor == null or not anchors.has(anchor.stable_id):
			return false
	if row["authored_map"]:
		if definition.map_node_position != row["map_node_position"] or definition.map_layer != row["map_layer"] or definition.label_id != row["label_id"] or definition.safe_haven != row["safe_haven"] or definition.biome_tag != row["hazard_tag"]:
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
