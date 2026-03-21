extends CanvasLayer

const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")
const STATUS_CONDITION_ROW_SCENE := preload("res://scenes/ui/StatusConditionRow.tscn")

const TAB_INVENTORY: StringName = &"inventory"
const TAB_STATUS: StringName = &"status"

@export var player_path: NodePath
@export var hud_path: NodePath

@onready var overlay: Control = $Overlay
@onready var tab_button_inventory: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftMenuPanel/MarginContainer/LeftMenu/TabButton_Inventory
@onready var tab_button_status: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftMenuPanel/MarginContainer/LeftMenu/TabButton_Status
@onready var inventory_page: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage
@onready var status_page: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage
@onready var scroll_container: ScrollContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/ScrollContainer
@onready var rows_container: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/ScrollContainer/RowsContainer
@onready var empty_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/EmptyLabel
@onready var general_condition_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/GeneralConditionLabel
@onready var condition_scroll_container: ScrollContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/ConditionScroll
@onready var condition_list_container: VBoxContainer = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/ConditionScroll/ConditionList
@onready var empty_conditions_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/EmptyConditionsLabel
@onready var selected_condition_title_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionTitleLabel
@onready var selected_condition_status_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionStatusLabel
@onready var selected_condition_description_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionDescriptionLabel
@onready var total_weight_label: Label = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/FooterRow/TotalWeightLabel
@onready var footer_spacer: Control = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/FooterRow/FooterSpacer
@onready var use_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/FooterRow/UseButton
@onready var drop_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/FooterRow/DropButton
@onready var close_button: Button = $Overlay/CenterContainer/WindowPanel/MarginContainer/WindowLayout/FooterRow/CloseButton

var _player: Node
var _hud: Node
var _freelance_state: Node = null
var _row_controls: Array = []
var _condition_row_controls: Array = []
var _condition_display_by_id: Dictionary = {}
var _selected_slot_index := -1
var _selected_condition_id := ""
var _active_tab: StringName = TAB_INVENTORY


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 6
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tab_button_inventory.pressed.connect(_on_inventory_tab_pressed)
	tab_button_status.pressed.connect(_on_status_tab_pressed)
	use_button.pressed.connect(_on_use_button_pressed)
	drop_button.pressed.connect(_on_drop_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_resolve_scene_references()
	_resolve_freelance_state()
	_connect_freelance_state_signals()

	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_inventory_changed):
		player_inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh_view()
	_switch_tab(TAB_INVENTORY)


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


func open_inventory() -> void:
	if visible:
		return

	_resolve_scene_references()
	_resolve_freelance_state()
	_connect_freelance_state_signals()
	_selected_slot_index = -1
	_selected_condition_id = ""
	visible = true
	var player_inventory := _get_player_inventory()

	if player_inventory != null:
		player_inventory.set_inventory_open(true)

	_apply_modal_state(true)
	_refresh_view()
	_switch_tab(TAB_INVENTORY)
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

	_refresh_inventory_page()


func _on_conditions_changed() -> void:
	if not is_inside_tree():
		return

	_refresh_status_page()


func _on_row_selected(slot_index: int) -> void:
	_selected_slot_index = slot_index
	_sync_row_selection()
	_update_action_buttons()


func _on_row_activated(slot_index: int) -> void:
	_on_row_selected(slot_index)

	if not use_button.disabled:
		_on_use_button_pressed()


func _on_condition_selected(condition_id: String) -> void:
	_selected_condition_id = condition_id
	_sync_condition_selection()
	_show_selected_condition_details()


func _on_inventory_tab_pressed() -> void:
	_switch_tab(TAB_INVENTORY)


func _on_status_tab_pressed() -> void:
	_switch_tab(TAB_STATUS)


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
	_refresh_inventory_page()
	_refresh_status_page()
	_update_tab_state()
	_update_action_buttons()


func _switch_tab(tab_name: StringName) -> void:
	_active_tab = TAB_STATUS if tab_name == TAB_STATUS else TAB_INVENTORY
	_update_tab_state()
	_update_action_buttons()

	if _active_tab == TAB_STATUS and (use_button.has_focus() or drop_button.has_focus()):
		close_button.grab_focus()


func _refresh_inventory_page() -> void:
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
		var row := ROW_SCENE.instantiate()

		if row == null:
			continue

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


