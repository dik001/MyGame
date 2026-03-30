class_name InventorySlotUI
extends Button

signal slot_pressed(slot_index: int)
signal equipment_slot_pressed(slot_name: StringName)
signal equipment_item_dropped(slot_name: StringName, data: Dictionary)

@onready var icon_texture_rect: TextureRect = $Content/IconTextureRect
@onready var fallback_label: Label = $Content/FallbackLabel
@onready var quantity_label: Label = $QuantityLabel

var _slot_index := -1
var _slot_data: InventorySlotData
var _slot_name: StringName = &""
var _drag_payload: Dictionary = {}
var _empty_placeholder_text: String = ""


func bind(slot_index: int, slot_data) -> void:
	_slot_index = slot_index
	_slot_name = &""
	_slot_data = slot_data as InventorySlotData
	_empty_placeholder_text = ""
	update_view()


func bind_equipment_slot(
	slot_name: StringName,
	slot_data,
	drag_payload: Dictionary = {},
	empty_placeholder_text: String = ""
) -> void:
	_slot_index = -1
	_slot_name = slot_name
	_slot_data = slot_data as InventorySlotData
	_drag_payload = drag_payload.duplicate(true)
	_empty_placeholder_text = empty_placeholder_text
	update_view()


func update_view() -> void:
	var has_item: bool = _slot_data != null and not _slot_data.is_empty() and _slot_data.item_data != null
	var item_data: ItemData = _slot_data.item_data if has_item else null
	var item_icon: Texture2D = item_data.icon if item_data != null else null

	icon_texture_rect.texture = item_icon
	icon_texture_rect.visible = item_icon != null
	fallback_label.visible = (has_item and item_icon == null) or (not has_item and not _empty_placeholder_text.is_empty())
	fallback_label.text = _get_fallback_text(item_data) if has_item else _empty_placeholder_text

	if has_item and _slot_data.quantity > 1:
		quantity_label.text = str(_slot_data.quantity)
		quantity_label.visible = true
	else:
		quantity_label.text = ""
		quantity_label.visible = false

	tooltip_text = ""

	if has_item:
		tooltip_text = "%s x%d" % [item_data.get_display_name(), _slot_data.quantity]
	elif not _empty_placeholder_text.is_empty():
		tooltip_text = _empty_placeholder_text


func _pressed() -> void:
	if _slot_name != &"":
		equipment_slot_pressed.emit(_slot_name)
		return

	if _slot_data == null or _slot_data.is_empty():
		return

	slot_pressed.emit(_slot_index)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _drag_payload.is_empty() or _slot_data == null or _slot_data.is_empty():
		return null

	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(160.0, 56.0)
	var label := Label.new()
	label.text = _slot_data.item_data.get_display_name() if _slot_data.item_data != null else ""
	preview.add_child(label)
	set_drag_preview(preview)
	return _drag_payload.duplicate(true)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _slot_name == &"":
		return false

	if not (data is Dictionary):
		return false

	var payload := data as Dictionary
	var drag_type := String(payload.get("drag_type", "")).strip_edges()
	var payload_slot := StringName(payload.get("equipment_slot", &""))

	if drag_type != "equipment_inventory_item":
		return false

	return payload_slot == _slot_name


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if _slot_name == &"" or not (data is Dictionary):
		return

	equipment_item_dropped.emit(_slot_name, (data as Dictionary).duplicate(true))


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()
