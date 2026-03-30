extends CanvasLayer

const HUD_NOTIFICATION_SCENE := preload("res://scenes/ui/HudNotificationToast.tscn")
const DEFAULT_DOLLARS_ICON := preload("res://art/ui/stats/Money.png")
const HUNGER_COLOR_SATED := Color(1.0, 1.0, 1.0, 1.0)
const HUNGER_COLOR_HUNGRY := Color(0.95, 0.81, 0.52, 1.0)
const HUNGER_COLOR_VERY_HUNGRY := Color(1.0, 0.63, 0.33, 1.0)
const HUNGER_COLOR_EXHAUSTED := Color(0.95, 0.42, 0.26, 1.0)
const HUNGER_COLOR_STARVING := Color(0.88, 0.20, 0.20, 1.0)
const MOOD_COLOR_EXCELLENT := Color(0.72, 0.92, 0.55, 1.0)
const MOOD_COLOR_NORMAL := Color(0.96, 0.96, 0.96, 1.0)
const MOOD_COLOR_LOW := Color(1.0, 0.82, 0.46, 1.0)
const MOOD_COLOR_DEPRESSED := Color(0.93, 0.42, 0.42, 1.0)
const STRESS_COLOR_CALM := Color(0.67, 0.91, 0.86, 1.0)
const STRESS_COLOR_TENSE := Color(0.98, 0.84, 0.45, 1.0)
const STRESS_COLOR_HIGH := Color(0.99, 0.62, 0.32, 1.0)
const STRESS_COLOR_PANIC := Color(0.92, 0.28, 0.28, 1.0)

@export var player_path: NodePath
@export var inventory_ui_path: NodePath
@export_range(0, 23) var test_time_hours := 7
@export_range(0, 59) var test_time_minutes := 25
@export var run_test_clock := true
@export_range(0.05, 60.0, 0.05) var seconds_per_game_minute := 1.0
@export var dollars_icon: Texture2D

@onready var root_control: Control = $root
@onready var inventory_shortcut_anchor: Control = $root/InventoryShortcutAnchor
@onready var inventory_shortcut_button: TextureButton = $root/InventoryShortcutAnchor/InventoryShortcutButton
@onready var inventory_shortcut_key_label: Label = $root/InventoryShortcutAnchor/InventoryShortcutKeyPanel/InventoryShortcutKeyLabel
@onready var stats_container: VBoxContainer = $root/MarginContainer/VBoxContainer
@onready var time_widget: TimeWidget = $root/MarginContainer/VBoxContainer/TimeWidget
@onready var health_label: Label = $root/MarginContainer/VBoxContainer/HealthRow/HealthLabel
@onready var hunger_icon: TextureRect = $root/MarginContainer/VBoxContainer/HungerRow/HungerIcon
@onready var hunger_label: Label = $root/MarginContainer/VBoxContainer/HungerRow/HungerLabel
@onready var energy_label: Label = $root/MarginContainer/VBoxContainer/EnergyRow/EnergyLabel
@onready var currency_icon: TextureRect = get_node_or_null("root/MarginContainer/VBoxContainer/CurrencyRow/CurrencyIconPanel/CurrencyIcon") as TextureRect
@onready var currency_fallback_label: Label = get_node_or_null("root/MarginContainer/VBoxContainer/CurrencyRow/CurrencyIconPanel/CurrencyFallbackLabel") as Label
@onready var dollars_label: Label = get_node_or_null("root/MarginContainer/VBoxContainer/CurrencyRow/DollarsLabel") as Label
@onready var interaction_prompt: Control = $root/InteractionPrompt
@onready var interaction_key_label: Label = $root/InteractionPrompt/PromptPanel/PromptRow/KeyPanel/KeyLabel
@onready var interaction_action_label: Label = $root/InteractionPrompt/PromptPanel/PromptRow/ActionLabel

var _player: Node
var _inventory_ui: Node
var _stats: PlayerStatsState
var _interact_key_text := "E"
var _notification_stack: VBoxContainer
var _mood_row: HBoxContainer = null
var _mood_label: Label = null
var _mood_badge_panel: PanelContainer = null
var _mood_badge_label: Label = null
var _stress_row: HBoxContainer = null
var _stress_label: Label = null
var _stress_badge_panel: PanelContainer = null
var _stress_badge_label: Label = null


