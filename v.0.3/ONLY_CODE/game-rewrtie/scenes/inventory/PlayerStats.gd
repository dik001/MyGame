class_name PlayerStatsState
extends Node

signal stats_changed(current_stats: Dictionary)
signal tick_applied(tick_name: StringName, delta: Dictionary, current_stats: Dictionary)

@export var max_hp: int = 100
@export var max_hunger: int = 100
@export var max_energy: float = 100.0

@export var hp: int = 100
@export var hunger: int = 50
@export var energy: float = 100.0


func _ready() -> void:
	hp = clampi(hp, 0, max_hp)
	hunger = clampi(hunger, 0, max_hunger)
	energy = clampf(energy, 0.0, max_energy)
	stats_changed.emit(get_stats())


func add_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(clampi(hunger + value, 0, max_hunger)), &"add_hunger", {"hunger": value})


func reduce_hunger(value: int) -> void:
	add_hunger(-value)


func set_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(value), &"set_hunger", {"hunger": value})


func apply_movement_tick() -> void:
	apply_delta({"energy": -0.5}, &"move_tick")


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
