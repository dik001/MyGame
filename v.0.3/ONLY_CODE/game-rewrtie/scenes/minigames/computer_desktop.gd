extends Control

const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const SLITHARIO_SCENE_PATH := "res://scenes/minigames/slithario.tscn"
const FREELANCE_APP_SCENE_PATH := "res://scenes/freelance/FreelanceAppWindow.tscn"
const BANK_APP_SCENE_PATH := "res://scenes/freelance/BankAppWindow.tscn"
const MODERATION_MINIGAME_SCENE_PATH := "res://scenes/freelance/ModerationMinigameUI.tscn"
const INFO_WINDOW_SCENE_PATH := "res://scenes/freelance/DesktopInfoWindow.tscn"

const WINDOW_KEY_SHOP: StringName = &"shop"
const WINDOW_KEY_DELIVERY: StringName = &"delivery"
const WINDOW_KEY_FREELANCE: StringName = &"freelance"
const WINDOW_KEY_BANK: StringName = &"bank"
const WINDOW_KEY_MODERATION: StringName = &"moderation"
const WINDOW_KEY_PLACEHOLDER: StringName = &"placeholder"

@onready var slithario_button: TextureButton = $DesktopRoot/ShortcutLayer/SlitharioShortcut/SlitharioIconButton
@onready var shop_button: TextureButton = $DesktopRoot/ShortcutLayer/ShopShortcut/ShopIconButton
@onready var delivery_button: TextureButton = $DesktopRoot/ShortcutLayer/DeliveryShortcut/DeliveryIconButton
@onready var freelance_button: TextureButton = $DesktopRoot/ShortcutLayer/FreelanceShortcut/FreelanceIconButton
@onready var bank_button: TextureButton = $DesktopRoot/ShortcutLayer/BankShortcut/BankIconButton
@onready var windows_layer: Control = $DesktopRoot/WindowsLayer
@onready var shop_window: Control = $DesktopRoot/WindowsLayer/ShopWindow
@onready var delivery_tracker_window: Control = $DesktopRoot/WindowsLayer/DeliveryTrackerWindow

var _window_instances: Dictionary = {}
var _last_moderation_session_result: Dictionary = {}
var _placeholder_return_target: StringName = &""


func _ready() -> void:
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

	_register_existing_window(WINDOW_KEY_SHOP, shop_window)
	_register_existing_window(WINDOW_KEY_DELIVERY, delivery_tracker_window)
	_close_all_windows()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _has_open_window():
			# Desktop windows handle ui_cancel on their own. We intentionally avoid
			# force-closing them here so placeholder return targets and the
			# moderation fail flow stay authoritative.
			return
		else:
			var viewport: Viewport = get_viewport()

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


func _close_all_windows() -> void:
	_placeholder_return_target = &""
	_hide_all_desktop_windows()


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

	_window_instances[key] = window
	_connect_window_signals(window, key)


func _open_registered_window(key: StringName) -> void:
	var window: Control = _get_window_instance(key)

	if window == null:
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(key)
	_show_window(window)


func _open_freelance_app() -> void:
	var window: Control = _open_scene_window(FREELANCE_APP_SCENE_PATH, WINDOW_KEY_FREELANCE)

	if window == null:
		_show_placeholder("Фриланс", "Приложение пока не установлено.")
		return

	_refresh_freelance_app(window)


func _open_bank_app() -> void:
	var window: Control = _open_scene_window(BANK_APP_SCENE_PATH, WINDOW_KEY_BANK)

	if window == null:
		_show_placeholder("Банк", "Приложение пока не установлено.")


func _open_moderation_minigame(order_id: int) -> void:
	var minigame_window: Control = _ensure_scene_window_instance(MODERATION_MINIGAME_SCENE_PATH, WINDOW_KEY_MODERATION)

	if minigame_window == null:
		_show_placeholder("Модерация", "Режим модерации пока не установлен.", WINDOW_KEY_FREELANCE)
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(WINDOW_KEY_MODERATION)
	_show_window(minigame_window)

	if minigame_window.has_method("start_for_order"):
		minigame_window.call("start_for_order", order_id)


func _open_scene_window(scene_path: String, key: StringName) -> Control:
	var window: Control = _ensure_scene_window_instance(scene_path, key)

	if window == null:
		return null

	_placeholder_return_target = &""
	_hide_all_desktop_windows(key)
	_show_window(window)
	return window


func _ensure_scene_window_instance(scene_path: String, key: StringName) -> Control:
	var existing_window: Control = _get_window_instance(key)

	if existing_window != null:
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
	windows_layer.add_child(window)
	_window_instances[key] = window
	_connect_window_signals(window, key)
	return window


func _show_placeholder(title: String, message: String, return_target: StringName = &"") -> void:
	var placeholder_window: Control = _ensure_scene_window_instance(INFO_WINDOW_SCENE_PATH, WINDOW_KEY_PLACEHOLDER)

	if placeholder_window == null:
		push_warning("DesktopInfoWindow scene is missing. Could not show placeholder.")
		return

	_placeholder_return_target = return_target
	_hide_all_desktop_windows(WINDOW_KEY_PLACEHOLDER)

	if placeholder_window.has_method("set_content"):
		placeholder_window.call("set_content", title, message)

	if placeholder_window.has_method("open_window"):
		placeholder_window.call("open_window", title, message)
	else:
		placeholder_window.visible = true
		placeholder_window.move_to_front()


func _hide_all_desktop_windows(except_key: StringName = &"") -> void:
	for key_variant in _window_instances.keys():
		var key: StringName = StringName(key_variant)
		var window: Control = _get_window_instance(key)

		if window == null:
			continue

		if not String(except_key).is_empty() and key == except_key:
			continue

		_hide_window(window)

	if except_key != WINDOW_KEY_PLACEHOLDER:
		_placeholder_return_target = &""


func _show_window(window: Control) -> void:
	if window == null:
		return

	window.move_to_front()

	if window.has_method("open_window"):
		window.call("open_window")
	else:
		window.visible = true


func _hide_window(window: Control) -> void:
	if window == null:
		return

	if window.has_method("close_window"):
		window.call("close_window")
	else:
		window.visible = false


func _get_window_instance(key: StringName) -> Control:
	if not _window_instances.has(key):
		return null

	var window: Control = _window_instances[key] as Control

	if window != null and is_instance_valid(window):
		return window

	_window_instances.erase(key)
	return null


func _connect_window_signals(window: Node, key: StringName) -> void:
	_connect_optional_signal(window, &"close_requested", Callable(self, "_on_window_close_requested").bind(key))

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


func _reopen_freelance_app_after_minigame() -> void:
	var moderation_window: Control = _get_window_instance(WINDOW_KEY_MODERATION)

	if moderation_window != null:
		_hide_window(moderation_window)

	var freelance_window: Control = _ensure_scene_window_instance(FREELANCE_APP_SCENE_PATH, WINDOW_KEY_FREELANCE)

	if freelance_window == null:
		_show_placeholder("Фриланс", "Приложение пока не установлено.")
		return

	_placeholder_return_target = &""
	_hide_all_desktop_windows(WINDOW_KEY_FREELANCE)
	_show_window(freelance_window)
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
