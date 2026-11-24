extends Node

const HOST := preload("res://tools/prg05_production_lan/host_fixture.gd")
const CLIENT := preload("res://tools/prg05_production_lan/client.gd")


func _ready() -> void:
	var args := {}
	for raw in OS.get_cmdline_user_args():
		var parts := str(raw).split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var role := str(args.get("--role", ""))
	var game_port := int(args.get("--game-port", 0))
	var discovery_port := int(args.get("--discovery-port", 0))
	var work := str(args.get("--work", ""))
	if not SessionProtocol.valid_port(game_port) or not SessionProtocol.valid_port(discovery_port) \
			or game_port == discovery_port or work.is_empty():
		push_error("PRG05_PRODUCTION_LAN_FAILURE: invalid harness arguments")
		get_tree().quit(2)
		return
	var worker: Node
	match role:
		"host":
			worker = HOST.new()
		"client":
			worker = CLIENT.new()
		_:
			push_error("PRG05_PRODUCTION_LAN_FAILURE: invalid role")
			get_tree().quit(2)
			return
	worker.name = "Worker"
	add_child(worker)
	worker.start_case(game_port, discovery_port, work)
