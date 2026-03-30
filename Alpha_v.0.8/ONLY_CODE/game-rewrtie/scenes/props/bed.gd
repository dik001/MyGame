extends WorldInteractable

const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := 24 * 60
const SLEEP_DIALOG_SCENE := preload("res://scenes/ui/sleep_dialog.tscn")

@export_range(0, 23, 1) var wake_up_hour := 6
@export var energy_per_hour: float = 12.5
@export var hp_per_hour: int = 10
@export var hunger_per_hour: int = -2
@export_range(0.1, 1.0, 0.05) var min_energy_restore_multiplier_at_zero_hp: float = 0.45
@export var repeat_sleep_blocked_text: String = "Я не хочу спать..."

var _active_dialog = null
var _active_player: Node
var _is_sleep_in_progress := false


func _ready() -> void:
	interaction_name = "bed"
	interaction_prompt_text = "Спать"
	stat_delta = {}
	super._ready()


func interact(player: Node) -> void:
	if _active_dialog != null:
		return

	var player_stats := _get_player_stats_for(player)

	if player_stats != null and player_stats.has_pending_forced_blackout():
		return

	if GameTime.has_slept_today():
		_show_hud_notification(repeat_sleep_blocked_text)
		return

	interacted.emit(player, interaction_name, {})
	_after_interact(player)


func _after_interact(player: Node) -> void:
	_active_player = player
	_set_modal_state(true)
	_active_dialog = SLEEP_DIALOG_SCENE.instantiate()

	if _active_dialog == null:
		push_warning("Bed could not instantiate SleepDialog.")
		_set_modal_state(false)
		_active_player = null
		return

	_active_dialog.setup(calculate_sleep_results())
	_active_dialog.connect(&"sleep_confirmed", Callable(self, "_on_sleep_confirmed"))
	_active_dialog.connect(&"cancelled", Callable(self, "_close_sleep_dialog"))
	_active_dialog.tree_exited.connect(_on_dialog_tree_exited)
	_get_ui_parent().add_child(_active_dialog)


func _on_sleep_confirmed() -> void:
	if _is_sleep_in_progress:
		return

	var dialog := _active_dialog as SleepDialog

	if dialog == null:
		return

	_is_sleep_in_progress = true
	var sleep_results := calculate_sleep_results()
	var stats := _get_player_stats()

	if stats != null:
		stats.register_sleep(
			int(sleep_results.get("sleep_duration_minutes", 0)),
			int(sleep_results.get("sleep_started_absolute_minutes", GameTime.get_absolute_minutes()))
		)

	GameTime.mark_sleep_started()
	await dialog.play_sleep_transition(Callable(self, "_apply_sleep_effects").bind(sleep_results))
	_close_sleep_dialog()


func calculate_sleep_results() -> Dictionary:
	var current_absolute_minutes: int = GameTime.get_absolute_minutes()
	var wake_absolute_minutes: int = _calculate_wake_up_absolute_minutes(current_absolute_minutes)
	var sleep_duration_minutes: int = max(0, wake_absolute_minutes - current_absolute_minutes)
	var stats := _get_player_stats()
	var sleep_config := _build_sleep_effect_config(stats)
	var sleep_effects := SleepMath.calculate_sleep_effects(
		stats,
		sleep_duration_minutes,
		float(sleep_config.get("energy_per_hour", energy_per_hour)),
		int(sleep_config.get("hp_per_hour", hp_per_hour)),
		int(sleep_config.get("hunger_per_hour", hunger_per_hour)),
		float(
			sleep_config.get(
				"min_energy_restore_multiplier_at_zero_hp",
				min_energy_restore_multiplier_at_zero_hp
			)
		)
	)

	var wake_time_data: Dictionary = GameTime.get_time_data_for_absolute(wake_absolute_minutes)
	var daily_summary: Dictionary = PlayerEconomy.get_daily_summary()

	return {
		"sleep_started_absolute_minutes": current_absolute_minutes,
		"sleep_duration_minutes": sleep_duration_minutes,
		"wake_absolute_minutes": wake_absolute_minutes,
		"wake_day": int(wake_time_data.get("day", GameTime.get_day())),
		"wake_hour": int(wake_time_data.get("hours", wake_up_hour)),
		"wake_minute": int(wake_time_data.get("minutes", 0)),
		"energy_change": float(sleep_effects.get("energy_change", 0.0)),
		"hp_change": int(sleep_effects.get("hp_change", 0)),
		"hunger_change": int(sleep_effects.get("hunger_change", 0)),
		"time_change_minutes": sleep_duration_minutes,
		"daily_income": int(daily_summary.get("income", 0)),
		"daily_expenses": int(daily_summary.get("expense", 0)),
	}


