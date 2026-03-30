class_name StatusConditionRow
extends Button

signal condition_selected(condition_id: String)

@onready var title_label: Label = $MarginContainer/Content/TitleLabel
@onready var status_label: Label = $MarginContainer/Content/StatusLabel

var _condition_entry: Dictionary = {}
var _condition_id := ""


func _ready() -> void:
	if not _condition_entry.is_empty():
		_refresh_view()


func bind_condition(entry: Dictionary) -> void:
	_condition_entry = entry.duplicate(true)
	_condition_id = String(_condition_entry.get("id", "")).strip_edges()

	if is_node_ready():
		_refresh_view()


func get_condition_id() -> String:
	return _condition_id


func set_selected(is_selected: bool) -> void:
	set_pressed_no_signal(is_selected)


func _pressed() -> void:
	if _condition_id.is_empty():
		return

	condition_selected.emit(_condition_id)


func _refresh_view() -> void:
	var title: String = String(_condition_entry.get("title", "Состояние")).strip_edges()
	var status_text: String = String(_condition_entry.get("status_text", "")).strip_edges()

	if title.is_empty():
		title = "Состояние"

	title_label.text = title
	status_label.text = status_text
	status_label.visible = not status_text.is_empty()
	tooltip_text = "%s%s" % [
		title,
		"\n%s" % status_text if not status_text.is_empty() else "",
	]
