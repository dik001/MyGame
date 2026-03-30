extends CanvasLayer


const ROW_SCENE := preload("res://scenes/ui/InventoryRowUI.tscn")
const SLOT_SCENE := preload("res://scenes/ui/InventorySlotUI.tscn")
const STATUS_CONDITION_ROW_SCENE := preload("res://scenes/ui/StatusConditionRow.tscn")
const EquipmentDropTargetScript := preload("res://scenes/ui/EquipmentDropTarget.gd")
const EquipmentPreviewScript := preload("res://scenes/ui/EquipmentPreview.gd")
const MOOD_ICON_GOOD := preload("res://art/ui/stats/Mood_nice.png")
const MOOD_ICON_NEUTRAL := preload("res://art/ui/stats/Mood_niceandbad.png")
const MOOD_ICON_BAD := preload("res://art/ui/stats/Mood_VeryBad.png")
const STRESS_ICON := preload("res://art/ui/stats/Stress.png")

const TAB_INVENTORY: StringName = &"inventory"
const TAB_EQUIPMENT: StringName = &"equipment"
const TAB_STATUS: StringName = &"status"
const TAB_QUESTS: StringName = &"quests"
const TAB_MENU: StringName = &"menu"
const EQUIPMENT_SLOT_ORDER: Array[StringName] = [
	&"head",
	&"top",
	&"bottom",
	&"shoes",
]
const EQUIPMENT_SLOT_LABELS := {
	&"head": "Голова",
	&"top": "Верх",
	&"bottom": "Низ",
	&"shoes": "Обувь",
}

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
@onready var stats_content: VBoxContainer = $Overlay/ScreenMargin/WindowPanel/MarginContainer/WindowLayout/MainRow/LeftColumn/InventoryStatsPanel/MarginContainer/StatsContent
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
var _mental_state: Node = null
var _row_controls: Array = []
var _condition_row_controls: Array = []
var _condition_display_by_id: Dictionary = {}
var _selected_slot_index := -1
var _selected_condition_id := ""
var _active_tab: StringName = TAB_INVENTORY
var _tab_button_equipment: Button
var _equipment_page: VBoxContainer
var _equipment_stats_label: Label
var _equipment_drop_target: PanelContainer
var _equipment_scroll_container: ScrollContainer
var _equipment_rows_container: VBoxContainer
var _equipment_empty_label: Label
var _equipment_slot_controls: Dictionary = {}
var _equipment_preview: Control
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
var _mood_stat_icon: TextureRect = null
var _mood_stat_value_label: Label = null
var _mood_stat_bar: ProgressBar = null
var _stress_stat_icon: TextureRect = null
var _stress_stat_value_label: Label = null
var _stress_stat_bar: ProgressBar = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 6
	_apply_fullscreen_layout()
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_apply_inventory_static_texts()
	_apply_quest_static_texts()
	_ensure_mental_stat_rows()
	_build_equipment_tab()
	_rebuild_equipment_tab_layout_v2()
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
	_resolve_mental_state()
	_connect_player_stats_signals()
	_connect_mental_state_signals()
	_resolve_freelance_state()
	_connect_freelance_state_signals()
	_resolve_story_state()
	_connect_story_state_signals()
	_connect_settings_signals()

	var player_inventory := _get_player_inventory()

	if player_inventory != null and not player_inventory.inventory_changed.is_connected(_on_inventory_changed):
		player_inventory.inventory_changed.connect(_on_inventory_changed)

	_connect_player_equipment_signals()
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
	_resolve_mental_state()
	_connect_player_stats_signals()
	_connect_mental_state_signals()
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
	_refresh_equipment_page()


func _on_conditions_changed() -> void:
	if not is_inside_tree():
		return

	_refresh_status_page()


func _on_stats_changed(_current_stats: Dictionary) -> void:
	if not is_inside_tree():
		return

	_refresh_stats_panel()


func _on_mental_state_changed(_snapshot: Dictionary) -> void:
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


func _on_equipment_changed(_equipped_state: Dictionary) -> void:
	_refresh_equipment_page()
	_update_action_buttons()


func _on_condition_selected(condition_id: String) -> void:
	_selected_condition_id = condition_id
	_sync_condition_selection()
	_show_selected_condition_details()


func _on_inventory_tab_pressed() -> void:
	_switch_tab(TAB_INVENTORY)


func _on_equipment_tab_pressed() -> void:
	_switch_tab(TAB_EQUIPMENT)


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

	var slot_data := _get_selected_slot_data()

	if slot_data != null and slot_data.item_data != null and slot_data.item_data.is_equipment_item():
		var player_equipment = _get_player_equipment()

		if player_equipment == null:
			return

		if _is_selected_slot_equipped():
			player_equipment.unequip_slot(slot_data.item_data.get_equipment_slot())
		else:
			player_equipment.equip_item(_selected_slot_index)

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
	_refresh_equipment_page()
	_refresh_status_page()
	_refresh_quests_page()
	_refresh_menu_page()
	_refresh_stats_panel()
	_update_tab_state()
	_update_action_buttons()


