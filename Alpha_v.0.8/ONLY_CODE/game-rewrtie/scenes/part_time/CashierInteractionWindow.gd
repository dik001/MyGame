class_name CashierInteractionWindow
extends Control

signal shop_selected
signal job_selected
signal closed

@onready var title_label: Label = $Dim/Panel/MarginContainer/Content/TitleLabel
@onready var subtitle_label: Label = $Dim/Panel/MarginContainer/Content/SubtitleLabel
@onready var shop_button: Button = $Dim/Panel/MarginContainer/Content/ButtonsColumn/ShopButton
@onready var job_button: Button = $Dim/Panel/MarginContainer/Content/ButtonsColumn/JobButton
@onready var close_button: Button = $Dim/Panel/MarginContainer/Content/ButtonsColumn/CloseButton
@onready var hint_label: Label = $Dim/Panel/MarginContainer/Content/HintLabel


func _ready() -> void:
	visible = false
	title_label.text = "Касса"
	subtitle_label.text = "Что тебе нужно?"
	shop_button.text = "Магазин"
	job_button.text = "Подработка"
	close_button.text = "Закрыть"
	hint_label.text = "Подработка: сортировка мусора, только утром."

	if not shop_button.pressed.is_connected(_on_shop_button_pressed):
		shop_button.pressed.connect(_on_shop_button_pressed)

	if not job_button.pressed.is_connected(_on_job_button_pressed):
		job_button.pressed.connect(_on_job_button_pressed)

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)


func open_window() -> void:
	visible = true
	shop_button.grab_focus()


func close_window() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("pause_menu") and not event.is_echo():
		closed.emit()
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		closed.emit()
		get_viewport().set_input_as_handled()


func _on_shop_button_pressed() -> void:
	shop_selected.emit()


func _on_job_button_pressed() -> void:
	job_selected.emit()


func _on_close_button_pressed() -> void:
	closed.emit()
