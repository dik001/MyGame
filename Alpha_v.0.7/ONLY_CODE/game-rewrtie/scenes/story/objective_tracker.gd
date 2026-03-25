extends PanelContainer

@onready var status_label: Label = $MarginContainer/Content/StatusLabel
@onready var title_label: Label = $MarginContainer/Content/TitleLabel
@onready var countdown_label: Label = $MarginContainer/Content/CountdownLabel
@onready var description_label: Label = $MarginContainer/Content/DescriptionLabel
@onready var details_label: Label = $MarginContainer/Content/DetailsLabel

var _current_objective: Dictionary = {}
var _reveal_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	if not StoryState.primary_objective_changed.is_connected(_on_primary_objective_changed):
		StoryState.primary_objective_changed.connect(_on_primary_objective_changed)

	if not GameTime.time_changed.is_connected(_on_game_time_changed):
		GameTime.time_changed.connect(_on_game_time_changed)

	_apply_objective(StoryState.get_primary_objective(), false)


func _on_primary_objective_changed(objective: Dictionary) -> void:
	_apply_objective(objective, true)


func _on_game_time_changed(_absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	if visible:
		_refresh_countdown()


func _apply_objective(objective: Dictionary, animate: bool) -> void:
	_current_objective = objective.duplicate(true)
	var title := String(_current_objective.get("title", "")).strip_edges()

	if title.is_empty():
		visible = false
		return

	visible = true
	status_label.text = "Основная цель"
	title_label.text = title

	var description := String(_current_objective.get("description", "")).strip_edges()
	description_label.text = description
	description_label.visible = not description.is_empty()

	var details_variant: Variant = _current_objective.get("details", [])
	var detail_lines: Array[String] = []

	if details_variant is Array:
		for detail in details_variant:
			var detail_text := String(detail).strip_edges()

			if detail_text.is_empty():
				continue

			detail_lines.append("- %s" % detail_text)

	details_label.text = "\n".join(detail_lines)
	details_label.visible = not detail_lines.is_empty()
	_refresh_countdown()

	if animate:
		_play_reveal_animation()


func _refresh_countdown() -> void:
	var metadata_variant: Variant = _current_objective.get("metadata", {})

	if not (metadata_variant is Dictionary):
		countdown_label.visible = false
		return

	var metadata := metadata_variant as Dictionary
	var start_day := int(metadata.get("start_day", 0))
	var deadline_day := int(metadata.get("deadline_day", 0))

	if start_day <= 0 or deadline_day <= 0:
		countdown_label.visible = false
		return

	var current_day: int = GameTime.get_day()
	var total_days: int = max(1, deadline_day - start_day + 1)
	var days_remaining: int = max(0, deadline_day - current_day + 1)
	var current_step := clampi(current_day - start_day + 1, 1, total_days)

	if days_remaining <= 0:
		countdown_label.text = "Срок вышел"
	else:
		countdown_label.text = "День %d из %d | Осталось: %d" % [current_step, total_days, days_remaining]

	countdown_label.visible = true


func _play_reveal_animation() -> void:
	if _reveal_tween != null and is_instance_valid(_reveal_tween):
		_reveal_tween.kill()

	modulate = Color(1.0, 1.0, 1.0, 0.0)
	position = Vector2(18.0, 0.0)
	_reveal_tween = create_tween()
	_reveal_tween.set_parallel(true)
	_reveal_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.22)
	_reveal_tween.tween_property(self, "position", Vector2.ZERO, 0.22)
