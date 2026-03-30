extends Control


const PANEL_BG := Color(0.06, 0.08, 0.13, 0.9)
const PANEL_BORDER := Color(0.62, 0.74, 0.88, 0.22)

var _continue_button: Button
var _subpanel_shell: PanelContainer
var _subpanel_title_label: Label
var _subpanel_host: Control
var _save_slots_panel: SaveSlotsPanel
var _settings_panel: SettingsPanel


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()

	if SaveManager != null and not SaveManager.save_slots_changed.is_connected(_update_continue_button):
		SaveManager.save_slots_changed.connect(_update_continue_button)

	_show_home()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.color = Color(0.02, 0.03, 0.05, 1.0)
	add_child(background)

	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen_margin.add_theme_constant_override("margin_left", 88)
	screen_margin.add_theme_constant_override("margin_top", 76)
	screen_margin.add_theme_constant_override("margin_right", 88)
	screen_margin.add_theme_constant_override("margin_bottom", 76)
	add_child(screen_margin)

	var main_row := HBoxContainer.new()
	main_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_row.add_theme_constant_override("separation", 56)
	screen_margin.add_child(main_row)

	var left_column := VBoxContainer.new()
	left_column.custom_minimum_size = Vector2(680.0, 0.0)
	left_column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_theme_constant_override("separation", 36)
	main_row.add_child(left_column)

	var title_label := Label.new()
	title_label.text = "The history of the Rune"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 44)
	left_column.add_child(title_label)

	var menu_panel := PanelContainer.new()
	menu_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_panel.add_theme_stylebox_override("panel", _build_panel_style())
	left_column.add_child(menu_panel)

	var menu_margin := MarginContainer.new()
	menu_margin.add_theme_constant_override("margin_left", 40)
	menu_margin.add_theme_constant_override("margin_top", 40)
	menu_margin.add_theme_constant_override("margin_right", 40)
	menu_margin.add_theme_constant_override("margin_bottom", 40)
	menu_panel.add_child(menu_margin)

	var menu_content := VBoxContainer.new()
	menu_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_content.add_theme_constant_override("separation", 18)
	menu_margin.add_child(menu_content)

	menu_content.add_child(_build_menu_button("Новая игра", _on_new_game_pressed))
	_continue_button = _build_menu_button("Продолжить", _on_continue_pressed)
	menu_content.add_child(_continue_button)
	menu_content.add_child(_build_menu_button("Загрузить", _on_load_pressed))
	menu_content.add_child(_build_menu_button("Настройки", _on_settings_pressed))
	menu_content.add_child(_build_menu_button("Выход", _on_exit_pressed))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_column.add_child(spacer)

	_subpanel_shell = PanelContainer.new()
	_subpanel_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subpanel_shell.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_subpanel_shell.add_theme_stylebox_override("panel", _build_panel_style())
	main_row.add_child(_subpanel_shell)

	var subpanel_margin := MarginContainer.new()
	subpanel_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subpanel_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subpanel_margin.add_theme_constant_override("margin_left", 40)
	subpanel_margin.add_theme_constant_override("margin_top", 40)
	subpanel_margin.add_theme_constant_override("margin_right", 40)
	subpanel_margin.add_theme_constant_override("margin_bottom", 40)
	_subpanel_shell.add_child(subpanel_margin)

	var subpanel_content := VBoxContainer.new()
	subpanel_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subpanel_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subpanel_content.add_theme_constant_override("separation", 24)
	subpanel_margin.add_child(subpanel_content)

	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 12)
	subpanel_content.add_child(header_row)

	var back_button := Button.new()
	back_button.text = "Назад"
	back_button.custom_minimum_size = Vector2(110.0, 0.0)
	back_button.pressed.connect(_show_home)
	header_row.add_child(back_button)

	_subpanel_title_label = Label.new()
	_subpanel_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subpanel_title_label.add_theme_font_size_override("font_size", 28)
	header_row.add_child(_subpanel_title_label)

	_subpanel_host = Control.new()
	_subpanel_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subpanel_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subpanel_content.add_child(_subpanel_host)

	_save_slots_panel = SaveSlotsPanel.new()
	_save_slots_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subpanel_host.add_child(_save_slots_panel)

	_settings_panel = SettingsPanel.new()
	_settings_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_subpanel_host.add_child(_settings_panel)


func _build_menu_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	return button


func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	return style


func _show_home() -> void:
	if _settings_panel != null:
		_settings_panel.stop_rebind_capture()

	_subpanel_shell.visible = false
	_save_slots_panel.visible = false
	_settings_panel.visible = false
	_update_continue_button()


func _show_load_panel() -> void:
	if _settings_panel != null:
		_settings_panel.stop_rebind_capture()

	_subpanel_shell.visible = true
	_subpanel_title_label.text = "Загрузка"
	_save_slots_panel.visible = true
	_settings_panel.visible = false
	_save_slots_panel.configure(SaveSlotsPanel.MODE_LOAD)
	_save_slots_panel.refresh_panel()


func _show_settings_panel() -> void:
	_subpanel_shell.visible = true
	_subpanel_title_label.text = "Настройки"
	_save_slots_panel.visible = false
	_settings_panel.visible = true
	_settings_panel.refresh_panel()


func _update_continue_button() -> void:
	if _continue_button == null:
		return

	var latest_summary := SaveManager.get_continue_summary()
	var has_save := not latest_summary.is_empty()
	_continue_button.disabled = not has_save

	if not has_save:
		_continue_button.tooltip_text = "Нет доступных сохранений."
		return

	var summary: Dictionary = SaveDataUtils.sanitize_dictionary(latest_summary.get("summary", {}))
	_continue_button.tooltip_text = "Последний слот: %s, день %d %02d:%02d" % [
		String(summary.get("room_name", "Неизвестно")),
		int(summary.get("day", 1)),
		int(summary.get("hours", 0)),
		int(summary.get("minutes", 0)),
	]


func _on_new_game_pressed() -> void:
	SaveManager.request_new_game()


func _on_continue_pressed() -> void:
	SaveManager.request_load_latest_save()


func _on_load_pressed() -> void:
	_show_load_panel()


func _on_settings_pressed() -> void:
	_show_settings_panel()


func _on_exit_pressed() -> void:
	get_tree().quit()
