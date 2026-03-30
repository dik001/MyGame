extends Control

const GAME_THEME := preload("res://resources/ui/game_theme.tres")

const SCREEN_BG := Color(0.02, 0.03, 0.05, 1.0)
const SCREEN_LAYER := Color(0.04, 0.07, 0.12, 0.48)
const SCREEN_ACCENT := Color(0.18, 0.06, 0.08, 0.24)

const PANEL_BG := Color(0.06, 0.08, 0.13, 0.90)
const PANEL_BORDER := Color(0.62, 0.74, 0.88, 0.22)
const PANEL_BORDER_STRONG := Color(0.46, 0.62, 0.82, 0.54)

const CARD_BG := Color(0.09, 0.11, 0.17, 0.82)
const CARD_BORDER := Color(0.52, 0.66, 0.82, 0.26)

const BADGE_BG := Color(0.18, 0.09, 0.11, 0.94)
const BADGE_BORDER := Color(0.76, 0.36, 0.42, 0.54)
const BADGE_TEXT := Color(0.98, 0.82, 0.86, 1.0)

const META_LABEL_COLOR := Color(0.66, 0.76, 0.88, 1.0)
const META_VALUE_COLOR := Color(0.95, 0.96, 0.99, 1.0)

var _main_menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = GAME_THEME
	_build_ui()
	call_deferred("_grab_default_focus")


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0

	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = SCREEN_BG
	add_child(background)

	var top_band := ColorRect.new()
	top_band.anchor_right = 1.0
	top_band.offset_bottom = 220.0
	top_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_band.color = SCREEN_LAYER
	add_child(top_band)

	var side_accent := ColorRect.new()
	side_accent.anchor_left = 0.56
	side_accent.anchor_top = 0.16
	side_accent.anchor_right = 1.0
	side_accent.anchor_bottom = 1.0
	side_accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side_accent.color = SCREEN_ACCENT
	add_child(side_accent)

	var frame := Panel.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 22.0
	frame.offset_top = 22.0
	frame.offset_right = -22.0
	frame.offset_bottom = -22.0
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _build_frame_style())
	add_child(frame)

	var screen_margin := MarginContainer.new()
	screen_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

	main_row.add_child(_build_left_column())
	main_row.add_child(_build_right_column())


func _build_left_column() -> Control:
	var column := VBoxContainer.new()
	column.custom_minimum_size = Vector2(620.0, 0.0)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 30)

	var badge := _build_badge("КОНЕЦ ПОПЫТКИ")
	column.add_child(badge)

	var title_label := Label.new()
	title_label.text = "GAME OVER"
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title_label.add_theme_font_size_override("font_size", 64)
	column.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Попытка закончилась."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 24)
	column.add_child(subtitle_label)

	var summary_line := Label.new()
	summary_line.text = _build_summary_line()
	summary_line.visible = not summary_line.text.is_empty()
	summary_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_line.add_theme_font_size_override("font_size", 18)
	summary_line.add_theme_color_override("font_color", META_LABEL_COLOR)
	column.add_child(summary_line)

	column.add_child(_build_action_panel())

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)

	return column


func _build_right_column() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_panel_style(true))

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 24)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = "Сводка попытки"
	title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Финальное состояние текущей сессии."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", META_LABEL_COLOR)
	content.add_child(subtitle_label)

	var cards := GridContainer.new()
	cards.columns = 2
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_theme_constant_override("h_separation", 12)
	cards.add_theme_constant_override("v_separation", 12)
	content.add_child(cards)

	cards.add_child(_build_info_card("ДЕНЬ", _format_day_value()))
	cards.add_child(_build_info_card("ВРЕМЯ", _format_time_value()))

	var location_text := _format_location_value()
	if not location_text.is_empty():
		cards.add_child(_build_info_card("ЛОКАЦИЯ", location_text))

	cards.add_child(_build_info_card("СТАТУС", "ЗАВЕРШЕНА"))

	var note_panel := PanelContainer.new()
	note_panel.add_theme_stylebox_override("panel", _build_card_style())
	content.add_child(note_panel)

	var note_margin := MarginContainer.new()
	note_margin.add_theme_constant_override("margin_left", 18)
	note_margin.add_theme_constant_override("margin_top", 18)
	note_margin.add_theme_constant_override("margin_right", 18)
	note_margin.add_theme_constant_override("margin_bottom", 18)
	note_panel.add_child(note_margin)

	var note_label := Label.new()
	note_label.text = "Возврат в эту попытку недоступен."
	note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note_label.add_theme_font_size_override("font_size", 18)
	note_margin.add_child(note_label)

	var filler := Control.new()
	filler.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(filler)

	return panel


