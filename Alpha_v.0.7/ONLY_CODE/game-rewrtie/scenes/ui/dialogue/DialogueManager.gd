extends Node

signal dialogue_sequence_started
signal dialogue_sequence_finished
signal dialogue_line_shown(speaker_name: String, text: String)
signal dialogue_hidden

const DIALOGUE_BOX_SCENE := preload("res://scenes/ui/dialogue/DialogueBoxUI.tscn")
const DEFAULT_PHONE_DEMO_SEQUENCE: Array[Dictionary] = [
	{
		"speaker_name": "Мама",
		"speaker_id": "mama",
		"text": "Ты где? Почему не отвечала?",
	},
	{
		"speaker_name": "Руна",
		"speaker_id": "runa",
		"text": "Я уже здесь. Только взяла трубку.",
	},
]

var _dialogue_box: DialogueBoxUI = null
var _waiting_for_advance := false
var _advance_requested := false
var _sequence_id := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_dialogue_box()


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


func show_line(speaker_name: String, text: String, speaker_id: String = "", portrait: Texture2D = null, show_continue_hint := false) -> void:
	if not _ensure_dialogue_box():
		return

	_dialogue_box.show_dialogue_line(speaker_name, text, speaker_id, portrait, show_continue_hint)
	dialogue_line_shown.emit(speaker_name, text)


func hide_dialogue(instant := false) -> void:
	_waiting_for_advance = false
	_advance_requested = false

	if _ensure_dialogue_box():
		_dialogue_box.hide_dialogue_box(instant)


func play_sequence(entries: Array[Dictionary], auto_hide := true) -> void:
	_sequence_id += 1
	_play_sequence(entries.duplicate(true), auto_hide, _sequence_id)


func play_demo_phone_sequence() -> void:
	play_sequence(DEFAULT_PHONE_DEMO_SEQUENCE, true)


func is_dialogue_visible() -> bool:
	return _dialogue_box != null and is_instance_valid(_dialogue_box) and _dialogue_box.is_dialogue_visible()


func set_portrait(speaker_id: String, portrait: Texture2D) -> void:
	if portrait == null:
		return

	if _ensure_dialogue_box():
		_dialogue_box.set_portrait(speaker_id, portrait)


func _play_sequence(entries: Array[Dictionary], auto_hide: bool, sequence_id: int) -> void:
	if entries.is_empty():
		hide_dialogue(true)
		return

	dialogue_sequence_started.emit()

	for entry in entries:
		if sequence_id != _sequence_id:
			return

		var speaker_name := String(entry.get("speaker_name", entry.get("speaker", ""))).strip_edges()
		var speaker_id := String(entry.get("speaker_id", "")).strip_edges()
		var text := String(entry.get("text", "")).strip_edges()
		var portrait := entry.get("portrait", null) as Texture2D

		show_line(speaker_name, text, speaker_id, portrait, true)

		if not await _wait_for_advance(sequence_id):
			return

	_waiting_for_advance = false
	_advance_requested = false

	if auto_hide:
		hide_dialogue()

	dialogue_sequence_finished.emit()


func _wait_for_advance(sequence_id: int) -> bool:
	_waiting_for_advance = true
	_advance_requested = false

	while not _advance_requested:
		if sequence_id != _sequence_id:
			_waiting_for_advance = false
			_advance_requested = false
			return false

		await get_tree().process_frame

	_waiting_for_advance = false
	_advance_requested = false
	return true


func _ensure_dialogue_box() -> bool:
	if _dialogue_box != null and is_instance_valid(_dialogue_box):
		return true

	var dialogue_box_instance := DIALOGUE_BOX_SCENE.instantiate() as DialogueBoxUI

	if dialogue_box_instance == null:
		push_warning("DialogueManager could not instantiate DialogueBoxUI.")
		return false

	add_child(dialogue_box_instance)
	_dialogue_box = dialogue_box_instance

	if not _dialogue_box.dialogue_hidden.is_connected(_on_dialogue_box_hidden):
		_dialogue_box.dialogue_hidden.connect(_on_dialogue_box_hidden)

	return true


func _on_dialogue_box_hidden() -> void:
	dialogue_hidden.emit()
