extends Node

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")

signal settings_changed
signal input_binding_changed(action_name: StringName)

const SETTINGS_PATH := "user://settings.json"
const MUSIC_BUS_NAME := "Music"
const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)
const WINDOW_MODE_WINDOWED := "windowed"
const WINDOW_MODE_FULLSCREEN := "fullscreen"
const DEFAULT_MASTER_VOLUME_DB := 0.0
const DEFAULT_MUSIC_VOLUME_DB := -20.0
const DEFAULT_ACTION_KEYCODES := {
	&"move_left": KEY_A,
	&"move_right": KEY_D,
	&"move_up": KEY_W,
	&"move_down": KEY_S,
	&"interact": KEY_E,
	&"inventory_toggle": KEY_I,
	&"open_phone": KEY_UP,
	&"pause_menu": KEY_ESCAPE,
}
const ACTION_LABELS := {
	&"move_left": "Движение влево",
	&"move_right": "Движение вправо",
	&"move_up": "Движение вверх",
	&"move_down": "Движение вниз",
	&"interact": "Взаимодействие",
	&"inventory_toggle": "Инвентарь",
	&"open_phone": "Телефон",
	&"pause_menu": "Меню / пауза",
}

var _settings: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_music_bus_exists()
	ensure_actions_initialized()
	_load_settings()
	_apply_all_settings()


func ensure_actions_initialized() -> void:
	_ensure_actions_exist()


func get_music_bus_name() -> String:
	return MUSIC_BUS_NAME


func get_window_mode() -> String:
	return String(_settings.get("window_mode", WINDOW_MODE_WINDOWED))


func get_master_volume_db() -> float:
	return float(_settings.get("master_volume_db", DEFAULT_MASTER_VOLUME_DB))


func get_music_volume_db() -> float:
	return float(_settings.get("music_volume_db", DEFAULT_MUSIC_VOLUME_DB))


func get_action_keycode(action_name: StringName) -> int:
	var bindings: Dictionary = SaveDataUtils.sanitize_dictionary(_settings.get("input_bindings", {}))
	return int(bindings.get(String(action_name), int(DEFAULT_ACTION_KEYCODES.get(action_name, KEY_NONE))))


func get_action_display_text(action_name: StringName, fallback: String = "") -> String:
	for event in InputMap.action_get_events(action_name):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var keycode := int(key_event.physical_keycode)

		if keycode == 0:
			keycode = int(key_event.keycode)

		var key_text := OS.get_keycode_string(keycode)

		if not key_text.is_empty():
			return key_text.to_upper()

	if not fallback.is_empty():
		return fallback

	var default_keycode: int = int(DEFAULT_ACTION_KEYCODES.get(action_name, KEY_NONE))
	return OS.get_keycode_string(default_keycode).to_upper() if default_keycode != KEY_NONE else ""


func get_rebindable_actions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		result.append({
			"id": String(action_name),
			"label": String(ACTION_LABELS.get(action_name, String(action_name))),
			"keycode": get_action_keycode(action_name),
			"display_text": get_action_display_text(action_name),
		})

	return result


func set_window_mode(window_mode: String) -> void:
	var normalized_mode := window_mode.strip_edges().to_lower()

	if normalized_mode != WINDOW_MODE_FULLSCREEN:
		normalized_mode = WINDOW_MODE_WINDOWED

	if get_window_mode() == normalized_mode:
		return

	_settings["window_mode"] = normalized_mode
	_apply_window_mode_setting()
	_save_settings()
	settings_changed.emit()


func set_master_volume_db(volume_db: float) -> void:
	var normalized_volume := clampf(volume_db, -60.0, 6.0)

	if is_equal_approx(get_master_volume_db(), normalized_volume):
		return

	_settings["master_volume_db"] = normalized_volume
	_apply_master_volume_setting()
	_save_settings()
	settings_changed.emit()


func set_music_volume_db(volume_db: float) -> void:
	var normalized_volume := clampf(volume_db, -60.0, 6.0)

	if is_equal_approx(get_music_volume_db(), normalized_volume):
		return

	_settings["music_volume_db"] = normalized_volume
	_apply_music_volume_setting()
	_save_settings()
	settings_changed.emit()


func rebind_action_to_keycode(action_name: StringName, keycode: int) -> void:
	if not DEFAULT_ACTION_KEYCODES.has(action_name):
		return

	if keycode == KEY_NONE:
		return

	var bindings: Dictionary = SaveDataUtils.sanitize_dictionary(_settings.get("input_bindings", {}))
	bindings[String(action_name)] = keycode
	_settings["input_bindings"] = bindings
	_apply_input_binding(action_name)
	_save_settings()
	input_binding_changed.emit(action_name)
	settings_changed.emit()


