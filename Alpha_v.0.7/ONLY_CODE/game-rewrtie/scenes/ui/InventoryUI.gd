extends CanvasLayer

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")
const SaveSlotsPanel = preload("res://scenes/ui/SaveSlotsPanel.gd")
const SettingsPanel = preload("res://scenes/ui/SettingsPanel.gd")
const StyledConfirmationDialog = preload("res://scenes/ui/StyledConfirmationDialog.gd")

const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")
const STATUS_CONDITION_ROW_SCENE := preload("res://scenes/ui/StatusConditionRow.tscn")

const TAB_INVENTORY: StringName = &"inventory"
const TAB_STATUS: StringName = &"status"
const TAB_QUESTS: StringName = &"quests"
const TAB_MENU: StringName = &"menu"

@export var player_path: NodePath
@export var hud_path: NodePath

@onready var overlay: Control = $Overlay
@onready var tab_button_inventory: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/LeftMenuPanel/MarginContainer/LeftMenu/TabButton_Inventory
@onready var tab_button_status: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/LeftMenuPanel/MarginContainer/LeftMenu/TabButton_Status
@onready var tab_button_quests: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/LeftMenuPanel/MarginContainer/LeftMenu/TabButton_Quests
@onready var hint_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/LeftMenuPanel/MarginContainer/LeftMenu/HintLabel
@onready var inventory_page: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage
@onready var status_page: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage
@onready var quests_page: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage
@onready var quests_header_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage/HeaderLabel
@onready var scroll_container: ScrollContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/ScrollContainer
@onready var rows_container: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/ScrollContainer/RowsContainer
@onready var empty_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/EmptyLabel
@onready var freshness_header_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/InventoryPage/HeaderPanel/HeaderRow/FreshnessHeader
@onready var general_condition_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/GeneralConditionLabel
@onready var condition_scroll_container: ScrollContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/ConditionScroll
@onready var condition_list_container: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/ConditionScroll/ConditionList
@onready var empty_conditions_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionListPanel/MarginContainer/ConditionListContent/EmptyConditionsLabel
@onready var selected_condition_title_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionTitleLabel
@onready var selected_condition_status_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionStatusLabel
@onready var selected_condition_description_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/StatusPage/MainRow/ConditionDetailsPanel/MarginContainer/ConditionDetailsContent/SelectedConditionDescriptionLabel
@onready var current_quest_section_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage/QuestCurrentPanel/MarginContainer/CurrentQuestContent/CurrentQuestLabel
@onready var current_quest_title_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage/QuestCurrentPanel/MarginContainer/CurrentQuestContent/CurrentQuestTitleLabel
@onready var quest_details_section_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage/QuestDetailsPanel/MarginContainer/QuestDetailsContent/QuestDetailsLabel
@onready var quest_description_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/ContentPanel/MarginContainer/PagesContainer/QuestsPage/QuestDetailsPanel/MarginContainer/QuestDetailsContent/QuestDetailsScroll/QuestDetailsBody/QuestDescriptionLabel
@onready var total_weight_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/FooterRow/TotalWeightLabel
@onready var footer_spacer: Control = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/FooterRow/FooterSpacer
@onready var use_button: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/FooterRow/UseButton
@onready var drop_button: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/FooterRow/DropButton
@onready var close_button: Button = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/FooterRow/CloseButton
@onready var stats_status_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/StatsStatusLabel
@onready var health_value_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/HealthStatRow/HeaderRow/HealthValueLabel
@onready var health_bar: ProgressBar = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/HealthStatRow/HealthBar
@onready var hunger_value_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/HungerStatRow/HeaderRow/HungerValueLabel
@onready var hunger_bar: ProgressBar = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/HungerStatRow/HungerBar
@onready var energy_value_label: Label = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/EnergyStatRow/HeaderRow/EnergyValueLabel
@onready var energy_bar: ProgressBar = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent/EnergyStatRow/EnergyBar

