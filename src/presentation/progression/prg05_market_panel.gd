class_name Prg05MarketPanel
extends PanelContainer

# Presentation only: quotes are read-only and all mutations are host intents.
signal market_intent_requested(operation: String, payload: Dictionary)
signal close_requested

const MAX_ORDER := 100
var _market_id := ""
var _quote: Dictionary = {}
var _balance := 0
var _quantity := 1
var _summary: Label
var _amount: Label
var _feedback: Label


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "LİMAN PAZARI"
	title.add_theme_font_size_override("font_size", 28)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := _button("KAPAT", 110)
	close.pressed.connect(func() -> void: close_requested.emit())
	header.add_child(close)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 23)
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.y = 120
	column.add_child(_summary)
	var quantity_bar := HBoxContainer.new()
	column.add_child(quantity_bar)
	var less := _button("−", 90)
	less.pressed.connect(func() -> void: set_quantity(_quantity - 1))
	quantity_bar.add_child(less)
	_amount = Label.new()
	_amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_amount.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_amount.add_theme_font_size_override("font_size", 28)
	quantity_bar.add_child(_amount)
	var more := _button("+", 90)
	more.pressed.connect(func() -> void: set_quantity(_quantity + 1))
	quantity_bar.add_child(more)
	var actions := HBoxContainer.new()
	column.add_child(actions)
	var buy := _button("SATIN AL", 205)
	buy.pressed.connect(func() -> void: request_trade(InventoryState.OP_MARKET_BUY, _quantity))
	actions.add_child(buy)
	var sell := _button("SAT", 205)
	sell.pressed.connect(func() -> void: request_trade(InventoryState.OP_MARKET_SELL, _quantity))
	actions.add_child(sell)
	_feedback = Label.new()
	_feedback.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_feedback.add_theme_font_size_override("font_size", 22)
	column.add_child(_feedback)
	_refresh()


static func _button(label_text: String, min_width: float) -> Button:
	var button := Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(min_width, 70.0)
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.add_theme_font_size_override("font_size", 23)
	return button


func consume_snapshot(market_id: String, quote: Dictionary, balance: int) -> bool:
	if not SectorIds.valid(market_id) or not DtoContract.is_primitive_safe(quote) or balance < 0:
		return false
	for key in ["item", "stock", "buy", "sell", "disposition"]:
		if not quote.has(key):
			return false
	if not quote["item"] is String or not SectorIds.valid(quote["item"]):
		return false
	if int(quote["stock"]) < 0 or int(quote["buy"]) <= 0 or int(quote["sell"]) <= 0:
		return false
	_market_id = market_id
	_quote = quote.duplicate(true)
	_balance = balance
	_refresh()
	return true


func set_quantity(quantity: int) -> bool:
	if quantity < 1 or quantity > MAX_ORDER:
		return false
	_quantity = quantity
	_refresh()
	return true


func request_trade(operation: String, quantity: int) -> bool:
	if operation not in [InventoryState.OP_MARKET_BUY, InventoryState.OP_MARKET_SELL] or _quote.is_empty() or _market_id.is_empty() or quantity < 1 or quantity > MAX_ORDER:
		return false
	market_intent_requested.emit(operation, {"market_id": _market_id, "quantity": quantity})
	return true


func show_result(result: Dictionary) -> void:
	if _feedback != null:
		_feedback.text = "İşlem başarılı" if result.get("accepted", false) else "Reddedildi: %s" % result.get("reason", "bilinmiyor")


func _refresh() -> void:
	if _amount != null:
		_amount.text = "Adet: %d" % _quantity
	if _summary == null:
		return
	if _quote.is_empty():
		_summary.text = "Pazar verisi yok"
		return
	_summary.text = "Malzeme: %s\nStok: %d    Bakiye: %d\nAlış: %d    Satış: %d\nİlişki: %s" % [
		_quote["item"], int(_quote["stock"]), _balance, int(_quote["buy"]), int(_quote["sell"]), _quote["disposition"],
	]