func _switch_tab(tab_name: StringName) -> void:
	match tab_name:
		TAB_EQUIPMENT:
			_active_tab = TAB_EQUIPMENT
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


func _refresh_equipment_page() -> void:
	if _equipment_page == null:
		return

	var player_inventory := _get_player_inventory()
	var player_equipment = _get_player_equipment()
	var slots: Array = player_inventory.get_slots() if player_inventory != null else []
	var has_items := false

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_control := _equipment_slot_controls.get(slot_name) as InventorySlotUI

		if slot_control == null:
			continue

		var equipped_slot_data = player_equipment.get_equipped_slot_data(slot_name) if player_equipment != null else null
		var equipped_inventory_slot_index = (
			player_equipment.get_equipped_inventory_slot_index(slot_name)
			if player_equipment != null
			else -1
		)
		var drag_payload: Dictionary = {}

		if equipped_slot_data != null and not equipped_slot_data.is_empty():
			drag_payload = {
				"drag_type": "equipped_item",
				"equipment_slot": slot_name,
				"inventory_slot_index": equipped_inventory_slot_index,
				"instance_id": (
					player_inventory.get_slot_instance_id(equipped_inventory_slot_index)
					if player_inventory != null and equipped_inventory_slot_index >= 0
					else ""
				),
			}

		slot_control.bind_equipment_slot(
			slot_name,
			equipped_slot_data,
			drag_payload,
			""
		)

	if _equipment_stats_label != null:
		var equipment_stats = (
			player_equipment.get_equipment_stats()
			if player_equipment != null and player_equipment.has_method("get_equipment_stats")
			else {}
		)
		_equipment_stats_label.text = _format_equipment_stats(equipment_stats)

	if _equipment_preview != null and _equipment_preview.has_method("refresh_preview"):
		_equipment_preview.refresh_preview()

	_clear_equipment_rows()

	for slot_index in range(slots.size()):
		var slot_data := slots[slot_index] as InventorySlotData

		if slot_data == null or slot_data.is_empty() or slot_data.item_data == null:
			continue

		if not slot_data.item_data.is_equipment_item():
			continue

		if player_equipment != null and player_equipment.is_inventory_slot_equipped(slot_index):
			continue

		has_items = true
		var row := ROW_SCENE.instantiate() as InventoryRowUI

		if row == null:
			continue

		row.row_selected.connect(_on_equipment_inventory_item_pressed)
		row.row_drop_requested.connect(_on_equipment_row_drop_requested)
		row.bind_row(slot_index, slot_data)
		row.set_drag_payload({
			"drag_type": "equipment_inventory_item",
			"inventory_slot_index": slot_index,
			"equipment_slot": slot_data.item_data.get_equipment_slot(),
			"instance_id": (
				player_inventory.get_slot_instance_id(slot_index)
				if player_inventory != null and player_inventory.has_method("get_slot_instance_id")
				else ""
			),
		})
		row.set_accepted_drop_types(PackedStringArray(["equipped_item"]))
		_equipment_rows_container.add_child(row)

	if _equipment_empty_label != null:
		_equipment_empty_label.visible = not has_items

	if _equipment_scroll_container != null:
		_equipment_scroll_container.visible = has_items


func _clear_equipment_rows() -> void:
	if _equipment_rows_container == null:
		return

	for child in _equipment_rows_container.get_children():
		_equipment_rows_container.remove_child(child)
		child.queue_free()


func _on_equipment_inventory_item_pressed(slot_index: int) -> void:
	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return

	player_equipment.equip_item(slot_index)


func _on_equipment_slot_pressed(slot_name: StringName) -> void:
	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return

	player_equipment.unequip_slot(slot_name)


func _on_equipment_slot_drop_requested(_slot_name: StringName, data: Dictionary) -> void:
	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return

	if String(data.get("drag_type", "")).strip_edges() != "equipment_inventory_item":
		return

	player_equipment.equip_item(int(data.get("inventory_slot_index", -1)))


func _on_equipment_row_drop_requested(_slot_index: int, data: Dictionary) -> void:
	_on_equipment_drop_target_received(data)


func _on_equipment_drop_target_received(data: Dictionary) -> void:
	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return

	if String(data.get("drag_type", "")).strip_edges() != "equipped_item":
		return

	player_equipment.unequip_slot(StringName(data.get("equipment_slot", &"")))


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
	var mental_snapshot := _get_mental_stats_snapshot()
	var mental_available := not mental_snapshot.is_empty()

	stats_status_label.visible = not stats_available

	if not stats_available:
		stats_status_label.text = "Данные о показателях недоступны"
		_set_stat_row_unavailable(health_value_label, health_bar)
		_set_stat_row_unavailable(hunger_value_label, hunger_bar)
		_set_stat_row_unavailable(energy_value_label, energy_bar)
		_set_mental_rows_unavailable()
		return

	stats_status_label.text = ""
	_update_stat_bars(stats_snapshot)

	if mental_available:
		_update_mental_stat_bars(mental_snapshot)
	else:
		_set_mental_rows_unavailable()


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