var _player: Node
var _hud: Node
var _freelance_state: Node = null
var _story_state: Node = null
var _stats: PlayerStatsState = null
var _row_controls: Array = []
var _condition_row_controls: Array = []
var _condition_display_by_id: Dictionary = {}
var _selected_slot_index := -1
var _selected_condition_id := ""
var _active_tab: StringName = TAB_INVENTORY
var _tab_button_menu: Button
var _menu_page: VBoxContainer
var _menu_summary_label: Label
var _menu_nested_title_label: Label
var _menu_subpanel_host: Control
var _menu_save_panel: SaveSlotsPanel
var _menu_load_panel: SaveSlotsPanel
var _menu_settings_panel: SettingsPanel
var _main_menu_confirm_dialog: StyledConfirmationDialog
var _menu_nested_view: StringName = &"home"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 6
	_apply_fullscreen_layout()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_inventory_static_texts()
	_apply_quest_static_texts()
	_build_menu_tab()
	tab_button_inventory.pressed.connect(_on_inventory_tab_pressed)
	tab_button_status.pressed.connect(_on_status_tab_pressed)
	tab_button_quests.pressed.connect(_on_quests_tab_pressed)
	use_button.pressed.connect(_on_use_button_pressed)
	drop_button.pressed.connect(_on_drop_button_pressed)
	close_button.pressed.connect(_on_close_button_pressed)
	_refresh_inventory_shortcut_key()
	_resolve_scene_references()
	_resolve_player_stats()
	_connect_player_stats_signals()
	_resolve_freelance_state()
	_connect_freelance_state_signals()
	_resolve_story_state()
	_connect_story_state_signals()
	_connect_settings_signals()

	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_inventory_changed):
		player_inventory.inventory_changed.connect(_on_inventory_changed)

	_refresh_view()
	_switch_tab(TAB_INVENTORY)


func _apply_inventory_static_texts() -> void:
	if freshness_header_label != null:
		freshness_header_label.text = "\u0421\u0432\u0435\u0436\u0435\u0441\u0442\u044c"


func _refresh_inventory_shortcut_key() -> void:
	var key_text := _resolve_action_key_text(&"inventory_toggle", "I")
	var menu_key_text := _resolve_action_key_text(&"pause_menu", "ESC")

	if hint_label != null:
		hint_label.text = "%s - инвентарь | %s - меню" % [key_text, menu_key_text]


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory_toggle") and not event.is_echo():
		_handle_tab_hotkey(TAB_INVENTORY)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("pause_menu") and not event.is_echo():
		_handle_tab_hotkey(TAB_MENU)
		get_viewport().set_input_as_handled()
		return

	if not visible:
		return


func open_inventory_tab() -> void:
	_refresh_inventory_shortcut_key()

	if visible:
		_switch_tab(TAB_INVENTORY)
		return

	if _can_open_inventory():
		open_inventory()


func open_menu_tab() -> void:
	_refresh_inventory_shortcut_key()

	if visible:
		_switch_tab(TAB_MENU)
		return

	if _can_open_inventory():
		_open_with_tab(TAB_MENU)


func open_inventory() -> void:
	_open_with_tab(TAB_INVENTORY)


func force_close() -> void:
	if not visible:
		return

	_close_menu_nested_view()
	close_inventory()


func _open_with_tab(target_tab: StringName) -> void:
	if visible:
		_switch_tab(target_tab)
		return

	_refresh_inventory_shortcut_key()
	_apply_fullscreen_layout()
	_resolve_scene_references()
	_resolve_player_stats()
	_connect_player_stats_signals()
	_resolve_freelance_state()
	_connect_freelance_state_signals()
	_resolve_story_state()
	_connect_story_state_signals()
	_selected_slot_index = -1
	_selected_condition_id = ""
	visible = true
	var player_inventory := _get_player_inventory()

	if player_inventory != null:
		player_inventory.set_inventory_open(true)

	_apply_modal_state(true)
	_refresh_view()
	_switch_tab(target_tab)
	call_deferred("_grab_initial_focus")


func close_inventory() -> void:
	if not visible:
		return

	visible = false
	_selected_slot_index = -1
	_close_menu_nested_view()

	if _main_menu_confirm_dialog != null:
		_main_menu_confirm_dialog.hide_dialog()

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


