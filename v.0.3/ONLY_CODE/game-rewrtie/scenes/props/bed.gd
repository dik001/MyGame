extends WorldInteractable

const MINUTES_PER_HOUR := 60
const SLEEP_DIALOG_SCENE := preload("res://scenes/ui/sleep_dialog.tscn")

@export_range(1, 12, 1) var min_sleep_hours := 1
@export_range(1, 12, 1) var max_sleep_hours := 12
@export_range(1, 12, 1) var default_sleep_hours := 1
@export var energy_per_hour: float = 12.5
@export var hp_per_hour: int = 10
@export var hunger_per_hour: int = -10

var _active_dialog = null
var _active_player: Node
var _is_sleep_in_progress := false


func _ready() -> void:
	interaction_name = "bed"
	interaction_prompt_text = "\u0421\u043F\u0430\u0442\u044C"
	stat_delta = {}
	super._ready()


func interact(player: Node) -> void:
	if _active_dialog != null:
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

	_active_dialog.setup(min_sleep_hours, max_sleep_hours, default_sleep_hours)
	_active_dialog.set_sleep_results_provider(Callable(self, "calculate_sleep_results"))
	_active_dialog.connect(&"sleep_confirmed", Callable(self, "_on_sleep_confirmed"))
	_active_dialog.connect(&"cancelled", Callable(self, "_close_sleep_dialog"))
	_active_dialog.tree_exited.connect(_on_dialog_tree_exited)
	_get_ui_parent().add_child(_active_dialog)


func _on_sleep_confirmed(hours: int) -> void:
	if _is_sleep_in_progress:
		return

	var dialog := _active_dialog as SleepDialog

	if dialog == null:
		return

	_is_sleep_in_progress = true
	var sleep_results := calculate_sleep_results(hours)
	await dialog.play_sleep_transition(Callable(self, "_apply_sleep_effects").bind(sleep_results))
	_close_sleep_dialog()


func calculate_sleep_results(hours: int) -> Dictionary:
	var sleep_hours := clampi(hours, min_sleep_hours, max_sleep_hours)
	var energy_change := float(sleep_hours) * energy_per_hour
	var hp_change := sleep_hours * hp_per_hour
	var hunger_change := sleep_hours * hunger_per_hour
	var stats := _get_player_stats()

	if stats != null:
		energy_change = clampf(stats.energy + energy_change, 0.0, stats.max_energy) - stats.energy
		hp_change = clampi(stats.hp + hp_change, 0, stats.max_hp) - stats.hp
		hunger_change = clampi(stats.hunger + hunger_change, 0, stats.max_hunger) - stats.hunger

	return {
		"hours": sleep_hours,
		"energy_change": energy_change,
		"hp_change": hp_change,
		"hunger_change": hunger_change,
		"time_change_minutes": sleep_hours * MINUTES_PER_HOUR,
	}


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


func _clear_rest_recoverable_conditions() -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition_by_rest"):
		return

	freelance_state.call("remove_condition_by_rest", &"eye_strain")