func _update_mental_stat_bars(mental_snapshot: Dictionary) -> void:
	if _mood_stat_value_label != null and _mood_stat_bar != null:
		var mood_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("mood_state", {}))
		var mood_value := float(mental_snapshot.get("mood", 0.0))
		_build_stat_row(
			_mood_stat_value_label,
			_mood_stat_bar,
			mood_value,
			mental_snapshot.get("max_value", 100.0)
		)
		_apply_mental_bar_style(
			_mood_stat_value_label,
			_mood_stat_bar,
			String(mood_state.get("id", "")),
			false
		)
		var mood_tooltip := String(mood_state.get("description", mood_state.get("title", "")))
		_mood_stat_value_label.tooltip_text = mood_tooltip
		_mood_stat_bar.tooltip_text = mood_tooltip
		if _mood_stat_icon != null:
			_mood_stat_icon.texture = _resolve_mood_icon(mood_value)
			_mood_stat_icon.tooltip_text = mood_tooltip

	if _stress_stat_value_label != null and _stress_stat_bar != null:
		var stress_state := SaveDataUtils.sanitize_dictionary(mental_snapshot.get("stress_state", {}))
		var stress_tooltip := String(stress_state.get("description", stress_state.get("title", "")))
		_build_stat_row(
			_stress_stat_value_label,
			_stress_stat_bar,
			mental_snapshot.get("stress", 0.0),
			mental_snapshot.get("max_value", 100.0)
		)
		_apply_mental_bar_style(
			_stress_stat_value_label,
			_stress_stat_bar,
			String(stress_state.get("id", "")),
			true
		)
		_stress_stat_value_label.tooltip_text = stress_tooltip
		_stress_stat_bar.tooltip_text = stress_tooltip
		if _stress_stat_icon != null:
			_stress_stat_icon.texture = STRESS_ICON
			_stress_stat_icon.tooltip_text = stress_tooltip


func _set_mental_rows_unavailable() -> void:
	if _mood_stat_value_label != null and _mood_stat_bar != null:
		_set_stat_row_unavailable(_mood_stat_value_label, _mood_stat_bar)

	if _stress_stat_value_label != null and _stress_stat_bar != null:
		_set_stat_row_unavailable(_stress_stat_value_label, _stress_stat_bar)


func _apply_mental_bar_style(
	value_label: Label,
	progress_bar: ProgressBar,
	state_id: String,
	is_stress: bool
) -> void:
	var display_color := _resolve_mental_state_color(state_id, is_stress)
	value_label.modulate = display_color
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = display_color
	fill_style.corner_radius_top_left = 6
	fill_style.corner_radius_top_right = 6
	fill_style.corner_radius_bottom_right = 6
	fill_style.corner_radius_bottom_left = 6
	progress_bar.add_theme_stylebox_override("fill", fill_style)


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

				var payload: Dictionary = normalized_entry.get("payload", {})

				if bool(payload.get("hidden_in_ui", false)):
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


func _ensure_mental_stat_rows() -> void:
	if stats_content == null or _mood_stat_value_label != null or _stress_stat_value_label != null:
		return

	var template_row := stats_content.get_node_or_null("EnergyStatRow") as VBoxContainer

	if template_row == null:
		return

	var mood_row := _create_mental_stat_row(template_row, "MoodStatRow", "Настроение")
	var stress_row := _create_mental_stat_row(template_row, "StressStatRow", "Стресс")

	if mood_row != null:
		stats_content.add_child(mood_row)
		stats_content.move_child(mood_row, stats_content.get_children().find(template_row) + 1)

	if stress_row != null:
		stats_content.add_child(stress_row)
		stats_content.move_child(stress_row, stats_content.get_children().find(template_row) + 2)


func _create_mental_stat_row(
	template_row: VBoxContainer,
	row_name: String,
	title_text: String
) -> VBoxContainer:
	var row := template_row.duplicate() as VBoxContainer

	if row == null:
		return null

	row.name = row_name
	var icon := row.get_node_or_null("HeaderRow/EnergyIcon") as TextureRect
	var title_label := row.get_node_or_null("HeaderRow/EnergyLabel") as Label
	var value_label := row.get_node_or_null("HeaderRow/EnergyValueLabel") as Label
	var bar := row.get_node_or_null("EnergyBar") as ProgressBar

	if icon != null:
		icon.visible = true
		icon.custom_minimum_size = Vector2(28, 28)

	if title_label != null:
		title_label.text = title_text

	match row_name:
		"MoodStatRow":
			if icon != null:
				icon.texture = MOOD_ICON_NEUTRAL
			_mood_stat_icon = icon
			_mood_stat_value_label = value_label
			_mood_stat_bar = bar
		"StressStatRow":
			if icon != null:
				icon.texture = STRESS_ICON
			_stress_stat_icon = icon
			_stress_stat_value_label = value_label
			_stress_stat_bar = bar

	return row


func _resolve_mood_icon(value: float) -> Texture2D:
	if value > 50.0:
		return MOOD_ICON_GOOD

	if value > 25.0:
		return MOOD_ICON_NEUTRAL

	return MOOD_ICON_BAD


