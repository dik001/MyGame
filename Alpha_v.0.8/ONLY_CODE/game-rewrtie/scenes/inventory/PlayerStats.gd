class_name PlayerStatsState
extends Node

signal stats_changed(current_stats: Dictionary)
signal tick_applied(tick_name: StringName, delta: Dictionary, current_stats: Dictionary)
signal critical_energy_state_changed(is_critical: bool)
signal hunger_warning_requested(message: String, duration: float)
signal sleep_warning_requested(message: String, duration: float)
signal hygiene_warning_requested(message: String, duration: float)
signal forced_blackout_requested()
signal sleep_state_changed(state: Dictionary)
signal hygiene_state_changed(state: Dictionary)
signal death_occurred(death_payload: Dictionary)
signal death_state_changed(is_dead: bool, death_payload: Dictionary)

const HUNGER_STAGE_SATED: StringName = &"hunger_sated"
const HUNGER_STAGE_HUNGRY: StringName = &"hunger_hungry"
const HUNGER_STAGE_VERY_HUNGRY: StringName = &"hunger_very_hungry"
const HUNGER_STAGE_EXHAUSTED: StringName = &"hunger_exhausted"
const HUNGER_STAGE_STARVING: StringName = &"hunger_starving"
const HUNGER_STAGE_CONDITIONS: Array[StringName] = [
	HUNGER_STAGE_HUNGRY,
	HUNGER_STAGE_VERY_HUNGRY,
	HUNGER_STAGE_EXHAUSTED,
	HUNGER_STAGE_STARVING,
]

const SLEEP_STAGE_NONE: StringName = &""
const SLEEP_STAGE_TIRED: StringName = &"sleep_tired"
const SLEEP_STAGE_VERY_TIRED: StringName = &"sleep_very_tired"
const SLEEP_STAGE_CRITICAL: StringName = &"sleep_critical"
const SLEEP_STAGE_CONDITIONS: Array[StringName] = [
	SLEEP_STAGE_TIRED,
	SLEEP_STAGE_VERY_TIRED,
	SLEEP_STAGE_CRITICAL,
]
const HYGIENE_STAGE_CLEAN: StringName = &"hygiene_clean"
const HYGIENE_STAGE_UNTIDY: StringName = &"hygiene_untidy"
const HYGIENE_STAGE_DIRTY: StringName = &"hygiene_dirty"
const HYGIENE_STAGE_UNSANITARY: StringName = &"hygiene_unsanitary"
const HYGIENE_STAGE_CONDITIONS: Array[StringName] = [
	HYGIENE_STAGE_UNTIDY,
	HYGIENE_STAGE_DIRTY,
	HYGIENE_STAGE_UNSANITARY,
]
const DEFAULT_HUNGER_WARNING_DURATION: float = 3.2
const DEFAULT_SLEEP_WARNING_DURATION: float = 3.2
const DEFAULT_HYGIENE_WARNING_DURATION: float = 3.2
const DEFAULT_BLACKOUT_WARNING_DURATION: float = 2.8
const HYGIENE_REMINDER_INTERVAL_MINUTES: int = 6 * 60
const HYGIENE_SOURCE_TIME: StringName = &"time"
const HYGIENE_SOURCE_SLEEP: StringName = &"sleep"
const HYGIENE_SOURCE_MOVEMENT: StringName = &"movement"
const HYGIENE_SOURCE_BATH: StringName = &"bath"
const HYGIENE_SOURCE_SEX_SCENE: StringName = &"sex_scene"
const HYGIENE_SOURCE_FIGHT: StringName = &"fight"
const HYGIENE_SOURCE_MENSTRUATION: StringName = &"menstruation"
const HYGIENE_SOURCE_BODY_FLUIDS: StringName = &"body_fluids"
const HYGIENE_SOURCE_DIRTY_WORK: StringName = &"dirty_work"
const HYGIENE_SOURCE_BLOOD: StringName = &"blood"
const HYGIENE_SOURCE_EVENT_GRIME: StringName = &"event_grime"
const HYGIENE_SOURCE_HUMILIATION_SCENE: StringName = &"humiliation_scene"
const ITEM_CONDITION_PREFIX := "item_effect_"
const ITEM_CONDITION_INDIGESTION: StringName = &"item_effect_indigestion"
const ITEM_CONDITION_RELAXATION: StringName = &"item_effect_relaxation"
const ITEM_CONDITION_STOMACH_PAIN: StringName = &"item_effect_stomach_pain"
const ITEM_CONDITION_VIGOR: StringName = &"item_effect_vigor"
const ITEM_CONDITION_DRUNK: StringName = &"item_effect_drunk"
const ITEM_CONDITION_UNDER_INFLUENCE: StringName = &"item_effect_under_influence"
const ITEM_CONDITION_FRACTURE_RESISTANCE: StringName = &"item_effect_fracture_resistance"
const ITEM_CONDITION_SOAP_READY: StringName = &"item_effect_soap_ready"
const ITEM_CONDITION_DISEASE_PROTECTION: StringName = &"item_effect_disease_protection"
const ITEM_CONDITION_PREGNANCY_PROTECTION: StringName = &"item_effect_pregnancy_protection"
const ITEM_CONDITION_PAD_PROTECTION: StringName = &"item_effect_pad_protection"
const ITEM_CONDITION_BLEEDING: StringName = &"item_effect_bleeding"

@export var max_hp: int = 100
@export var max_hunger: int = 100
@export var max_energy: float = 100.0
@export_range(1, 100, 1) var max_hygiene: int = 100
@export_range(0.0, 100.0, 0.5) var critical_energy_threshold: float = 15.0
@export_range(0, 100, 1) var hunger_hungry_threshold: int = 60
@export_range(0, 100, 1) var hunger_severe_threshold: int = 30
@export_range(0, 100, 1) var hunger_exhaustion_threshold: int = 10
@export_range(0, 100, 1) var hunger_starvation_threshold: int = 5
@export_range(0, 100, 1) var hygiene_clean_threshold: int = 76
@export_range(0, 100, 1) var hygiene_untidy_threshold: int = 51
@export_range(0, 100, 1) var hygiene_dirty_threshold: int = 26
@export_range(0.0, 1.0, 0.01) var severe_hunger_energy_recovery_multiplier: float = 0.9
@export_range(0.0, 1.0, 0.01) var severe_hunger_movement_speed_multiplier: float = 0.95
@export_range(0.0, 1.0, 0.01) var exhaustion_energy_recovery_multiplier: float = 0.8
@export_range(0.0, 1.0, 0.01) var exhaustion_movement_speed_multiplier: float = 0.9
@export var exhaustion_blocks_passive_hp_regen: bool = true
@export_range(0.1, 60.0, 0.1) var starvation_damage_interval_seconds: float = 15.0
@export_range(1, 100, 1) var starvation_damage_per_tick: int = 1
@export_range(0.0, 24.0, 0.1) var awake_hunger_decay_per_hour: float = 4.0
@export_range(0.0, 24.0, 0.1) var awake_hygiene_decay_per_hour: float = 1.0
@export_range(0.0, 24.0, 0.1) var sleep_hygiene_decay_per_hour: float = 0.5
@export_range(0.0, 1.0, 0.01) var movement_hygiene_decay_per_step: float = 0.03
@export_range(1, 10080, 1) var sleep_tired_threshold_minutes: int = 24 * 60
@export_range(1, 10080, 1) var sleep_very_tired_threshold_minutes: int = 36 * 60
@export_range(1, 10080, 1) var sleep_critical_threshold_minutes: int = 44 * 60
@export_range(1, 10080, 1) var sleep_blackout_threshold_minutes: int = 48 * 60
@export_range(1, 1440, 1) var forced_blackout_sleep_minutes: int = 8 * 60
@export_range(1, 1440, 1) var full_reset_sleep_minutes: int = 6 * 60
@export_range(0.0, 4.0, 0.05) var short_sleep_recovery_ratio: float = 1.0
@export var sleep_energy_per_hour: float = 12.5
@export var sleep_hp_per_hour: int = 10
@export var sleep_hunger_per_hour: int = -2
@export_range(0.1, 1.0, 0.05) var sleep_min_energy_restore_multiplier_at_zero_hp: float = 0.45
@export_range(0, 100, 1) var bath_hygiene_restore_amount: int = 100
@export_range(0.0, 1.0, 0.01) var dirty_hygiene_movement_speed_multiplier: float = 0.95
@export_range(0.0, 1.0, 0.01) var unsanitary_hygiene_movement_speed_multiplier: float = 0.88
@export_range(0.0, 10.0, 0.1) var dirty_hygiene_mood_pressure: float = 1.0
@export_range(0.0, 10.0, 0.1) var unsanitary_hygiene_mood_pressure: float = 2.0
@export_range(0.0, 1.0, 0.01) var dirty_hygiene_social_penalty_weight: float = 0.6
@export_range(0.0, 1.0, 0.01) var unsanitary_hygiene_social_penalty_weight: float = 1.0
@export_range(0.0, 1.0, 0.01) var dirty_hygiene_illness_risk: float = 0.2
@export_range(0.0, 1.0, 0.01) var unsanitary_hygiene_illness_risk: float = 0.45
@export_range(0.0, 1.0, 0.01) var clean_dirt_visual_alpha: float = 0.0
@export_range(0.0, 1.0, 0.01) var untidy_dirt_visual_alpha: float = 0.22
@export_range(0.0, 1.0, 0.01) var dirty_dirt_visual_alpha: float = 0.55
@export_range(0.0, 1.0, 0.01) var unsanitary_dirt_visual_alpha: float = 0.90
@export var future_hygiene_enables_illness_hooks: bool = true
@export var future_hygiene_enables_smell_hooks: bool = true
@export var future_hygiene_enables_npc_reaction_hooks: bool = true
@export_range(0, 100, 1) var future_sex_scene_hygiene_loss: int = 20
@export_range(0, 100, 1) var future_fight_hygiene_loss: int = 14
@export_range(0, 100, 1) var future_menstruation_hygiene_loss: int = 8
@export_range(0, 100, 1) var future_body_fluids_hygiene_loss: int = 12
@export_range(0, 100, 1) var future_dirty_work_hygiene_loss: int = 10
@export_range(0, 100, 1) var future_blood_hygiene_loss: int = 10
@export_range(0, 100, 1) var future_event_grime_hygiene_loss: int = 6
@export_range(0, 100, 1) var future_humiliation_scene_hygiene_loss: int = 8
@export_range(0, 100, 1) var future_snack_hunger_restore: int = 12
@export_range(0, 100, 1) var future_cheap_food_hunger_restore: int = 25
@export_range(0, 100, 1) var future_hot_meal_hunger_restore: int = 50
@export_range(0, 100, 1) var future_soda_hunger_restore: int = 6
@export_range(0, 100, 1) var future_alcohol_hunger_restore: int = 0
@export_range(1, 1440, 1) var indigestion_duration_minutes: int = 6 * 60
@export_range(1, 1440, 1) var relaxation_duration_minutes: int = 4 * 60
@export_range(1, 1440, 1) var stomach_pain_duration_minutes: int = 6 * 60
@export_range(1, 1440, 1) var vigor_duration_minutes: int = 5 * 60
@export_range(1, 1440, 1) var beer_drunk_duration_minutes: int = 3 * 60
@export_range(1, 1440, 1) var wine_drunk_duration_minutes: int = 6 * 60
@export_range(1, 1440, 1) var selfmade_duration_minutes: int = 8 * 60
@export_range(1, 1440, 1) var fracture_resistance_duration_minutes: int = 6 * 60
@export_range(1, 10080, 1) var medicine_effect_duration_minutes: int = 24 * 60
@export_range(1, 10080, 1) var contraceptive_fallback_duration_minutes: int = 24 * 60
@export_range(1, 10080, 1) var pads_fallback_duration_minutes: int = 24 * 60
@export_range(1, 1440, 1) var noodle_overuse_window_minutes: int = 6 * 60
@export_range(1, 10, 1) var noodle_overuse_threshold: int = 3
@export_range(0, 100, 1) var soap_bonus_hygiene_amount: int = 30
@export_range(1, 1440, 1) var soap_bonus_window_minutes: int = 60
@export_range(0, 100, 1) var cigarette_nicotine_addiction_gain: int = 8
@export_range(0, 100, 1) var vape_nicotine_addiction_gain: int = 12
@export_range(0.0, 100.0, 0.1) var nicotine_addiction: float = 0.0
@export_range(0.0, 1.0, 0.01) var future_disease_risk_multiplier: float = 0.9
@export_range(0.0, 1.0, 0.01) var future_pregnancy_risk_multiplier: float = 0.11
@export_range(0.0, 1.0, 0.01) var future_menstruation_leak_risk_multiplier: float = 0.3
@export_range(0.0, 1.0, 0.01) var future_fracture_risk_multiplier: float = 0.85

