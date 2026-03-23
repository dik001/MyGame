class_name PhoneUI
extends CanvasLayer

signal phone_opened
signal phone_closed
signal incoming_call_shown(contact_name: String, conversation_id: String)
signal call_accepted(contact_name: String)
signal call_ended(contact_name: String, duration: int)
signal sms_unlocked(contact_name: String)
signal sms_sent(contact_name: String, text: String)
signal sms_received(contact_name: String, text: String)

enum CallState {
	IDLE,
	INCOMING,
	ACTIVE,
	ENDED,
}

enum PhonePage {
	HOME,
	CALL,
	MAP,
	SMS,
}

const APARTMENT_SCENE := "res://scenes/rooms/apartament.tscn"
const ENTRANCE_SCENE := "res://scenes/rooms/enterance.tscn"
const ELEVATOR_SCENE := "res://scenes/rooms/elevator.tscn"
const TOWN_SCENE := "res://scenes/rooms/town.tscn"
const SUPERMARKET_SCENE := "res://scenes/rooms/supermarket.tscn"
const ROOM_DISPLAY_NAMES := {
	APARTMENT_SCENE: "Квартира",
	ENTRANCE_SCENE: "Подъезд",
	ELEVATOR_SCENE: "Лифт",
	TOWN_SCENE: "Улица",
	SUPERMARKET_SCENE: "Магазин",
}
const ROOM_CONNECTIONS: Array[Dictionary] = [
	{"from": APARTMENT_SCENE, "to": ENTRANCE_SCENE, "label": "Дверь квартиры"},
	{"from": ENTRANCE_SCENE, "to": ELEVATOR_SCENE, "label": "Дверь к лифту"},
	{"from": ENTRANCE_SCENE, "to": TOWN_SCENE, "label": "Выход на улицу"},
	{"from": ELEVATOR_SCENE, "to": TOWN_SCENE, "label": "Панель лифта"},
	{"from": TOWN_SCENE, "to": SUPERMARKET_SCENE, "label": "Вход в супермаркет"},
]
const MAP_NODE_SIZE := Vector2(104.0, 42.0)
const MAP_NODE_POSITIONS := {
	APARTMENT_SCENE: Vector2(12.0, 12.0),
	ENTRANCE_SCENE: Vector2(144.0, 12.0),
	ELEVATOR_SCENE: Vector2(144.0, 78.0),
	TOWN_SCENE: Vector2(144.0, 144.0),
	SUPERMARKET_SCENE: Vector2(12.0, 144.0),
}

const DEFAULT_CONTACT_NAME := "Контакт"
const DEFAULT_INCOMING_STATUS := "Входящий вызов"
const DEFAULT_ACTIVE_STATUS := "Разговор..."
const DEFAULT_ENDED_STATUS := "Завершён"
const DEFAULT_IDLE_STATUS := "Телефон ждёт нового звонка"
const DEFAULT_DIALOGUE_PREVIEW := "Мама: Ты где? Почему не отвечала?"
const DEFAULT_HOME_HINT := "Карта доступна всегда. SMS откроются после первого звонка."
const OPEN_TRANSITION_DURATION := 0.24
const CLOSED_OFFSET_Y := 720.0
const POST_END_DELAY := 1.1

@onready var root: Control = $Root
@onready var phone_shell: PanelContainer = $Root/PhoneAnchor/PhoneShell
@onready var layout: VBoxContainer = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout
@onready var content: VBoxContainer = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content
@onready var signal_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/StatusBar/MarginContainer/Row/SignalLabel
@onready var battery_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/StatusBar/MarginContainer/Row/BatteryLabel
@onready var time_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/StatusBar/MarginContainer/Row/TimeLabel
@onready var avatar_center: CenterContainer = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/AvatarCenter
@onready var avatar_texture: TextureRect = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/AvatarCenter/AvatarFrame/AvatarTexture
@onready var avatar_initials: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/AvatarCenter/AvatarFrame/AvatarInitials
@onready var name_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/NameLabel
@onready var call_status_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/CallStatusLabel
@onready var conversation_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/ConversationLabel
@onready var timer_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/TimerCenter/TimerPill/TimerLabel
@onready var dialogue_text_label: Label = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/DialoguePanel/DialogueMargin/DialogueTextLabel
@onready var content_spacer: Control = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/ContentSpacer
@onready var buttons_row: HBoxContainer = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/ButtonsRow
@onready var accept_button: Button = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/ButtonsRow/AcceptButton
@onready var end_button: Button = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/ButtonsRow/EndButton
@onready var bottom_indicator_center: CenterContainer = $Root/PhoneAnchor/PhoneShell/ScreenPanel/ScreenMargin/Layout/Content/BottomIndicatorCenter
@onready var status_clock_timer: Timer = $StatusClockTimer
@onready var call_duration_timer: Timer = $CallDurationTimer
@onready var post_end_timer: Timer = $PostEndTimer

var _call_state := CallState.IDLE
var _selected_page := PhonePage.HOME
var _page_before_call := PhonePage.HOME
var _current_contact_name := DEFAULT_CONTACT_NAME
var _current_conversation_id := ""
var _current_dialogue_text := ""
var _current_avatar: Texture2D = null
var _call_duration_seconds := 0
var _is_open := false
var _requested_open := false
var _layout_ready := false
var _auto_close_after_end := false
var _transition_tween: Tween = null
var _open_position := Vector2.ZERO
var _closed_position := Vector2.ZERO
var _sms_unlocked := false
var _selected_sms_contact := ""
var _sms_contact_order: Array[String] = []
var _sms_threads: Dictionary = {}
var _contact_avatars: Dictionary = {}
var _map_node_panels_by_scene: Dictionary = {}
var _header_row: HBoxContainer
var _back_button: Button
var _header_title_label: Label
var _home_page: VBoxContainer
var _map_page: VBoxContainer
var _sms_page: VBoxContainer
var _home_apps_grid: GridContainer
var _home_summary_label: Label
var _home_status_label: Label
var _home_hint_label: Label
var _map_home_button: Button
var _sms_home_button: Button
var _map_location_label: Label
var _map_diagram_container: Control
var _map_routes_label: Label
var _sms_locked_panel: PanelContainer
var _sms_content: VBoxContainer
var _sms_contacts_container: HBoxContainer
var _sms_selected_contact_label: Label
var _sms_messages_scroll: ScrollContainer
var _sms_messages_container: VBoxContainer
var _sms_empty_label: Label
var _sms_input: LineEdit
var _sms_send_button: Button
var _sms_helper_label: Label
var _app_dock_row: HBoxContainer
var _app_home_button: Button
var _app_map_button: Button
var _app_sms_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	phone_shell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	accept_button.pressed.connect(_on_accept_button_pressed)
	end_button.pressed.connect(_on_end_button_pressed)
	status_clock_timer.timeout.connect(_on_status_clock_timer_timeout)
	call_duration_timer.timeout.connect(_on_call_duration_timer_timeout)
	post_end_timer.timeout.connect(_on_post_end_timer_timeout)
	status_clock_timer.start()
	_build_header_row()
	_build_home_page()
	_build_map_page()
	_build_sms_page()
	_build_app_dock()
	_update_status_bar_text()
	_refresh_view()
	call_deferred("_initialize_layout")


