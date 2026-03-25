class_name SleepDialog
extends CanvasLayer

signal sleep_confirmed
signal cancelled

const FADE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.25

@onready var dimmer: ColorRect = $Overlay/Dimmer
@onready var center_container: CenterContainer = $Overlay/CenterContainer
@onready var title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var hours_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HoursRow/HoursLabel
@onready var duration_value_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HoursRow/DurationValueLabel
@onready var hours_selector: SpinBox = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/HoursRow/HoursSelector
@onready var preview_title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewTitleLabel
@onready var preview_energy_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewEnergyLabel
@onready var preview_hp_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewHpLabel
@onready var preview_hunger_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewHungerLabel
@onready var preview_time_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewTimeLabel
@onready var day_income_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/DayIncomeLabel
@onready var day_expense_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/DayExpenseLabel
@onready var confirm_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/ConfirmButton
@onready var cancel_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/CancelButton
@onready var screen_fade: ColorRect = $SleepFade

var _sleep_preview: Dictionary = {}
var _is_busy := false
var _is_transition_running := false


func _ready() -> void:
	title_label.text = "Сон"
	preview_title_label.text = "После сна"
	confirm_button.text = "Спать"
	cancel_button.text = "Отмена"
	hours_label.text = "Сон:"

	if hours_selector != null:
		hours_selector.visible = false
		hours_selector.editable = false
		hours_selector.focus_mode = Control.FOCUS_NONE
		hours_selector.mouse_filter = Control.MOUSE_FILTER_IGNORE

	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	_set_screen_fade_alpha(0.0)
	screen_fade.visible = false
	_refresh_preview()
	call_deferred("_grab_initial_focus")


func setup(sleep_preview: Dictionary) -> void:
	_sleep_preview = sleep_preview.duplicate(true)

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


func _refresh_preview() -> void:
	if duration_value_label == null:
		return

	var wake_hour: int = int(_sleep_preview.get("wake_hour", 6))
	var wake_minute: int = int(_sleep_preview.get("wake_minute", 0))
	description_label.text = "Подъём в %02d:%02d. Короткий итог дня перед сном." % [wake_hour, wake_minute]
	duration_value_label.text = _format_sleep_duration(
		int(_sleep_preview.get("sleep_duration_minutes", 0)),
		wake_hour,
		wake_minute
	)
	preview_energy_label.text = "Энергия: %s" % _format_signed_value(_sleep_preview.get("energy_change", 0.0))
	preview_hp_label.text = "HP: %s" % _format_signed_value(_sleep_preview.get("hp_change", 0))
	preview_hunger_label.text = "Голод: %s" % _format_signed_value(_sleep_preview.get("hunger_change", 0))
	preview_time_label.text = "Подъём: День %d, %02d:%02d" % [
		int(_sleep_preview.get("wake_day", 1)),
		wake_hour,
		wake_minute,
	]
	day_income_label.text = "Доход за день: $%d" % int(_sleep_preview.get("daily_income", 0))
	day_expense_label.text = "Расходы за день: $%d" % int(_sleep_preview.get("daily_expenses", 0))


func _format_sleep_duration(total_minutes: int, wake_hour: int, wake_minute: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(floor(float(safe_minutes) / 60.0))
	var minutes: int = safe_minutes % 60

	if minutes <= 0:
		return "%d ч, до %02d:%02d" % [hours, wake_hour, wake_minute]

	return "%d ч %02d м, до %02d:%02d" % [hours, minutes, wake_hour, wake_minute]


func _format_signed_value(value: Variant) -> String:
	if value is float:
		var float_value := float(value)

		if is_equal_approx(float_value, roundf(float_value)):
			return "%+d" % int(roundi(float_value))

		return "%+.1f" % float_value

	return "%+d" % int(value)


func _grab_initial_focus() -> void:
	if confirm_button != null:
		confirm_button.grab_focus()


func _on_confirm_button_pressed() -> void:
	if _is_busy:
		return

	_set_busy_state(true)
	sleep_confirmed.emit()


func _on_cancel_button_pressed() -> void:
	if _is_busy:
		return

	cancelled.emit()


func _set_busy_state(is_busy: bool) -> void:
	_is_busy = is_busy

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