func _build_action_panel() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_panel_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_top", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_bottom", 40)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 18)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = "Меню"
	title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(title_label)

	var subtitle_label := Label.new()
	subtitle_label.text = "Текущая сессия завершена."
	subtitle_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle_label.add_theme_font_size_override("font_size", 18)
	subtitle_label.add_theme_color_override("font_color", META_LABEL_COLOR)
	content.add_child(subtitle_label)

	_main_menu_button = _build_menu_button("Главное меню", _on_main_menu_pressed)
	content.add_child(_main_menu_button)
	content.add_child(_build_menu_button("Выйти", _on_exit_pressed))

	return panel


func _build_badge(text_value: String) -> Control:
	var badge := PanelContainer.new()
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	badge.add_theme_stylebox_override("panel", _build_badge_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 10)
	badge.add_child(margin)

	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", BADGE_TEXT)
	margin.add_child(label)

	return badge


func _build_info_card(title_text: String, value_text: String) -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _build_card_style())

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)

	var title_label := Label.new()
	title_label.text = title_text
	title_label.add_theme_font_size_override("font_size", 16)
	title_label.add_theme_color_override("font_color", META_LABEL_COLOR)
	content.add_child(title_label)

	var value_label := Label.new()
	value_label.text = value_text
	value_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	value_label.add_theme_font_size_override("font_size", 26)
	value_label.add_theme_color_override("font_color", META_VALUE_COLOR)
	content.add_child(value_label)

	return panel


func _build_frame_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.34, 0.44, 0.58, 0.22)
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	return style


func _build_panel_style(strong_border := false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PANEL_BORDER_STRONG if strong_border else PANEL_BORDER
	style.corner_radius_top_left = 18
	style.corner_radius_top_right = 18
	style.corner_radius_bottom_right = 18
	style.corner_radius_bottom_left = 18
	return style


func _build_card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = CARD_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = CARD_BORDER
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func _build_badge_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = BADGE_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = BADGE_BORDER
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	return style


func _build_menu_button(button_text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0.0, 68.0)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_size_override("font_size", 26)
	button.pressed.connect(callback)
	return button


func _build_summary_line() -> String:
	var parts: Array[String] = []
	var payload := _get_game_over_payload()
	var day := int(payload.get("day", 0))
	var absolute_minutes := int(payload.get("absolute_minutes", -1))
	var location_text := _format_location_value()

	if day > 0:
		parts.append("День %d" % day)

	if absolute_minutes >= 0:
		var hours := int(absolute_minutes / 60.0) % 24
		var minutes := absolute_minutes % 60
		parts.append("%02d:%02d" % [hours, minutes])

	if not location_text.is_empty():
		parts.append(location_text)

	return " / ".join(parts)


func _get_game_over_payload() -> Dictionary:
	if GameManager == null or not GameManager.has_method("get_game_over_payload"):
		return {}

	return GameManager.get_game_over_payload()


func _format_day_value() -> String:
	var payload := _get_game_over_payload()
	var day := int(payload.get("day", 0))

	if day <= 0:
		return "Неизвестно"

	return "День %d" % day


func _format_time_value() -> String:
	var payload := _get_game_over_payload()
	var absolute_minutes := int(payload.get("absolute_minutes", -1))

	if absolute_minutes < 0:
		return "Неизвестно"

	var hours := int(absolute_minutes / 60.0) % 24
	var minutes := absolute_minutes % 60
	return "%02d:%02d" % [hours, minutes]


func _format_location_value() -> String:
	var payload := _get_game_over_payload()
	var room_scene_path := String(payload.get("room_scene_path", "")).strip_edges()

	if room_scene_path.is_empty():
		return ""

	var scene_id := room_scene_path.get_file().get_basename().to_lower()

	match scene_id:
		"apartament":
			return "Квартира"
		"elevator":
			return "Лифт"
		"enterance":
			return "Подъезд"
		"supermarket":
			return "Супермаркет"
		"town":
			return "Город"
		_:
			return ""


func _grab_default_focus() -> void:
	if _main_menu_button != null:
		_main_menu_button.grab_focus()


func _on_main_menu_pressed() -> void:
	if SaveManager != null and SaveManager.has_method("return_to_title_screen"):
		SaveManager.return_to_title_screen()


func _on_exit_pressed() -> void:
	get_tree().quit()