@export var hp: int = 100
@export var hunger: int = 100
@export var energy: float = 100.0
@export var hygiene: int = 100

var _last_time_tick_absolute_minutes: int = -1
var _awake_hunger_decay_accumulator: float = 0.0
var _awake_hygiene_decay_accumulator: float = 0.0
var _sleep_hygiene_decay_accumulator: float = 0.0
var _movement_hygiene_decay_accumulator: float = 0.0
var _pending_sleep_time_advance_minutes: int = 0
var _starvation_damage_accumulator: float = 0.0
var _is_energy_critical: bool = false
var _last_sleep_finished_absolute_minutes: int = -1
var _pending_forced_blackout := false
var _forced_blackout_in_progress := false
var _current_sleep_stage_id: StringName = SLEEP_STAGE_NONE
var _current_hunger_stage_id: StringName = HUNGER_STAGE_SATED
var _current_hygiene_stage_id: StringName = HYGIENE_STAGE_CLEAN
var _last_sleep_state_signature: Dictionary = {}
var _last_hygiene_state_signature: Dictionary = {}
var _last_hygiene_warning_absolute_minutes: int = -1
var _hygiene_npc_comment_state: Dictionary = {}
var _noodle_use_absolute_minutes: Array[int] = []
var _default_state: Dictionary = {}
var _is_dead := false
var _death_payload: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_capture_default_state()
	hp = clampi(hp, 0, max_hp)
	hunger = clampi(hunger, 0, max_hunger)
	energy = clampf(energy, 0.0, max_energy)
	hygiene = clampi(hygiene, 0, max_hygiene)
	_is_energy_critical = energy <= critical_energy_threshold
	_current_hunger_stage_id = _resolve_hunger_stage_id(hunger)
	_current_hygiene_stage_id = _resolve_hygiene_stage_id(hygiene)
	refresh_hunger_runtime_state(false, true)
	refresh_hygiene_runtime_state(false, true)
	call_deferred("_connect_game_time")
	stats_changed.emit(get_stats())


func _process(delta: float) -> void:
	if hp <= 0:
		_starvation_damage_accumulator = 0.0
		return

	if _current_hunger_stage_id != HUNGER_STAGE_STARVING:
		_starvation_damage_accumulator = 0.0
		return

	if starvation_damage_interval_seconds <= 0.0 or starvation_damage_per_tick <= 0:
		return

	if GameTime != null and GameTime.has_method("is_clock_paused") and GameTime.is_clock_paused():
		return

	_starvation_damage_accumulator += delta

	if _starvation_damage_accumulator < starvation_damage_interval_seconds:
		return

	var starvation_ticks: int = int(
		floor(_starvation_damage_accumulator / starvation_damage_interval_seconds)
	)
	_starvation_damage_accumulator -= float(starvation_ticks) * starvation_damage_interval_seconds

	if starvation_ticks <= 0:
		return

	apply_action_tick(
		&"hunger_starvation_damage",
		{"hp": -(starvation_ticks * starvation_damage_per_tick)}
	)

	if hp <= 0:
		_starvation_damage_accumulator = 0.0


func add_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(clampi(hunger + value, 0, max_hunger)), &"add_hunger", {"hunger": value})


func reduce_hunger(value: int) -> void:
	add_hunger(-value)


func set_hunger(value: int) -> void:
	_apply_direct_change(_set_hunger_internal(value), &"set_hunger", {"hunger": value})


func consume_food_hunger(amount: int, _source_name: String = "") -> int:
	var resolved_amount: int = max(0, amount)

	if resolved_amount <= 0:
		return 0

	var previous_hunger: int = hunger
	apply_action_tick(&"consume_food", {"hunger": resolved_amount})
	return max(0, hunger - previous_hunger)


func can_use_item(item_data: ItemData, item_state: Dictionary = {}) -> Dictionary:
	var result := {
		"success": false,
		"message": "",
		"item_name": item_data.get_display_name() if item_data != null else "",
	}

	if _is_dead:
		result["message"] = "Сейчас это невозможно."
		return result

	if item_data == null:
		result["message"] = "Предмет не найден."
		return result

	if not item_data.can_use_directly():
		result["message"] = "Этот предмет нельзя использовать напрямую."
		return result

	if FoodFreshness.is_spoiled(item_data, item_state):
		result["message"] = "Эта еда испорчена."
		return result

	result["success"] = true
	result["message"] = "Можно использовать."
	return result


func apply_item_use(item_data: ItemData, item_state: Dictionary = {}) -> Dictionary:
	var result := can_use_item(item_data, item_state)

	if not bool(result.get("success", false)):
		return result

	if item_data == null:
		return result

	var instant_delta: Dictionary = item_data.get_instant_stat_delta()
	var stat_delta: Dictionary = {}
	var hp_delta: int = int(instant_delta.get("hp", 0))
	var hunger_delta: int = int(instant_delta.get("hunger", 0))
	var energy_delta: int = int(instant_delta.get("energy", 0))
	var mood_delta: int = int(instant_delta.get("mood", 0))
	var stress_delta: int = int(instant_delta.get("stress", 0))

	if hp_delta != 0:
		stat_delta["hp"] = hp_delta

	if hunger_delta != 0:
		stat_delta["hunger"] = hunger_delta

	if energy_delta != 0:
		stat_delta["energy"] = energy_delta

	if not stat_delta.is_empty():
		var tick_name: StringName = &"use_item"

		if hunger_delta > 0:
			tick_name = &"consume_food"

		apply_action_tick(tick_name, stat_delta)

	var mental_state := _get_player_mental_state()

	if mental_state != null and mental_state.has_method("apply_delta") and (mood_delta != 0 or stress_delta != 0):
		mental_state.apply_delta(
			float(mood_delta),
			float(stress_delta),
			&"item_use",
			[item_data.id, "item_use"]
		)

	_apply_item_use_effects(item_data)
	_refresh_item_runtime_state()
	result["message"] = "Использовано: %s." % item_data.get_display_name()
	return result


func get_nicotine_addiction() -> float:
	return clampf(nicotine_addiction, 0.0, 100.0)


func get_disease_risk_multiplier() -> float:
	return _get_item_modifier_multiplier("disease_risk_multiplier", 1.0)


func get_pregnancy_risk_multiplier() -> float:
	return _get_item_modifier_multiplier("pregnancy_risk_multiplier", 1.0)


func get_menstruation_leak_risk_multiplier() -> float:
	return _get_item_modifier_multiplier("menstruation_leak_risk_multiplier", 1.0)


func has_active_fracture_resistance() -> bool:
	return _has_item_condition(ITEM_CONDITION_FRACTURE_RESISTANCE)


func get_current_drunk_level() -> int:
	var condition_payload := _get_item_condition_payload(ITEM_CONDITION_DRUNK)
	return max(0, int(condition_payload.get("level", 0)))


func has_bleeding() -> bool:
	return _has_item_condition(ITEM_CONDITION_BLEEDING)


func start_bleeding(payload: Dictionary = {}) -> void:
	var bleeding_payload: Dictionary = _build_item_condition_payload(
		"Кровотечение",
		"Нужно остановить кровь",
		"Кровотечение активно. Бинты помогут быстро остановить его."
	)
	bleeding_payload["hidden_in_ui"] = true
	bleeding_payload.merge(payload, true)
	_upsert_item_condition(ITEM_CONDITION_BLEEDING, bleeding_payload, -1)


func clear_bleeding() -> bool:
	return _remove_item_condition(ITEM_CONDITION_BLEEDING)


func consume_soap_bath_bonus() -> int:
	var payload := _get_item_condition_payload(ITEM_CONDITION_SOAP_READY)

	if payload.is_empty():
		return 0

	if _is_item_condition_expired(payload, _get_current_absolute_minutes()):
		_remove_item_condition(ITEM_CONDITION_SOAP_READY)
		return 0

	var bonus_amount: int = max(0, int(payload.get("bonus_hygiene", soap_bonus_hygiene_amount)))
	_remove_item_condition(ITEM_CONDITION_SOAP_READY)
	return bonus_amount


func apply_movement_tick() -> void:
	if movement_hygiene_decay_per_step <= 0.0:
		return

	_movement_hygiene_decay_accumulator += movement_hygiene_decay_per_step
	var hygiene_loss: int = int(floor(_movement_hygiene_decay_accumulator))

	if hygiene_loss <= 0:
		return

	_movement_hygiene_decay_accumulator -= float(hygiene_loss)
	apply_action_tick(&"movement_hygiene_decay", {"hygiene": -hygiene_loss})


func apply_action_tick(action_name: StringName, delta: Dictionary) -> void:
	apply_delta(delta, action_name)


func apply_delta(delta: Dictionary, tick_name: StringName = &"tick") -> void:
	if _is_dead:
		return

	var changed := false

	if delta.has("hp"):
		changed = _set_hp_internal(hp + int(delta["hp"])) or changed

	if delta.has("hunger"):
		changed = _set_hunger_internal(hunger + int(delta["hunger"])) or changed

	if delta.has("energy"):
		changed = _set_energy_internal(energy + float(delta["energy"])) or changed

	if delta.has("hygiene"):
		changed = _set_hygiene_internal(hygiene + int(delta["hygiene"])) or changed

	var current_stats := _finalize_stat_change(changed)
	_maybe_trigger_death(tick_name, delta, current_stats)
	tick_applied.emit(tick_name, delta.duplicate(true), current_stats)


func get_stats() -> Dictionary:
	var hunger_state := get_hunger_state()

	return {
		"hp": hp,
		"hunger": hunger,
		"energy": energy,
		"max_hp": max_hp,
		"max_hunger": max_hunger,
		"max_energy": max_energy,
		"hunger_stage_id": String(hunger_state.get("stage_id", "")),
		"hunger_movement_speed_multiplier": float(
			hunger_state.get("movement_speed_multiplier", 1.0)
		),
		"hunger_energy_recovery_multiplier": float(
			hunger_state.get("energy_recovery_multiplier", 1.0)
		),
	}


func _apply_direct_change(changed: bool, tick_name: StringName, delta: Dictionary) -> void:
	var current_stats := _finalize_stat_change(changed)
	_maybe_trigger_death(tick_name, delta, current_stats)
	tick_applied.emit(tick_name, delta.duplicate(true), current_stats)


func is_dead() -> bool:
	return _is_dead


func get_death_payload() -> Dictionary:
	return _death_payload.duplicate(true)


func _finalize_stat_change(changed: bool) -> Dictionary:
	if changed:
		refresh_hunger_runtime_state(true)
		refresh_hygiene_runtime_state(true)

	var current_stats := get_stats()

	if changed:
		stats_changed.emit(current_stats)
		_refresh_critical_energy_state()

	return current_stats


func _set_hp_internal(value: int) -> bool:
	var next_value := clampi(value, 0, max_hp)

	if next_value == hp:
		return false

	hp = next_value
	return true


func _maybe_trigger_death(
	tick_name: StringName,
	delta: Dictionary,
	current_stats: Dictionary
) -> void:
	if _is_dead or hp > 0:
		return

	_is_dead = true
	_pending_forced_blackout = false
	_forced_blackout_in_progress = false
	_starvation_damage_accumulator = 0.0
	_death_payload = {
		"cause": String(tick_name),
		"tick_name": String(tick_name),
		"delta": delta.duplicate(true),
		"absolute_minutes": _get_current_absolute_minutes(),
		"day": GameTime.get_day() if GameTime != null and GameTime.has_method("get_day") else 1,
		"room_scene_path": (
			String(GameManager.get_current_room_scene_path())
			if GameManager != null and GameManager.has_method("get_current_room_scene_path")
			else ""
		),
		"stats": current_stats.duplicate(true),
	}
	death_state_changed.emit(true, _death_payload.duplicate(true))
	death_occurred.emit(_death_payload.duplicate(true))


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


func _set_hygiene_internal(value: int) -> bool:
	var next_value := clampi(value, 0, max_hygiene)

	if next_value == hygiene:
		return false

	hygiene = next_value
	return true


func is_energy_critical() -> bool:
	return _is_energy_critical


func get_critical_energy_threshold() -> float:
	return critical_energy_threshold


func get_max_hygiene_value() -> int:
	return max_hygiene


func get_hygiene_value() -> int:
	return hygiene


