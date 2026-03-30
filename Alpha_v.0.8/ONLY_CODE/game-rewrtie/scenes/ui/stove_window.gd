class_name StoveWindow
extends CanvasLayer

signal close_requested
signal selection_changed(selected_items: Array)
signal cook_requested(selected_items: Array)

const SLOT_SCENE := preload("res://scenes/ui/InventorySlotUI.tscn")

const STATUS_COLOR_INFO := Color(0.82, 0.88, 0.97, 1.0)
const STATUS_COLOR_SUCCESS := Color(0.66, 1.0, 0.76, 1.0)
const STATUS_COLOR_WARNING := Color(1.0, 0.84, 0.52, 1.0)
const STATUS_COLOR_ERROR := Color(1.0, 0.65, 0.65, 1.0)

const WINDOW_TITLE_TEXT := "Плита"
const WINDOW_HINT_TEXT := "Esc - закрыть окно"
const INGREDIENTS_PANEL_TITLE_TEXT := "Конфорка"
const INGREDIENTS_PANEL_SUBTITLE_TEXT := "Нажмите на предмет справа, чтобы положить его на плиту."
const SUPPLY_PANEL_TITLE_TEXT := "Запасы"
const SUPPLY_PANEL_SUBTITLE_TEXT := "Инвентарь и холодильник"
const FIRE_BUTTON_TEXT := "Огонь"
const CLOSE_BUTTON_TEXT := "Закрыть"
const EMPTY_SUPPLY_TEXT := "Подходящих ингредиентов сейчас нет."
const EMPTY_SLOT_TEXT := "+"
const FILLED_SLOT_TOOLTIP_TEXT := "Нажмите, чтобы убрать ингредиент."
const FIRE_BUTTON_TOOLTIP_TEXT := "Начать готовку"
const INGREDIENT_SLOT_COUNT := 6

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/HeaderRow/TitleBlock/TitleLabel
@onready var hint_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/HeaderRow/TitleBlock/HintLabel
@onready var close_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/HeaderRow/CloseButton
@onready var ingredients_panel_title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/IngredientsPanel/MarginContainer/IngredientsContent/PanelTitleLabel
@onready var ingredients_panel_subtitle_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/IngredientsPanel/MarginContainer/IngredientsContent/SubtitleLabel
@onready var ingredient_slots_container: GridContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/IngredientsPanel/MarginContainer/IngredientsContent/IngredientSlotsContainer
@onready var status_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/IngredientsPanel/MarginContainer/IngredientsContent/StatusLabel
@onready var fire_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/IngredientsPanel/MarginContainer/IngredientsContent/FireButton
@onready var supply_panel_title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/SupplyPanel/MarginContainer/SupplyContent/PanelTitleLabel
@onready var supply_panel_subtitle_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/SupplyPanel/MarginContainer/SupplyContent/SubtitleLabel
@onready var supply_scroll_container: ScrollContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/SupplyPanel/MarginContainer/SupplyContent/Body/ScrollContainer
@onready var supply_slots_container: GridContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/SupplyPanel/MarginContainer/SupplyContent/Body/ScrollContainer/SupplySlotsContainer
@onready var supply_empty_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BodyRow/SupplyPanel/MarginContainer/SupplyContent/Body/EmptyLabel

var _station_title := WINDOW_TITLE_TEXT
var _supply_entries: Array = []
var _ingredient_slot_controls: Array[InventorySlotUI] = []
var _selected_items: Array = []
var _selection_report: Dictionary = {}
var _status_override_message := ""
var _status_override_color := STATUS_COLOR_INFO


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_static_texts()
	_build_ingredient_slots()
	_refresh_supply_grid()
	_refresh_ingredient_grid()
	_refresh_status()
	close_button.pressed.connect(_on_close_button_pressed)
	fire_button.pressed.connect(_on_fire_button_pressed)
	call_deferred("_grab_initial_focus")


func set_station_title(title: String) -> void:
	_station_title = title.strip_edges()

	if _station_title.is_empty():
		_station_title = WINDOW_TITLE_TEXT

	if is_inside_tree():
		title_label.text = _station_title


func set_supply_entries(entries: Array) -> void:
	_supply_entries = entries.duplicate(true)
	var selection_changed_by_sync := _prune_selection_to_supply()

	if is_inside_tree():
		_refresh_supply_grid()
		_refresh_ingredient_grid()

	if selection_changed_by_sync:
		_emit_selection_changed()


