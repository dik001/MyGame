extends Node

signal rent_state_changed()
signal landlord_feed_changed()
signal calendar_events_changed()
signal rent_due_today()
signal rent_overdue()
signal rent_paid(result: Dictionary)
signal unread_landlord_count_changed(new_value: int)

const RENT_CYCLE_DAYS: int = 7
const FIRST_CYCLE_OFFSET_DAYS: int = RENT_CYCLE_DAYS - 1
const RENT_AMOUNT: int = 700
const REMINDER_DAYS_BEFORE_DUE: int = 1
const OVERDUE_FOLLOWUP_INTERVAL_DAYS: int = 3
const MINUTES_PER_DAY: int = 24 * 60
const REMINDER_HOUR: int = 10
const DUE_HOUR: int = 10
const OVERDUE_HOUR: int = 11
const OVERDUE_FOLLOWUP_HOUR: int = 11
const LANDLORD_SENDER_ID: String = "landlord"
const LANDLORD_SENDER_NAME: String = "Арендодатель"

var _is_initialized: bool = false
var _current_cycle: Dictionary = {}
var _landlord_messages: Array[Dictionary] = []
var _calendar_events: Array[Dictionary] = []
var _rent_history: Array[Dictionary] = []
var _unread_landlord_count: int = 0
var _next_message_id: int = 1
var _next_calendar_event_id: int = 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	if not GameTime.time_changed.is_connected(_on_game_time_changed):
		GameTime.time_changed.connect(_on_game_time_changed)

	_initialize_from_current_time()
	_process_current_time(GameTime.get_absolute_minutes(), GameTime.get_day(), false)


func get_current_rent_snapshot() -> Dictionary:
	if _current_cycle.is_empty():
		return {}

	return _build_cycle_snapshot(_current_cycle, GameTime.get_day(), GameTime.get_absolute_minutes())


func get_rent_amount() -> int:
	return RENT_AMOUNT


func get_next_due_day() -> int:
	return int(_current_cycle.get("due_day", 0))


func is_rent_due() -> bool:
	return _get_cycle_state(_current_cycle, GameTime.get_day()) == "due"


func is_rent_overdue() -> bool:
	return _get_cycle_state(_current_cycle, GameTime.get_day()) == "overdue"


func pay_current_rent() -> Dictionary:
	_initialize_from_current_time()
	_process_current_time(GameTime.get_absolute_minutes(), GameTime.get_day(), false)

	if _current_cycle.is_empty():
		return _make_payment_result(false, "no_active_cycle", "Текущий цикл аренды недоступен.")

	if bool(_current_cycle.get("is_paid", false)):
		return _make_payment_result(true, "", "Текущий цикл аренды уже оплачен.", true)

	var current_day: int = GameTime.get_day()
	var current_absolute_minutes: int = GameTime.get_absolute_minutes()

	if not _is_cycle_payable(_current_cycle, current_day):
		return _make_payment_result(false, "rent_not_payable", "Сейчас активного счёта на оплату аренды нет.")

	if not PlayerEconomy.can_afford(RENT_AMOUNT):
		var failure_result: Dictionary = _make_payment_result(false, "insufficient_funds", "Недостаточно денег для оплаты аренды.")
		failure_result["required_amount"] = RENT_AMOUNT
		failure_result["current_dollars"] = PlayerEconomy.get_dollars()
		return failure_result

	if not PlayerEconomy.spend_dollars(RENT_AMOUNT):
		return _make_payment_result(false, "payment_failed", "Не удалось списать деньги за аренду.")

	var cycle_index: int = int(_current_cycle.get("cycle_index", 1))
	var previous_due_day: int = int(_current_cycle.get("due_day", current_day))
	var was_overdue: bool = bool(_current_cycle.get("is_overdue", false))

	_current_cycle["is_paid"] = true
	_current_cycle["is_overdue"] = false
	_current_cycle["paid_day"] = current_day
	_current_cycle["paid_absolute_minutes"] = current_absolute_minutes

	var history_entry: Dictionary = _append_rent_history_entry(_current_cycle)
	var payment_changes: Dictionary = {
		"state_changed": true,
		"landlord_changed": _append_landlord_message(
			"Оплата аренды получена. Спасибо.",
			current_absolute_minutes,
			current_day,
			"rent_paid",
			cycle_index
		),
		"calendar_changed": _mark_cycle_calendar_events_completed(cycle_index),
		"emit_due": false,
		"emit_overdue": false,
	}
	var paid_cycle_snapshot: Dictionary = _build_cycle_snapshot(_current_cycle, current_day, current_absolute_minutes)

	_current_cycle = _build_cycle(cycle_index + 1, previous_due_day + RENT_CYCLE_DAYS, current_absolute_minutes)
	var next_cycle_changes: Dictionary = _process_current_time(current_absolute_minutes, current_day, false)
	var result: Dictionary = {
		"success": true,
		"already_paid": false,
		"error": "",
		"message": "Аренда оплачена.",
		"cycle_index": cycle_index,
		"amount": RENT_AMOUNT,
		"paid_day": current_day,
		"paid_absolute_minutes": current_absolute_minutes,
		"was_overdue": was_overdue,
		"history_entry": history_entry.duplicate(true),
		"paid_cycle_snapshot": paid_cycle_snapshot.duplicate(true),
		"next_cycle_snapshot": _build_cycle_snapshot(_current_cycle, current_day, current_absolute_minutes),
		"current_dollars": PlayerEconomy.get_dollars(),
	}

	_emit_change_set(_merge_change_sets(payment_changes, next_cycle_changes))
	rent_paid.emit(result)
	return result


