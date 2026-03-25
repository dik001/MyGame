class_name StorageWindow
extends CanvasLayer

signal close_requested
signal store_requested(slot_index: int)
signal take_requested(slot_index: int)
signal consume_requested(slot_index: int)

const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")

const WINDOW_TITLE_TEXT := "\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435"
const CLOSE_HINT_TEXT := "Esc - \u0437\u0430\u043a\u0440\u044b\u0442\u044c \u043e\u043a\u043d\u043e"
const PLAYER_PANEL_TITLE_TEXT := "\u0418\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c"
const DEFAULT_STORAGE_PANEL_TITLE_TEXT := "\u0425\u0440\u0430\u043d\u0438\u043b\u0438\u0449\u0435"
const PLAYER_EMPTY_TEXT := "\u0418\u043d\u0432\u0435\u043d\u0442\u0430\u0440\u044c \u043f\u0443\u0441\u0442"
const NAME_HEADER_TEXT := "\u041d\u0430\u0437\u0432\u0430\u043d\u0438\u0435"
const WEIGHT_HEADER_TEXT := "\u0412\u0435\u0441"
const FRESHNESS_HEADER_TEXT := "\u0421\u0432\u0435\u0436\u0435\u0441\u0442\u044c"
const QUANTITY_HEADER_TEXT := "\u041a\u043e\u043b-\u0432\u043e"
const TOTAL_WEIGHT_TEMPLATE := "\u041e\u0431\u0449\u0438\u0439 \u0432\u0435\u0441: %.1f"
const STORE_BUTTON_TEXT := "\u041f\u043e\u043b\u043e\u0436\u0438\u0442\u044c"
const TAKE_BUTTON_TEXT := "\u0412\u0437\u044f\u0442\u044c"
const CONSUME_BUTTON_TEXT := "\u0421\u044a\u0435\u0441\u0442\u044c"
const CLOSE_BUTTON_TEXT := "\u0417\u0430\u043a\u0440\u044b\u0442\u044c"
const STORAGE_EMPTY_TEMPLATE := "%s \u043f\u0443\u0441\u0442"

@onready var overlay: Control = $Overlay
@onready var title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/TitleLabel
@onready var hint_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/HintLabel
@onready var player_panel_title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/PanelTitleLabel
@onready var player_name_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/HeaderPanel/HeaderRow/NameHeader
@onready var player_weight_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/HeaderPanel/HeaderRow/WeightHeader
@onready var player_freshness_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/HeaderPanel/HeaderRow/FreshnessHeader
@onready var player_quantity_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/HeaderPanel/HeaderRow/QuantityHeader
@onready var player_scroll_container: ScrollContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/Body/ScrollContainer
@onready var player_rows_container: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/Body/ScrollContainer/RowsContainer
@onready var player_empty_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/Body/EmptyLabel
@onready var player_total_weight_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/FooterRow/TotalWeightLabel
@onready var store_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/PlayerPanel/MarginContainer/PlayerContent/FooterRow/StoreButton
@onready var storage_panel_title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/PanelTitleLabel
@onready var storage_name_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/HeaderPanel/HeaderRow/NameHeader
@onready var storage_weight_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/HeaderPanel/HeaderRow/WeightHeader
@onready var storage_freshness_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/HeaderPanel/HeaderRow/FreshnessHeader
@onready var storage_quantity_header_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/HeaderPanel/HeaderRow/QuantityHeader
@onready var storage_scroll_container: ScrollContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/Body/ScrollContainer
@onready var storage_rows_container: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/Body/ScrollContainer/RowsContainer
@onready var storage_empty_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/Body/EmptyLabel
@onready var storage_total_weight_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/FooterRow/TotalWeightLabel
@onready var take_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/FooterRow/TakeButton
@onready var consume_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/PanelsRow/StoragePanel/MarginContainer/StorageContent/FooterRow/ConsumeButton
@onready var status_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/StatusLabel
@onready var close_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/Content/BottomRow/CloseButton

