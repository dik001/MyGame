extends Control

signal close_requested()
signal return_to_freelance_requested()
signal session_finished(result: Dictionary)

const COMMENTS_TEMPLATE_PATH := "res://resources/freelance/moderation_comments_template.json"

# Readable tuning constants for the moderation sprint.
const BASE_TIME_PER_COMMENT_BY_DIFFICULTY := {
	"easy": 3.2,
	"medium": 2.4,
	"hard": 1.7,
}
const COMMENT_COUNT_BY_DIFFICULTY := {
	"easy": 7,
	"medium": 12,
	"hard": 17,
}
const URGENT_TIME_MULTIPLIER: float = 0.8
const PRESSURE_START_RATIO: float = 0.35
const PRESSURE_PULSE_MIN_HZ: float = 2.0
const PRESSURE_PULSE_MAX_HZ: float = 8.0
const WARNING_MAX_ALPHA: float = 0.48
const EYE_STRAIN_BLINK_MIN_INTERVAL: float = 2.6
const EYE_STRAIN_BLINK_MAX_INTERVAL: float = 5.0
const EYE_STRAIN_BLINK_MIN_DURATION: float = 0.06
const EYE_STRAIN_BLINK_MAX_DURATION: float = 0.12
const EYE_STRAIN_BLINK_ALPHA: float = 0.78

const EMERGENCY_FALLBACK_COMMENTS := [
	{
		"text": "Спасибо за стрим, было полезно!",
		"category": "safe",
		"should_reject": false,
		"tags": ["positive", "stream"],
	},
	{
		"text": "Нравится формат, продолжай так же.",
		"category": "safe",
		"should_reject": false,
		"tags": ["positive"],
	},
	{
		"text": "Ребята, держите тему обсуждения, пожалуйста.",
		"category": "safe",
		"should_reject": false,
		"tags": ["chat"],
	},
	{
		"text": "Забирай халяву по ссылке в профиле прямо сейчас!",
		"category": "spam",
		"should_reject": true,
		"tags": ["promo", "spam"],
	},
	{
		"text": "Ты вообще бесполезный, выключай уже эфир.",
		"category": "abuse",
		"should_reject": true,
		"tags": ["toxicity"],
	},
	{
		"text": "Переходи в мой канал, там всё лучше и без правил.",
		"category": "spam",
		"should_reject": true,
		"tags": ["promo"],
	},
	{
		"text": "Можно потом таймкоды по ключевым моментам?",
		"category": "safe",
		"should_reject": false,
		"tags": ["question"],
	},
	{
		"text": "С такими руками тебе только чат читать.",
		"category": "abuse",
		"should_reject": true,
		"tags": ["insult"],
	},
	{
		"text": "Кто-нибудь знает, где был прошлый выпуск?",
		"category": "safe",
		"should_reject": false,
		"tags": ["question"],
	},
	{
		"text": "Срочно напиши мне в личку, дам схему заработка.",
		"category": "spam",
		"should_reject": true,
		"tags": ["scam"],
	},
]

const AVATAR_SYMBOLS := ["A", "K", "M", "P", "R", "S", "T", "V", "X", "Y"]
const AVATAR_COLORS := [
	Color(0.23, 0.47, 0.72, 1.0),
	Color(0.21, 0.62, 0.52, 1.0),
	Color(0.71, 0.34, 0.30, 1.0),
	Color(0.62, 0.51, 0.22, 1.0),
	Color(0.48, 0.36, 0.68, 1.0),
	Color(0.21, 0.54, 0.67, 1.0),
]