func _calculate_wake_up_absolute_minutes(current_absolute_minutes: int) -> int:
	var current_day: int = GameTime.get_day()
	var wake_absolute_minutes: int = ((current_day - 1) * MINUTES_PER_DAY) + (wake_up_hour * MINUTES_PER_HOUR)

	if current_absolute_minutes >= wake_absolute_minutes:
		wake_absolute_minutes += MINUTES_PER_DAY

	return wake_absolute_minutes


func _apply_sleep_effects(sleep_results: Dictionary) -> void:
	var player := _active_player

	if player != null and player.has_method("get_stats_component"):
		var stats := _get_player_stats()

		if stats != null:
			stats.apply_action_tick(&"sleep", {
				"energy": float(sleep_results.get("energy_change", 0.0)),
				"hp": int(sleep_results.get("hp_change", 0)),
				"hunger": int(sleep_results.get("hunger_change", 0)),
			})

	var hud := _find_hud()

	if hud != null and hud.has_method("advance_time_by_minutes"):
		hud.advance_time_by_minutes(int(sleep_results.get("time_change_minutes", 0)))
	else:
		GameTime.advance_minutes(int(sleep_results.get("time_change_minutes", 0)))

	if PlayerMentalState != null and PlayerMentalState.has_method("apply_event"):
		var duration_minutes := int(sleep_results.get("sleep_duration_minutes", 0))
		var sleep_multiplier := clampf(float(duration_minutes) / float(max(1, 6 * MINUTES_PER_HOUR)), 0.75, 1.4)
		PlayerMentalState.apply_event(&"sleep_completed", {
			"source": "bed_sleep",
			"multiplier": sleep_multiplier,
			"modifier_scale": sleep_multiplier,
			"sleep_duration_minutes": duration_minutes,
		})

	_clear_rest_recoverable_conditions()


func _close_sleep_dialog() -> void:
	var dialog = _active_dialog
	_active_dialog = null
	_is_sleep_in_progress = false

	if dialog != null and is_instance_valid(dialog):
		if dialog.tree_exited.is_connected(_on_dialog_tree_exited):
			dialog.tree_exited.disconnect(_on_dialog_tree_exited)

		dialog.queue_free()

	_clear_modal_state()


func _on_dialog_tree_exited() -> void:
	_active_dialog = null
	_is_sleep_in_progress = false
	_clear_modal_state()


func _clear_modal_state() -> void:
	_set_modal_state(false)
	_active_player = null


func _set_modal_state(is_active: bool) -> void:
	if _active_player != null and _active_player.has_method("set_input_locked"):
		_active_player.set_input_locked(is_active)

	var hud := _find_hud()

	if hud != null and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _show_hud_notification(message: String) -> void:
	var hud := _find_hud()

	if hud != null and hud.has_method("show_notification"):
		hud.show_notification(message)


func _get_ui_parent() -> Node:
	var current_scene := get_tree().current_scene

	if current_scene != null:
		return current_scene

	return get_tree().root


func _find_hud() -> Node:
	var hud := get_tree().get_first_node_in_group("hud")

	if hud != null:
		return hud

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return null

	return current_scene.get_node_or_null("HUD")


func _get_player_stats() -> PlayerStatsState:
	var player := _active_player

	if player == null or not player.has_method("get_stats_component"):
		return null

	return player.get_stats_component() as PlayerStatsState


func _get_player_stats_for(player: Node) -> PlayerStatsState:
	if player == null or not player.has_method("get_stats_component"):
		return null

	return player.get_stats_component() as PlayerStatsState


func _build_sleep_effect_config(stats: PlayerStatsState) -> Dictionary:
	if stats != null and stats.has_method("get_sleep_effect_config"):
		return stats.get_sleep_effect_config()

	return {
		"energy_per_hour": energy_per_hour,
		"hp_per_hour": hp_per_hour,
		"hunger_per_hour": hunger_per_hour,
		"min_energy_restore_multiplier_at_zero_hp": min_energy_restore_multiplier_at_zero_hp,
	}


func _clear_rest_recoverable_conditions() -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition_by_rest"):
		return

	freelance_state.call("remove_condition_by_rest", &"eye_strain")
