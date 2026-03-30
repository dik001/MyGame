class_name PlayerMentalStateState
extends Node

signal mental_state_changed(snapshot: Dictionary)
signal mood_state_changed(state: Dictionary)
signal stress_state_changed(state: Dictionary)
signal mental_threshold_crossed(stat_id: StringName, from_id: StringName, to_id: StringName)
signal modifiers_changed(modifiers: Array)

const CONFIG_PATH := "res://resources/mental/default_mental_state_config.tres"
const DEFAULT_SLEEP_RECOVERY_MULTIPLIER := 1.0
const DEFAULT_WORK_ENERGY_COST_MULTIPLIER := 1.0
const MOOD_STATE_EXCELLENT: StringName = &"excellent"
const MOOD_STATE_NORMAL: StringName = &"normal"
const MOOD_STATE_LOW: StringName = &"low"
const MOOD_STATE_DEPRESSED: StringName = &"depressed"
const STRESS_STATE_CALM: StringName = &"calm"
const STRESS_STATE_TENSE: StringName = &"tense"
const STRESS_STATE_HIGH: StringName = &"high"
const STRESS_STATE_PANIC: StringName = &"panic"
const CONDITION_PREFIX := "mental_"
const MentalStateConfigScript = preload("res://scenes/mental/MentalStateConfig.gd")
const MentalStateModifierDataScript = preload("res://scenes/mental/MentalStateModifierData.gd")

var config = null
var mood: float = 0.0
var stress: float = 0.0
var base_mood: float = 0.0
var base_stress: float = 0.0

var _active_modifiers: Array[Dictionary] = []
var _last_processed_absolute_minutes: int = 0
var _current_mood_state_id: StringName = MOOD_STATE_NORMAL
var _current_stress_state_id: StringName = STRESS_STATE_CALM
var _last_state_signature: Dictionary = {}
var _last_modifier_signature: Array[String] = []
var _synced_condition_ids: Array[StringName] = []
var _is_syncing_visible_conditions: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()
	reset_state()
	call_deferred("_connect_dependencies")
	call_deferred("_emit_initial_state")


func get_state() -> Dictionary:
	return {
		"mood": mood,
		"stress": stress,
		"base_mood": base_mood,
		"base_stress": base_stress,
		"min_value": _get_min_value(),
		"max_value": _get_max_value(),
		"normalized_mood": _normalize_value(mood),
		"normalized_stress": _normalize_value(stress),
		"mood_state": get_mood_state(),
		"stress_state": get_stress_state(),
		"effects": get_effects(),
		"last_processed_absolute_minutes": _last_processed_absolute_minutes,
		"active_modifiers": get_active_modifiers(),
	}


func get_mood_state() -> Dictionary:
	var definition: Dictionary = config.get_mood_state_definition(_current_mood_state_id)
	definition["id"] = str(_current_mood_state_id)
	definition["value"] = mood
	definition["normalized_value"] = _normalize_value(mood)
	return definition


func get_stress_state() -> Dictionary:
	var definition: Dictionary = config.get_stress_state_definition(_current_stress_state_id)
	definition["id"] = str(_current_stress_state_id)
	definition["value"] = stress
	definition["normalized_value"] = _normalize_value(stress)
	return definition


func get_effects() -> Dictionary:
	var bonus_totals = {
		"sleep_recovery_multiplier": 0.0,
		"work_energy_cost_multiplier": 0.0,
	}

	_accumulate_effect_bonuses(
		bonus_totals,
		SaveDataUtils.sanitize_dictionary(get_mood_state().get("effect_bonuses", {}))
	)
	_accumulate_effect_bonuses(
		bonus_totals,
		SaveDataUtils.sanitize_dictionary(get_stress_state().get("effect_bonuses", {}))
	)

	for modifier in _active_modifiers:
		_accumulate_effect_bonuses(
			bonus_totals,
			SaveDataUtils.sanitize_dictionary(modifier.get("effect_bonuses", {}))
		)

	return {
		"sleep_recovery_bonus": float(bonus_totals.get("sleep_recovery_multiplier", 0.0)),
		"sleep_recovery_multiplier": maxf(
			0.25,
			DEFAULT_SLEEP_RECOVERY_MULTIPLIER + float(bonus_totals.get("sleep_recovery_multiplier", 0.0))
		),
		"work_energy_cost_bonus": float(bonus_totals.get("work_energy_cost_multiplier", 0.0)),
		"work_energy_cost_multiplier": maxf(
			0.40,
			DEFAULT_WORK_ENERGY_COST_MULTIPLIER + float(bonus_totals.get("work_energy_cost_multiplier", 0.0))
		),
	}