func _on_stats_changed(_current_stats: Dictionary) -> void:
	if not is_inside_tree():
		return

	_refresh_stats_panel()


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


func _on_quests_tab_pressed() -> void:
	_switch_tab(TAB_QUESTS)


func _on_menu_tab_pressed() -> void:
	_switch_tab(TAB_MENU)


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


func _on_primary_objective_changed(_objective: Dictionary) -> void:
	if not is_inside_tree():
		return

	_refresh_quests_page()


func _refresh_view() -> void:
	_refresh_inventory_layout()
	_refresh_inventory_page()
	_refresh_status_page()
	_refresh_quests_page()
	_refresh_menu_page()
	_refresh_stats_panel()
	_update_tab_state()
	_update_action_buttons()


func _switch_tab(tab_name: StringName) -> void:
	match tab_name:
		TAB_STATUS:
			_active_tab = TAB_STATUS
		TAB_QUESTS:
			_active_tab = TAB_QUESTS
		TAB_MENU:
			_active_tab = TAB_MENU
		_:
			_active_tab = TAB_INVENTORY

	_update_tab_state()
	_update_action_buttons()

	if _active_tab != TAB_INVENTORY and (use_button.has_focus() or drop_button.has_focus()):
		close_button.grab_focus()


func _refresh_inventory_layout() -> void:
	_apply_fullscreen_layout()


func _apply_quest_static_texts() -> void:
	tab_button_quests.text = "Задания"
	quests_header_label.text = "Задания"
	current_quest_section_label.text = "Текущее задание"
	quest_details_section_label.text = "Подробности"


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


func _refresh_quests_page() -> void:
	var quest_data := _get_current_quest_data()
	var title := String(quest_data.get("title", "")).strip_edges()
	var description := _build_quest_description_text(quest_data)

	if title.is_empty():
		current_quest_title_label.text = "Активных заданий нет"
		quest_description_label.text = "Сейчас у героини нет активного задания. Осматривайся, разговаривай с людьми и следи за новыми событиями."
		return

	current_quest_title_label.text = title

	if description.is_empty():
		quest_description_label.text = "Подробности для этого задания пока не добавлены."
		return

	quest_description_label.text = description


func _build_quest_description_text(quest_data: Dictionary) -> String:
	var description := String(quest_data.get("description", "")).strip_edges()

	if not description.is_empty():
		return description

	var details_variant: Variant = quest_data.get("details", [])

	if details_variant is Array:
		var detail_lines: Array[String] = []

		for detail in details_variant:
			var detail_text := String(detail).strip_edges()

			if detail_text.is_empty():
				continue

			detail_lines.append("- %s" % detail_text)

		if not detail_lines.is_empty():
			return "\n".join(detail_lines)

	return ""


func _refresh_stats_panel() -> void:
	var stats_snapshot := _get_stats_snapshot()
	var stats_available := not stats_snapshot.is_empty()

	stats_status_label.visible = not stats_available

	if not stats_available:
		stats_status_label.text = "Данные о показателях недоступны"
		_set_stat_row_unavailable(health_value_label, health_bar)
		_set_stat_row_unavailable(hunger_value_label, hunger_bar)
		_set_stat_row_unavailable(energy_value_label, energy_bar)
		return

	stats_status_label.text = ""
	_update_stat_bars(stats_snapshot)


func _update_stat_bars(stats_snapshot: Dictionary) -> void:
	_build_stat_row(
		health_value_label,
		health_bar,
		stats_snapshot.get("hp", 0),
		stats_snapshot.get("max_hp", 0)
	)
	_build_stat_row(
		hunger_value_label,
		hunger_bar,
		stats_snapshot.get("hunger", 0),
		stats_snapshot.get("max_hunger", 0)
	)
	_build_stat_row(
		energy_value_label,
		energy_bar,
		stats_snapshot.get("energy", 0.0),
		stats_snapshot.get("max_energy", 0.0)
	)


