class_name ItemPopupUI
extends Control

signal action_requested(slot_index: int, action_id: StringName)
signal close_requested

@onready var title_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var icon_texture_rect: TextureRect = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ItemRow/IconPanel/IconTextureRect
@onready var fallback_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ItemRow/IconPanel/FallbackLabel
@onready var name_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ItemRow/InfoColumn/NameLabel
@onready var quantity_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ItemRow/InfoColumn/QuantityLabel
@onready var description_label: Label = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var primary_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/PrimaryButton
@onready var secondary_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/SecondaryButton
@onready var close_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/CloseButton

var _slot_index := -1
var _slot_data: InventorySlotData
var _window_title: String = "\u041F\u0440\u0435\u0434\u043C\u0435\u0442"
var _primary_action: Dictionary = {}
var _secondary_action: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	primary_button.pressed.connect(_on_primary_button_pressed)
	secondary_button.pressed.connect(_on_secondary_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)


func present(slot_index: int, slot_data: InventorySlotData, config: Dictionary = {}) -> void:
	_slot_index = slot_index
	_slot_data = slot_data
	_window_title = String(config.get("window_title", "\u041F\u0440\u0435\u0434\u043C\u0435\u0442"))
	_primary_action = _normalize_action_config(config.get("primary_action", {}))
	_secondary_action = _normalize_action_config(config.get("secondary_action", {}))
	visible = true
	_update_view()


func refresh_slot(slot_index: int, slot_data: InventorySlotData) -> void:
	_slot_index = slot_index
	_slot_data = slot_data

	if _slot_data == null or _slot_data.is_empty():
		close_popup()
		return

	_update_view()


func is_open() -> bool:
	return visible and _slot_index >= 0


func get_slot_index() -> int:
	return _slot_index


func close_popup() -> void:
	visible = false
	_slot_index = -1
	_slot_data = null


func _update_view() -> void:
	if _slot_data == null or _slot_data.is_empty() or _slot_data.item_data == null:
		close_popup()
		return

	var item_data: ItemData = _slot_data.item_data
	var item_icon: Texture2D = item_data.icon

	title_label.text = _window_title
	name_label.text = item_data.get_display_name()
	quantity_label.text = "\u041A\u043E\u043B-\u0432\u043E: %d" % _slot_data.quantity
	description_label.text = item_data.description if not item_data.description.is_empty() else "\u0411\u0435\u0437 \u043E\u043F\u0438\u0441\u0430\u043D\u0438\u044F."
	icon_texture_rect.texture = item_icon
	icon_texture_rect.visible = item_icon != null
	fallback_label.visible = item_icon == null
	fallback_label.text = _get_fallback_text(item_data)
	_apply_action_to_button(primary_button, _primary_action)
	_apply_action_to_button(secondary_button, _secondary_action)


func _normalize_action_config(raw_action_config: Variant) -> Dictionary:
	var action_config: Dictionary = {}

	if raw_action_config is Dictionary:
		action_config = raw_action_config

	return {
		"id": StringName(action_config.get("id", &"")),
		"label": String(action_config.get("label", "")),
		"visible": bool(action_config.get("visible", true)),
		"enabled": bool(action_config.get("enabled", true)),
	}


func _apply_action_to_button(button: Button, action_config: Dictionary) -> void:
	var label: String = String(action_config.get("label", ""))
	var is_visible: bool = bool(action_config.get("visible", true)) and not label.is_empty()

	button.text = label
	button.visible = is_visible
	button.disabled = not bool(action_config.get("enabled", true))


func _get_fallback_text(item_data: ItemData) -> String:
	if item_data == null:
		return ""

	var display_name: String = item_data.get_display_name().strip_edges()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()


func _emit_action_requested(action_config: Dictionary) -> void:
	var action_id: StringName = StringName(action_config.get("id", &""))

	if action_id == &"":
		return

	action_requested.emit(_slot_index, action_id)


func _on_primary_button_pressed() -> void:
	_emit_action_requested(_primary_action)


func _on_secondary_button_pressed() -> void:
	_emit_action_requested(_secondary_action)


func _on_close_button_pressed() -> void:
	close_requested.emit()
