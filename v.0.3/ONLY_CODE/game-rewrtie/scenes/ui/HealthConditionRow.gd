class_name HealthConditionRow
extends PanelContainer

@onready var title_label: Label = $MarginContainer/Content/HeaderRow/TitleLabel
@onready var status_label: Label = $MarginContainer/Content/HeaderRow/StatusLabel
@onready var description_label: Label = $MarginContainer/Content/DescriptionLabel

var _condition_entry: Dictionary = {}


func _ready() -> void:
	if not _condition_entry.is_empty():
		_refresh_view()


func set_condition_entry(entry: Dictionary) -> void:
	_condition_entry = entry.duplicate(true)

	if is_node_ready():
		_refresh_view()


func get_condition_entry() -> Dictionary:
	return _condition_entry.duplicate(true)


func _refresh_view() -> void:
	var title: String = String(_condition_entry.get("title", "Состояние")).strip_edges()
	var description: String = String(_condition_entry.get("description", "Описание отсутствует.")).strip_edges()
	var status_text: String = String(_condition_entry.get("status_text", "")).strip_edges()

	if title.is_empty():
		title = "Состояние"

	if description.is_empty():
		description = "Описание отсутствует."

	title_label.text = title
	description_label.text = description
	status_label.text = status_text
	status_label.visible = not status_text.is_empty()
	tooltip_text = "%s\n%s%s" % [
		title,
		description,
		"\n%s" % status_text if not status_text.is_empty() else "",
	]
