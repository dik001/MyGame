extends Control

const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const SLITHARIO_SCENE_PATH := "res://scenes/minigames/slithario.tscn"
const FREELANCE_APP_SCENE_PATH := "res://scenes/freelance/FreelanceAppWindow.tscn"
const BANK_APP_SCENE_PATH := "res://scenes/freelance/BankAppWindow.tscn"
const LECHAT_APP_SCENE_PATH := "res://scenes/apps/LeChatWindow.tscn"
const CALENDAR_APP_SCENE_PATH := "res://scenes/apps/CalendarWindow.tscn"
const MODERATION_MINIGAME_SCENE_PATH := "res://scenes/freelance/ModerationMinigameUI.tscn"
const INFO_WINDOW_SCENE_PATH := "res://scenes/freelance/DesktopInfoWindow.tscn"

const WINDOW_KEY_SHOP: StringName = &"shop"
const WINDOW_KEY_DELIVERY: StringName = &"delivery"
const WINDOW_KEY_FREELANCE: StringName = &"freelance"
const WINDOW_KEY_BANK: StringName = &"bank"
const WINDOW_KEY_LECHAT: StringName = &"lechat"
const WINDOW_KEY_CALENDAR: StringName = &"calendar"
const WINDOW_KEY_MODERATION: StringName = &"moderation"
const WINDOW_KEY_PLACEHOLDER: StringName = &"placeholder"

const COLOR_WIDGET_NEUTRAL := Color(0.82, 0.88, 0.97, 1.0)
const COLOR_WIDGET_SOON := Color(0.96, 0.90, 0.63, 1.0)
const COLOR_WIDGET_DUE := Color(1.0, 0.79, 0.46, 1.0)
const COLOR_WIDGET_OVERDUE := Color(1.0, 0.58, 0.58, 1.0)
const FULLSCREEN_APP_BACKDROP_COLOR := Color(0.0156863, 0.0392157, 0.0705882, 1.0)

@onready var desktop_home_layer: Control = $DesktopRoot/DesktopHomeLayer
@onready var slithario_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/SlitharioShortcut/SlitharioIconButton
@onready var shop_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/ShopShortcut/ShopIconButton
@onready var delivery_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/DeliveryShortcut/DeliveryIconButton
@onready var freelance_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/FreelanceShortcut/FreelanceIconButton
@onready var bank_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/BankShortcut/BankIconButton
@onready var lechat_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/LeChatShortcut/LeChatIconButton
@onready var calendar_button: TextureButton = $DesktopRoot/DesktopHomeLayer/ShortcutLayer/CalendarShortcut/CalendarIconButton
@onready var fullscreen_app_layer: Control = $DesktopRoot/FullscreenAppLayer
@onready var app_backdrop: ColorRect = $DesktopRoot/FullscreenAppLayer/AppBackdrop
@onready var app_host: Control = $DesktopRoot/FullscreenAppLayer/AppHost
@onready var shop_window: Control = $DesktopRoot/FullscreenAppLayer/AppHost/ShopWindow
@onready var delivery_tracker_window: Control = $DesktopRoot/FullscreenAppLayer/AppHost/DeliveryTrackerWindow
@onready var desktop_day_time_label: Label = $DesktopRoot/DesktopHomeLayer/DesktopStatusWidget/MarginContainer/Content/DayTimeLabel
@onready var desktop_rent_due_label: Label = $DesktopRoot/DesktopHomeLayer/DesktopStatusWidget/MarginContainer/Content/RentDueLabel
@onready var desktop_rent_status_label: Label = $DesktopRoot/DesktopHomeLayer/DesktopStatusWidget/MarginContainer/Content/RentStatusLabel

var _window_instances: Dictionary = {}
var _last_moderation_session_result: Dictionary = {}
var _placeholder_return_target: StringName = &""
var _current_window_key: StringName = &""
var _rent_state: Node = null