func get_active_modifiers() -> Array:
	var result: Array[Dictionary] = []
	var current_absolute_minutes: int = _get_current_absolute_minutes()

	for modifier in _active_modifiers:
		var modifier_copy: Dictionary = MentalStateModifierDataScript.duplicate_modifier(modifier)
		modifier_copy["remaining_minutes"] = MentalStateModifierDataScript.get_remaining_minutes(
			modifier,
			current_absolute_minutes
		)
		result.append(modifier_copy)

	return result


func build_debug_snapshot() -> Dictionary:
	return {
		"state": get_state(),
		"effect_snapshot": get_effects(),
		"active_modifier_count": _active_modifiers.size(),
		"modifiers": get_active_modifiers(),
	}


func apply_delta(
	mood_delta: float,
	stress_delta: float,
	source: StringName = &"system",
	tags: Array = []
) -> Dictionary:
	_process_time_to(_get_current_absolute_minutes())
	var changed: bool = _apply_direct_delta_internal(
		mood_delta,
		stress_delta,
		str(source),
		_normalize_tags(tags)
	)

	if changed:
		_after_state_changed(true)

	return get_state()


func apply_event(event_id: StringName, payload: Dictionary = {}) -> Dictionary:
	_process_time_to(_get_current_absolute_minutes())
	var preset: Dictionary = config.get_event_preset(event_id)
	var resolved_payload: Dictionary = SaveDataUtils.sanitize_dictionary(payload)
	var source_name: String = str(
		resolved_payload.get("source", preset.get("source", str(event_id)))
	).strip_edges()
	var scale: float = maxf(0.0, float(resolved_payload.get("multiplier", 1.0)))
	var merged_tags: Array[String] = _merge_tag_arrays(
		_normalize_tags(preset.get("tags", [])),
		_normalize_tags(resolved_payload.get("tags", []))
	)
	var mood_delta: float = float(
		resolved_payload.get("mood_delta", preset.get("mood_delta", 0.0))
	)
	var stress_delta: float = float(
		resolved_payload.get("stress_delta", preset.get("stress_delta", 0.0))
	)
	var changed: bool = _apply_direct_delta_internal(
		mood_delta * scale,
		stress_delta * scale,
		source_name,
		merged_tags
	)
	var modifier_source: Variant = resolved_payload.get("modifier", preset.get("modifier", {}))
	var modifier_data: Dictionary = SaveDataUtils.sanitize_dictionary(modifier_source)

	if not modifier_data.is_empty():
		var modifier_patch: Dictionary = SaveDataUtils.sanitize_dictionary(
			resolved_payload.get("modifier_patch", {})
		)
		modifier_data.merge(modifier_patch, true)
		modifier_data["source"] = str(
			modifier_data.get("source", source_name if not source_name.is_empty() else str(event_id))
		).strip_edges()
		modifier_data["tags"] = _merge_tag_arrays(
			_normalize_tags(modifier_data.get("tags", [])),
			merged_tags
		)

		if resolved_payload.has("modifier_duration_minutes"):
			modifier_data["duration_minutes"] = int(
				resolved_payload.get("modifier_duration_minutes", -1)
			)
			modifier_data.erase("expires_at_absolute_minutes")

		if resolved_payload.has("modifier_scale"):
			var modifier_scale: float = float(resolved_payload.get("modifier_scale", 1.0))
			modifier_data["mood_delta_per_hour"] = float(
				modifier_data.get("mood_delta_per_hour", 0.0)
			) * modifier_scale
			modifier_data["stress_delta_per_hour"] = float(
				modifier_data.get("stress_delta_per_hour", 0.0)
			) * modifier_scale

		var add_result: Dictionary = upsert_modifier(modifier_data)
		changed = bool(add_result.get("changed", false)) or changed

	if changed:
		_after_state_changed(true)

	return get_state()


func add_modifier(raw_modifier: Variant) -> Dictionary:
	return _add_modifier_internal(raw_modifier, false)


func upsert_modifier(raw_modifier: Variant) -> Dictionary:
	return _add_modifier_internal(raw_modifier, true)


func update_modifier(modifier_id: String, patch: Dictionary) -> Dictionary:
	_process_time_to(_get_current_absolute_minutes())
	var resolved_modifier_id: String = modifier_id.strip_edges()

	if resolved_modifier_id.is_empty():
		return {"changed": false}

	var patch_copy: Dictionary = SaveDataUtils.sanitize_dictionary(patch)

	for index in range(_active_modifiers.size()):
		var modifier: Dictionary = _active_modifiers[index]

		if str(modifier.get("id", "")) != resolved_modifier_id:
			continue

		var next_modifier: Dictionary = modifier.duplicate(true)

		if patch_copy.has("duration_minutes") and not patch_copy.has("applied_at_absolute_minutes") and not patch_copy.has("expires_at_absolute_minutes"):
			next_modifier["applied_at_absolute_minutes"] = _get_current_absolute_minutes()

		next_modifier.merge(patch_copy, true)
		var normalized: Dictionary = MentalStateModifierDataScript.normalize(
			next_modifier,
			_get_current_absolute_minutes()
		)

		if normalized.is_empty():
			return {"changed": false}

		_active_modifiers[index] = normalized
		_prune_expired_modifiers(_get_current_absolute_minutes())
		_after_modifiers_changed()
		_after_state_changed(true)
		return {"changed": true, "modifier": normalized.duplicate(true)}

	return {"changed": false}