func _build_stat_row(value_label: Label, progress_bar: ProgressBar, current_value: Variant, max_value: Variant) -> void:
	var resolved_current := _coerce_numeric(current_value)
	var resolved_max := _resolve_max_value(current_value, max_value)

	progress_bar.max_value = resolved_max
	progress_bar.value = clampf(resolved_current, 0.0, resolved_max)
	value_label.text = _format_stat_pair(current_value, max_value)


func _set_stat_row_unavailable(value_label: Label, progress_bar: ProgressBar) -> void:
	progress_bar.max_value = 1.0
	progress_bar.value = 0.0
	value_label.text = "-"


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


func _format_stat_pair(current_value: Variant, max_value: Variant) -> String:
	var current_text := _format_stat_value(current_value)
	var resolved_max := _coerce_numeric(max_value)

	if resolved_max <= 0.0:
		return current_text

	return "%s / %s" % [current_text, _format_stat_value(max_value)]


func _format_stat_value(value: Variant) -> String:
	if value is float:
		var float_value := float(value)

		if is_equal_approx(float_value, roundf(float_value)):
			return str(int(roundi(float_value)))

		return "%.1f" % float_value

	if value is int:
		return str(value)

	var text_value := String(value).strip_edges()
	return text_value if not text_value.is_empty() else "0"


func _coerce_numeric(value: Variant) -> float:
	if value is int or value is float:
		return float(value)

	var text_value := String(value).strip_edges()

	if text_value.is_empty():
		return 0.0

	return text_value.to_float()


func _resolve_max_value(current_value: Variant, max_value: Variant) -> float:
	var resolved_max := _coerce_numeric(max_value)

	if resolved_max > 0.0:
		return resolved_max

	return max(1.0, _coerce_numeric(current_value))


func _resolve_action_key_text(action_name: StringName, fallback: String) -> String:
	if GameSettings != null and GameSettings.has_method("get_action_display_text"):
		return GameSettings.get_action_display_text(action_name, fallback)

	for event in InputMap.action_get_events(action_name):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var keycode := key_event.physical_keycode

		if keycode == 0:
			keycode = key_event.keycode

		var key_text := OS.get_keycode_string(keycode)

		if not key_text.is_empty():
			return key_text.to_upper()

	return fallback


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
	var show_status_page := _active_tab == TAB_STATUS
	var show_quests_page := _active_tab == TAB_QUESTS
	var show_menu_page := _active_tab == TAB_MENU

	inventory_page.visible = show_inventory_page
	status_page.visible = show_status_page
	quests_page.visible = show_quests_page
	if _menu_page != null:
		_menu_page.visible = show_menu_page
	tab_button_inventory.set_pressed_no_signal(show_inventory_page)
	tab_button_status.set_pressed_no_signal(show_status_page)
	tab_button_quests.set_pressed_no_signal(show_quests_page)
	if _tab_button_menu != null:
		_tab_button_menu.set_pressed_no_signal(show_menu_page)


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
	var can_use := (
		has_selection
		and slot_data.item_data != null
		and slot_data.item_data.is_consumable
		and slot_data.can_consume_safely()
	)

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


func _get_stats_snapshot() -> Dictionary:
	_resolve_player_stats()
	return _stats.get_stats() if _stats != null else {}


func _get_current_quest_data() -> Dictionary:
	_resolve_story_state()

	if _story_state == null or not _story_state.has_method("get_current_quest"):
		return {}

	var quest_variant: Variant = _story_state.call("get_current_quest")
	return quest_variant.duplicate(true) if quest_variant is Dictionary else {}


func show_quests_tab() -> void:
	if not visible:
		open_inventory()

	_switch_tab(TAB_QUESTS)
	call_deferred("_grab_initial_focus")


func set_current_quest(title: String, details: String) -> void:
	_resolve_story_state()

	if _story_state == null:
		return

	if _story_state.has_method("set_current_quest"):
		_story_state.call("set_current_quest", title, details)
	elif _story_state.has_method("set_primary_objective"):
		_story_state.call("set_primary_objective", title, details, [], {})


func clear_current_quest() -> void:
	_resolve_story_state()

	if _story_state == null:
		return

	if _story_state.has_method("clear_current_quest"):
		_story_state.call("clear_current_quest")
	elif _story_state.has_method("clear_primary_objective"):
		_story_state.call("clear_primary_objective")