func get_landlord_messages(limit: int = 100) -> Array:
	return _get_recent_entries(_landlord_messages, limit)


func get_unread_landlord_count() -> int:
	return _unread_landlord_count


func mark_all_landlord_messages_read() -> void:
	var changed: bool = false

	for index in range(_landlord_messages.size()):
		var entry: Dictionary = _landlord_messages[index]

		if bool(entry.get("is_read", false)):
			continue

		entry["is_read"] = true
		_landlord_messages[index] = entry
		changed = true

	if not changed:
		return

	_refresh_unread_landlord_count()
	landlord_feed_changed.emit()


func get_calendar_events(limit: int = 100) -> Array:
	return _get_recent_entries(_calendar_events, limit)


func get_recent_rent_history(limit: int = 30) -> Array:
	return _get_recent_entries(_rent_history, limit)


func get_debug_snapshot() -> Dictionary:
	return {
		"current_day": GameTime.get_day(),
		"current_absolute_minutes": GameTime.get_absolute_minutes(),
		"rent_amount": RENT_AMOUNT,
		"current_cycle": get_current_rent_snapshot(),
		"landlord_messages": get_landlord_messages(200),
		"calendar_events": get_calendar_events(200),
		"unread_landlord_count": _unread_landlord_count,
		"rent_history": get_recent_rent_history(100),
	}


func _on_game_time_changed(absolute_minutes: int, day: int, _hours: int, _minutes: int) -> void:
	_initialize_from_current_time()
	_emit_change_set(_process_current_time(absolute_minutes, day, false))


func _initialize_from_current_time() -> void:
	if _is_initialized:
		return

	_is_initialized = true

	# Deterministic bootstrap rule:
	# if the system first initializes on in-game day D, the first rent due day is D + 6.
	# That gives the player a simple 7-day cycle with the current day counting as day 1.
	_current_cycle = _build_cycle(1, GameTime.get_day() + FIRST_CYCLE_OFFSET_DAYS, GameTime.get_absolute_minutes())


func _build_cycle(cycle_index: int, due_day: int, created_absolute_minutes: int) -> Dictionary:
	return {
		"cycle_index": max(1, cycle_index),
		"due_day": max(1, due_day),
		"rent_amount": RENT_AMOUNT,
		"is_paid": false,
		"is_overdue": false,
		"reminder_generated": false,
		"due_generated": false,
		"overdue_generated": false,
		"overdue_followups_generated": 0,
		"paid_day": -1,
		"paid_absolute_minutes": -1,
		"created_absolute_minutes": max(0, created_absolute_minutes),
	}


