class_name PlayerEconomyState
extends Node

signal dollars_changed(new_value: int)
signal cash_dollars_changed(new_value: int)
signal bank_dollars_changed(new_value: int)
signal daily_summary_changed(summary: Dictionary)

const DEFAULT_STARTING_CASH_DOLLARS := 25
const DEFAULT_STARTING_BANK_DOLLARS := 0
const DEFAULT_STARTING_DOLLARS := DEFAULT_STARTING_CASH_DOLLARS

var cash_dollars := DEFAULT_STARTING_CASH_DOLLARS
var bank_dollars := DEFAULT_STARTING_BANK_DOLLARS
var _daily_totals_by_day: Dictionary = {}
var _current_observed_day: int = 1

var dollars: int:
	get:
		return cash_dollars
	set(value):
		set_cash_dollars(value)


func _ready() -> void:
	cash_dollars = max(0, cash_dollars)
	bank_dollars = max(0, bank_dollars)
	call_deferred("_initialize_daily_bookkeeping")
	_emit_cash_changed()
	_emit_bank_changed()


func set_cash_dollars(amount: int) -> void:
	var next_amount: int = max(0, amount)

	if cash_dollars == next_amount:
		return

	cash_dollars = next_amount
	_emit_cash_changed()


func get_cash_dollars() -> int:
	return cash_dollars


func add_cash_dollars(amount: int, count_as_income: bool = true, bookkeeping_day: int = -1) -> void:
	if amount <= 0:
		return

	cash_dollars += amount

	if count_as_income:
		_record_income(amount, bookkeeping_day)

	_emit_cash_changed()


func spend_cash_dollars(amount: int, count_as_expense: bool = true, bookkeeping_day: int = -1) -> bool:
	if amount <= 0:
		return true

	if not can_afford_cash(amount):
		return false

	cash_dollars -= amount

	if count_as_expense:
		_record_expense(amount, bookkeeping_day)

	_emit_cash_changed()
	return true


func can_afford_cash(amount: int) -> bool:
	if amount <= 0:
		return true

	return cash_dollars >= amount


func set_bank_dollars(amount: int) -> void:
	var next_amount: int = max(0, amount)

	if bank_dollars == next_amount:
		return

	bank_dollars = next_amount
	_emit_bank_changed()


func get_bank_dollars() -> int:
	return bank_dollars


func add_bank_dollars(amount: int, count_as_income: bool = true, bookkeeping_day: int = -1) -> void:
	if amount <= 0:
		return

	bank_dollars += amount

	if count_as_income:
		_record_income(amount, bookkeeping_day)

	_emit_bank_changed()


func remove_bank_dollars(amount: int, count_as_expense: bool = true, bookkeeping_day: int = -1) -> bool:
	if amount <= 0:
		return false

	if amount > bank_dollars:
		return false

	bank_dollars -= amount

	if count_as_expense:
		_record_expense(amount, bookkeeping_day)

	_emit_bank_changed()
	return true


func can_withdraw_from_bank(amount: int) -> bool:
	if amount <= 0:
		return false

	return bank_dollars >= amount


func withdraw_bank_dollars(amount: int) -> bool:
	if not can_withdraw_from_bank(amount):
		return false

	bank_dollars -= amount
	_emit_bank_changed()
	cash_dollars += amount
	_emit_cash_changed()
	return true


func add_dollars(amount: int, count_as_income: bool = true, bookkeeping_day: int = -1) -> void:
	add_cash_dollars(amount, count_as_income, bookkeeping_day)


func spend_dollars(amount: int, count_as_expense: bool = true, bookkeeping_day: int = -1) -> bool:
	return spend_cash_dollars(amount, count_as_expense, bookkeeping_day)


func can_afford(amount: int) -> bool:
	return can_afford_cash(amount)


func get_dollars() -> int:
	return get_cash_dollars()


func get_daily_income_dollars(day_id: int = -1) -> int:
	return int(get_daily_summary(day_id).get("income", 0))


func get_daily_expense_dollars(day_id: int = -1) -> int:
	return int(get_daily_summary(day_id).get("expense", 0))


func get_daily_summary(day_id: int = -1) -> Dictionary:
	var resolved_day: int = _resolve_bookkeeping_day(day_id)
	var totals: Dictionary = _get_day_totals(resolved_day)

	return {
		"day": resolved_day,
		"income": int(totals.get("income", 0)),
		"expense": int(totals.get("expense", 0)),
	}


func _emit_cash_changed() -> void:
	dollars_changed.emit(cash_dollars)
	cash_dollars_changed.emit(cash_dollars)


func _emit_bank_changed() -> void:
	bank_dollars_changed.emit(bank_dollars)


func _initialize_daily_bookkeeping() -> void:
	_current_observed_day = _resolve_bookkeeping_day(-1)
	_ensure_day_bucket(_current_observed_day)
	_emit_daily_summary_changed()

	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time == null:
		return

	if not game_time.day_changed.is_connected(_on_game_day_changed):
		game_time.day_changed.connect(_on_game_day_changed)


func _on_game_day_changed(_previous_day: int, current_day: int) -> void:
	_current_observed_day = max(1, current_day)
	_ensure_day_bucket(_current_observed_day)
	_prune_old_daily_totals()
	_emit_daily_summary_changed()


func _record_income(amount: int, bookkeeping_day: int = -1) -> void:
	var resolved_day: int = _resolve_bookkeeping_day(bookkeeping_day)
	var totals: Dictionary = _ensure_day_bucket(resolved_day)
	totals["income"] = int(totals.get("income", 0)) + amount
	_daily_totals_by_day[resolved_day] = totals
	_emit_daily_summary_changed()


func _record_expense(amount: int, bookkeeping_day: int = -1) -> void:
	var resolved_day: int = _resolve_bookkeeping_day(bookkeeping_day)
	var totals: Dictionary = _ensure_day_bucket(resolved_day)
	totals["expense"] = int(totals.get("expense", 0)) + amount
	_daily_totals_by_day[resolved_day] = totals
	_emit_daily_summary_changed()


func _resolve_bookkeeping_day(day_id: int) -> int:
	if day_id > 0:
		return day_id

	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time != null:
		return max(1, game_time.get_day())

	return max(1, _current_observed_day)


func _ensure_day_bucket(day_id: int) -> Dictionary:
	var resolved_day: int = max(1, day_id)
	var totals: Dictionary = _get_day_totals(resolved_day)
	_daily_totals_by_day[resolved_day] = totals
	return totals


func _get_day_totals(day_id: int) -> Dictionary:
	var resolved_day: int = max(1, day_id)
	var existing_totals: Variant = _daily_totals_by_day.get(resolved_day, {})

	if existing_totals is Dictionary:
		var totals: Dictionary = (existing_totals as Dictionary).duplicate(true)
		totals["income"] = int(totals.get("income", 0))
		totals["expense"] = int(totals.get("expense", 0))
		return totals

	return {
		"income": 0,
		"expense": 0,
	}


func _prune_old_daily_totals() -> void:
	var min_day_to_keep: int = max(1, _current_observed_day - 7)

	for day_key in _daily_totals_by_day.keys():
		var resolved_day: int = int(day_key)

		if resolved_day < min_day_to_keep:
			_daily_totals_by_day.erase(day_key)


func _emit_daily_summary_changed() -> void:
	daily_summary_changed.emit(get_daily_summary(_current_observed_day))
