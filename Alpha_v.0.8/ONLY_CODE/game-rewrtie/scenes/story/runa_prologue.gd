extends CanvasLayer

const PLAYER_START_POSITION := Vector2(244.0, 78.0)
const CALL_DIALOGUE: Array[Dictionary] = [
	{
		"speaker": "Хлоя",
		"text": "Ты трубку когда-нибудь вовремя берёшь?",
	},
	{
		"speaker": "Руна",
		"text": "Я проснулась.",
	},
	{
		"speaker": "Хлоя",
		"text": "Тогда слушай внимательно. У тебя семь дней. Семь дней, чтобы прожить их как нормальный человек и оплатить аренду.",
	},
	{
		"speaker": "Руна",
		"text": "Поняла.",
	},
	{
		"speaker": "Хлоя",
		"text": "Нет, Руна. Если бы поняла раньше, не было бы игр, вранья и того парня, который вытянул из семьи деньги.",
	},
	{
		"speaker": "Руна",
		"text": "...",
	},
	{
		"speaker": "Хлоя",
		"text": "Ты взрослая только на словах. Я больше не буду тебя вытаскивать.",
	},
	{
		"speaker": "Руна",
		"text": "Да.",
	},
	{
		"speaker": "Хлоя",
		"text": "Через семь дней квартира должна быть оплачена. Дальше без меня.",
	},
	{
		"speaker": "Хлоя",
		"text": "Посмотрим, умеешь ли ты наконец жить сама.",
	},
]

@onready var root: Control = $Root
@onready var fade_overlay: ColorRect = $Root/FadeOverlay
@onready var backdrop_tint: ColorRect = $Root/BackdropTint
@onready var narration_label: Label = $Root/NarrationLayer/NarrationLabel
@onready var phone_card: PanelContainer = $Root/PhoneCard
@onready var phone_status_label: Label = $Root/PhoneCard/MarginContainer/Content/StatusLabel
@onready var phone_name_label: Label = $Root/PhoneCard/MarginContainer/Content/NameLabel
@onready var phone_meta_label: Label = $Root/PhoneCard/MarginContainer/Content/MetaLabel
@onready var phone_caption_label: Label = $Root/PhoneCard/MarginContainer/Content/CaptionLabel
@onready var call_panel: PanelContainer = $Root/CallPanel
@onready var call_status_label: Label = $Root/CallPanel/MarginContainer/Content/CallStatusLabel
@onready var speaker_label: Label = $Root/CallPanel/MarginContainer/Content/SpeakerLabel
@onready var dialog_label: Label = $Root/CallPanel/MarginContainer/Content/DialogLabel
@onready var call_hint_label: Label = $Root/CallPanel/MarginContainer/Content/HintLabel
@onready var thought_panel: PanelContainer = $Root/ThoughtPanel
@onready var thought_label: Label = $Root/ThoughtPanel/MarginContainer/ThoughtLabel
@onready var objective_panel: PanelContainer = $Root/ObjectivePanel
@onready var objective_meta_label: Label = $Root/ObjectivePanel/MarginContainer/Content/MetaLabel
@onready var objective_title_label: Label = $Root/ObjectivePanel/MarginContainer/Content/TitleLabel
@onready var objective_details_label: Label = $Root/ObjectivePanel/MarginContainer/Content/DetailsLabel

var _player: Node
var _hud: Node
var _room: Node
var _is_running := false
var _waiting_for_advance := false
var _advance_requested := false
var _fade_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	call_hint_label.text = "E - далее"
	_hide_all_story_panels()


func _exit_tree() -> void:
	if _is_running:
		_apply_modal_state(false)


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_advance:
		return

	var should_advance := false

	if event is InputEventKey and event.pressed and not event.echo:
		should_advance = event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")
	elif event is InputEventMouseButton and event.pressed:
		should_advance = event.button_index == MOUSE_BUTTON_LEFT

	if not should_advance:
		return

	_advance_requested = true
	get_viewport().set_input_as_handled()


func start_prologue(player_node: Node, hud_node: Node, room_node: Node) -> void:
	if _is_running:
		return

	_player = player_node
	_hud = hud_node
	_room = room_node
	_is_running = true
	_apply_modal_state(true)
	call_deferred("_run_prologue")


func _run_prologue() -> void:
	if _player == null or not is_instance_valid(_player):
		queue_free()
		return

	_apply_modal_state(true)
	_position_player()
	await _fade_from_black()
	await _show_narration("Утро было серым даже внутри квартиры. Воздух стоял тяжёлый, монитор всё ещё светил с ночи.")
	await _show_narration("В голове сразу всплыло: двадцать пять долларов, одно яблоко в холодильнике и семь дней до аренды.")
	await _show_phone_card("1 пропущенный вызов", "Хлоя", "07:21", "Экран вспыхнул снова.")
	await _show_phone_card("Входящий звонок", "Хлоя", "Сейчас", "Игнорировать уже не выйдет.")
	await _run_call_dialogue()
	await _show_thought("Она уже почти не злится. Просто не верит.\nЛадно. Плевать. На улице я не окажусь.")
	_apply_main_objective()
	await _show_objective_splash()
	StoryState.mark_runa_prologue_completed()
	_apply_modal_state(false)
	await _fade_out()
	_is_running = false
	queue_free()