func _process_current_time(_current_absolute_minutes: int, current_day: int, emit_signals: bool = true) -> Dictionary:
	var changes: Dictionary = {
		"state_changed": false,
		"landlord_changed": false,
		"calendar_changed": false,
		"emit_due": false,
		"emit_overdue": false,
	}

	if _current_cycle.is_empty() or bool(_current_cycle.get("is_paid", false)):
		if emit_signals:
			_emit_change_set(changes)
		return changes

	var cycle_index: int = int(_current_cycle.get("cycle_index", 1))
	var due_day: int = int(_current_cycle.get("due_day", current_day))
	var reminder_day: int = max(1, due_day - REMINDER_DAYS_BEFORE_DUE)

	if current_day >= reminder_day and not bool(_current_cycle.get("reminder_generated", false)):
		changes["landlord_changed"] = _append_landlord_message(
			"Напоминаю: завтра нужно оплатить аренду квартиры. Сумма: $700.",
			_build_absolute_minutes_for_day(reminder_day, REMINDER_HOUR),
			reminder_day,
			"rent_reminder",
			cycle_index
		) or bool(changes.get("landlord_changed", false))
		changes["calendar_changed"] = _append_calendar_event(
			"Напоминание об аренде",
			"Завтра нужно оплатить аренду квартиры. Сумма: $700.",
			reminder_day,
			_build_absolute_minutes_for_day(reminder_day, REMINDER_HOUR),
			"rent",
			cycle_index,
			"upcoming",
			false,
			false,
			"rent_reminder"
		) or bool(changes.get("calendar_changed", false))
		_current_cycle["reminder_generated"] = true
		changes["state_changed"] = true

	if current_day >= due_day and not bool(_current_cycle.get("due_generated", false)):
		changes["landlord_changed"] = _append_landlord_message(
			"Сегодня срок оплаты аренды. Сумма: $700.",
			_build_absolute_minutes_for_day(due_day, DUE_HOUR),
			due_day,
			"rent_due",
			cycle_index
		) or bool(changes.get("landlord_changed", false))
		changes["calendar_changed"] = _append_calendar_event(
			"Аренда сегодня",
			"Сегодня срок оплаты аренды. Сумма: $700.",
			due_day,
			_build_absolute_minutes_for_day(due_day, DUE_HOUR),
			"rent",
			cycle_index,
			"due",
			false,
			true,
			"rent_due"
		) or bool(changes.get("calendar_changed", false))
		_current_cycle["due_generated"] = true
		changes["state_changed"] = true

		if current_day == due_day:
			changes["emit_due"] = true

	var should_be_overdue: bool = current_day > due_day

	if bool(_current_cycle.get("is_overdue", false)) != should_be_overdue:
		_current_cycle["is_overdue"] = should_be_overdue
		changes["state_changed"] = true

	if should_be_overdue and not bool(_current_cycle.get("overdue_generated", false)):
		var overdue_day: int = due_day + 1
		changes["landlord_changed"] = _append_landlord_message(
			"Аренда просрочена. Пожалуйста, оплатите $700 как можно скорее.",
			_build_absolute_minutes_for_day(overdue_day, OVERDUE_HOUR),
			overdue_day,
			"rent_overdue",
			cycle_index
		) or bool(changes.get("landlord_changed", false))
		changes["calendar_changed"] = _append_calendar_event(
			"Аренда просрочена",
			"Аренда просрочена. Пожалуйста, оплатите $700 как можно скорее.",
			overdue_day,
			_build_absolute_minutes_for_day(overdue_day, OVERDUE_HOUR),
			"rent",
			cycle_index,
			"overdue",
			false,
			true,
			"rent_overdue"
		) or bool(changes.get("calendar_changed", false))
		_current_cycle["overdue_generated"] = true
		changes["state_changed"] = true
		changes["emit_overdue"] = true

	if should_be_overdue:
		# While rent stays unpaid, add one follow-up every 3 overdue days:
		# overdue day 4, 7, 10 and so on. This keeps future LeChat/Calendar feeds active
		# without spamming the player every in-game day.
		var overdue_days: int = current_day - due_day
		var expected_followups: int = max(0, int(floor(float(overdue_days - 1) / float(OVERDUE_FOLLOWUP_INTERVAL_DAYS))))
		var generated_followups: int = int(_current_cycle.get("overdue_followups_generated", 0))

		while generated_followups < expected_followups:
			generated_followups += 1
			var followup_day: int = due_day + 1 + (generated_followups * OVERDUE_FOLLOWUP_INTERVAL_DAYS)
			changes["landlord_changed"] = _append_landlord_message(
				"Аренда всё ещё просрочена. Пожалуйста, оплатите $700 как можно скорее.",
				_build_absolute_minutes_for_day(followup_day, OVERDUE_FOLLOWUP_HOUR),
				followup_day,
				"rent_overdue",
				cycle_index
			) or bool(changes.get("landlord_changed", false))
			changes["calendar_changed"] = _append_calendar_event(
				"Просрочка аренды",
				"Просрочка по аренде сохраняется. Оплатите $700 при первой возможности.",
				followup_day,
				_build_absolute_minutes_for_day(followup_day, OVERDUE_FOLLOWUP_HOUR),
				"rent",
				cycle_index,
				"overdue",
				false,
				true,
				"rent_overdue_followup"
			) or bool(changes.get("calendar_changed", false))
			_current_cycle["overdue_followups_generated"] = generated_followups
			changes["state_changed"] = true

	if emit_signals:
		_emit_change_set(changes)

	return changes