func is_open() -> bool:
	return _is_open


func has_active_call() -> bool:
	return _call_state == CallState.INCOMING or _call_state == CallState.ACTIVE


func is_sms_unlocked() -> bool:
	return _sms_unlocked


func go_home() -> void:
	open_phone()
	_switch_to_page(PhonePage.HOME)


func open_map_app() -> void:
	open_phone()
	_switch_to_page(PhonePage.MAP)


func open_sms_app(contact_name: String = "") -> void:
	if not contact_name.strip_edges().is_empty() and _sms_threads.has(contact_name.strip_edges()):
		_selected_sms_contact = contact_name.strip_edges()

	open_phone()
	_switch_to_page(PhonePage.SMS)


func open_phone(instant := false) -> void:
	_requested_open = true
	_refresh_view()

	if not _layout_ready:
		return

	if _is_open and not instant:
		return

	_is_open = true
	_set_phone_interaction_enabled(true)
	_animate_visibility(_open_position, 1.0, instant)
	phone_opened.emit()


func close_phone(instant := false) -> void:
	_requested_open = false

	if _call_state == CallState.ENDED and _selected_page == PhonePage.CALL:
		_call_state = CallState.IDLE
		_selected_page = _restore_page_after_call()

	if not _layout_ready:
		return

	if not _is_open and not instant:
		return

	_is_open = false
	_set_phone_interaction_enabled(false)
	_animate_visibility(_closed_position, 0.0, instant)
	phone_closed.emit()


func toggle_phone() -> void:
	if _requested_open:
		close_phone()
		return

	open_phone()


func show_incoming_call(contact_name: String, avatar: Texture2D = null, conversation_id: String = "", dialogue_text: String = "") -> void:
	post_end_timer.stop()
	_page_before_call = _selected_page if _selected_page != PhonePage.CALL else PhonePage.HOME
	_auto_close_after_end = not (_requested_open or _is_open)
	_call_state = CallState.INCOMING
	_current_contact_name = _normalize_contact_name(contact_name)
	_current_avatar = avatar
	_current_conversation_id = conversation_id.strip_edges()
	_current_dialogue_text = dialogue_text.strip_edges()

	if _current_dialogue_text.is_empty():
		_current_dialogue_text = "%s: Ты где? Почему не отвечала?" % _current_contact_name

	_unlock_sms_for_contact(_current_contact_name, avatar)
	_selected_sms_contact = _current_contact_name
	reset_call_timer()
	_switch_to_page(PhonePage.CALL, true)
	open_phone()
	incoming_call_shown.emit(_current_contact_name, _current_conversation_id)


func accept_call() -> void:
	if _call_state != CallState.INCOMING:
		return

	post_end_timer.stop()
	_call_state = CallState.ACTIVE
	_call_duration_seconds = 0
	_refresh_timer_label()
	call_duration_timer.start()
	_refresh_view()
	call_accepted.emit(_current_contact_name)


func end_call() -> void:
	if _call_state == CallState.IDLE:
		return

	if _call_state == CallState.ENDED:
		return

	call_duration_timer.stop()
	_call_state = CallState.ENDED
	_refresh_view()
	call_ended.emit(_current_contact_name, _call_duration_seconds)
	post_end_timer.start(POST_END_DELAY)


func update_contact_data(contact_name: String, avatar: Texture2D = null, dialogue_text: String = "", conversation_id: String = "") -> void:
	_current_contact_name = _normalize_contact_name(contact_name)
	_current_avatar = avatar

	if avatar != null:
		_contact_avatars[_current_contact_name] = avatar

	if not dialogue_text.strip_edges().is_empty():
		_current_dialogue_text = dialogue_text.strip_edges()

	if not conversation_id.strip_edges().is_empty():
		_current_conversation_id = conversation_id.strip_edges()

	_refresh_view()


func set_dialogue_preview_text(dialogue_text: String) -> void:
	_current_dialogue_text = dialogue_text.strip_edges()
	_refresh_view()


func reset_call_timer() -> void:
	call_duration_timer.stop()
	_call_duration_seconds = 0
	_refresh_timer_label()


func send_sms(contact_name: String, text: String) -> void:
	var resolved_contact := contact_name.strip_edges()

	if resolved_contact.is_empty():
		resolved_contact = _selected_sms_contact

	var trimmed_text := text.strip_edges()

	if resolved_contact.is_empty() or trimmed_text.is_empty():
		return

	if not _sms_unlocked or not _sms_threads.has(resolved_contact):
		return

	_append_sms_message(resolved_contact, trimmed_text, true)
	_selected_sms_contact = resolved_contact
	_refresh_sms_view()
	sms_sent.emit(resolved_contact, trimmed_text)


func receive_sms(contact_name: String, text: String, avatar: Texture2D = null, auto_open := false) -> void:
	var resolved_contact := _normalize_contact_name(contact_name)
	var trimmed_text := text.strip_edges()

	if trimmed_text.is_empty():
		return

	_unlock_sms_for_contact(resolved_contact, avatar)
	_append_sms_message(resolved_contact, trimmed_text, false)
	_selected_sms_contact = resolved_contact
	_refresh_sms_view()
	sms_received.emit(resolved_contact, trimmed_text)

	if auto_open:
		open_phone()
		_switch_to_page(PhonePage.SMS)


