class_name FreelanceAppWindow
extends PanelContainer

signal close_requested()
signal request_start_order(order_id: int)

const ORDER_CARD_SCENE := preload("res://scenes/freelance/FreelanceOrderCard.tscn")
const HISTORY_ITEM_SCENE := preload("res://scenes/freelance/FreelanceHistoryItem.tscn")
const WORKDAY_START_HOUR: int = 6
const WORKDAY_CLOSE_HOUR: int = 22

@onready var title_label: Label = $MarginContainer/Content/HeaderRow/TitleLabel
@onready var level_label: Label = $MarginContainer/Content/HeaderRow/LevelLabel
@onready var xp_label: Label = $MarginContainer/Content/HeaderRow/XpLabel
@onready var rating_label: Label = $MarginContainer/Content/HeaderRow/RatingLabel
@onready var completed_today_label: Label = $MarginContainer/Content/HeaderRow/CompletedTodayLabel
@onready var close_button: Button = $MarginContainer/Content/HeaderRow/CloseButton
@onready var workday_state_label: Label = $MarginContainer/Content/WorkdayPanel/WorkdayStateLabel
@onready var orders_scroll: ScrollContainer = $MarginContainer/Content/ContentRow/OrdersPanel/MarginContainer/OrdersColumn/OrdersScroll
@onready var orders_list: VBoxContainer = $MarginContainer/Content/ContentRow/OrdersPanel/MarginContainer/OrdersColumn/OrdersScroll/OrdersList
@onready var empty_orders_label: Label = $MarginContainer/Content/ContentRow/OrdersPanel/MarginContainer/OrdersColumn/EmptyOrdersLabel
@onready var selected_title_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedTitleLabel
@onready var selected_difficulty_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedDifficultyLabel
@onready var selected_comments_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedCommentsLabel
@onready var selected_duration_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedDurationLabel
@onready var selected_energy_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedEnergyLabel
@onready var selected_reward_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedRewardLabel
@onready var selected_urgent_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedUrgentLabel
@onready var selected_day_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedDayLabel
@onready var selected_availability_label: Label = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/SelectedAvailabilityLabel
@onready var start_order_button: Button = $MarginContainer/Content/ContentRow/DetailsPanel/MarginContainer/DetailsColumn/StartOrderButton
@onready var history_scroll: ScrollContainer = $MarginContainer/Content/HistoryPanel/MarginContainer/HistorySection/HistoryScroll
@onready var history_list: VBoxContainer = $MarginContainer/Content/HistoryPanel/MarginContainer/HistorySection/HistoryScroll/HistoryList
@onready var empty_history_label: Label = $MarginContainer/Content/HistoryPanel/MarginContainer/HistorySection/EmptyHistoryLabel

var _freelance_state: Node = null
var _selected_order_id: int = -1
var _order_cards_by_id: Dictionary = {}


func _ready() -> void:
	title_label.text = "Фриланс"

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if not start_order_button.pressed.is_connected(_on_start_order_button_pressed):
		start_order_button.pressed.connect(_on_start_order_button_pressed)

	_resolve_freelance_state()
	_connect_state_signals()
	refresh_view()


func open_window() -> void:
	visible = true
	refresh_view()
	close_button.grab_focus()


func close_window() -> void:
	visible = false


func refresh() -> void:
	refresh_view()


func refresh_view() -> void:
	_resolve_freelance_state()
	_connect_state_signals()

	if _freelance_state == null:
		_render_missing_state()
		return

	var snapshot: Dictionary = _build_snapshot()
	var orders: Array[Dictionary] = _extract_orders(snapshot)
	var history_entries: Array[Dictionary] = _extract_history(snapshot)
	var can_start_new_order: bool = _extract_can_start_new_order(snapshot, orders)

	_update_header(snapshot)
	_update_workday_state_label(orders, can_start_new_order)
	_rebuild_orders_list(orders)
	_update_selected_order_details(orders)
	_rebuild_history(history_entries)


func select_first_available_order() -> void:
	var orders: Array[Dictionary] = _extract_orders(_build_snapshot())

	if orders.is_empty():
		_selected_order_id = -1
	else:
		_selected_order_id = _find_first_available_order_id(orders)

		if _selected_order_id < 0:
			_selected_order_id = _find_first_valid_order_id(orders)

	_refresh_order_card_selection()
	_update_selected_order_details(orders)


func set_status_message(text: String) -> void:
	workday_state_label.text = text


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _resolve_freelance_state() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")


func _connect_state_signals() -> void:
	if _freelance_state == null:
		return

	_connect_optional_state_signal(&"orders_changed")
	_connect_optional_state_signal(&"history_changed")
	_connect_optional_state_signal(&"service_rating_changed")
	_connect_optional_state_signal(&"skill_changed")
	_connect_optional_state_signal(&"conditions_changed")
	_connect_optional_state_signal(&"day_orders_generated")


