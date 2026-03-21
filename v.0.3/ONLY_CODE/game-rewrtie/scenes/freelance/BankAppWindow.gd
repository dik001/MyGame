class_name BankAppWindow
extends PanelContainer

signal close_requested()

const TRANSFER_ITEM_SCENE := preload("res://scenes/freelance/BankTransferItem.tscn")
const HISTORY_LIMIT: int = 20

@onready var title_label: Label = $MarginContainer/Content/HeaderRow/TitleLabel
@onready var balance_label: Label = $MarginContainer/Content/HeaderRow/BalanceLabel
@onready var close_button: Button = $MarginContainer/Content/HeaderRow/CloseButton
@onready var notification_title_label: Label = $MarginContainer/Content/NotificationPanel/MarginContainer/NotificationContent/NotificationHeaderRow/NotificationTitleLabel
@onready var clear_notification_button: Button = $MarginContainer/Content/NotificationPanel/MarginContainer/NotificationContent/NotificationHeaderRow/ClearNotificationButton
@onready var notification_label: Label = $MarginContainer/Content/NotificationPanel/MarginContainer/NotificationContent/NotificationLabel
@onready var history_title_label: Label = $MarginContainer/Content/HistoryTitleLabel
@onready var history_scroll: ScrollContainer = $MarginContainer/Content/HistoryScroll
@onready var transfer_history_list: VBoxContainer = $MarginContainer/Content/HistoryScroll/TransferHistoryList
@onready var empty_history_label: Label = $MarginContainer/Content/EmptyHistoryLabel

var _freelance_state: Node = null
var _player_economy: Node = null


func _ready() -> void:
	title_label.text = "Банк"
	notification_title_label.text = "Последний перевод"
	history_title_label.text = "История переводов"
	close_button.text = "Закрыть"
	clear_notification_button.text = "Очистить"

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if not clear_notification_button.pressed.is_connected(_on_clear_notification_button_pressed):
		clear_notification_button.pressed.connect(_on_clear_notification_button_pressed)

	_resolve_dependencies()
	_connect_state_signals()
	refresh_view()


func open_window() -> void:
	visible = true
	refresh_view()
	close_button.grab_focus()


func close_window() -> void:
	visible = false


func refresh_view() -> void:
	_resolve_dependencies()
	_connect_state_signals()
	_update_balance()
	_update_notification()
	_rebuild_history()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _resolve_dependencies() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")
	_player_economy = get_node_or_null("/root/PlayerEconomy")


func _connect_state_signals() -> void:
	if _freelance_state != null:
		_connect_optional_signal(_freelance_state, &"bank_history_changed", Callable(self, "_on_bank_history_changed"))

	if _player_economy != null:
		_connect_optional_signal(_player_economy, &"dollars_changed", Callable(self, "_on_dollars_changed"))


func _connect_optional_signal(target: Node, signal_name: StringName, callable: Callable) -> void:
	if target == null:
		return

	if not target.has_signal(signal_name):
		return

	if target.is_connected(signal_name, callable):
		return

	target.connect(signal_name, callable)


func _update_balance() -> void:
	if _player_economy == null or not _player_economy.has_method("get_dollars"):
		balance_label.text = "Баланс: --"
		return

	var dollars: int = int(_player_economy.call("get_dollars"))
	balance_label.text = "Баланс: %s" % _format_money(dollars)


func _update_notification() -> void:
	var notification_lines: PackedStringArray = []
	var last_notification: String = ""
	var can_clear_notification: bool = false

	if _freelance_state == null:
		notification_lines.append("FreelanceState недоступен. Уведомления банка не загружены.")
	else:
		if _freelance_state.has_method("get_last_bank_notification"):
			last_notification = String(_freelance_state.call("get_last_bank_notification")).strip_edges()

		if last_notification.is_empty():
			notification_lines.append("Новых переводов нет")
		else:
			notification_lines.append(last_notification)
			can_clear_notification = true

	if _player_economy == null:
		notification_lines.append("PlayerEconomy недоступен. Текущий баланс не загружен.")

	notification_label.text = "\n".join(notification_lines)
	clear_notification_button.disabled = not can_clear_notification


func _rebuild_history() -> void:
	_clear_container(transfer_history_list)

	if _freelance_state == null:
		history_scroll.visible = false
		empty_history_label.visible = true
		empty_history_label.text = "История переводов недоступна: FreelanceState не найден."
		return

	var history_entries: Array[Dictionary] = _get_bank_history_entries()
	var built_count: int = 0

	for entry in history_entries:
		var item_scene: Node = TRANSFER_ITEM_SCENE.instantiate()
		var item: Control = item_scene as Control

		if item == null:
			if item_scene != null:
				item_scene.queue_free()
			continue

		item.set_transfer_entry(entry)
		transfer_history_list.add_child(item)
		built_count += 1

	history_scroll.visible = built_count > 0
	empty_history_label.visible = built_count <= 0
	empty_history_label.text = "История переводов пуста"


func _get_bank_history_entries() -> Array[Dictionary]:
	if _freelance_state == null or not _freelance_state.has_method("get_bank_history"):
		return []

	var raw_history: Variant = _freelance_state.call("get_bank_history", HISTORY_LIMIT)
	return _normalize_transfer_history(raw_history)


func _normalize_transfer_history(raw_history: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not (raw_history is Array):
		return result

	for entry_variant in raw_history:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var has_amount: bool = entry.has("amount")
		var source: String = String(entry.get("source", "")).strip_edges()
		var order_title: String = String(entry.get("order_title", "")).strip_edges()

		if not has_amount:
			continue

		if source.is_empty() and order_title.is_empty():
			continue

		result.append(entry.duplicate(true))

	return result


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _format_money(amount: int) -> String:
	return "$%d" % max(0, amount)


func _on_clear_notification_button_pressed() -> void:
	if _freelance_state == null or not _freelance_state.has_method("clear_last_bank_notification"):
		return

	_freelance_state.call("clear_last_bank_notification")
	refresh_view()


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_bank_history_changed() -> void:
	refresh_view()


func _on_dollars_changed(new_value: int) -> void:
	balance_label.text = "Баланс: %s" % _format_money(new_value)