@onready var order_title_label: Label = $MainPanel/MarginContainer/Content/HeaderRow/OrderTitleLabel
@onready var progress_label: Label = $MainPanel/MarginContainer/Content/HeaderRow/ProgressLabel
@onready var accuracy_label: Label = $MainPanel/MarginContainer/Content/HeaderRow/AccuracyLabel
@onready var avatar_holder: PanelContainer = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/AvatarColumn/AvatarHolder
@onready var avatar_label: Label = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/AvatarColumn/AvatarHolder/AvatarLabel
@onready var avatar_tag_label: Label = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/AvatarColumn/AvatarTagLabel
@onready var comment_text_label: Label = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/CommentColumn/CommentTextLabel
@onready var timer_value_label: Label = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/CommentColumn/TimerRow/TimerHeaderRow/TimerValueLabel
@onready var timer_bar: ProgressBar = $MainPanel/MarginContainer/Content/CommentPanel/MarginContainer/CommentContent/CommentColumn/TimerRow/TimerBar
@onready var warning_flash: ColorRect = $MainPanel/MarginContainer/Content/CommentPanel/WarningFlash
@onready var black_blink: ColorRect = $MainPanel/MarginContainer/Content/CommentPanel/BlackBlink
@onready var approve_button: Button = $MainPanel/MarginContainer/Content/ButtonsRow/ApproveButton
@onready var reject_button: Button = $MainPanel/MarginContainer/Content/ButtonsRow/RejectButton
@onready var hint_label: Label = $MainPanel/MarginContainer/Content/FooterRow/HintLabel
@onready var cancel_button: Button = $MainPanel/MarginContainer/Content/FooterRow/CancelButton
@onready var result_popup: Control = $FreelanceResultPopup

var _rng := RandomNumberGenerator.new()
var _freelance_state: Node = null
var _order_id: int = -1
var _order_data: Dictionary = {}
var _comments_pool: Array[Dictionary] = []
var _run_comments: Array[Dictionary] = []
var _current_comment: Dictionary = {}
var _current_comment_index: int = -1
var _correct_count: int = 0
var _wrong_count: int = 0
var _processed_count: int = 0
var _time_per_comment: float = 0.0
var _time_remaining: float = 0.0
var _pressure_elapsed: float = 0.0
var _session_active: bool = false
var _session_completed: bool = false
var _error_state: bool = false
var _eye_strain_enabled: bool = false
var _blink_time_remaining: float = 0.0
var _next_blink_in: float = 0.0
var _last_result: Dictionary = {}


func _ready() -> void:
	visible = false
	set_process(false)
	_rng.randomize()
	timer_bar.max_value = 1.0

	if not approve_button.pressed.is_connected(_on_approve_button_pressed):
		approve_button.pressed.connect(_on_approve_button_pressed)

	if not reject_button.pressed.is_connected(_on_reject_button_pressed):
		reject_button.pressed.connect(_on_reject_button_pressed)

	if not cancel_button.pressed.is_connected(_on_cancel_button_pressed):
		cancel_button.pressed.connect(_on_cancel_button_pressed)

	if not result_popup.continue_requested.is_connected(_on_result_popup_continue_requested):
		result_popup.continue_requested.connect(_on_result_popup_continue_requested)

	_apply_idle_view()


func open_window() -> void:
	visible = true

	if _session_active:
		approve_button.grab_focus()
	else:
		cancel_button.grab_focus()


func close_window() -> void:
	visible = false
	result_popup.close_popup()
	_stop_session_timers()


func start_for_order(order_id: int) -> void:
	if not is_node_ready():
		call_deferred("start_for_order", order_id)
		return

	visible = true
	_reset_run_state()
	_order_id = order_id
	_resolve_freelance_state()

	if _freelance_state == null:
		_show_error_state("FreelanceState недоступен. Вернитесь в приложение фриланса.")
		return

	if not _freelance_state.has_method("get_order_by_id"):
		_show_error_state("FreelanceState не умеет выдавать данные заказа.")
		return

	var order_variant: Variant = _freelance_state.call("get_order_by_id", order_id)

	if not (order_variant is Dictionary):
		_show_error_state("Не удалось загрузить заказ.")
		return

	_order_data = (order_variant as Dictionary).duplicate(true)

	if _order_data.is_empty():
		_show_error_state("Заказ не найден или уже недоступен.")
		return

	if not _ensure_order_started():
		return

	_comments_pool = _load_comment_pool()
	_run_comments = _build_run_comments(_resolve_comment_count(_order_data))

	if _run_comments.is_empty():
		_show_error_state("Не удалось подготовить набор комментариев для модерации.")
		return

	_begin_session()


func _process(delta: float) -> void:
	if not _session_active:
		return

	_time_remaining = maxf(0.0, _time_remaining - delta)
	_pressure_elapsed += delta
	_update_timer_visuals()
	_update_eye_strain(delta)

	if _time_remaining <= 0.0:
		_handle_timeout()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if result_popup.visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		_handle_cancel_request()
		get_viewport().set_input_as_handled()
		return

	if not _session_active:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_A, KEY_LEFT:
				_submit_answer(false)
				get_viewport().set_input_as_handled()
			KEY_D, KEY_RIGHT:
				_submit_answer(true)
				get_viewport().set_input_as_handled()