func restore_defaults() -> void:
	_settings = _build_default_settings()
	_apply_all_settings()
	_save_settings()


func _build_default_settings() -> Dictionary:
	var bindings: Dictionary = {}

	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		bindings[String(action_name)] = int(DEFAULT_ACTION_KEYCODES[action_name])

	return {
		"window_mode": WINDOW_MODE_WINDOWED,
		"master_volume_db": DEFAULT_MASTER_VOLUME_DB,
		"music_volume_db": DEFAULT_MUSIC_VOLUME_DB,
		"input_bindings": bindings,
	}


func _load_settings() -> void:
	_settings = _build_default_settings()

	if not FileAccess.file_exists(SETTINGS_PATH):
		return

	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)

	if file == null:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not (parsed is Dictionary):
		return

	var loaded: Dictionary = parsed
	_settings["window_mode"] = String(loaded.get("window_mode", WINDOW_MODE_WINDOWED)).strip_edges().to_lower()
	_settings["master_volume_db"] = clampf(
		float(loaded.get("master_volume_db", DEFAULT_MASTER_VOLUME_DB)),
		-60.0,
		6.0
	)
	_settings["music_volume_db"] = clampf(
		float(loaded.get("music_volume_db", DEFAULT_MUSIC_VOLUME_DB)),
		-60.0,
		6.0
	)

	var loaded_bindings: Dictionary = SaveDataUtils.sanitize_dictionary(loaded.get("input_bindings", {}))
	var merged_bindings: Dictionary = SaveDataUtils.sanitize_dictionary(_settings.get("input_bindings", {}))

	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		var binding_key := String(action_name)
		merged_bindings[binding_key] = int(loaded_bindings.get(binding_key, merged_bindings.get(binding_key, KEY_NONE)))

	_settings["input_bindings"] = merged_bindings

	if get_window_mode() != WINDOW_MODE_FULLSCREEN:
		_settings["window_mode"] = WINDOW_MODE_WINDOWED


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)

	if file == null:
		push_warning("GameSettings could not open the settings file for writing.")
		return

	file.store_string(JSON.stringify(_settings, "\t"))


func _apply_all_settings() -> void:
	_ensure_music_bus_exists()
	_ensure_actions_exist()
	_apply_input_bindings()
	_apply_window_mode_setting()
	_apply_master_volume_setting()
	_apply_music_volume_setting()
	settings_changed.emit()


func _ensure_music_bus_exists() -> void:
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)

	if music_bus_index != -1:
		return

	var new_bus_index := AudioServer.bus_count
	AudioServer.add_bus(new_bus_index)
	AudioServer.set_bus_name(new_bus_index, MUSIC_BUS_NAME)
	AudioServer.set_bus_send(new_bus_index, "Master")


func _ensure_actions_exist() -> void:
	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		if InputMap.has_action(action_name):
			continue

		InputMap.add_action(action_name)


func _apply_input_bindings() -> void:
	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		_apply_input_binding(action_name)

	for action_name in DEFAULT_ACTION_KEYCODES.keys():
		input_binding_changed.emit(action_name)


func _apply_input_binding(action_name: StringName) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

	InputMap.action_erase_events(action_name)

	var keycode := get_action_keycode(action_name)

	if keycode == KEY_NONE:
		return

	InputMap.action_add_event(action_name, _create_key_event(keycode))


func _create_key_event(keycode: int) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.physical_keycode = keycode
	key_event.keycode = keycode
	return key_event


func _apply_window_mode_setting() -> void:
	var tree := get_tree()

	if tree == null or tree.root == null:
		return

	var window := tree.root

	if get_window_mode() == WINDOW_MODE_FULLSCREEN:
		window.mode = Window.MODE_FULLSCREEN
		return

	window.mode = Window.MODE_WINDOWED
	window.min_size = TARGET_WINDOW_SIZE
	window.size = TARGET_WINDOW_SIZE


func _apply_master_volume_setting() -> void:
	var master_bus_index := AudioServer.get_bus_index("Master")

	if master_bus_index == -1:
		return

	AudioServer.set_bus_volume_db(master_bus_index, get_master_volume_db())


func _apply_music_volume_setting() -> void:
	_ensure_music_bus_exists()
	var music_bus_index := AudioServer.get_bus_index(MUSIC_BUS_NAME)

	if music_bus_index == -1:
		return

	AudioServer.set_bus_volume_db(music_bus_index, get_music_volume_db())
