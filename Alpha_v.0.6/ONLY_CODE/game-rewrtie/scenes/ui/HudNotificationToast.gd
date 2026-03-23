class_name HudNotificationToast
extends PanelContainer

const FADE_IN_DURATION: float = 0.16
const DEFAULT_VISIBLE_DURATION: float = 2.4
const FADE_OUT_DURATION: float = 0.22

@onready var message_label: Label = $MarginContainer/MessageLabel

var _message: String = ""
var _duration: float = DEFAULT_VISIBLE_DURATION
var _lifecycle_started: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if _message.is_empty() and message_label != null:
		_message = message_label.text

	if message_label != null:
		message_label.text = _message

	self_modulate = Color(1.0, 1.0, 1.0, 0.0)
	call_deferred("_begin_lifecycle")


func setup(message: String, duration: float = DEFAULT_VISIBLE_DURATION) -> void:
	_message = message.strip_edges()
	_duration = max(0.4, duration)

	if message_label != null:
		message_label.text = _message


func _begin_lifecycle() -> void:
	if _lifecycle_started:
		return

	_lifecycle_started = true

	if _message.is_empty():
		queue_free()
		return

	var fade_in_tween := create_tween()
	fade_in_tween.tween_property(self, "self_modulate:a", 1.0, FADE_IN_DURATION)
	await fade_in_tween.finished
	await get_tree().create_timer(_duration).timeout

	var fade_out_tween := create_tween()
	fade_out_tween.tween_property(self, "self_modulate:a", 0.0, FADE_OUT_DURATION)
	await fade_out_tween.finished
	queue_free()
