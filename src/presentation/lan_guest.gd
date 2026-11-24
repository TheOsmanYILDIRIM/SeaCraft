extends Node2D

const GAME_PORT := 17350
const DISCOVERY_PORT := 17351
const MARKET_ID := "market.haven.salvage"
var _client: SessionClient
var _discovery := LanRoomBrowser.new()
var _camera: GameplayCamera
var _input_controller: GameplayInputController
var _ui: CanvasLayer
var _lobby: PanelContainer
var _status: Label
var _address: LineEdit
var _rooms: ItemList
var _join: Button
var _resume: Button
var _scan: Button
var _menu: Button
var _market_button: Button
var _market: Prg05MarketPanel
var _room_rows: Array[Dictionary] = []
var _last_rooms := ""
var _endpoint := ""
var _port := GAME_PORT
var _quote_allowed := false
var _pending_txn := ""
var _pending_sequence := -1
var _pending_operation := ""
var _pending_payload: Dictionary = {}
var _followed: NetworkEntityProxy
var _deadline := 0
var _permission_pending := false
var _permission_epoch := 0


func _ready() -> void:
	# Scene root and RPC descendants deliberately match shipped host paths.
	var session := Node.new()
	session.name = "LanSession"
	add_child(session)
	_client = SessionClient.new()
	_client.name = "Session"
	session.add_child(_client)
	_client.connection_state_changed.connect(_state_changed)
	_client.market_snapshot_received.connect(_consume_market)
	_client.command_rejected.connect(_command_rejected)
	_camera = GameplayCamera.new()
	_camera.name = "GameplayCamera"
	add_child(_camera)
	_camera.set_world_limits(Rect2(-640, -360, 1280, 720))
	_input_controller = GameplayInputController.new()
	_input_controller.camera_path = NodePath("../GameplayCamera")
	add_child(_input_controller)
	_input_controller.ui_hit_test = _ui_hit
	_input_controller.command_emitted.connect(_command)
	_ui = CanvasLayer.new()
	add_child(_ui)
	_lobby = PanelContainer.new()
	_ui.add_child(_lobby)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_lobby.add_child(column)
	_status = Label.new()
	_status.text = "LAN • Aynı Wi-Fi ağına bağlanın"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 22)
	column.add_child(_status)
	_scan = _button(column, "Odaları ara", _scan_rooms)
	_rooms = ItemList.new()
	_rooms.custom_minimum_size.y = 104
	_rooms.item_selected.connect(_select_room)
	column.add_child(_rooms)
	_address = LineEdit.new()
	_address.placeholder_text = "Host IPv4 adresi (örn. 192.168.1.10)"
	_address.custom_minimum_size.y = 60
	_address.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_URL
	_address.add_theme_font_size_override("font_size", 22)
	column.add_child(_address)
	_join = _button(column, "IP ile / seçili odaya katıl", _join_room)
	_resume = _button(column, "Yeniden bağlan", _resume_room)
	_button(column, "Bağlantıyı kapat", _disconnect)
	_button(column, "Tek oyuncuya dön", _leave)
	_menu = _button(_ui, "LAN", _toggle_lobby)
	_market_button = _button(_ui, "PAZAR", _toggle_market)
	_market = Prg05MarketPanel.new()
	_ui.add_child(_market)
	_market.hide()
	_market.market_intent_requested.connect(_trade)
	_market.close_requested.connect(_toggle_market)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_state_changed(_client.state())
	queue_redraw()


