class_name SleepDialog
extends CanvasLayer

signal sleep_confirmed(hours: int)
signal cancelled

const FADE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.25

@onready var overlay: Control = $Overlay
@onready var dimmer: ColorRect = $Overlay/Dimmer
@onready var center_container: CenterContainer = $Overlay/CenterContainer
@onready var title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var hours_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HoursRow/HoursLabel
@onready var hours_selector: SpinBox = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HoursRow/HoursSelector
@onready var preview_title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewTitleLabel
@onready var preview_energy_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewEnergyLabel
@onready var preview_hp_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewHpLabel
@onready var preview_hunger_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewHungerLabel
@onready var preview_time_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewTimeLabel
@onready var confirm_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/ConfirmButton
@onready var cancel_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/CancelButton
@onready var screen_fade: ColorRect = $SleepFade

var _min_hours := 1
var _max_hours := 12
var _default_hours := 1
var _sleep_results_provider := Callable()
var _is_busy := false
var _is_transition_running := false


func _ready() -> void:
	title_label.text = "\u0421\u043E\u043D"
	description_label.text = "\u0412\u044B\u0431\u0435\u0440\u0438\u0442\u0435, \u0441\u043A\u043E\u043B\u044C\u043A\u043E \u0447\u0430\u0441\u043E\u0432 \u0441\u043F\u0430\u0442\u044C"
	hours_label.text = "\u0427\u0430\u0441\u044B:"
	preview_title_label.text = "\u041F\u0440\u0435\u0434\u043F\u0440\u043E\u0441\u043C\u043E\u0442\u0440"
	confirm_button.text = "\u0421\u043F\u0430\u0442\u044C"
	cancel_button.text = "\u041E\u0442\u043C\u0435\u043D\u0430"
	_apply_hours_settings()
	var line_edit := hours_selector.get_line_edit()

	if line_edit != null:
		line_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER

	hours_selector.value_changed.connect(_on_hours_selector_value_changed)
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	_set_screen_fade_alpha(0.0)
	screen_fade.visible = false
	_refresh_preview()
	call_deferred("_grab_initial_focus")


func setup(min_hours: int = 1, max_hours: int = 12, default_hours: int = 1) -> void:
	_min_hours = max(1, min_hours)
	_max_hours = max(_min_hours, max_hours)
	_default_hours = clampi(default_hours, _min_hours, _max_hours)

	if is_inside_tree():
		_apply_hours_settings()


func set_sleep_results_provider(provider: Callable) -> void:
	_sleep_results_provider = provider

	if is_inside_tree():
		_refresh_preview()


func _unhandled_input(event: InputEvent) -> void:
	if _is_busy:
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		cancelled.emit()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		cancelled.emit()
		get_viewport().set_input_as_handled()


func get_selected_hours() -> int:
	if hours_selector == null:
		return _default_hours

	return int(roundi(hours_selector.value))


func _apply_hours_settings() -> void:
	if hours_selector == null:
		return

	hours_selector.min_value = float(_min_hours)
	hours_selector.max_value = float(_max_hours)
	hours_selector.step = 1.0
	hours_selector.allow_greater = false
	hours_selector.allow_lesser = false
	hours_selector.rounded = true
	hours_selector.value = float(_default_hours)
	_refresh_preview()


func _grab_initial_focus() -> void:
	if hours_selector != null:
		hours_selector.grab_focus()


func _on_confirm_button_pressed() -> void:
	if _is_busy:
		return

	_set_busy_state(true)
	sleep_confirmed.emit(get_selected_hours())


func _on_cancel_button_pressed() -> void:
	if _is_busy:
		return

	cancelled.emit()


func play_sleep_transition(apply_sleep_callback: Callable = Callable()) -> void:
	if _is_transition_running:
		return

	_is_transition_running = true
	_set_busy_state(true)
	screen_fade.visible = true
	await _tween_screen_fade(1.0, FADE_IN_DURATION)
	_set_dialog_content_visible(false)

	if apply_sleep_callback.is_valid():
		apply_sleep_callback.call()

	await _tween_screen_fade(0.0, FADE_OUT_DURATION)
	_is_transition_running = false
	screen_fade.visible = false


func _on_hours_selector_value_changed(_value: float) -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	if preview_energy_label == null:
		return

	var sleep_results := _get_sleep_results()
	var time_change_minutes := int(sleep_results.get("time_change_minutes", get_selected_hours() * 60))
	var time_change_hours := int(roundi(float(time_change_minutes) / 60.0))

	preview_energy_label.text = "\u042D\u043D\u0435\u0440\u0433\u0438\u044F: %s" % _format_signed_value(sleep_results.get("energy_change", 0.0))
	preview_hp_label.text = "HP: %s" % _format_signed_value(sleep_results.get("hp_change", 0))
	preview_hunger_label.text = "\u0413\u043E\u043B\u043E\u0434: %s" % _format_signed_value(sleep_results.get("hunger_change", 0))
	preview_time_label.text = "\u0412\u0440\u0435\u043C\u044F: %+d \u0447" % time_change_hours


func _get_sleep_results() -> Dictionary:
	if _sleep_results_provider.is_valid():
		var result: Variant = _sleep_results_provider.call(get_selected_hours())

		if result is Dictionary:
			return result

	return {
		"energy_change": 0.0,
		"hp_change": 0,
		"hunger_change": 0,
		"time_change_minutes": get_selected_hours() * 60,
	}


func _format_signed_value(value: Variant) -> String:
	if value is float:
		var float_value := float(value)

		if is_equal_approx(float_value, roundf(float_value)):
			return "%+d" % int(roundi(float_value))

		return "%+.1f" % float_value

	return "%+d" % int(value)


func _set_busy_state(is_busy: bool) -> void:
	_is_busy = is_busy

	if hours_selector != null:
		hours_selector.editable = not is_busy
		hours_selector.mouse_filter = Control.MOUSE_FILTER_STOP if not is_busy else Control.MOUSE_FILTER_IGNORE
		hours_selector.focus_mode = Control.FOCUS_ALL if not is_busy else Control.FOCUS_NONE

	if confirm_button != null:
		confirm_button.disabled = is_busy

	if cancel_button != null:
		cancel_button.disabled = is_busy


func _set_dialog_content_visible(visible_state: bool) -> void:
	if dimmer != null:
		dimmer.visible = visible_state

	if center_container != null:
		center_container.visible = visible_state


func _tween_screen_fade(target_alpha: float, duration: float) -> void:
	if screen_fade == null:
		return

	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(Callable(self, "_set_screen_fade_alpha"), screen_fade.color.a, target_alpha, duration)
	await tween.finished


func _set_screen_fade_alpha(alpha: float) -> void:
	if screen_fade == null:
		return

	var fade_color := screen_fade.color
	fade_color.a = clampf(alpha, 0.0, 1.0)
	screen_fade.color = fade_color