func _resolve_mental_state_color(state_id: String, is_stress: bool) -> Color:
	if is_stress:
		match state_id:
			"calm":
				return Color(0.65, 0.89, 0.86, 1.0)
			"tense":
				return Color(0.98, 0.83, 0.45, 1.0)
			"high":
				return Color(0.98, 0.60, 0.30, 1.0)
			"panic":
				return Color(0.90, 0.30, 0.30, 1.0)
			_:
				return Color(0.75, 0.85, 0.88, 1.0)

	match state_id:
		"excellent":
			return Color(0.72, 0.92, 0.55, 1.0)
		"low":
			return Color(1.0, 0.82, 0.46, 1.0)
		"depressed":
			return Color(0.93, 0.42, 0.42, 1.0)
		_:
			return Color(0.93, 0.93, 0.93, 1.0)


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
	var show_equipment_page := _active_tab == TAB_EQUIPMENT
	var show_status_page := _active_tab == TAB_STATUS
	var show_quests_page := _active_tab == TAB_QUESTS
	var show_menu_page := _active_tab == TAB_MENU

	inventory_page.visible = show_inventory_page
	if _equipment_page != null:
		_equipment_page.visible = show_equipment_page
	status_page.visible = show_status_page
	quests_page.visible = show_quests_page
	if _menu_page != null:
		_menu_page.visible = show_menu_page
	tab_button_inventory.set_pressed_no_signal(show_inventory_page)
	if _tab_button_equipment != null:
		_tab_button_equipment.visible = true
		_tab_button_equipment.set_pressed_no_signal(show_equipment_page)
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
	use_button.text = "Использовать"

	if not inventory_tab_active:
		use_button.disabled = true
		drop_button.disabled = true
		return

	var slot_data := _get_selected_slot_data()
	var has_selection := slot_data != null and not slot_data.is_empty()
	var is_equipment_item := (
		has_selection
		and slot_data.item_data != null
		and slot_data.item_data.is_equipment_item()
	)
	var is_equipped := is_equipment_item and _is_selected_slot_equipped()
	var can_use := is_equipment_item or (
		has_selection
		and slot_data.item_data != null
		and slot_data.item_data.can_use_directly()
		and slot_data.can_consume_safely()
	)
	var can_drop := has_selection and not is_equipped

	if is_equipped:
		use_button.text = "\u0421\u043d\u044f\u0442\u044c"
	elif is_equipment_item:
		use_button.text = "\u041d\u0430\u0434\u0435\u0442\u044c"
	else:
		use_button.text = "\u0418\u0441\u043f\u043e\u043b\u044c\u0437\u043e\u0432\u0430\u0442\u044c"

	use_button.disabled = not can_use
	drop_button.disabled = not can_drop


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


func _get_mental_stats_snapshot() -> Dictionary:
	_resolve_mental_state()

	if _mental_state == null or not _mental_state.has_method("get_state"):
		return {}

	var snapshot_variant: Variant = _mental_state.call("get_state")
	return snapshot_variant.duplicate(true) if snapshot_variant is Dictionary else {}


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