func _ready() -> void:
	if not is_in_group("hud"):
		add_to_group("hud")

	inventory_shortcut_button.pressed.connect(_on_inventory_shortcut_pressed)
	_refresh_inventory_shortcut_key()
	_resolve_inventory_ui()
	_update_inventory_shortcut_visibility()
	_ensure_notification_stack()
	_configure_clock()
	_connect_time_signals()
	_connect_economy_signals()
	_connect_system_notifications()
	_connect_mental_state_signals()
	_connect_settings_signals()

	if player_path.is_empty():
		push_warning("HUD.player_path is not set.")
		return

	_player = get_node_or_null(player_path)

	if _player == null:
		push_warning("HUD could not find the player node.")
		return

	_interact_key_text = _resolve_action_key_text(&"interact", "E")
	interaction_key_label.text = _interact_key_text
	_set_interaction_prompt_visible(false)

	if not _player.has_method("get_stats_component"):
		push_warning("Player is missing get_stats_component().")
		return

	_stats = _player.get_stats_component()

	if _stats == null:
		push_warning("Player stats component is missing.")
		return

	if not _stats.stats_changed.is_connected(_on_stats_changed):
		_stats.stats_changed.connect(_on_stats_changed)

	if not _stats.critical_energy_state_changed.is_connected(_on_critical_energy_state_changed):
		_stats.critical_energy_state_changed.connect(_on_critical_energy_state_changed)

	if not _stats.sleep_warning_requested.is_connected(_on_sleep_warning_requested):
		_stats.sleep_warning_requested.connect(_on_sleep_warning_requested)

	if not _stats.hunger_warning_requested.is_connected(_on_hunger_warning_requested):
		_stats.hunger_warning_requested.connect(_on_hunger_warning_requested)

	if (
		_stats.has_signal(&"hygiene_warning_requested")
		and not _stats.hygiene_warning_requested.is_connected(_on_hygiene_warning_requested)
	):
		_stats.hygiene_warning_requested.connect(_on_hygiene_warning_requested)

	_on_stats_changed(_stats.get_stats())


func set_time(hours: int, minutes: int) -> void:
	GameTime.set_time(hours, minutes)


func set_total_minutes(total_minutes: int) -> void:
	GameTime.set_absolute_minutes(total_minutes)


func advance_time_by_minutes(minutes: int) -> void:
	GameTime.advance_minutes(minutes)


func set_clock_paused(paused: bool) -> void:
	GameTime.set_clock_paused(paused)


func show_notification(message: String, duration: float = 2.4) -> void:
	var trimmed_message: String = message.strip_edges()

	if trimmed_message.is_empty():
		return

	_ensure_notification_stack()

	if _notification_stack == null:
		return

	var toast := HUD_NOTIFICATION_SCENE.instantiate() as HudNotificationToast

	if toast == null:
		return

	toast.setup(trimmed_message, duration)
	_notification_stack.add_child(toast)


func _on_inventory_shortcut_pressed() -> void:
	if _is_inventory_shortcut_blocked():
		return

	_refresh_inventory_shortcut_key()
	var inventory_ui := _resolve_inventory_ui()

	if inventory_ui == null or not inventory_ui.has_method("open_inventory_tab"):
		push_warning("HUD could not find InventoryUI.")
		return

	inventory_ui.call("open_inventory_tab")


func _process(_delta: float) -> void:
	_update_inventory_shortcut_visibility()
	_update_interaction_prompt()


func _on_stats_changed(current_stats: Dictionary) -> void:
	health_label.text = str(current_stats.get("hp", 0))
	hunger_label.text = str(current_stats.get("hunger", 0))
	energy_label.text = _format_stat_value(current_stats.get("energy", 0.0))
	_refresh_hunger_visuals()


func _on_critical_energy_state_changed(is_critical: bool) -> void:
	if not is_critical:
		return

	show_notification("\u042d\u043d\u0435\u0440\u0433\u0438\u044f \u043a\u0440\u0438\u0442\u0438\u0447\u0435\u0441\u043a\u0438 \u043d\u0438\u0437\u043a\u0430\u044f")


func _on_sleep_warning_requested(message: String, duration: float) -> void:
	show_notification(message, duration)


func _on_hunger_warning_requested(message: String, duration: float) -> void:
	show_notification(message, duration)


func _on_hygiene_warning_requested(message: String, duration: float) -> void:
	show_notification(message, duration)