func get_hunger_state() -> Dictionary:
	var title := "Сытость"
	var status_text := "Без штрафов"
	var description := "Организм пока держится ровно. Голод не мешает движению и отдыху."
	var energy_recovery_multiplier := 1.0
	var movement_speed_multiplier := 1.0
	var blocks_passive_hp_regen := false

	match _current_hunger_stage_id:
		HUNGER_STAGE_HUNGRY:
			title = "Голод"
			status_text = "Давление нарастает"
			description = "Желудок пустеет. Пока голод только давит на нервы и напоминает о себе."
		HUNGER_STAGE_VERY_HUNGRY:
			title = "Сильный голод"
			status_text = "Энергия восстанавливается хуже"
			description = "Сильный голод режет восстановление энергии на 10% и замедляет шаг на 5%."
			energy_recovery_multiplier = severe_hunger_energy_recovery_multiplier
			movement_speed_multiplier = severe_hunger_movement_speed_multiplier
		HUNGER_STAGE_EXHAUSTED:
			title = "Истощение"
			status_text = "Силы на исходе"
			description = "Истощение режет восстановление энергии на 20%, замедляет движение на 10% и срывает естественное восстановление."
			energy_recovery_multiplier = exhaustion_energy_recovery_multiplier
			movement_speed_multiplier = exhaustion_movement_speed_multiplier
			blocks_passive_hp_regen = exhaustion_blocks_passive_hp_regen
		HUNGER_STAGE_STARVING:
			title = "Голодание"
			status_text = "HP убывает"
			description = "Тело уже горит изнутри: каждые %.0f сек теряется %d HP, а штрафы истощения сохраняются." % [
				starvation_damage_interval_seconds,
				starvation_damage_per_tick,
			]
			energy_recovery_multiplier = exhaustion_energy_recovery_multiplier
			movement_speed_multiplier = exhaustion_movement_speed_multiplier
			blocks_passive_hp_regen = exhaustion_blocks_passive_hp_regen

	return {
		"stage_id": String(_current_hunger_stage_id),
		"title": title,
		"status_text": status_text,
		"description": description,
		"energy_recovery_multiplier": energy_recovery_multiplier,
		"movement_speed_multiplier": movement_speed_multiplier,
		"blocks_passive_hp_regen": blocks_passive_hp_regen,
		"is_starving": _current_hunger_stage_id == HUNGER_STAGE_STARVING,
		"is_exhausted_or_worse": _get_hunger_stage_severity(_current_hunger_stage_id) >= 3,
		"value": hunger,
	}


func get_hunger_stage_id() -> StringName:
	return _current_hunger_stage_id


func get_hygiene_stage_id() -> StringName:
	return _current_hygiene_stage_id


func get_hygiene_state() -> Dictionary:
	var title := "Чистота"
	var status_text := "Без заметных следов"
	var description := "Тело отмыто, одежда пока не липнет к коже, и мир ещё не успел прилипнуть обратно."
	var movement_speed_multiplier := 1.0
	var mood_pressure := 0.0
	var social_penalty_weight := 0.0
	var illness_risk := 0.0
	var dirt_visual_alpha := clean_dirt_visual_alpha
	var npc_comment_tag := "clean"

	match _current_hygiene_stage_id:
		HYGIENE_STAGE_UNTIDY:
			title = "Неопрятность"
			status_text = "Пятна уже заметны"
			description = "Пыль и пот ещё не делают жизнь невыносимой, но тело уже просит воды и тишины ванной."
			dirt_visual_alpha = untidy_dirt_visual_alpha
			npc_comment_tag = "untidy"
		HYGIENE_STAGE_DIRTY:
			title = "Грязь"
			status_text = "Шаг тяжелеет"
			description = "Кожа липнет, на ткани проступили пятна. Движения становятся тяжелее, а чужие взгляды задерживаются слишком долго."
			movement_speed_multiplier = dirty_hygiene_movement_speed_multiplier
			mood_pressure = dirty_hygiene_mood_pressure
			social_penalty_weight = dirty_hygiene_social_penalty_weight
			illness_risk = dirty_hygiene_illness_risk
			dirt_visual_alpha = dirty_dirt_visual_alpha
			npc_comment_tag = "dirty"
		HYGIENE_STAGE_UNSANITARY:
			title = "Антисанитария"
			status_text = "Запущенность бросается в глаза"
			description = "Грязь въелась в тело и одежду. Шаг вязнет, самоощущение тухнет, а состояние уже просится в болезни, запах и унизительные замечания."
			movement_speed_multiplier = unsanitary_hygiene_movement_speed_multiplier
			mood_pressure = unsanitary_hygiene_mood_pressure
			social_penalty_weight = unsanitary_hygiene_social_penalty_weight
			illness_risk = unsanitary_hygiene_illness_risk
			dirt_visual_alpha = unsanitary_dirt_visual_alpha
			npc_comment_tag = "unsanitary"

	return {
		"stage_id": String(_current_hygiene_stage_id),
		"title": title,
		"status_text": status_text,
		"description": description,
		"movement_speed_multiplier": movement_speed_multiplier,
		"mood_pressure": mood_pressure,
		"social_penalty_weight": social_penalty_weight,
		"illness_risk": illness_risk,
		"dirt_visual_alpha": dirt_visual_alpha,
		"npc_comment_tag": npc_comment_tag,
		"value": hygiene,
		"max_value": max_hygiene,
		"is_dirty_or_worse": _get_hygiene_stage_severity(_current_hygiene_stage_id) >= 2,
		"is_unsanitary": _current_hygiene_stage_id == HYGIENE_STAGE_UNSANITARY,
		"future_illness_hook_enabled": future_hygiene_enables_illness_hooks,
		"future_smell_hook_enabled": future_hygiene_enables_smell_hooks,
		"future_npc_reaction_hook_enabled": future_hygiene_enables_npc_reaction_hooks,
	}


func restore_hygiene(amount: int, source_id: StringName = HYGIENE_SOURCE_BATH) -> int:
	var resolved_amount: int = max(0, amount)

	if resolved_amount <= 0:
		return 0

	var previous_hygiene: int = hygiene
	apply_action_tick(StringName("%s_hygiene_restore" % String(source_id)), {"hygiene": resolved_amount})
	return max(0, hygiene - previous_hygiene)


func apply_hygiene_source(
	source_id: StringName,
	intensity := 1.0,
	payload: Dictionary = {}
) -> int:
	var hygiene_loss: int = _resolve_hygiene_source_loss(source_id, intensity, payload)

	if hygiene_loss <= 0:
		return 0

	var previous_hygiene: int = hygiene
	apply_action_tick(StringName("%s_hygiene_loss" % String(source_id)), {"hygiene": -hygiene_loss})

	if PlayerBodyState != null and payload.has("blood_delta") and PlayerBodyState.has_method("set_body_blood"):
		var current_body_blood := 0

		if PlayerBodyState.has_method("get_body_state"):
			var body_state: Variant = PlayerBodyState.get_body_state()

			if body_state is Dictionary:
				current_body_blood = int((body_state as Dictionary).get("body_blood", 0))

		PlayerBodyState.set_body_blood(current_body_blood + int(payload.get("blood_delta", 0)))

	return max(0, previous_hygiene - hygiene)


func consume_hygiene_npc_comment(npc_id: StringName) -> Dictionary:
	var stage_severity: int = _get_hygiene_stage_severity(_current_hygiene_stage_id)

	if stage_severity < 2:
		return {
			"should_comment": false,
			"stage_id": String(_current_hygiene_stage_id),
		}

	var npc_key: String = String(npc_id).strip_edges().to_lower()

	if npc_key.is_empty():
		npc_key = "unknown"

	var current_day: int = GameTime.get_day()
	var last_entry: Dictionary = {}

	if _hygiene_npc_comment_state.has(npc_key) and _hygiene_npc_comment_state[npc_key] is Dictionary:
		last_entry = (_hygiene_npc_comment_state[npc_key] as Dictionary).duplicate(true)

	var last_day: int = int(last_entry.get("day_id", -1))
	var last_stage_severity: int = int(last_entry.get("stage_severity", 0))
	var last_stage_id: String = String(last_entry.get("stage_id", ""))
	var should_comment: bool = (
		last_day != current_day
		or stage_severity > last_stage_severity
		or last_stage_id != String(_current_hygiene_stage_id)
	)

	if not should_comment:
		return {
			"should_comment": false,
			"stage_id": String(_current_hygiene_stage_id),
			"state": get_hygiene_state(),
		}

	_hygiene_npc_comment_state[npc_key] = {
		"day_id": current_day,
		"stage_id": String(_current_hygiene_stage_id),
		"stage_severity": stage_severity,
		"absolute_minutes": GameTime.get_absolute_minutes(),
	}

	return {
		"should_comment": true,
		"stage_id": String(_current_hygiene_stage_id),
		"state": get_hygiene_state(),
	}


func get_movement_speed_multiplier() -> float:
	var hunger_multiplier := float(get_hunger_state().get("movement_speed_multiplier", 1.0))
	var hygiene_multiplier := float(get_hygiene_state().get("movement_speed_multiplier", 1.0))
	var equipment_multiplier := 1.0

	if PlayerEquipment != null and PlayerEquipment.has_method("get_movement_speed_multiplier"):
		equipment_multiplier = maxf(0.05, float(PlayerEquipment.get_movement_speed_multiplier()))

	return maxf(0.05, hunger_multiplier * hygiene_multiplier * equipment_multiplier)


func get_energy_recovery_multiplier() -> float:
	return float(get_hunger_state().get("energy_recovery_multiplier", 1.0))


func is_passive_hp_regen_blocked() -> bool:
	return bool(get_hunger_state().get("blocks_passive_hp_regen", false))


func get_food_restore_reference_values() -> Dictionary:
	return {
		"snack": future_snack_hunger_restore,
		"cheap_food": future_cheap_food_hunger_restore,
		"hot_meal": future_hot_meal_hunger_restore,
		"soda": future_soda_hunger_restore,
		"alcohol": future_alcohol_hunger_restore,
	}


func _get_player_mental_state() -> Node:
	var mental_state := get_node_or_null("/root/PlayerMentalState")
	return mental_state if is_instance_valid(mental_state) else null


func _get_freelance_state() -> Node:
	var freelance_state := get_node_or_null("/root/FreelanceState")
	return freelance_state if is_instance_valid(freelance_state) else null


func _get_current_absolute_minutes() -> int:
	if GameTime != null and GameTime.has_method("get_absolute_minutes"):
		return GameTime.get_absolute_minutes()

	return 0


func _resolve_effect_duration(effect_data: Dictionary, fallback_minutes: int) -> int:
	if effect_data.has("duration_minutes"):
		return max(0, int(effect_data.get("duration_minutes", fallback_minutes)))

	return max(0, fallback_minutes)


func _build_item_condition_payload(
	title: String,
	status_text: String,
	description: String
) -> Dictionary:
	return {
		"item_effect": true,
		"title": title,
		"status_text": status_text,
		"description": description,
		"hidden_in_ui": false,
		"clear_on_new_day": false,
	}


func _is_item_condition_expired(payload: Dictionary, current_absolute_minutes: int) -> bool:
	var expires_at: int = int(payload.get("expires_at_absolute_minutes", -1))
	return expires_at >= 0 and current_absolute_minutes >= expires_at


func _get_active_item_condition_entries() -> Array[Dictionary]:
	var freelance_state := _get_freelance_state()
	var result: Array[Dictionary] = []

	if freelance_state == null or not freelance_state.has_method("get_active_conditions"):
		return result

	var raw_entries: Variant = freelance_state.call("get_active_conditions")

	if not (raw_entries is Array):
		return result

	for entry_variant in raw_entries:
		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var payload_variant: Variant = entry.get("payload", {})
		var payload: Dictionary = payload_variant if payload_variant is Dictionary else {}
		var condition_id_text: String = String(entry.get("id", "")).strip_edges()

		if condition_id_text.is_empty():
			continue

		if bool(payload.get("item_effect", false)) or condition_id_text.begins_with(ITEM_CONDITION_PREFIX):
			result.append({
				"id": condition_id_text,
				"payload": payload.duplicate(true),
			})

	return result


func _get_item_condition_payload(condition_id: StringName) -> Dictionary:
	var condition_id_text: String = String(condition_id)

	if condition_id_text.is_empty():
		return {}

	for entry in _get_active_item_condition_entries():
		if String(entry.get("id", "")) != condition_id_text:
			continue

		var payload_variant: Variant = entry.get("payload", {})
		return payload_variant.duplicate(true) if payload_variant is Dictionary else {}

	return {}


func _has_item_condition(condition_id: StringName) -> bool:
	var payload := _get_item_condition_payload(condition_id)

	if payload.is_empty():
		return false

	if _is_item_condition_expired(payload, _get_current_absolute_minutes()):
		_remove_item_condition(condition_id)
		return false

	return true


