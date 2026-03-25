class_name DeliveryTrackerWindow
extends PanelContainer

signal close_requested

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var current_time_label: Label = $MarginContainer/Content/TitleRow/CurrentTimeLabel
@onready var close_button: Button = $MarginContainer/Content/TitleRow/CloseButton
@onready var subtitle_label: Label = $MarginContainer/Content/SubtitleLabel
@onready var scroll_container: ScrollContainer = $MarginContainer/Content/ScrollContainer
@onready var orders_container: VBoxContainer = $MarginContainer/Content/ScrollContainer/OrdersContainer
@onready var empty_label: Label = $MarginContainer/Content/EmptyLabel


func _ready() -> void:
	title_label.text = "\u0414\u043E\u0441\u0442\u0430\u0432\u043A\u0430"
	subtitle_label.text = "\u041E\u0442\u0441\u043B\u0435\u0436\u0438\u0432\u0430\u0439\u0442\u0435 \u0442\u0435\u043A\u0443\u0449\u0438\u0435 \u0437\u0430\u043A\u0430\u0437\u044B \u0438 \u0432\u0440\u0435\u043C\u044F \u0438\u0445 \u043F\u0440\u0438\u0431\u044B\u0442\u0438\u044F."
	close_button.text = "\u0417\u0430\u043A\u0440\u044B\u0442\u044C"
	empty_label.text = "\u0410\u043A\u0442\u0438\u0432\u043D\u044B\u0445 \u0434\u043E\u0441\u0442\u0430\u0432\u043E\u043A \u043D\u0435\u0442."
	close_button.pressed.connect(_on_close_button_pressed)

	if not DeliveryManager.deliveries_updated.is_connected(_on_deliveries_updated):
		DeliveryManager.deliveries_updated.connect(_on_deliveries_updated)

	if not GameTime.time_changed.is_connected(_on_time_changed):
		GameTime.time_changed.connect(_on_time_changed)

	_refresh_current_time()
	_refresh_view()


func open_window() -> void:
	visible = true
	_refresh_current_time()
	_refresh_view()

	if close_button != null:
		close_button.grab_focus()


func close_window() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _refresh_view() -> void:
	for child in orders_container.get_children():
		orders_container.remove_child(child)
		child.queue_free()

	var deliveries: Array = DeliveryManager.get_active_deliveries()
	deliveries.sort_custom(Callable(self, "_sort_deliveries"))

	var has_deliveries: bool = not deliveries.is_empty()
	scroll_container.visible = has_deliveries
	empty_label.visible = not has_deliveries

	for delivery in deliveries:
		orders_container.add_child(_build_delivery_row(delivery))


func _build_delivery_row(delivery: Dictionary) -> Control:
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 170)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 16)
	row_panel.add_child(margin)

	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title: Label = Label.new()
	title.add_theme_font_size_override("font_size", 26)
	title.text = "\u0417\u0430\u043A\u0430\u0437 #%d" % int(delivery.get("id", 0))
	content.add_child(title)

	var items_label: Label = Label.new()
	items_label.add_theme_font_size_override("font_size", 20)
	items_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	items_label.text = _format_items(delivery.get("items", []))
	content.add_child(items_label)

	var remaining_label: Label = Label.new()
	remaining_label.add_theme_font_size_override("font_size", 20)
	remaining_label.text = _format_delivery_state(delivery)
	content.add_child(remaining_label)

	var arrival_label: Label = Label.new()
	arrival_label.add_theme_font_size_override("font_size", 18)
	arrival_label.text = _format_arrival(delivery)
	content.add_child(arrival_label)

	return row_panel


func _format_items(items: Array) -> String:
	var lines: Array = []

	for entry_variant in items:
		var entry: Dictionary = {}

		if entry_variant is Dictionary:
			entry = entry_variant

		var item_data: ItemData = _load_item_data(entry)
		var quantity: int = int(entry.get("quantity", 0))

		if item_data == null or quantity <= 0:
			continue

		lines.append("%s x%d" % [item_data.get_display_name(), quantity])

	if lines.is_empty():
		return "\u0421\u043E\u0441\u0442\u0430\u0432 \u0437\u0430\u043A\u0430\u0437\u0430 \u043D\u0435\u0434\u043E\u0441\u0442\u0443\u043F\u0435\u043D."

	return "\n".join(lines)


func _format_delivery_state(delivery: Dictionary) -> String:
	var status: String = String(delivery.get("status", "in_transit"))

	if status == "awaiting_fridge_space":
		return "\u0421\u0442\u0430\u0442\u0443\u0441: \u0436\u0434\u0451\u0442 \u043C\u0435\u0441\u0442\u043E \u0432 \u0445\u043E\u043B\u043E\u0434\u0438\u043B\u044C\u043D\u0438\u043A\u0435"

	return "\u041E\u0441\u0442\u0430\u043B\u043E\u0441\u044C: %s" % _format_duration(DeliveryManager.get_remaining_minutes(delivery))


func _format_arrival(delivery: Dictionary) -> String:
	var arrival_data: Dictionary = GameTime.get_time_data_for_absolute(int(delivery.get("deliver_at", 0)))
	return "\u041F\u0440\u0438\u0431\u0443\u0434\u0435\u0442: \u0414\u0435\u043D\u044C %d, %02d:%02d" % [
		int(arrival_data.get("day", 1)),
		int(arrival_data.get("hours", 0)),
		int(arrival_data.get("minutes", 0)),
	]


func _format_duration(total_minutes: int) -> String:
	var safe_minutes: int = total_minutes

	if safe_minutes < 0:
		safe_minutes = 0
	var hours: int = int(safe_minutes / 60.0)
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%d\u043C" % minutes

	return "%d\u0447 %02d\u043C" % [hours, minutes]


func _refresh_current_time() -> void:
	var current_time: Dictionary = GameTime.get_current_time_data()
	current_time_label.text = "\u0421\u0435\u0439\u0447\u0430\u0441: \u0414\u0435\u043D\u044C %d, %02d:%02d" % [
		int(current_time.get("day", 1)),
		int(current_time.get("hours", 0)),
		int(current_time.get("minutes", 0)),
	]


func _load_item_data(entry: Dictionary) -> ItemData:
	var item_data: ItemData = entry.get("item_data", null) as ItemData

	if item_data != null:
		return item_data

	var item_path: String = String(entry.get("item_path", ""))

	if item_path.is_empty():
		return null

	return load(item_path) as ItemData


func _sort_deliveries(a: Dictionary, b: Dictionary) -> bool:
	return int(a.get("deliver_at", 0)) < int(b.get("deliver_at", 0))


func _on_deliveries_updated() -> void:
	if not visible:
		return

	_refresh_view()


func _on_time_changed(_absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	_refresh_current_time()

	if visible:
		_refresh_view()


func _on_close_button_pressed() -> void:
	close_requested.emit()