func _ready() -> void:
	if app_backdrop != null:
		app_backdrop.color = FULLSCREEN_APP_BACKDROP_COLOR

	if not slithario_button.pressed.is_connected(_on_slithario_icon_button_pressed):
		slithario_button.pressed.connect(_on_slithario_icon_button_pressed)

	if not shop_button.pressed.is_connected(_on_shop_button_pressed):
		shop_button.pressed.connect(_on_shop_button_pressed)

	if not delivery_button.pressed.is_connected(_on_delivery_button_pressed):
		delivery_button.pressed.connect(_on_delivery_button_pressed)

	if not freelance_button.pressed.is_connected(_on_freelance_button_pressed):
		freelance_button.pressed.connect(_on_freelance_button_pressed)

	if not bank_button.pressed.is_connected(_on_bank_button_pressed):
		bank_button.pressed.connect(_on_bank_button_pressed)

	if not lechat_button.pressed.is_connected(_on_lechat_button_pressed):
		lechat_button.pressed.connect(_on_lechat_button_pressed)

	if not calendar_button.pressed.is_connected(_on_calendar_button_pressed):
		calendar_button.pressed.connect(_on_calendar_button_pressed)

	_register_existing_window(WINDOW_KEY_SHOP, shop_window)
	_register_existing_window(WINDOW_KEY_DELIVERY, delivery_tracker_window)
	_connect_desktop_widget_signals()
	_refresh_desktop_widget()
	_close_all_windows()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport: Viewport = get_viewport()

		if _has_open_window():
			if viewport != null:
				viewport.set_input_as_handled()

			_close_current_fullscreen_app()
			return

		if viewport != null:
			viewport.set_input_as_handled()

		_change_scene_to_file_safe(GAME_SCENE_PATH)


func _on_slithario_icon_button_pressed() -> void:
	if not _change_scene_to_file_safe(SLITHARIO_SCENE_PATH):
		_show_placeholder("Slithario", "Игра сейчас недоступна.")


func _on_shop_button_pressed() -> void:
	_open_registered_window(WINDOW_KEY_SHOP)


func _on_delivery_button_pressed() -> void:
	_open_registered_window(WINDOW_KEY_DELIVERY)


func _on_freelance_button_pressed() -> void:
	_open_freelance_app()


func _on_bank_button_pressed() -> void:
	_open_bank_app()


func _on_lechat_button_pressed() -> void:
	_open_lechat()


func _on_calendar_button_pressed() -> void:
	_open_calendar()


func _close_all_windows() -> void:
	_placeholder_return_target = &""
	_hide_all_desktop_windows()


func _close_current_fullscreen_app() -> void:
	var visible_window_key: StringName = _current_window_key

	if String(visible_window_key).is_empty():
		visible_window_key = _get_top_visible_window_key()

	if String(visible_window_key).is_empty():
		return

	_on_window_close_requested(visible_window_key)


func _has_open_window() -> bool:
	for window_variant in _window_instances.values():
		var window: Control = window_variant as Control

		if window != null and is_instance_valid(window) and window.visible:
			return true

	return false


func get_last_moderation_session_result() -> Dictionary:
	return _last_moderation_session_result.duplicate(true)


func _register_existing_window(key: StringName, window: Control) -> void:
	if window == null:
		return

	_prepare_app_for_fullscreen(window)
	_window_instances[key] = window
	_connect_window_signals(window, key)


func _open_registered_window(key: StringName) -> void:
	var window: Control = _get_window_instance(key)

	if window == null:
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(key)
	_show_window(window, key)


func _open_freelance_app() -> void:
	var window: Control = _open_or_focus_app(
		FREELANCE_APP_SCENE_PATH,
		WINDOW_KEY_FREELANCE,
		"Фриланс",
		"Приложение пока не установлено."
	)

	if window == null:
		return

	_refresh_freelance_app(window)


func _open_bank_app() -> void:
	_open_or_focus_app(
		BANK_APP_SCENE_PATH,
		WINDOW_KEY_BANK,
		"Банк",
		"Приложение пока не установлено."
	)


func _open_lechat() -> void:
	_open_or_focus_app(
		LECHAT_APP_SCENE_PATH,
		WINDOW_KEY_LECHAT,
		"LeChat",
		"Приложение LeChat пока не установлено."
	)


func _open_calendar() -> void:
	_open_or_focus_app(
		CALENDAR_APP_SCENE_PATH,
		WINDOW_KEY_CALENDAR,
		"Календарь",
		"Приложение календаря пока не установлено."
	)


func _open_or_focus_app(
	scene_path: String,
	key: StringName,
	placeholder_title: String,
	placeholder_message: String
) -> Control:
	var window: Control = _open_fullscreen_app(scene_path, key)

	if window == null:
		_show_placeholder(placeholder_title, placeholder_message)
		return null

	_refresh_window_if_supported(window)
	return window