func _on_mental_state_changed(snapshot: Dictionary) -> void:
	var mood_state := SaveDataUtils.sanitize_dictionary(snapshot.get("mood_state", {}))
	var stress_state := SaveDataUtils.sanitize_dictionary(snapshot.get("stress_state", {}))
	_update_mental_row(
		_mood_label,
		_mood_badge_panel,
		_mood_badge_label,
		"M",
		float(snapshot.get("mood", 0.0)),
		String(mood_state.get("title", "Настроение")),
		_resolve_mood_color(String(mood_state.get("id", "")))
	)
	_update_mental_row(
		_stress_label,
		_stress_badge_panel,
		_stress_badge_label,
		"S",
		float(snapshot.get("stress", 0.0)),
		String(stress_state.get("title", "Стресс")),
		_resolve_stress_color(String(stress_state.get("id", "")))
	)

	if _mood_label != null:
		_mood_label.tooltip_text = String(mood_state.get("description", String(mood_state.get("title", ""))))

	if _stress_label != null:
		_stress_label.tooltip_text = String(stress_state.get("description", String(stress_state.get("title", ""))))


func _on_mental_threshold_crossed(stat_id: StringName, _from_id: StringName, to_id: StringName) -> void:
	if PlayerMentalState == null:
		return

	match stat_id:
		&"mood":
			var mood_state := PlayerMentalState.get_mood_state()
			show_notification("Настроение: %s" % String(mood_state.get("title", String(to_id))))
		&"stress":
			var stress_state := PlayerMentalState.get_stress_state()
			show_notification("Стресс: %s" % String(stress_state.get("title", String(to_id))))
		_:
			pass


func _on_delivery_completed(_delivery_id: int) -> void:
	show_notification("\u0414\u043e\u0441\u0442\u0430\u0432\u043a\u0430 \u043f\u0440\u0438\u0431\u044b\u043b\u0430")


func _on_rent_due_tomorrow() -> void:
	show_notification("\u0410\u0440\u0435\u043d\u0434\u0430 \u0437\u0430\u0432\u0442\u0440\u0430")


func _on_game_time_changed(_absolute_minutes: int, _day: int, hours: int, minutes: int) -> void:
	if time_widget == null:
		return

	time_widget.set_time(hours, minutes)


func _on_cash_dollars_changed(new_value: int) -> void:
	if dollars_label == null:
		return

	dollars_label.text = str(new_value)


func _format_stat_value(value: Variant) -> String:
	if value is float:
		var float_value := float(value)

		if is_equal_approx(float_value, roundf(float_value)):
			return str(int(roundi(float_value)))

		return "%.1f" % float_value

	return str(value)


func _refresh_hunger_visuals() -> void:
	if _stats == null or not _stats.has_method("get_hunger_state"):
		hunger_label.modulate = HUNGER_COLOR_SATED

		if hunger_icon != null:
			hunger_icon.modulate = HUNGER_COLOR_SATED

		return

	var hunger_state: Dictionary = _stats.get_hunger_state()
	var hunger_color: Color = _resolve_hunger_color(
		String(hunger_state.get("stage_id", ""))
	)
	hunger_label.modulate = hunger_color

	if hunger_icon != null:
		hunger_icon.modulate = hunger_color


func _resolve_hunger_color(stage_id: String) -> Color:
	match stage_id:
		"hunger_hungry":
			return HUNGER_COLOR_HUNGRY
		"hunger_very_hungry":
			return HUNGER_COLOR_VERY_HUNGRY
		"hunger_exhausted":
			return HUNGER_COLOR_EXHAUSTED
		"hunger_starving":
			return HUNGER_COLOR_STARVING
		_:
			return HUNGER_COLOR_SATED


func _update_interaction_prompt() -> void:
	if interaction_prompt == null:
		return

	if _player == null:
		_set_interaction_prompt_visible(false)
		return

	if _player.has_method("is_input_locked") and _player.is_input_locked():
		_set_interaction_prompt_visible(false)
		return

	if not _player.has_method("get_nearest_interactable"):
		_set_interaction_prompt_visible(false)
		return

	var interactable = _player.get_nearest_interactable()

	if interactable == null:
		_set_interaction_prompt_visible(false)
		return

	var prompt_text := "ВЗАИМОДЕЙСТВОВАТЬ"

	if interactable.has_method("get_interaction_prompt_text"):
		prompt_text = String(interactable.get_interaction_prompt_text()).strip_edges()

	if prompt_text.is_empty():
		prompt_text = "ВЗАИМОДЕЙСТВОВАТЬ"

	interaction_key_label.text = _interact_key_text
	interaction_action_label.text = "- %s" % prompt_text
	_set_interaction_prompt_visible(true)


func _set_interaction_prompt_visible(visible_state: bool) -> void:
	if interaction_prompt != null:
		interaction_prompt.visible = visible_state