func _build_equipment_tab() -> void:
	if _tab_button_equipment != null:
		return

	var left_menu := tab_button_inventory.get_parent() as VBoxContainer
	var pages_container := inventory_page.get_parent() as Control

	if left_menu == null or pages_container == null:
		return

	_tab_button_equipment = Button.new()
	_tab_button_equipment.name = "TabButton_Equipment"
	_tab_button_equipment.custom_minimum_size = tab_button_inventory.custom_minimum_size
	_tab_button_equipment.toggle_mode = tab_button_inventory.toggle_mode
	_tab_button_equipment.focus_mode = tab_button_inventory.focus_mode
	_tab_button_equipment.text = "Снаряжение"
	_tab_button_equipment.add_theme_font_size_override("font_size", tab_button_inventory.get_theme_font_size("font_size"))

	for stylebox_name in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		var stylebox := tab_button_inventory.get_theme_stylebox(stylebox_name)

		if stylebox != null:
			_tab_button_equipment.add_theme_stylebox_override(stylebox_name, stylebox)

	_tab_button_equipment.pressed.connect(_on_equipment_tab_pressed)
	left_menu.add_child(_tab_button_equipment)
	left_menu.move_child(_tab_button_equipment, left_menu.get_children().find(tab_button_inventory) + 1)

	_equipment_page = VBoxContainer.new()
	_equipment_page.name = "EquipmentPage"
	_equipment_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_equipment_page.add_theme_constant_override("separation", 18)
	_equipment_page.visible = false
	pages_container.add_child(_equipment_page)

	var header_label := Label.new()
	header_label.text = "Снаряжение"
	header_label.add_theme_font_size_override("font_size", 40)
	_equipment_page.add_child(header_label)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 18)
	_equipment_page.add_child(main_row)

	var equipped_panel := PanelContainer.new()
	equipped_panel.custom_minimum_size = Vector2(340.0, 0.0)
	equipped_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(equipped_panel)

	var equipped_margin := MarginContainer.new()
	equipped_margin.add_theme_constant_override("margin_left", 20)
	equipped_margin.add_theme_constant_override("margin_top", 20)
	equipped_margin.add_theme_constant_override("margin_right", 20)
	equipped_margin.add_theme_constant_override("margin_bottom", 20)
	equipped_panel.add_child(equipped_margin)

	var equipped_content := VBoxContainer.new()
	equipped_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_content.add_theme_constant_override("separation", 16)
	equipped_margin.add_child(equipped_content)

	var equipped_title := Label.new()
	equipped_title.text = "Надето"
	equipped_title.add_theme_font_size_override("font_size", 28)
	equipped_content.add_child(equipped_title)

	_equipment_stats_label = Label.new()
	_equipment_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_content.add_child(_equipment_stats_label)

	var slots_container := VBoxContainer.new()
	slots_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_container.add_theme_constant_override("separation", 12)
	equipped_content.add_child(slots_container)

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_row := HBoxContainer.new()
		slot_row.add_theme_constant_override("separation", 12)
		slots_container.add_child(slot_row)

		var slot_label := Label.new()
		slot_label.custom_minimum_size = Vector2(110.0, 0.0)
		slot_label.text = String(EQUIPMENT_SLOT_LABELS.get(slot_name, String(slot_name).capitalize()))
		slot_row.add_child(slot_label)

		var slot_control := SLOT_SCENE.instantiate() as InventorySlotUI

		if slot_control == null:
			continue

		slot_control.equipment_slot_pressed.connect(_on_equipment_slot_pressed)
		slot_control.equipment_item_dropped.connect(_on_equipment_slot_drop_requested)
		slot_row.add_child(slot_control)
		_equipment_slot_controls[slot_name] = slot_control

	var inventory_panel := EquipmentDropTargetScript.new() as PanelContainer

	if inventory_panel == null:
		return

	inventory_panel.name = "EquipmentInventoryPanel"
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_panel.drop_received.connect(_on_equipment_drop_target_received)
	main_row.add_child(inventory_panel)
	_equipment_drop_target = inventory_panel

	var inventory_margin := MarginContainer.new()
	inventory_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_margin.add_theme_constant_override("margin_left", 20)
	inventory_margin.add_theme_constant_override("margin_top", 20)
	inventory_margin.add_theme_constant_override("margin_right", 20)
	inventory_margin.add_theme_constant_override("margin_bottom", 20)
	inventory_panel.add_child(inventory_margin)

	var inventory_content := VBoxContainer.new()
	inventory_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 14)
	inventory_margin.add_child(inventory_content)

	var inventory_title := Label.new()
	inventory_title.text = "Предметы"
	inventory_title.add_theme_font_size_override("font_size", 28)
	inventory_content.add_child(inventory_title)

	var inventory_hint := Label.new()
	inventory_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_hint.text = "Клик по предмету надевает его сразу. Предмет из слота можно снять кликом или перетащить обратно сюда."
	inventory_content.add_child(inventory_hint)

	_equipment_scroll_container = ScrollContainer.new()
	_equipment_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_child(_equipment_scroll_container)

	_equipment_rows_container = VBoxContainer.new()
	_equipment_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_rows_container.add_theme_constant_override("separation", 8)
	_equipment_scroll_container.add_child(_equipment_rows_container)

	_equipment_empty_label = Label.new()
	_equipment_empty_label.custom_minimum_size = Vector2(0.0, 240.0)
	_equipment_empty_label.visible = false
	_equipment_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipment_empty_label.text = "Подходящих предметов нет"
	inventory_content.add_child(_equipment_empty_label)