func _open_moderation_minigame(order_id: int) -> void:
	var minigame_window: Control = _ensure_scene_window_instance(MODERATION_MINIGAME_SCENE_PATH, WINDOW_KEY_MODERATION)

	if minigame_window == null:
		_show_placeholder("Модерация", "Режим модерации пока не установлен.", WINDOW_KEY_FREELANCE)
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(WINDOW_KEY_MODERATION)
	_show_window(minigame_window, WINDOW_KEY_MODERATION)

	if minigame_window.has_method("start_for_order"):
		minigame_window.call("start_for_order", order_id)


func _open_fullscreen_app(scene_path: String, key: StringName) -> Control:
	var window: Control = _ensure_scene_window_instance(scene_path, key)

	if window == null:
		return null

	_placeholder_return_target = &""
	_hide_all_desktop_windows(key)
	_show_window(window, key)
	return window


func _ensure_scene_window_instance(scene_path: String, key: StringName) -> Control:
	var existing_window: Control = _get_window_instance(key)

	if existing_window != null:
		_prepare_app_for_fullscreen(existing_window)
		return existing_window

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		return null

	var scene_resource: PackedScene = load(scene_path) as PackedScene

	if scene_resource == null:
		return null

	var instance: Node = scene_resource.instantiate()
	var window: Control = instance as Control

	if window == null:
		if instance != null:
			instance.queue_free()

		return null

	window.visible = false
	app_host.add_child(window)
	_prepare_app_for_fullscreen(window)
	_window_instances[key] = window
	_connect_window_signals(window, key)
	return window


func _prepare_app_for_fullscreen(app: Control) -> void:
	if app == null:
		return

	if app_host != null and app.get_parent() != app_host:
		var current_parent: Node = app.get_parent()

		if current_parent != null:
			current_parent.remove_child(app)

		app_host.add_child(app)
	app.set_anchors_preset(Control.PRESET_FULL_RECT)
	app.anchor_left = 0.0
	app.anchor_top = 0.0
	app.anchor_right = 1.0
	app.anchor_bottom = 1.0
	app.offset_left = 0.0
	app.offset_top = 0.0
	app.offset_right = 0.0
	app.offset_bottom = 0.0
	app.grow_horizontal = Control.GROW_DIRECTION_BOTH
	app.grow_vertical = Control.GROW_DIRECTION_BOTH
	app.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	app.size_flags_vertical = Control.SIZE_EXPAND_FILL
	app.mouse_filter = Control.MOUSE_FILTER_PASS


func _refresh_window_if_supported(window: Control) -> void:
	if window == null:
		return

	if window.has_method("refresh"):
		window.call("refresh")
	elif window.has_method("refresh_view"):
		window.call("refresh_view")


func _show_placeholder(title: String, message: String, return_target: StringName = &"") -> void:
	var placeholder_window: Control = _ensure_scene_window_instance(INFO_WINDOW_SCENE_PATH, WINDOW_KEY_PLACEHOLDER)

	if placeholder_window == null:
		push_warning("DesktopInfoWindow scene is missing. Could not show placeholder.")
		return

	_placeholder_return_target = return_target
	_hide_all_desktop_windows(WINDOW_KEY_PLACEHOLDER)
	_hide_desktop_home()

	if placeholder_window.has_method("set_content"):
		placeholder_window.call("set_content", title, message)

	if placeholder_window.has_method("open_window"):
		placeholder_window.call("open_window", title, message)
	else:
		placeholder_window.visible = true
		placeholder_window.move_to_front()

	_current_window_key = WINDOW_KEY_PLACEHOLDER
	_sync_desktop_layers()


func _hide_all_desktop_windows(except_key: StringName = &"") -> void:
	for key_variant in _window_instances.keys():
		var key: StringName = StringName(key_variant)
		var window: Control = _get_window_instance(key)

		if window == null:
			continue

		if not String(except_key).is_empty() and key == except_key:
			continue

		_hide_window_immediate(window)

	if except_key != WINDOW_KEY_PLACEHOLDER:
		_placeholder_return_target = &""

	_current_window_key = _get_top_visible_window_key()
	_sync_desktop_layers()


func _show_window(window: Control, key: StringName = &"") -> void:
	if window == null:
		return

	_prepare_app_for_fullscreen(window)
	_hide_desktop_home()
	window.move_to_front()

	if window.has_method("open_window"):
		window.call("open_window")
	else:
		window.visible = true

	if String(key).is_empty():
		_current_window_key = _find_window_key(window)
	else:
		_current_window_key = key

	_sync_desktop_layers()


func _hide_window(window: Control) -> void:
	if window == null:
		return

	_hide_window_immediate(window)
	_current_window_key = _get_top_visible_window_key()
	_sync_desktop_layers()