func _upsert_item_condition(condition_id: StringName, payload: Dictionary = {}, duration_minutes: int = -1) -> void:
	var freelance_state := _get_freelance_state()

	if freelance_state == null:
		return

	var normalized_payload: Dictionary = payload.duplicate(true)
	var current_absolute_minutes: int = _get_current_absolute_minutes()
	normalized_payload["item_effect"] = true
	normalized_payload["condition_id"] = String(condition_id)
	normalized_payload["applied_at_absolute_minutes"] = current_absolute_minutes
	normalized_payload["applied_day_id"] = GameTime.get_day() if GameTime != null and GameTime.has_method("get_day") else 1

	if duration_minutes > 0:
		normalized_payload["expires_at_absolute_minutes"] = (
			current_absolute_minutes + duration_minutes
		)
	else:
		normalized_payload.erase("expires_at_absolute_minutes")

	if freelance_state.has_method("remove_condition"):
		freelance_state.call("remove_condition", condition_id)

	if freelance_state.has_method("add_condition"):
		freelance_state.call("add_condition", condition_id, normalized_payload)


func _remove_item_condition(condition_id: StringName) -> bool:
	var freelance_state := _get_freelance_state()

	if freelance_state == null or not freelance_state.has_method("has_condition"):
		return false

	if not bool(freelance_state.call("has_condition", condition_id)):
		return false

	if freelance_state.has_method("remove_condition"):
		freelance_state.call("remove_condition", condition_id)

	return true


func _remove_all_item_conditions() -> void:
	var freelance_state := _get_freelance_state()

	if freelance_state == null or not freelance_state.has_method("remove_condition"):
		return

	for entry in _get_active_item_condition_entries():
		var condition_id_text: String = String(entry.get("id", "")).strip_edges()

		if condition_id_text.is_empty():
			continue

		freelance_state.call("remove_condition", StringName(condition_id_text))


func _prune_expired_item_conditions() -> void:
	var current_absolute_minutes: int = _get_current_absolute_minutes()
	var expired_ids: Array[StringName] = []

	for entry in _get_active_item_condition_entries():
		var payload_variant: Variant = entry.get("payload", {})

		if not (payload_variant is Dictionary):
			continue

		var payload: Dictionary = payload_variant

		if not _is_item_condition_expired(payload, current_absolute_minutes):
			continue

		expired_ids.append(StringName(String(entry.get("id", ""))))

	for condition_id in expired_ids:
		_remove_item_condition(condition_id)


func _get_item_modifier_multiplier(modifier_key: String, default_value: float = 1.0) -> float:
	var resolved_multiplier: float = default_value
	var current_absolute_minutes: int = _get_current_absolute_minutes()

	for entry in _get_active_item_condition_entries():
		var payload_variant: Variant = entry.get("payload", {})

		if not (payload_variant is Dictionary):
			continue

		var payload: Dictionary = payload_variant

		if _is_item_condition_expired(payload, current_absolute_minutes):
			continue

		if String(payload.get("modifier_key", "")).strip_edges() != modifier_key:
			continue

		resolved_multiplier *= float(payload.get("multiplier", 1.0))

	return maxf(0.0, resolved_multiplier)


func _prune_noodle_history(current_absolute_minutes: int) -> void:
	if noodle_overuse_window_minutes <= 0:
		_noodle_use_absolute_minutes.clear()
		return

	var min_allowed_absolute_minutes: int = current_absolute_minutes - noodle_overuse_window_minutes
	var filtered_history: Array[int] = []

	for entry_minutes in _noodle_use_absolute_minutes:
		if entry_minutes < min_allowed_absolute_minutes:
			continue

		filtered_history.append(entry_minutes)

	_noodle_use_absolute_minutes = filtered_history


func _add_nicotine_addiction(amount: float) -> void:
	nicotine_addiction = clampf(nicotine_addiction + amount, 0.0, 100.0)


func _apply_simple_item_condition(
	condition_id: StringName,
	title: String,
	status_text: String,
	description: String,
	duration_minutes: int,
	extra_payload: Dictionary = {}
) -> void:
	var payload: Dictionary = _build_item_condition_payload(title, status_text, description)
	payload.merge(extra_payload, true)
	_upsert_item_condition(condition_id, payload, duration_minutes)


func _apply_item_use_effects(item_data: ItemData) -> void:
	if item_data == null:
		return

	for effect_variant in item_data.get_use_effects():
		if not (effect_variant is Dictionary):
			continue

		_apply_single_item_effect(item_data, effect_variant)


func _apply_single_item_effect(item_data: ItemData, raw_effect: Dictionary) -> void:
	var effect_data: Dictionary = SaveDataUtils.sanitize_dictionary(raw_effect)
	var effect_id: String = String(effect_data.get("id", "")).strip_edges().to_lower()

	if effect_id.is_empty():
		return

	match effect_id:
		"indigestion":
			_apply_simple_item_condition(
				ITEM_CONDITION_INDIGESTION,
				"Несварение",
				"Желудок недоволен",
				"Пища легла тяжело. Состояние пройдёт само, если дать организму немного времени.",
				_resolve_effect_duration(effect_data, indigestion_duration_minutes)
			)
		"relaxation":
			_apply_simple_item_condition(
				ITEM_CONDITION_RELAXATION,
				"Расслабление",
				"Становится спокойнее",
				"Напиток помогает ненадолго выдохнуть и чуть легче пережить день.",
				_resolve_effect_duration(effect_data, relaxation_duration_minutes)
			)
		"stomach_pain":
			_apply_simple_item_condition(
				ITEM_CONDITION_STOMACH_PAIN,
				"Боль в животе",
				"Живот крутит",
				"Слишком тяжёлая еда отзывается неприятной болью в животе.",
				_resolve_effect_duration(effect_data, stomach_pain_duration_minutes)
			)
		"vigor":
			_apply_simple_item_condition(
				ITEM_CONDITION_VIGOR,
				"Бодрость",
				"Сил чуть больше обычного",
				"Стимулятор ненадолго разгоняет усталость и даёт краткий прилив бодрости.",
				_resolve_effect_duration(effect_data, vigor_duration_minutes)
			)
		"drunk":
			var level: int = max(1, int(effect_data.get("level", 1)))
			var default_duration: int = beer_drunk_duration_minutes if level <= 1 else wine_drunk_duration_minutes
			_apply_simple_item_condition(
				ITEM_CONDITION_DRUNK,
				"Опьянение",
				"Пьяный x%d" % level,
				"Алкоголь уже ударил в голову. Состояние спадёт со временем.",
				_resolve_effect_duration(effect_data, default_duration),
				{
					"level": level,
				}
			)
		"under_influence":
			_apply_simple_item_condition(
				ITEM_CONDITION_UNDER_INFLUENCE,
				"Под веществами",
				"Сознание плывёт",
				"Состояние нестабильное: мысли и ощущения слегка уносят в сторону.",
				_resolve_effect_duration(effect_data, selfmade_duration_minutes)
			)
		"fracture_resistance":
			_apply_simple_item_condition(
				ITEM_CONDITION_FRACTURE_RESISTANCE,
				"Устойчивость к перелому",
				"Кости под защитой",
				"Организм ненадолго получает запас прочности на случай будущих травм.",
				_resolve_effect_duration(effect_data, fracture_resistance_duration_minutes),
				{
					"modifier_key": "fracture_risk_multiplier",
					"multiplier": future_fracture_risk_multiplier,
				}
			)
		"soap_bath_bonus":
			_apply_simple_item_condition(
				ITEM_CONDITION_SOAP_READY,
				"Мыло подготовлено",
				"Следующее мытьё будет эффективнее",
				"Если помыться в течение ближайшего часа, ванна даст дополнительную гигиену.",
				_resolve_effect_duration(effect_data, soap_bonus_window_minutes),
				{
					"bonus_hygiene": int(effect_data.get("bonus_hygiene", soap_bonus_hygiene_amount)),
				}
			)
		"nicotine_addiction":
			_add_nicotine_addiction(float(effect_data.get("amount", 0.0)))
		"noodles_overuse":
			var current_absolute_minutes: int = _get_current_absolute_minutes()
			_prune_noodle_history(current_absolute_minutes)
			_noodle_use_absolute_minutes.append(current_absolute_minutes)

			if _noodle_use_absolute_minutes.size() >= noodle_overuse_threshold:
				_apply_simple_item_condition(
					ITEM_CONDITION_INDIGESTION,
					"Несварение",
					"Желудок недоволен",
					"Слишком много лапши за короткое время перегрузило желудок.",
					indigestion_duration_minutes
				)
		"disease_risk_multiplier":
			_apply_simple_item_condition(
				ITEM_CONDITION_DISEASE_PROTECTION,
				"Поддержка организма",
				"Риск болезни снижен",
				"Организм ненадолго получает защиту от будущих болезней.",
				_resolve_effect_duration(effect_data, medicine_effect_duration_minutes),
				{
					"hidden_in_ui": true,
					"modifier_key": "disease_risk_multiplier",
					"multiplier": float(effect_data.get("multiplier", future_disease_risk_multiplier)),
				}
			)
		"pregnancy_risk_multiplier":
			_apply_simple_item_condition(
				ITEM_CONDITION_PREGNANCY_PROTECTION,
				"Защита",
				"Риск беременности снижен",
				"Эффект сохранён как будущий hook для системы беременности.",
				_resolve_effect_duration(effect_data, contraceptive_fallback_duration_minutes),
				{
					"hidden_in_ui": true,
					"modifier_key": "pregnancy_risk_multiplier",
					"multiplier": float(effect_data.get("multiplier", future_pregnancy_risk_multiplier)),
				}
			)
		"leak_risk_multiplier":
			_apply_simple_item_condition(
				ITEM_CONDITION_PAD_PROTECTION,
				"Защита",
				"Риск протечки снижен",
				"Эффект сохранён как будущий hook для системы месячных.",
				_resolve_effect_duration(effect_data, pads_fallback_duration_minutes),
				{
					"hidden_in_ui": true,
					"modifier_key": "menstruation_leak_risk_multiplier",
					"multiplier": float(
						effect_data.get("multiplier", future_menstruation_leak_risk_multiplier)
					),
				}
			)
		"remove_bleeding":
			clear_bleeding()
		_:
			push_warning(
				"PlayerStats: unknown item effect '%s' on item '%s'." % [
					effect_id,
					item_data.id,
				]
			)


func _refresh_item_runtime_state() -> void:
	_prune_expired_item_conditions()
	_prune_noodle_history(_get_current_absolute_minutes())


func refresh_hunger_runtime_state(
	emit_notifications := true,
	force_condition_sync := false
) -> Dictionary:
	var previous_stage_id: StringName = _current_hunger_stage_id
	_current_hunger_stage_id = _resolve_hunger_stage_id(hunger)

	if hunger <= 0:
		_awake_hunger_decay_accumulator = 0.0

	if _current_hunger_stage_id != HUNGER_STAGE_STARVING or hp <= 0:
		_starvation_damage_accumulator = 0.0

	if force_condition_sync or previous_stage_id != _current_hunger_stage_id:
		_sync_hunger_stage_conditions(_current_hunger_stage_id)

	if emit_notifications:
		_emit_hunger_warning_if_needed(previous_stage_id, _current_hunger_stage_id)

	return get_hunger_state()


func refresh_hygiene_runtime_state(
	emit_notifications := true,
	force_condition_sync := false
) -> Dictionary:
	var previous_stage_id: StringName = _current_hygiene_stage_id
	_current_hygiene_stage_id = _resolve_hygiene_stage_id(hygiene)
	_sync_hygiene_body_state()

	if force_condition_sync or previous_stage_id != _current_hygiene_stage_id:
		_sync_hygiene_stage_conditions(_current_hygiene_stage_id)

	if emit_notifications:
		_emit_hygiene_warning_if_needed(previous_stage_id, _current_hygiene_stage_id)

	_emit_hygiene_state_if_needed()
	return get_hygiene_state()


func get_sleep_state() -> Dictionary:
	var current_absolute_minutes: int = GameTime.get_absolute_minutes()
	var resolved_last_sleep_finished_absolute_minutes: int = _get_resolved_last_sleep_finished_absolute_minutes(
		current_absolute_minutes
	)
	var minutes_without_sleep: int = max(
		0,
		current_absolute_minutes - resolved_last_sleep_finished_absolute_minutes
	)

	return {
		"last_sleep_finished_absolute_minutes": resolved_last_sleep_finished_absolute_minutes,
		"minutes_without_sleep": minutes_without_sleep,
		"hours_without_sleep": float(minutes_without_sleep) / 60.0,
		"sleep_stage_id": String(_current_sleep_stage_id),
		"pending_forced_blackout": _pending_forced_blackout,
		"forced_blackout_in_progress": _forced_blackout_in_progress,
	}


