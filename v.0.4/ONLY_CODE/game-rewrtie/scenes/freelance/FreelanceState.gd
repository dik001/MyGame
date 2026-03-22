extends Node

signal orders_changed()
signal order_started(order_id: int)
signal order_finished(order_id: int, result: Dictionary)
signal service_rating_changed(new_value: int)
signal skill_changed(level: int, xp: int)
signal history_changed()
signal bank_history_changed()
signal conditions_changed()
signal day_orders_generated(day_id: int)

const WORKDAY_START_HOUR: int = 6
const WORKDAY_CLOSE_HOUR: int = 22
const DAILY_ORDER_COUNT: int = 2
const ORDER_DURATION_MINUTES: int = 90
const DEFAULT_SERVICE_RATING: int = 50
const DEFAULT_MODERATION_LEVEL: int = 1
const DEFAULT_MODERATION_XP: int = 0
const MAX_SERVICE_RATING: int = 100
const MAX_MODERATION_LEVEL: int = 15
const MAX_RECENT_HISTORY_ENTRIES: int = 50
const MAX_BANK_HISTORY_ENTRIES: int = 50
const HIGH_RATING_URGENT_THRESHOLD: int = 75
const BASE_URGENT_CHANCE: float = 0.15
const HIGH_RATING_URGENT_CHANCE: float = 0.25
const URGENT_REWARD_MULTIPLIER: float = 1.35
const SUCCESS_ENERGY_DELTA: float = -15.0
const FAIL_ENERGY_DELTA: float = -40.0
const RESULT_EXCELLENT := "excellent"
const RESULT_NORMAL := "normal"
const RESULT_FAIL := "fail"

const COMMENT_COUNT_BY_DIFFICULTY := {
	"easy": 7,
	"medium": 12,
	"hard": 17,
}

const BASE_REWARD_BY_DIFFICULTY := {
	"easy": 40,
	"medium": 65,
	"hard": 90,
}

const TITLE_POOLS_BY_DIFFICULTY := {
	"easy": [
		"Базовая смена модерации",
		"Рутинная проверка комментариев",
		"Тихая дневная очередь",
	],
	"medium": [
		"Потоковая проверка чата",
		"Вечерняя проверка комментариев",
		"Пиковая смена",
	],
	"hard": [
		"Массовая ручная модерация",
		"Горячая линия контента",
		"Ночной разбор жалоб",
	],
}

const URGENT_TITLE_POOL := [
	"Срочная модерация эфира",
	"Экстренная очистка чата",
	"Кризисная смена модерации",
]

var _current_generated_day_id: int = 0
var _current_day_orders: Array[Dictionary] = []
var _completed_today_count: int = 0
var _completed_today_day_id: int = 0
var _service_rating: int = DEFAULT_SERVICE_RATING
var _moderation_level: int = DEFAULT_MODERATION_LEVEL
var _moderation_xp: int = DEFAULT_MODERATION_XP
var _recent_history: Array[Dictionary] = []
var _bank_history: Array[Dictionary] = []
var _last_bank_notification: String = ""
var _active_conditions: Dictionary = {}
var _last_observed_day_id: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameTime.time_changed.is_connected(_on_game_time_changed):
		GameTime.time_changed.connect(_on_game_time_changed)

	service_rating_changed.emit(_service_rating)
	skill_changed.emit(_moderation_level, _moderation_xp)
	ensure_orders_for_current_time()


func ensure_orders_for_current_time() -> void:
	var current_day: int = GameTime.get_day()

	if current_day != _last_observed_day_id:
		_handle_day_changed(current_day)

	if GameTime.get_hours() >= WORKDAY_START_HOUR and _current_generated_day_id != current_day:
		generate_orders_for_day(current_day)


