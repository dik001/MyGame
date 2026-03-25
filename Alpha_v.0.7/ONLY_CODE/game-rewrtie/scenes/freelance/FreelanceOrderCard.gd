class_name FreelanceOrderCard
extends Button

signal selected(order_id: int)

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var urgent_label: Label = $MarginContainer/Content/TitleRow/UrgentLabel
@onready var difficulty_label: Label = $MarginContainer/Content/InfoRow/DifficultyLabel
@onready var reward_label: Label = $MarginContainer/Content/InfoRow/RewardLabel
@onready var duration_label: Label = $MarginContainer/Content/InfoRow/DurationLabel
@onready var status_label: Label = $MarginContainer/Content/StatusLabel

var _order_data: Dictionary = {}


func _ready() -> void:
	if not _order_data.is_empty():
		_refresh_view()


func set_order_data(data: Dictionary) -> void:
	_order_data = data.duplicate(true)

	if is_node_ready():
		_refresh_view()


func get_order_data() -> Dictionary:
	return _order_data.duplicate(true)


func get_order_id() -> int:
	return int(_order_data.get("id", -1))


func set_selected(is_selected: bool) -> void:
	button_pressed = is_selected


func _pressed() -> void:
	var order_id: int = get_order_id()

	if order_id < 0:
		return

	selected.emit(order_id)


func _refresh_view() -> void:
	var title: String = String(_order_data.get("title", "Без названия")).strip_edges()

	if title.is_empty():
		title = "Без названия"

	var difficulty: String = String(_order_data.get("difficulty", "easy"))
	var reward_estimate: int = max(0, int(_order_data.get("reward_final_estimate", _order_data.get("reward_base", 0))))
	var duration_minutes: int = max(0, int(_order_data.get("duration_minutes", 0)))
	var status: String = String(_order_data.get("status", "available"))
	var is_urgent: bool = bool(_order_data.get("is_urgent", false))

	title_label.text = title
	difficulty_label.text = _format_difficulty(difficulty)
	reward_label.text = "Доход: ~$%d" % reward_estimate
	duration_label.text = "Время: %s" % _format_duration(duration_minutes)
	urgent_label.visible = is_urgent
	status_label.visible = status != "available"
	status_label.text = _format_status(status)
	tooltip_text = "%s\n%s\n%s\n%s" % [
		title,
		difficulty_label.text,
		reward_label.text,
		duration_label.text,
	]


func _format_difficulty(difficulty: String) -> String:
	match difficulty:
		"hard":
			return "Сложность: высокая"
		"medium":
			return "Сложность: средняя"
		_:
			return "Сложность: низкая"


func _format_status(status: String) -> String:
	match status:
		"completed":
			return "Выполнен"
		"failed":
			return "Провален"
		_:
			return ""


func _format_duration(total_minutes: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(safe_minutes / 60.0)
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%dм" % minutes

	return "%dч %02dм" % [hours, minutes]
