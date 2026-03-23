class_name BankTransferItem
extends PanelContainer

const MINUTES_PER_HOUR: int = 60
const MINUTES_PER_DAY: int = 24 * MINUTES_PER_HOUR

@onready var order_title_label: Label = $MarginContainer/Content/OrderTitleLabel
@onready var source_label: Label = $MarginContainer/Content/MetaRow/SourceLabel
@onready var time_label: Label = $MarginContainer/Content/MetaRow/TimeLabel
@onready var status_label: Label = $MarginContainer/Content/MetaRow/StatusLabel
@onready var amount_label: Label = $MarginContainer/Content/MetaRow/AmountLabel

var _transfer_entry: Dictionary = {}


func _ready() -> void:
	if not _transfer_entry.is_empty():
		_refresh_view()


func set_transfer_entry(entry: Dictionary) -> void:
	_transfer_entry = entry.duplicate(true)

	if is_node_ready():
		_refresh_view()


func get_transfer_entry() -> Dictionary:
	return _transfer_entry.duplicate(true)


func _refresh_view() -> void:
	var order_title: String = String(_transfer_entry.get("order_title", "Без названия")).strip_edges()

	if order_title.is_empty():
		order_title = "Без названия"

	var source: String = String(_transfer_entry.get("source", "")).strip_edges()
	var amount: int = int(_transfer_entry.get("amount", 0))
	var status: String = String(_transfer_entry.get("status", "credited")).strip_edges()

	order_title_label.text = order_title
	source_label.text = _format_source(source)
	time_label.text = _format_time_label(_transfer_entry)
	status_label.text = _format_status(status)
	status_label.add_theme_color_override("font_color", _get_status_color(status))
	amount_label.text = _format_money(amount)
	amount_label.add_theme_color_override("font_color", _get_amount_color(amount))
	tooltip_text = "%s\n%s\n%s\n%s" % [
		order_title_label.text,
		source_label.text,
		time_label.text,
		"%s  •  %s" % [status_label.text, amount_label.text],
	]


func _format_source(source: String) -> String:
	match source:
		"freelance":
			return "Источник: фриланс"
		"":
			return "Источник: неизвестно"
		_:
			return "Источник: %s" % source.capitalize()


func _format_status(status: String) -> String:
	match status:
		"credited":
			return "Зачислено"
		"pending":
			return "В обработке"
		"failed":
			return "Ошибка"
		_:
			return "Статус: %s" % status


func _format_money(amount: int) -> String:
	if amount >= 0:
		return "+$%d" % amount

	return "-$%d" % abs(amount)


func _format_time_label(entry: Dictionary) -> String:
	var absolute_minutes: int = int(entry.get("absolute_minutes", -1))

	if absolute_minutes >= 0:
		var day_id: int = int(absolute_minutes / MINUTES_PER_DAY) + 1
		var minutes_within_day: int = absolute_minutes % MINUTES_PER_DAY
		var hours: int = int(minutes_within_day / MINUTES_PER_HOUR)
		var minutes: int = minutes_within_day % MINUTES_PER_HOUR
		return "День %d • %02d:%02d" % [day_id, hours, minutes]

	var fallback_day: int = max(1, int(entry.get("day_id", 1)))
	return "День %d" % fallback_day


func _get_status_color(status: String) -> Color:
	match status:
		"credited":
			return Color(0.60, 0.95, 0.68, 1.0)
		"failed":
			return Color(1.0, 0.58, 0.58, 1.0)
		_:
			return Color(0.82, 0.88, 0.97, 1.0)


func _get_amount_color(amount: int) -> Color:
	if amount >= 0:
		return Color(0.66, 1.0, 0.76, 1.0)

	return Color(1.0, 0.65, 0.65, 1.0)
