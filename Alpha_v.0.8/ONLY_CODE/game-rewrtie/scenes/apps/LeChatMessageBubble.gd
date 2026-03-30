class_name LeChatMessageBubble
extends Control

const MINUTES_PER_DAY: int = 24 * 60
const MIN_BUBBLE_HEIGHT := 92.0

const COLOR_INCOMING_BACKGROUND := Color(0.047, 0.101, 0.145, 1.0)
const COLOR_INCOMING_BORDER := Color(0.235, 0.439, 0.561, 1.0)
const COLOR_OUTGOING_BACKGROUND := Color(0.035, 0.165, 0.173, 1.0)
const COLOR_OUTGOING_BORDER := Color(0.349, 0.867, 0.878, 1.0)
const COLOR_NOTICE_BACKGROUND := Color(0.156, 0.094, 0.031, 1.0)
const COLOR_NOTICE_BORDER := Color(0.949, 0.678, 0.247, 1.0)
const COLOR_TEXT := Color(0.93, 0.96, 0.99, 1.0)
const COLOR_META := Color(0.67, 0.79, 0.86, 1.0)

@onready var left_spacer: Control = $AlignmentRow/LeftSpacer
@onready var alignment_row: HBoxContainer = $AlignmentRow
@onready var bubble_holder: VBoxContainer = $AlignmentRow/BubbleHolder
@onready var bubble_panel: PanelContainer = $AlignmentRow/BubbleHolder/BubblePanel
@onready var sender_label: Label = $AlignmentRow/BubbleHolder/BubblePanel/BubbleMargin/BubbleContent/SenderLabel
@onready var message_label: Label = $AlignmentRow/BubbleHolder/BubblePanel/BubbleMargin/BubbleContent/MessageLabel
@onready var meta_label: Label = $AlignmentRow/BubbleHolder/BubblePanel/BubbleMargin/BubbleContent/MetaLabel
@onready var right_spacer: Control = $AlignmentRow/RightSpacer

var _message_data: Dictionary = {}


func _ready() -> void:
	_apply_message_data()


func set_message_data(message_data: Dictionary) -> void:
	_message_data = message_data.duplicate(true)

	if is_node_ready():
		_apply_message_data()


func _apply_message_data() -> void:
	var is_outgoing: bool = bool(_message_data.get("is_outgoing", false))
	var sender_name: String = String(_message_data.get("sender_display_name", "")).strip_edges()
	var message_text: String = String(_message_data.get("text", "")).strip_edges()
	var message_type: String = String(_message_data.get("type", "message")).strip_edges()

	if sender_name.is_empty():
		sender_name = "Вы" if is_outgoing else "Арендодатель"

	message_label.text = message_text
	sender_label.text = sender_name
	sender_label.visible = not is_outgoing or _is_notice_message(message_type)
	meta_label.text = _build_meta_text()
	meta_label.visible = not meta_label.text.is_empty()

	_apply_alignment(is_outgoing)
	_apply_colors(is_outgoing, message_type)
	call_deferred("_refresh_layout")


func _get_minimum_size() -> Vector2:
	if alignment_row == null or not is_instance_valid(alignment_row):
		return Vector2(0.0, MIN_BUBBLE_HEIGHT)

	var content_size: Vector2 = alignment_row.get_combined_minimum_size()
	return Vector2(0.0, max(MIN_BUBBLE_HEIGHT, content_size.y))


func _refresh_layout() -> void:
	update_minimum_size()


func _apply_alignment(is_outgoing: bool) -> void:
	left_spacer.size_flags_stretch_ratio = 0.76 if is_outgoing else 0.24
	bubble_holder.size_flags_stretch_ratio = 1.08
	right_spacer.size_flags_stretch_ratio = 0.24 if is_outgoing else 0.76

	sender_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_outgoing else HORIZONTAL_ALIGNMENT_LEFT
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_outgoing else HORIZONTAL_ALIGNMENT_LEFT


func _apply_colors(is_outgoing: bool, message_type: String) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	var background_color: Color = COLOR_OUTGOING_BACKGROUND if is_outgoing else COLOR_INCOMING_BACKGROUND
	var border_color: Color = COLOR_OUTGOING_BORDER if is_outgoing else COLOR_INCOMING_BORDER

	if _is_notice_message(message_type):
		background_color = COLOR_NOTICE_BACKGROUND
		border_color = COLOR_NOTICE_BORDER
	elif message_type == "rent_due":
		border_color = Color(0.922, 0.745, 0.290, 1.0)
	elif message_type == "rent_overdue":
		border_color = Color(0.933, 0.424, 0.341, 1.0)
	elif message_type == "rent_paid":
		border_color = Color(0.506, 0.922, 0.592, 1.0)

	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_detail = 1
	style.anti_aliasing = false

	bubble_panel.add_theme_stylebox_override("panel", style)
	sender_label.add_theme_color_override("font_color", border_color.lightened(0.18))
	message_label.add_theme_color_override("font_color", COLOR_TEXT)
	meta_label.add_theme_color_override("font_color", COLOR_META)


func _build_meta_text() -> String:
	var absolute_minutes: int = int(_message_data.get("absolute_minutes", -1))
	var day: int = int(_message_data.get("day", -1))
	var parts: PackedStringArray = []

	if absolute_minutes >= 0:
		var derived_day: int = int(absolute_minutes / float(MINUTES_PER_DAY)) + 1
		var minutes_in_day: int = absolute_minutes % MINUTES_PER_DAY
		var hours: int = int(minutes_in_day / 60.0)
		var minutes: int = minutes_in_day % 60

		if day <= 0:
			day = derived_day

		parts.append("%02d:%02d" % [hours, minutes])

	if day > 0:
		parts.insert(0, "День %d" % day)

	return " - ".join(parts)


func _is_notice_message(message_type: String) -> bool:
	return message_type == "local_notice"
