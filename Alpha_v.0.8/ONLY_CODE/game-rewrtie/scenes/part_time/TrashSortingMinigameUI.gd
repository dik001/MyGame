class_name TrashSortingMinigameUI
extends Control

signal finished(result: Dictionary)

const PART_TIME_CONFIG = preload("res://scenes/part_time/CashierPartTimeConfig.gd")

@onready var title_label: Label = $Background/MainPanel/MarginContainer/Content/HeaderRow/TitleLabel
@onready var progress_label: Label = $Background/MainPanel/MarginContainer/Content/HeaderRow/ProgressLabel
@onready var mistakes_label: Label = $Background/MainPanel/MarginContainer/Content/HeaderRow/MistakesLabel
@onready var item_icon: TextureRect = $Background/MainPanel/MarginContainer/Content/BodyRow/ItemPanel/MarginContainer/ItemContent/ItemIcon
@onready var item_name_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/ItemPanel/MarginContainer/ItemContent/ItemNameLabel
@onready var timer_value_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/ItemPanel/MarginContainer/ItemContent/TimerRow/TimerHeaderRow/TimerValueLabel
@onready var timer_bar: ProgressBar = $Background/MainPanel/MarginContainer/Content/BodyRow/ItemPanel/MarginContainer/ItemContent/TimerRow/TimerBar
@onready var shift_info_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/SummaryPanel/MarginContainer/SummaryContent/ShiftInfoLabel
@onready var processed_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/SummaryPanel/MarginContainer/SummaryContent/ProcessedLabel
@onready var remaining_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/SummaryPanel/MarginContainer/SummaryContent/RemainingLabel
@onready var time_window_label: Label = $Background/MainPanel/MarginContainer/Content/BodyRow/SummaryPanel/MarginContainer/SummaryContent/TimeWindowLabel
@onready var bins_title_label: Label = $Background/MainPanel/MarginContainer/Content/BinsTitleLabel
@onready var glass_button: Button = $Background/MainPanel/MarginContainer/Content/BinsRow/GlassButton
@onready var plastic_button: Button = $Background/MainPanel/MarginContainer/Content/BinsRow/PlasticButton
@onready var paper_button: Button = $Background/MainPanel/MarginContainer/Content/BinsRow/PaperButton
@onready var feedback_label: Label = $Background/MainPanel/MarginContainer/Content/FooterLabel
@onready var result_overlay: Control = $ResultOverlay
@onready var result_title_label: Label = $ResultOverlay/CenterContainer/PanelContainer/MarginContainer/Content/ResultTitleLabel
@onready var result_status_label: Label = $ResultOverlay/CenterContainer/PanelContainer/MarginContainer/Content/ResultStatusLabel
@onready var result_summary_label: Label = $ResultOverlay/CenterContainer/PanelContainer/MarginContainer/Content/ResultSummaryLabel
@onready var result_reward_label: Label = $ResultOverlay/CenterContainer/PanelContainer/MarginContainer/Content/ResultRewardLabel
@onready var result_continue_button: Button = $ResultOverlay/CenterContainer/PanelContainer/MarginContainer/Content/ContinueButton

var _rng := RandomNumberGenerator.new()
var _run_items: Array[Dictionary] = []
var _current_item: Dictionary = {}
var _processed_count := 0
var _mistake_count := 0
var _timeout_count := 0
var _time_remaining := 0.0
var _session_active := false
var _final_result: Dictionary = {}


func _ready() -> void:
	visible = false
	result_overlay.visible = false
	set_process(false)
	_rng.randomize()
	timer_bar.max_value = PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS

	if not glass_button.pressed.is_connected(_on_glass_button_pressed):
		glass_button.pressed.connect(_on_glass_button_pressed)

	if not plastic_button.pressed.is_connected(_on_plastic_button_pressed):
		plastic_button.pressed.connect(_on_plastic_button_pressed)

	if not paper_button.pressed.is_connected(_on_paper_button_pressed):
		paper_button.pressed.connect(_on_paper_button_pressed)

	if not result_continue_button.pressed.is_connected(_on_result_continue_button_pressed):
		result_continue_button.pressed.connect(_on_result_continue_button_pressed)

	_apply_static_content()
	_apply_idle_view()


func open_window() -> void:
	visible = true

	if not _session_active and _final_result.is_empty():
		start_session()


func close_window() -> void:
	visible = false
	set_process(false)