func _initialize_layout() -> void:
	await get_tree().process_frame

	if not is_inside_tree():
		return

	_open_position = phone_shell.position
	_closed_position = _open_position + Vector2(0.0, phone_shell.size.y + CLOSED_OFFSET_Y)
	_layout_ready = true
	_apply_visibility_state(_requested_open, true)

	if _requested_open:
		phone_opened.emit()


func _build_header_row() -> void:
	_header_row = HBoxContainer.new()
	_header_row.name = "PhoneHeaderRow"
	_header_row.add_theme_constant_override("separation", 8)

	_back_button = Button.new()
	_back_button.text = "Назад"
	_back_button.custom_minimum_size = Vector2(76.0, 36.0)
	_back_button.text = "Назад"
	_apply_secondary_button_style(_back_button)
	_back_button.visible = false
	_back_button.pressed.connect(_on_back_button_pressed)
	_header_row.add_child(_back_button)

	_header_title_label = Label.new()
	_header_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_title_label.add_theme_font_size_override("font_size", 22)
	_header_title_label.add_theme_color_override("font_color", Color(0.082353, 0.117647, 0.176471, 1.0))
	_header_row.add_child(_header_title_label)

	var right_spacer := Control.new()
	right_spacer.custom_minimum_size = Vector2(76.0, 0.0)
	right_spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_row.add_child(right_spacer)

	layout.add_child(_header_row)
	layout.move_child(_header_row, 1)


