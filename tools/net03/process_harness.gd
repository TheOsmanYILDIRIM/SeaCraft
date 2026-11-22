extends Node

const HOST := preload("res://tools/net03/host_fixture.gd")
const DRIVER := preload("res://tools/net03/client_driver.gd")


func _ready() -> void:
	var args: Dictionary = {}
	for raw in OS.get_cmdline_user_args():
		var parts := raw.split("=", true, 1)
		if parts.size() == 2:
			args[parts[0]] = parts[1]
	var role := str(args.get("--role", ""))
	var test_case := str(args.get("--case", ""))
	var port := int(args.get("--port", 0))
	var stop_path := str(args.get("--stop", ""))
	if not SessionProtocol.valid_port(port) or test_case not in ["full", "disconnect"]:
		push_error("NET03_PROCESS_FAILURE: invalid harness arguments")
		get_tree().quit(2)
	elif role == "host" and not stop_path.is_empty():
		var fixture := HOST.new()
		add_child(fixture)
		fixture.start_case(port, test_case, stop_path)
	elif role == "client":
		var driver := DRIVER.new()
		add_child(driver)
		driver.start_case(port, test_case)
	else:
		push_error("NET03_PROCESS_FAILURE: invalid harness role")
		get_tree().quit(2)