func _rebuild_equipment_tab_layout() -> void:
	if _equipment_page == null:
		return

	for child in _equipment_page.get_children():
		_equipment_page.remove_child(child)
		child.queue_free()

	_equipment_slot_controls.clear()
	_equipment_drop_target = null
	_equipment_scroll_container = null
	_equipment_rows_container = null
	_equipment_empty_label = null
	_equipment_stats_label = null
	_equipment_preview = null

	var header_label := Label.new()
	header_label.text = "Снаряжение"
	header_label.add_theme_font_size_override("font_size", 40)
	_equipment_page.add_child(header_label)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 24)
	_equipment_page.add_child(main_row)

	var equipped_panel := PanelContainer.new()
	equipped_panel.custom_minimum_size = Vector2(420.0, 0.0)
	equipped_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(equipped_panel)

	var equipped_margin := MarginContainer.new()
	equipped_margin.add_theme_constant_override("margin_left", 20)
	equipped_margin.add_theme_constant_override("margin_top", 20)
	equipped_margin.add_theme_constant_override("margin_right", 20)
	equipped_margin.add_theme_constant_override("margin_bottom", 20)
	equipped_panel.add_child(equipped_margin)

	var equipped_content := VBoxContainer.new()
	equipped_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_content.add_theme_constant_override("separation", 16)
	equipped_margin.add_child(equipped_content)

	var equipped_title := Label.new()
	equipped_title.text = "Бумажная кукла"
	equipped_title.add_theme_font_size_override("font_size", 28)
	equipped_content.add_child(equipped_title)

	var equipped_hint := Label.new()
	equipped_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_hint.text = "Нажми по вещи, чтобы надеть или снять. Можно перетаскивать одежду между куклой и списком."
	equipped_content.add_child(equipped_hint)

	_equipment_stats_label = Label.new()
	_equipment_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_content.add_child(_equipment_stats_label)

	var doll_panel := PanelContainer.new()
	doll_panel.custom_minimum_size = Vector2(0.0, 430.0)
	doll_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_content.add_child(doll_panel)

	var doll_margin := MarginContainer.new()
	doll_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doll_margin.add_theme_constant_override("margin_left", 18)
	doll_margin.add_theme_constant_override("margin_top", 18)
	doll_margin.add_theme_constant_override("margin_right", 18)
	doll_margin.add_theme_constant_override("margin_bottom", 18)
	doll_panel.add_child(doll_margin)

	var doll_canvas := Control.new()
	doll_canvas.custom_minimum_size = Vector2(330.0, 380.0)
	doll_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	doll_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	doll_margin.add_child(doll_canvas)

	var silhouette_panel := PanelContainer.new()
	silhouette_panel.position = Vector2(104.0, 28.0)
	silhouette_panel.custom_minimum_size = Vector2(122.0, 304.0)
	doll_canvas.add_child(silhouette_panel)

	var silhouette_label := Label.new()
	silhouette_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	silhouette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouette_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	silhouette_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	silhouette_label.text = "ГОЛОВА\n\nВЕРХ\n\nНИЗ\n\nОБУВЬ"
	silhouette_panel.add_child(silhouette_label)

	var slot_positions := {
		&"head": Vector2(118.0, 0.0),
		&"top": Vector2(118.0, 92.0),
		&"bottom": Vector2(118.0, 184.0),
		&"shoes": Vector2(118.0, 276.0),
	}

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_control := SLOT_SCENE.instantiate() as InventorySlotUI

		if slot_control == null:
			continue

		slot_control.custom_minimum_size = Vector2(104.0, 104.0)
		slot_control.position = slot_positions.get(slot_name, Vector2.ZERO)
		slot_control.equipment_slot_pressed.connect(_on_equipment_slot_pressed)
		slot_control.equipment_item_dropped.connect(_on_equipment_slot_drop_requested)
		doll_canvas.add_child(slot_control)
		_equipment_slot_controls[slot_name] = slot_control

		var slot_label := Label.new()
		slot_label.custom_minimum_size = Vector2(120.0, 24.0)
		slot_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot_label.text = _get_equipment_slot_placeholder(slot_name)
		slot_label.position = Vector2(float(slot_control.position.x) - 12.0, float(slot_control.position.y) + 98.0)
		doll_canvas.add_child(slot_label)

	var inventory_panel := EquipmentDropTargetScript.new() as PanelContainer

	if inventory_panel == null:
		return

	inventory_panel.name = "EquipmentInventoryPanel"
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_panel.drop_received.connect(_on_equipment_drop_target_received)
	main_row.add_child(inventory_panel)
	_equipment_drop_target = inventory_panel

	var inventory_margin := MarginContainer.new()
	inventory_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_margin.add_theme_constant_override("margin_left", 20)
	inventory_margin.add_theme_constant_override("margin_top", 20)
	inventory_margin.add_theme_constant_override("margin_right", 20)
	inventory_margin.add_theme_constant_override("margin_bottom", 20)
	inventory_panel.add_child(inventory_margin)

	var inventory_content := VBoxContainer.new()
	inventory_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 14)
	inventory_margin.add_child(inventory_content)

	var inventory_title := Label.new()
	inventory_title.text = "Одежда в инвентаре"
	inventory_title.add_theme_font_size_override("font_size", 28)
	inventory_content.add_child(inventory_title)

	var inventory_hint := Label.new()
	inventory_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_hint.text = "Здесь показывается только одежда. Нажатие сразу надевает вещь в подходящий слот."
	inventory_content.add_child(inventory_hint)

	_equipment_scroll_container = ScrollContainer.new()
	_equipment_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_child(_equipment_scroll_container)

	_equipment_rows_container = VBoxContainer.new()
	_equipment_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_rows_container.add_theme_constant_override("separation", 8)
	_equipment_scroll_container.add_child(_equipment_rows_container)

	_equipment_empty_label = Label.new()
	_equipment_empty_label.custom_minimum_size = Vector2(0.0, 240.0)
	_equipment_empty_label.visible = false
	_equipment_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipment_empty_label.text = "Подходящей одежды нет"
	inventory_content.add_child(_equipment_empty_label)


