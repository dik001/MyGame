class_name ATMWindow
extends Control

signal close_requested()

const STATUS_COLOR_INFO := Color(0.82, 0.88, 0.97, 1.0)
const STATUS_COLOR_SUCCESS := Color(0.66, 1.0, 0.76, 1.0)
const STATUS_COLOR_ERROR := Color(1.0, 0.65, 0.65, 1.0)

@onready var title_label: Label = $Dim/Panel/MarginContainer/Content/HeaderRow/TitleLabel
@onready var close_button: Button = $Dim/Panel/MarginContainer/Content/HeaderRow/CloseButton
@onready var cash_label: Label = $Dim/Panel/MarginContainer/Content/SummaryPanel/MarginContainer/SummaryContent/CashLabel
@onready var bank_label: Label = $Dim/Panel/MarginContainer/Content/SummaryPanel/MarginContainer/SummaryContent/BankLabel
@onready var withdraw_section_label: Label = $Dim/Panel/MarginContainer/Content/WithdrawSectionLabel
@onready var quick_10_button: Button = $Dim/Panel/MarginContainer/Content/QuickButtonsRow/Quick10Button
@onready var quick_20_button: Button = $Dim/Panel/MarginContainer/Content/QuickButtonsRow/Quick20Button
@onready var quick_50_button: Button = $Dim/Panel/MarginContainer/Content/QuickButtonsRow/Quick50Button
@onready var quick_100_button: Button = $Dim/Panel/MarginContainer/Content/QuickButtonsRow/Quick100Button
@onready var quick_200_button: Button = $Dim/Panel/MarginContainer/Content/QuickButtonsRow/Quick200Button
@onready var amount_label: Label = $Dim/Panel/MarginContainer/Content/CustomRow/AmountLabel
@onready var amount_input: LineEdit = $Dim/Panel/MarginContainer/Content/CustomRow/AmountInput
@onready var withdraw_button: Button = $Dim/Panel/MarginContainer/Content/CustomRow/WithdrawButton
@onready var status_label: Label = $Dim/Panel/MarginContainer/Content/StatusLabel


func _ready() -> void:
	title_label.text = "Банкомат"
	withdraw_section_label.text = "Снять наличные"
	amount_label.text = "Сумма"
	withdraw_button.text = "Снять"
	close_button.text = "Закрыть"
	amount_input.placeholder_text = "Введите сумму"

	quick_10_button.text = "$10"
	quick_20_button.text = "$20"
	quick_50_button.text = "$50"
	quick_100_button.text = "$100"
	quick_200_button.text = "$200"

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if not withdraw_button.pressed.is_connected(_on_withdraw_button_pressed):
		withdraw_button.pressed.connect(_on_withdraw_button_pressed)

	if not amount_input.text_submitted.is_connected(_on_amount_input_text_submitted):
		amount_input.text_submitted.connect(_on_amount_input_text_submitted)

	if not quick_10_button.pressed.is_connected(_on_quick_withdraw_pressed.bind(10)):
		quick_10_button.pressed.connect(_on_quick_withdraw_pressed.bind(10))

	if not quick_20_button.pressed.is_connected(_on_quick_withdraw_pressed.bind(20)):
		quick_20_button.pressed.connect(_on_quick_withdraw_pressed.bind(20))

	if not quick_50_button.pressed.is_connected(_on_quick_withdraw_pressed.bind(50)):
		quick_50_button.pressed.connect(_on_quick_withdraw_pressed.bind(50))

	if not quick_100_button.pressed.is_connected(_on_quick_withdraw_pressed.bind(100)):
		quick_100_button.pressed.connect(_on_quick_withdraw_pressed.bind(100))

	if not quick_200_button.pressed.is_connected(_on_quick_withdraw_pressed.bind(200)):
		quick_200_button.pressed.connect(_on_quick_withdraw_pressed.bind(200))

	if not PlayerEconomy.cash_dollars_changed.is_connected(_on_cash_dollars_changed):
		PlayerEconomy.cash_dollars_changed.connect(_on_cash_dollars_changed)

	if not PlayerEconomy.bank_dollars_changed.is_connected(_on_bank_dollars_changed):
		PlayerEconomy.bank_dollars_changed.connect(_on_bank_dollars_changed)

	refresh_view()
	_show_status("", STATUS_COLOR_INFO)


func open_window() -> void:
	visible = true
	refresh_view()
	amount_input.clear()
	_show_status("", STATUS_COLOR_INFO)
	amount_input.grab_focus()


func close_window() -> void:
	visible = false


func refresh_view() -> void:
	cash_label.text = "Наличные: %s" % _format_money(PlayerEconomy.get_cash_dollars())
	bank_label.text = "На счете: %s" % _format_money(PlayerEconomy.get_bank_dollars())


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _withdraw_amount(amount: int) -> void:
	if amount <= 0:
		_show_status("Сумма должна быть больше нуля.", STATUS_COLOR_ERROR)
		return

	if not PlayerEconomy.can_withdraw_from_bank(amount):
		_show_status("На счете недостаточно денег для снятия.", STATUS_COLOR_ERROR)
		return

	if not PlayerEconomy.withdraw_bank_dollars(amount):
		_show_status("Не удалось снять деньги. Попробуйте снова.", STATUS_COLOR_ERROR)
		return

	amount_input.clear()
	_show_status("Снято наличными: %s" % _format_money(amount), STATUS_COLOR_SUCCESS)


func _parse_custom_amount() -> int:
	var amount_text: String = amount_input.text.strip_edges()

	if amount_text.is_empty():
		_show_status("Введите сумму для снятия.", STATUS_COLOR_ERROR)
		return -1

	if not amount_text.is_valid_int():
		_show_status("Введите целое число без символов и знаков.", STATUS_COLOR_ERROR)
		return -1

	return int(amount_text)


func _show_status(message: String, color: Color) -> void:
	status_label.text = message
	status_label.add_theme_color_override("font_color", color)
	status_label.visible = not message.is_empty()


func _format_money(amount: int) -> String:
	return "$%d" % max(0, amount)


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_withdraw_button_pressed() -> void:
	var amount: int = _parse_custom_amount()

	if amount < 0:
		return

	_withdraw_amount(amount)


func _on_amount_input_text_submitted(_new_text: String) -> void:
	_on_withdraw_button_pressed()


func _on_quick_withdraw_pressed(amount: int) -> void:
	_withdraw_amount(amount)


func _on_cash_dollars_changed(new_value: int) -> void:
	cash_label.text = "Наличные: %s" % _format_money(new_value)


func _on_bank_dollars_changed(new_value: int) -> void:
	bank_label.text = "На счете: %s" % _format_money(new_value)
