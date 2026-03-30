extends WorldInteractable

const BATH_DIALOG_SCENE := preload("res://scenes/ui/bath_dialog.tscn")
const BATH_DURATION_MINUTES := 45
const CLEAN_NOTIFICATION_TEXT := "Горячая вода наконец смыла с Руны липкую грязь."
const CLEAN_LIGHT_NOTIFICATION_TEXT := "Ванна всё равно помогла отмыть остатки дня."

var _active_player: Node = null
var _active_dialog = null
var _is_washing := false


func _ready() -> void:
	interaction_name = "bath"
	interaction_prompt_text = "Мыться"
	stat_delta = {}
	super._ready()


func interact(player: Node) -> void:
	if _is_washing:
		return

	_active_player = player
	interacted.emit(player, interaction_name, {})
	_set_modal_state(true)
	_open_bath_dialog()

	if _active_dialog == null:
		_clear_modal_state()
		return

	_active_dialog.setup(_build_bath_preview())


func _on_confirmed() -> void:
	if _is_washing:
		return

	_is_washing = true

	if _active_dialog != null and is_instance_valid(_active_dialog):
		await _active_dialog.play_bath_transition(Callable(self, "_apply_bath_effects"))

	_is_washing = false
	_close_bath_dialog()


func _on_canceled() -> void:
	_close_bath_dialog()


func _on_dialog_tree_exited() -> void:
	_active_dialog = null
	_is_washing = false
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
	if _active_player == null or not _active_player.has_method("get_stats_component"):
		return null

	return _active_player.get_stats_component() as PlayerStatsState


func _open_bath_dialog() -> void:
	if _active_dialog != null and is_instance_valid(_active_dialog):
		return

	_active_dialog = BATH_DIALOG_SCENE.instantiate()

	if _active_dialog == null:
		push_warning("Bath could not instantiate BathDialog.")
		return

	_active_dialog.bath_confirmed.connect(_on_confirmed)
	_active_dialog.cancelled.connect(_on_canceled)
	_active_dialog.tree_exited.connect(_on_dialog_tree_exited)

	var ui_parent := _get_ui_parent()

	if ui_parent == null:
		push_warning("Bath could not find a UI parent for BathDialog.")
		_active_dialog.queue_free()
		_active_dialog = null
		return

	ui_parent.add_child(_active_dialog)


func _close_bath_dialog() -> void:
	var dialog: Node = _active_dialog
	_active_dialog = null

	if dialog != null and is_instance_valid(dialog):
		if dialog.tree_exited.is_connected(_on_dialog_tree_exited):
			dialog.tree_exited.disconnect(_on_dialog_tree_exited)

		dialog.queue_free()

	_clear_modal_state()


func _apply_bath_effects() -> void:
	var player_stats := _get_player_stats()
	var restored_hygiene := 0
	var soap_bonus_hygiene := 0

	if player_stats != null:
		if player_stats.has_method("consume_soap_bath_bonus"):
			soap_bonus_hygiene = int(player_stats.consume_soap_bath_bonus())

		if player_stats.has_method("restore_hygiene"):
			restored_hygiene = player_stats.restore_hygiene(
				int(player_stats.bath_hygiene_restore_amount) + soap_bonus_hygiene,
				&"bath"
			)

	if PlayerBodyState != null and PlayerBodyState.has_method("wash_body"):
		PlayerBodyState.wash_body(true)

	var hud := _find_hud()

	if hud != null and hud.has_method("advance_time_by_minutes"):
		hud.advance_time_by_minutes(BATH_DURATION_MINUTES)
	else:
		GameTime.advance_minutes(BATH_DURATION_MINUTES)

	if PlayerMentalState != null and PlayerMentalState.has_method("apply_event"):
		var hygiene_multiplier := clampf(float(max(1, restored_hygiene)) / 45.0, 0.75, 1.6)
		PlayerMentalState.apply_event(&"bath_completed", {
			"source": "bath",
			"multiplier": hygiene_multiplier,
			"modifier_scale": hygiene_multiplier,
			"restored_hygiene": restored_hygiene,
		})

	_show_hud_notification(CLEAN_NOTIFICATION_TEXT if restored_hygiene > 0 else CLEAN_LIGHT_NOTIFICATION_TEXT)


func _build_bath_preview() -> Dictionary:
	var player_stats := _get_player_stats()
	var current_hygiene := 0
	var max_hygiene := 100
	var stage_before_title := "Грязь"
	var stage_after_title := "Чистота"

	if player_stats != null:
		if player_stats.has_method("get_hygiene_value"):
			current_hygiene = int(player_stats.get_hygiene_value())

		if player_stats.has_method("get_max_hygiene_value"):
			max_hygiene = int(player_stats.get_max_hygiene_value())

		if player_stats.has_method("get_hygiene_state"):
			var hygiene_state: Variant = player_stats.get_hygiene_state()

			if hygiene_state is Dictionary:
				stage_before_title = String((hygiene_state as Dictionary).get("title", stage_before_title))

	var finish_absolute_minutes: int = GameTime.get_absolute_minutes() + BATH_DURATION_MINUTES
	var finish_time_data: Dictionary = GameTime.get_time_data_for_absolute(finish_absolute_minutes)
	var hygiene_gain: int = max(0, max_hygiene - current_hygiene)
	var blood_text := "Следы крови: смоет остатки с кожи и ткани."
	var relief_text := "Грязь и липкие следы уйдут почти полностью. После ванны Руне будет легче двигаться и дышать."

	if PlayerBodyState != null and PlayerBodyState.has_method("get_body_state"):
		var body_state: Variant = PlayerBodyState.get_body_state()

		if body_state is Dictionary and int((body_state as Dictionary).get("body_blood", 0)) <= 0:
			blood_text = "Следы крови: заметных пятен сейчас нет."

	if hygiene_gain <= 0:
		relief_text = "Тёплая вода всё равно даст телу короткую передышку, даже если грязи уже почти нет."

	return {
		"bath_duration_minutes": BATH_DURATION_MINUTES,
		"finish_day": int(finish_time_data.get("day", GameTime.get_day())),
		"finish_hour": int(finish_time_data.get("hours", GameTime.get_hours())),
		"finish_minute": int(finish_time_data.get("minutes", GameTime.get_minutes())),
		"hygiene_delta_text": "+%d" % hygiene_gain,
		"stage_before_title": stage_before_title,
		"stage_after_title": stage_after_title,
		"blood_text": blood_text,
		"relief_text": relief_text,
	}