func remove_modifier(modifier_id: String) -> bool:
	_process_time_to(_get_current_absolute_minutes())
	var resolved_modifier_id: String = modifier_id.strip_edges()

	if resolved_modifier_id.is_empty():
		return false

	for index in range(_active_modifiers.size() - 1, -1, -1):
		if str(_active_modifiers[index].get("id", "")) != resolved_modifier_id:
			continue

		_active_modifiers.remove_at(index)
		_after_modifiers_changed()
		_after_state_changed(true)
		return true

	return false


func remove_by_tag(tag: StringName) -> int:
	_process_time_to(_get_current_absolute_minutes())
	var tag_text: String = str(tag).strip_edges().to_lower()

	if tag_text.is_empty():
		return 0

	var removed_count: int = 0

	for index in range(_active_modifiers.size() - 1, -1, -1):
		if not MentalStateModifierDataScript.has_tag(_active_modifiers[index], StringName(tag_text)):
			continue

		_active_modifiers.remove_at(index)
		removed_count += 1

	if removed_count > 0:
		_after_modifiers_changed()
		_after_state_changed(true)

	return removed_count


func refresh_context_modifiers(force_emit: bool = false) -> void:
	_process_time_to(_get_current_absolute_minutes())
	_sync_hunger_modifier()
	_sync_sleep_modifier()
	_sync_hygiene_modifier()
	_sync_home_safe_zone_modifier()
	_sync_eye_strain_modifier()
	_sync_poverty_modifier()
	_sync_rent_modifier()
	_prune_expired_modifiers(_get_current_absolute_minutes())
	_after_modifiers_changed()

	if force_emit:
		_after_state_changed(true)
	else:
		_after_state_changed(false)


func build_save_data() -> Dictionary:
	var modifiers_payload: Array[Dictionary] = []

	for modifier in _active_modifiers:
		modifiers_payload.append(MentalStateModifierDataScript.build_save_payload(modifier))

	return {
		"mood": mood,
		"stress": stress,
		"base_mood": base_mood,
		"base_stress": base_stress,
		"current_mood_state_id": str(_current_mood_state_id),
		"current_stress_state_id": str(_current_stress_state_id),
		"last_processed_absolute_minutes": _last_processed_absolute_minutes,
		"active_modifiers": modifiers_payload,
	}


func apply_save_data(data: Dictionary) -> void:
	var resolved_data: Dictionary = SaveDataUtils.sanitize_dictionary(data)
	mood = _clamp_value(float(resolved_data.get("mood", config.default_mood)))
	stress = _clamp_value(float(resolved_data.get("stress", config.default_stress)))
	base_mood = _clamp_value(float(resolved_data.get("base_mood", config.base_mood)))
	base_stress = _clamp_value(float(resolved_data.get("base_stress", config.base_stress)))
	_last_processed_absolute_minutes = int(
		resolved_data.get("last_processed_absolute_minutes", _get_current_absolute_minutes())
	)
	_active_modifiers.clear()

	for modifier_variant in SaveDataUtils.sanitize_array(resolved_data.get("active_modifiers", [])):
		var normalized: Dictionary = MentalStateModifierDataScript.normalize(
			modifier_variant,
			_last_processed_absolute_minutes
		)

		if normalized.is_empty():
			continue

		_active_modifiers.append(normalized)

	_current_mood_state_id = _resolve_mood_state_id(mood)
	_current_stress_state_id = _resolve_stress_state_id(stress)
	_prune_expired_modifiers(_get_current_absolute_minutes())
	refresh_context_modifiers(true)
	_process_time_to(_get_current_absolute_minutes())
	_emit_state_changed_if_needed(true)


func reset_state() -> void:
	mood = config.default_mood
	stress = config.default_stress
	base_mood = config.base_mood
	base_stress = config.base_stress
	_active_modifiers.clear()
	_last_processed_absolute_minutes = _get_current_absolute_minutes()
	_current_mood_state_id = _resolve_mood_state_id(mood)
	_current_stress_state_id = _resolve_stress_state_id(stress)
	_last_state_signature.clear()
	_last_modifier_signature.clear()
	_clear_synced_conditions()
	_emit_state_changed_if_needed(true)


func _load_config() -> void:
	var loaded_resource = load(CONFIG_PATH)
	config = loaded_resource

	if config == null or not config.has_method("get_mood_state_definition"):
		config = MentalStateConfigScript.new()