func start_session() -> void:
	_rng.randomize()
	_run_items = PART_TIME_CONFIG.build_shift_items(_rng)
	_current_item.clear()
	_processed_count = 0
	_mistake_count = 0
	_timeout_count = 0
	_time_remaining = PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS
	_session_active = true
	_final_result.clear()
	result_overlay.visible = false
	feedback_label.text = "1/A - стекло, 2/S - пластик, 3/D - бумага."
	set_process(true)
	_update_header()
	_advance_to_next_item()


func force_close() -> void:
	if _session_active and CashierPartTimeState != null and CashierPartTimeState.has_method("interrupt_shift"):
		CashierPartTimeState.interrupt_shift(&"forced_close")

	_session_active = false
	_final_result.clear()
	set_process(false)
	visible = false


func _process(delta: float) -> void:
	if not _session_active:
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_update_timer_visuals()

	if _time_remaining <= 0.0:
		_submit_answer(&"", true)


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("pause_menu") and not event.is_echo():
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		if result_overlay.visible:
			_emit_finished()

		get_viewport().set_input_as_handled()
		return

	if result_overlay.visible:
		if event.is_action_pressed("ui_accept") and not event.is_echo():
			_emit_finished()
			get_viewport().set_input_as_handled()

		return

	if not _session_active:
		return

	var key_event: InputEventKey = event as InputEventKey

	if key_event == null or not key_event.pressed or key_event.echo:
		return

	if key_event.is_action_pressed("trash_sort_glass") or _matches_key(key_event, KEY_1):
		_submit_answer(&"glass")
		get_viewport().set_input_as_handled()
		return

	if key_event.is_action_pressed("trash_sort_plastic") or _matches_key(key_event, KEY_2):
		_submit_answer(&"plastic")
		get_viewport().set_input_as_handled()
		return

	if key_event.is_action_pressed("trash_sort_paper") or _matches_key(key_event, KEY_3):
		_submit_answer(&"paper")
		get_viewport().set_input_as_handled()


func _exit_tree() -> void:
	if _session_active and CashierPartTimeState != null and CashierPartTimeState.has_method("interrupt_shift"):
		CashierPartTimeState.interrupt_shift(&"ui_destroyed")


func _apply_static_content() -> void:
	title_label.text = "Подработка: сортировка мусора"
	bins_title_label.text = "Отправь мусор в правильный ящик"
	shift_info_label.text = "Смена: 30 предметов, максимум 3 ошибки."
	time_window_label.text = "На предмет: %.2f с" % PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS
	result_continue_button.text = "Продолжить"

	var bins: Array[Dictionary] = PART_TIME_CONFIG.get_bin_definitions()
	var buttons: Array[Button] = [glass_button, plastic_button, paper_button]

	for index in range(min(buttons.size(), bins.size())):
		var button: Button = buttons[index]
		var bin_definition: Dictionary = bins[index]
		button.text = "%s\n%s" % [
			String(bin_definition.get("label", "")),
			String(bin_definition.get("hint", "")),
		]
		button.icon = PART_TIME_CONFIG.load_texture(String(bin_definition.get("icon_path", "")))


func _apply_idle_view() -> void:
	item_name_label.text = "Подготовка смены..."
	item_icon.texture = null
	timer_value_label.text = "--"
	progress_label.text = "0 / %d" % PART_TIME_CONFIG.TARGET_ITEM_COUNT
	mistakes_label.text = "Ошибки: 0 / %d" % PART_TIME_CONFIG.MAX_MISTAKES
	processed_label.text = "Обработано: 0 / %d" % PART_TIME_CONFIG.TARGET_ITEM_COUNT
	remaining_label.text = "Осталось: %d" % PART_TIME_CONFIG.TARGET_ITEM_COUNT
	timer_bar.value = PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS
	feedback_label.text = "1/A - стекло, 2/S - пластик, 3/D - бумага."


func _advance_to_next_item() -> void:
	if _processed_count >= PART_TIME_CONFIG.TARGET_ITEM_COUNT:
		_finish_session(true, &"completed")
		return

	if _run_items.is_empty():
		_finish_session(false, &"missing_catalog")
		return

	_current_item = _run_items[_processed_count].duplicate(true)
	_time_remaining = PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS
	item_name_label.text = String(_current_item.get("display_name", "Неизвестный предмет"))
	item_icon.texture = PART_TIME_CONFIG.load_texture(String(_current_item.get("icon_path", "")))
	_update_header()
	_update_timer_visuals()
	glass_button.grab_focus()


