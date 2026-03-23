class_name PlayerStatsState
extends Node

signal stats_changed(current_stats: Dictionary)
signal tick_applied(tick_name: StringName, delta: Dictionary, current_stats: Dictionary)
signal critical_energy_state_changed(is_critical: bool)

@export var max_hp: int = 100
@export var max_hunger: int = 100
@export var max_energy: float = 100.0
@export_range(0.0, 100.0, 0.5) var critical_energy_threshold: float = 15.0
@export_range(0, 100, 1) var low_hunger_hp_threshold: int = 10
@export_range(1, 1440, 1) var low_hunger_hp_tick_minutes: int = 60
@export_range(1, 100, 1) var low_hunger_hp_loss_per_tick: int = 40

@export var hp: int = 100
@export var hunger: int = 50
@export var energy: float = 100.0

var _last_time_tick_absolute_minutes: int = -1
var _low_hunger_minutes_accumulator: int = 0
var _is_energy_critical: bool = false


func _ready() -> void:
	hp = clampi(hp, 0, max_hp)
	hunger = clampi(hunger, 0, max_hunger)
	energy = clampf(energy, 0.0, max_energy)
	_is_energy_critical = energy <= critical_energy_threshold
	call_deferred("_connect_game_time")
	stats_changed.emit(get_stats())


func add_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(clampi(hunger + value, 0, max_hunger)), &"add_hunger", {"hunger": value})


func reduce_hunger(value: int) -> void:
	add_hunger(-value)


func set_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(value), &"set_hunger", {"hunger": value})


func apply_movement_tick() -> void:
	return


func apply_action_tick(action_name: StringName, delta: Dictionary) -> void:
	apply_delta(delta, action_name)


func apply_delta(delta: Dictionary, tick_name: StringName = &"tick") -> void:
	var changed := false

	if delta.has("hp"):
		changed = _set_hp_internal(hp + int(delta["hp"])) or changed

	if delta.has("hunger"):
		changed = _set_hunger_internal(hunger + int(delta["hunger"])) or changed

	if delta.has("energy"):
		changed = _set_energy_internal(energy + float(delta["energy"])) or changed

	var current_stats := get_stats()

	if changed:
		stats_changed.emit(current_stats)
		_refresh_critical_energy_state()

	tick_applied.emit(tick_name, delta.duplicate(true), current_stats)


func get_stats() -> Dictionary:
	return {
		"hp": hp,
		"hunger": hunger,
		"energy": energy,
		"max_hp": max_hp,
		"max_hunger": max_hunger,
		"max_energy": max_energy,
	}


func _apply_direct_change(changed: bool, tick_name: StringName, delta: Dictionary) -> void:
	var current_stats := get_stats()

	if changed:
		stats_changed.emit(current_stats)
		_refresh_critical_energy_state()

	tick_applied.emit(tick_name, delta.duplicate(true), current_stats)


func _set_hp_internal(value: int) -> bool:
	var next_value := clampi(value, 0, max_hp)

	if next_value == hp:
		return false

	hp = next_value
	return true


func _set_hunger_internal(value: int) -> bool:
	var next_value := clampi(value, 0, max_hunger)

	if next_value == hunger:
		return false

	hunger = next_value
	return true


func _set_energy_internal(value: float) -> bool:
	var next_value := clampf(value, 0.0, max_energy)

	if is_equal_approx(next_value, energy):
		return false

	energy = next_value
	return true


func is_energy_critical() -> bool:
	return _is_energy_critical


func get_critical_energy_threshold() -> float:
	return critical_energy_threshold


func _connect_game_time() -> void:
	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time == null:
		return

	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)

	_last_time_tick_absolute_minutes = game_time.get_absolute_minutes()


func _on_game_time_changed(absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	if _last_time_tick_absolute_minutes < 0:
		_last_time_tick_absolute_minutes = absolute_minutes
		return

	var elapsed_minutes: int = absolute_minutes - _last_time_tick_absolute_minutes
	_last_time_tick_absolute_minutes = absolute_minutes

	if elapsed_minutes <= 0:
		return

	if hunger > low_hunger_hp_threshold or hp <= 0:
		_low_hunger_minutes_accumulator = 0
		return

	_low_hunger_minutes_accumulator += elapsed_minutes
	var hp_loss_total: int = 0

	while _low_hunger_minutes_accumulator >= low_hunger_hp_tick_minutes:
		_low_hunger_minutes_accumulator -= low_hunger_hp_tick_minutes
		hp_loss_total += low_hunger_hp_loss_per_tick

	if hp_loss_total > 0:
		apply_action_tick(&"low_hunger_hp_decay", {"hp": -hp_loss_total})


func _refresh_critical_energy_state() -> void:
	var next_is_critical: bool = energy <= critical_energy_threshold

	if next_is_critical == _is_energy_critical:
		return

	_is_energy_critical = next_is_critical
	critical_energy_state_changed.emit(_is_energy_critical)