func _build_menu_tab() -> void:
	if _tab_button_menu != null:
		return

	var left_menu := tab_button_inventory.get_parent() as VBoxContainer
	var pages_container := inventory_page.get_parent() as Control

	if left_menu == null or pages_container == null:
		return

	_tab_button_menu = Button.new()
	_tab_button_menu.name = "TabButton_Menu"
	_tab_button_menu.custom_minimum_size = tab_button_inventory.custom_minimum_size
	_tab_button_menu.toggle_mode = tab_button_inventory.toggle_mode
	_tab_button_menu.focus_mode = tab_button_inventory.focus_mode
	_tab_button_menu.text = "Меню"
	_tab_button_menu.add_theme_font_size_override("font_size", tab_button_inventory.get_theme_font_size("font_size"))

	for stylebox_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var stylebox := tab_button_inventory.get_theme_stylebox(stylebox_name)

		if stylebox != null:
			_tab_button_menu.add_theme_stylebox_override(stylebox_name, stylebox)

	_tab_button_menu.pressed.connect(_on_menu_tab_pressed)
	left_menu.add_child(_tab_button_menu)
	left_menu.move_child(_tab_button_menu, left_menu.get_children().find(tab_button_quests) + 1)

	_menu_page = VBoxContainer.new()
	_menu_page.name = "MenuPage"
	_menu_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_menu_page.add_theme_constant_override("separation", 22)
	_menu_page.visible = false
	pages_container.add_child(_menu_page)

	var header_label := Label.new()
	header_label.text = "Меню"
	header_label.add_theme_font_size_override("font_size", 34)
	_menu_page.add_child(header_label)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 36)
	_menu_page.add_child(main_row)

	var actions_panel := PanelContainer.new()
	actions_panel.custom_minimum_size = Vector2(380.0, 0.0)
	actions_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(actions_panel)

	var actions_margin := MarginContainer.new()
	actions_margin.add_theme_constant_override("margin_left", 34)
	actions_margin.add_theme_constant_override("margin_top", 34)
	actions_margin.add_theme_constant_override("margin_right", 34)
	actions_margin.add_theme_constant_override("margin_bottom", 34)
	actions_panel.add_child(actions_margin)

	var actions_list := VBoxContainer.new()
	actions_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions_list.add_theme_constant_override("separation", 18)
	actions_margin.add_child(actions_list)

	actions_list.add_child(_build_menu_action_button("Продолжить", _on_resume_button_pressed))
	actions_list.add_child(_build_menu_action_button("Сохранить", _on_menu_save_button_pressed))
	actions_list.add_child(_build_menu_action_button("Загрузить", _on_menu_load_button_pressed))
	actions_list.add_child(_build_menu_action_button("Настройки", _on_menu_settings_button_pressed))
	actions_list.add_child(_build_menu_action_button("Главное меню", _on_menu_main_menu_button_pressed))

	var content_panel := PanelContainer.new()
	content_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(content_panel)

	var content_margin := MarginContainer.new()
	content_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_margin.add_theme_constant_override("margin_left", 36)
	content_margin.add_theme_constant_override("margin_top", 36)
	content_margin.add_theme_constant_override("margin_right", 36)
	content_margin.add_theme_constant_override("margin_bottom", 36)
	content_panel.add_child(content_margin)

	var content_layout := VBoxContainer.new()
	content_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_layout.add_theme_constant_override("separation", 22)
	content_margin.add_child(content_layout)

	_menu_nested_title_label = Label.new()
	_menu_nested_title_label.text = "Пауза"
	_menu_nested_title_label.add_theme_font_size_override("font_size", 28)
	content_layout.add_child(_menu_nested_title_label)

	_menu_summary_label = Label.new()
	_menu_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_layout.add_child(_menu_summary_label)

	_menu_subpanel_host = Control.new()
	_menu_subpanel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_menu_subpanel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_layout.add_child(_menu_subpanel_host)

	_menu_save_panel = SaveSlotsPanel.new()
	_menu_save_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_save_panel.visible = false
	_menu_subpanel_host.add_child(_menu_save_panel)

	_menu_load_panel = SaveSlotsPanel.new()
	_menu_load_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_load_panel.visible = false
	_menu_subpanel_host.add_child(_menu_load_panel)

	_menu_settings_panel = SettingsPanel.new()
	_menu_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu_settings_panel.visible = false
	_menu_subpanel_host.add_child(_menu_settings_panel)

	_main_menu_confirm_dialog = StyledConfirmationDialog.new()
	_main_menu_confirm_dialog.dialog_text = "Выйти в главное меню? Несохранённый прогресс будет потерян."
	_main_menu_confirm_dialog.confirmed.connect(_on_main_menu_confirmed)
	add_child(_main_menu_confirm_dialog)

	_show_menu_home()


