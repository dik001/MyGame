class_name ShopWindow
extends PanelContainer

signal close_requested

const ITEM_ICON_OUTLINE_MATERIAL := preload("res://resources/ui/item_icon_outline_material.tres")
const FALLBACK_OUTLINE_COLOR := Color(0.02, 0.04, 0.08, 1.0)
const DEFAULT_WINDOW_TITLE := "\u041c\u0430\u0433\u0430\u0437\u0438\u043d"
const DEFAULT_WINDOW_SUBTITLE := "\u0415\u0434\u0430 \u043f\u043e\u043a\u0443\u043f\u0430\u0435\u0442\u0441\u044f \u0437\u0430 \u0434\u043e\u043b\u043b\u0430\u0440\u044b \u0438 \u043f\u0440\u0438\u0435\u0437\u0436\u0430\u0435\u0442 \u0447\u0435\u0440\u0435\u0437 4 \u0438\u0433\u0440\u043e\u0432\u044b\u0445 \u0447\u0430\u0441\u0430."

@export var catalog: Array[ItemData] = []
@export var window_title_text: String = DEFAULT_WINDOW_TITLE
@export_multiline var window_subtitle_text: String = DEFAULT_WINDOW_SUBTITLE
@export var price_overrides: Dictionary = {}
@export var use_delivery: bool = true

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var balance_label: Label = $MarginContainer/Content/TitleRow/BalanceLabel
@onready var close_button: Button = $MarginContainer/Content/TitleRow/CloseButton
@onready var subtitle_label: Label = $MarginContainer/Content/SubtitleLabel
@onready var scroll_container: ScrollContainer = $MarginContainer/Content/ScrollContainer
@onready var items_container: VBoxContainer = $MarginContainer/Content/ScrollContainer/ItemsContainer
@onready var status_label: Label = $MarginContainer/Content/StatusLabel


func _ready() -> void:
	_apply_window_texts()
	close_button.text = "\u0417\u0430\u043a\u0440\u044b\u0442\u044c"
	status_label.visible = false
	close_button.pressed.connect(_on_close_button_pressed)

	if not PlayerEconomy.cash_dollars_changed.is_connected(_on_cash_dollars_changed):
		PlayerEconomy.cash_dollars_changed.connect(_on_cash_dollars_changed)

	_on_cash_dollars_changed(PlayerEconomy.get_cash_dollars())
	_rebuild_catalog()


func open_window() -> void:
	visible = true
	status_label.visible = false
	_apply_window_texts()
	_rebuild_catalog()
	_on_cash_dollars_changed(PlayerEconomy.get_cash_dollars())

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
	buy_button.text = "\u041a\u0443\u043f\u0438\u0442\u044c"
	buy_button.add_theme_font_size_override("font_size", 22)
	buy_button.pressed.connect(_on_buy_button_pressed.bind(item_data))
	content_row.add_child(buy_button)

	return row_panel


func _on_buy_button_pressed(item_data: ItemData) -> void:
	if item_data == null:
		_show_status("\u0422\u043e\u0432\u0430\u0440 \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d.")
		return

	var price: int = _resolve_item_price(item_data)
	var player_inventory: PlayerInventoryState = get_node_or_null("/root/PlayerInventory") as PlayerInventoryState

	if not use_delivery:
		if player_inventory == null:
			_show_status("\u0418\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c \u043d\u0435\u0434\u043e\u0441\u0442\u0443\u043f\u0435\u043d.")
			return

		if not player_inventory.can_add_item(item_data, 1):
			_show_status("\u041d\u0435\u0442 \u043c\u0435\u0441\u0442\u0430 \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u0435.")
			return

	if not PlayerEconomy.spend_cash_dollars(price):
		_show_status("\u041d\u0435\u0434\u043e\u0441\u0442\u0430\u0442\u043e\u0447\u043d\u043e \u0434\u043e\u043b\u043b\u0430\u0440\u043e\u0432.")
		return

	if not use_delivery:
		if not player_inventory.add_item(item_data, 1):
			PlayerEconomy.add_cash_dollars(price, false)
			_show_status("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0434\u043e\u0431\u0430\u0432\u0438\u0442\u044c \u043f\u0440\u0435\u0434\u043c\u0435\u0442 \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c.")
			return

		_show_status("\u041f\u043e\u043a\u0443\u043f\u043a\u0430 \u0434\u043e\u0431\u0430\u0432\u043b\u0435\u043d\u0430 \u0432 \u0438\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c.")
		return

	var delivery: Dictionary = DeliveryManager.create_delivery([
		{
			"item_data": item_data,
			"quantity": 1,
		}
	])

	if delivery.is_empty():
		PlayerEconomy.add_cash_dollars(price, false)
		_show_status("\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u043e\u0444\u043e\u0440\u043c\u0438\u0442\u044c \u0434\u043e\u0441\u0442\u0430\u0432\u043a\u0443.")
		return

	var delivery_id: int = int(delivery.get("id", 0))
	_show_status("\u0417\u0430\u043a\u0430\u0437 #%d \u043e\u0444\u043e\u0440\u043c\u043b\u0435\u043d. \u0414\u043e\u0441\u0442\u0430\u0432\u043a\u0430 \u0447\u0435\u0440\u0435\u0437 4 \u0447\u0430\u0441\u0430." % delivery_id)


func _on_cash_dollars_changed(new_value: int) -> void:
	if balance_label == null:
		return

	balance_label.text = "\u041d\u0430\u043b\u0438\u0447\u043d\u044b\u0435: $%d" % new_value


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


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return "?"

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()


func _on_close_button_pressed() -> void:
	close_requested.emit()