func _hide_window_immediate(window: Control) -> void:
	if window == null:
		return

	if window.has_method("close_window"):
		window.call("close_window")
	else:
		window.visible = false


func _show_desktop_home() -> void:
	_current_window_key = &""

	if desktop_home_layer != null:
		desktop_home_layer.visible = true

	if fullscreen_app_layer != null:
		fullscreen_app_layer.visible = false

	if app_backdrop != null:
		app_backdrop.visible = false

	if app_host != null:
		app_host.visible = false


func _hide_desktop_home() -> void:
	if desktop_home_layer != null:
		desktop_home_layer.visible = false

	if fullscreen_app_layer != null:
		fullscreen_app_layer.visible = true

	if app_backdrop != null:
		app_backdrop.visible = true

	if app_host != null:
		app_host.visible = true


func _sync_desktop_layers() -> void:
	if _has_open_window():
		_hide_desktop_home()
	else:
		_show_desktop_home()


func _get_window_instance(key: StringName) -> Control:
	if not _window_instances.has(key):
		return null

	var window: Control = _window_instances[key] as Control

	if window != null and is_instance_valid(window):
		return window

	_window_instances.erase(key)
	return null


func _find_window_key(window: Control) -> StringName:
	if window == null:
		return &""

	for key_variant in _window_instances.keys():
		var key: StringName = StringName(key_variant)

		if _get_window_instance(key) == window:
			return key

	return &""


func _get_top_visible_window_key() -> StringName:
	if app_host != null:
		var children: Array = app_host.get_children()

		for child_index in range(children.size() - 1, -1, -1):
			var child: Control = children[child_index] as Control

			if child == null or not child.visible:
				continue

			return _find_window_key(child)

	for key_variant in _window_instances.keys():
		var key: StringName = StringName(key_variant)
		var window: Control = _get_window_instance(key)

		if window != null and window.visible:
			return key

	return &""


func _connect_window_signals(window: Node, key: StringName) -> void:
	_connect_optional_signal(window, &"close_requested", Callable(self, "_on_window_close_requested").bind(key))
	_connect_optional_signal(window, &"return_to_desktop", Callable(self, "_on_window_close_requested").bind(key))
	_connect_optional_signal(window, &"return_to_desktop_requested", Callable(self, "_on_window_close_requested").bind(key))

	match key:
		WINDOW_KEY_FREELANCE:
			_connect_optional_signal(window, &"request_start_order", Callable(self, "_on_freelance_request_start_order"))
		WINDOW_KEY_MODERATION:
			_connect_optional_signal(window, &"return_to_freelance_requested", Callable(self, "_on_moderation_return_to_freelance_requested"))
			_connect_optional_signal(window, &"session_finished", Callable(self, "_on_moderation_session_finished"))


func _connect_optional_signal(window: Node, signal_name: StringName, callable: Callable) -> void:
	if not window.has_signal(signal_name):
		return

	if window.is_connected(signal_name, callable):
		return

	window.connect(signal_name, callable)


func _change_scene_to_file_safe(scene_path: String) -> bool:
	if scene_path.is_empty():
		return false

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("Desktop could not change scene because it is missing: %s" % scene_path)
		return false

	get_tree().change_scene_to_file(scene_path)
	return true


func _refresh_freelance_app(window: Control = null) -> void:
	var target_window: Control = window

	if target_window == null:
		target_window = _get_window_instance(WINDOW_KEY_FREELANCE)

	if target_window == null:
		return

	if target_window.has_method("refresh"):
		target_window.call("refresh")


func _connect_desktop_widget_signals() -> void:
	if not GameTime.time_changed.is_connected(_on_desktop_time_changed):
		GameTime.time_changed.connect(_on_desktop_time_changed)

	_rent_state = _get_rent_state()

	if _rent_state != null:
		_connect_optional_signal(_rent_state, &"rent_state_changed", Callable(self, "_on_rent_state_changed"))


func _get_rent_state() -> Node:
	if _rent_state != null and is_instance_valid(_rent_state):
		return _rent_state

	_rent_state = get_node_or_null("/root/ApartmentRentState")
	return _rent_state


