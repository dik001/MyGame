class_name StyledConfirmationDialog
extends Control

signal confirmed
signal canceled

const GAME_THEME := preload("res://resources/ui/game_theme.tres")

var _title_label: Label
var _message_label: Label
var _confirm_button: Button
var _cancel_button: Button
var _is_open := false
var dialog_text := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	top_level = true
	z_index = 100
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = GAME_THEME
	_build_ui()


func popup_confirmation(
	title_text: String,
	message_text: String,
	confirm_text: String = "Подтвердить",
	cancel_text: String = "Отмена"
) -> void:
	_title_label.text = title_text
	_message_label.text = message_text
	_confirm_button.text = confirm_text
	_cancel_button.text = cancel_text
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	position = Vector2.ZERO
	size = get_viewport_rect().size
	visible = true
	_is_open = true
	call_deferred("_focus_confirm_button")


func popup_centered(_minsize: Vector2 = Vector2.ZERO) -> void:
	popup_confirmation("Подтверждение", dialog_text, "Подтвердить", "Отмена")


func hide_dialog() -> void:
	visible = false
	_is_open = false


func is_open() -> bool:
	return _is_open


func _unhandled_input(event: InputEvent) -> void:
	if not _is_open:
		return

	if event.is_action_pressed("pause_menu") and not event.is_echo():
		_cancel()
		get_viewport().set_input_as_handled()
		return


func _build_ui() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.76)
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var shell := MarginContainer.new()
	shell.add_theme_constant_override("margin_left", 24)
	shell.add_theme_constant_override("margin_top", 24)
	shell.add_theme_constant_override("margin_right", 24)
	shell.add_theme_constant_override("margin_bottom", 24)
	center.add_child(shell)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(720.0, 0.0)
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.add_theme_stylebox_override("panel", _build_panel_style())
	shell.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 34)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_right", 34)
	margin.add_theme_constant_override("margin_bottom", 30)
	panel.add_child(margin)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 22)
	margin.add_child(content)

	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 28)
	content.add_child(_title_label)

	_message_label = Label.new()
	_message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_message_label.add_theme_font_size_override("font_size", 22)
	content.add_child(_message_label)

	var buttons_row := HBoxContainer.new()
	buttons_row.add_theme_constant_override("separation", 14)
	content.add_child(buttons_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons_row.add_child(spacer)

	_cancel_button = Button.new()
	_cancel_button.custom_minimum_size = Vector2(180.0, 58.0)
	_cancel_button.pressed.connect(_cancel)
	buttons_row.add_child(_cancel_button)

	_confirm_button = Button.new()
	_confirm_button.custom_minimum_size = Vector2(220.0, 58.0)
	_confirm_button.pressed.connect(_confirm)
	buttons_row.add_child(_confirm_button)


func _build_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.07, 0.11, 0.98)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.58, 0.68, 0.82, 1.0)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	return style


func _focus_confirm_button() -> void:
	if _confirm_button != null:
		_confirm_button.grab_focus()


func _confirm() -> void:
	hide_dialog()
	confirmed.emit()


func _cancel() -> void:
	hide_dialog()
	canceled.emit()