func _build_home_page() -> void:
	_home_page = VBoxContainer.new()
	_home_page.name = "HomePage"
	_home_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_home_page.add_theme_constant_override("separation", 14)

	var hero_panel := PanelContainer.new()
	hero_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	_home_page.add_child(hero_panel)

	var hero_margin := MarginContainer.new()
	hero_margin.add_theme_constant_override("margin_left", 16)
	hero_margin.add_theme_constant_override("margin_top", 16)
	hero_margin.add_theme_constant_override("margin_right", 16)
	hero_margin.add_theme_constant_override("margin_bottom", 16)
	hero_panel.add_child(hero_margin)

	var hero_content := VBoxContainer.new()
	hero_content.add_theme_constant_override("separation", 6)
	hero_margin.add_child(hero_content)

	var title_label := Label.new()
	title_label.text = "Приложения"
	title_label.add_theme_font_size_override("font_size", 24)
	title_label.text = "Приложения"
	title_label.add_theme_color_override("font_color", Color(0.082353, 0.117647, 0.176471, 1.0))
	hero_content.add_child(title_label)

	_home_summary_label = Label.new()
	_home_summary_label.text = "Точка сейчас: Квартира"
	_home_summary_label.add_theme_font_size_override("font_size", 16)
	_home_summary_label.text = "Точка сейчас: Квартира"
	_home_summary_label.add_theme_color_override("font_color", Color(0.129412, 0.219608, 0.305882, 1.0))
	hero_content.add_child(_home_summary_label)

	var home_status_label := Label.new()
	home_status_label.text = "Пока нет контактов для сообщений"
	home_status_label.add_theme_font_size_override("font_size", 14)
	home_status_label.text = "Пока нет контактов для сообщений"
	home_status_label.add_theme_color_override("font_color", Color(0.25098, 0.333333, 0.403922, 1.0))
	home_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hero_content.add_child(home_status_label)
	_home_status_label = home_status_label

	_home_apps_grid = GridContainer.new()
	_home_apps_grid.columns = 1
	_home_apps_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_home_apps_grid.add_theme_constant_override("h_separation", 10)
	_home_apps_grid.add_theme_constant_override("v_separation", 10)
	_home_page.add_child(_home_apps_grid)

	_map_home_button = Button.new()
	_map_home_button.text = "Карта\nПереходы"
	_map_home_button.custom_minimum_size = Vector2(0.0, 92.0)
	_apply_primary_app_button_style(_map_home_button)
	_map_home_button.pressed.connect(_on_map_home_button_pressed)
	_home_apps_grid.add_child(_map_home_button)

	_sms_home_button = Button.new()
	_sms_home_button.text = "SMS\nКонтакты"
	_sms_home_button.custom_minimum_size = Vector2(0.0, 92.0)
	_apply_primary_app_button_style(_sms_home_button)
	_sms_home_button.visible = false
	_sms_home_button.pressed.connect(_on_sms_home_button_pressed)
	_home_apps_grid.add_child(_sms_home_button)

	var hint_panel := PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	_home_page.add_child(hint_panel)

	var hint_margin := MarginContainer.new()
	hint_margin.add_theme_constant_override("margin_left", 14)
	hint_margin.add_theme_constant_override("margin_top", 14)
	hint_margin.add_theme_constant_override("margin_right", 14)
	hint_margin.add_theme_constant_override("margin_bottom", 14)
	hint_panel.add_child(hint_margin)

	_home_hint_label = Label.new()
	_home_hint_label.text = DEFAULT_HOME_HINT
	_home_hint_label.add_theme_font_size_override("font_size", 14)
	_home_hint_label.add_theme_color_override("font_color", Color(0.25098, 0.333333, 0.403922, 1.0))
	_home_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_margin.add_child(_home_hint_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_home_page.add_child(spacer)

	content.add_child(_home_page)
	content.move_child(_home_page, 0)


func _build_map_page() -> void:
	_map_page = VBoxContainer.new()
	_map_page.name = "MapPage"
	_map_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map_page.add_theme_constant_override("separation", 12)
	_map_page.visible = false

	var current_location_panel := PanelContainer.new()
	current_location_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	_map_page.add_child(current_location_panel)

	var current_location_margin := MarginContainer.new()
	current_location_margin.add_theme_constant_override("margin_left", 14)
	current_location_margin.add_theme_constant_override("margin_top", 12)
	current_location_margin.add_theme_constant_override("margin_right", 14)
	current_location_margin.add_theme_constant_override("margin_bottom", 12)
	current_location_panel.add_child(current_location_margin)

	_map_location_label = Label.new()
	_map_location_label.text = "Сейчас: Квартира"
	_map_location_label.add_theme_font_size_override("font_size", 16)
	_map_location_label.add_theme_color_override("font_color", Color(0.129412, 0.219608, 0.305882, 1.0))
	current_location_margin.add_child(_map_location_label)

	var map_scroll := ScrollContainer.new()
	map_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_map_page.add_child(map_scroll)

	var map_content := VBoxContainer.new()
	map_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_content.add_theme_constant_override("separation", 12)
	map_scroll.add_child(map_content)

	var diagram_panel := PanelContainer.new()
	diagram_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	map_content.add_child(diagram_panel)

	var diagram_margin := MarginContainer.new()
	diagram_margin.add_theme_constant_override("margin_left", 12)
	diagram_margin.add_theme_constant_override("margin_top", 12)
	diagram_margin.add_theme_constant_override("margin_right", 12)
	diagram_margin.add_theme_constant_override("margin_bottom", 12)
	diagram_panel.add_child(diagram_margin)

	var diagram_center := CenterContainer.new()
	diagram_margin.add_child(diagram_center)

	_map_diagram_container = Control.new()
	_map_diagram_container.custom_minimum_size = Vector2(260.0, 198.0)
	_map_diagram_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	diagram_center.add_child(_map_diagram_container)

	var routes_panel := PanelContainer.new()
	routes_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	map_content.add_child(routes_panel)

	var routes_margin := MarginContainer.new()
	routes_margin.add_theme_constant_override("margin_left", 14)
	routes_margin.add_theme_constant_override("margin_top", 14)
	routes_margin.add_theme_constant_override("margin_right", 14)
	routes_margin.add_theme_constant_override("margin_bottom", 14)
	routes_panel.add_child(routes_margin)

	_map_routes_label = Label.new()
	_map_routes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_map_routes_label.add_theme_font_size_override("font_size", 13)
	_map_routes_label.add_theme_color_override("font_color", Color(0.25098, 0.333333, 0.403922, 1.0))
	routes_margin.add_child(_map_routes_label)

	content.add_child(_map_page)
	content.move_child(_map_page, 1)
	_build_map_diagram()


func _build_sms_page() -> void:
	_sms_page = VBoxContainer.new()
	_sms_page.name = "SmsPage"
	_sms_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sms_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sms_page.add_theme_constant_override("separation", 10)
	_sms_page.visible = false

	_sms_locked_panel = PanelContainer.new()
	_sms_locked_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	_sms_page.add_child(_sms_locked_panel)

	var locked_margin := MarginContainer.new()
	locked_margin.add_theme_constant_override("margin_left", 18)
	locked_margin.add_theme_constant_override("margin_top", 18)
	locked_margin.add_theme_constant_override("margin_right", 18)
	locked_margin.add_theme_constant_override("margin_bottom", 18)
	_sms_locked_panel.add_child(locked_margin)

	var locked_label := Label.new()
	locked_label.text = "SMS появятся после входящего звонка. Как только кто-то позвонит, контакт откроется здесь."
	locked_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	locked_label.add_theme_font_size_override("font_size", 16)
	locked_label.add_theme_color_override("font_color", Color(0.129412, 0.219608, 0.305882, 1.0))
	locked_margin.add_child(locked_label)

	_sms_content = VBoxContainer.new()
	_sms_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sms_content.add_theme_constant_override("separation", 10)
	_sms_page.add_child(_sms_content)

	var contacts_scroll := ScrollContainer.new()
	contacts_scroll.custom_minimum_size = Vector2(0.0, 46.0)
	contacts_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	contacts_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sms_content.add_child(contacts_scroll)

	_sms_contacts_container = HBoxContainer.new()
	_sms_contacts_container.add_theme_constant_override("separation", 8)
	contacts_scroll.add_child(_sms_contacts_container)

	_sms_selected_contact_label = Label.new()
	_sms_selected_contact_label.text = "Диалог: -"
	_sms_selected_contact_label.add_theme_font_size_override("font_size", 16)
	_sms_selected_contact_label.add_theme_color_override("font_color", Color(0.082353, 0.117647, 0.176471, 1.0))
	_sms_content.add_child(_sms_selected_contact_label)

	var messages_panel := PanelContainer.new()
	messages_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages_panel.add_theme_stylebox_override("panel", _create_soft_panel_style())
	_sms_content.add_child(messages_panel)

	var messages_margin := MarginContainer.new()
	messages_margin.add_theme_constant_override("margin_left", 12)
	messages_margin.add_theme_constant_override("margin_top", 12)
	messages_margin.add_theme_constant_override("margin_right", 12)
	messages_margin.add_theme_constant_override("margin_bottom", 12)
	messages_panel.add_child(messages_margin)

	_sms_messages_scroll = ScrollContainer.new()
	_sms_messages_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	messages_margin.add_child(_sms_messages_scroll)

	_sms_messages_container = VBoxContainer.new()
	_sms_messages_container.add_theme_constant_override("separation", 8)
	_sms_messages_scroll.add_child(_sms_messages_container)

	_sms_empty_label = Label.new()
	_sms_empty_label.text = "История пуста. Можно отправить первое сообщение."
	_sms_empty_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sms_empty_label.add_theme_font_size_override("font_size", 14)
	_sms_empty_label.add_theme_color_override("font_color", Color(0.25098, 0.333333, 0.403922, 1.0))
	messages_margin.add_child(_sms_empty_label)

	var composer_row := HBoxContainer.new()
	composer_row.add_theme_constant_override("separation", 8)
	_sms_content.add_child(composer_row)

	_sms_input = LineEdit.new()
	_sms_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_sms_input.placeholder_text = "Написать сообщение..."
	_sms_input.text_submitted.connect(_on_sms_input_text_submitted)
	composer_row.add_child(_sms_input)

	_sms_send_button = Button.new()
	_sms_send_button.text = "Отпр."
	_sms_send_button.custom_minimum_size = Vector2(84.0, 0.0)
	_apply_primary_app_button_style(_sms_send_button)
	_sms_send_button.pressed.connect(_on_sms_send_button_pressed)
	composer_row.add_child(_sms_send_button)

	_sms_helper_label = Label.new()
	_sms_helper_label.text = "Контакт открылся после звонка. Можно писать новые сообщения вручную."
	_sms_helper_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sms_helper_label.add_theme_font_size_override("font_size", 13)
	_sms_helper_label.add_theme_color_override("font_color", Color(0.25098, 0.333333, 0.403922, 1.0))
	_sms_content.add_child(_sms_helper_label)

	content.add_child(_sms_page)
	content.move_child(_sms_page, 2)


func _build_app_dock() -> void:
	_app_dock_row = HBoxContainer.new()
	_app_dock_row.name = "AppDockRow"
	_app_dock_row.add_theme_constant_override("separation", 8)
	_app_dock_row.visible = false

	_app_home_button = Button.new()
	_app_home_button.text = "Домой"
	_app_home_button.toggle_mode = true
	_apply_dock_button_style(_app_home_button)
	_app_home_button.pressed.connect(_on_app_home_button_pressed)
	_app_dock_row.add_child(_app_home_button)

	_app_map_button = Button.new()
	_app_map_button.text = "Карта"
	_app_map_button.toggle_mode = true
	_apply_dock_button_style(_app_map_button)
	_app_map_button.pressed.connect(_on_app_map_button_pressed)
	_app_dock_row.add_child(_app_map_button)

	_app_sms_button = Button.new()
	_app_sms_button.text = "SMS"
	_app_sms_button.toggle_mode = true
	_app_sms_button.visible = false
	_apply_dock_button_style(_app_sms_button)
	_app_sms_button.pressed.connect(_on_app_sms_button_pressed)
	_app_dock_row.add_child(_app_sms_button)

	content.add_child(_app_dock_row)
	content.move_child(_app_dock_row, content.get_child_count() - 2)


func _build_map_diagram() -> void:
	if _map_diagram_container == null:
		return

	_map_node_panels_by_scene.clear()

	for child in _map_diagram_container.get_children():
		_map_diagram_container.remove_child(child)
		child.queue_free()

	_create_map_line(Vector2(116.0, 31.0), Vector2(28.0, 4.0))
	_create_map_line(Vector2(194.0, 54.0), Vector2(4.0, 24.0))
	_create_map_line(Vector2(194.0, 120.0), Vector2(4.0, 24.0))
	_create_map_line(Vector2(116.0, 163.0), Vector2(28.0, 4.0))

	for scene_path in MAP_NODE_POSITIONS.keys():
		_create_map_node(scene_path, MAP_NODE_POSITIONS.get(scene_path, Vector2.ZERO))


func _create_map_line(position_value: Vector2, size_value: Vector2) -> void:
	var line := ColorRect.new()
	line.position = position_value
	line.size = size_value
	line.color = Color(0.188235, 0.305882, 0.427451, 0.34)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map_diagram_container.add_child(line)


func _create_map_node(scene_path: String, position_value: Vector2) -> void:
	var panel := PanelContainer.new()
	panel.position = position_value
	panel.size = MAP_NODE_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.offset_left = 8.0
	margin.offset_top = 6.0
	margin.offset_right = -8.0
	margin.offset_bottom = -6.0
	panel.add_child(margin)

	var label := Label.new()
	label.text = String(ROOM_DISPLAY_NAMES.get(scene_path, "Локация"))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(0.082353, 0.117647, 0.176471, 1.0))
	margin.add_child(label)

	_map_diagram_container.add_child(panel)
	_map_node_panels_by_scene[scene_path] = panel


