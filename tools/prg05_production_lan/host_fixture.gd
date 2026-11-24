extends Node

const BOOTSTRAP := preload("res://src/presentation/bootstrap.tscn")
const PLAYER := FoundationSector.PLAYER
const GUEST := "player.lan.guest"
const MARKET := "market.haven.salvage"
const CREDIT := 1000

var _game_port := 0
var _discovery_port := 0
var _work := ""
var _save_directory := ""
var _scene: Node
var _initial_price := 0
var _failed := false


func start_case(game_port: int, discovery_port: int, work: String) -> void:
	_game_port = game_port
	_discovery_port = discovery_port
	_work = work
	_save_directory = "user://prg05-production-lan-%d" % OS.get_process_id()
	_run.call_deferred()


func _run() -> void:
	_scene = _new_bootstrap()
	if _scene == null or not _travel_to_haven(_scene):
		_abort("bootstrap haven composition")
		return
	var motor := _scene.get_node("ShipMotor") as ShipMotor
	var center: Vector2 = _scene.active_sector().anchor("anchor.haven_center").position
	motor.global_position = center
	if not _scene.active_sector().move_entity(PLAYER, center):
		_abort("host market placement")
		return
	var started: Dictionary = _scene.start_lan_host(_game_port, _discovery_port, "127.0.0.1")
	if not bool(started.get("accepted", false)) or started.get("remote_player_id") != GUEST:
		_abort("production host start " + str(started))
		return
	var inventory := (_scene.get("_loot") as LootAuthority).inventory_state()
	if not inventory.grant_economy_currency_authoritative(GUEST, "event.prg05.production.credit", CREDIT).get("accepted", false):
		_abort("guest credit")
		return
	var quote := inventory.economy_quote(GUEST, MARKET)
	_initial_price = int(quote.get("buy", 0))
	if _initial_price <= 0 or int(quote.get("stock", -1)) != 8:
		_abort("initial quote")
		return
	print("PRG05_PRODUCTION_LAN_HOST_READY session=%s guest=%s" % [started["session_id"], GUEST])
	if not await _wait_file("client_trade_done", "first trade"):
		return
	if not _verify_trade_state(_scene, 7, CREDIT - _initial_price, 1):
		_abort("first authoritative trade state")
		return
	_scene._flush_checkpoint()
	var service := _scene.get("_save_service") as SaveService
	var saved := service.load()
	if saved.get("status") != SaveService.OK_STATUS:
		_abort("host save")
		return
	var snapshot: Dictionary = saved["snapshot"]
	if snapshot["ownership"]["kind"] != SaveSnapshot.HOST or str(snapshot["ownership"]["session_id"]) != str(started["session_id"]):
		_abort("host ownership metadata")
		return
	var authority := SaveSnapshot.authoritative_state(snapshot)
	var lan: Dictionary = authority.get("lan", {})
	if int(lan.get("transaction_ledger", {}).get("commit_sequence", -1)) != 1 \
			or int(lan.get("quantities", {}).get("item.vs03_salvage_scrap", 0)) != 1:
		_abort("host lan save state")
		return
	print("PRG05_PRODUCTION_LAN_SAVE_OK owner=host stock=7 guest_quantity=1 ledger=1")

	_scene.stop_lan_host()
	_scene.free()
	_scene = null
	await get_tree().process_frame
	_scene = _new_bootstrap()
	if _scene == null:
		_abort("reload bootstrap")
		return
	var restored_inventory := (_scene.get("_loot") as LootAuthority).inventory_state()
	if not _verify_trade_state(_scene, 7, CREDIT - _initial_price, 1):
		_abort("restored economy state")
		return
	var restarted: Dictionary = _scene.start_lan_host(_game_port, _discovery_port, "127.0.0.1")
	if not bool(restarted.get("accepted", false)):
		_abort("restarted production host " + str(restarted))
		return
	if int((_scene.lan_host_snapshot() as Dictionary).get("transaction_watermark", -1)) != 1:
		_abort("restored host ledger watermark")
		return
	_touch("host_restarted")
	print("PRG05_PRODUCTION_LAN_RELOAD_OK session=%s stock=7 balance=%d quantity=1" % [
		restarted["session_id"], restored_inventory.economy_balance(GUEST)])
	if not await _wait_file("client_retry_done", "cached replay"):
		return
	if not _verify_trade_state(_scene, 7, CREDIT - _initial_price, 1):
		_abort("cached replay mutated state")
		return
	var host_node := _scene.get("_lan_host") as ProductionLanHost
	var ledger := host_node.transaction_ledger_snapshot()
	if int(ledger.get("commit_sequence", -1)) != 1 or (ledger.get("entries", []) as Array).size() != 1:
		_abort("cached replay ledger duplicate")
		return
	print("PRG05_PRODUCTION_LAN_REPLAY_OK stock=7 balance=%d quantity=1 ledger=1" % [CREDIT - _initial_price])
	_scene.stop_lan_host()
	print("PRG05_PRODUCTION_LAN_HOST_CLEAN_EXIT")
	get_tree().quit(0)


func _new_bootstrap() -> Node:
	var scene := BOOTSTRAP.instantiate()
	scene.set("_save_service", SaveService.new(_save_directory))
	add_child(scene)
	var status: Dictionary = scene.get("save_status")
	if status.get("status") not in [SaveService.MISSING, SaveService.OK_STATUS, SaveService.RECOVERED]:
		return null
	return scene


func _travel_to_haven(scene: Node) -> bool:
	if scene.active_sector().sector_id == FoundationSector.HAVEN_ID:
		return true
	if scene.active_sector().sector_id != FoundationSector.ID:
		return false
	var motor := scene.get_node("ShipMotor") as ShipMotor
	motor.global_position = scene.active_sector().anchor(FoundationSector.FOUNDATION_GATE).position
	var first: Dictionary = scene.request_sector_transition(FoundationSector.GATE_FOUNDATION_OUTER)
	if not bool(first.get("accepted", false)):
		return false
	motor.global_position = scene.active_sector().anchor(FoundationSector.OUTER_EAST).position
	var second: Dictionary = scene.request_sector_transition(FoundationSector.GATE_OUTER_HAVEN)
	return bool(second.get("accepted", false)) and scene.active_sector().sector_id == FoundationSector.HAVEN_ID


func _verify_trade_state(scene: Node, stock: int, balance: int, quantity: int) -> bool:
	var inventory := (scene.get("_loot") as LootAuthority).inventory_state()
	return int(inventory.economy_quote(GUEST, MARKET).get("stock", -1)) == stock \
		and inventory.economy_balance(GUEST) == balance \
		and inventory.quantity(GUEST, "item.vs03_salvage_scrap") == quantity


func _wait_file(name: String, stage: String, timeout_ms: int = 12000) -> bool:
	var deadline := Time.get_ticks_msec() + timeout_ms
	while not _failed and Time.get_ticks_msec() < deadline:
		if FileAccess.file_exists(_work + "/" + name):
			return true
		await get_tree().process_frame
	if not _failed:
		_abort("stage timeout: " + stage)
	return false


func _touch(name: String) -> void:
	var file := FileAccess.open(_work + "/" + name, FileAccess.WRITE)
	if file != null:
		file.store_string("ok\n")


func _abort(reason: String) -> void:
	_failed = true
	push_error("PRG05_PRODUCTION_LAN_FAILURE: host " + reason)
	if _scene != null and _scene.has_method("stop_lan_host"):
		_scene.stop_lan_host()
	get_tree().quit(1)