func _connect_dependencies() -> void:
	if GameTime != null and GameTime.has_signal(&"time_changed"):
		if not GameTime.time_changed.is_connected(_on_game_time_changed):
			GameTime.time_changed.connect(_on_game_time_changed)

	if PlayerStats != null:
		if PlayerStats.has_signal(&"stats_changed") and not PlayerStats.stats_changed.is_connected(_on_player_stats_changed):
			PlayerStats.stats_changed.connect(_on_player_stats_changed)

		if PlayerStats.has_signal(&"tick_applied") and not PlayerStats.tick_applied.is_connected(_on_player_tick_applied):
			PlayerStats.tick_applied.connect(_on_player_tick_applied)

		if PlayerStats.has_signal(&"sleep_state_changed") and not PlayerStats.sleep_state_changed.is_connected(_on_sleep_state_changed):
			PlayerStats.sleep_state_changed.connect(_on_sleep_state_changed)

		if PlayerStats.has_signal(&"hygiene_state_changed") and not PlayerStats.hygiene_state_changed.is_connected(_on_hygiene_state_changed):
			PlayerStats.hygiene_state_changed.connect(_on_hygiene_state_changed)

	if PlayerEconomy != null:
		if PlayerEconomy.has_signal(&"cash_dollars_changed") and not PlayerEconomy.cash_dollars_changed.is_connected(_on_money_changed):
			PlayerEconomy.cash_dollars_changed.connect(_on_money_changed)

		if PlayerEconomy.has_signal(&"bank_dollars_changed") and not PlayerEconomy.bank_dollars_changed.is_connected(_on_money_changed):
			PlayerEconomy.bank_dollars_changed.connect(_on_money_changed)

	if ApartmentRentState != null:
		if ApartmentRentState.has_signal(&"rent_state_changed") and not ApartmentRentState.rent_state_changed.is_connected(_on_rent_state_changed):
			ApartmentRentState.rent_state_changed.connect(_on_rent_state_changed)

		if ApartmentRentState.has_signal(&"rent_due_today") and not ApartmentRentState.rent_due_today.is_connected(_on_rent_due_today):
			ApartmentRentState.rent_due_today.connect(_on_rent_due_today)

		if ApartmentRentState.has_signal(&"rent_overdue") and not ApartmentRentState.rent_overdue.is_connected(_on_rent_overdue):
			ApartmentRentState.rent_overdue.connect(_on_rent_overdue)

		if ApartmentRentState.has_signal(&"rent_paid") and not ApartmentRentState.rent_paid.is_connected(_on_rent_paid):
			ApartmentRentState.rent_paid.connect(_on_rent_paid)

	if FreelanceState != null:
		if FreelanceState.has_signal(&"order_finished") and not FreelanceState.order_finished.is_connected(_on_freelance_order_finished):
			FreelanceState.order_finished.connect(_on_freelance_order_finished)

		if FreelanceState.has_signal(&"conditions_changed") and not FreelanceState.conditions_changed.is_connected(_on_freelance_conditions_changed):
			FreelanceState.conditions_changed.connect(_on_freelance_conditions_changed)

	refresh_context_modifiers(true)


func _emit_initial_state() -> void:
	_emit_state_changed_if_needed(true)


func _on_game_time_changed(absolute_minutes: int, _day: int, _hours: int, _minutes: int) -> void:
	_process_time_to(absolute_minutes)
	refresh_context_modifiers()


func _on_player_stats_changed(_current_stats: Dictionary) -> void:
	refresh_context_modifiers()


func _on_player_tick_applied(
	tick_name: StringName,
	delta: Dictionary,
	_current_stats: Dictionary
) -> void:
	match tick_name:
		&"consume_food":
			var hunger_delta: int = abs(int(delta.get("hunger", 0)))
			var multiplier: float = clampf(float(hunger_delta) / 24.0, 0.65, 1.75)
			apply_event(&"consume_food", {"multiplier": multiplier, "source": "food"})
		_:
			pass

	refresh_context_modifiers()


func _on_sleep_state_changed(_state: Dictionary) -> void:
	refresh_context_modifiers()


func _on_hygiene_state_changed(_state: Dictionary) -> void:
	refresh_context_modifiers()


func _on_money_changed(_new_value: int) -> void:
	refresh_context_modifiers()


func _on_rent_state_changed() -> void:
	refresh_context_modifiers()


func _on_rent_due_today() -> void:
	apply_event(&"rent_due_today", {"source": "rent"})
	refresh_context_modifiers()


func _on_rent_overdue() -> void:
	apply_event(&"rent_overdue", {"source": "rent"})
	refresh_context_modifiers()


func _on_rent_paid(result: Dictionary) -> void:
	var multiplier: float = 1.0

	if bool(result.get("was_overdue", false)):
		multiplier = 1.15

	apply_event(&"rent_paid", {"source": "rent", "multiplier": multiplier})
	refresh_context_modifiers()


