class_name SettingsPanel
extends PanelContainer

var _window_mode_option: OptionButton
var _master_slider: HSlider
var _master_value_label: Label
var _music_slider: HSlider
var _music_value_label: Label
var _bindings_container: VBoxContainer
var _binding_buttons: Dictionary = {}
var _status_label: Label
var _waiting_action: StringName = &""
var _is_refreshing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()

	if GameSettings != null:
		if not GameSettings.settings_changed.is_connected(refresh_panel):
			GameSettings.settings_changed.connect(refresh_panel)

	refresh_panel()


func is_waiting_for_rebind() -> bool:
	return not _waiting_action.is_empty()


func stop_rebind_capture() -> void:
	_waiting_action = &""
	refresh_panel()


func refresh_panel() -> void:
	if _window_mode_option == null:
		return

	_is_refreshing = true
	_window_mode_option.select(0 if GameSettings.get_window_mode() == GameSettings.WINDOW_MODE_WINDOWED else 1)
	_master_slider.value = GameSettings.get_master_volume_db()
	_music_slider.value = GameSettings.get_music_volume_db()
	_master_value_label.text = _format_volume_text(_master_slider.value)
	_music_value_label.text = _format_volume_text(_music_slider.value)
	_rebuild_bindings_list()
	_is_refreshing = false

	if _waiting_action.is_empty():
		_status_label.text = "Изменения применяются сразу."
	else:
		_status_label.text = "Нажмите новую клавишу для: %s" % GameSettings.get_action_display_text(_waiting_action, String(_waiting_action))


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_action.is_empty():
		return

	if not (event is InputEventKey):
		return

	var key_event := event as InputEventKey

	if not key_event.pressed or key_event.echo:
		return

	var keycode := int(key_event.physical_keycode)

	if keycode == 0:
		keycode = int(key_event.keycode)

	if keycode == KEY_NONE:
		return

	GameSettings.rebind_action_to_keycode(_waiting_action, keycode)
	_waiting_action = &""
	get_viewport().set_input_as_handled()
	refresh_panel()


func _build_ui() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 44)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 44)
	margin.add_theme_constant_override("margin_bottom", 44)
	add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = "Настройки"
	title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Экран, громкость и игровые клавиши."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 16)
	content.add_child(subtitle_label)

	content.add_child(_build_window_mode_row())
	content.add_child(_build_volume_row("Общая громкость", true))
	content.add_child(_build_volume_row("Громкость музыки", false))

	var bindings_title := Label.new()
	bindings_title.text = "Клавиши"
	bindings_title.add_theme_font_size_override("font_size", 22)
	content.add_child(bindings_title)

	var bindings_scroll := ScrollContainer.new()
	bindings_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bindings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bindings_scroll.custom_minimum_size = Vector2(0.0, 320.0)
	content.add_child(bindings_scroll)

	_bindings_container = VBoxContainer.new()
	_bindings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bindings_container.add_theme_constant_override("separation", 14)
	bindings_scroll.add_child(_bindings_container)

	var footer_row := HBoxContainer.new()
	footer_row.custom_minimum_size = Vector2(0.0, 60.0)
	footer_row.add_theme_constant_override("separation", 16)
	content.add_child(footer_row)

	var restore_button := Button.new()
	restore_button.text = "Сбросить по умолчанию"
	restore_button.pressed.connect(_on_restore_defaults_pressed)
	footer_row.add_child(restore_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer_row.add_child(spacer)

	_status_label = Label.new()
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	footer_row.add_child(_status_label)


func _build_window_mode_row() -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 56.0)
	row.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = "Режим окна"
	label.custom_minimum_size = Vector2(280.0, 0.0)
	row.add_child(label)

	_window_mode_option = OptionButton.new()
	_window_mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_window_mode_option.add_item("Окно")
	_window_mode_option.add_item("Полный экран")
	_window_mode_option.item_selected.connect(_on_window_mode_selected)
	row.add_child(_window_mode_option)

	return row


func _build_volume_row(label_text: String, is_master: bool) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0.0, 56.0)
	row.add_theme_constant_override("separation", 18)

	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(280.0, 0.0)
	row.add_child(label)

	var slider := HSlider.new()
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.min_value = -60.0
	slider.max_value = 6.0
	slider.step = 1.0
	row.add_child(slider)

	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(92.0, 0.0)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)

	if is_master:
		_master_slider = slider
		_master_value_label = value_label
		_master_slider.value_changed.connect(_on_master_volume_changed)
	else:
		_music_slider = slider
		_music_value_label = value_label
		_music_slider.value_changed.connect(_on_music_volume_changed)

	return row


func _rebuild_bindings_list() -> void:
	for child in _bindings_container.get_children():
		_bindings_container.remove_child(child)
		child.queue_free()

	_binding_buttons.clear()

	for entry in GameSettings.get_rebindable_actions():
		var action_name := StringName(String(entry.get("id", "")))
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0.0, 56.0)
		row.add_theme_constant_override("separation", 18)

		var label := Label.new()
		label.text = String(entry.get("label", action_name))
		label.custom_minimum_size = Vector2(280.0, 0.0)
		row.add_child(label)

		var button := Button.new()
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0.0, 56.0)
		button.text = "Нажмите клавишу..." if action_name == _waiting_action else String(entry.get("display_text", ""))
		button.pressed.connect(_on_rebind_button_pressed.bind(action_name))
		row.add_child(button)
		_binding_buttons[String(action_name)] = button

		_bindings_container.add_child(row)


func _format_volume_text(value: float) -> String:
	return "%ddB" % int(roundi(value))


func _on_window_mode_selected(index: int) -> void:
	if _is_refreshing:
		return

	GameSettings.set_window_mode(
		GameSettings.WINDOW_MODE_WINDOWED if index == 0 else GameSettings.WINDOW_MODE_FULLSCREEN
	)


func _on_master_volume_changed(value: float) -> void:
	if _is_refreshing:
		return

	_master_value_label.text = _format_volume_text(value)
	GameSettings.set_master_volume_db(value)


func _on_music_volume_changed(value: float) -> void:
	if _is_refreshing:
		return

	_music_value_label.text = _format_volume_text(value)
	GameSettings.set_music_volume_db(value)


func _on_rebind_button_pressed(action_name: StringName) -> void:
	_waiting_action = action_name
	refresh_panel()


func _on_restore_defaults_pressed() -> void:
	_waiting_action = &""
	GameSettings.restore_defaults()
	refresh_panel()