func _refresh_desktop_widget() -> void:
	var current_time: Dictionary = GameTime.get_current_time_data()
	var current_day: int = int(current_time.get("day", 1))
	var hours: int = int(current_time.get("hours", 0))
	var minutes: int = int(current_time.get("minutes", 0))

	desktop_day_time_label.text = "День %d, %02d:%02d" % [current_day, hours, minutes]
	desktop_rent_due_label.add_theme_color_override("font_color", COLOR_WIDGET_NEUTRAL)

	var rent_state: Node = _get_rent_state()

	if rent_state == null or not rent_state.has_method("get_current_rent_snapshot"):
		desktop_rent_due_label.text = "Следующая аренда: --"
		_set_rent_status_display("Статус: Нет данных", COLOR_WIDGET_NEUTRAL)
		return

	var snapshot: Dictionary = {}
	var snapshot_variant: Variant = rent_state.call("get_current_rent_snapshot")

	if snapshot_variant is Dictionary:
		snapshot = snapshot_variant

	var due_day: int = 0

	if snapshot.has("due_day"):
		due_day = int(snapshot.get("due_day", 0))
	elif rent_state.has_method("get_next_due_day"):
		due_day = int(rent_state.call("get_next_due_day"))

	if due_day > 0:
		desktop_rent_due_label.text = "Следующая аренда: день %d" % due_day
	else:
		desktop_rent_due_label.text = "Следующая аренда: --"

	var status_display: Dictionary = _build_rent_status_display(snapshot, current_day)
	_set_rent_status_display(
		String(status_display.get("text", "Статус: Нет данных")),
		status_display.get("color", COLOR_WIDGET_NEUTRAL)
	)


func _build_rent_status_display(snapshot: Dictionary, current_day: int) -> Dictionary:
	if snapshot.is_empty():
		return {
			"text": "Статус: Нет данных",
			"color": COLOR_WIDGET_NEUTRAL,
		}

	if bool(snapshot.get("is_overdue", false)):
		return {
			"text": "Статус: Просрочено",
			"color": COLOR_WIDGET_OVERDUE,
		}

	if bool(snapshot.get("is_due", false)):
		return {
			"text": "Статус: Аренда сегодня",
			"color": COLOR_WIDGET_DUE,
		}

	var due_day: int = int(snapshot.get("due_day", current_day))

	if due_day <= 0:
		return {
			"text": "Статус: Нет данных",
			"color": COLOR_WIDGET_NEUTRAL,
		}

	var days_until_due: int = int(snapshot.get("days_until_due", due_day - current_day))

	if days_until_due <= 2:
		return {
			"text": "Статус: Аренда скоро",
			"color": COLOR_WIDGET_SOON,
		}

	return {
		"text": "Статус: Без просрочки",
		"color": COLOR_WIDGET_NEUTRAL,
	}


func _set_rent_status_display(text: String, color: Color) -> void:
	desktop_rent_status_label.text = text
	desktop_rent_status_label.add_theme_color_override("font_color", color)


func _reopen_freelance_app_after_minigame() -> void:
	var moderation_window: Control = _get_window_instance(WINDOW_KEY_MODERATION)

	if moderation_window != null:
		_hide_window_immediate(moderation_window)

	var freelance_window: Control = _ensure_scene_window_instance(FREELANCE_APP_SCENE_PATH, WINDOW_KEY_FREELANCE)

	if freelance_window == null:
		_show_placeholder("Фриланс", "Приложение пока не установлено.")
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(WINDOW_KEY_FREELANCE)
	_show_window(freelance_window, WINDOW_KEY_FREELANCE)
	_refresh_freelance_app(freelance_window)


func _on_window_close_requested(key: StringName) -> void:
	if key == WINDOW_KEY_PLACEHOLDER:
		var return_target: StringName = _placeholder_return_target
		_placeholder_return_target = &""
		var placeholder_window: Control = _get_window_instance(WINDOW_KEY_PLACEHOLDER)

		if placeholder_window != null:
			_hide_window(placeholder_window)

		if return_target == WINDOW_KEY_FREELANCE:
			_open_freelance_app()

		return

	if key == WINDOW_KEY_MODERATION:
		_reopen_freelance_app_after_minigame()
		return

	_close_all_windows()


func _on_freelance_request_start_order(order_id: int) -> void:
	_open_moderation_minigame(order_id)


func _on_moderation_return_to_freelance_requested() -> void:
	_reopen_freelance_app_after_minigame()


func _on_moderation_session_finished(result: Dictionary) -> void:
	_last_moderation_session_result = result.duplicate(true)


func _on_desktop_time_changed(_absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	_refresh_desktop_widget()


func _on_rent_state_changed() -> void:
	_refresh_desktop_widget()