func _on_freelance_order_finished(_order_id: int, result: Dictionary) -> void:
	if not bool(result.get("success", false)):
		return

	var result_status: String = str(result.get("result_status", "")).strip_edges().to_lower()

	if result_status == "fail":
		apply_event(&"freelance_fail", {"source": "freelance"})
	else:
		var multiplier: float = 1.2 if result_status == "excellent" else 1.0
		apply_event(
			&"freelance_success",
			{"source": "freelance", "multiplier": multiplier}
		)

	refresh_context_modifiers()


func _on_freelance_conditions_changed() -> void:
	if _is_syncing_visible_conditions:
		return

	refresh_context_modifiers()


func _process_time_to(target_absolute_minutes: int) -> void:
	var resolved_target: int = max(0, target_absolute_minutes)

	if resolved_target <= _last_processed_absolute_minutes:
		return

	var current_absolute_minutes: int = _last_processed_absolute_minutes

	while current_absolute_minutes < resolved_target:
		_prune_expired_modifiers(current_absolute_minutes)
		var next_expiry: int = _find_next_modifier_expiry(current_absolute_minutes)
		var segment_end: int = resolved_target

		if next_expiry >= 0 and next_expiry < segment_end:
			segment_end = next_expiry

		var elapsed_minutes: int = max(0, segment_end - current_absolute_minutes)

		if elapsed_minutes > 0:
			_apply_elapsed_minutes(elapsed_minutes)

		current_absolute_minutes = segment_end
		_last_processed_absolute_minutes = current_absolute_minutes

		if next_expiry >= 0 and current_absolute_minutes >= next_expiry:
			_prune_expired_modifiers(current_absolute_minutes)

	_last_processed_absolute_minutes = resolved_target
	_after_state_changed(false)


func _apply_elapsed_minutes(elapsed_minutes: int) -> void:
	var current_min: float = _get_min_value()
	var current_max: float = _get_max_value()

	for _minute in range(elapsed_minutes):
		var modifier_rates: Dictionary = _get_modifier_hourly_rates()
		var mood_rate_per_hour: float = _resolve_natural_mood_rate() + float(
			modifier_rates.get("mood", 0.0)
		)
		var stress_rate_per_hour: float = _resolve_natural_stress_rate() + float(
			modifier_rates.get("stress", 0.0)
		)

		if stress > config.stress_to_mood_pressure_threshold:
			var pressure_scale: float = inverse_lerp(
				config.stress_to_mood_pressure_threshold,
				current_max,
				stress
			)
			mood_rate_per_hour -= config.stress_to_mood_pressure_per_hour_at_max * clampf(
				pressure_scale,
				0.0,
				1.0
			)

		mood = clampf(mood + (mood_rate_per_hour / 60.0), current_min, current_max)
		stress = clampf(stress + (stress_rate_per_hour / 60.0), current_min, current_max)


func _resolve_natural_mood_rate() -> float:
	if mood < base_mood:
		return config.natural_mood_recovery_per_hour

	if mood > base_mood:
		return -config.natural_mood_decay_above_base_per_hour

	return 0.0


func _resolve_natural_stress_rate() -> float:
	if stress > base_stress:
		return -config.natural_stress_relief_per_hour

	if stress < base_stress:
		return config.natural_stress_build_up_to_base_per_hour

	return 0.0


func _get_modifier_hourly_rates() -> Dictionary:
	var mood_total: float = 0.0
	var stress_total: float = 0.0

	for modifier in _active_modifiers:
		mood_total += float(modifier.get("mood_delta_per_hour", 0.0))
		stress_total += float(modifier.get("stress_delta_per_hour", 0.0))

	return {
		"mood": mood_total,
		"stress": stress_total,
	}


func _apply_direct_delta_internal(
	mood_delta: float,
	stress_delta: float,
	_source: String,
	_tags: Array[String]
) -> bool:
	var previous_mood: float = mood
	var previous_stress: float = stress
	mood = _clamp_value(mood + mood_delta)
	stress = _clamp_value(stress + stress_delta)
	return not is_equal_approx(previous_mood, mood) or not is_equal_approx(previous_stress, stress)