func generate_orders_for_day(day_id: int) -> void:
	if day_id <= 0:
		return

	if GameTime.get_day() != day_id:
		return

	if GameTime.get_hours() < WORKDAY_START_HOUR:
		return

	if _current_generated_day_id == day_id and _current_day_orders.size() == DAILY_ORDER_COUNT:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = _build_generation_seed(day_id)

	var urgent_index: int = -1

	if rng.randf() < _get_urgent_order_chance():
		urgent_index = rng.randi_range(0, DAILY_ORDER_COUNT - 1)

	var used_titles: Array[String] = []
	var generated_orders: Array[Dictionary] = []

	for order_index in range(DAILY_ORDER_COUNT):
		var difficulty: String = _pick_difficulty(rng)
		var is_urgent: bool = order_index == urgent_index
		var reward_base: int = _build_generated_reward(difficulty, is_urgent)
		var title: String = _pick_order_title(rng, difficulty, is_urgent, used_titles)
		used_titles.append(title)

		generated_orders.append({
			"id": (day_id * 100) + order_index + 1,
			"title": title,
			"difficulty": difficulty,
			"comment_count": int(COMMENT_COUNT_BY_DIFFICULTY.get(difficulty, COMMENT_COUNT_BY_DIFFICULTY["easy"])),
			"duration_minutes": ORDER_DURATION_MINUTES,
			"energy_cost_success": SUCCESS_ENERGY_DELTA,
			"energy_cost_fail": FAIL_ENERGY_DELTA,
			"reward_base": reward_base,
			"reward_final_estimate": reward_base,
			"is_urgent": is_urgent,
			"status": "available",
			"generated_day_id": day_id,
			"available_until_hour": WORKDAY_CLOSE_HOUR,
			"accuracy_last": -1.0,
			"rating_delta_last": 0,
			"xp_gained_last": 0,
			"payout_last": 0,
			"is_started": false,
			"started_at_absolute_minutes": -1,
			"finished_at_absolute_minutes": -1,
			"result_status_last": "",
		})

	_current_generated_day_id = day_id
	_current_day_orders = generated_orders
	orders_changed.emit()
	day_orders_generated.emit(day_id)


func start_order(order_id: int) -> Dictionary:
	ensure_orders_for_current_time()
	var order_index: int = _find_order_index(order_id)

	if order_index == -1:
		return _make_error_result("order_not_found", "Заказ не найден.")

	var order: Dictionary = _current_day_orders[order_index]

	if not _can_start_order_data(order):
		if bool(order.get("is_started", false)):
			return _make_error_result("order_already_started", "Заказ уже запущен.")

		if String(order.get("status", "")) != "available":
			return _make_error_result("order_unavailable", "Заказ уже завершен.")

		return _make_error_result("workday_closed", "Новые заказы нельзя запускать после 22:00.")

	order["is_started"] = true
	order["started_at_absolute_minutes"] = GameTime.get_absolute_minutes()
	_current_day_orders[order_index] = order

	orders_changed.emit()
	order_started.emit(order_id)

	return {
		"success": true,
		"order_id": order_id,
		"started_at_absolute_minutes": int(order.get("started_at_absolute_minutes", -1)),
		"order": order.duplicate(true),
	}


func finish_order(order_id: int, accuracy: float) -> Dictionary:
	return _resolve_order_result(order_id, clampf(accuracy, 0.0, 1.0), false)


func fail_order(order_id: int) -> Dictionary:
	return _resolve_order_result(order_id, 0.0, true)


func add_condition(condition_id: StringName, payload: Dictionary = {}) -> void:
	if String(condition_id).is_empty():
		return

	if _active_conditions.has(condition_id):
		return

	var normalized_payload: Dictionary = payload.duplicate(true)
	normalized_payload["condition_id"] = String(condition_id)
	normalized_payload["applied_at_absolute_minutes"] = int(
		normalized_payload.get("applied_at_absolute_minutes", GameTime.get_absolute_minutes())
	)
	normalized_payload["applied_day_id"] = int(normalized_payload.get("applied_day_id", GameTime.get_day()))
	_active_conditions[condition_id] = normalized_payload
	conditions_changed.emit()


func remove_condition(condition_id: StringName) -> void:
	if not _active_conditions.has(condition_id):
		return

	_active_conditions.erase(condition_id)
	conditions_changed.emit()


func has_condition(condition_id: StringName) -> bool:
	return _active_conditions.has(condition_id)