func _button(parent: Node, label_text: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(0, 58)
	button.add_theme_font_size_override("font_size", 21)
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func _layout() -> void:
	var safe := get_viewport_rect()
	if OS.has_feature("android"):
		var window := Rect2i(DisplayServer.window_get_position(), DisplayServer.window_get_size())
		var pixels := window.intersection(DisplayServer.get_display_safe_area())
		if pixels.has_area():
			pixels.position -= window.position
			safe = safe.intersection(SafeAreaMath.display_safe_area_to_logical(Rect2(pixels), Vector2(1280, 720), Vector2(window.size)))
	_lobby.size = Vector2(minf(740, safe.size.x - 48), minf(590, safe.size.y - 40))
	_lobby.position = safe.get_center() - _lobby.size * 0.5
	_menu.size = Vector2(150, 64)
	_menu.position = Vector2(safe.end.x - 174, safe.position.y + 24)
	_market_button.size = Vector2(150, 64)
	_market_button.position = Vector2(safe.end.x - 174, safe.position.y + 98)
	_market.size = Vector2(minf(730, safe.size.x - 48), minf(490, safe.size.y - 48))
	_market.position = safe.get_center() - _market.size * 0.5


func _draw() -> void:
	draw_rect(Rect2(-640, -360, 1280, 720), Color(0.035, 0.095, 0.115))
	draw_arc(Vector2.ZERO, 128, 0, TAU, 64, Color(0.9, 0.75, 0.3), 2)
	draw_circle(Vector2.ZERO, 5, Color.GOLD)


func _permit() -> bool:
	if _permission_pending:
		return false
	_permission_pending = true
	var epoch := _permission_epoch
	var gate := LanPermissionGate.new()
	var result: String = await gate.request_and_wait(get_tree(), func() -> void:
		_status.text = "Android yerel ağ izni bekleniyor…"
		_join.disabled = true
		_scan.disabled = true
		_resume.disabled = true
	)
	_permission_pending = false
	_join.disabled = _client.state() not in [SessionClient.STATE_DISCONNECTED, SessionClient.STATE_REJECTED]
	_scan.disabled = _join.disabled
	_resume.disabled = not _client.can_resume()
	if epoch != _permission_epoch:
		return false
	if result == LanPermissionGate.RESULT_ALLOWED:
		return true
	_status.text = LanPermissionGate.user_message(result)
	return false


func _scan_rooms() -> void:
	if not await _permit():
		return
	if _discovery.is_active():
		_discovery.stop()
	var error := _discovery.start(DISCOVERY_PORT)
	_status.text = "Odalar aranıyor..." if error == OK else "Arama açılamadı: %s (IP ile katılabilirsiniz)" % error


func _select_room(index: int) -> void:
	if index < 0 or index >= _room_rows.size():
		return
	_address.text = str(_room_rows[index]["address"])
	_port = int(_room_rows[index]["game_port"])


func _join_room() -> void:
	if not await _permit():
		return
	var address := _address.text.strip_edges()
	if not SessionProtocol.valid_ipv4(address):
		_status.text = "Geçerli IPv4 adresi girin."
		return
	if _client.state() != SessionClient.STATE_DISCONNECTED:
		_client.close_session()
	_endpoint = address
	_pending_txn = ""
	_pending_payload.clear()
	_connect_result(_client.join(_endpoint, _port))


func _resume_room() -> void:
	if not _client.can_resume() or not await _permit() or not _client.can_resume():
		return
	_connect_result(_client.resume(_endpoint, _port))


func _connect_result(error: int) -> void:
	if error != OK:
		_status.text = "Bağlantı açılamadı: %s" % error
	else:
		_deadline = Time.get_ticks_msec() + 15000
		if _discovery.is_active():
			_discovery.stop()


func _disconnect() -> void:
	_permission_epoch += 1
	_client.close_session()
	_client.clear_resume_credentials()
	_pending_txn = ""
	_pending_payload.clear()
	_state_changed(_client.state())


func _leave() -> void:
	_disconnect()
	_discovery.stop()
	get_tree().change_scene_to_file("res://src/presentation/bootstrap.tscn")


func _exit_tree() -> void:
	_discovery.stop()
	if is_instance_valid(_client) and _client.is_inside_tree():
		_client.close_session()


func _state_changed(state: String) -> void:
	var ready := state == SessionClient.STATE_READY
	_status.text = "Bağlandı • Pazar halkasına yaklaşın" if ready else "LAN: " + state
	if state == SessionClient.STATE_REJECTED:
		_status.text = "Bağlantı reddedildi: " + _client.rejection_reason()
	if ready:
		_deadline = 0
		_lobby.hide()
		if not _pending_txn.is_empty():
			_pending_sequence = _client.next_sequence()
			if not _client.send_intent(_pending_operation, _pending_payload):
				_pending_sequence = -1
	else:
		_lobby.show()
		_market.hide()
		_quote_allowed = false
		_followed = null
		_camera.set_follow_target(null)
	_join.disabled = _permission_pending or ready or state not in [SessionClient.STATE_DISCONNECTED, SessionClient.STATE_REJECTED]
	_scan.disabled = _join.disabled
	_resume.disabled = _permission_pending or not _client.can_resume()
	_market_button.disabled = not ready or not _quote_allowed
	_input_controller.set_world_input_blocked(not ready or _lobby.visible)


func _toggle_lobby() -> void:
	if _client.state() != SessionClient.STATE_READY:
		return
	_market.hide()
	_lobby.visible = not _lobby.visible
	_input_controller.set_world_input_blocked(_lobby.visible)


func _toggle_market() -> void:
	if not _quote_allowed or _client.state() != SessionClient.STATE_READY:
		return
	_lobby.hide()
	_market.visible = not _market.visible
	_input_controller.set_world_input_blocked(_market.visible)


func _ui_hit(position: Vector2) -> bool:
	for control in [_lobby, _menu, _market_button, _market]:
		if control.is_visible_in_tree() and control.get_global_rect().has_point(position):
			return true
	return false


func _command(command: Dictionary) -> void:
	if command.get("type") in [GameplayCommand.MOVE_TO_WORLD_POSITION, GameplayCommand.CANCEL]:
		_client.send_command(command)


func _consume_market(snapshot: Dictionary) -> void:
	if snapshot.get("market_id") != MARKET_ID:
		return
	_quote_allowed = bool(snapshot.get("allowed", false))
	if _quote_allowed:
		_quote_allowed = _market.consume_snapshot(MARKET_ID, snapshot.get("quote", {}), int(snapshot.get("balance", -1)))
	_market_button.disabled = not _quote_allowed
	if not _quote_allowed:
		_market.hide()
		_input_controller.set_world_input_blocked(_lobby.visible)


func _trade(operation: String, payload: Dictionary) -> void:
	if not _quote_allowed or not _pending_txn.is_empty():
		return
	var id := "txn.market.guest.r%s" % Crypto.new().generate_random_bytes(16).hex_encode()
	var request := payload.duplicate(true)
	request["transaction_id"] = id
	var sequence := _client.next_sequence()
	if _client.send_intent(operation, request):
		_pending_txn = id
		_pending_sequence = sequence
		_pending_operation = operation
		_pending_payload = request
		_market.show_result({"accepted": false, "reason": "Sunucu yanıtı bekleniyor"})


func _command_rejected(sequence: int, reason: String) -> void:
	if sequence == _pending_sequence and not _pending_txn.is_empty():
		_market.show_result({"accepted": false, "reason": reason})
		_pending_txn = ""
		_pending_payload.clear()


func _process(_delta: float) -> void:
	if _discovery.is_active():
		_discovery.poll()
		var rows := _discovery.compatible_sessions()
		var signature := ""
		for row in rows:
			signature += "%s:%s:%s:%s;" % [row.get("session_id"), row.get("address"), row.get("game_port"), row.get("player_count")]
		if signature != _last_rooms:
			_last_rooms = signature
			_room_rows = rows
			_rooms.clear()
			for row in rows:
				_rooms.add_item("%s:%s • %s oyuncu" % [row.get("address"), row.get("game_port"), row.get("player_count")])
	if _deadline > 0 and Time.get_ticks_msec() > _deadline:
		_deadline = 0
		_client.close_session()
		_status.text = "Bağlantı zaman aşımı. Tekrar deneyin."
	if _client.state() != SessionClient.STATE_READY:
		return
	var registry := _client.network_entity_registry()
	if registry != null:
		for id in registry.entity_ids():
			var proxy := registry.proxy(id)
			if proxy == null:
				continue
			if not proxy.has_node("LanShipMarker"):
				var marker := Polygon2D.new()
				marker.name = "LanShipMarker"
				marker.polygon = PackedVector2Array([Vector2(-18, 12), Vector2(20, 0), Vector2(-18, -12)])
				marker.color = Color.CYAN if id == _client.assigned_player_id() else Color.WHITE
				proxy.add_child(marker)
			if id == _client.assigned_player_id() and proxy != _followed:
				_followed = proxy
				_camera.set_follow_target(proxy)
				_camera.recenter()
	if not _pending_txn.is_empty():
		var result := _client.transaction_result(_pending_txn)
		if not result.is_empty():
			_market.show_result(result)
			_pending_txn = ""
			_pending_payload.clear()
