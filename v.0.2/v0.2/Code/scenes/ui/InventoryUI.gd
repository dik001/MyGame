extends CanvasLayer

const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")

@export var player_path: NodePath
@export var hud_path: NodePath

@onready var overlay: Control = $Overlay
@onready var scroll_container: ScrollContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/ScrollContainer
@onready var rows_container: VBoxContainer = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/ScrollContainer/RowsContainer
@onready var empty_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/EmptyLabel
@onready var total_weight_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/TotalWeightLabel
@onready var use_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/UseButton
@onready var drop_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/DropButton
@onready var close_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/Content/FooterRow/CloseButton

var _player: Node
var _hud: Node
var _row_controls: Array = []
var _selected_slot_index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	use_button.pressed.connect(_on_use_button_pressed)
	drop_button.pressed.connect(_on_drop_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_resolve_scene_references()

	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_inventory_changed):
		player_inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh_view()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle") and not event.is_echo():
		if visible:
			close_inventory()
		elif _can_open_inventory():
			open_inventory()

		get_viewport().set_input_as_handled()
		return

	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_inventory()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_inventory()
		get_viewport().set_input_as_handled()


func open_inventory() -> void:
	if visible:
		return

	_resolve_scene_references()
	_selected_slot_index = -1
	visible = true
	var player_inventory := _get_player_inventory()

	if player_inventory != null:
		player_inventory.set_inventory_open(true)

	_apply_modal_state(true)
	_refresh_view()
	call_deferred("_grab_initial_focus")


func close_inventory() -> void:
	if not visible:
		return

	visible = false
	_selected_slot_index = -1
	var player_inventory := _get_player_inventory()

	if player_inventory != null:
		player_inventory.set_inventory_open(false)

	_apply_modal_state(false)
	_update_action_buttons()


func _on_inventory_changed() -> void:
	if not is_inside_tree():
		return

	_refresh_view()


func _on_row_selected(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_sync_row_selection()
	_update_action_buttons()


func _on_row_activated(slot_index: int) -> void:
	_on_row_selected(slot_index)

	if not use_button.disabled:
		_on_use_button_pressed()


func _on_use_button_pressed() -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory == null or _selected_slot_index < 0:
		return

	player_inventory.use_item_at(_selected_slot_index)


func _on_drop_button_pressed() -> void:
	var player_inventory := _get_player_inventory()

	if player_inventory == null or _selected_slot_index < 0:
		return

	player_inventory.drop_item_at(_selected_slot_index, 1)


func _on_close_button_pressed() -> void:
	close_inventory()


func _refresh_view() -> void:
	_clear_rows()
	var player_inventory := _get_player_inventory()
	var slots: Array = player_inventory.get_slots() if player_inventory != null else []
	var has_items := false
	var selection_is_valid := false

	for slot_index in range(slots.size()):
		var slot_data := slots[slot_index] as InventorySlotData

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
	total_weight_label.text = "Общий вес: %.1f" % (player_inventory.get_total_weight() if player_inventory != null else 0.0)
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
	var can_use := has_selection and slot_data.item_data != null and slot_data.item_data.is_consumable

	use_button.disabled = not can_use
	drop_button.disabled = not has_selection


func _get_selected_slot_data() -> InventorySlotData:
	if _selected_slot_index < 0:
		return null

	var player_inventory := _get_player_inventory()

	if player_inventory == null:
		return null

	var slot_data := player_inventory.get_slot_at(_selected_slot_index)

	if slot_data == null or slot_data.is_empty():
		return null

	return slot_data


func _can_open_inventory() -> bool:
	_resolve_scene_references()

	if _player != null and _player.has_method("is_input_locked") and _player.is_input_locked():
		return false

	return true


func _apply_modal_state(is_active: bool) -> void:
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(is_active)

	if _hud != null and _hud.has_method("set_clock_paused"):
		_hud.set_clock_paused(is_active)


func _grab_initial_focus() -> void:
	if close_button != null:
		close_button.grab_focus()


func _resolve_scene_references() -> void:
	if _player == null:
		_player = _resolve_node(player_path, "player")

	if _hud == null:
		_hud = _resolve_node(hud_path, "hud")


func _resolve_node(node_path: NodePath, group_name: String) -> Node:
	if not node_path.is_empty():
		var node := get_node_or_null(node_path)

		if node != null:
			return node

	return get_tree().get_first_node_in_group(group_name)


func _get_player_inventory() -> PlayerInventoryState:
	return get_node_or_null("/root/PlayerInventory") as PlayerInventoryState