func _rebuild_equipment_tab_layout_v2() -> void:
	if _equipment_page == null:
		return

	for child in _equipment_page.get_children():
		_equipment_page.remove_child(child)
		child.queue_free()

	_equipment_slot_controls.clear()
	_equipment_drop_target = null
	_equipment_scroll_container = null
	_equipment_rows_container = null
	_equipment_empty_label = null
	_equipment_stats_label = null

	var header_label := Label.new()
	header_label.text = "Снаряжение"
	header_label.add_theme_font_size_override("font_size", 40)
	_equipment_page.add_child(header_label)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 20)
	_equipment_page.add_child(main_row)

	var equipped_panel := PanelContainer.new()
	equipped_panel.custom_minimum_size = Vector2(520.0, 0.0)
	equipped_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_child(equipped_panel)

	var equipped_margin := MarginContainer.new()
	equipped_margin.add_theme_constant_override("margin_left", 20)
	equipped_margin.add_theme_constant_override("margin_top", 20)
	equipped_margin.add_theme_constant_override("margin_right", 20)
	equipped_margin.add_theme_constant_override("margin_bottom", 20)
	equipped_panel.add_child(equipped_margin)

	var equipped_content := VBoxContainer.new()
	equipped_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipped_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipped_content.add_theme_constant_override("separation", 16)
	equipped_margin.add_child(equipped_content)

	var equipped_title := Label.new()
	equipped_title.text = "Экипировка"
	equipped_title.add_theme_font_size_override("font_size", 28)
	equipped_content.add_child(equipped_title)

	var equipped_hint := Label.new()
	equipped_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_hint.text = "Нажми по вещи, чтобы надеть или снять. Слева текущая экипировка, справа список одежды."
	equipped_content.add_child(equipped_hint)

	_equipment_stats_label = Label.new()
	_equipment_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	equipped_content.add_child(_equipment_stats_label)

	var equipment_body := HBoxContainer.new()
	equipment_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equipment_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_body.add_theme_constant_override("separation", 18)
	equipped_content.add_child(equipment_body)

	var silhouette_panel := PanelContainer.new()
	silhouette_panel.custom_minimum_size = Vector2(220.0, 380.0)
	silhouette_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	equipment_body.add_child(silhouette_panel)

	var silhouette_margin := MarginContainer.new()
	silhouette_margin.add_theme_constant_override("margin_left", 16)
	silhouette_margin.add_theme_constant_override("margin_top", 16)
	silhouette_margin.add_theme_constant_override("margin_right", 16)
	silhouette_margin.add_theme_constant_override("margin_bottom", 16)
	silhouette_panel.add_child(silhouette_margin)

	var silhouette_label := Label.new()
	silhouette_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	silhouette_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	silhouette_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	silhouette_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	silhouette_label.text = "ГЕРОИНЯ\n\nГолова\nВерх\nНиз\nОбувь"
	silhouette_margin.add_child(silhouette_label)

	_equipment_preview = EquipmentPreviewScript.new()
	_equipment_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	silhouette_margin.add_child(_equipment_preview)

	if _equipment_preview.has_method("setup"):
		_equipment_preview.setup(_get_player_equipment(), _get_player_body_state())

	for existing_child in silhouette_margin.get_children():
		if existing_child == _equipment_preview:
			continue

		existing_child.queue_free()

	var slots_panel := VBoxContainer.new()
	slots_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slots_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slots_panel.add_theme_constant_override("separation", 14)
	equipment_body.add_child(slots_panel)

	var slot_frame_style := StyleBoxFlat.new()
	slot_frame_style.bg_color = Color(0.0901961, 0.121569, 0.180392, 0.98)
	slot_frame_style.border_width_left = 2
	slot_frame_style.border_width_top = 2
	slot_frame_style.border_width_right = 2
	slot_frame_style.border_width_bottom = 2
	slot_frame_style.border_color = Color(0.509804, 0.631373, 0.792157, 1.0)
	slot_frame_style.corner_radius_top_left = 10
	slot_frame_style.corner_radius_top_right = 10
	slot_frame_style.corner_radius_bottom_right = 10
	slot_frame_style.corner_radius_bottom_left = 10

	for slot_name in EQUIPMENT_SLOT_ORDER:
		var slot_frame := PanelContainer.new()
		slot_frame.custom_minimum_size = Vector2(240.0, 110.0)
		slot_frame.add_theme_stylebox_override("panel", slot_frame_style)
		slots_panel.add_child(slot_frame)

		var slot_margin := MarginContainer.new()
		slot_margin.add_theme_constant_override("margin_left", 12)
		slot_margin.add_theme_constant_override("margin_top", 12)
		slot_margin.add_theme_constant_override("margin_right", 12)
		slot_margin.add_theme_constant_override("margin_bottom", 12)
		slot_frame.add_child(slot_margin)

		var slot_row := HBoxContainer.new()
		slot_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_row.add_theme_constant_override("separation", 14)
		slot_margin.add_child(slot_row)

		var slot_label := Label.new()
		slot_label.custom_minimum_size = Vector2(110.0, 0.0)
		slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		slot_label.add_theme_color_override("font_outline_color", Color(0.0196078, 0.0352941, 0.0745098, 1.0))
		slot_label.add_theme_constant_override("outline_size", 8)
		slot_label.add_theme_font_size_override("font_size", 22)
		slot_label.text = _get_equipment_slot_display_name(slot_name)
		slot_row.add_child(slot_label)

		var slot_control := SLOT_SCENE.instantiate() as InventorySlotUI

		if slot_control == null:
			continue

		slot_control.custom_minimum_size = Vector2(86.0, 86.0)
		slot_control.equipment_slot_pressed.connect(_on_equipment_slot_pressed)
		slot_control.equipment_item_dropped.connect(_on_equipment_slot_drop_requested)
		slot_row.add_child(slot_control)
		_equipment_slot_controls[slot_name] = slot_control

	var inventory_panel := EquipmentDropTargetScript.new() as PanelContainer

	if inventory_panel == null:
		return

	inventory_panel.name = "EquipmentInventoryPanel"
	inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_panel.drop_received.connect(_on_equipment_drop_target_received)
	main_row.add_child(inventory_panel)
	_equipment_drop_target = inventory_panel

	var inventory_margin := MarginContainer.new()
	inventory_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_margin.add_theme_constant_override("margin_left", 20)
	inventory_margin.add_theme_constant_override("margin_top", 20)
	inventory_margin.add_theme_constant_override("margin_right", 20)
	inventory_margin.add_theme_constant_override("margin_bottom", 20)
	inventory_panel.add_child(inventory_margin)

	var inventory_content := VBoxContainer.new()
	inventory_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inventory_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_theme_constant_override("separation", 14)
	inventory_margin.add_child(inventory_content)

	var inventory_title := Label.new()
	inventory_title.text = "Одежда в инвентаре"
	inventory_title.add_theme_font_size_override("font_size", 28)
	inventory_content.add_child(inventory_title)

	var inventory_hint := Label.new()
	inventory_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_hint.text = "Здесь показывается только одежда. Нажатие сразу надевает вещь в подходящий слот."
	inventory_content.add_child(inventory_hint)

	_equipment_scroll_container = ScrollContainer.new()
	_equipment_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inventory_content.add_child(_equipment_scroll_container)

	_equipment_rows_container = VBoxContainer.new()
	_equipment_rows_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_equipment_rows_container.add_theme_constant_override("separation", 8)
	_equipment_scroll_container.add_child(_equipment_rows_container)

	_equipment_empty_label = Label.new()
	_equipment_empty_label.custom_minimum_size = Vector2(0.0, 240.0)
	_equipment_empty_label.visible = false
	_equipment_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_equipment_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_equipment_empty_label.text = "Подходящей одежды нет"
	inventory_content.add_child(_equipment_empty_label)


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


