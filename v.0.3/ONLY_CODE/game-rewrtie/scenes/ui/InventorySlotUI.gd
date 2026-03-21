class_name InventorySlotUI
extends Button

signal slot_pressed(slot_index: int)

@onready var icon_texture_rect: TextureRect = $Content/IconTextureRect
@onready var fallback_label: Label = $Content/FallbackLabel
@onready var quantity_label: Label = $QuantityLabel

var _slot_index := -1
var _slot_data: InventorySlotData


func bind(slot_index: int, slot_data) -> void:
	_slot_index = slot_index
	_slot_data = slot_data as InventorySlotData
	update_view()


func update_view() -> void:
	var has_item: bool = _slot_data != null and not _slot_data.is_empty() and _slot_data.item_data != null
	var item_data: ItemData = _slot_data.item_data if has_item else null
	var item_icon: Texture2D = item_data.icon if item_data != null else null

	icon_texture_rect.texture = item_icon
	icon_texture_rect.visible = item_icon != null
	fallback_label.visible = has_item and item_icon == null
	fallback_label.text = _get_fallback_text(item_data)

	if has_item and _slot_data.quantity > 1:
		quantity_label.text = str(_slot_data.quantity)
		quantity_label.visible = true
	else:
		quantity_label.text = ""
		quantity_label.visible = false

	tooltip_text = ""

	if has_item:
		tooltip_text = "%s x%d" % [item_data.get_display_name(), _slot_data.quantity]


func _pressed() -> void:
	if _slot_data == null or _slot_data.is_empty():
		return

	slot_pressed.emit(_slot_index)


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()