func _connect_optional_state_signal(signal_name: StringName) -> void:
	if _freelance_state == null:
		return

	if not _freelance_state.has_signal(signal_name):
		return

	var refresh_callable: Callable = Callable(self, "_on_state_changed")

	if _freelance_state.is_connected(signal_name, refresh_callable):
		return

	_freelance_state.connect(signal_name, refresh_callable)


func _build_snapshot() -> Dictionary:
	if _freelance_state == null:
		return {}

	if not _freelance_state.has_method("get_debug_snapshot"):
		return {}

	var raw_snapshot: Variant = _freelance_state.call("get_debug_snapshot")

	if raw_snapshot is Dictionary:
		return raw_snapshot

	return {}


func _extract_orders(snapshot: Dictionary) -> Array[Dictionary]:
	var raw_orders: Variant = snapshot.get("current_day_orders", null)

	if raw_orders == null:
		raw_orders = _call_state(&"get_current_orders")

	return _normalize_order_list(raw_orders)


func _extract_history(snapshot: Dictionary) -> Array[Dictionary]:
	var raw_history: Variant = snapshot.get("recent_history", null)

	if raw_history == null:
		raw_history = _call_state(&"get_recent_history", [10])

	return _normalize_history_list(raw_history)


func _extract_can_start_new_order(snapshot: Dictionary, orders: Array[Dictionary]) -> bool:
	if snapshot.has("can_start_new_order"):
		return bool(snapshot.get("can_start_new_order", false))

	if _freelance_state != null and _freelance_state.has_method("can_start_new_order"):
		return bool(_freelance_state.call("can_start_new_order"))

	return _count_available_orders(orders) > 0


func _update_header(snapshot: Dictionary) -> void:
	var level: int = int(snapshot.get("moderation_level", _call_state_int(&"get_level", 1)))
	var xp: int = int(snapshot.get("moderation_xp", _call_state_int(&"get_xp", 0)))
	var next_level_threshold: int = int(snapshot.get("next_level_threshold", 0))
	var rating: int = int(snapshot.get("service_rating", _call_state_int(&"get_service_rating", 0)))
	var completed_today_count: int = int(snapshot.get("completed_today_count", _call_state_int(&"get_completed_today_count", 0)))

	level_label.text = "Уровень: %d" % max(1, level)

	if next_level_threshold > 0:
		xp_label.text = "XP: %d / %d" % [max(0, xp), next_level_threshold]
	else:
		xp_label.text = "XP: %d" % max(0, xp)

	rating_label.text = "Рейтинг: %d/100" % clampi(rating, 0, 100)
	completed_today_label.text = "Сегодня: %d/2" % max(0, completed_today_count)


func _update_workday_state_label(orders: Array[Dictionary], can_start_new_order: bool) -> void:
	var available_count: int = _count_available_orders(orders)

	if can_start_new_order:
		if available_count >= 2:
			workday_state_label.text = "Доступно 2 заказа"
		elif available_count == 1:
			workday_state_label.text = "Доступно 1 заказ"
		else:
			workday_state_label.text = "Сегодня заказов больше нет"

		return

	if available_count == 0 and not orders.is_empty():
		workday_state_label.text = "Сегодня заказов больше нет"
	else:
		workday_state_label.text = "Рабочий день окончен"


func _rebuild_orders_list(orders: Array[Dictionary]) -> void:
	_clear_container(orders_list)
	_order_cards_by_id.clear()

	var selected_order_still_exists: bool = false
	var built_cards_count: int = 0

	for order in orders:
		var order_id: int = int(order.get("id", -1))

		if order_id < 0:
			continue

		var card_scene: Node = ORDER_CARD_SCENE.instantiate()
		var card: FreelanceOrderCard = card_scene as FreelanceOrderCard

		if card == null:
			if card_scene != null:
				card_scene.queue_free()

			continue

		card.set_order_data(order)

		if not card.selected.is_connected(_on_order_card_selected):
			card.selected.connect(_on_order_card_selected)

		orders_list.add_child(card)
		_order_cards_by_id[order_id] = card
		built_cards_count += 1

		if order_id == _selected_order_id:
			selected_order_still_exists = true

	if not selected_order_still_exists:
		_selected_order_id = _find_first_available_order_id(orders)

		if _selected_order_id < 0:
			_selected_order_id = _find_first_valid_order_id(orders)

	_refresh_order_card_selection()
	orders_scroll.visible = built_cards_count > 0
	empty_orders_label.visible = built_cards_count <= 0
	empty_orders_label.text = _build_empty_orders_message(orders)