func _add_modifier_internal(raw_modifier: Variant, _upsert: bool) -> Dictionary:
	_process_time_to(_get_current_absolute_minutes())
	var normalized: Dictionary = MentalStateModifierDataScript.normalize(
		raw_modifier,
		_get_current_absolute_minutes()
	)

	if normalized.is_empty():
		return {"changed": false}

	var stack_policy: String = str(
		normalized.get("stack_policy", MentalStateModifierDataScript.STACK_POLICY_REPLACE)
	)
	var resolved_id: String = str(normalized.get("id", "")).strip_edges()
	var existing_index: int = _find_modifier_index_by_id(resolved_id)

	if existing_index >= 0:
		match stack_policy:
			MentalStateModifierDataScript.STACK_POLICY_STACK:
				normalized["id"] = _build_stacked_modifier_id(resolved_id)
			MentalStateModifierDataScript.STACK_POLICY_REFRESH_DURATION, MentalStateModifierDataScript.STACK_POLICY_REPLACE:
				_active_modifiers[existing_index] = normalized
				_prune_expired_modifiers(_get_current_absolute_minutes())
				_after_modifiers_changed()
				_after_state_changed(true)
				return {"changed": true, "modifier": normalized.duplicate(true)}
			_:
				_active_modifiers[existing_index] = normalized
				_prune_expired_modifiers(_get_current_absolute_minutes())
				_after_modifiers_changed()
				_after_state_changed(true)
				return {"changed": true, "modifier": normalized.duplicate(true)}

	_active_modifiers.append(normalized)
	_prune_expired_modifiers(_get_current_absolute_minutes())
	_after_modifiers_changed()
	_after_state_changed(true)
	return {"changed": true, "modifier": normalized.duplicate(true)}


func _find_modifier_index_by_id(modifier_id: String) -> int:
	for index in range(_active_modifiers.size()):
		if str(_active_modifiers[index].get("id", "")) == modifier_id:
			return index

	return -1


func _build_stacked_modifier_id(base_id: String) -> String:
	var suffix: int = 2
	var candidate: String = base_id

	while _find_modifier_index_by_id(candidate) >= 0:
		candidate = "%s__%d" % [base_id, suffix]
		suffix += 1

	return candidate


func _prune_expired_modifiers(current_absolute_minutes: int) -> void:
	var removed_any: bool = false

	for index in range(_active_modifiers.size() - 1, -1, -1):
		if not MentalStateModifierDataScript.is_expired(_active_modifiers[index], current_absolute_minutes):
			continue

		_active_modifiers.remove_at(index)
		removed_any = true

	if removed_any:
		_after_modifiers_changed()


func _find_next_modifier_expiry(current_absolute_minutes: int) -> int:
	var next_expiry: int = -1

	for modifier in _active_modifiers:
		var expiry: int = int(modifier.get("expires_at_absolute_minutes", -1))

		if expiry < 0 or expiry <= current_absolute_minutes:
			continue

		if next_expiry < 0 or expiry < next_expiry:
			next_expiry = expiry

	return next_expiry


func _sync_hunger_modifier() -> void:
	var stage_id: String = str(PlayerStats.get_hunger_stage_id()) if PlayerStats != null and PlayerStats.has_method("get_hunger_stage_id") else ""
	var modifier: Dictionary = config.get_hunger_stage_modifier(StringName(stage_id))
	_sync_context_modifier("context_hunger_pressure", modifier, "hunger")


func _sync_sleep_modifier() -> void:
	var sleep_state: Dictionary = PlayerStats.get_sleep_state() if PlayerStats != null and PlayerStats.has_method("get_sleep_state") else {}
	var stage_id: String = str(sleep_state.get("sleep_stage_id", "")).strip_edges()
	var modifier: Dictionary = config.get_sleep_stage_modifier(StringName(stage_id))
	_sync_context_modifier("context_sleep_pressure", modifier, "sleep")


func _sync_hygiene_modifier() -> void:
	var stage_id: String = str(PlayerStats.get_hygiene_stage_id()) if PlayerStats != null and PlayerStats.has_method("get_hygiene_stage_id") else ""
	var modifier: Dictionary = config.get_hygiene_stage_modifier(StringName(stage_id))
	_sync_context_modifier("context_hygiene_pressure", modifier, "hygiene")


func _sync_home_safe_zone_modifier() -> void:
	var room_scene_path: String = ""

	if GameManager != null and GameManager.has_method("get_current_room_scene_path"):
		room_scene_path = str(GameManager.get_current_room_scene_path()).strip_edges()

	var modifier: Dictionary = config.get_home_safe_zone_modifier(room_scene_path)
	_sync_context_modifier("context_safe_home", modifier, "safe_zone")


func _sync_eye_strain_modifier() -> void:
	var has_eye_strain: bool = false

	if FreelanceState != null and FreelanceState.has_method("has_condition"):
		has_eye_strain = bool(FreelanceState.has_condition(&"eye_strain"))

	var modifier: Dictionary = config.get_eye_strain_modifier() if has_eye_strain else {}
	_sync_context_modifier("context_eye_strain", modifier, "freelance")


func _sync_poverty_modifier() -> void:
	var total_money: int = 0

	if PlayerEconomy != null:
		if PlayerEconomy.has_method("get_cash_dollars"):
			total_money += int(PlayerEconomy.get_cash_dollars())

		if PlayerEconomy.has_method("get_bank_dollars"):
			total_money += int(PlayerEconomy.get_bank_dollars())

	var modifier: Dictionary = config.get_poverty_modifier(total_money)
	_sync_context_modifier("context_poverty_pressure", modifier, "economy")