func _resolve_freelance_state() -> void:
	_freelance_state = get_node_or_null("/root/FreelanceState")


func _reset_run_state() -> void:
	result_popup.close_popup()
	_stop_session_timers()
	_order_data.clear()
	_comments_pool.clear()
	_run_comments.clear()
	_current_comment.clear()
	_current_comment_index = -1
	_correct_count = 0
	_wrong_count = 0
	_processed_count = 0
	_time_per_comment = 0.0
	_time_remaining = 0.0
	_pressure_elapsed = 0.0
	_session_active = false
	_session_completed = false
	_error_state = false
	_eye_strain_enabled = false
	_last_result.clear()
	_apply_idle_view()


func _apply_idle_view() -> void:
	order_title_label.text = "Модерация комментариев"
	progress_label.text = "0 / 0"
	accuracy_label.text = "Точность: --"
	comment_text_label.text = "Подготовка заказа..."
	timer_value_label.text = "0.0с"
	timer_bar.value = 0.0
	hint_label.text = "A или ←: одобрить. D или →: отклонить."
	cancel_button.text = "Назад"
	approve_button.disabled = true
	reject_button.disabled = true
	_set_warning_strength(0.0)
	_set_black_blink_strength(0.0)
	_apply_avatar_style("?", AVATAR_COLORS[0])
	avatar_tag_label.text = "Ожидание"
	_set_timer_fill_color(Color(0.36, 0.80, 0.55, 1.0))


func _show_error_state(message: String) -> void:
	_session_active = false
	_session_completed = false
	_error_state = true
	_stop_session_timers()
	order_title_label.text = "Ошибка заказа"
	progress_label.text = "-- / --"
	accuracy_label.text = "Точность: --"
	comment_text_label.text = message
	timer_value_label.text = "--"
	timer_bar.value = 0.0
	hint_label.text = "Можно безопасно вернуться в окно фриланса."
	cancel_button.text = "Назад"
	approve_button.disabled = true
	reject_button.disabled = true
	_set_warning_strength(0.0)
	_set_black_blink_strength(0.0)
	_apply_avatar_style("!", Color(0.60, 0.20, 0.20, 1.0))
	avatar_tag_label.text = "Ошибка"
	cancel_button.grab_focus()


func _ensure_order_started() -> bool:
	var status: String = String(_order_data.get("status", ""))
	var is_started: bool = bool(_order_data.get("is_started", false))

	if status != "available":
		_show_error_state("Этот заказ уже завершён и не может быть запущен повторно.")
		return false

	if is_started:
		return true

	if _freelance_state == null or not _freelance_state.has_method("start_order"):
		_show_error_state("FreelanceState не поддерживает запуск заказов.")
		return false

	var start_variant: Variant = _freelance_state.call("start_order", _order_id)

	if not (start_variant is Dictionary):
		_show_error_state("Не удалось начать заказ.")
		return false

	var start_result: Dictionary = start_variant as Dictionary

	if bool(start_result.get("success", false)):
		var started_order: Variant = start_result.get("order", null)

		if started_order is Dictionary:
			_order_data = (started_order as Dictionary).duplicate(true)

		return true

	if String(start_result.get("error", "")) == "order_already_started":
		_order_data["is_started"] = true
		return true

	_show_error_state(String(start_result.get("message", "Не удалось начать заказ.")))
	return false


func _load_comment_pool() -> Array[Dictionary]:
	var normalized_comments: Array[Dictionary] = []
	var loaded_comments: Array = ModerationCommentsLoader.load_comments(COMMENTS_TEMPLATE_PATH)

	for entry_variant in loaded_comments:
		if not (entry_variant is Dictionary):
			continue

		var normalized_entry: Dictionary = ModerationCommentsLoader.normalize_comment_entry(entry_variant)

		if normalized_entry.is_empty():
			continue

		normalized_comments.append(normalized_entry)

	if normalized_comments.is_empty():
		for fallback_entry in EMERGENCY_FALLBACK_COMMENTS:
			normalized_comments.append(fallback_entry.duplicate(true))

	return normalized_comments


