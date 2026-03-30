extends Node

signal shift_state_changed(is_active: bool)
signal shift_finished(result: Dictionary)

const PART_TIME_CONFIG = preload("res://scenes/part_time/CashierPartTimeConfig.gd")

var worked_day_id := 0
var last_observed_day_id := 0
var shift_active := false
var _last_result: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_connect_game_time_signals()
	_sync_day_state()


func reset_state() -> void:
	worked_day_id = 0
	last_observed_day_id = 0
	shift_active = false
	_last_result.clear()
	shift_state_changed.emit(false)


func has_worked_today() -> bool:
	_sync_day_state()
	return worked_day_id == _get_current_day_id()


func is_shift_active() -> bool:
	return shift_active


func can_start_shift() -> Dictionary:
	_sync_day_state()

	if shift_active:
		return _build_availability_result(false, &"shift_active")

	var current_hour := _get_current_hour()

	if current_hour < PART_TIME_CONFIG.SHIFT_START_HOUR:
		return _build_availability_result(false, &"too_early")

	if current_hour >= PART_TIME_CONFIG.SHIFT_END_HOUR:
		return _build_availability_result(false, &"too_late")

	if has_worked_today():
		return _build_availability_result(false, &"already_worked")

	return {
		"allowed": true,
		"reason": StringName(),
		"message": "",
	}


func start_shift() -> void:
	var availability: Dictionary = can_start_shift()

	if not bool(availability.get("allowed", false)):
		return

	var current_day := _get_current_day_id()
	worked_day_id = current_day
	last_observed_day_id = current_day
	shift_active = true
	_last_result.clear()
	shift_state_changed.emit(true)


func finish_shift(success: bool, reason: StringName = &"completed") -> Dictionary:
	_sync_day_state()

	if not shift_active:
		return _last_result.duplicate(true)

	var completion_day := _get_current_day_id()
	var payout: int = PART_TIME_CONFIG.SUCCESS_PAYOUT if success else 0
	var energy_delta: float = _resolve_work_energy_delta(-PART_TIME_CONFIG.SHIFT_ENERGY_COST)
	var hunger_delta: int = PART_TIME_CONFIG.SHIFT_HUNGER_DELTA
	var mental_event_id: StringName = (
		PART_TIME_CONFIG.SUCCESS_MENTAL_EVENT
		if success
		else PART_TIME_CONFIG.FAIL_MENTAL_EVENT
	)

	shift_active = false
	worked_day_id = completion_day
	last_observed_day_id = completion_day

	_apply_shift_stats(energy_delta, hunger_delta)
	_apply_shift_hygiene()
	_apply_shift_mental_event(mental_event_id, reason)
	_apply_shift_time_cost()
	_apply_shift_payout(payout, completion_day)

	_last_result = {
		"success": success,
		"reason": String(reason),
		"result_status": "completed" if success else "fail",
		"title": "Смена завершена" if success else "Смена сорвана",
		"message": (
			"Кассир молча отсчитывает деньги."
			if success
			else "Кассир снимает тебя со смены без оплаты."
		),
		"payout": payout,
		"time_spent_minutes": PART_TIME_CONFIG.SHIFT_DURATION_MINUTES,
		"energy_delta": energy_delta,
		"hunger_delta": hunger_delta,
		"worked_day_id": completion_day,
		"completed": true,
	}

	shift_state_changed.emit(false)
	shift_finished.emit(_last_result.duplicate(true))
	return _last_result.duplicate(true)


func interrupt_shift(reason: StringName = &"forced_close") -> void:
	if not shift_active:
		return

	finish_shift(false, reason)


func build_save_data() -> Dictionary:
	return {
		"worked_day_id": worked_day_id,
		"last_observed_day_id": last_observed_day_id,
		"shift_active": shift_active,
		"last_result": _last_result.duplicate(true),
	}