func _sync_rent_modifier() -> void:
	var rent_modifier: Dictionary = {}

	if ApartmentRentState != null and ApartmentRentState.has_method("get_current_rent_snapshot"):
		var snapshot: Dictionary = ApartmentRentState.get_current_rent_snapshot()
		var rent_state: String = str(snapshot.get("state", snapshot.get("current_state", ""))).strip_edges().to_lower()
		rent_modifier = config.get_rent_state_modifier(rent_state)

	_sync_context_modifier("context_rent_pressure", rent_modifier, "rent")


func _sync_context_modifier(modifier_id: String, modifier_data: Dictionary, source_name: String) -> void:
	if modifier_data.is_empty():
		_remove_modifier_silently(modifier_id)
		return

	var modifier: Dictionary = modifier_data.duplicate(true)
	modifier["id"] = modifier_id
	modifier["source"] = str(modifier.get("source", source_name))
	modifier["stack_policy"] = MentalStateModifierDataScript.STACK_POLICY_REPLACE
	modifier["applied_at_absolute_minutes"] = _get_current_absolute_minutes()
	modifier["duration_minutes"] = -1
	modifier["expires_at_absolute_minutes"] = -1
	modifier["tags"] = _merge_tag_arrays(
		_normalize_tags(modifier.get("tags", [])),
		["context", source_name]
	)
	var normalized: Dictionary = MentalStateModifierDataScript.normalize(
		modifier,
		_get_current_absolute_minutes()
	)
	var existing_index: int = _find_modifier_index_by_id(modifier_id)

	if existing_index >= 0:
		_active_modifiers[existing_index] = normalized
	else:
		_active_modifiers.append(normalized)


func _remove_modifier_silently(modifier_id: String) -> void:
	for index in range(_active_modifiers.size() - 1, -1, -1):
		if str(_active_modifiers[index].get("id", "")) != modifier_id:
			continue

		_active_modifiers.remove_at(index)


func _after_state_changed(force_emit: bool) -> void:
	var previous_mood_state: StringName = _current_mood_state_id
	var previous_stress_state: StringName = _current_stress_state_id
	_current_mood_state_id = _resolve_mood_state_id(mood)
	_current_stress_state_id = _resolve_stress_state_id(stress)
	var states_changed: bool = previous_mood_state != _current_mood_state_id or previous_stress_state != _current_stress_state_id

	if previous_mood_state != _current_mood_state_id:
		mental_threshold_crossed.emit(&"mood", previous_mood_state, _current_mood_state_id)
		mood_state_changed.emit(get_mood_state())

	if previous_stress_state != _current_stress_state_id:
		mental_threshold_crossed.emit(&"stress", previous_stress_state, _current_stress_state_id)
		stress_state_changed.emit(get_stress_state())

	if states_changed or force_emit:
		_sync_visible_conditions()

	_emit_state_changed_if_needed(force_emit or states_changed)


func _after_modifiers_changed() -> void:
	var current_signature: Array[String] = _build_modifier_signature()

	if current_signature == _last_modifier_signature:
		return

	_last_modifier_signature = current_signature
	_sync_visible_conditions()
	modifiers_changed.emit(get_active_modifiers())


func _emit_state_changed_if_needed(force_emit: bool) -> void:
	var snapshot: Dictionary = get_state()
	var signature = {
		"mood": snapped(float(snapshot.get("mood", 0.0)), 0.01),
		"stress": snapped(float(snapshot.get("stress", 0.0)), 0.01),
		"mood_state_id": str(snapshot.get("mood_state", {}).get("id", "")),
		"stress_state_id": str(snapshot.get("stress_state", {}).get("id", "")),
		"modifier_count": int(_active_modifiers.size()),
	}

	if not force_emit and signature == _last_state_signature:
		return

	_last_state_signature = signature
	mental_state_changed.emit(snapshot)