func _resolve_comment_count(order: Dictionary) -> int:
	var explicit_count: int = int(order.get("comment_count", 0))

	if explicit_count > 0:
		return explicit_count

	var difficulty: String = String(order.get("difficulty", "easy"))
	return int(COMMENT_COUNT_BY_DIFFICULTY.get(difficulty, COMMENT_COUNT_BY_DIFFICULTY["easy"]))


func _build_run_comments(comment_count: int) -> Array[Dictionary]:
	var total_count: int = max(1, comment_count)
	var source_pool: Array[Dictionary] = []
	var unique_selection: Array[Dictionary] = []
	var seen_texts: Dictionary = {}

	for entry in _comments_pool:
		source_pool.append(entry.duplicate(true))

	if source_pool.is_empty():
		for fallback_entry in EMERGENCY_FALLBACK_COMMENTS:
			source_pool.append(fallback_entry.duplicate(true))

	source_pool.shuffle()

	for entry in source_pool:
		var text: String = String(entry.get("text", "")).strip_edges()

		if text.is_empty():
			continue

		if seen_texts.has(text):
			continue

		seen_texts[text] = true
		unique_selection.append(entry.duplicate(true))

		if unique_selection.size() >= min(total_count, source_pool.size()):
			break

	_ensure_comment_variety(unique_selection, source_pool)

	while unique_selection.size() < total_count and not source_pool.is_empty():
		var reused_entry: Dictionary = source_pool[_rng.randi_range(0, source_pool.size() - 1)]
		unique_selection.append(reused_entry.duplicate(true))

	unique_selection.shuffle()
	return unique_selection


func _ensure_comment_variety(selection: Array[Dictionary], source_pool: Array[Dictionary]) -> void:
	if selection.size() < 2:
		return

	var source_has_safe: bool = false
	var source_has_reject: bool = false

	for entry in source_pool:
		if bool(entry.get("should_reject", false)):
			source_has_reject = true
		else:
			source_has_safe = true

	var selection_has_safe: bool = false
	var selection_has_reject: bool = false

	for entry in selection:
		if bool(entry.get("should_reject", false)):
			selection_has_reject = true
		else:
			selection_has_safe = true

	if not (source_has_safe and source_has_reject):
		return

	if selection_has_safe and selection_has_reject:
		return

	var missing_reject_value: bool = selection_has_safe and not selection_has_reject

	for source_entry in source_pool:
		if bool(source_entry.get("should_reject", false)) != missing_reject_value:
			continue

		selection[selection.size() - 1] = source_entry.duplicate(true)
		return


func _begin_session() -> void:
	_error_state = false
	_session_active = true
	_session_completed = false
	_eye_strain_enabled = _freelance_state != null \
		and _freelance_state.has_method("has_condition") \
		and bool(_freelance_state.call("has_condition", &"eye_strain"))
	_next_blink_in = _roll_blink_interval()
	_blink_time_remaining = 0.0
	approve_button.disabled = false
	reject_button.disabled = false
	cancel_button.disabled = false
	cancel_button.text = "Сдаться"
	hint_label.text = "A или ←: одобрить. D или →: отклонить. Сдаться = провал заказа."
	order_title_label.text = String(_order_data.get("title", "Модерация комментариев"))
	avatar_tag_label.text = "Чат"
	set_process(true)
	_show_comment(0)
	approve_button.grab_focus()


func _show_comment(comment_index: int) -> void:
	if comment_index < 0 or comment_index >= _run_comments.size():
		_finish_session()
		return

	_current_comment_index = comment_index
	_current_comment = _run_comments[comment_index].duplicate(true)
	_time_per_comment = _resolve_time_per_comment(_order_data)
	_time_remaining = _time_per_comment
	_pressure_elapsed = 0.0
	comment_text_label.text = String(_current_comment.get("text", ""))
	_update_progress_labels()
	_update_timer_visuals()
	_apply_random_avatar()


func _resolve_time_per_comment(order: Dictionary) -> float:
	var difficulty: String = String(order.get("difficulty", "easy"))
	var base_time: float = float(BASE_TIME_PER_COMMENT_BY_DIFFICULTY.get(difficulty, BASE_TIME_PER_COMMENT_BY_DIFFICULTY["easy"]))

	if bool(order.get("is_urgent", false)):
		base_time *= URGENT_TIME_MULTIPLIER

	return maxf(0.8, base_time)


