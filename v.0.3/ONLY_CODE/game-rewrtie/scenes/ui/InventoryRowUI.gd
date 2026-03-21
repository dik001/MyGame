class_name InventoryRowUI
extends Button

signal row_selected(slot_index: int)
signal row_activated(slot_index: int)

@onready var icon_texture_rect: TextureRect = $MarginContainer/ContentRow/IconPanel/IconTextureRect
@onready var fallback_label: Label = $MarginContainer/ContentRow/IconPanel/FallbackLabel
@onready var name_label: Label = $MarginContainer/ContentRow/NameLabel
@onready var weight_label: Label = $MarginContainer/ContentRow/WeightLabel
@onready var quantity_label: Label = $MarginContainer/ContentRow/QuantityLabel

var _slot_index := -1
var _slot_data: InventorySlotData


func _ready() -> void:
	if _slot_index >= 0:
		_refresh_view()


func bind_row(slot_index: int, slot_data: InventorySlotData) -> void:
	_slot_index = slot_index
	_slot_data = slot_data

	if is_node_ready():
		_refresh_view()


func get_slot_index() -> int:
	return _slot_index


func get_slot_data() -> InventorySlotData:
	return _slot_data


func set_selected(is_selected: bool) -> void:
	button_pressed = is_selected


func _pressed() -> void:
	if _slot_data == null or _slot_data.is_empty():
		return

	row_selected.emit(_slot_index)


func _gui_input(event: InputEvent) -> void:
	var mouse_button := event as InputEventMouseButton

	if mouse_button == null:
		return

	if mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed and mouse_button.double_click:
		if _slot_data == null or _slot_data.is_empty():
			return

		row_activated.emit(_slot_index)


func _refresh_view() -> void:
	var has_item := _slot_data != null and not _slot_data.is_empty() and _slot_data.item_data != null
	var item_data: ItemData = _slot_data.item_data if has_item else null
	var item_icon: Texture2D = item_data.icon if item_data != null else null

	name_label.text = item_data.get_display_name() if item_data != null else ""
	weight_label.text = "%.1f" % _slot_data.get_total_weight() if has_item else "0.0"
	quantity_label.text = str(_slot_data.quantity) if has_item else "0"
	icon_texture_rect.texture = item_icon
	icon_texture_rect.visible = item_icon != null
	fallback_label.visible = has_item and item_icon == null
	fallback_label.text = _get_fallback_text(item_data)
	tooltip_text = _build_tooltip()


func _build_tooltip() -> String:
	if _slot_data == null or _slot_data.is_empty() or _slot_data.item_data == null:
		return ""

	return "%s | %.1f | x%d" % [
		_slot_data.item_data.get_display_name(),
		_slot_data.get_total_weight(),
		_slot_data.quantity,
	]


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	var display_name := item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()