func _resolve_mental_state() -> void:
	_mental_state = get_node_or_null("/root/PlayerMentalState")


func _resolve_freelance_state() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")


func _resolve_story_state() -> void:
	_story_state = get_node_or_null("/root/StoryState")


func _connect_player_stats_signals() -> void:
	if _stats == null:
		return

	if not _stats.stats_changed.is_connected(_on_stats_changed):
		_stats.stats_changed.connect(_on_stats_changed)


func _connect_mental_state_signals() -> void:
	if _mental_state == null:
		return

	if not _mental_state.has_signal(&"mental_state_changed"):
		return

	var refresh_callable: Callable = Callable(self, "_on_mental_state_changed")

	if _mental_state.is_connected(&"mental_state_changed", refresh_callable):
		return

	_mental_state.connect(&"mental_state_changed", refresh_callable)


func _connect_player_equipment_signals() -> void:
	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return

	if not player_equipment.equipment_changed.is_connected(_on_equipment_changed):
		player_equipment.equipment_changed.connect(_on_equipment_changed)


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


func _get_player_equipment() -> Node:
	return get_node_or_null("/root/PlayerEquipment")


func _get_player_body_state() -> Node:
	return get_node_or_null("/root/PlayerBodyState")


func _is_selected_slot_equipped() -> bool:
	if _selected_slot_index < 0:
		return false

	var player_equipment = _get_player_equipment()

	if player_equipment == null:
		return false

	return player_equipment.is_inventory_slot_equipped(_selected_slot_index)


func _get_equipment_slot_placeholder(slot_name: StringName) -> String:
	if String(slot_name) == "shoes":
		return "Ботинки"

	match String(slot_name):
		"head":
			return "Голова"
		"top":
			return "Верх"
		"bottom":
			return "Низ"
		"shoes":
			return "Обувь"
		_:
			return String(slot_name).capitalize()


func _get_equipment_slot_display_name(slot_name: StringName) -> String:
	if String(slot_name) == "shoes":
		return "Ботинки"

	match String(slot_name):
		"head":
			return "Голова"
		"top":
			return "Верх"
		"bottom":
			return "Низ"
		"shoes":
			return "Обувь"
		_:
			return String(slot_name).capitalize()


func _format_equipment_stats(stats: Dictionary) -> String:
	var speed_percent := int(round(float(stats.get("speed_modifier", 0.0)) * 100.0))
	var speed_prefix := "+" if speed_percent >= 0 else ""
	return "Защита: %d\nСкрытность: %d\nПривлекательность: %d\nСкорость: %s%d%%" % [
		int(stats.get("protection", 0)),
		int(stats.get("stealth", 0)),
		int(stats.get("attractiveness", 0)),
		speed_prefix,
		speed_percent,
	]