func _append_landlord_message(text: String, absolute_minutes: int, day: int, message_type: String, related_cycle: int) -> bool:
	_landlord_messages.append({
		"id": "landlord_%d" % _next_message_id,
		"sender_id": LANDLORD_SENDER_ID,
		"sender_display_name": LANDLORD_SENDER_NAME,
		"text": text,
		"absolute_minutes": absolute_minutes,
		"day": day,
		"type": message_type,
		"is_read": false,
		"related_cycle": related_cycle,
	})
	_next_message_id += 1
	_refresh_unread_landlord_count()
	return true


func _append_calendar_event(
	title: String,
	description: String,
	day: int,
	absolute_minutes: int,
	category: String,
	related_cycle: int,
	state: String,
	is_completed: bool,
	is_high_priority: bool,
	event_type: String
) -> bool:
	_calendar_events.append({
		"id": "rent_event_%d" % _next_calendar_event_id,
		"title": title,
		"description": description,
		"day": day,
		"absolute_minutes": absolute_minutes,
		"category": category,
		"related_cycle": related_cycle,
		"state": state,
		"is_completed": is_completed,
		"is_high_priority": is_high_priority,
		"event_type": event_type,
	})
	_next_calendar_event_id += 1
	return true


func _append_rent_history_entry(cycle_data: Dictionary) -> Dictionary:
	var history_entry: Dictionary = {
		"cycle_index": int(cycle_data.get("cycle_index", 0)),
		"amount": int(cycle_data.get("rent_amount", RENT_AMOUNT)),
		"due_day": int(cycle_data.get("due_day", -1)),
		"paid_day": int(cycle_data.get("paid_day", -1)),
		"paid_absolute_minutes": int(cycle_data.get("paid_absolute_minutes", -1)),
		"status": "paid_overdue" if bool(cycle_data.get("overdue_generated", false)) else "paid",
		"was_overdue": bool(cycle_data.get("overdue_generated", false)),
	}

	_rent_history.append(history_entry)
	return history_entry


func _mark_cycle_calendar_events_completed(cycle_index: int) -> bool:
	var changed: bool = false

	for index in range(_calendar_events.size()):
		var event_entry: Dictionary = _calendar_events[index]

		if int(event_entry.get("related_cycle", -1)) != cycle_index:
			continue

		var event_changed: bool = false

		if String(event_entry.get("state", "")) != "completed":
			event_entry["state"] = "completed"
			event_changed = true

		if not bool(event_entry.get("is_completed", false)):
			event_entry["is_completed"] = true
			event_changed = true

		if bool(event_entry.get("is_high_priority", false)):
			event_entry["is_high_priority"] = false
			event_changed = true

		if not event_changed:
			continue

		_calendar_events[index] = event_entry
		changed = true

	return changed


func _refresh_unread_landlord_count() -> void:
	var next_count: int = 0

	for entry in _landlord_messages:
		if not bool(entry.get("is_read", false)):
			next_count += 1

	if next_count == _unread_landlord_count:
		return

	_unread_landlord_count = next_count
	unread_landlord_count_changed.emit(_unread_landlord_count)


