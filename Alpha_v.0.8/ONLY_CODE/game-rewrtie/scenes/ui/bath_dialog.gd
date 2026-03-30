class_name BathDialog
extends CanvasLayer

signal bath_confirmed
signal cancelled

const FADE_IN_DURATION := 0.25
const FADE_OUT_DURATION := 0.25

@onready var dimmer: ColorRect = $Overlay/Dimmer
@onready var center_container: CenterContainer = $Overlay/CenterContainer
@onready var title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/TitleLabel
@onready var description_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var duration_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DurationRow/DurationLabel
@onready var duration_value_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/DurationRow/DurationValueLabel
@onready var preview_title_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewTitleLabel
@onready var preview_hygiene_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewHygieneLabel
@onready var preview_stage_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewStageLabel
@onready var preview_blood_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewBloodLabel
@onready var preview_finish_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewFinishLabel
@onready var preview_relief_label: Label = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/PreviewBlock/PreviewReliefLabel
@onready var confirm_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/ConfirmButton
@onready var cancel_button: Button = $Overlay/CenterContainer/PanelContainer/MarginContainer/VBoxContainer/ButtonsRow/CancelButton
@onready var screen_fade: ColorRect = $BathFade

var _bath_preview: Dictionary = {}
var _is_busy := false
var _is_transition_running := false


func _ready() -> void:
	title_label.text = "Ванна"
	duration_label.text = "Мытьё:"
	preview_title_label.text = "После ванны"
	confirm_button.text = "Мыться"
	cancel_button.text = "Отмена"
	confirm_button.pressed.connect(_on_confirm_button_pressed)
	cancel_button.pressed.connect(_on_cancel_button_pressed)
	_set_screen_fade_alpha(0.0)
	screen_fade.visible = false
	_refresh_preview()
	call_deferred("_grab_initial_focus")


func setup(bath_preview: Dictionary) -> void:
	_bath_preview = bath_preview.duplicate(true)

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


func play_bath_transition(apply_bath_callback: Callable = Callable()) -> void:
	if _is_transition_running:
		return

	_is_transition_running = true
	_set_busy_state(true)
	screen_fade.visible = true
	await _tween_screen_fade(1.0, FADE_IN_DURATION)
	_set_dialog_content_visible(false)

	if apply_bath_callback.is_valid():
		apply_bath_callback.call()

	await _tween_screen_fade(0.0, FADE_OUT_DURATION)
	_is_transition_running = false
	screen_fade.visible = false


func _refresh_preview() -> void:
	if duration_value_label == null:
		return

	var finish_day: int = int(_bath_preview.get("finish_day", 1))
	var finish_hour: int = int(_bath_preview.get("finish_hour", 0))
	var finish_minute: int = int(_bath_preview.get("finish_minute", 0))
	var stage_before: String = String(_bath_preview.get("stage_before_title", "грязь")).strip_edges()
	var stage_after: String = String(_bath_preview.get("stage_after_title", "чистота")).strip_edges()
	var blood_text: String = String(_bath_preview.get("blood_text", "Следов крови нет.")).strip_edges()
	var relief_text: String = String(_bath_preview.get("relief_text", "Тепло смоет липкую грязь и даст короткую передышку.")).strip_edges()

	description_label.text = "Горячая вода даст Рууне короткую передышку и смоет накопившуюся липкую грязь."
	duration_value_label.text = _format_bath_duration(
		int(_bath_preview.get("bath_duration_minutes", 45)),
		finish_hour,
		finish_minute
	)
	preview_hygiene_label.text = "Гигиена: %s" % String(_bath_preview.get("hygiene_delta_text", "+0"))
	preview_stage_label.text = "Состояние: %s -> %s" % [stage_before, stage_after]
	preview_blood_label.text = blood_text
	preview_finish_label.text = "Завершение: День %d, %02d:%02d" % [
		finish_day,
		finish_hour,
		finish_minute,
	]
	preview_relief_label.text = relief_text


func _format_bath_duration(total_minutes: int, finish_hour: int, finish_minute: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(floor(float(safe_minutes) / 60.0))
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%d м, до %02d:%02d" % [minutes, finish_hour, finish_minute]

	if minutes <= 0:
		return "%d ч, до %02d:%02d" % [hours, finish_hour, finish_minute]

	return "%d ч %02d м, до %02d:%02d" % [hours, minutes, finish_hour, finish_minute]


func _grab_initial_focus() -> void:
	if confirm_button != null:
		confirm_button.grab_focus()


func _on_confirm_button_pressed() -> void:
	if _is_busy:
		return

	_set_busy_state(true)
	bath_confirmed.emit()


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
