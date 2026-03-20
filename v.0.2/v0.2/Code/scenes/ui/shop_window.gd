class_name ShopWindow
extends PanelContainer

signal close_requested

const ITEM_ICON_OUTLINE_MATERIAL := preload("res://resources/ui/item_icon_outline_material.tres")
const FALLBACK_OUTLINE_COLOR := Color(0.02, 0.04, 0.08, 1.0)

@export var catalog: Array[ItemData] = []

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var balance_label: Label = $MarginContainer/Content/TitleRow/BalanceLabel
@onready var close_button: Button = $MarginContainer/Content/TitleRow/CloseButton
@onready var subtitle_label: Label = $MarginContainer/Content/SubtitleLabel
@onready var scroll_container: ScrollContainer = $MarginContainer/Content/ScrollContainer
@onready var items_container: VBoxContainer = $MarginContainer/Content/ScrollContainer/ItemsContainer
@onready var status_label: Label = $MarginContainer/Content/StatusLabel


func _ready() -> void:
	title_label.text = "\u041C\u0430\u0433\u0430\u0437\u0438\u043D"
	subtitle_label.text = "\u0415\u0434\u0430 \u043F\u043E\u043A\u0443\u043F\u0430\u0435\u0442\u0441\u044F \u0437\u0430 \u0434\u043E\u043B\u043B\u0430\u0440\u044B \u0438 \u043F\u0440\u0438\u0435\u0437\u0436\u0430\u0435\u0442 \u0447\u0435\u0440\u0435\u0437 4 \u0438\u0433\u0440\u043E\u0432\u044B\u0445 \u0447\u0430\u0441\u0430."
	close_button.text = "\u0417\u0430\u043A\u0440\u044B\u0442\u044C"
	status_label.visible = false
	close_button.pressed.connect(_on_close_button_pressed)

	if not PlayerEconomy.dollars_changed.is_connected(_on_dollars_changed):
		PlayerEconomy.dollars_changed.connect(_on_dollars_changed)

	_on_dollars_changed(PlayerEconomy.get_dollars())
	_rebuild_catalog()


func open_window() -> void:
	visible = true
	status_label.visible = false
	_on_dollars_changed(PlayerEconomy.get_dollars())

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
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
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
	price_label.text = "$%d" % item_data.get_effective_price()
	price_label.add_theme_font_size_override("font_size", 20)
	info_box.add_child(price_label)

	var buy_button: Button = Button.new()
	buy_button.custom_minimum_size = Vector2(170, 54)
	buy_button.text = "\u041A\u0443\u043F\u0438\u0442\u044C"
	buy_button.add_theme_font_size_override("font_size", 22)
	buy_button.pressed.connect(_on_buy_button_pressed.bind(item_data))
	content_row.add_child(buy_button)

	return row_panel


func _on_buy_button_pressed(item_data: ItemData) -> void:
	if item_data == null:
		_show_status("\u0422\u043E\u0432\u0430\u0440 \u043D\u0435 \u043D\u0430\u0439\u0434\u0435\u043D.")
		return

	var price: int = item_data.get_effective_price()

	if not PlayerEconomy.spend_dollars(price):
		_show_status("\u041D\u0435\u0434\u043E\u0441\u0442\u0430\u0442\u043E\u0447\u043D\u043E \u0434\u043E\u043B\u043B\u0430\u0440\u043E\u0432.")
		return

	var delivery: Dictionary = DeliveryManager.create_delivery([
		{
			"item_data": item_data,
			"quantity": 1,
		}
	])

	if delivery.is_empty():
		PlayerEconomy.add_dollars(price)
		_show_status("\u041D\u0435 \u0443\u0434\u0430\u043B\u043E\u0441\u044C \u043E\u0444\u043E\u0440\u043C\u0438\u0442\u044C \u0434\u043E\u0441\u0442\u0430\u0432\u043A\u0443.")
		return

	var delivery_id: int = int(delivery.get("id", 0))
	_show_status("\u0417\u0430\u043A\u0430\u0437 #%d \u043E\u0444\u043E\u0440\u043C\u043B\u0435\u043D. \u0414\u043E\u0441\u0442\u0430\u0432\u043A\u0430 \u0447\u0435\u0440\u0435\u0437 4 \u0447\u0430\u0441\u0430." % delivery_id)


func _on_dollars_changed(new_value: int) -> void:
	if balance_label == null:
		return

	balance_label.text = "\u0411\u0430\u043B\u0430\u043D\u0441: $%d" % new_value


func _show_status(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return "?"

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()


func _on_close_button_pressed() -> void:
	close_requested.emit()