func _apply_primary_app_button_style(button: Button) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_stylebox_override("normal", _create_button_style(Color(0.231373, 0.509804, 0.909804, 1.0)))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.266667, 0.552941, 0.952941, 1.0)))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.176471, 0.427451, 0.780392, 1.0)))
	button.add_theme_stylebox_override("focus", _create_button_style(Color(0.231373, 0.509804, 0.909804, 1.0)))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 18)


func _apply_dock_button_style(button: Button) -> void:
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.custom_minimum_size = Vector2(0.0, 42.0)
	button.add_theme_stylebox_override("normal", _create_button_style(Color(0.113725, 0.215686, 0.298039, 0.92), 18, Color(0.223529, 0.345098, 0.447059, 1.0), 1))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.145098, 0.266667, 0.364706, 0.96), 18, Color(0.223529, 0.345098, 0.447059, 1.0), 1))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.101961, 0.168627, 0.25098, 1.0), 18, Color(0.223529, 0.345098, 0.447059, 1.0), 1))
	button.add_theme_stylebox_override("focus", _create_button_style(Color(0.113725, 0.215686, 0.298039, 0.92), 18, Color(0.223529, 0.345098, 0.447059, 1.0), 1))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 17)


func _create_soft_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 1.0, 1.0, 0.92)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.243137, 0.364706, 0.458824, 0.24)
	style.corner_radius_top_left = 24
	style.corner_radius_top_right = 24
	style.corner_radius_bottom_right = 24
	style.corner_radius_bottom_left = 24
	return style


func _create_button_style(background: Color, radius := 18, border_color := Color(0.0, 0.0, 0.0, 0.0), border_width := 0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius

	if border_width > 0:
		style.border_width_left = border_width
		style.border_width_top = border_width
		style.border_width_right = border_width
		style.border_width_bottom = border_width
		style.border_color = border_color

	return style


func _apply_secondary_button_style(button: Button) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(Color(0.141176, 0.192157, 0.294118, 1.0), 18, Color(0.25098, 0.364706, 0.486275, 1.0), 2))
	button.add_theme_stylebox_override("hover", _create_button_style(Color(0.172549, 0.239216, 0.34902, 1.0), 18, Color(0.286275, 0.411765, 0.533333, 1.0), 2))
	button.add_theme_stylebox_override("pressed", _create_button_style(Color(0.101961, 0.145098, 0.231373, 1.0), 18, Color(0.219608, 0.333333, 0.454902, 1.0), 2))
	button.add_theme_stylebox_override("focus", _create_button_style(Color(0.141176, 0.192157, 0.294118, 1.0), 18, Color(0.25098, 0.364706, 0.486275, 1.0), 2))
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_focus_color", Color.WHITE)
	button.add_theme_font_size_override("font_size", 16)


