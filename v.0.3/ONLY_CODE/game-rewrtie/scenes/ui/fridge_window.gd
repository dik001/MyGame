class_name FridgeWindow
extends CanvasLayer

signal close_requested
signal take_requested(slot_index: int)
signal eat_requested(slot_index: int)

const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")

@onready var overlay: Control = $Overlay
@onready var scroll_container: ScrollContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/ScrollContainer
@onready var rows_container: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/ScrollContainer/RowsContainer
@onready var empty_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/EmptyLabel
@onready var status_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/StatusLabel
@onready var total_weight_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/TotalWeightLabel
@onready var take_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/TakeButton
@onready var eat_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/EatButton
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/CloseButton

var _slots: Array = []
var _row_controls: Array = []
var _selected_slot_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	status_label.visible = false
	take_button.pressed.connect(_on_take_button_pressed)
	eat_button.pressed.connect(_on_eat_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_refresh_view()
	call_deferred("_grab_initial_focus")


func set_inventory_size(_slot_count: int) -> void:
	pass


func set_slots(slots: Array) -> void:
	_slots = slots.duplicate()

	if is_inside_tree():
		_refresh_view()


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


func _grab_initial_focus() -> void:
	if close_button != null:
		close_button.grab_focus()


func _refresh_view() -> void:
	_clear_rows()
	var has_items := false
	var selection_is_valid := false

	for slot_index in range(_slots.size()):
		var slot_data := _slots[slot_index] as InventorySlotData

		if slot_data == null or slot_data.is_empty():
			continue

		has_items = true
		var row = ROW_SCENE.instantiate()
		row.row_selected.connect(_on_row_selected)
		row.row_activated.connect(_on_row_activated)
		rows_container.add_child(row)
		row.bind_row(slot_index, slot_data)
		row.set_selected(slot_index == _selected_slot_index)
		_row_controls.append(row)

		if slot_index == _selected_slot_index:
			selection_is_valid = true

	if not selection_is_valid:
		_selected_slot_index = -1

	empty_label.visible = not has_items
	scroll_container.visible = has_items
	total_weight_label.text = "Общий вес: %.1f" % _get_total_weight()
	_sync_row_selection()
	_update_action_buttons()


func _clear_rows() -> void:
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()

	_row_controls.clear()


func _sync_row_selection() -> void:
	for row in _row_controls:
		if row == null:
			continue

		row.set_selected(row.get_slot_index() == _selected_slot_index)


func _update_action_buttons() -> void:
	var slot_data := _get_selected_slot_data()
	var has_selection := slot_data != null and not slot_data.is_empty()
	var can_eat := has_selection and slot_data.item_data != null and slot_data.item_data.is_consumable

	take_button.disabled = not has_selection
	eat_button.disabled = not can_eat


func _get_selected_slot_data() -> InventorySlotData:
	if _selected_slot_index < 0 or _selected_slot_index >= _slots.size():
		return null

	var slot_data := _slots[_selected_slot_index] as InventorySlotData

	if slot_data == null or slot_data.is_empty():
		return null

	return slot_data


func _get_total_weight() -> float:
	var total_weight := 0.0

	for slot_entry in _slots:
		var slot := slot_entry as InventorySlotData

		if slot == null or slot.is_empty():
			continue

		total_weight += slot.get_total_weight()

	return total_weight


func _on_row_selected(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_sync_row_selection()
	_update_action_buttons()


func _on_row_activated(slot_index: int) -> void:
	_on_row_selected(slot_index)

	if not take_button.disabled:
		take_requested.emit(slot_index)


func _on_take_button_pressed() -> void:
	if _selected_slot_index < 0:
		return

	take_requested.emit(_selected_slot_index)


func _on_eat_button_pressed() -> void:
	if _selected_slot_index < 0:
		return

	eat_requested.emit(_selected_slot_index)


func _on_close_button_pressed() -> void:
	close_requested.emit()