func _emit_change_set(changes: Dictionary) -> void:
	if bool(changes.get("state_changed", false)):
		rent_state_changed.emit()

	if bool(changes.get("landlord_changed", false)):
		landlord_feed_changed.emit()

	if bool(changes.get("calendar_changed", false)):
		calendar_events_changed.emit()

	if bool(changes.get("emit_due", false)):
		rent_due_today.emit()

	if bool(changes.get("emit_overdue", false)):
		rent_overdue.emit()


func _merge_change_sets(left: Dictionary, right: Dictionary) -> Dictionary:
	return {
		"state_changed": bool(left.get("state_changed", false)) or bool(right.get("state_changed", false)),
		"landlord_changed": bool(left.get("landlord_changed", false)) or bool(right.get("landlord_changed", false)),
		"calendar_changed": bool(left.get("calendar_changed", false)) or bool(right.get("calendar_changed", false)),
		"emit_due": bool(left.get("emit_due", false)) or bool(right.get("emit_due", false)),
		"emit_overdue": bool(left.get("emit_overdue", false)) or bool(right.get("emit_overdue", false)),
	}


func _make_payment_result(success: bool, error_code: String, message: String, already_paid: bool = false) -> Dictionary:
	return {
		"success": success,
		"already_paid": already_paid,
		"error": error_code,
		"message": message,
		"snapshot": get_current_rent_snapshot(),
		"current_dollars": PlayerEconomy.get_dollars(),
	}


func _build_cycle_snapshot(cycle_data: Dictionary, current_day: int, current_absolute_minutes: int) -> Dictionary:
	var due_day: int = int(cycle_data.get("due_day", 0))
	var state: String = _get_cycle_state(cycle_data, current_day)

	return {
		"cycle_index": int(cycle_data.get("cycle_index", 0)),
		"due_day": due_day,
		"current_due_day": due_day,
		"rent_amount": int(cycle_data.get("rent_amount", RENT_AMOUNT)),
		"current_rent_amount": int(cycle_data.get("rent_amount", RENT_AMOUNT)),
		"state": state,
		"current_state": state,
		"is_paid": bool(cycle_data.get("is_paid", false)),
		"is_upcoming": state == "upcoming",
		"is_due": state == "due",
		"is_overdue": state == "overdue",
		"can_pay": _is_cycle_payable(cycle_data, current_day),
		"days_until_due": due_day - current_day,
		"days_overdue": max(0, current_day - due_day),
		"reminder_generated": bool(cycle_data.get("reminder_generated", false)),
		"due_generated": bool(cycle_data.get("due_generated", false)),
		"overdue_generated": bool(cycle_data.get("overdue_generated", false)),
		"overdue_followups_generated": int(cycle_data.get("overdue_followups_generated", 0)),
		"paid_day": int(cycle_data.get("paid_day", -1)),
		"paid_absolute_minutes": int(cycle_data.get("paid_absolute_minutes", -1)),
		"unread_landlord_count": _unread_landlord_count,
		"current_day": current_day,
		"current_absolute_minutes": current_absolute_minutes,
	}


func _get_cycle_state(cycle_data: Dictionary, current_day: int) -> String:
	if cycle_data.is_empty():
		return "upcoming"

	if bool(cycle_data.get("is_paid", false)):
		return "paid"

	var due_day: int = int(cycle_data.get("due_day", current_day))

	if current_day > due_day:
		return "overdue"

	if current_day == due_day:
		return "due"

	return "upcoming"


func _is_cycle_payable(cycle_data: Dictionary, current_day: int) -> bool:
	var state: String = _get_cycle_state(cycle_data, current_day)
	return state == "due" or state == "overdue"


func _build_absolute_minutes_for_day(day: int, hour: int, minute: int = 0) -> int:
	var safe_day: int = max(1, day)
	return ((safe_day - 1) * MINUTES_PER_DAY) + (clampi(hour, 0, 23) * 60) + clampi(minute, 0, 59)


func _get_recent_entries(entries: Array[Dictionary], limit: int) -> Array:
	if limit <= 0:
		return []

	var result: Array[Dictionary] = []
	var start_index: int = max(0, entries.size() - limit)

	for index in range(start_index, entries.size()):
		result.append(entries[index].duplicate(true))

	return result