func set_selection_report(report: Dictionary) -> void:
	_selection_report = report.duplicate(true)

	if is_inside_tree():
		_refresh_status()


func get_selected_items() -> Array:
	return _selected_items.duplicate(true)


func clear_selection() -> void:
	if _selected_items.is_empty():
		return

	_selected_items.clear()
	_status_override_message = ""

	if is_inside_tree():
		_refresh_ingredient_grid()
		_refresh_supply_grid()
		_refresh_status()

	_emit_selection_changed()


func show_status_message(message: String, color: Color = STATUS_COLOR_INFO) -> void:
	_status_override_message = message.strip_edges()
	_status_override_color = color

	if is_inside_tree():
		_refresh_status()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_static_texts() -> void:
	title_label.text = _station_title
	hint_label.text = WINDOW_HINT_TEXT
	close_button.text = CLOSE_BUTTON_TEXT
	ingredients_panel_title_label.text = INGREDIENTS_PANEL_TITLE_TEXT
	ingredients_panel_subtitle_label.text = INGREDIENTS_PANEL_SUBTITLE_TEXT
	supply_panel_title_label.text = SUPPLY_PANEL_TITLE_TEXT
	supply_panel_subtitle_label.text = SUPPLY_PANEL_SUBTITLE_TEXT
	supply_empty_label.text = EMPTY_SUPPLY_TEXT
	fire_button.text = FIRE_BUTTON_TEXT
	fire_button.tooltip_text = FIRE_BUTTON_TOOLTIP_TEXT


func _build_ingredient_slots() -> void:
	for child in ingredient_slots_container.get_children():
		ingredient_slots_container.remove_child(child)
		child.queue_free()

	_ingredient_slot_controls.clear()

	for slot_index in range(INGREDIENT_SLOT_COUNT):
		var slot_control := SLOT_SCENE.instantiate() as InventorySlotUI

		if slot_control == null:
			continue

		slot_control.equipment_slot_pressed.connect(_on_ingredient_slot_pressed)
		ingredient_slots_container.add_child(slot_control)
		slot_control.bind_equipment_slot(StringName(str(slot_index)), null, {}, EMPTY_SLOT_TEXT)
		_ingredient_slot_controls.append(slot_control)


func _refresh_ingredient_grid() -> void:
	for slot_index in range(_ingredient_slot_controls.size()):
		var slot_control := _ingredient_slot_controls[slot_index]

		if slot_control == null:
			continue

		var selected_item: Dictionary = {}

		if slot_index < _selected_items.size():
			selected_item = _selected_items[slot_index] as Dictionary

		var item_data := selected_item.get("item_data") as ItemData

		if item_data == null:
			slot_control.bind_equipment_slot(StringName(str(slot_index)), null, {}, EMPTY_SLOT_TEXT)
			slot_control.tooltip_text = ""
			continue

		var slot_data := InventorySlotData.new(item_data, 1)
		slot_control.bind_equipment_slot(StringName(str(slot_index)), slot_data, {}, EMPTY_SLOT_TEXT)
		slot_control.tooltip_text = FILLED_SLOT_TOOLTIP_TEXT


func _refresh_supply_grid() -> void:
	for child in supply_slots_container.get_children():
		supply_slots_container.remove_child(child)
		child.queue_free()

	var visible_entry_count := 0

	for entry_index in range(_supply_entries.size()):
		var supply_entry := _supply_entries[entry_index] as Dictionary
		var item_data := supply_entry.get("item_data") as ItemData
		var total_quantity := int(supply_entry.get("quantity", 0))
		var remaining_quantity := total_quantity - _get_selected_quantity_for_item(item_data)

		if item_data == null or remaining_quantity <= 0:
			continue

		var slot_control := SLOT_SCENE.instantiate() as InventorySlotUI

		if slot_control == null:
			continue

		var slot_data := InventorySlotData.new(item_data, remaining_quantity)
		slot_control.slot_pressed.connect(_on_supply_slot_pressed)
		supply_slots_container.add_child(slot_control)
		slot_control.bind(entry_index, slot_data)
		slot_control.tooltip_text = "%s x%d" % [item_data.get_display_name(), remaining_quantity]
		visible_entry_count += 1

	supply_empty_label.visible = visible_entry_count == 0
	supply_scroll_container.visible = visible_entry_count > 0


