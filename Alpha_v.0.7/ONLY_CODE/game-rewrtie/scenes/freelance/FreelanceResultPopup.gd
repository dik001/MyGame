class_name FreelanceResultPopup
extends Control

signal continue_requested()

@onready var title_label: Label = $Dim/Panel/MarginContainer/Content/TitleLabel
@onready var status_label: Label = $Dim/Panel/MarginContainer/Content/StatusLabel
@onready var accuracy_label: Label = $Dim/Panel/MarginContainer/Content/AccuracyLabel
@onready var reward_label: Label = $Dim/Panel/MarginContainer/Content/RewardLabel
@onready var energy_spent_label: Label = $Dim/Panel/MarginContainer/Content/EnergySpentLabel
@onready var time_spent_label: Label = $Dim/Panel/MarginContainer/Content/TimeSpentLabel
@onready var rating_delta_label: Label = $Dim/Panel/MarginContainer/Content/RatingDeltaLabel
@onready var xp_gain_label: Label = $Dim/Panel/MarginContainer/Content/XpGainLabel
@onready var continue_button: Button = $Dim/Panel/MarginContainer/Content/ContinueButton


func _ready() -> void:
	visible = false

	if not continue_button.pressed.is_connected(_on_continue_button_pressed):
		continue_button.pressed.connect(_on_continue_button_pressed)


func open_popup(result: Dictionary) -> void:
	_apply_result(result)
	visible = true
	continue_button.grab_focus()


func close_popup() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_accept") and not event.is_echo():
		continue_requested.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		continue_requested.emit()
		get_viewport().set_input_as_handled()


func _apply_result(result: Dictionary) -> void:
	var title: String = String(result.get("title", "Результат заказа")).strip_edges()

	if title.is_empty():
		title = "Результат заказа"

	var result_status: String = String(result.get("result_status", "normal"))
	var accuracy: float = clampf(float(result.get("accuracy", 0.0)), 0.0, 1.0)
	var payout: int = max(0, int(result.get("payout", 0)))
	var energy_delta: float = float(result.get("energy_delta", 0.0))
	var time_spent_minutes: int = max(0, int(result.get("time_spent_minutes", 0)))
	var rating_delta: int = int(result.get("rating_delta", 0))
	var xp_gained: int = max(0, int(result.get("xp_gained", 0)))

	title_label.text = title
	status_label.text = _format_status_text(result_status)
	status_label.add_theme_color_override("font_color", _get_status_color(result_status))
	accuracy_label.text = "Точность: %s" % _format_accuracy(accuracy)
	reward_label.text = "На счет зачислено: $%d" % payout
	energy_spent_label.text = "Энергия: -%d" % int(round(absf(energy_delta)))
	time_spent_label.text = "Рабочее время: %s" % _format_duration(time_spent_minutes)
	rating_delta_label.text = "Рейтинг: %s" % _format_signed_value(rating_delta)
	rating_delta_label.add_theme_color_override("font_color", _get_signed_color(rating_delta))
	xp_gain_label.text = "Опыт: +%d XP" % xp_gained
	xp_gain_label.add_theme_color_override("font_color", _get_signed_color(xp_gained))


func _format_status_text(result_status: String) -> String:
	match result_status:
		"excellent":
			return "Статус: отлично"
		"fail":
			return "Статус: провал"
		_:
			return "Статус: выполнено"


func _format_accuracy(accuracy: float) -> String:
	return "%d%%" % int(round(accuracy * 100.0))


func _format_duration(total_minutes: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(safe_minutes / 60.0)
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%dм" % minutes

	return "%dч %02dм" % [hours, minutes]


func _format_signed_value(value: int) -> String:
	if value > 0:
		return "+%d" % value

	return "%d" % value


func _get_status_color(result_status: String) -> Color:
	match result_status:
		"excellent":
			return Color(0.95, 0.88, 0.54, 1.0)
		"fail":
			return Color(1.0, 0.56, 0.56, 1.0)
		_:
			return Color(0.72, 0.92, 1.0, 1.0)


func _get_signed_color(value: int) -> Color:
	if value > 0:
		return Color(0.60, 0.95, 0.68, 1.0)

	if value < 0:
		return Color(1.0, 0.58, 0.58, 1.0)

	return Color(0.85, 0.88, 0.96, 1.0)


func _on_continue_button_pressed() -> void:
	continue_requested.emit()