func get_active_conditions() -> Array:
	var result: Array[Dictionary] = []

	for condition_key in _active_conditions.keys():
		var condition_id: StringName = StringName(condition_key)
		var payload: Dictionary = {}

		if _active_conditions[condition_id] is Dictionary:
			payload = _active_conditions[condition_id]

		result.append({
			"id": String(condition_id),
			"payload": payload.duplicate(true),
		})

	return result


func clear_daily_conditions_if_needed() -> void:
	var current_day: int = GameTime.get_day()
	var removed_any: bool = false

	for condition_key in _active_conditions.keys():
		var condition_id: StringName = StringName(condition_key)
		var payload: Dictionary = {}

		if _active_conditions[condition_id] is Dictionary:
			payload = _active_conditions[condition_id]

		if not bool(payload.get("clear_on_new_day", false)):
			continue

		if int(payload.get("applied_day_id", current_day)) == current_day:
			continue

		_active_conditions.erase(condition_id)
		removed_any = true

	if removed_any:
		conditions_changed.emit()


func remove_condition_by_rest(condition_id: StringName = &"eye_strain") -> void:
	remove_condition(condition_id)


func get_current_orders() -> Array:
	ensure_orders_for_current_time()
	return _duplicate_dictionary_array(_current_day_orders)


func get_recent_history(limit: int = 10) -> Array:
	return _get_recent_entries(_recent_history, limit)


func get_bank_history(limit: int = 20) -> Array:
	return _get_recent_entries(_bank_history, limit)


func get_last_bank_notification() -> String:
	return _last_bank_notification


func clear_last_bank_notification() -> void:
	if _last_bank_notification.is_empty():
		return

	_last_bank_notification = ""
	bank_history_changed.emit()


func get_service_rating() -> int:
	return _service_rating


func get_level() -> int:
	return _moderation_level


func get_xp() -> int:
	return _moderation_xp


func get_completed_today_count() -> int:
	return _completed_today_count


func is_workday_open() -> bool:
	ensure_orders_for_current_time()

	if GameTime.get_day() != _current_generated_day_id:
		return false

	return _is_within_start_hours(WORKDAY_CLOSE_HOUR)


func can_start_new_order() -> bool:
	ensure_orders_for_current_time()

	if not is_workday_open():
		return false

	for order in _current_day_orders:
		if _can_start_order_data(order):
			return true

	return false


func can_start_order(order_id: int) -> bool:
	ensure_orders_for_current_time()
	var order_index: int = _find_order_index(order_id)

	if order_index == -1:
		return false

	return _can_start_order_data(_current_day_orders[order_index])


func get_order_by_id(order_id: int) -> Dictionary:
	ensure_orders_for_current_time()
	var order_index: int = _find_order_index(order_id)

	if order_index == -1:
		return {}

	return _current_day_orders[order_index].duplicate(true)


func get_debug_snapshot() -> Dictionary:
	ensure_orders_for_current_time()

	return {
		"current_day": GameTime.get_day(),
		"current_generated_day_id": _current_generated_day_id,
		"current_day_orders": get_current_orders(),
		"completed_today_count": _completed_today_count,
		"service_rating": _service_rating,
		"moderation_level": _moderation_level,
		"moderation_xp": _moderation_xp,
		"next_level_threshold": _get_xp_threshold_for_level(_moderation_level),
		"recent_history": get_recent_history(MAX_RECENT_HISTORY_ENTRIES),
		"bank_history": get_bank_history(MAX_BANK_HISTORY_ENTRIES),
		"last_bank_notification": _last_bank_notification,
		"active_conditions": get_active_conditions(),
		"workday_open": is_workday_open(),
		"can_start_new_order": can_start_new_order(),
	}