func _refresh_inventory_shortcut_key() -> void:
	if inventory_shortcut_key_label == null:
		return

	inventory_shortcut_key_label.text = _resolve_action_key_text(&"inventory_toggle", "I")


func _update_inventory_shortcut_visibility() -> void:
	if inventory_shortcut_anchor == null:
		return

	inventory_shortcut_anchor.visible = not _is_inventory_shortcut_blocked()


func _is_inventory_shortcut_blocked() -> bool:
	_resolve_inventory_ui()

	if _inventory_ui != null and is_instance_valid(_inventory_ui) and _inventory_ui.visible:
		return true

	if _player != null and _player.has_method("is_input_locked") and _player.is_input_locked():
		return true

	if PhoneManager != null and PhoneManager.has_method("is_phone_open") and PhoneManager.is_phone_open():
		return true

	if DialogueManager != null and DialogueManager.has_method("is_dialogue_visible") and DialogueManager.is_dialogue_visible():
		return true

	return false


func _resolve_action_key_text(action_name: StringName, fallback: String) -> String:
	if GameSettings != null and GameSettings.has_method("get_action_display_text"):
		return GameSettings.get_action_display_text(action_name, fallback)

	for event in InputMap.action_get_events(action_name):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var keycode := key_event.physical_keycode

		if keycode == 0:
			keycode = key_event.keycode

		var key_text := OS.get_keycode_string(keycode)

		if not key_text.is_empty():
			return key_text.to_upper()

	return fallback


func _configure_clock() -> void:
	GameTime.initialize_if_needed(test_time_hours, test_time_minutes)
	GameTime.configure_clock(run_test_clock, seconds_per_game_minute)


func _connect_time_signals() -> void:
	if not GameTime.time_changed.is_connected(_on_game_time_changed):
		GameTime.time_changed.connect(_on_game_time_changed)

	var current_time := GameTime.get_current_time_data()
	_on_game_time_changed(
		int(current_time.get("absolute_minutes", 0)),
		int(current_time.get("day", 1)),
		int(current_time.get("hours", 0)),
		int(current_time.get("minutes", 0))
	)


func _connect_economy_signals() -> void:
	if not PlayerEconomy.cash_dollars_changed.is_connected(_on_cash_dollars_changed):
		PlayerEconomy.cash_dollars_changed.connect(_on_cash_dollars_changed)

	_refresh_currency_icon()
	_on_cash_dollars_changed(PlayerEconomy.get_cash_dollars())


func _connect_system_notifications() -> void:
	if not DeliveryManager.delivery_completed.is_connected(_on_delivery_completed):
		DeliveryManager.delivery_completed.connect(_on_delivery_completed)

	if not ApartmentRentState.rent_due_tomorrow.is_connected(_on_rent_due_tomorrow):
		ApartmentRentState.rent_due_tomorrow.connect(_on_rent_due_tomorrow)


func _connect_mental_state_signals() -> void:
	if PlayerMentalState == null:
		return

	if PlayerMentalState.has_signal(&"mental_state_changed") and not PlayerMentalState.mental_state_changed.is_connected(_on_mental_state_changed):
		PlayerMentalState.mental_state_changed.connect(_on_mental_state_changed)

	if PlayerMentalState.has_signal(&"mental_threshold_crossed") and not PlayerMentalState.mental_threshold_crossed.is_connected(_on_mental_threshold_crossed):
		PlayerMentalState.mental_threshold_crossed.connect(_on_mental_threshold_crossed)

	if PlayerMentalState.has_method("get_state"):
		_on_mental_state_changed(PlayerMentalState.get_state())


func _connect_settings_signals() -> void:
	if GameSettings == null:
		return

	if not GameSettings.settings_changed.is_connected(_on_settings_changed):
		GameSettings.settings_changed.connect(_on_settings_changed)

	_on_settings_changed()


func _refresh_currency_icon() -> void:
	if currency_icon == null:
		return

	var resolved_icon: Texture2D = dollars_icon

	if resolved_icon == null:
		resolved_icon = currency_icon.texture

	if resolved_icon == null:
		resolved_icon = DEFAULT_DOLLARS_ICON

	currency_icon.texture = resolved_icon
	currency_icon.visible = resolved_icon != null

	if currency_fallback_label != null:
		currency_fallback_label.visible = resolved_icon == null


func _on_settings_changed() -> void:
	_refresh_inventory_shortcut_key()
	_interact_key_text = _resolve_action_key_text(&"interact", "E")

	if interaction_key_label != null:
		interaction_key_label.text = _interact_key_text