func _refresh_status_page() -> void:
	_clear_condition_rows()
	_resolve_freelance_state()
	var active_conditions: Array[Dictionary] = _get_active_conditions_data()

	if _freelance_state == null:
		general_condition_label.text = "Данные о состоянии недоступны"
		empty_conditions_label.visible = true
		empty_conditions_label.text = "Данные о состоянии недоступны"
		condition_scroll_container.visible = false
		_selected_condition_id = ""
		_show_condition_details({
			"title": "Данные о состоянии недоступны",
			"status_text": "",
			"description": "FreelanceState не найден. Информация о состоянии сейчас недоступна.",
		})
		return

	general_condition_label.text = _format_general_condition(active_conditions.size())

	if active_conditions.is_empty():
		empty_conditions_label.visible = true
		empty_conditions_label.text = "Активных состояний нет"
		condition_scroll_container.visible = false
		_selected_condition_id = ""
		_show_condition_details({
			"title": "Серьёзных проблем не обнаружено",
			"status_text": "",
			"description": "Сейчас активных состояний нет. Можно продолжать день в обычном режиме.",
		})
		return

	var selection_is_valid := false

	for condition_entry in active_conditions:
		var display_data: Dictionary = _build_condition_display_data(condition_entry)

		if display_data.is_empty():
			continue

		var condition_id: String = String(display_data.get("id", "")).strip_edges()

		if condition_id.is_empty():
			continue

		_condition_display_by_id[condition_id] = display_data.duplicate(true)
		var row = STATUS_CONDITION_ROW_SCENE.instantiate()

		if row == null:
			continue

		row.condition_selected.connect(_on_condition_selected)
		condition_list_container.add_child(row)
		row.bind_condition(display_data)
		row.set_selected(condition_id == _selected_condition_id)
		_condition_row_controls.append(row)

		if condition_id == _selected_condition_id:
			selection_is_valid = true

	empty_conditions_label.visible = _condition_row_controls.is_empty()
	empty_conditions_label.text = "Активных состояний нет"
	condition_scroll_container.visible = not _condition_row_controls.is_empty()

	if _condition_row_controls.is_empty():
		_selected_condition_id = ""
		_show_condition_details({
			"title": "Серьёзных проблем не обнаружено",
			"status_text": "",
			"description": "Сейчас активных состояний нет. Можно продолжать день в обычном режиме.",
		})
		return

	if not selection_is_valid:
		_selected_condition_id = String(_condition_row_controls[0].get_condition_id())

	_sync_condition_selection()
	_show_selected_condition_details()


func _get_active_conditions_data() -> Array[Dictionary]:
	var active_conditions: Array[Dictionary] = []

	if _freelance_state == null:
		return active_conditions

	if _freelance_state.has_method("get_active_conditions"):
		var raw_conditions: Variant = _freelance_state.call("get_active_conditions")

		if raw_conditions is Array:
			for condition_variant in raw_conditions:
				var normalized_entry: Dictionary = _normalize_condition_entry(condition_variant)

				if normalized_entry.is_empty():
					continue

				active_conditions.append(normalized_entry)

	if active_conditions.is_empty() and _freelance_state.has_method("has_condition"):
		if bool(_freelance_state.call("has_condition", &"eye_strain")):
			active_conditions.append({
				"id": "eye_strain",
				"payload": {},
			})

	return active_conditions


func _normalize_condition_entry(raw_entry: Variant) -> Dictionary:
	if not (raw_entry is Dictionary):
		return {}

	var entry: Dictionary = raw_entry
	var condition_id_text: String = String(entry.get("id", entry.get("condition_id", ""))).strip_edges()

	if condition_id_text.is_empty():
		return {}

	var payload: Dictionary = {}
	var raw_payload: Variant = entry.get("payload", {})

	if raw_payload is Dictionary:
		payload = (raw_payload as Dictionary).duplicate(true)
	else:
		payload = entry.duplicate(true)
		payload.erase("id")
		payload.erase("condition_id")

	return {
		"id": condition_id_text,
		"payload": payload,
	}


func _build_condition_display_data(condition_entry: Dictionary) -> Dictionary:
	var condition_id_text: String = String(condition_entry.get("id", "")).strip_edges()

	if condition_id_text.is_empty():
		return {}

	var payload: Dictionary = {}
	var raw_payload: Variant = condition_entry.get("payload", {})

	if raw_payload is Dictionary:
		payload = raw_payload

	var default_title := condition_id_text.replace("_", " ").capitalize()
	var title := ""
	var status_text := ""
	var description := ""

	match condition_id_text:
		"eye_strain":
			title = _first_non_empty_text([
				payload.get("title", ""),
				"Усталость глаз",
			])
			status_text = _first_non_empty_text([
				payload.get("status_text", ""),
				payload.get("status", ""),
				"Лёгкое перенапряжение",
			])
			description = _first_non_empty_text([
				payload.get("description", ""),
				"После длительной работы за экраном зрение иногда кратко темнеет. Снимается отдыхом или сном.",
			])
		_:
			title = _first_non_empty_text([
				payload.get("title", ""),
				default_title,
				"Неизвестное состояние",
			])
			status_text = _first_non_empty_text([
				payload.get("status_text", ""),
				payload.get("status", ""),
				"Активно",
			])
			description = _first_non_empty_text([
				payload.get("description", ""),
				"Состояние активно. Следите за самочувствием и при возможности отдохните.",
			])

	return {
		"id": condition_id_text,
		"title": title,
		"status_text": status_text,
		"description": description,
	}