func _apply_sms_contact_button_style(button: Button, is_selected: bool) -> void:
	var background := Color(0.231373, 0.509804, 0.909804, 1.0) if is_selected else Color(1.0, 1.0, 1.0, 0.94)
	var border := Color(0.231373, 0.509804, 0.909804, 1.0) if is_selected else Color(0.25098, 0.364706, 0.486275, 0.22)
	button.add_theme_stylebox_override("normal", _create_button_style(background, 18, border, 2))
	button.add_theme_stylebox_override("hover", _create_button_style(background.lightened(0.08), 18, border, 2))
	button.add_theme_stylebox_override("pressed", _create_button_style(background.darkened(0.08), 18, border, 2))
	button.add_theme_stylebox_override("focus", _create_button_style(background, 18, border, 2))
	button.add_theme_color_override("font_color", Color.WHITE if is_selected else Color(0.082353, 0.117647, 0.176471, 1.0))
	button.add_theme_color_override("font_hover_color", Color.WHITE if is_selected else Color(0.082353, 0.117647, 0.176471, 1.0))
	button.add_theme_color_override("font_pressed_color", Color.WHITE if is_selected else Color(0.082353, 0.117647, 0.176471, 1.0))


func _refresh_view() -> void:
	_update_status_bar_text()
	_refresh_header()
	_refresh_pages_visibility()
	_refresh_home_view()
	_refresh_map_view()
	_refresh_sms_view()
	_refresh_avatar()
	_refresh_content_text()
	_refresh_timer_label()
	_refresh_buttons()


func _refresh_header() -> void:
	if _header_title_label == null:
		return

	_header_title_label.text = _resolve_page_title()
	_back_button.visible = _should_show_back_button()
	_back_button.disabled = not _back_button.visible


func _refresh_pages_visibility() -> void:
	var call_page_visible := _selected_page == PhonePage.CALL
	var app_page_visible := not call_page_visible

	avatar_center.visible = call_page_visible
	name_label.visible = call_page_visible
	call_status_label.visible = call_page_visible
	conversation_label.visible = call_page_visible
	timer_label.get_parent().get_parent().visible = call_page_visible
	dialogue_text_label.get_parent().get_parent().visible = call_page_visible
	content_spacer.visible = call_page_visible
	bottom_indicator_center.visible = call_page_visible
	_home_page.visible = app_page_visible and _selected_page == PhonePage.HOME
	_map_page.visible = app_page_visible and _selected_page == PhonePage.MAP
	_sms_page.visible = app_page_visible and _selected_page == PhonePage.SMS
	_app_dock_row.visible = app_page_visible


func _refresh_home_view() -> void:
	if _home_page == null:
		return

	var location_name := _get_room_display_name(_resolve_current_room_scene_path())
	_home_summary_label.text = "Точка сейчас: %s" % location_name

	if _sms_unlocked:
		_home_status_label.text = "Последний контакт: %s" % _selected_sms_contact
		_home_hint_label.text = "SMS разблокированы. Можно открыть переписку и писать этому контакту."
	else:
		_home_status_label.text = "Пока нет контактов для сообщений"
		_home_hint_label.text = DEFAULT_HOME_HINT

	_home_apps_grid.columns = 2 if _sms_unlocked else 1
	_sms_home_button.visible = _sms_unlocked


func _refresh_map_view() -> void:
	if _map_page == null:
		return

	var current_scene_path := _resolve_current_room_scene_path()
	_map_location_label.text = "Сейчас: %s" % _get_room_display_name(current_scene_path)
	_map_routes_label.text = _build_routes_text()

	for scene_path in _map_node_panels_by_scene.keys():
		var panel := _map_node_panels_by_scene.get(scene_path) as PanelContainer

		if panel == null:
			continue

		panel.add_theme_stylebox_override("panel", _create_map_node_style(scene_path == current_scene_path))


func _refresh_sms_view() -> void:
	if _sms_page == null:
		return

	_sms_locked_panel.visible = not _sms_unlocked
	_sms_content.visible = _sms_unlocked
	_app_sms_button.visible = _sms_unlocked

	if not _sms_unlocked:
		return

	if _selected_sms_contact.is_empty() and not _sms_contact_order.is_empty():
		_selected_sms_contact = _sms_contact_order[0]

	_refresh_sms_contacts()
	_refresh_sms_messages()
	_sms_selected_contact_label.text = "Диалог: %s" % _selected_sms_contact
	_sms_helper_label.text = "Контакт открылся после звонка. Можно писать новые сообщения вручную."


func _refresh_avatar() -> void:
	avatar_texture.texture = _current_avatar
	avatar_texture.visible = _current_avatar != null
	avatar_initials.visible = _current_avatar == null
	avatar_initials.text = _build_contact_initials(_current_contact_name)


func _refresh_content_text() -> void:
	name_label.text = _current_contact_name
	call_status_label.text = _resolve_call_status_text()
	conversation_label.text = _resolve_conversation_text()
	conversation_label.visible = not conversation_label.text.is_empty()
	# This label is the future hook for branching phone dialogue and subtitles.
	dialogue_text_label.text = _resolve_dialogue_preview_text()


func _refresh_timer_label() -> void:
	timer_label.text = "%02d:%02d" % [int(_call_duration_seconds / 60.0), _call_duration_seconds % 60]


func _refresh_buttons() -> void:
	if _selected_page != PhonePage.CALL:
		buttons_row.visible = false
		accept_button.visible = false
		end_button.visible = false
		_app_home_button.set_pressed_no_signal(_selected_page == PhonePage.HOME)
		_app_map_button.set_pressed_no_signal(_selected_page == PhonePage.MAP)
		_app_sms_button.set_pressed_no_signal(_selected_page == PhonePage.SMS)
		return

	buttons_row.visible = true
	accept_button.visible = _call_state == CallState.INCOMING
	accept_button.disabled = _call_state != CallState.INCOMING

	match _call_state:
		CallState.INCOMING:
			end_button.text = "Сбросить"
		CallState.ACTIVE:
			end_button.text = "Завершить"
		CallState.ENDED:
			end_button.text = "Закрыть"
		_:
			end_button.text = "Скрыть"


