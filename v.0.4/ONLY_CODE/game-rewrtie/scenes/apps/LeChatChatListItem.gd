class_name LeChatChatListItem
extends Button

signal chosen(chat_id: String)

const COLOR_BACKGROUND_NORMAL := Color(0.030, 0.072, 0.105, 1.0)
const COLOR_BACKGROUND_HOVER := Color(0.052, 0.108, 0.158, 1.0)
const COLOR_BACKGROUND_SELECTED := Color(0.078, 0.188, 0.255, 1.0)
const COLOR_BORDER_NORMAL := Color(0.180, 0.384, 0.463, 1.0)
const COLOR_BORDER_SELECTED := Color(0.357, 0.812, 0.906, 1.0)
const COLOR_TITLE_NORMAL := Color(0.91, 0.95, 0.98, 1.0)
const COLOR_TITLE_SELECTED := Color(0.98, 1.0, 1.0, 1.0)
const COLOR_PREVIEW_NORMAL := Color(0.64, 0.75, 0.82, 1.0)
const COLOR_PREVIEW_SELECTED := Color(0.84, 0.95, 0.98, 1.0)
const COLOR_BADGE_BACKGROUND := Color(0.016, 0.492, 0.531, 1.0)
const COLOR_BADGE_BORDER := Color(0.533, 0.957, 0.984, 1.0)

@onready var title_label: Label = $MarginContainer/ContentRow/TextColumn/TitleLabel
@onready var preview_label: Label = $MarginContainer/ContentRow/TextColumn/PreviewLabel
@onready var unread_badge_panel: PanelContainer = $MarginContainer/ContentRow/UnreadBadgePanel
@onready var unread_label: Label = $MarginContainer/ContentRow/UnreadBadgePanel/UnreadBadgeMargin/UnreadLabel

var _chat_data: Dictionary = {}
var _is_selected: bool = false


func _ready() -> void:
	text = ""
	focus_mode = Control.FOCUS_NONE

	if not pressed.is_connected(_on_pressed):
		pressed.connect(_on_pressed)

	_apply_chat_data()


func set_chat_data(chat_data: Dictionary) -> void:
	_chat_data = chat_data.duplicate(true)

	if is_node_ready():
		_apply_chat_data()


func set_selected(is_selected: bool) -> void:
	_is_selected = is_selected

	if is_node_ready():
		_apply_selection_state()


func _apply_chat_data() -> void:
	var title: String = String(_chat_data.get("display_name", "Чат")).strip_edges()
	var preview: String = String(_chat_data.get("preview", "")).strip_edges()
	var unread_count: int = max(0, int(_chat_data.get("unread_count", 0)))

	title_label.text = title if not title.is_empty() else "Чат"
	preview_label.text = preview if not preview.is_empty() else "Нет сообщений"
	unread_badge_panel.visible = unread_count > 0
	unread_label.text = "%d" % unread_count

	_apply_selection_state()


func _apply_selection_state() -> void:
	var normal_style: StyleBoxFlat = _build_style(
		COLOR_BACKGROUND_SELECTED if _is_selected else COLOR_BACKGROUND_NORMAL,
		COLOR_BORDER_SELECTED if _is_selected else COLOR_BORDER_NORMAL
	)
	var hover_style: StyleBoxFlat = _build_style(
		COLOR_BACKGROUND_SELECTED.lightened(0.06) if _is_selected else COLOR_BACKGROUND_HOVER,
		COLOR_BORDER_SELECTED if _is_selected else COLOR_BORDER_NORMAL.lightened(0.08)
	)
	var pressed_style: StyleBoxFlat = _build_style(
		COLOR_BACKGROUND_SELECTED.darkened(0.08) if _is_selected else COLOR_BACKGROUND_HOVER.darkened(0.10),
		COLOR_BORDER_SELECTED if _is_selected else COLOR_BORDER_NORMAL.lightened(0.15)
	)

	add_theme_stylebox_override("normal", normal_style)
	add_theme_stylebox_override("hover", hover_style)
	add_theme_stylebox_override("pressed", pressed_style)
	add_theme_stylebox_override("focus", hover_style)
	add_theme_stylebox_override("disabled", normal_style)

	title_label.add_theme_color_override("font_color", COLOR_TITLE_SELECTED if _is_selected else COLOR_TITLE_NORMAL)
	preview_label.add_theme_color_override("font_color", COLOR_PREVIEW_SELECTED if _is_selected else COLOR_PREVIEW_NORMAL)
	unread_badge_panel.add_theme_stylebox_override("panel", _build_badge_style())


func _build_style(background_color: Color, border_color: Color) -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = background_color
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = border_color
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.corner_radius_bottom_right = 14
	style.corner_radius_bottom_left = 14
	style.corner_detail = 1
	style.anti_aliasing = false
	return style


func _build_badge_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()

	style.bg_color = COLOR_BADGE_BACKGROUND
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = COLOR_BADGE_BORDER
	style.corner_radius_top_left = 10
	style.corner_radius_top_right = 10
	style.corner_radius_bottom_right = 10
	style.corner_radius_bottom_left = 10
	style.corner_detail = 1
	style.anti_aliasing = false
	return style


func _on_pressed() -> void:
	chosen.emit(String(_chat_data.get("chat_id", "")))