func _show_selected_condition_details() -> void:
	if _selected_condition_id.is_empty():
		_show_condition_details({
			"title": "Серьёзных проблем не обнаружено",
			"status_text": "",
			"description": "Сейчас активных состояний нет. Можно продолжать день в обычном режиме.",
		})
		return

	var display_data: Dictionary = _condition_display_by_id.get(_selected_condition_id, {})

	if display_data.is_empty():
		_show_condition_details({
			"title": "Состояние не найдено",
			"status_text": "",
			"description": "Не удалось загрузить подробности выбранного состояния.",
		})
		return

	_show_condition_details(display_data)


func _show_condition_details(data: Dictionary) -> void:
	var title: String = _first_non_empty_text([
		data.get("title", ""),
		"Состояние",
	])
	var status_text: String = String(data.get("status_text", "")).strip_edges()
	var description: String = _first_non_empty_text([
		data.get("description", ""),
		"Описание состояния отсутствует.",
	])

	selected_condition_title_label.text = title
	selected_condition_status_label.text = status_text
	selected_condition_status_label.visible = not status_text.is_empty()
	selected_condition_description_label.text = description


func _first_non_empty_text(candidates: Array) -> String:
	for candidate in candidates:
		var text_value: String = String(candidate).strip_edges()

		if not text_value.is_empty():
			return text_value

	return ""


func _format_general_condition(active_conditions_count: int) -> String:
	if _freelance_state == null:
		return "Данные о состоянии недоступны"

	if active_conditions_count <= 0:
		return "Общее состояние: стабильное"

	if active_conditions_count == 1:
		return "Общее состояние: есть лёгкие проблемы"

	return "Общее состояние: требуется отдых"


func _clear_rows() -> void:
	for child in rows_container.get_children():
		rows_container.remove_child(child)
		child.queue_free()

	_row_controls.clear()


func _clear_condition_rows() -> void:
	for child in condition_list_container.get_children():
		condition_list_container.remove_child(child)
		child.queue_free()

	_condition_row_controls.clear()
	_condition_display_by_id.clear()


func _sync_row_selection() -> void:
	for row in _row_controls:
		if row == null:
			continue

		row.set_selected(row.get_slot_index() == _selected_slot_index)


func _sync_condition_selection() -> void:
	for row in _condition_row_controls:
		if row == null:
			continue

		row.set_selected(row.get_condition_id() == _selected_condition_id)


func _update_tab_state() -> void:
	var show_inventory_page := _active_tab == TAB_INVENTORY
	inventory_page.visible = show_inventory_page
	status_page.visible = not show_inventory_page
	tab_button_inventory.set_pressed_no_signal(show_inventory_page)
	tab_button_status.set_pressed_no_signal(not show_inventory_page)


func _update_action_buttons() -> void:
	var inventory_tab_active := _active_tab == TAB_INVENTORY
	total_weight_label.visible = inventory_tab_active
	footer_spacer.visible = not inventory_tab_active
	use_button.visible = inventory_tab_active
	drop_button.visible = inventory_tab_active

	if not inventory_tab_active:
		use_button.disabled = true
		drop_button.disabled = true
		return

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


func _resolve_freelance_state() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")


func _connect_freelance_state_signals() -> void:
	if _freelance_state == null:
		return

	if not _freelance_state.has_signal(&"conditions_changed"):
		return

	var refresh_callable: Callable = Callable(self, "_on_conditions_changed")

	if _freelance_state.is_connected(&"conditions_changed", refresh_callable):
		return

	_freelance_state.connect(&"conditions_changed", refresh_callable)


func _resolve_node(node_path: NodePath, group_name: String) -> Node:
	if not node_path.is_empty():
		var node := get_node_or_null(node_path)

		if node != null:
			return node

	return get_tree().get_first_node_in_group(group_name)


func _get_player_inventory() -> PlayerInventoryState:
	return get_node_or_null("/root/PlayerInventory") as PlayerInventoryState