func _build_menu_action_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0.0, 62.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 24)
	button.pressed.connect(callback)
	return button


func _refresh_menu_page() -> void:
	if _menu_page == null:
		return

	var current_time := GameTime.get_current_time_data()
	var room_scene_path := GameManager.get_current_room_scene_path()
	var summary_lines: Array[String] = [
		"Игра поставлена на паузу.",
		"Локация: %s" % SaveDataUtils.format_room_name(room_scene_path),
		"Игровое время: день %d, %02d:%02d" % [
			int(current_time.get("day", 1)),
			int(current_time.get("hours", 0)),
			int(current_time.get("minutes", 0)),
		],
	]
	var latest_summary := SaveManager.get_continue_summary()

	if not latest_summary.is_empty():
		var latest_data: Dictionary = SaveDataUtils.sanitize_dictionary(latest_summary.get("summary", {}))
		summary_lines.append(
			"Последний сейв: %s, день %d %02d:%02d" % [
				String(latest_data.get("room_name", "Неизвестно")),
				int(latest_data.get("day", 1)),
				int(latest_data.get("hours", 0)),
				int(latest_data.get("minutes", 0)),
			]
		)

	_menu_summary_label.text = "\n".join(summary_lines)

	match _menu_nested_view:
		&"save":
			_menu_nested_title_label.text = "Ручное сохранение"
			_menu_summary_label.visible = false
			_menu_save_panel.visible = true
			_menu_load_panel.visible = false
			_menu_settings_panel.visible = false
			_menu_save_panel.configure(SaveSlotsPanel.MODE_SAVE)
			_menu_save_panel.refresh_panel()
		&"load":
			_menu_nested_title_label.text = "Загрузка"
			_menu_summary_label.visible = false
			_menu_save_panel.visible = false
			_menu_load_panel.visible = true
			_menu_settings_panel.visible = false
			_menu_load_panel.configure(SaveSlotsPanel.MODE_LOAD)
			_menu_load_panel.refresh_panel()
		&"settings":
			_menu_nested_title_label.text = "Настройки"
			_menu_summary_label.visible = false
			_menu_save_panel.visible = false
			_menu_load_panel.visible = false
			_menu_settings_panel.visible = true
			_menu_settings_panel.refresh_panel()
		_:
			_menu_nested_title_label.text = "Пауза"
			_menu_summary_label.visible = true
			_menu_save_panel.visible = false
			_menu_load_panel.visible = false
			_menu_settings_panel.visible = false


func _show_menu_home() -> void:
	_menu_nested_view = &"home"

	if _menu_settings_panel != null:
		_menu_settings_panel.stop_rebind_capture()

	_refresh_menu_page()


func _close_menu_nested_view() -> void:
	_show_menu_home()


func _on_resume_button_pressed() -> void:
	close_inventory()


func _on_menu_save_button_pressed() -> void:
	_menu_nested_view = &"save"
	_refresh_menu_page()


func _on_menu_load_button_pressed() -> void:
	_menu_nested_view = &"load"
	_refresh_menu_page()


func _on_menu_settings_button_pressed() -> void:
	_menu_nested_view = &"settings"
	_refresh_menu_page()