func apply_save_data(data: Dictionary) -> void:
	worked_day_id = max(0, int(data.get("worked_day_id", 0)))
	last_observed_day_id = max(0, int(data.get("last_observed_day_id", 0)))
	shift_active = bool(data.get("shift_active", false))
	_last_result = SaveDataUtils.sanitize_dictionary(data.get("last_result", {}))
	_sync_day_state()

	if shift_active:
		finish_shift(false, &"loaded_interrupted")


func get_last_result() -> Dictionary:
	return _last_result.duplicate(true)


func _build_availability_result(allowed: bool, reason: StringName) -> Dictionary:
	var sequence: Array[Dictionary] = PART_TIME_CONFIG.get_job_unavailable_sequence(reason)
	var message := ""

	if not sequence.is_empty():
		message = String(sequence[0].get("text", "")).strip_edges()

	return {
		"allowed": allowed,
		"reason": reason,
		"message": message,
	}


func _apply_shift_stats(energy_delta: float, hunger_delta: int) -> void:
	if PlayerStats == null or not PlayerStats.has_method("apply_action_tick"):
		return

	PlayerStats.apply_action_tick(&"cashier_part_time_shift", {
		"energy": energy_delta,
		"hunger": hunger_delta,
	})


func _apply_shift_hygiene() -> void:
	if PlayerStats == null or not PlayerStats.has_method("apply_hygiene_source"):
		return

	PlayerStats.apply_hygiene_source(
		PlayerStats.HYGIENE_SOURCE_DIRTY_WORK,
		PART_TIME_CONFIG.SHIFT_HYGIENE_INTENSITY
	)


func _apply_shift_mental_event(event_id: StringName, reason: StringName) -> void:
	if PlayerMentalState == null or not PlayerMentalState.has_method("apply_event"):
		return

	PlayerMentalState.apply_event(event_id, {
		"source": "cashier_shift",
		"reason": String(reason),
		"tags": ["work", "shop", "trash_sorting"],
	})


func _apply_shift_time_cost() -> void:
	if GameTime == null or not GameTime.has_method("advance_minutes"):
		return

	GameTime.advance_minutes(PART_TIME_CONFIG.SHIFT_DURATION_MINUTES)


func _apply_shift_payout(payout: int, bookkeeping_day: int) -> void:
	if payout <= 0:
		return

	if PlayerEconomy == null or not PlayerEconomy.has_method("add_cash_dollars"):
		return

	PlayerEconomy.add_cash_dollars(payout, true, bookkeeping_day)


func _resolve_work_energy_delta(energy_delta: float) -> float:
	var resolved_energy_delta := energy_delta

	if resolved_energy_delta < 0.0 and PlayerMentalState != null and PlayerMentalState.has_method("get_effects"):
		var work_multiplier := float(
			PlayerMentalState.get_effects().get("work_energy_cost_multiplier", 1.0)
		)
		resolved_energy_delta *= work_multiplier

	return resolved_energy_delta


func _connect_game_time_signals() -> void:
	if GameTime == null or not GameTime.has_signal(&"day_changed"):
		return

	if not GameTime.day_changed.is_connected(_on_game_day_changed):
		GameTime.day_changed.connect(_on_game_day_changed)


func _on_game_day_changed(_previous_day: int, current_day: int) -> void:
	_sync_day_state(current_day)


func _sync_day_state(current_day: int = -1) -> void:
	var resolved_day := current_day

	if resolved_day < 0:
		resolved_day = _get_current_day_id()

	if resolved_day <= 0:
		return

	if last_observed_day_id <= 0:
		last_observed_day_id = resolved_day
		return

	if resolved_day == last_observed_day_id:
		return

	worked_day_id = 0 if worked_day_id != resolved_day else worked_day_id
	last_observed_day_id = resolved_day


func _get_current_day_id() -> int:
	if GameTime == null or not GameTime.has_method("get_day"):
		return max(1, last_observed_day_id)

	return max(1, int(GameTime.get_day()))


func _get_current_hour() -> int:
	if GameTime == null or not GameTime.has_method("get_hours"):
		return 0

	return clampi(int(GameTime.get_hours()), 0, 23)