func _resolve_inventory_ui() -> Node:
	if _inventory_ui != null and is_instance_valid(_inventory_ui):
		return _inventory_ui

	if inventory_ui_path.is_empty():
		return null

	_inventory_ui = get_node_or_null(inventory_ui_path)
	return _inventory_ui


func _ensure_notification_stack() -> void:
	if _notification_stack != null and is_instance_valid(_notification_stack):
		return

	if root_control == null:
		return

	var anchor: MarginContainer = MarginContainer.new()
	anchor.name = "NotificationAnchor"
	anchor.anchor_left = 1.0
	anchor.anchor_top = 0.0
	anchor.anchor_right = 1.0
	anchor.anchor_bottom = 0.0
	anchor.offset_left = -480.0
	anchor.offset_top = 88.0
	anchor.offset_right = -16.0
	anchor.offset_bottom = 372.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_theme_constant_override("margin_left", 0)
	anchor.add_theme_constant_override("margin_top", 0)
	anchor.add_theme_constant_override("margin_right", 0)
	anchor.add_theme_constant_override("margin_bottom", 0)
	root_control.add_child(anchor)

	var stack: VBoxContainer = VBoxContainer.new()
	stack.name = "NotificationStack"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 10)
	anchor.add_child(stack)
	_notification_stack = stack


func _ensure_mental_rows() -> void:
	if stats_container == null or _mood_row != null or _stress_row != null:
		return

	var template_row := stats_container.get_node_or_null("CurrencyRow") as HBoxContainer

	if template_row == null:
		return

	_mood_row = _create_mental_row(template_row, "MoodRow", "M")
	_stress_row = _create_mental_row(template_row, "StressRow", "S")

	if _mood_row != null:
		stats_container.add_child(_mood_row)
		stats_container.move_child(_mood_row, stats_container.get_children().find(template_row))

	if _stress_row != null:
		stats_container.add_child(_stress_row)
		stats_container.move_child(_stress_row, stats_container.get_children().find(template_row))


func _create_mental_row(template_row: HBoxContainer, row_name: String, badge_text: String) -> HBoxContainer:
	var row := template_row.duplicate() as HBoxContainer

	if row == null:
		return null

	row.name = row_name
	var icon_panel := row.get_node_or_null("CurrencyIconPanel") as PanelContainer
	var icon := row.get_node_or_null("CurrencyIconPanel/CurrencyIcon") as TextureRect
	var fallback_label := row.get_node_or_null("CurrencyIconPanel/CurrencyFallbackLabel") as Label
	var value_label := row.get_node_or_null("DollarsLabel") as Label

	if icon != null:
		icon.visible = false
		icon.texture = null

	if icon_panel != null and fallback_label == null:
		fallback_label = Label.new()
		fallback_label.name = "CurrencyFallbackLabel"
		fallback_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		fallback_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		fallback_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		icon_panel.add_child(fallback_label)

	if fallback_label != null:
		fallback_label.visible = true
		fallback_label.text = badge_text
		fallback_label.add_theme_font_size_override("font_size", 22)

	if value_label != null:
		value_label.text = "%s | -" % badge_text

	match row_name:
		"MoodRow":
			_mood_label = value_label
			_mood_badge_panel = icon_panel
			_mood_badge_label = fallback_label
		"StressRow":
			_stress_label = value_label
			_stress_badge_panel = icon_panel
			_stress_badge_label = fallback_label

	return row


func _update_mental_row(
	value_label: Label,
	badge_panel: PanelContainer,
	badge_label: Label,
	badge_text: String,
	current_value: float,
	state_title: String,
	display_color: Color
) -> void:
	if value_label != null:
		value_label.text = "%s %s | %s" % [
			badge_text,
			_format_stat_value(current_value),
			state_title,
		]
		value_label.modulate = display_color

	if badge_panel != null:
		badge_panel.modulate = display_color

	if badge_label != null:
		badge_label.text = badge_text
		badge_label.modulate = display_color


func _resolve_mood_color(state_id: String) -> Color:
	match state_id:
		"excellent":
			return MOOD_COLOR_EXCELLENT
		"low":
			return MOOD_COLOR_LOW
		"depressed":
			return MOOD_COLOR_DEPRESSED
		_:
			return MOOD_COLOR_NORMAL


func _resolve_stress_color(state_id: String) -> Color:
	match state_id:
		"calm":
			return STRESS_COLOR_CALM
		"tense":
			return STRESS_COLOR_TENSE
		"high":
			return STRESS_COLOR_HIGH
		"panic":
			return STRESS_COLOR_PANIC
		_:
			return STRESS_COLOR_CALM