func _refresh_status() -> void:
	var report_message := String(_selection_report.get("message", "")).strip_edges()
	var has_override := not _status_override_message.is_empty()
	var resolved_message := _status_override_message if has_override else report_message
	var resolved_color := _status_override_color if has_override else _resolve_report_color()

	status_label.text = resolved_message
	status_label.visible = not resolved_message.is_empty()
	status_label.add_theme_color_override("font_color", resolved_color)

	var can_cook := bool(_selection_report.get("can_cook", false))
	fire_button.disabled = not can_cook
	fire_button.tooltip_text = FIRE_BUTTON_TOOLTIP_TEXT if can_cook else resolved_message


func _resolve_report_color() -> Color:
	match String(_selection_report.get("state", "")):
		"ready":
			return STATUS_COLOR_SUCCESS
		"partial":
			return STATUS_COLOR_WARNING
		"blocked", "invalid":
			return STATUS_COLOR_ERROR
		_:
			return STATUS_COLOR_INFO


func _prune_selection_to_supply() -> bool:
	if _selected_items.is_empty():
		return false

	var next_selection: Array = []
	var changed := false

	for selected_item_variant in _selected_items:
		var selected_item := selected_item_variant as Dictionary
		var item_data := selected_item.get("item_data") as ItemData

		if item_data == null:
			changed = true
			continue

		var already_selected := _get_quantity_for_item_in_array(next_selection, item_data)

		if already_selected >= _get_supply_quantity_for_item(item_data):
			changed = true
			continue

		next_selection.append({
			"item_data": item_data,
			"quantity": 1,
		})

	if next_selection.size() != _selected_items.size():
		changed = true

	_selected_items = next_selection
	return changed


func _get_supply_quantity_for_item(item_data: ItemData) -> int:
	for supply_entry_variant in _supply_entries:
		var supply_entry := supply_entry_variant as Dictionary
		var supply_item := supply_entry.get("item_data") as ItemData

		if supply_item == null or item_data == null or not supply_item.matches(item_data):
			continue

		return int(supply_entry.get("quantity", 0))

	return 0


func _get_selected_quantity_for_item(item_data: ItemData) -> int:
	return _get_quantity_for_item_in_array(_selected_items, item_data)


func _get_quantity_for_item_in_array(entries: Array, item_data: ItemData) -> int:
	if item_data == null:
		return 0

	var total_quantity := 0

	for entry_variant in entries:
		var entry := entry_variant as Dictionary
		var entry_item := entry.get("item_data") as ItemData

		if entry_item == null or not entry_item.matches(item_data):
			continue

		total_quantity += int(entry.get("quantity", 1))

	return total_quantity


func _find_next_empty_slot_index() -> int:
	if _selected_items.size() >= INGREDIENT_SLOT_COUNT:
		return -1

	return _selected_items.size()


func _emit_selection_changed() -> void:
	selection_changed.emit(get_selected_items())


func _grab_initial_focus() -> void:
	if close_button != null:
		close_button.grab_focus()


func _on_supply_slot_pressed(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _supply_entries.size():
		return

	var supply_entry := _supply_entries[slot_index] as Dictionary
	var item_data := supply_entry.get("item_data") as ItemData

	if item_data == null:
		return

	if _get_selected_quantity_for_item(item_data) >= int(supply_entry.get("quantity", 0)):
		return

	if _find_next_empty_slot_index() < 0:
		show_status_message("На плите больше нет свободных ячеек.", STATUS_COLOR_WARNING)
		return

	_selected_items.append({
		"item_data": item_data,
		"quantity": 1,
	})
	_status_override_message = ""
	_refresh_ingredient_grid()
	_refresh_supply_grid()
	_refresh_status()
	_emit_selection_changed()


func _on_ingredient_slot_pressed(slot_name: StringName) -> void:
	var slot_index := int(String(slot_name))

	if slot_index < 0 or slot_index >= _selected_items.size():
		return

	_selected_items.remove_at(slot_index)
	_status_override_message = ""
	_refresh_ingredient_grid()
	_refresh_supply_grid()
	_refresh_status()
	_emit_selection_changed()


func _on_fire_button_pressed() -> void:
	if fire_button.disabled:
		return

	cook_requested.emit(get_selected_items())


func _on_close_button_pressed() -> void:
	close_requested.emit()
