class_name DesktopInfoWindow
extends PanelContainer

signal close_requested()

@onready var title_label: Label = $MarginContainer/Content/TitleRow/TitleLabel
@onready var close_button: Button = $MarginContainer/Content/TitleRow/CloseButton
@onready var message_label: Label = $MarginContainer/Content/MessageLabel


func _ready() -> void:
	visible = false
	close_button.text = "Закрыть"

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)


func open_window(window_title: String = "Информация", message: String = "") -> void:
	set_content(window_title, message)
	visible = true
	close_button.grab_focus()


func close_window() -> void:
	visible = false


func set_content(window_title: String, message: String) -> void:
	title_label.text = window_title
	message_label.text = message


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _on_close_button_pressed() -> void:
	close_requested.emit()