func _on_game_time_changed(_absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	ensure_orders_for_current_time()


func _handle_day_changed(current_day: int) -> void:
	_last_observed_day_id = current_day
	_completed_today_count = 0
	_completed_today_day_id = current_day
	clear_daily_conditions_if_needed()

	if _current_generated_day_id == 0 and _current_day_orders.is_empty():
		return

	_current_generated_day_id = 0

	if _current_day_orders.is_empty():
		return

	_current_day_orders.clear()
	orders_changed.emit()


func _resolve_order_result(order_id: int, accuracy: float, forced_fail: bool) -> Dictionary:
	ensure_orders_for_current_time()
	var order_index: int = _find_order_index(order_id)

	if order_index == -1:
		return _make_error_result("order_not_found", "Заказ не найден.")

	var order: Dictionary = _current_day_orders[order_index]

	if String(order.get("status", "")) != "available":
		return _make_error_result("order_unavailable", "Заказ уже обработан.")

	if not bool(order.get("is_started", false)):
		return _make_error_result("order_not_started", "Сначала нужно запустить заказ.")

	var result_status: String = RESULT_FAIL if forced_fail else _grade_accuracy(accuracy)
	var duration_minutes: int = max(0, int(order.get("duration_minutes", ORDER_DURATION_MINUTES)))
	var completion_absolute_minutes: int = GameTime.get_absolute_minutes() + duration_minutes
	var completion_time_data: Dictionary = GameTime.get_time_data_for_absolute(completion_absolute_minutes)
	var completion_day_id: int = int(completion_time_data.get("day", GameTime.get_day()))
	var was_urgent: bool = bool(order.get("is_urgent", false))
	var payout: int = _calculate_payout(int(order.get("reward_base", 0)), result_status)
	var rating_delta: int = _get_rating_delta(result_status, was_urgent)
	var xp_gained: int = _get_xp_gain(String(order.get("difficulty", "easy")), result_status)
	var energy_delta: float = FAIL_ENERGY_DELTA if result_status == RESULT_FAIL else SUCCESS_ENERGY_DELTA
	var accuracy_value: float = 0.0 if forced_fail else accuracy

	order["status"] = "failed" if result_status == RESULT_FAIL else "completed"
	order["accuracy_last"] = accuracy_value
	order["rating_delta_last"] = rating_delta
	order["xp_gained_last"] = xp_gained
	order["payout_last"] = payout
	order["is_started"] = false
	order["finished_at_absolute_minutes"] = completion_absolute_minutes
	order["result_status_last"] = result_status
	_current_day_orders[order_index] = order

	_apply_energy_delta(energy_delta, result_status)

	if payout > 0:
		PlayerEconomy.add_dollars(payout)
		_append_bank_history_entry(
			String(order.get("title", "")),
			payout,
			completion_absolute_minutes,
			completion_day_id
		)

	_apply_service_rating_delta(rating_delta)
	_apply_xp_gain(xp_gained)
	_increment_completed_count(completion_day_id, completion_absolute_minutes)

	var history_entry: Dictionary = _append_history_entry(
		String(order.get("title", "")),
		result_status,
		accuracy_value,
		duration_minutes,
		payout,
		completion_day_id,
		was_urgent,
		completion_absolute_minutes
	)

	GameTime.advance_minutes(duration_minutes)
	orders_changed.emit()

	var result: Dictionary = {
		"success": true,
		"order_id": order_id,
		"title": String(order.get("title", "")),
		"result_status": result_status,
		"status": String(order.get("status", "")),
		"accuracy": accuracy_value,
		"payout": payout,
		"rating_delta": rating_delta,
		"service_rating": _service_rating,
		"xp_gained": xp_gained,
		"level": _moderation_level,
		"xp": _moderation_xp,
		"time_spent_minutes": duration_minutes,
		"energy_delta": energy_delta,
		"was_urgent": was_urgent,
		"completed_today_count": _completed_today_count,
		"active_conditions": get_active_conditions(),
		"completion_absolute_minutes": completion_absolute_minutes,
		"completion_day_id": completion_day_id,
		"bank_notification": _last_bank_notification,
		"history_entry": history_entry.duplicate(true),
		"order": order.duplicate(true),
	}

	order_finished.emit(order_id, result)
	return result


func _find_order_index(order_id: int) -> int:
	for order_index in range(_current_day_orders.size()):
		if int(_current_day_orders[order_index].get("id", -1)) == order_id:
			return order_index

	return -1


func _can_start_order_data(order: Dictionary) -> bool:
	if order.is_empty():
		return false

	if GameTime.get_day() != int(order.get("generated_day_id", -1)):
		return false

	if String(order.get("status", "")) != "available":
		return false

	if bool(order.get("is_started", false)):
		return false

	return _is_within_start_hours(int(order.get("available_until_hour", WORKDAY_CLOSE_HOUR)))


func _is_within_start_hours(available_until_hour: int) -> bool:
	var current_hour: int = GameTime.get_hours()

	if current_hour < WORKDAY_START_HOUR:
		return false

	return current_hour < available_until_hour


func _build_generation_seed(day_id: int) -> int:
	return (day_id * 10007) + (_service_rating * 131) + (_moderation_level * 17)


func _get_urgent_order_chance() -> float:
	if _service_rating >= HIGH_RATING_URGENT_THRESHOLD:
		return HIGH_RATING_URGENT_CHANCE

	return BASE_URGENT_CHANCE


func _pick_difficulty(rng: RandomNumberGenerator) -> String:
	# Better service rating shifts generation away from easy contracts and toward
	# medium/hard ones, which makes future days more profitable on average.
	var easy_weight: int = clampi(55 - int(round(float(_service_rating) * 0.25)), 20, 55)
	var medium_weight: int = clampi(30 + int(round(float(_service_rating) * 0.15)), 25, 50)
	var hard_weight: int = clampi(15 + int(round(float(_service_rating) * 0.10)), 10, 30)
	var roll: int = rng.randi_range(1, easy_weight + medium_weight + hard_weight)

	if roll <= easy_weight:
		return "easy"

	roll -= easy_weight

	if roll <= medium_weight:
		return "medium"

	return "hard"


func _build_generated_reward(difficulty: String, is_urgent: bool) -> int:
	var base_reward: int = int(BASE_REWARD_BY_DIFFICULTY.get(difficulty, BASE_REWARD_BY_DIFFICULTY["easy"]))
	# Rating gives a modest +/-10% swing so stronger reputation matters without
	# making low-rating days feel impossible to recover from.
	var reward_multiplier: float = 1.0 + ((float(_service_rating) - 50.0) / 500.0)

	if is_urgent:
		reward_multiplier *= URGENT_REWARD_MULTIPLIER

	return max(0, int(round(float(base_reward) * reward_multiplier)))


func _pick_order_title(
	rng: RandomNumberGenerator,
	difficulty: String,
	is_urgent: bool,
	used_titles: Array[String]
) -> String:
	var pool_variant: Variant = URGENT_TITLE_POOL if is_urgent else TITLE_POOLS_BY_DIFFICULTY.get(difficulty, [])
	var pool: Array = []

	if pool_variant is Array:
		pool = pool_variant

	if pool.is_empty():
		return "Смена модерации #%d" % rng.randi_range(10, 99)

	for _attempt in range(pool.size()):
		var candidate: String = String(pool[rng.randi_range(0, pool.size() - 1)])

		if not used_titles.has(candidate):
			return candidate

	return "%s #%d" % [String(pool[0]), rng.randi_range(2, 99)]


func _grade_accuracy(accuracy: float) -> String:
	if accuracy < 0.60:
		return RESULT_FAIL

	if accuracy >= 0.90:
		return RESULT_EXCELLENT

	return RESULT_NORMAL


func _calculate_payout(reward_base: int, result_status: String) -> int:
	var multiplier: float = 0.0

	match result_status:
		RESULT_EXCELLENT:
			multiplier = 1.25
		RESULT_NORMAL:
			multiplier = 1.0
		_:
			multiplier = 0.0

	return max(0, int(round(float(reward_base) * multiplier)))


func _get_rating_delta(result_status: String, is_urgent: bool) -> int:
	match result_status:
		RESULT_EXCELLENT:
			return 5
		RESULT_NORMAL:
			return 1
		_:
			return -10 if is_urgent else -7


func _get_xp_gain(difficulty: String, result_status: String) -> int:
	# Fails intentionally grant 0 XP so the player cannot safely grind progression
	# by repeatedly losing orders.
	if result_status == RESULT_FAIL:
		return 0

	match difficulty:
		"hard":
			return 18 if result_status == RESULT_EXCELLENT else 12
		"medium":
			return 15 if result_status == RESULT_EXCELLENT else 10
		_:
			return 12 if result_status == RESULT_EXCELLENT else 8


func _get_xp_threshold_for_level(level: int) -> int:
	var normalized_level: int = clampi(level, DEFAULT_MODERATION_LEVEL, MAX_MODERATION_LEVEL)
	return 25 + ((normalized_level - 1) * 15)


func _apply_energy_delta(energy_delta: float, result_status: String) -> void:
	var tick_name: StringName = &"freelance_order_fail" if result_status == RESULT_FAIL else &"freelance_order_success"
	PlayerStats.apply_action_tick(tick_name, {"energy": energy_delta})


func _apply_service_rating_delta(delta: int) -> void:
	if delta == 0:
		return

	var next_rating: int = clampi(_service_rating + delta, 0, MAX_SERVICE_RATING)

	if next_rating == _service_rating:
		return

	_service_rating = next_rating
	service_rating_changed.emit(_service_rating)


func _apply_xp_gain(amount: int) -> void:
	if amount <= 0:
		return

	if _moderation_level >= MAX_MODERATION_LEVEL:
		_moderation_level = MAX_MODERATION_LEVEL
		_moderation_xp = 0
		return

	_moderation_xp += amount

	while _moderation_level < MAX_MODERATION_LEVEL:
		var threshold: int = _get_xp_threshold_for_level(_moderation_level)

		if _moderation_xp < threshold:
			break

		_moderation_xp -= threshold
		_moderation_level += 1

		if _moderation_level >= MAX_MODERATION_LEVEL:
			_moderation_level = MAX_MODERATION_LEVEL
			_moderation_xp = 0
			break

	skill_changed.emit(_moderation_level, _moderation_xp)


func _increment_completed_count(completion_day_id: int, completion_absolute_minutes: int) -> void:
	if _completed_today_day_id != completion_day_id:
		_completed_today_count = 0
		_completed_today_day_id = completion_day_id

	_completed_today_count += 1

	if _completed_today_count >= 2:
		add_condition(&"eye_strain", {
			"source": "freelance",
			"applied_at_absolute_minutes": completion_absolute_minutes,
			"applied_day_id": completion_day_id,
		})


func _append_history_entry(
	title: String,
	result_status: String,
	accuracy: float,
	time_spent_minutes: int,
	payout: int,
	day_id: int,
	was_urgent: bool,
	timestamp_absolute_minutes: int
) -> Dictionary:
	var history_entry: Dictionary = {
		"title": title,
		"result_status": result_status,
		"accuracy": accuracy,
		"time_spent_minutes": time_spent_minutes,
		"payout": payout,
		"day_id": day_id,
		"was_urgent": was_urgent,
		"timestamp_absolute_minutes": timestamp_absolute_minutes,
	}

	_recent_history.append(history_entry)

	while _recent_history.size() > MAX_RECENT_HISTORY_ENTRIES:
		_recent_history.remove_at(0)

	history_changed.emit()
	return history_entry


func _append_bank_history_entry(
	order_title: String,
	amount: int,
	absolute_minutes: int,
	day_id: int
) -> Dictionary:
	var notification_text := "Перевод за заказ \"%s\": $%d" % [order_title, amount]
	var transfer_entry: Dictionary = {
		"source": "freelance",
		"order_title": order_title,
		"amount": amount,
		"absolute_minutes": absolute_minutes,
		"day_id": day_id,
		"status": "credited",
		"notification_text": notification_text,
	}

	_bank_history.append(transfer_entry)

	while _bank_history.size() > MAX_BANK_HISTORY_ENTRIES:
		_bank_history.remove_at(0)

	_last_bank_notification = notification_text
	bank_history_changed.emit()
	return transfer_entry


func _get_recent_entries(entries: Array[Dictionary], limit: int) -> Array:
	if limit <= 0:
		return []

	var result: Array[Dictionary] = []
	var min_index: int = max(0, entries.size() - limit)

	for entry_index in range(entries.size() - 1, min_index - 1, -1):
		result.append(entries[entry_index].duplicate(true))

	return result


func _duplicate_dictionary_array(entries: Array[Dictionary]) -> Array:
	var duplicated: Array[Dictionary] = []

	for entry in entries:
		duplicated.append(entry.duplicate(true))

	return duplicated


func _make_error_result(error_code: String, message: String) -> Dictionary:
	return {
		"success": false,
		"error": error_code,
		"message": message,
	}