func get_sleep_effect_config() -> Dictionary:
	var sleep_recovery_multiplier := 1.0

	if PlayerMentalState != null and PlayerMentalState.has_method("get_effects"):
		sleep_recovery_multiplier = float(
			PlayerMentalState.get_effects().get("sleep_recovery_multiplier", 1.0)
		)

	return {
		"energy_per_hour": sleep_energy_per_hour * get_energy_recovery_multiplier() * sleep_recovery_multiplier,
		"hp_per_hour": int(round(float(sleep_hp_per_hour) * sleep_recovery_multiplier)),
		"hunger_per_hour": sleep_hunger_per_hour,
		"min_energy_restore_multiplier_at_zero_hp": sleep_min_energy_restore_multiplier_at_zero_hp,
		"hunger_stage_id": String(_current_hunger_stage_id),
		"blocks_passive_hp_regen": is_passive_hp_regen_blocked(),
		"sleep_recovery_multiplier": sleep_recovery_multiplier,
	}


func has_pending_forced_blackout() -> bool:
	return _pending_forced_blackout and not _forced_blackout_in_progress


func begin_forced_blackout() -> bool:
	if not _pending_forced_blackout or _forced_blackout_in_progress:
		return false

	_forced_blackout_in_progress = true
	_emit_sleep_state_if_needed()
	return true


func finish_forced_blackout() -> void:
	if not _forced_blackout_in_progress:
		return

	_forced_blackout_in_progress = false
	_emit_sleep_state_if_needed()


func register_sleep(sleep_duration_minutes: int, sleep_started_absolute_minutes: int = -1) -> Dictionary:
	var safe_sleep_duration_minutes: int = max(0, sleep_duration_minutes)
	var resolved_sleep_started_absolute_minutes: int = sleep_started_absolute_minutes

	if resolved_sleep_started_absolute_minutes < 0:
		resolved_sleep_started_absolute_minutes = GameTime.get_absolute_minutes()

	_pending_sleep_time_advance_minutes += safe_sleep_duration_minutes

	var resolved_last_sleep_finished_absolute_minutes: int = _get_resolved_last_sleep_finished_absolute_minutes(
		resolved_sleep_started_absolute_minutes
	)
	var wake_absolute_minutes: int = (
		resolved_sleep_started_absolute_minutes + safe_sleep_duration_minutes
	)
	var minutes_without_sleep_before_rest: int = max(
		0,
		resolved_sleep_started_absolute_minutes - resolved_last_sleep_finished_absolute_minutes
	)

	if safe_sleep_duration_minutes >= full_reset_sleep_minutes:
		_last_sleep_finished_absolute_minutes = wake_absolute_minutes
	else:
		var recovered_sleep_minutes: int = max(
			0,
			int(round(float(safe_sleep_duration_minutes) * short_sleep_recovery_ratio))
		)
		var minutes_without_sleep_after_rest: int = max(
			0,
			minutes_without_sleep_before_rest - recovered_sleep_minutes
		)
		_last_sleep_finished_absolute_minutes = wake_absolute_minutes - minutes_without_sleep_after_rest

	_pending_forced_blackout = false
	return refresh_sleep_runtime_state(false)


func refresh_sleep_runtime_state(emit_notifications := true, force_condition_sync := false) -> Dictionary:
	var current_absolute_minutes: int = GameTime.get_absolute_minutes()
	var resolved_last_sleep_finished_absolute_minutes: int = _get_resolved_last_sleep_finished_absolute_minutes(
		current_absolute_minutes
	)
	var minutes_without_sleep: int = max(
		0,
		current_absolute_minutes - resolved_last_sleep_finished_absolute_minutes
	)
	var previous_stage_id: StringName = _current_sleep_stage_id
	var previous_pending_forced_blackout: bool = _pending_forced_blackout
	var next_stage_id: StringName = _resolve_sleep_stage_id(minutes_without_sleep)
	var should_request_blackout: bool = (
		minutes_without_sleep >= sleep_blackout_threshold_minutes
		and not _pending_forced_blackout
		and not _forced_blackout_in_progress
	)

	_current_sleep_stage_id = next_stage_id

	if should_request_blackout:
		_pending_forced_blackout = true

	if force_condition_sync or previous_stage_id != _current_sleep_stage_id:
		_sync_sleep_stage_conditions(_current_sleep_stage_id, minutes_without_sleep)

	if emit_notifications:
		_emit_sleep_warning_if_needed(
			previous_stage_id,
			_current_sleep_stage_id,
			should_request_blackout
		)

	if should_request_blackout and not previous_pending_forced_blackout:
		sleep_warning_requested.emit(
			"Руна больше не может бодрствовать.",
			DEFAULT_BLACKOUT_WARNING_DURATION
		)
		forced_blackout_requested.emit()

	_emit_sleep_state_if_needed()
	return get_sleep_state()


func build_save_data() -> Dictionary:
	return {
		"hp": hp,
		"hunger": hunger,
		"energy": energy,
		"hygiene": hygiene,
		"nicotine_addiction": nicotine_addiction,
		"noodle_use_absolute_minutes": _noodle_use_absolute_minutes.duplicate(),
		"last_time_tick_absolute_minutes": _last_time_tick_absolute_minutes,
		"awake_hunger_decay_accumulator": _awake_hunger_decay_accumulator,
		"awake_hygiene_decay_accumulator": _awake_hygiene_decay_accumulator,
		"sleep_hygiene_decay_accumulator": _sleep_hygiene_decay_accumulator,
		"movement_hygiene_decay_accumulator": _movement_hygiene_decay_accumulator,
		"pending_sleep_time_advance_minutes": _pending_sleep_time_advance_minutes,
		"starvation_damage_accumulator": _starvation_damage_accumulator,
		"last_sleep_finished_absolute_minutes": _last_sleep_finished_absolute_minutes,
		"sleep_stage_id": String(_current_sleep_stage_id),
		"hygiene_stage_id": String(_current_hygiene_stage_id),
		"last_hygiene_warning_absolute_minutes": _last_hygiene_warning_absolute_minutes,
		"hygiene_npc_comment_state": _hygiene_npc_comment_state.duplicate(true),
		"pending_forced_blackout": _pending_forced_blackout,
		"forced_blackout_in_progress": _forced_blackout_in_progress,
	}


func apply_save_data(data: Dictionary) -> void:
	_is_dead = false
	_death_payload.clear()
	hp = clampi(int(data.get("hp", _default_state.get("hp", hp))), 0, max_hp)
	hunger = clampi(int(data.get("hunger", _default_state.get("hunger", hunger))), 0, max_hunger)
	energy = clampf(float(data.get("energy", _default_state.get("energy", energy))), 0.0, max_energy)
	hygiene = clampi(int(data.get("hygiene", _default_state.get("hygiene", hygiene))), 0, max_hygiene)
	nicotine_addiction = clampf(
		float(data.get("nicotine_addiction", _default_state.get("nicotine_addiction", 0.0))),
		0.0,
		100.0
	)
	_noodle_use_absolute_minutes.clear()

	for entry_variant in SaveDataUtils.sanitize_array(data.get("noodle_use_absolute_minutes", [])):
		_noodle_use_absolute_minutes.append(int(entry_variant))

	_last_time_tick_absolute_minutes = int(
		data.get("last_time_tick_absolute_minutes", GameTime.get_absolute_minutes())
	)
	_awake_hunger_decay_accumulator = max(
		0.0,
		float(data.get("awake_hunger_decay_accumulator", 0.0))
	)
	_awake_hygiene_decay_accumulator = max(
		0.0,
		float(data.get("awake_hygiene_decay_accumulator", 0.0))
	)
	_sleep_hygiene_decay_accumulator = max(
		0.0,
		float(data.get("sleep_hygiene_decay_accumulator", 0.0))
	)
	_movement_hygiene_decay_accumulator = max(
		0.0,
		float(data.get("movement_hygiene_decay_accumulator", 0.0))
	)
	_pending_sleep_time_advance_minutes = max(
		0,
		int(data.get("pending_sleep_time_advance_minutes", 0))
	)
	_starvation_damage_accumulator = max(
		0.0,
		float(data.get("starvation_damage_accumulator", 0.0))
	)
	_last_sleep_finished_absolute_minutes = int(
		data.get("last_sleep_finished_absolute_minutes", GameTime.get_absolute_minutes())
	)
	_current_sleep_stage_id = _normalize_sleep_stage_id(String(data.get("sleep_stage_id", "")))
	_current_hunger_stage_id = _resolve_hunger_stage_id(hunger)
	_current_hygiene_stage_id = _normalize_hygiene_stage_id(String(data.get("hygiene_stage_id", "")))
	_last_hygiene_warning_absolute_minutes = int(
		data.get("last_hygiene_warning_absolute_minutes", -1)
	)
	_hygiene_npc_comment_state.clear()

	var raw_hygiene_comment_state: Variant = data.get("hygiene_npc_comment_state", {})

	if raw_hygiene_comment_state is Dictionary:
		for npc_key in (raw_hygiene_comment_state as Dictionary).keys():
			var comment_entry: Variant = (raw_hygiene_comment_state as Dictionary).get(npc_key, {})

			if comment_entry is Dictionary:
				_hygiene_npc_comment_state[String(npc_key).to_lower()] = (
					comment_entry as Dictionary
				).duplicate(true)

	_pending_forced_blackout = bool(data.get("pending_forced_blackout", false))
	_forced_blackout_in_progress = bool(data.get("forced_blackout_in_progress", false))

	if _forced_blackout_in_progress:
		_pending_forced_blackout = true
		_forced_blackout_in_progress = false

	refresh_hunger_runtime_state(false, true)
	refresh_hygiene_runtime_state(false, true)
	_is_energy_critical = energy <= critical_energy_threshold
	call_deferred("_refresh_item_runtime_state")
	stats_changed.emit(get_stats())
	critical_energy_state_changed.emit(_is_energy_critical)
	refresh_sleep_runtime_state(false)


