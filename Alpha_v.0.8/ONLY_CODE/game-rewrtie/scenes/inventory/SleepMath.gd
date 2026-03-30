class_name SleepMath
extends RefCounted


static func calculate_sleep_effects(
	stats: PlayerStatsState,
	sleep_duration_minutes: int,
	energy_per_hour: float,
	hp_per_hour: int,
	hunger_per_hour: int,
	min_energy_restore_multiplier_at_zero_hp: float
) -> Dictionary:
	var safe_sleep_minutes: int = max(0, sleep_duration_minutes)
	var sleep_hours: float = float(safe_sleep_minutes) / 60.0
	var base_energy_change: float = sleep_hours * energy_per_hour
	var hp_change: int = int(roundi(sleep_hours * float(hp_per_hour)))
	var hunger_change: int = int(roundi(sleep_hours * float(hunger_per_hour)))
	var hp_ratio: float = 1.0

	if stats != null and stats.max_hp > 0:
		hp_ratio = clampf(float(stats.hp) / float(stats.max_hp), 0.0, 1.0)

	var energy_recovery_multiplier: float = lerpf(
		min_energy_restore_multiplier_at_zero_hp,
		1.0,
		hp_ratio
	)
	var energy_change: float = base_energy_change * energy_recovery_multiplier

	if stats != null:
		energy_change = clampf(stats.energy + energy_change, 0.0, stats.max_energy) - stats.energy
		hp_change = clampi(stats.hp + hp_change, 0, stats.max_hp) - stats.hp
		hunger_change = clampi(stats.hunger + hunger_change, 0, stats.max_hunger) - stats.hunger

	return {
		"sleep_duration_minutes": safe_sleep_minutes,
		"time_change_minutes": safe_sleep_minutes,
		"energy_change": energy_change,
		"hp_change": hp_change,
		"hunger_change": hunger_change,
	}
