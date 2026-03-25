class_name ShopWindow
extends PanelContainer

signal close_requested

const ITEM_ICON_OUTLINE_MATERIAL := preload("res://resources/ui/item_icon_outline_material.tres")
const FALLBACK_OUTLINE_COLOR := Color(0.02, 0.04, 0.08, 1.0)
const DEFAULT_WINDOW_TITLE := "Магазин"
const DEFAULT_WINDOW_SUBTITLE := "Еда оплачивается со счета и приезжает через 4 игровых часа."
const PAYMENT_SOURCE_CASH := "cash"
const PAYMENT_SOURCE_BANK := "bank"

@export var catalog: Array[ItemData] = []
@export var window_title_text: String = DEFAULT_WINDOW_TITLE
@export_multiline var window_subtitle_text: String = DEFAULT_WINDOW_SUBTITLE
@export var price_overrides: Dictionary = {}
@export var use_delivery: bool = true
@export_enum("cash", "bank") var payment_source: String = PAYMENT_SOURCE_CASH

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var balance_label: Label = $MarginContainer/Content/TitleRow/BalanceLabel
@onready var close_button: Button = $MarginContainer/Content/TitleRow/CloseButton
@onready var subtitle_label: Label = $MarginContainer/Content/SubtitleLabel
@onready var scroll_container: ScrollContainer = $MarginContainer/Content/ScrollContainer
@onready var items_container: VBoxContainer = $MarginContainer/Content/ScrollContainer/ItemsContainer
@onready var status_label: Label = $MarginContainer/Content/StatusLabel


func _ready() -> void:
	_apply_window_texts()
	close_button.text = "Закрыть"
	status_label.visible = false
	close_button.pressed.connect(_on_close_button_pressed)

	var player_economy: PlayerEconomyState = _get_player_economy()

	if player_economy != null:
		if not player_economy.cash_dollars_changed.is_connected(_on_cash_dollars_changed):
			player_economy.cash_dollars_changed.connect(_on_cash_dollars_changed)

		if not player_economy.bank_dollars_changed.is_connected(_on_bank_dollars_changed):
			player_economy.bank_dollars_changed.connect(_on_bank_dollars_changed)

	_refresh_balance_label()
	_rebuild_catalog()


func open_window() -> void:
	visible = true
	status_label.visible = false
	_apply_window_texts()
	_rebuild_catalog()
	_refresh_balance_label()

	if close_button != null:
		close_button.grab_focus()


func close_window() -> void:
	visible = false
	status_label.visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _rebuild_catalog() -> void:
	for child in items_container.get_children():
		items_container.remove_child(child)
		child.queue_free()

	for item_data in catalog:
		if item_data == null:
			continue

		items_container.add_child(_build_item_row(item_data))