func _update_progress_labels() -> void:
	var total_count: int = _run_comments.size()
	var current_number: int = clampi(_current_comment_index + 1, 0, max(1, total_count))
	progress_label.text = "%d / %d" % [current_number, total_count]

	if _processed_count <= 0:
		accuracy_label.text = "Точность: --"
	else:
		accuracy_label.text = "Точность: %d%%" % int(round(_get_accuracy() * 100.0))


func _update_timer_visuals() -> void:
	var fill_ratio: float = 0.0

	if _time_per_comment > 0.0:
		fill_ratio = clampf(_time_remaining / _time_per_comment, 0.0, 1.0)

	timer_bar.value = fill_ratio
	timer_value_label.text = "%.1fс" % _time_remaining

	var pressure_ratio: float = 0.0

	if fill_ratio <= PRESSURE_START_RATIO:
		pressure_ratio = 1.0 - (fill_ratio / PRESSURE_START_RATIO)

	var pulse_speed: float = lerpf(PRESSURE_PULSE_MIN_HZ, PRESSURE_PULSE_MAX_HZ, pressure_ratio)
	var pulse: float = (sin(_pressure_elapsed * TAU * pulse_speed) + 1.0) * 0.5
	_set_warning_strength(pressure_ratio * (0.40 + (pulse * 0.60)))
	_update_timer_theme(fill_ratio)


func _update_timer_theme(fill_ratio: float) -> void:
	var fill_color: Color = Color(0.36, 0.80, 0.55, 1.0)

	if fill_ratio <= PRESSURE_START_RATIO:
		fill_color = Color(0.95, 0.30, 0.30, 1.0)
	elif fill_ratio <= 0.60:
		fill_color = Color(0.93, 0.69, 0.27, 1.0)

	_set_timer_fill_color(fill_color)


func _set_timer_fill_color(fill_color: Color) -> void:
	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_detail = 1
	fill_style.anti_aliasing = false
	timer_bar.add_theme_stylebox_override("fill", fill_style)


func _set_warning_strength(strength: float) -> void:
	var clamped_strength: float = clampf(strength, 0.0, 1.0)
	var flash_color: Color = warning_flash.color
	flash_color.a = clamped_strength * WARNING_MAX_ALPHA
	warning_flash.color = flash_color


func _set_black_blink_strength(strength: float) -> void:
	var clamped_strength: float = clampf(strength, 0.0, 1.0)
	var blink_color: Color = black_blink.color
	blink_color.a = clamped_strength * EYE_STRAIN_BLINK_ALPHA
	black_blink.color = blink_color


func _apply_random_avatar() -> void:
	var avatar_symbol: String = AVATAR_SYMBOLS[_rng.randi_range(0, AVATAR_SYMBOLS.size() - 1)]
	var avatar_color: Color = AVATAR_COLORS[_rng.randi_range(0, AVATAR_COLORS.size() - 1)]
	_apply_avatar_style(avatar_symbol, avatar_color)


func _apply_avatar_style(symbol: String, color: Color) -> void:
	avatar_label.text = symbol
	var avatar_style := StyleBoxFlat.new()
	avatar_style.bg_color = color
	avatar_style.border_width_left = 2
	avatar_style.border_width_top = 2
	avatar_style.border_width_right = 2
	avatar_style.border_width_bottom = 2
	avatar_style.border_color = color.lightened(0.25)
	avatar_style.corner_detail = 1
	avatar_style.anti_aliasing = false
	avatar_holder.add_theme_stylebox_override("panel", avatar_style)


func _update_eye_strain(delta: float) -> void:
	if not _eye_strain_enabled:
		_set_black_blink_strength(0.0)
		return

	if _blink_time_remaining > 0.0:
		_blink_time_remaining = maxf(0.0, _blink_time_remaining - delta)
		_set_black_blink_strength(1.0)
		return

	_set_black_blink_strength(0.0)
	_next_blink_in = maxf(0.0, _next_blink_in - delta)

	if _next_blink_in > 0.0:
		return

	_blink_time_remaining = _rng.randf_range(EYE_STRAIN_BLINK_MIN_DURATION, EYE_STRAIN_BLINK_MAX_DURATION)
	_next_blink_in = _roll_blink_interval()


