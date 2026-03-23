class_name GameTimeState
extends Node

signal time_changed(absolute_minutes: int, day: int, hours: int, minutes: int)
signal day_changed(previous_day: int, current_day: int)
signal clock_paused_changed(is_paused: bool)

const HOURS_PER_DAY: int = 24
const MINUTES_PER_HOUR: int = 60
const MINUTES_PER_DAY: int = HOURS_PER_DAY * MINUTES_PER_HOUR
const DEFAULT_START_HOURS: int = 7
const DEFAULT_START_MINUTES: int = 25

var run_clock: bool = true
var seconds_per_game_minute: float = 1.0

var _absolute_minutes: int = (DEFAULT_START_HOURS * MINUTES_PER_HOUR) + DEFAULT_START_MINUTES
var _time_accumulator: float = 0.0
var _clock_paused: bool = false
var _initialized_from_scene: bool = false
var _last_emitted_day: int = -1
var _last_sleep_started_day: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_emit_time_changed()


func _process(delta: float) -> void:
	if not run_clock:
		return

	if _clock_paused:
		return

	if seconds_per_game_minute <= 0.0:
		return

	_time_accumulator += delta

	if _time_accumulator < seconds_per_game_minute:
		return

	var minutes_to_advance: int = int(floor(_time_accumulator / seconds_per_game_minute))
	_time_accumulator -= float(minutes_to_advance) * seconds_per_game_minute
	advance_minutes(minutes_to_advance)


func initialize_if_needed(hours: int, minutes: int) -> void:
	if _initialized_from_scene:
		return

	_initialized_from_scene = true
	set_time(hours, minutes, 1)


func configure_clock(is_running: bool, next_seconds_per_game_minute: float) -> void:
	run_clock = is_running
	seconds_per_game_minute = next_seconds_per_game_minute

	if seconds_per_game_minute < 0.01:
		seconds_per_game_minute = 0.01


func set_time(hours: int, minutes: int, day: int = -1) -> void:
	var target_day: int = day

	if target_day < 1:
		target_day = get_day()

	set_absolute_minutes(((target_day - 1) * MINUTES_PER_DAY) + (clampi(hours, 0, 23) * MINUTES_PER_HOUR) + clampi(minutes, 0, 59))


func set_absolute_minutes(total_minutes: int) -> void:
	var next_total: int = total_minutes

	if next_total < 0:
		next_total = 0

	if next_total == _absolute_minutes:
		return

	_absolute_minutes = next_total
	_emit_time_changed()


func advance_minutes(minutes: int) -> void:
	if minutes == 0:
		return

	set_absolute_minutes(_absolute_minutes + minutes)


func set_clock_paused(is_paused: bool) -> void:
	if _clock_paused == is_paused:
		return

	_clock_paused = is_paused
	clock_paused_changed.emit(_clock_paused)


func is_clock_paused() -> bool:
	return _clock_paused


func get_absolute_minutes() -> int:
	return _absolute_minutes


func get_total_minutes() -> int:
	return _absolute_minutes % MINUTES_PER_DAY


func get_day() -> int:
	return int(floor(float(_absolute_minutes) / float(MINUTES_PER_DAY))) + 1


func get_hours() -> int:
	return int(floor(float(get_total_minutes()) / float(MINUTES_PER_HOUR)))


func get_minutes() -> int:
	return get_total_minutes() % MINUTES_PER_HOUR


func get_time_data_for_absolute(total_minutes: int) -> Dictionary:
	var normalized_total: int = total_minutes

	if normalized_total < 0:
		normalized_total = 0
	var day: int = int(floor(float(normalized_total) / float(MINUTES_PER_DAY))) + 1
	var minutes_within_day: int = normalized_total % MINUTES_PER_DAY
	var hours: int = int(floor(float(minutes_within_day) / float(MINUTES_PER_HOUR)))
	var minutes: int = minutes_within_day % MINUTES_PER_HOUR

	return {
		"absolute_minutes": normalized_total,
		"day": day,
		"hours": hours,
		"minutes": minutes,
	}


func get_current_time_data() -> Dictionary:
	return get_time_data_for_absolute(_absolute_minutes)


func has_slept_today() -> bool:
	return _last_sleep_started_day == get_day()


func mark_sleep_started(day: int = -1) -> void:
	var target_day: int = day

	if target_day < 1:
		target_day = get_day()

	_last_sleep_started_day = max(1, target_day)


func get_last_sleep_started_day() -> int:
	return _last_sleep_started_day


func _emit_time_changed() -> void:
	var time_data: Dictionary = get_current_time_data()
	var current_day: int = int(time_data.get("day", 1))

	if _last_emitted_day != -1 and _last_emitted_day != current_day:
		day_changed.emit(_last_emitted_day, current_day)

	_last_emitted_day = current_day
	time_changed.emit(
		int(time_data.get("absolute_minutes", 0)),
		current_day,
		int(time_data.get("hours", 0)),
		int(time_data.get("minutes", 0))
	)