func _on_menu_main_menu_button_pressed() -> void:
	if _main_menu_confirm_dialog != null:
		_main_menu_confirm_dialog.popup_confirmation(
			"Подтверждение",
			"Выйти в главное меню? Несохраненный прогресс будет потерян.",
			"Выйти",
			"Отмена"
		)


func _on_main_menu_confirmed() -> void:
	if _menu_settings_panel != null:
		_menu_settings_panel.stop_rebind_capture()

	SaveManager.return_to_title_screen()


func _handle_tab_hotkey(target_tab: StringName) -> void:
	if _is_nested_input_capture_active():
		return

	if visible:
		if _active_tab == target_tab:
			close_inventory()
		else:
			_switch_tab(target_tab)
		return

	if _can_open_inventory():
		_open_with_tab(target_tab)


func _is_nested_input_capture_active() -> bool:
	if _menu_settings_panel != null and _menu_settings_panel.visible and _menu_settings_panel.is_waiting_for_rebind():
		return true

	if _main_menu_confirm_dialog != null and _main_menu_confirm_dialog.is_open():
		return true

	return false


func _connect_settings_signals() -> void:
	if GameSettings == null:
		return

	if not GameSettings.settings_changed.is_connected(_on_settings_changed):
		GameSettings.settings_changed.connect(_on_settings_changed)

	_on_settings_changed()


func _on_settings_changed() -> void:
	_refresh_inventory_shortcut_key()
	_refresh_menu_page()


func _can_open_inventory() -> bool:
	_resolve_scene_references()

	if _player != null and _player.has_method("is_input_locked") and _player.is_input_locked():
		return false

	if PhoneManager != null and PhoneManager.has_method("is_phone_open") and PhoneManager.is_phone_open():
		return false

	if DialogueManager != null and DialogueManager.has_method("is_dialogue_visible") and DialogueManager.is_dialogue_visible():
		return false

	return true


func _apply_modal_state(is_active: bool) -> void:
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(is_active)

	if _hud != null and _hud.has_method("set_clock_paused"):
		_hud.set_clock_paused(is_active)


func _apply_fullscreen_layout() -> void:
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.offset_left = 0.0
	overlay.offset_top = 0.0
	overlay.offset_right = 0.0
	overlay.offset_bottom = 0.0


func _grab_initial_focus() -> void:
	if close_button != null:
		close_button.grab_focus()


func _resolve_scene_references() -> void:
	if _player == null:
		_player = _resolve_node(player_path, "player")

	if _hud == null:
		_hud = _resolve_node(hud_path, "hud")


func _resolve_player_stats() -> void:
	_stats = get_node_or_null("/root/PlayerStats") as PlayerStatsState


func _resolve_freelance_state() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")


func _resolve_story_state() -> void:
	_story_state = get_node_or_null("/root/StoryState")


func _connect_player_stats_signals() -> void:
	if _stats == null:
		return

	if not _stats.stats_changed.is_connected(_on_stats_changed):
		_stats.stats_changed.connect(_on_stats_changed)


func _connect_freelance_state_signals() -> void:
	if _freelance_state == null:
		return

	if not _freelance_state.has_signal(&"conditions_changed"):
		return

	var refresh_callable: Callable = Callable(self, "_on_conditions_changed")

	if _freelance_state.is_connected(&"conditions_changed", refresh_callable):
		return

	_freelance_state.connect(&"conditions_changed", refresh_callable)


func _connect_story_state_signals() -> void:
	if _story_state == null:
		return

	if not _story_state.has_signal(&"primary_objective_changed"):
		return

	var refresh_callable: Callable = Callable(self, "_on_primary_objective_changed")

	if _story_state.is_connected(&"primary_objective_changed", refresh_callable):
		return

	_story_state.connect(&"primary_objective_changed", refresh_callable)


func _resolve_node(node_path: NodePath, group_name: String) -> Node:
	if not node_path.is_empty():
		var node := get_node_or_null(node_path)

		if node != null:
			return node

	return get_tree().get_first_node_in_group(group_name)


func _get_player_inventory() -> PlayerInventoryState:
	return get_node_or_null("/root/PlayerInventory") as PlayerInventoryState