func reset_state() -> void:
	_is_dead = false
	_death_payload.clear()
	if _default_state.is_empty():
		_capture_default_state()

	max_hp = int(_default_state.get("max_hp", max_hp))
	max_hunger = int(_default_state.get("max_hunger", max_hunger))
	max_energy = float(_default_state.get("max_energy", max_energy))
	max_hygiene = int(_default_state.get("max_hygiene", max_hygiene))
	critical_energy_threshold = float(_default_state.get("critical_energy_threshold", critical_energy_threshold))
	hunger_hungry_threshold = int(_default_state.get("hunger_hungry_threshold", hunger_hungry_threshold))
	hunger_severe_threshold = int(_default_state.get("hunger_severe_threshold", hunger_severe_threshold))
	hunger_exhaustion_threshold = int(
		_default_state.get("hunger_exhaustion_threshold", hunger_exhaustion_threshold)
	)
	hunger_starvation_threshold = int(
		_default_state.get("hunger_starvation_threshold", hunger_starvation_threshold)
	)
	hygiene_clean_threshold = int(_default_state.get("hygiene_clean_threshold", hygiene_clean_threshold))
	hygiene_untidy_threshold = int(_default_state.get("hygiene_untidy_threshold", hygiene_untidy_threshold))
	hygiene_dirty_threshold = int(_default_state.get("hygiene_dirty_threshold", hygiene_dirty_threshold))
	severe_hunger_energy_recovery_multiplier = float(
		_default_state.get(
			"severe_hunger_energy_recovery_multiplier",
			severe_hunger_energy_recovery_multiplier
		)
	)
	severe_hunger_movement_speed_multiplier = float(
		_default_state.get(
			"severe_hunger_movement_speed_multiplier",
			severe_hunger_movement_speed_multiplier
		)
	)
	exhaustion_energy_recovery_multiplier = float(
		_default_state.get(
			"exhaustion_energy_recovery_multiplier",
			exhaustion_energy_recovery_multiplier
		)
	)
	exhaustion_movement_speed_multiplier = float(
		_default_state.get(
			"exhaustion_movement_speed_multiplier",
			exhaustion_movement_speed_multiplier
		)
	)
	exhaustion_blocks_passive_hp_regen = bool(
		_default_state.get(
			"exhaustion_blocks_passive_hp_regen",
			exhaustion_blocks_passive_hp_regen
		)
	)
	starvation_damage_interval_seconds = float(
		_default_state.get(
			"starvation_damage_interval_seconds",
			starvation_damage_interval_seconds
		)
	)
	starvation_damage_per_tick = int(
		_default_state.get("starvation_damage_per_tick", starvation_damage_per_tick)
	)
	awake_hunger_decay_per_hour = float(
		_default_state.get("awake_hunger_decay_per_hour", awake_hunger_decay_per_hour)
	)
	awake_hygiene_decay_per_hour = float(
		_default_state.get("awake_hygiene_decay_per_hour", awake_hygiene_decay_per_hour)
	)
	sleep_hygiene_decay_per_hour = float(
		_default_state.get("sleep_hygiene_decay_per_hour", sleep_hygiene_decay_per_hour)
	)
	movement_hygiene_decay_per_step = float(
		_default_state.get("movement_hygiene_decay_per_step", movement_hygiene_decay_per_step)
	)
	sleep_tired_threshold_minutes = int(_default_state.get("sleep_tired_threshold_minutes", sleep_tired_threshold_minutes))
	sleep_very_tired_threshold_minutes = int(
		_default_state.get("sleep_very_tired_threshold_minutes", sleep_very_tired_threshold_minutes)
	)
	sleep_critical_threshold_minutes = int(
		_default_state.get("sleep_critical_threshold_minutes", sleep_critical_threshold_minutes)
	)
	sleep_blackout_threshold_minutes = int(
		_default_state.get("sleep_blackout_threshold_minutes", sleep_blackout_threshold_minutes)
	)
	forced_blackout_sleep_minutes = int(
		_default_state.get("forced_blackout_sleep_minutes", forced_blackout_sleep_minutes)
	)
	full_reset_sleep_minutes = int(_default_state.get("full_reset_sleep_minutes", full_reset_sleep_minutes))
	short_sleep_recovery_ratio = float(
		_default_state.get("short_sleep_recovery_ratio", short_sleep_recovery_ratio)
	)
	sleep_energy_per_hour = float(_default_state.get("sleep_energy_per_hour", sleep_energy_per_hour))
	sleep_hp_per_hour = int(_default_state.get("sleep_hp_per_hour", sleep_hp_per_hour))
	sleep_hunger_per_hour = int(_default_state.get("sleep_hunger_per_hour", sleep_hunger_per_hour))
	sleep_min_energy_restore_multiplier_at_zero_hp = float(
		_default_state.get(
			"sleep_min_energy_restore_multiplier_at_zero_hp",
			sleep_min_energy_restore_multiplier_at_zero_hp
		)
	)
	bath_hygiene_restore_amount = int(
		_default_state.get("bath_hygiene_restore_amount", bath_hygiene_restore_amount)
	)
	dirty_hygiene_movement_speed_multiplier = float(
		_default_state.get(
			"dirty_hygiene_movement_speed_multiplier",
			dirty_hygiene_movement_speed_multiplier
		)
	)
	unsanitary_hygiene_movement_speed_multiplier = float(
		_default_state.get(
			"unsanitary_hygiene_movement_speed_multiplier",
			unsanitary_hygiene_movement_speed_multiplier
		)
	)
	dirty_hygiene_mood_pressure = float(
		_default_state.get("dirty_hygiene_mood_pressure", dirty_hygiene_mood_pressure)
	)
	unsanitary_hygiene_mood_pressure = float(
		_default_state.get("unsanitary_hygiene_mood_pressure", unsanitary_hygiene_mood_pressure)
	)
	dirty_hygiene_social_penalty_weight = float(
		_default_state.get(
			"dirty_hygiene_social_penalty_weight",
			dirty_hygiene_social_penalty_weight
		)
	)
	unsanitary_hygiene_social_penalty_weight = float(
		_default_state.get(
			"unsanitary_hygiene_social_penalty_weight",
			unsanitary_hygiene_social_penalty_weight
		)
	)
	dirty_hygiene_illness_risk = float(
		_default_state.get("dirty_hygiene_illness_risk", dirty_hygiene_illness_risk)
	)
	unsanitary_hygiene_illness_risk = float(
		_default_state.get("unsanitary_hygiene_illness_risk", unsanitary_hygiene_illness_risk)
	)
	clean_dirt_visual_alpha = float(
		_default_state.get("clean_dirt_visual_alpha", clean_dirt_visual_alpha)
	)
	untidy_dirt_visual_alpha = float(
		_default_state.get("untidy_dirt_visual_alpha", untidy_dirt_visual_alpha)
	)
	dirty_dirt_visual_alpha = float(
		_default_state.get("dirty_dirt_visual_alpha", dirty_dirt_visual_alpha)
	)
	unsanitary_dirt_visual_alpha = float(
		_default_state.get("unsanitary_dirt_visual_alpha", unsanitary_dirt_visual_alpha)
	)
	future_hygiene_enables_illness_hooks = bool(
		_default_state.get(
			"future_hygiene_enables_illness_hooks",
			future_hygiene_enables_illness_hooks
		)
	)
	future_hygiene_enables_smell_hooks = bool(
		_default_state.get("future_hygiene_enables_smell_hooks", future_hygiene_enables_smell_hooks)
	)
	future_hygiene_enables_npc_reaction_hooks = bool(
		_default_state.get(
			"future_hygiene_enables_npc_reaction_hooks",
			future_hygiene_enables_npc_reaction_hooks
		)
	)
	future_sex_scene_hygiene_loss = int(
		_default_state.get("future_sex_scene_hygiene_loss", future_sex_scene_hygiene_loss)
	)
	future_fight_hygiene_loss = int(
		_default_state.get("future_fight_hygiene_loss", future_fight_hygiene_loss)
	)
	future_menstruation_hygiene_loss = int(
		_default_state.get("future_menstruation_hygiene_loss", future_menstruation_hygiene_loss)
	)
	future_body_fluids_hygiene_loss = int(
		_default_state.get("future_body_fluids_hygiene_loss", future_body_fluids_hygiene_loss)
	)
	future_dirty_work_hygiene_loss = int(
		_default_state.get("future_dirty_work_hygiene_loss", future_dirty_work_hygiene_loss)
	)
	future_blood_hygiene_loss = int(
		_default_state.get("future_blood_hygiene_loss", future_blood_hygiene_loss)
	)
	future_event_grime_hygiene_loss = int(
		_default_state.get("future_event_grime_hygiene_loss", future_event_grime_hygiene_loss)
	)
	future_humiliation_scene_hygiene_loss = int(
		_default_state.get(
			"future_humiliation_scene_hygiene_loss",
			future_humiliation_scene_hygiene_loss
		)
	)
	future_snack_hunger_restore = int(
		_default_state.get("future_snack_hunger_restore", future_snack_hunger_restore)
	)
	future_cheap_food_hunger_restore = int(
		_default_state.get("future_cheap_food_hunger_restore", future_cheap_food_hunger_restore)
	)
	future_hot_meal_hunger_restore = int(
		_default_state.get("future_hot_meal_hunger_restore", future_hot_meal_hunger_restore)
	)
	future_soda_hunger_restore = int(
		_default_state.get("future_soda_hunger_restore", future_soda_hunger_restore)
	)
	future_alcohol_hunger_restore = int(
		_default_state.get("future_alcohol_hunger_restore", future_alcohol_hunger_restore)
	)
	indigestion_duration_minutes = int(
		_default_state.get("indigestion_duration_minutes", indigestion_duration_minutes)
	)
	relaxation_duration_minutes = int(
		_default_state.get("relaxation_duration_minutes", relaxation_duration_minutes)
	)
	stomach_pain_duration_minutes = int(
		_default_state.get("stomach_pain_duration_minutes", stomach_pain_duration_minutes)
	)
	vigor_duration_minutes = int(
		_default_state.get("vigor_duration_minutes", vigor_duration_minutes)
	)
	beer_drunk_duration_minutes = int(
		_default_state.get("beer_drunk_duration_minutes", beer_drunk_duration_minutes)
	)
	wine_drunk_duration_minutes = int(
		_default_state.get("wine_drunk_duration_minutes", wine_drunk_duration_minutes)
	)
	selfmade_duration_minutes = int(
		_default_state.get("selfmade_duration_minutes", selfmade_duration_minutes)
	)
	fracture_resistance_duration_minutes = int(
		_default_state.get(
			"fracture_resistance_duration_minutes",
			fracture_resistance_duration_minutes
		)
	)
	medicine_effect_duration_minutes = int(
		_default_state.get(
			"medicine_effect_duration_minutes",
			medicine_effect_duration_minutes
		)
	)
	contraceptive_fallback_duration_minutes = int(
		_default_state.get(
			"contraceptive_fallback_duration_minutes",
			contraceptive_fallback_duration_minutes
		)
	)
	pads_fallback_duration_minutes = int(
		_default_state.get(
			"pads_fallback_duration_minutes",
			pads_fallback_duration_minutes
		)
	)
	noodle_overuse_window_minutes = int(
		_default_state.get("noodle_overuse_window_minutes", noodle_overuse_window_minutes)
	)
	noodle_overuse_threshold = int(
		_default_state.get("noodle_overuse_threshold", noodle_overuse_threshold)
	)
	soap_bonus_hygiene_amount = int(
		_default_state.get("soap_bonus_hygiene_amount", soap_bonus_hygiene_amount)
	)
	soap_bonus_window_minutes = int(
		_default_state.get("soap_bonus_window_minutes", soap_bonus_window_minutes)
	)
	cigarette_nicotine_addiction_gain = int(
		_default_state.get(
			"cigarette_nicotine_addiction_gain",
			cigarette_nicotine_addiction_gain
		)
	)
	vape_nicotine_addiction_gain = int(
		_default_state.get("vape_nicotine_addiction_gain", vape_nicotine_addiction_gain)
	)
	nicotine_addiction = float(
		_default_state.get("nicotine_addiction", nicotine_addiction)
	)
	future_disease_risk_multiplier = float(
		_default_state.get("future_disease_risk_multiplier", future_disease_risk_multiplier)
	)
	future_pregnancy_risk_multiplier = float(
		_default_state.get(
			"future_pregnancy_risk_multiplier",
			future_pregnancy_risk_multiplier
		)
	)
	future_menstruation_leak_risk_multiplier = float(
		_default_state.get(
			"future_menstruation_leak_risk_multiplier",
			future_menstruation_leak_risk_multiplier
		)
	)
	future_fracture_risk_multiplier = float(
		_default_state.get(
			"future_fracture_risk_multiplier",
			future_fracture_risk_multiplier
		)
	)
	hp = int(_default_state.get("hp", hp))
	hunger = int(_default_state.get("hunger", hunger))
	energy = float(_default_state.get("energy", energy))
	hygiene = int(_default_state.get("hygiene", hygiene))
	_last_time_tick_absolute_minutes = -1
	_awake_hunger_decay_accumulator = 0.0
	_awake_hygiene_decay_accumulator = 0.0
	_sleep_hygiene_decay_accumulator = 0.0
	_movement_hygiene_decay_accumulator = 0.0
	_pending_sleep_time_advance_minutes = 0
	_starvation_damage_accumulator = 0.0
	_last_sleep_finished_absolute_minutes = GameTime.get_absolute_minutes()
	_pending_forced_blackout = false
	_forced_blackout_in_progress = false
	_current_sleep_stage_id = SLEEP_STAGE_NONE
	_current_hunger_stage_id = _resolve_hunger_stage_id(hunger)
	_current_hygiene_stage_id = _resolve_hygiene_stage_id(hygiene)
	_last_sleep_state_signature.clear()
	_last_hygiene_state_signature.clear()
	_last_hygiene_warning_absolute_minutes = -1
	_hygiene_npc_comment_state.clear()
	_noodle_use_absolute_minutes.clear()
	_remove_all_item_conditions()
	refresh_hunger_runtime_state(false, true)
	refresh_hygiene_runtime_state(false, true)
	_is_energy_critical = energy <= critical_energy_threshold
	stats_changed.emit(get_stats())
	critical_energy_state_changed.emit(_is_energy_critical)
	refresh_sleep_runtime_state(false)


func _connect_game_time() -> void:
	var game_time: GameTimeState = get_node_or_null("/root/GameTime") as GameTimeState

	if game_time == null:
		return

	if not game_time.time_changed.is_connected(_on_game_time_changed):
		game_time.time_changed.connect(_on_game_time_changed)

	_last_time_tick_absolute_minutes = game_time.get_absolute_minutes()
	_refresh_item_runtime_state()
	refresh_hunger_runtime_state(false, true)
	refresh_hygiene_runtime_state(false, true)
	refresh_sleep_runtime_state(false)