func _position_player() -> void:
	if _player == null:
		return

	if _player.has_method("apply_spawn_world_position"):
		_player.call("apply_spawn_world_position", PLAYER_START_POSITION, Vector2.DOWN)
		return

	if _player is Node2D:
		(_player as Node2D).global_position = PLAYER_START_POSITION


func _apply_modal_state(is_active: bool) -> void:
	if _player != null and _player.has_method("set_input_locked"):
		_player.set_input_locked(is_active)

	if _hud != null and _hud.has_method("set_clock_paused"):
		_hud.set_clock_paused(is_active)


func _hide_all_story_panels() -> void:
	narration_label.visible = false
	phone_card.visible = false
	call_panel.visible = false
	thought_panel.visible = false
	objective_panel.visible = false
	DialogueManager.hide_dialogue(true)
	backdrop_tint.color = Color(0.0, 0.0, 0.0, 0.0)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)


func _fade_from_black() -> void:
	backdrop_tint.color = Color(0.0, 0.0, 0.0, 0.42)
	fade_overlay.color = Color(0.0, 0.0, 0.0, 1.0)

	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 0.0), 0.55)
	await _fade_tween.finished


func _fade_out() -> void:
	if _fade_tween != null and is_instance_valid(_fade_tween):
		_fade_tween.kill()

	_hide_all_story_panels()
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(backdrop_tint, "color", Color(0.0, 0.0, 0.0, 0.0), 0.3)
	_fade_tween.tween_property(fade_overlay, "color", Color(0.0, 0.0, 0.0, 1.0), 0.3)
	await _fade_tween.finished


func _show_narration(text: String) -> void:
	narration_label.text = "%s\n\n[E - далее]" % text
	narration_label.visible = true
	await _wait_for_advance()
	narration_label.visible = false


func _show_phone_card(status: String, caller_name: String, meta: String, caption: String) -> void:
	phone_status_label.text = status
	phone_name_label.text = caller_name
	phone_meta_label.text = meta
	phone_caption_label.text = caption
	phone_card.visible = true
	await _wait_seconds(1.2)
	phone_card.visible = false


func _run_call_dialogue() -> void:
	call_panel.visible = false
	var sequence: Array[Dictionary] = []

	for entry in CALL_DIALOGUE:
		var speaker_name := String(entry.get("speaker", "")).strip_edges()
		var speaker_text := String(entry.get("text", "")).strip_edges()
		sequence.append({
			"speaker_name": speaker_name,
			"speaker_id": _resolve_story_speaker_id(speaker_name),
			"text": speaker_text,
		})

	DialogueManager.play_sequence(sequence, true)
	await DialogueManager.dialogue_sequence_finished
	await _wait_seconds(0.2)


func _resolve_story_speaker_id(speaker_name: String) -> String:
	var normalized_name := speaker_name.strip_edges().to_lower()

	if normalized_name.contains("руна"):
		return "runa"

	return "mama"


func _show_thought(text: String) -> void:
	thought_label.text = "%s\n\n[E - далее]" % text
	thought_panel.visible = true
	await _wait_for_advance()
	thought_panel.visible = false


func _apply_main_objective() -> void:
	var current_day := GameTime.get_day()
	var deadline_day := ApartmentRentState.get_next_due_day()
	var first_rent_amount := ApartmentRentState.get_rent_amount()

	if deadline_day <= 0:
		deadline_day = current_day + 6

	StoryState.set_primary_objective(
		"Прожить 7 дней и оплатить аренду",
		"",
		[],
		{
			"id": "runa_first_rent",
			"start_day": current_day,
			"deadline_day": deadline_day,
			"rent_amount": first_rent_amount,
		}
	)


func _show_objective_splash() -> void:
	objective_panel.offset_left = -300.0
	objective_panel.offset_top = -52.0
	objective_panel.offset_right = 300.0
	objective_panel.offset_bottom = 52.0
	objective_meta_label.visible = false
	objective_details_label.visible = false
	objective_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_title_label.text = "Прожить 7 дней и оплатить аренду"
	objective_panel.visible = true
	await _wait_seconds(2.1)
	objective_panel.visible = false


func _wait_for_advance() -> void:
	_waiting_for_advance = true
	_advance_requested = false

	while not _advance_requested:
		await get_tree().process_frame

	_waiting_for_advance = false


func _wait_seconds(seconds: float) -> void:
	await get_tree().create_timer(max(0.01, seconds)).timeout
