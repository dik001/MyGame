class_name InventoryRowUI
extends Button

signal row_selected(slot_index: int)
signal row_activated(slot_index: int)
signal row_drop_requested(slot_index: int, data: Dictionary)

@onready var icon_texture_rect: TextureRect = $MarginContainer/ContentRow/IconPanel/IconTextureRect
@onready var fallback_label: Label = $MarginContainer/ContentRow/IconPanel/FallbackLabel
@onready var name_label: Label = $MarginContainer/ContentRow/NameLabel
@onready var weight_label: Label = $MarginContainer/ContentRow/WeightLabel
@onready var freshness_label: Label = $MarginContainer/ContentRow/FreshnessLabel
@onready var quantity_label: Label = $MarginContainer/ContentRow/QuantityLabel

var _slot_index := -1
var _slot_data: InventorySlotData
var _freshness_display_multiplier: float = 1.0
var _drag_payload: Dictionary = {}
var _accepted_drop_types: PackedStringArray = PackedStringArray()


func _ready() -> void:
	if _slot_index >= 0:
		_refresh_view()


func bind_row(slot_index: int, slot_data: InventorySlotData, freshness_display_multiplier: float = 1.0) -> void:
	_slot_index = slot_index
	_slot_data = slot_data
	_freshness_display_multiplier = max(freshness_display_multiplier, 0.0001)

	if is_node_ready():
		_refresh_view()


func get_slot_index() -> int:
	return _slot_index


func get_slot_data() -> InventorySlotData:
	return _slot_data


func set_drag_payload(payload: Dictionary) -> void:
	_drag_payload = payload.duplicate(true)


func set_accepted_drop_types(drag_types: PackedStringArray) -> void:
	_accepted_drop_types = drag_types.duplicate()


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


func _get_drag_data(_at_position: Vector2) -> Variant:
	if _drag_payload.is_empty() or _slot_data == null or _slot_data.is_empty():
		return null

	var preview := _build_drag_preview()

	if preview != null:
		set_drag_preview(preview)

	return _drag_payload.duplicate(true)


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if _accepted_drop_types.is_empty():
		return false

	if not (data is Dictionary):
		return false

	var drag_type := String((data as Dictionary).get("drag_type", "")).strip_edges()
	return _accepted_drop_types.has(drag_type)


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	if not (data is Dictionary):
		return

	row_drop_requested.emit(_slot_index, (data as Dictionary).duplicate(true))


func _refresh_view() -> void:
	var has_item := _slot_data != null and not _slot_data.is_empty() and _slot_data.item_data != null
	var item_data: ItemData = _slot_data.item_data if has_item else null
	var item_icon: Texture2D = item_data.icon if item_data != null else null

	name_label.text = item_data.get_display_name() if item_data != null else ""
	weight_label.text = "%.1f" % _slot_data.get_total_weight() if has_item else "0.0"
	freshness_label.text = _slot_data.get_freshness_text(_freshness_display_multiplier) if has_item else ""
	quantity_label.text = str(_slot_data.quantity) if has_item else "0"
	icon_texture_rect.texture = item_icon
	icon_texture_rect.visible = item_icon != null
	fallback_label.visible = has_item and item_icon == null
	fallback_label.text = _get_fallback_text(item_data)

	if has_item and _slot_data.is_spoiled():
		freshness_label.add_theme_color_override("font_color", Color(1.0, 0.72, 0.72, 1.0))
	else:
		freshness_label.remove_theme_color_override("font_color")

	tooltip_text = _build_tooltip()


func _build_tooltip() -> String:
	if _slot_data == null or _slot_data.is_empty() or _slot_data.item_data == null:
		return ""

	var tooltip_lines: Array[String] = [
		"%s | %.1f | x%d" % [
			_slot_data.item_data.get_display_name(),
			_slot_data.get_total_weight(),
			_slot_data.quantity,
		]
	]
	var freshness_text: String = _slot_data.get_freshness_tooltip_text(_freshness_display_multiplier)

	if not freshness_text.is_empty():
		tooltip_lines.append(freshness_text)

	return "\n".join(tooltip_lines)


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	var display_name := item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()


func _build_drag_preview() -> Control:
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(180.0, 56.0)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	preview.add_child(margin)

	var label := Label.new()
	label.text = _slot_data.item_data.get_display_name() if _slot_data != null and _slot_data.item_data != null else ""
	margin.add_child(label)
	return preview