func _refresh_sms_contacts() -> void:
	for child in _sms_contacts_container.get_children():
		_sms_contacts_container.remove_child(child)
		child.queue_free()

	for contact_name in _sms_contact_order:
		var button := Button.new()
		button.text = contact_name
		button.toggle_mode = true
		button.custom_minimum_size = Vector2(100.0, 38.0)
		button.set_pressed_no_signal(contact_name == _selected_sms_contact)
		_apply_sms_contact_button_style(button, contact_name == _selected_sms_contact)
		button.pressed.connect(_on_sms_contact_button_pressed.bind(contact_name))
		_sms_contacts_container.add_child(button)


func _refresh_sms_messages() -> void:
	for child in _sms_messages_container.get_children():
		_sms_messages_container.remove_child(child)
		child.queue_free()

	var thread: Array = []

	if _sms_threads.has(_selected_sms_contact):
		thread = _sms_threads.get(_selected_sms_contact, [])

	_sms_empty_label.visible = thread.is_empty()

	for message_data in thread:
		if not (message_data is Dictionary):
			continue

		var row := _build_sms_message_row(message_data)
		_sms_messages_container.add_child(row)

	call_deferred("_scroll_sms_to_bottom")


func _build_sms_message_row(message_data: Dictionary) -> HBoxContainer:
	var is_player_message := bool(message_data.get("is_player", false))
	var message_text := String(message_data.get("text", "")).strip_edges()
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var bubble := PanelContainer.new()
	bubble.custom_minimum_size = Vector2(0.0, 42.0)
	bubble.size_flags_horizontal = Control.SIZE_SHRINK_END
	bubble.add_theme_stylebox_override("panel", _create_sms_bubble_style(is_player_message))

	var bubble_margin := MarginContainer.new()
	bubble_margin.add_theme_constant_override("margin_left", 12)
	bubble_margin.add_theme_constant_override("margin_top", 10)
	bubble_margin.add_theme_constant_override("margin_right", 12)
	bubble_margin.add_theme_constant_override("margin_bottom", 10)
	bubble.add_child(bubble_margin)

	var bubble_label := Label.new()
	bubble_label.text = message_text
	bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble_label.custom_minimum_size = Vector2(0.0, 24.0)
	bubble_label.add_theme_font_size_override("font_size", 15)
	bubble_label.add_theme_color_override("font_color", Color.WHITE if is_player_message else Color(0.082353, 0.117647, 0.176471, 1.0))
	bubble_margin.add_child(bubble_label)

	if is_player_message:
		row.add_child(spacer)
		row.add_child(bubble)
	else:
		row.add_child(bubble)
		row.add_child(spacer)

	return row


func _scroll_sms_to_bottom() -> void:
	if _sms_messages_scroll == null:
		return

	await get_tree().process_frame

	if not is_instance_valid(_sms_messages_scroll):
		return

	var scrollbar := _sms_messages_scroll.get_v_scroll_bar()

	if scrollbar == null:
		return

	_sms_messages_scroll.scroll_vertical = int(scrollbar.max_value)


func _build_routes_text() -> String:
	var grouped_routes: Dictionary = {}
	var route_order: Array[String] = []

	for connection in ROOM_CONNECTIONS:
		var from_scene := String(connection.get("from", ""))
		var to_name := _get_room_display_name(String(connection.get("to", "")))

		if not grouped_routes.has(from_scene):
			grouped_routes[from_scene] = []
			route_order.append(from_scene)

		var exits: Array = grouped_routes.get(from_scene, [])
		exits.append(to_name)
		grouped_routes[from_scene] = exits

	var route_lines: Array[String] = []

	for from_scene in route_order:
		var exits: Array = grouped_routes.get(from_scene, [])
		var exit_names := PackedStringArray()

		for exit_name in exits:
			exit_names.append(String(exit_name))

		route_lines.append("- %s -> %s" % [_get_room_display_name(from_scene), ", ".join(exit_names)])

	return "\n".join(route_lines)


func _get_room_display_name(scene_path: String) -> String:
	if ROOM_DISPLAY_NAMES.has(scene_path):
		return String(ROOM_DISPLAY_NAMES.get(scene_path, "Локация"))

	if scene_path.is_empty():
		return "Неизвестно"

	return scene_path.get_file().get_basename()


func _resolve_current_room_scene_path() -> String:
	var game_manager := get_node_or_null("/root/GameManager")

	if game_manager != null and game_manager.has_method("get_current_room_scene_path"):
		return String(game_manager.get_current_room_scene_path())

	return ""


func _switch_to_page(target_page: int, force := false) -> void:
	if not force and (_call_state == CallState.INCOMING or _call_state == CallState.ACTIVE) and target_page != PhonePage.CALL:
		return

	if _selected_page == PhonePage.CALL and target_page != PhonePage.CALL and _call_state == CallState.ENDED:
		_call_state = CallState.IDLE

	_selected_page = target_page
	_refresh_view()


func _resolve_page_title() -> String:
	match _selected_page:
		PhonePage.CALL:
			return "Звонок"
		PhonePage.MAP:
			return "Карта"
		PhonePage.SMS:
			return "SMS"
		_:
			return "Телефон"


func _should_show_back_button() -> bool:
	if _call_state == CallState.INCOMING or _call_state == CallState.ACTIVE:
		return false

	return _selected_page != PhonePage.HOME


func _restore_page_after_call() -> int:
	return _page_before_call if _page_before_call != PhonePage.CALL else PhonePage.HOME


func _unlock_sms_for_contact(contact_name: String, avatar: Texture2D = null) -> void:
	var resolved_contact := _normalize_contact_name(contact_name)
	var is_new_contact := not _sms_threads.has(resolved_contact)
	_sms_unlocked = true

	if is_new_contact:
		_sms_threads[resolved_contact] = []
		_sms_contact_order.append(resolved_contact)
		sms_unlocked.emit(resolved_contact)

	if avatar != null:
		_contact_avatars[resolved_contact] = avatar

	if _selected_sms_contact.is_empty():
		_selected_sms_contact = resolved_contact


func _append_sms_message(contact_name: String, text: String, is_player_message: bool) -> void:
	if not _sms_threads.has(contact_name):
		_sms_threads[contact_name] = []

	var thread: Array = _sms_threads.get(contact_name, [])
	thread.append({
		"text": text.strip_edges(),
		"is_player": is_player_message,
	})
	_sms_threads[contact_name] = thread