func _update_selected_order_details(orders: Array[Dictionary]) -> void:
	var selected_order: Dictionary = _find_order_by_id(orders, _selected_order_id)

	if selected_order.is_empty():
		selected_title_label.text = "Выберите заказ"
		selected_difficulty_label.text = "Сложность: -"
		selected_comments_label.text = "Комментарии: -"
		selected_duration_label.text = "Время: -"
		selected_energy_label.text = "Энергия: -"
		selected_reward_label.text = "Оплата: -"
		selected_urgent_label.text = "Срочность: -"
		selected_day_label.text = "Выдано: -"
		selected_availability_label.text = "Статус: список заказов пуст"
		start_order_button.disabled = true
		return

	var difficulty: String = String(selected_order.get("difficulty", "easy"))
	var duration_minutes: int = max(0, int(selected_order.get("duration_minutes", 0)))
	var success_energy_cost: int = abs(int(round(float(selected_order.get("energy_cost_success", 0.0)))))
	var fail_energy_cost: int = abs(int(round(float(selected_order.get("energy_cost_fail", 0.0)))))
	var reward_base: int = max(0, int(selected_order.get("reward_base", 0)))
	var reward_estimate: int = max(0, int(selected_order.get("reward_final_estimate", reward_base)))
	var generated_day_id: int = max(1, int(selected_order.get("generated_day_id", 1)))
	var is_urgent: bool = bool(selected_order.get("is_urgent", false))

	selected_title_label.text = String(selected_order.get("title", "Без названия"))
	selected_difficulty_label.text = "Сложность: %s" % _format_difficulty(difficulty)
	selected_comments_label.text = "Комментарии: %d" % max(0, int(selected_order.get("comment_count", 0)))
	selected_duration_label.text = "Время: %s" % _format_duration(duration_minutes)
	selected_energy_label.text = "Энергия: -%d при успехе / -%d при провале" % [success_energy_cost, fail_energy_cost]
	selected_reward_label.text = "Оплата: базово $%d, оценка ~$%d" % [reward_base, reward_estimate]
	selected_urgent_label.text = "Срочность: %s" % ("срочный заказ" if is_urgent else "обычный заказ")
	selected_day_label.text = "Выдано: день %d" % generated_day_id
	selected_availability_label.text = _build_order_availability_summary(selected_order)
	start_order_button.disabled = not _can_request_start_order(selected_order)


func _rebuild_history(history_entries: Array[Dictionary]) -> void:
	_clear_container(history_list)
	var built_items_count: int = 0

	for entry in history_entries:
		var item_scene: Node = HISTORY_ITEM_SCENE.instantiate()
		var item: FreelanceHistoryItem = item_scene as FreelanceHistoryItem

		if item == null:
			if item_scene != null:
				item_scene.queue_free()

			continue

		item.set_history_entry(entry)
		history_list.add_child(item)
		built_items_count += 1

	history_scroll.visible = built_items_count > 0
	empty_history_label.visible = built_items_count <= 0
	empty_history_label.text = "История пока пуста."


func _render_missing_state() -> void:
	level_label.text = "Уровень: -"
	xp_label.text = "XP: -"
	rating_label.text = "Рейтинг: -"
	completed_today_label.text = "Сегодня: -"
	workday_state_label.text = "FreelanceState не найден"
	_clear_container(orders_list)
	_clear_container(history_list)
	_order_cards_by_id.clear()
	_selected_order_id = -1
	orders_scroll.visible = false
	history_scroll.visible = false
	empty_orders_label.visible = true
	empty_orders_label.text = "Глобальное состояние фриланса недоступно."
	empty_history_label.visible = true
	empty_history_label.text = "История недоступна."
	selected_title_label.text = "Нет подключения к FreelanceState"
	selected_difficulty_label.text = "Сложность: -"
	selected_comments_label.text = "Комментарии: -"
	selected_duration_label.text = "Время: -"
	selected_energy_label.text = "Энергия: -"
	selected_reward_label.text = "Оплата: -"
	selected_urgent_label.text = "Срочность: -"
	selected_day_label.text = "Выдано: -"
	selected_availability_label.text = "Статус: ошибка подключения"
	start_order_button.disabled = true