func _build_item_row(item_data: ItemData) -> Control:
	var row_panel: PanelContainer = PanelContainer.new()
	row_panel.custom_minimum_size = Vector2(0, 112)
	row_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 14)
	row_panel.add_child(margin)

	var content_row: HBoxContainer = HBoxContainer.new()
	content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_row.add_theme_constant_override("separation", 16)
	margin.add_child(content_row)

	var icon_panel: PanelContainer = PanelContainer.new()
	icon_panel.custom_minimum_size = Vector2(72, 72)
	content_row.add_child(icon_panel)

	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.anchors_preset = Control.PRESET_FULL_RECT
	icon_rect.anchor_right = 1.0
	icon_rect.anchor_bottom = 1.0
	icon_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	icon_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.texture = item_data.icon
	icon_rect.visible = item_data.icon != null
	icon_rect.material = ITEM_ICON_OUTLINE_MATERIAL
	icon_panel.add_child(icon_rect)

	var fallback_label: Label = Label.new()
	fallback_label.anchors_preset = Control.PRESET_FULL_RECT
	fallback_label.anchor_right = 1.0
	fallback_label.anchor_bottom = 1.0
	fallback_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	fallback_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	fallback_label.add_theme_color_override("font_outline_color", FALLBACK_OUTLINE_COLOR)
	fallback_label.add_theme_constant_override("outline_size", 8)
	fallback_label.add_theme_font_size_override("font_size", 22)
	fallback_label.text = _get_fallback_text(item_data)
	fallback_label.visible = item_data.icon == null
	icon_panel.add_child(fallback_label)

	var info_box: VBoxContainer = VBoxContainer.new()
	info_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_box.add_theme_constant_override("separation", 6)
	content_row.add_child(info_box)

	var name_label: Label = Label.new()
	name_label.text = item_data.get_display_name()
	name_label.add_theme_font_size_override("font_size", 24)
	info_box.add_child(name_label)

	var price_label: Label = Label.new()
	price_label.text = "$%d" % _resolve_item_price(item_data)
	price_label.add_theme_font_size_override("font_size", 20)
	info_box.add_child(price_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(170, 54)
	buy_button.text = "Купить"
	buy_button.add_theme_font_size_override("font_size", 22)
	buy_button.pressed.connect(_on_buy_button_pressed.bind(item_data))
	content_row.add_child(buy_button)

	return row_panel


func _on_buy_button_pressed(item_data: ItemData) -> void:
	if item_data == null:
		_show_status("Товар не найден.")
		return

	var price: int = _resolve_item_price(item_data)
	var player_inventory: PlayerInventoryState = get_node_or_null("/root/PlayerInventory") as PlayerInventoryState

	if not use_delivery:
		if player_inventory == null:
			_show_status("Инвентарь недоступен.")
			return

		if not player_inventory.can_add_item(item_data, 1):
			_show_status("Нет места в инвентаре.")
			return

	if not _spend_price(price):
		_show_status(_get_insufficient_funds_message())
		return

	if not use_delivery:
		if not player_inventory.add_item(item_data, 1):
			_refund_price(price)
			_show_status("Не удалось добавить предмет в инвентарь.")
			return

		_show_status("Покупка добавлена в инвентарь.")
		return

	var delivery_manager: Node = _get_delivery_manager()

	if delivery_manager == null:
		_refund_price(price)
		_show_status("Служба доставки недоступна.")
		return

	var delivery: Dictionary = delivery_manager.create_delivery([
		{
			"item_data": item_data,
			"quantity": 1,
		}
	])

	if delivery.is_empty():
		_refund_price(price)
		_show_status("Не удалось оформить доставку.")
		return

	_record_bank_purchase(item_data, price)
	var delivery_id: int = int(delivery.get("id", 0))
	_show_status("Заказ #%d оформлен. Доставка через 4 часа." % delivery_id)


func _on_cash_dollars_changed(_new_value: int) -> void:
	_refresh_balance_label()


func _on_bank_dollars_changed(_new_value: int) -> void:
	_refresh_balance_label()


func _refresh_balance_label() -> void:
	if balance_label == null:
		return

	var player_economy: PlayerEconomyState = _get_player_economy()

	if player_economy == null:
		balance_label.text = "На счете: --" if _uses_bank_payment() else "Наличные: --"
		return

	if _uses_bank_payment():
		balance_label.text = "На счете: $%d" % player_economy.get_bank_dollars()
		return

	balance_label.text = "Наличные: $%d" % player_economy.get_cash_dollars()


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func set_window_texts(title_text: String, subtitle_text: String) -> void:
	window_title_text = title_text
	window_subtitle_text = subtitle_text
	_apply_window_texts()


func set_price_overrides(overrides: Dictionary) -> void:
	price_overrides = overrides.duplicate(true)

	if is_inside_tree():
		_rebuild_catalog()


func _apply_window_texts() -> void:
	if title_label != null:
		title_label.text = _get_effective_title_text()

	if subtitle_label != null:
		subtitle_label.text = _get_effective_subtitle_text()
		subtitle_label.visible = not subtitle_label.text.is_empty()


func _get_effective_title_text() -> String:
	var trimmed_title: String = window_title_text.strip_edges()

	if trimmed_title.is_empty():
		return DEFAULT_WINDOW_TITLE

	return trimmed_title


func _get_effective_subtitle_text() -> String:
	var trimmed_subtitle: String = window_subtitle_text.strip_edges()

	if trimmed_subtitle.is_empty():
		return DEFAULT_WINDOW_SUBTITLE

	return trimmed_subtitle


func _resolve_item_price(item_data: ItemData) -> int:
	if item_data == null:
		return 0

	var resource_path: String = item_data.resource_path

	if not resource_path.is_empty() and price_overrides.has(resource_path):
		return max(0, int(price_overrides.get(resource_path, 0)))

	var item_id: String = item_data.id

	if not item_id.is_empty() and price_overrides.has(item_id):
		return max(0, int(price_overrides.get(item_id, 0)))

	return item_data.get_effective_price()


func _get_effective_payment_source() -> String:
	var source: String = payment_source.strip_edges().to_lower()

	if source == PAYMENT_SOURCE_BANK:
		return PAYMENT_SOURCE_BANK

	return PAYMENT_SOURCE_CASH


func _uses_bank_payment() -> bool:
	return _get_effective_payment_source() == PAYMENT_SOURCE_BANK


func _spend_price(price: int) -> bool:
	var player_economy: PlayerEconomyState = _get_player_economy()

	if player_economy == null:
		return false

	if _uses_bank_payment():
		return player_economy.spend_bank_dollars(price)

	return player_economy.spend_cash_dollars(price)


func _refund_price(price: int) -> void:
	if price <= 0:
		return

	var player_economy: PlayerEconomyState = _get_player_economy()

	if player_economy == null:
		return

	if _uses_bank_payment():
		player_economy.add_bank_dollars(price, false)
		return

	player_economy.add_cash_dollars(price, false)


func _get_insufficient_funds_message() -> String:
	if _uses_bank_payment():
		return "Недостаточно денег на счете."

	return "Недостаточно наличных."


func _record_bank_purchase(item_data: ItemData, price: int) -> void:
	if not _uses_bank_payment() or price <= 0:
		return

	var freelance_state: Node = get_node_or_null("/root/FreelanceState")

	if freelance_state == null or not freelance_state.has_method("append_bank_history_entry"):
		return

	var item_name: String = "Онлайн-покупка"

	if item_data != null:
		item_name = item_data.get_display_name().strip_edges()

		if item_name.is_empty():
			item_name = "Онлайн-покупка"

	var notification_text: String = "Списание за онлайн-покупку \"%s\": -$%d" % [item_name, price]
	freelance_state.call(
		"append_bank_history_entry",
		"shop_online",
		item_name,
		-price,
		"debited",
		notification_text
	)


func _get_player_economy() -> PlayerEconomyState:
	return get_node_or_null("/root/PlayerEconomy") as PlayerEconomyState


func _get_delivery_manager() -> Node:
	return get_node_or_null("/root/DeliveryManager")


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return "?"

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()


func _on_close_button_pressed() -> void:
	close_requested.emit()
