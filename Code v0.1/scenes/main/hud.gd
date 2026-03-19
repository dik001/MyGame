extends CanvasLayer

@export var player_path: NodePath
@export_range(0, 23) var test_time_hours := 7
@export_range(0, 59) var test_time_minutes := 25
@export var run_test_clock := true
@export_range(0.05, 60.0, 0.05) var seconds_per_game_minute := 1.0
@export var dollars_icon: Texture2D

@onready var time_widget: TimeWidget = $root/MarginContainer/VBoxContainer/TimeWidget
@onready var health_label: Label = $root/MarginContainer/VBoxContainer/HealthRow/HealthLabel
@onready var hunger_label: Label = $root/MarginContainer/VBoxContainer/HungerRow/HungerLabel
@onready var energy_label: Label = $root/MarginContainer/VBoxContainer/EnergyRow/EnergyLabel
@onready var currency_icon: TextureRect = $root/MarginContainer/VBoxContainer/CurrencyRow/CurrencyIconPanel/CurrencyIcon
@onready var currency_fallback_label: Label = $root/MarginContainer/VBoxContainer/CurrencyRow/CurrencyIconPanel/CurrencyFallbackLabel
@onready var dollars_label: Label = $root/MarginContainer/VBoxContainer/CurrencyRow/DollarsLabel
@onready var interaction_prompt: Control = $root/InteractionPrompt
@onready var interaction_key_label: Label = $root/InteractionPrompt/PromptPanel/PromptRow/KeyPanel/KeyLabel
@onready var interaction_action_label: Label = $root/InteractionPrompt/PromptPanel/PromptRow/ActionLabel

var _player: Node
var _stats: PlayerStatsState
var _interact_key_text := "E"


func _ready() -> void:
	if not is_in_group("hud"):
		add_to_group("hud")

	_configure_clock()
	_connect_time_signals()
	_connect_economy_signals()

	if player_path.is_empty():
		push_warning("HUD.player_path is not set.")
		return

	_player = get_node_or_null(player_path)

	if _player == null:
		push_warning("HUD could not find the player node.")
		return

	_interact_key_text = _resolve_interact_key_text()
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

	_on_stats_changed(_stats.get_stats())


func set_time(hours: int, minutes: int) -> void:
	GameTime.set_time(hours, minutes)


func set_total_minutes(total_minutes: int) -> void:
	GameTime.set_absolute_minutes(total_minutes)


func advance_time_by_minutes(minutes: int) -> void:
	GameTime.advance_minutes(minutes)


func set_clock_paused(paused: bool) -> void:
	GameTime.set_clock_paused(paused)


func _process(_delta: float) -> void:
	_update_interaction_prompt()


func _on_stats_changed(current_stats: Dictionary) -> void:
	health_label.text = str(current_stats.get("hp", 0))
	hunger_label.text = str(current_stats.get("hunger", 0))
	energy_label.text = _format_stat_value(current_stats.get("energy", 0.0))


func _on_game_time_changed(_absolute_minutes: int, _day: int, hours: int, minutes: int) -> void:
	if time_widget == null:
		return

	time_widget.set_time(hours, minutes)


func _on_dollars_changed(new_value: int) -> void:
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

	var prompt_text := "\u0412\u0437\u0430\u0438\u043C\u043E\u0434\u0435\u0439\u0441\u0442\u0432\u0438\u0435"

	if interactable.has_method("get_interaction_prompt_text"):
		prompt_text = interactable.get_interaction_prompt_text()

	interaction_key_label.text = _interact_key_text
	interaction_action_label.text = prompt_text
	_set_interaction_prompt_visible(true)


func _set_interaction_prompt_visible(is_visible: bool) -> void:
	if interaction_prompt != null:
		interaction_prompt.visible = is_visible


func _resolve_interact_key_text() -> String:
	for event in InputMap.action_get_events("interact"):
		var key_event := event as InputEventKey

		if key_event == null:
			continue

		var keycode := key_event.physical_keycode

		if keycode == 0:
			keycode = key_event.keycode

		var key_text := OS.get_keycode_string(keycode)

		if not key_text.is_empty():
			return key_text.to_upper()

	return "E"


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
	if not PlayerEconomy.dollars_changed.is_connected(_on_dollars_changed):
		PlayerEconomy.dollars_changed.connect(_on_dollars_changed)

	_refresh_currency_icon()
	_on_dollars_changed(PlayerEconomy.get_dollars())


func _refresh_currency_icon() -> void:
	if currency_icon == null or currency_fallback_label == null:
		return

	currency_icon.texture = dollars_icon
	currency_icon.visible = dollars_icon != null
	currency_fallback_label.visible = dollars_icon == null