func _submit_answer(category: StringName, timed_out := false) -> void:
	if not _session_active:
		return

	var item_category: StringName = StringName(String(_current_item.get("category", "")).strip_edges())
	var is_correct: bool = not timed_out and category == item_category
	_processed_count += 1

	if is_correct:
		feedback_label.text = "Верно. Дальше."
	else:
		_mistake_count += 1
		feedback_label.text = "Время вышло. Ошибка." if timed_out else "Промах. Ошибка."

		if timed_out:
			_timeout_count += 1

	_update_header()

	if _mistake_count >= PART_TIME_CONFIG.MAX_MISTAKES:
		_finish_session(false, &"mistake_limit")
		return

	if _processed_count >= PART_TIME_CONFIG.TARGET_ITEM_COUNT:
		_finish_session(true, &"completed")
		return

	_advance_to_next_item()


func _finish_session(success: bool, reason: StringName) -> void:
	_session_active = false
	set_process(false)

	var result: Dictionary = {}

	if CashierPartTimeState != null and CashierPartTimeState.has_method("finish_shift"):
		result = CashierPartTimeState.finish_shift(success, reason)

	if result.is_empty():
		result = {
			"success": success,
			"payout": PART_TIME_CONFIG.SUCCESS_PAYOUT if success else 0,
			"time_spent_minutes": PART_TIME_CONFIG.SHIFT_DURATION_MINUTES,
			"title": "Смена завершена" if success else "Смена сорвана",
			"result_status": "completed" if success else "fail",
		}

	result["processed_count"] = _processed_count
	result["mistakes"] = _mistake_count
	result["timeouts"] = _timeout_count
	_final_result = result.duplicate(true)
	_show_result_overlay()


func _show_result_overlay() -> void:
	var success: bool = bool(_final_result.get("success", false))
	var payout: int = int(_final_result.get("payout", 0))
	var processed_count: int = int(_final_result.get("processed_count", 0))
	var mistakes: int = int(_final_result.get("mistakes", 0))
	var timeouts: int = int(_final_result.get("timeouts", 0))

	result_title_label.text = String(_final_result.get("title", "Итог смены"))
	result_status_label.text = PART_TIME_CONFIG.build_result_status_text(success, processed_count, mistakes)
	result_status_label.add_theme_color_override(
		"font_color",
		Color(0.70, 0.95, 0.70, 1.0) if success else Color(1.0, 0.60, 0.60, 1.0)
	)
	result_summary_label.text = "Обработано: %d / %d | Ошибки: %d / %d | Таймауты: %d" % [
		processed_count,
		PART_TIME_CONFIG.TARGET_ITEM_COUNT,
		mistakes,
		PART_TIME_CONFIG.MAX_MISTAKES,
		timeouts,
	]
	result_reward_label.text = "%s\nИгровое время: %d минут" % [
		PART_TIME_CONFIG.build_result_reward_text(payout),
		int(_final_result.get("time_spent_minutes", PART_TIME_CONFIG.SHIFT_DURATION_MINUTES)),
	]
	result_overlay.visible = true
	result_continue_button.grab_focus()


func _update_header() -> void:
	progress_label.text = "%d / %d" % [_processed_count, PART_TIME_CONFIG.TARGET_ITEM_COUNT]
	mistakes_label.text = "Ошибки: %d / %d" % [_mistake_count, PART_TIME_CONFIG.MAX_MISTAKES]
	processed_label.text = "Обработано: %d / %d" % [_processed_count, PART_TIME_CONFIG.TARGET_ITEM_COUNT]
	remaining_label.text = "Осталось: %d" % max(0, PART_TIME_CONFIG.TARGET_ITEM_COUNT - _processed_count)


func _update_timer_visuals() -> void:
	timer_bar.max_value = PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS
	timer_bar.value = clampf(_time_remaining, 0.0, PART_TIME_CONFIG.TIME_PER_ITEM_SECONDS)
	timer_value_label.text = "%.2f с" % _time_remaining

	var warning_color: Color = Color(0.72, 0.92, 1.0, 1.0)

	if _time_remaining <= 0.40:
		warning_color = Color(1.0, 0.56, 0.56, 1.0)

	timer_value_label.add_theme_color_override("font_color", warning_color)


func _matches_key(event: InputEventKey, keycode: Key) -> bool:
	return event.keycode == keycode or event.physical_keycode == keycode


func _emit_finished() -> void:
	if _final_result.is_empty():
		return

	var result: Dictionary = _final_result.duplicate(true)
	_final_result.clear()
	result_overlay.visible = false
	finished.emit(result)


func _on_glass_button_pressed() -> void:
	_submit_answer(&"glass")


func _on_plastic_button_pressed() -> void:
	_submit_answer(&"plastic")


func _on_paper_button_pressed() -> void:
	_submit_answer(&"paper")


func _on_result_continue_button_pressed() -> void:
	_emit_finished()
