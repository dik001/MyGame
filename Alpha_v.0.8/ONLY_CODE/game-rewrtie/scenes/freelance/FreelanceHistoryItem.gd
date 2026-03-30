class_name FreelanceHistoryItem
extends PanelContainer

@onready var title_label: Label = $MarginContainer/Content/TitleLabel
@onready var meta_label: Label = $MarginContainer/Content/MetaLabel

var _history_entry: Dictionary = {}


func _ready() -> void:
	if not _history_entry.is_empty():
		_refresh_view()


func set_history_entry(entry: Dictionary) -> void:
	_history_entry = entry.duplicate(true)

	if is_node_ready():
		_refresh_view()


func get_history_entry() -> Dictionary:
	return _history_entry.duplicate(true)


func _refresh_view() -> void:
	var title: String = String(_history_entry.get("title", "Без названия")).strip_edges()

	if title.is_empty():
		title = "Без названия"

	var result_status: String = String(_history_entry.get("result_status", "normal"))
	var accuracy: float = clampf(float(_history_entry.get("accuracy", 0.0)), 0.0, 1.0)
	var time_spent_minutes: int = max(0, int(_history_entry.get("time_spent_minutes", 0)))

	title_label.text = title
	meta_label.text = "%s  •  Точность: %s  •  Время: %s" % [
		_format_result_status(result_status),
		_format_accuracy(accuracy),
		_format_duration(time_spent_minutes),
	]
	tooltip_text = "%s\n%s" % [title_label.text, meta_label.text]


func _format_result_status(result_status: String) -> String:
	match result_status:
		"excellent":
			return "Результат: отлично"
		"fail":
			return "Результат: провал"
		_:
			return "Результат: нормально"


func _format_accuracy(accuracy: float) -> String:
	return "%d%%" % int(round(accuracy * 100.0))


func _format_duration(total_minutes: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(safe_minutes / 60.0)
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%dм" % minutes

	return "%dч %02dм" % [hours, minutes]