var _player_slots: Array = []
var _storage_slots: Array = []
var _player_row_controls: Array = []
var _storage_row_controls: Array = []
var _selected_player_slot_index := -1
var _selected_storage_slot_index := -1
var _storage_title: String = ""
var _storage_supports_consume: bool = false
var _player_freshness_display_multiplier: float = 1.0
var _storage_freshness_display_multiplier: float = 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_static_texts()
	show_status_message("")
	store_button.pressed.connect(_on_store_button_pressed)
	take_button.pressed.connect(_on_take_button_pressed)
	consume_button.pressed.connect(_on_consume_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_refresh_player_panel()
	_refresh_storage_panel()
	call_deferred("_grab_initial_focus")


func set_storage_title(title: String) -> void:
	_storage_title = title.strip_edges()

	if is_inside_tree():
		_refresh_storage_title()


func set_player_slots(slots: Array) -> void:
	_player_slots = slots.duplicate()

	if is_inside_tree():
		_refresh_player_panel()


func set_storage_slots(slots: Array) -> void:
	_storage_slots = slots.duplicate()

	if is_inside_tree():
		_refresh_storage_panel()


func set_player_freshness_display_multiplier(multiplier: float) -> void:
	_player_freshness_display_multiplier = max(multiplier, 0.0001)

	if is_inside_tree():
		_refresh_player_panel()


func set_storage_freshness_display_multiplier(multiplier: float) -> void:
	_storage_freshness_display_multiplier = max(multiplier, 0.0001)

	if is_inside_tree():
		_refresh_storage_panel()


func set_storage_supports_consume(is_supported: bool) -> void:
	_storage_supports_consume = is_supported

	if is_inside_tree():
		_update_storage_action_buttons()


func show_status_message(message: String) -> void:
	status_label.text = message
	status_label.visible = not message.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_static_texts() -> void:
	title_label.text = WINDOW_TITLE_TEXT
	hint_label.text = CLOSE_HINT_TEXT
	player_panel_title_label.text = PLAYER_PANEL_TITLE_TEXT
	player_name_header_label.text = NAME_HEADER_TEXT
	player_weight_header_label.text = WEIGHT_HEADER_TEXT
	player_freshness_header_label.text = FRESHNESS_HEADER_TEXT
	player_quantity_header_label.text = QUANTITY_HEADER_TEXT
	player_empty_label.text = PLAYER_EMPTY_TEXT
	store_button.text = STORE_BUTTON_TEXT
	storage_name_header_label.text = NAME_HEADER_TEXT
	storage_weight_header_label.text = WEIGHT_HEADER_TEXT
	storage_freshness_header_label.text = FRESHNESS_HEADER_TEXT
	storage_quantity_header_label.text = QUANTITY_HEADER_TEXT
	take_button.text = TAKE_BUTTON_TEXT
	consume_button.text = CONSUME_BUTTON_TEXT
	close_button.text = CLOSE_BUTTON_TEXT
	_refresh_storage_title()


func _refresh_storage_title() -> void:
	var resolved_storage_title := _get_storage_title_text()

	storage_panel_title_label.text = resolved_storage_title
	storage_empty_label.text = STORAGE_EMPTY_TEMPLATE % resolved_storage_title


func _refresh_player_panel() -> void:
	_clear_player_rows()
	var has_items := false
	var selection_is_valid := false

	for slot_index in range(_player_slots.size()):
		var slot_data := _player_slots[slot_index] as InventorySlotData

		if slot_data == null or slot_data.is_empty():
			continue

		has_items = true
		var row := ROW_SCENE.instantiate() as InventoryRowUI

		if row == null:
			continue

		row.row_selected.connect(_on_player_row_selected)
		row.row_activated.connect(_on_player_row_activated)
		player_rows_container.add_child(row)
		row.bind_row(slot_index, slot_data, _player_freshness_display_multiplier)
		row.set_selected(slot_index == _selected_player_slot_index)
		_player_row_controls.append(row)

		if slot_index == _selected_player_slot_index:
			selection_is_valid = true

	if not selection_is_valid:
		_selected_player_slot_index = -1

	player_empty_label.visible = not has_items
	player_scroll_container.visible = has_items
	player_total_weight_label.text = TOTAL_WEIGHT_TEMPLATE % _get_total_weight(_player_slots)
	_sync_player_selection()
	_update_player_action_buttons()


func _refresh_storage_panel() -> void:
	_clear_storage_rows()
	var has_items := false
	var selection_is_valid := false

	for slot_index in range(_storage_slots.size()):
		var slot_data := _storage_slots[slot_index] as InventorySlotData

		if slot_data == null or slot_data.is_empty():
			continue

		has_items = true
		var row := ROW_SCENE.instantiate() as InventoryRowUI

		if row == null:
			continue

		row.row_selected.connect(_on_storage_row_selected)
		row.row_activated.connect(_on_storage_row_activated)
		storage_rows_container.add_child(row)
		row.bind_row(slot_index, slot_data, _storage_freshness_display_multiplier)
		row.set_selected(slot_index == _selected_storage_slot_index)
		_storage_row_controls.append(row)

		if slot_index == _selected_storage_slot_index:
			selection_is_valid = true

	if not selection_is_valid:
		_selected_storage_slot_index = -1

	storage_empty_label.visible = not has_items
	storage_scroll_container.visible = has_items
	storage_total_weight_label.text = TOTAL_WEIGHT_TEMPLATE % _get_total_weight(_storage_slots)
	_sync_storage_selection()
	_update_storage_action_buttons()


func _clear_player_rows() -> void:
	for child in player_rows_container.get_children():
		player_rows_container.remove_child(child)
		child.queue_free()

	_player_row_controls.clear()


func _clear_storage_rows() -> void:
	for child in storage_rows_container.get_children():
		storage_rows_container.remove_child(child)
		child.queue_free()

	_storage_row_controls.clear()


func _sync_player_selection() -> void:
	for row in _player_row_controls:
		if row == null:
			continue

		row.set_selected(row.get_slot_index() == _selected_player_slot_index)


func _sync_storage_selection() -> void:
	for row in _storage_row_controls:
		if row == null:
			continue

		row.set_selected(row.get_slot_index() == _selected_storage_slot_index)


func _update_player_action_buttons() -> void:
	var slot_data := _get_selected_player_slot_data()
	store_button.disabled = slot_data == null or slot_data.is_empty()


func _update_storage_action_buttons() -> void:
	var slot_data := _get_selected_storage_slot_data()
	var has_selection := slot_data != null and not slot_data.is_empty()
	var can_consume := (
		has_selection
		and slot_data.item_data != null
		and slot_data.item_data.is_consumable
		and slot_data.can_consume_safely()
	)

	take_button.disabled = not has_selection
	consume_button.visible = _storage_supports_consume
	consume_button.disabled = not (_storage_supports_consume and can_consume)


func _get_selected_player_slot_data() -> InventorySlotData:
	if _selected_player_slot_index < 0 or _selected_player_slot_index >= _player_slots.size():
		return null

	var slot_data := _player_slots[_selected_player_slot_index] as InventorySlotData

	if slot_data == null or slot_data.is_empty():
		return null

	return slot_data


func _get_selected_storage_slot_data() -> InventorySlotData:
	if _selected_storage_slot_index < 0 or _selected_storage_slot_index >= _storage_slots.size():
		return null

	var slot_data := _storage_slots[_selected_storage_slot_index] as InventorySlotData

	if slot_data == null or slot_data.is_empty():
		return null

	return slot_data


func _get_total_weight(slots: Array) -> float:
	var total_weight := 0.0

	for slot_entry in slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		total_weight += slot.get_total_weight()

	return total_weight


func _get_storage_title_text() -> String:
	if not _storage_title.is_empty():
		return _storage_title

	return DEFAULT_STORAGE_PANEL_TITLE_TEXT


func _grab_initial_focus() -> void:
	if close_button != null:
		close_button.grab_focus()


func _on_player_row_selected(slot_index: int) -> void:
	_selected_player_slot_index = slot_index
	_sync_player_selection()
	_update_player_action_buttons()


func _on_player_row_activated(slot_index: int) -> void:
	_on_player_row_selected(slot_index)

	if not store_button.disabled:
		store_requested.emit(slot_index)


func _on_storage_row_selected(slot_index: int) -> void:
	_selected_storage_slot_index = slot_index
	_sync_storage_selection()
	_update_storage_action_buttons()


func _on_storage_row_activated(slot_index: int) -> void:
	_on_storage_row_selected(slot_index)

	if not take_button.disabled:
		take_requested.emit(slot_index)


func _on_store_button_pressed() -> void:
	if _selected_player_slot_index < 0:
		return

	store_requested.emit(_selected_player_slot_index)


func _on_take_button_pressed() -> void:
	if _selected_storage_slot_index < 0:
		return

	take_requested.emit(_selected_storage_slot_index)


func _on_consume_button_pressed() -> void:
	if _selected_storage_slot_index < 0:
		return

	consume_requested.emit(_selected_storage_slot_index)


func _on_close_button_pressed() -> void:
	close_requested.emit()