func _roll_blink_interval() -> float:
	return _rng.randf_range(EYE_STRAIN_BLINK_MIN_INTERVAL, EYE_STRAIN_BLINK_MAX_INTERVAL)


func _handle_timeout() -> void:
	if not _session_active:
		return

	_register_answer(false, true)


func _submit_answer(should_reject: bool) -> void:
	if not _session_active or _current_comment.is_empty():
		return

	_register_answer(should_reject, false)


func _register_answer(should_reject: bool, timed_out: bool) -> void:
	var correct_reject_value: bool = bool(_current_comment.get("should_reject", false))
	var is_correct: bool = (not timed_out) and should_reject == correct_reject_value

	_processed_count += 1

	if is_correct:
		_correct_count += 1
	else:
		_wrong_count += 1

	if _processed_count >= _run_comments.size():
		_finish_session()
		return

	_show_comment(_current_comment_index + 1)


func _finish_session() -> void:
	if _session_completed:
		return

	_session_active = false
	_session_completed = true
	approve_button.disabled = true
	reject_button.disabled = true
	cancel_button.disabled = true
	_stop_session_timers()
	progress_label.text = "%d / %d" % [_run_comments.size(), _run_comments.size()]
	accuracy_label.text = "Точность: %d%%" % int(round(_get_accuracy() * 100.0))

	var accuracy: float = _get_accuracy()
	var final_result: Dictionary = _resolve_authoritative_result(accuracy)

	if not bool(final_result.get("success", false)):
		_show_error_state(String(final_result.get("message", "Не удалось завершить заказ.")))
		return

	_last_result = final_result.duplicate(true)
	result_popup.open_popup(_last_result)


func _resolve_authoritative_result(accuracy: float) -> Dictionary:
	if _freelance_state == null:
		return {
			"success": false,
			"message": "FreelanceState пропал во время завершения заказа.",
		}

	var force_fail: bool = accuracy < 0.60
	var result_variant: Variant = null

	if force_fail:
		if not _freelance_state.has_method("fail_order"):
			return {
				"success": false,
				"message": "FreelanceState не поддерживает провал заказа.",
			}

		result_variant = _freelance_state.call("fail_order", _order_id)
	else:
		if not _freelance_state.has_method("finish_order"):
			return {
				"success": false,
				"message": "FreelanceState не поддерживает завершение заказа.",
			}

		result_variant = _freelance_state.call("finish_order", _order_id, accuracy)

	if result_variant is Dictionary:
		var result_dict: Dictionary = result_variant as Dictionary

		if bool(result_dict.get("success", false)):
			return result_dict.duplicate(true)

		return {
			"success": false,
			"message": String(result_dict.get("message", "FreelanceState вернул ошибку при завершении заказа.")),
		}

	return {
		"success": false,
		"message": "FreelanceState вернул некорректный ответ при завершении заказа.",
	}


func _get_accuracy() -> float:
	if _run_comments.is_empty():
		return 0.0

	return clampf(float(_correct_count) / float(_run_comments.size()), 0.0, 1.0)


func _handle_cancel_request() -> void:
	if _error_state or (not _session_active and not _session_completed):
		close_requested.emit()
		return

	# Active cancellation always counts as failure so we never leave a started
	# order hanging in FreelanceState without an authoritative result.
	if _session_active and not _session_completed:
		abort_as_fail()


func abort_as_fail() -> void:
	if not _session_active:
		return

	_processed_count = _run_comments.size()
	_wrong_count = _run_comments.size() - _correct_count
	comment_text_label.text = "Заказ был прерван. Это считается провалом."
	_finish_session()


func _stop_session_timers() -> void:
	set_process(false)
	_set_warning_strength(0.0)
	_set_black_blink_strength(0.0)


func _on_approve_button_pressed() -> void:
	_submit_answer(false)


func _on_reject_button_pressed() -> void:
	_submit_answer(true)


func _on_cancel_button_pressed() -> void:
	_handle_cancel_request()


func _on_result_popup_continue_requested() -> void:
	result_popup.close_popup()
	session_finished.emit(_last_result.duplicate(true))
	return_to_freelance_requested.emit()