func _sync_visible_conditions() -> void:
	if _is_syncing_visible_conditions:
		return

	if FreelanceState == null:
		return

	if not FreelanceState.has_method("add_condition") or not FreelanceState.has_method("remove_condition"):
		return

	_is_syncing_visible_conditions = true
	_clear_synced_conditions()

	var condition_payloads: Dictionary = {}
	var mood_state: Dictionary = get_mood_state()
	var stress_state: Dictionary = get_stress_state()

	if bool(mood_state.get("condition_visible", false)):
		var mood_condition_id: StringName = StringName("%smood_%s" % [CONDITION_PREFIX, str(mood_state.get("id", ""))])
		condition_payloads[mood_condition_id] = {
			"title": str(mood_state.get("title", "Настроение")),
			"status_text": str(mood_state.get("status_text", "")),
			"description": str(mood_state.get("description", "")),
			"source": "mental_state",
			"severity": int(mood_state.get("severity", 0)),
		}

	if bool(stress_state.get("condition_visible", false)):
		var stress_condition_id: StringName = StringName("%sstress_%s" % [CONDITION_PREFIX, str(stress_state.get("id", ""))])
		condition_payloads[stress_condition_id] = {
			"title": str(stress_state.get("title", "Стресс")),
			"status_text": str(stress_state.get("status_text", "")),
			"description": str(stress_state.get("description", "")),
			"source": "mental_state",
			"severity": int(stress_state.get("severity", 0)),
		}

	for modifier in _active_modifiers:
		if not bool(modifier.get("show_in_ui", false)):
			continue

		var modifier_condition_id: StringName = StringName(
			"%smodifier_%s" % [CONDITION_PREFIX, str(modifier.get("id", ""))]
		)
		condition_payloads[modifier_condition_id] = {
			"title": str(modifier.get("title", "Психологическое состояние")),
			"status_text": str(modifier.get("status_text", "")),
			"description": str(modifier.get("description", "")),
			"source": str(modifier.get("source", "mental_modifier")),
			"severity": 1,
		}

	for condition_id in condition_payloads.keys():
		FreelanceState.add_condition(condition_id, condition_payloads[condition_id])
		_synced_condition_ids.append(condition_id)

	_is_syncing_visible_conditions = false


func _clear_synced_conditions() -> void:
	if FreelanceState == null or not FreelanceState.has_method("remove_condition"):
		_synced_condition_ids.clear()
		return

	var condition_ids: Array[StringName] = _synced_condition_ids.duplicate()
	_synced_condition_ids.clear()

	for condition_id in condition_ids:
		FreelanceState.remove_condition(condition_id)


func _build_modifier_signature() -> Array[String]:
	var signature: Array[String] = []

	for modifier in _active_modifiers:
		signature.append(
				"%s|%s|%s|%s|%s|%s" % [
				str(modifier.get("id", "")),
				str(modifier.get("title", "")),
				str(modifier.get("status_text", "")),
				str(modifier.get("show_in_ui", false)),
				str(modifier.get("mood_delta_per_hour", 0.0)),
				str(modifier.get("stress_delta_per_hour", 0.0)),
			]
		)

	signature.sort()
	return signature


func _resolve_mood_state_id(current_value: float) -> StringName:
	var thresholds: Dictionary = config.mood_thresholds.duplicate(true)

	if current_value >= float(thresholds.get("excellent", 78.0)):
		return MOOD_STATE_EXCELLENT

	if current_value >= float(thresholds.get("normal", 45.0)):
		return MOOD_STATE_NORMAL

	if current_value >= float(thresholds.get("low", 22.0)):
		return MOOD_STATE_LOW

	return MOOD_STATE_DEPRESSED


func _resolve_stress_state_id(current_value: float) -> StringName:
	var thresholds: Dictionary = config.stress_thresholds.duplicate(true)

	if current_value < float(thresholds.get("calm", 24.0)):
		return STRESS_STATE_CALM

	if current_value < float(thresholds.get("tense", 49.0)):
		return STRESS_STATE_TENSE

	if current_value < float(thresholds.get("high", 74.0)):
		return STRESS_STATE_HIGH

	return STRESS_STATE_PANIC


func _accumulate_effect_bonuses(target: Dictionary, bonuses: Dictionary) -> void:
	for key in bonuses.keys():
		var existing_value: float = float(target.get(key, 0.0))
		target[key] = existing_value + float(bonuses.get(key, 0.0))


func _normalize_tags(raw_tags: Variant) -> Array[String]:
	var normalized_tags: Array[String] = []

	if raw_tags is Array:
		for tag_value in raw_tags:
			var tag_text: String = str(tag_value).strip_edges()

			if tag_text.is_empty():
				continue

			if normalized_tags.has(tag_text):
				continue

			normalized_tags.append(tag_text)

	return normalized_tags


func _merge_tag_arrays(left: Array[String], right: Array[String]) -> Array[String]:
	var result: Array[String] = left.duplicate()

	for tag_text in right:
		if result.has(tag_text):
			continue

		result.append(tag_text)

	return result


func _clamp_value(value: float) -> float:
	return clampf(value, _get_min_value(), _get_max_value())


func _normalize_value(value: float) -> float:
	return inverse_lerp(_get_min_value(), _get_max_value(), value)


func _get_min_value() -> float:
	return config.min_value if config != null else 0.0


func _get_max_value() -> float:
	return config.max_value if config != null else 100.0


func _get_current_absolute_minutes() -> int:
	if GameTime != null and GameTime.has_method("get_absolute_minutes"):
		return int(GameTime.get_absolute_minutes())

	return 0