func _on_game_time_changed(absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	if _last_time_tick_absolute_minutes < 0:
		_last_time_tick_absolute_minutes = absolute_minutes
		_refresh_item_runtime_state()
		refresh_hunger_runtime_state(false)
		refresh_hygiene_runtime_state(false)
		refresh_sleep_runtime_state(false)
		return

	var elapsed_minutes: int = absolute_minutes - _last_time_tick_absolute_minutes
	_last_time_tick_absolute_minutes = absolute_minutes
	_refresh_item_runtime_state()

	if elapsed_minutes <= 0:
		refresh_hunger_runtime_state(false)
		refresh_hygiene_runtime_state(false)
		refresh_sleep_runtime_state(false)
		return

	var sleep_minutes: int = min(_pending_sleep_time_advance_minutes, elapsed_minutes)
	var awake_minutes: int = max(0, elapsed_minutes - sleep_minutes)
	_pending_sleep_time_advance_minutes = max(0, _pending_sleep_time_advance_minutes - sleep_minutes)

	if awake_minutes > 0:
		_apply_awake_hunger_decay(awake_minutes)
		_apply_awake_hygiene_decay(awake_minutes)

	if sleep_minutes > 0:
		_apply_sleep_hygiene_decay(sleep_minutes)

	refresh_hygiene_runtime_state(true)
	refresh_sleep_runtime_state(true)


func _refresh_critical_energy_state() -> void:
	var next_is_critical: bool = energy <= critical_energy_threshold

	if next_is_critical == _is_energy_critical:
		return

	_is_energy_critical = next_is_critical
	critical_energy_state_changed.emit(_is_energy_critical)


func _capture_default_state() -> void:
	if not _default_state.is_empty():
		return

	_default_state = {
		"max_hp": max_hp,
		"max_hunger": max_hunger,
		"max_energy": max_energy,
		"max_hygiene": max_hygiene,
		"critical_energy_threshold": critical_energy_threshold,
		"hunger_hungry_threshold": hunger_hungry_threshold,
		"hunger_severe_threshold": hunger_severe_threshold,
		"hunger_exhaustion_threshold": hunger_exhaustion_threshold,
		"hunger_starvation_threshold": hunger_starvation_threshold,
		"hygiene_clean_threshold": hygiene_clean_threshold,
		"hygiene_untidy_threshold": hygiene_untidy_threshold,
		"hygiene_dirty_threshold": hygiene_dirty_threshold,
		"severe_hunger_energy_recovery_multiplier": severe_hunger_energy_recovery_multiplier,
		"severe_hunger_movement_speed_multiplier": severe_hunger_movement_speed_multiplier,
		"exhaustion_energy_recovery_multiplier": exhaustion_energy_recovery_multiplier,
		"exhaustion_movement_speed_multiplier": exhaustion_movement_speed_multiplier,
		"exhaustion_blocks_passive_hp_regen": exhaustion_blocks_passive_hp_regen,
		"starvation_damage_interval_seconds": starvation_damage_interval_seconds,
		"starvation_damage_per_tick": starvation_damage_per_tick,
		"awake_hunger_decay_per_hour": awake_hunger_decay_per_hour,
		"awake_hygiene_decay_per_hour": awake_hygiene_decay_per_hour,
		"sleep_hygiene_decay_per_hour": sleep_hygiene_decay_per_hour,
		"movement_hygiene_decay_per_step": movement_hygiene_decay_per_step,
		"sleep_tired_threshold_minutes": sleep_tired_threshold_minutes,
		"sleep_very_tired_threshold_minutes": sleep_very_tired_threshold_minutes,
		"sleep_critical_threshold_minutes": sleep_critical_threshold_minutes,
		"sleep_blackout_threshold_minutes": sleep_blackout_threshold_minutes,
		"forced_blackout_sleep_minutes": forced_blackout_sleep_minutes,
		"full_reset_sleep_minutes": full_reset_sleep_minutes,
		"short_sleep_recovery_ratio": short_sleep_recovery_ratio,
		"sleep_energy_per_hour": sleep_energy_per_hour,
		"sleep_hp_per_hour": sleep_hp_per_hour,
		"sleep_hunger_per_hour": sleep_hunger_per_hour,
		"sleep_min_energy_restore_multiplier_at_zero_hp": sleep_min_energy_restore_multiplier_at_zero_hp,
		"bath_hygiene_restore_amount": bath_hygiene_restore_amount,
		"dirty_hygiene_movement_speed_multiplier": dirty_hygiene_movement_speed_multiplier,
		"unsanitary_hygiene_movement_speed_multiplier": unsanitary_hygiene_movement_speed_multiplier,
		"dirty_hygiene_mood_pressure": dirty_hygiene_mood_pressure,
		"unsanitary_hygiene_mood_pressure": unsanitary_hygiene_mood_pressure,
		"dirty_hygiene_social_penalty_weight": dirty_hygiene_social_penalty_weight,
		"unsanitary_hygiene_social_penalty_weight": unsanitary_hygiene_social_penalty_weight,
		"dirty_hygiene_illness_risk": dirty_hygiene_illness_risk,
		"unsanitary_hygiene_illness_risk": unsanitary_hygiene_illness_risk,
		"clean_dirt_visual_alpha": clean_dirt_visual_alpha,
		"untidy_dirt_visual_alpha": untidy_dirt_visual_alpha,
		"dirty_dirt_visual_alpha": dirty_dirt_visual_alpha,
		"unsanitary_dirt_visual_alpha": unsanitary_dirt_visual_alpha,
		"future_hygiene_enables_illness_hooks": future_hygiene_enables_illness_hooks,
		"future_hygiene_enables_smell_hooks": future_hygiene_enables_smell_hooks,
		"future_hygiene_enables_npc_reaction_hooks": future_hygiene_enables_npc_reaction_hooks,
		"future_sex_scene_hygiene_loss": future_sex_scene_hygiene_loss,
		"future_fight_hygiene_loss": future_fight_hygiene_loss,
		"future_menstruation_hygiene_loss": future_menstruation_hygiene_loss,
		"future_body_fluids_hygiene_loss": future_body_fluids_hygiene_loss,
		"future_dirty_work_hygiene_loss": future_dirty_work_hygiene_loss,
		"future_blood_hygiene_loss": future_blood_hygiene_loss,
		"future_event_grime_hygiene_loss": future_event_grime_hygiene_loss,
		"future_humiliation_scene_hygiene_loss": future_humiliation_scene_hygiene_loss,
		"future_snack_hunger_restore": future_snack_hunger_restore,
		"future_cheap_food_hunger_restore": future_cheap_food_hunger_restore,
		"future_hot_meal_hunger_restore": future_hot_meal_hunger_restore,
		"future_soda_hunger_restore": future_soda_hunger_restore,
		"future_alcohol_hunger_restore": future_alcohol_hunger_restore,
		"indigestion_duration_minutes": indigestion_duration_minutes,
		"relaxation_duration_minutes": relaxation_duration_minutes,
		"stomach_pain_duration_minutes": stomach_pain_duration_minutes,
		"vigor_duration_minutes": vigor_duration_minutes,
		"beer_drunk_duration_minutes": beer_drunk_duration_minutes,
		"wine_drunk_duration_minutes": wine_drunk_duration_minutes,
		"selfmade_duration_minutes": selfmade_duration_minutes,
		"fracture_resistance_duration_minutes": fracture_resistance_duration_minutes,
		"medicine_effect_duration_minutes": medicine_effect_duration_minutes,
		"contraceptive_fallback_duration_minutes": contraceptive_fallback_duration_minutes,
		"pads_fallback_duration_minutes": pads_fallback_duration_minutes,
		"noodle_overuse_window_minutes": noodle_overuse_window_minutes,
		"noodle_overuse_threshold": noodle_overuse_threshold,
		"soap_bonus_hygiene_amount": soap_bonus_hygiene_amount,
		"soap_bonus_window_minutes": soap_bonus_window_minutes,
		"cigarette_nicotine_addiction_gain": cigarette_nicotine_addiction_gain,
		"vape_nicotine_addiction_gain": vape_nicotine_addiction_gain,
		"nicotine_addiction": nicotine_addiction,
		"future_disease_risk_multiplier": future_disease_risk_multiplier,
		"future_pregnancy_risk_multiplier": future_pregnancy_risk_multiplier,
		"future_menstruation_leak_risk_multiplier": future_menstruation_leak_risk_multiplier,
		"future_fracture_risk_multiplier": future_fracture_risk_multiplier,
		"hp": hp,
		"hunger": hunger,
		"energy": energy,
		"hygiene": hygiene,
	}


func _get_resolved_last_sleep_finished_absolute_minutes(current_absolute_minutes: int) -> int:
	if _last_sleep_finished_absolute_minutes < 0:
		_last_sleep_finished_absolute_minutes = current_absolute_minutes

	return min(_last_sleep_finished_absolute_minutes, current_absolute_minutes)


func _apply_awake_hunger_decay(elapsed_minutes: int) -> void:
	if elapsed_minutes <= 0:
		return

	if awake_hunger_decay_per_hour <= 0.0:
		return

	if hunger <= 0:
		_awake_hunger_decay_accumulator = 0.0
		return

	_awake_hunger_decay_accumulator += (
		float(elapsed_minutes) * awake_hunger_decay_per_hour / 60.0
	)

	var hunger_loss: int = int(floor(_awake_hunger_decay_accumulator))

	if hunger_loss <= 0:
		return

	_awake_hunger_decay_accumulator -= float(hunger_loss)
	apply_action_tick(&"awake_hunger_decay", {"hunger": -hunger_loss})

	if hunger <= 0:
		_awake_hunger_decay_accumulator = 0.0


func _apply_awake_hygiene_decay(elapsed_minutes: int) -> void:
	if elapsed_minutes <= 0:
		return

	if awake_hygiene_decay_per_hour <= 0.0:
		return

	_awake_hygiene_decay_accumulator += (
		float(elapsed_minutes) * awake_hygiene_decay_per_hour / 60.0
	)

	var hygiene_loss: int = int(floor(_awake_hygiene_decay_accumulator))

	if hygiene_loss <= 0:
		return

	_awake_hygiene_decay_accumulator -= float(hygiene_loss)
	apply_action_tick(&"awake_hygiene_decay", {"hygiene": -hygiene_loss})


func _apply_sleep_hygiene_decay(elapsed_minutes: int) -> void:
	if elapsed_minutes <= 0:
		return

	if sleep_hygiene_decay_per_hour <= 0.0:
		return

	_sleep_hygiene_decay_accumulator += (
		float(elapsed_minutes) * sleep_hygiene_decay_per_hour / 60.0
	)

	var hygiene_loss: int = int(floor(_sleep_hygiene_decay_accumulator))

	if hygiene_loss <= 0:
		return

	_sleep_hygiene_decay_accumulator -= float(hygiene_loss)
	apply_action_tick(&"sleep_hygiene_decay", {"hygiene": -hygiene_loss})


func _resolve_hunger_stage_id(current_hunger: int) -> StringName:
	if current_hunger <= hunger_starvation_threshold:
		return HUNGER_STAGE_STARVING

	if current_hunger <= hunger_exhaustion_threshold:
		return HUNGER_STAGE_EXHAUSTED

	if current_hunger <= hunger_severe_threshold:
		return HUNGER_STAGE_VERY_HUNGRY

	if current_hunger <= hunger_hungry_threshold:
		return HUNGER_STAGE_HUNGRY

	return HUNGER_STAGE_SATED


func _resolve_hygiene_stage_id(current_hygiene: int) -> StringName:
	if current_hygiene >= hygiene_clean_threshold:
		return HYGIENE_STAGE_CLEAN

	if current_hygiene >= hygiene_untidy_threshold:
		return HYGIENE_STAGE_UNTIDY

	if current_hygiene >= hygiene_dirty_threshold:
		return HYGIENE_STAGE_DIRTY

	return HYGIENE_STAGE_UNSANITARY


func _resolve_sleep_stage_id(minutes_without_sleep: int) -> StringName:
	if minutes_without_sleep >= sleep_critical_threshold_minutes:
		return SLEEP_STAGE_CRITICAL

	if minutes_without_sleep >= sleep_very_tired_threshold_minutes:
		return SLEEP_STAGE_VERY_TIRED

	if minutes_without_sleep >= sleep_tired_threshold_minutes:
		return SLEEP_STAGE_TIRED

	return SLEEP_STAGE_NONE


func _emit_hunger_warning_if_needed(
	previous_stage_id: StringName,
	next_stage_id: StringName
) -> void:
	if _get_hunger_stage_severity(next_stage_id) <= _get_hunger_stage_severity(previous_stage_id):
		return

	match next_stage_id:
		HUNGER_STAGE_HUNGRY:
			hunger_warning_requested.emit(
				"Желудок пустеет. Пока это только давит, но голод уже рядом.",
				DEFAULT_HUNGER_WARNING_DURATION
			)
		HUNGER_STAGE_VERY_HUNGRY:
			hunger_warning_requested.emit(
				"Сильный голод. Энергия восстанавливается хуже, шаг тяжелеет.",
				DEFAULT_HUNGER_WARNING_DURATION
			)
		HUNGER_STAGE_EXHAUSTED:
			hunger_warning_requested.emit(
				"Истощение. Двигаться тяжелее, без еды долго не протянуть.",
				DEFAULT_HUNGER_WARNING_DURATION
			)
		HUNGER_STAGE_STARVING:
			hunger_warning_requested.emit(
				"Голодание. Тело начинает терять HP.",
				DEFAULT_HUNGER_WARNING_DURATION
			)


func _emit_sleep_warning_if_needed(
	previous_stage_id: StringName,
	next_stage_id: StringName,
	should_request_blackout: bool
) -> void:
	if should_request_blackout:
		return

	if _get_sleep_stage_severity(next_stage_id) <= _get_sleep_stage_severity(previous_stage_id):
		return

	match next_stage_id:
		SLEEP_STAGE_TIRED:
			sleep_warning_requested.emit(
				"Руна устала. Лучше найти время для сна.",
				DEFAULT_SLEEP_WARNING_DURATION
			)
		SLEEP_STAGE_VERY_TIRED:
			sleep_warning_requested.emit(
				"Руна очень устала. Без сна долго не протянуть.",
				DEFAULT_SLEEP_WARNING_DURATION
			)
		SLEEP_STAGE_CRITICAL:
			sleep_warning_requested.emit(
				"Критический недосып. Еще немного, и Руна вырубится.",
				DEFAULT_SLEEP_WARNING_DURATION
			)


func _emit_hygiene_warning_if_needed(
	previous_stage_id: StringName,
	next_stage_id: StringName
) -> void:
	var current_absolute_minutes: int = GameTime.get_absolute_minutes()
	var previous_severity: int = _get_hygiene_stage_severity(previous_stage_id)
	var next_severity: int = _get_hygiene_stage_severity(next_stage_id)

	if next_severity <= 1:
		if previous_severity > next_severity:
			_last_hygiene_warning_absolute_minutes = -1

		return

	if next_severity > previous_severity:
		var stage_warning := ""

		match next_stage_id:
			HYGIENE_STAGE_DIRTY:
				stage_warning = "Грязь въедается в кожу. Надо бы добраться до ванной, пока это не стало частью тебя."
			HYGIENE_STAGE_UNSANITARY:
				stage_warning = "Тело уже кажется запущенным. Всё липнет, тянет вниз и слишком хорошо читается со стороны."

		if not stage_warning.is_empty():
			hygiene_warning_requested.emit(stage_warning, DEFAULT_HYGIENE_WARNING_DURATION)
			_last_hygiene_warning_absolute_minutes = current_absolute_minutes

		return

	if _last_hygiene_warning_absolute_minutes < 0:
		_last_hygiene_warning_absolute_minutes = current_absolute_minutes
		return

	if current_absolute_minutes - _last_hygiene_warning_absolute_minutes < HYGIENE_REMINDER_INTERVAL_MINUTES:
		return

	var reminder_message := ""

	match next_stage_id:
		HYGIENE_STAGE_DIRTY:
			reminder_message = "Кожа неприятно липнет, а пятна уже не спрятать взглядом. Ванна всё ещё рядом."
		HYGIENE_STAGE_UNSANITARY:
			reminder_message = "Запущенность уже стала видимой частью Руны. Без нормального мытья это только глубже въестся."

	if reminder_message.is_empty():
		return

	hygiene_warning_requested.emit(reminder_message, DEFAULT_HYGIENE_WARNING_DURATION)
	_last_hygiene_warning_absolute_minutes = current_absolute_minutes


func _get_hunger_stage_severity(stage_id: StringName) -> int:
	match stage_id:
		HUNGER_STAGE_HUNGRY:
			return 1
		HUNGER_STAGE_VERY_HUNGRY:
			return 2
		HUNGER_STAGE_EXHAUSTED:
			return 3
		HUNGER_STAGE_STARVING:
			return 4
		_:
			return 0


func _get_sleep_stage_severity(stage_id: StringName) -> int:
	match stage_id:
		SLEEP_STAGE_TIRED:
			return 1
		SLEEP_STAGE_VERY_TIRED:
			return 2
		SLEEP_STAGE_CRITICAL:
			return 3
		_:
			return 0


func _get_hygiene_stage_severity(stage_id: StringName) -> int:
	match stage_id:
		HYGIENE_STAGE_UNTIDY:
			return 1
		HYGIENE_STAGE_DIRTY:
			return 2
		HYGIENE_STAGE_UNSANITARY:
			return 3
		_:
			return 0


func _sync_hunger_stage_conditions(stage_id: StringName) -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition") or not freelance_state.has_method("add_condition"):
		return

	for condition_id in HUNGER_STAGE_CONDITIONS:
		freelance_state.call("remove_condition", condition_id)

	if stage_id == HUNGER_STAGE_SATED:
		return

	freelance_state.call(
		"add_condition",
		stage_id,
		_build_hunger_condition_payload(stage_id, hunger)
	)


func _sync_sleep_stage_conditions(stage_id: StringName, minutes_without_sleep: int) -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition") or not freelance_state.has_method("add_condition"):
		return

	for condition_id in SLEEP_STAGE_CONDITIONS:
		freelance_state.call("remove_condition", condition_id)

	if stage_id == SLEEP_STAGE_NONE:
		return

	freelance_state.call(
		"add_condition",
		stage_id,
		_build_sleep_condition_payload(stage_id, minutes_without_sleep)
	)


func _sync_hygiene_stage_conditions(stage_id: StringName) -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition") or not freelance_state.has_method("add_condition"):
		return

	for condition_id in HYGIENE_STAGE_CONDITIONS:
		freelance_state.call("remove_condition", condition_id)

	if stage_id == HYGIENE_STAGE_CLEAN:
		return

	freelance_state.call(
		"add_condition",
		stage_id,
		_build_hygiene_condition_payload(stage_id)
	)


func _build_hunger_condition_payload(stage_id: StringName, current_hunger: int) -> Dictionary:
	match stage_id:
		HUNGER_STAGE_HUNGRY:
			return {
				"title": "Голод",
				"status_text": "Давление нарастает",
				"description": "Желудок почти пуст. Пока это только давит на нервы, но без еды к концу дня станет тяжелее. Текущий уровень голода: %d/100." % current_hunger,
				"source": "hunger",
			}
		HUNGER_STAGE_VERY_HUNGRY:
			return {
				"title": "Сильный голод",
				"status_text": "Энергия восстанавливается хуже",
				"description": "Сильный голод режет восстановление энергии на 10%% и замедляет движение на 5%%. Текущий уровень голода: %d/100." % current_hunger,
				"source": "hunger",
			}
		HUNGER_STAGE_EXHAUSTED:
			return {
				"title": "Истощение",
				"status_text": "Силы на исходе",
				"description": "Истощение режет восстановление энергии на 20%%, замедляет движение на 10%% и должно блокировать пассивное восстановление HP, если оно появится. Текущий уровень голода: %d/100." % current_hunger,
				"source": "hunger",
			}
		HUNGER_STAGE_STARVING:
			return {
				"title": "Голодание",
				"status_text": "HP убывает",
				"description": "Голодание уже сжигает тело изнутри: каждые %.0f сек теряется %d HP, а штрафы истощения сохраняются. Текущий уровень голода: %d/100." % [
					starvation_damage_interval_seconds,
					starvation_damage_per_tick,
					current_hunger,
				],
				"source": "hunger",
			}
		_:
			return {
				"title": "Сытость",
				"status_text": "Без штрафов",
				"description": "Организм пока держится ровно. Текущий уровень голода: %d/100." % current_hunger,
				"source": "hunger",
			}


func _build_sleep_condition_payload(stage_id: StringName, minutes_without_sleep: int) -> Dictionary:
	var hours_without_sleep: float = float(minutes_without_sleep) / 60.0

	match stage_id:
		SLEEP_STAGE_TIRED:
			return {
				"title": "Усталость",
				"status_text": "Нужен отдых",
				"description": "Руна не спала уже %.1f ч. Концентрация падает, лучше не затягивать со сном." % hours_without_sleep,
				"source": "sleep",
			}
		SLEEP_STAGE_VERY_TIRED:
			return {
				"title": "Очень сильная усталость",
				"status_text": "Недосып усиливается",
				"description": "Руна не спала уже %.1f ч. Организм работает на износе и требует сна." % hours_without_sleep,
				"source": "sleep",
			}
		SLEEP_STAGE_CRITICAL:
			return {
				"title": "Критический недосып",
				"status_text": "На грани вырубания",
				"description": "Руна не спала уже %.1f ч. Если срочно не уснуть, она потеряет сознание." % hours_without_sleep,
				"source": "sleep",
			}
		_:
			return {}


func _build_hygiene_condition_payload(stage_id: StringName) -> Dictionary:
	var hygiene_state: Dictionary = get_hygiene_state()

	return {
		"title": String(hygiene_state.get("title", "Гигиена")),
		"status_text": String(hygiene_state.get("status_text", "Активно")),
		"description": String(hygiene_state.get("description", "")),
		"source": "hygiene",
		"hidden_in_ui": true,
		"stage_id": String(stage_id),
		"mood_pressure": float(hygiene_state.get("mood_pressure", 0.0)),
		"social_penalty_weight": float(hygiene_state.get("social_penalty_weight", 0.0)),
		"illness_risk": float(hygiene_state.get("illness_risk", 0.0)),
	}


func _resolve_hygiene_source_loss(
	source_id: StringName,
	intensity: float,
	payload: Dictionary
) -> int:
	if payload.has("flat_amount"):
		return max(0, int(round(float(payload.get("flat_amount", 0.0)) * maxf(0.0, intensity))))

	var base_loss: float = 0.0

	match source_id:
		HYGIENE_SOURCE_SEX_SCENE:
			base_loss = future_sex_scene_hygiene_loss
		HYGIENE_SOURCE_FIGHT:
			base_loss = future_fight_hygiene_loss
		HYGIENE_SOURCE_MENSTRUATION:
			base_loss = future_menstruation_hygiene_loss
		HYGIENE_SOURCE_BODY_FLUIDS:
			base_loss = future_body_fluids_hygiene_loss
		HYGIENE_SOURCE_DIRTY_WORK:
			base_loss = future_dirty_work_hygiene_loss
		HYGIENE_SOURCE_BLOOD:
			base_loss = future_blood_hygiene_loss
		HYGIENE_SOURCE_EVENT_GRIME:
			base_loss = future_event_grime_hygiene_loss
		HYGIENE_SOURCE_HUMILIATION_SCENE:
			base_loss = future_humiliation_scene_hygiene_loss
		_:
			base_loss = 0.0

	if payload.has("base_amount"):
		base_loss = float(payload.get("base_amount", base_loss))

	var resolved_intensity: float = maxf(0.0, intensity)
	var multiplier: float = maxf(0.0, float(payload.get("multiplier", 1.0)))
	var flat_bonus: float = float(payload.get("flat_bonus", 0.0))

	return max(0, int(round((base_loss * resolved_intensity * multiplier) + flat_bonus)))


func _sync_hygiene_body_state() -> void:
	if PlayerBodyState == null:
		return

	if PlayerBodyState.has_method("set_body_dirt_from_hygiene_value"):
		PlayerBodyState.set_body_dirt_from_hygiene_value(hygiene)


func _emit_hygiene_state_if_needed() -> void:
	var hygiene_state: Dictionary = get_hygiene_state()
	var next_signature := {
		"value": int(hygiene_state.get("value", hygiene)),
		"stage_id": String(hygiene_state.get("stage_id", "")),
		"dirt_visual_alpha": float(hygiene_state.get("dirt_visual_alpha", 0.0)),
		"mood_pressure": float(hygiene_state.get("mood_pressure", 0.0)),
	}

	if next_signature == _last_hygiene_state_signature:
		return

	_last_hygiene_state_signature = next_signature
	hygiene_state_changed.emit(hygiene_state)


func _emit_sleep_state_if_needed() -> void:
	var sleep_state := get_sleep_state()
	var next_signature := {
		"last_sleep_finished_absolute_minutes": int(
			sleep_state.get("last_sleep_finished_absolute_minutes", 0)
		),
		"sleep_stage_id": String(sleep_state.get("sleep_stage_id", "")),
		"pending_forced_blackout": bool(sleep_state.get("pending_forced_blackout", false)),
		"forced_blackout_in_progress": bool(
			sleep_state.get("forced_blackout_in_progress", false)
		),
	}

	if next_signature == _last_sleep_state_signature:
		return

	_last_sleep_state_signature = next_signature
	sleep_state_changed.emit(sleep_state)


func _normalize_sleep_stage_id(raw_stage_id: String) -> StringName:
	match raw_stage_id.strip_edges():
		String(SLEEP_STAGE_TIRED):
			return SLEEP_STAGE_TIRED
		String(SLEEP_STAGE_VERY_TIRED):
			return SLEEP_STAGE_VERY_TIRED
		String(SLEEP_STAGE_CRITICAL):
			return SLEEP_STAGE_CRITICAL
		_:
			return SLEEP_STAGE_NONE


func _normalize_hygiene_stage_id(raw_stage_id: String) -> StringName:
	match raw_stage_id.strip_edges():
		String(HYGIENE_STAGE_CLEAN):
			return HYGIENE_STAGE_CLEAN
		String(HYGIENE_STAGE_UNTIDY):
			return HYGIENE_STAGE_UNTIDY
		String(HYGIENE_STAGE_DIRTY):
			return HYGIENE_STAGE_DIRTY
		String(HYGIENE_STAGE_UNSANITARY):
			return HYGIENE_STAGE_UNSANITARY
		_:
			return _resolve_hygiene_stage_id(hygiene)