func _update_status_bar_text() -> void:
	signal_label.text = "LTE"
	battery_label.text = "96%"
	time_label.text = _resolve_phone_time_text()


func _apply_visibility_state(should_open: bool, instant: bool) -> void:
	if should_open:
		_is_open = true
		_set_phone_interaction_enabled(true)
		_animate_visibility(_open_position, 1.0, instant)
		return

	_is_open = false
	_set_phone_interaction_enabled(false)
	_animate_visibility(_closed_position, 0.0, instant)


func _animate_visibility(target_position: Vector2, target_alpha: float, instant: bool) -> void:
	if _transition_tween != null and is_instance_valid(_transition_tween):
		_transition_tween.kill()

	if instant:
		phone_shell.position = target_position
		phone_shell.modulate.a = target_alpha
		return

	_transition_tween = create_tween()
	_transition_tween.set_parallel(true)
	_transition_tween.set_trans(Tween.TRANS_CUBIC)
	_transition_tween.set_ease(Tween.EASE_OUT)
	_transition_tween.tween_property(phone_shell, "position", target_position, OPEN_TRANSITION_DURATION)
	_transition_tween.tween_property(phone_shell, "modulate:a", target_alpha, OPEN_TRANSITION_DURATION - 0.04)


func _set_phone_interaction_enabled(is_enabled: bool) -> void:
	phone_shell.mouse_filter = Control.MOUSE_FILTER_STOP if is_enabled else Control.MOUSE_FILTER_IGNORE


func _resolve_call_status_text() -> String:
	match _call_state:
		CallState.INCOMING:
			return DEFAULT_INCOMING_STATUS
		CallState.ACTIVE:
			return DEFAULT_ACTIVE_STATUS
		CallState.ENDED:
			return DEFAULT_ENDED_STATUS
		_:
			return DEFAULT_IDLE_STATUS


func _resolve_conversation_text() -> String:
	if _current_conversation_id.is_empty():
		return "Контакт в телефоне"

	return "Диалог: %s" % _current_conversation_id


func _resolve_dialogue_preview_text() -> String:
	if not _current_dialogue_text.is_empty():
		return _current_dialogue_text

	match _call_state:
		CallState.INCOMING:
			return "Ответьте на звонок, чтобы запустить реплики и субтитры."
		CallState.ACTIVE:
			return DEFAULT_DIALOGUE_PREVIEW
		CallState.ENDED:
			return "Линия закрыта. Здесь можно оставить итог разговора или следующую реплику."
		_:
			return "Телефон готов. Здесь позже можно запускать телефонные диалоги, реплики и ветки."


func _resolve_phone_time_text() -> String:
	var game_time_node := get_node_or_null("/root/GameTime")

	if game_time_node != null and game_time_node.has_method("get_current_time_data"):
		var time_data: Dictionary = game_time_node.get_current_time_data()
		return "%02d:%02d" % [
			int(time_data.get("hours", 0)),
			int(time_data.get("minutes", 0)),
		]

	var time_text := Time.get_time_string_from_system()

	if time_text.length() >= 5:
		return time_text.substr(0, 5)

	return time_text


func _build_contact_initials(contact_name: String) -> String:
	var cleaned_name := _normalize_contact_name(contact_name)
	var parts := cleaned_name.split(" ", false)
	var initials := ""

	for part in parts:
		if part.is_empty():
			continue

		initials += part.substr(0, 1).to_upper()

		if initials.length() >= 2:
			break

	if initials.is_empty():
		return "?"

	return initials


func _normalize_contact_name(contact_name: String) -> String:
	var trimmed_name := contact_name.strip_edges()
	return trimmed_name if not trimmed_name.is_empty() else DEFAULT_CONTACT_NAME


func _create_map_node_style(is_current: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.992157, 0.784314, 0.301961, 1.0) if is_current else Color(1.0, 1.0, 1.0, 0.94)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.164706, 0.270588, 0.360784, 1.0) if is_current else Color(0.188235, 0.305882, 0.427451, 0.32)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style


func _create_sms_bubble_style(is_player_message: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.180392, 0.462745, 0.807843, 0.94) if is_player_message else Color(1.0, 1.0, 1.0, 0.94)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.164706, 0.270588, 0.360784, 0.2)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	return style


func _on_back_button_pressed() -> void:
	if _selected_page == PhonePage.CALL and _call_state == CallState.ENDED:
		_call_state = CallState.IDLE
		_switch_to_page(_restore_page_after_call(), true)
		return

	_switch_to_page(PhonePage.HOME, true)


func _on_map_home_button_pressed() -> void:
	_switch_to_page(PhonePage.MAP)


func _on_sms_home_button_pressed() -> void:
	_switch_to_page(PhonePage.SMS)


func _on_app_home_button_pressed() -> void:
	_switch_to_page(PhonePage.HOME)


func _on_app_map_button_pressed() -> void:
	_switch_to_page(PhonePage.MAP)


func _on_app_sms_button_pressed() -> void:
	_switch_to_page(PhonePage.SMS)


func _on_sms_send_button_pressed() -> void:
	send_sms(_selected_sms_contact, _sms_input.text)
	_sms_input.clear()


func _on_sms_input_text_submitted(new_text: String) -> void:
	send_sms(_selected_sms_contact, new_text)
	_sms_input.clear()


func _on_sms_contact_button_pressed(contact_name: String) -> void:
	_selected_sms_contact = contact_name
	_refresh_sms_view()


func _on_status_clock_timer_timeout() -> void:
	_update_status_bar_text()


func _on_call_duration_timer_timeout() -> void:
	_call_duration_seconds += 1
	_refresh_timer_label()


func _on_post_end_timer_timeout() -> void:
	if _auto_close_after_end:
		close_phone()


func _on_accept_button_pressed() -> void:
	accept_call()


func _on_end_button_pressed() -> void:
	if _call_state == CallState.ENDED or _call_state == CallState.IDLE:
		_call_state = CallState.IDLE
		_switch_to_page(_restore_page_after_call(), true)
		return

	end_call()