func _normalize_order_list(raw_orders: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not (raw_orders is Array):
		return result

	for order_variant in raw_orders:
		if not (order_variant is Dictionary):
			continue

		var order: Dictionary = order_variant
		var order_id: int = int(order.get("id", -1))

		if order_id < 0:
			continue

		result.append(order.duplicate(true))

	return result


func _normalize_history_list(raw_history: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if not (raw_history is Array):
		return result

	for entry_variant in raw_history:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var title: String = String(entry.get("title", "")).strip_edges()

		if title.is_empty():
			continue

		result.append(entry.duplicate(true))

	return result


func _find_order_by_id(orders: Array[Dictionary], order_id: int) -> Dictionary:
	if order_id < 0:
		return {}

	for order in orders:
		if int(order.get("id", -1)) == order_id:
			return order

	return {}


func _find_first_available_order_id(orders: Array[Dictionary]) -> int:
	for order in orders:
		if _is_order_available(order):
			return int(order.get("id", -1))

	return -1


func _find_first_valid_order_id(orders: Array[Dictionary]) -> int:
	for order in orders:
		var order_id: int = int(order.get("id", -1))

		if order_id >= 0:
			return order_id

	return -1


func _count_available_orders(orders: Array[Dictionary]) -> int:
	var available_count: int = 0

	for order in orders:
		if _is_order_available(order):
			available_count += 1

	return available_count


func _is_order_available(order: Dictionary) -> bool:
	return String(order.get("status", "available")) == "available"


func _can_request_start_order(order: Dictionary) -> bool:
	if order.is_empty():
		return false

	if not _is_order_available(order):
		return false

	var order_id: int = int(order.get("id", -1))

	if order_id < 0:
		return false

	if _freelance_state == null:
		return false

	if _freelance_state.has_method("can_start_order"):
		return bool(_freelance_state.call("can_start_order", order_id))

	return false


func _build_order_availability_summary(order: Dictionary) -> String:
	var status: String = String(order.get("status", "available"))

	match status:
		"completed":
			return "Статус: заказ уже выполнен"
		"failed":
			return "Статус: заказ уже провален"

	if bool(order.get("is_started", false)):
		return "Статус: заказ уже запущен"

	if _can_request_start_order(order):
		return "Статус: можно начать прямо сейчас"

	if _is_before_daily_generation():
		return "Статус: заказы будут доступны после 06:00"

	if _is_after_workday_close():
		return "Статус: рабочий день закрыт, новые запуски недоступны"

	return "Статус: запуск сейчас недоступен"


func _build_empty_orders_message(orders: Array[Dictionary]) -> String:
	if not orders.is_empty():
		return "Список заказов пуст."

	if _is_before_daily_generation():
		return "Заказы на сегодня еще не сформированы. Новая выдача после 06:00."

	if _is_after_workday_close():
		return "Рабочий день окончен. Новые заказы появятся завтра после 06:00."

	return "Заказы пока не появились. Обновите окно чуть позже."


func _format_difficulty(difficulty: String) -> String:
	match difficulty:
		"hard":
			return "высокая"
		"medium":
			return "средняя"
		_:
			return "низкая"


func _format_duration(total_minutes: int) -> String:
	var safe_minutes: int = max(0, total_minutes)
	var hours: int = int(safe_minutes / 60)
	var minutes: int = safe_minutes % 60

	if hours <= 0:
		return "%dм" % minutes

	return "%dч %02dм" % [hours, minutes]


func _refresh_order_card_selection() -> void:
	for order_id_variant in _order_cards_by_id.keys():
		var order_id: int = int(order_id_variant)
		var card: FreelanceOrderCard = _order_cards_by_id[order_id] as FreelanceOrderCard

		if card == null:
			continue

		card.set_selected(order_id == _selected_order_id)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _call_state(method_name: StringName, args: Array = []) -> Variant:
	if _freelance_state == null:
		return null

	if not _freelance_state.has_method(method_name):
		return null

	return _freelance_state.callv(method_name, args)


func _call_state_int(method_name: StringName, default_value: int) -> int:
	var value: Variant = _call_state(method_name)

	if value == null:
		return default_value

	return int(value)


func _get_game_time() -> Node:
	return get_node_or_null("/root/GameTime")


func _is_before_daily_generation() -> bool:
	var game_time: Node = _get_game_time()

	if game_time == null or not game_time.has_method("get_hours"):
		return false

	return int(game_time.call("get_hours")) < WORKDAY_START_HOUR


func _is_after_workday_close() -> bool:
	var game_time: Node = _get_game_time()

	if game_time == null or not game_time.has_method("get_hours"):
		return false

	return int(game_time.call("get_hours")) >= WORKDAY_CLOSE_HOUR


func _on_order_card_selected(order_id: int) -> void:
	_selected_order_id = order_id
	_refresh_order_card_selection()
	_update_selected_order_details(_extract_orders(_build_snapshot()))


func _on_start_order_button_pressed() -> void:
	if _selected_order_id < 0:
		return

	request_start_order.emit(_selected_order_id)


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_state_changed(_arg1: Variant = null, _arg2: Variant = null) -> void:
	refresh_view()
