extends Node

signal phone_opened
signal phone_closed
signal incoming_call_shown(contact_name: String, conversation_id: String)
signal call_accepted(contact_name: String)
signal call_ended(contact_name: String, duration: int)
signal sms_unlocked(contact_name: String)
signal sms_sent(contact_name: String, text: String)
signal sms_received(contact_name: String, text: String)

const PHONE_UI_SCENE := preload("res://scenes/ui/phone/PhoneUI.tscn")
const OPEN_PHONE_ACTION: StringName = &"open_phone"
const DEMO_CONTACT_AVATAR := preload("res://art/ui/dialogue/Unknown.png")
const DEMO_CONTACT_NAME := "Мама"
const DEMO_CONVERSATION_ID := "demo_mama_call"
const DEMO_DIALOGUE_TEXT := "Мама: Ты где? Почему не отвечала?"

var _phone_ui: PhoneUI = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if GameSettings != null and GameSettings.has_method("ensure_actions_initialized"):
		GameSettings.ensure_actions_initialized()
	_ensure_phone_ui()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(OPEN_PHONE_ACTION) or event.is_echo():
		return

	if _phone_ui == null:
		return

	if not _can_toggle_phone() and not _phone_ui.is_open():
		return

	_phone_ui.toggle_phone()
	get_viewport().set_input_as_handled()


func open_phone() -> void:
	if _ensure_phone_ui():
		_phone_ui.open_phone()


func close_phone() -> void:
	if _ensure_phone_ui():
		_phone_ui.close_phone()


func toggle_phone() -> void:
	if _ensure_phone_ui():
		_phone_ui.toggle_phone()


func open_map_app() -> void:
	if _ensure_phone_ui():
		_phone_ui.open_map_app()


func open_sms_app(contact_name: String = "") -> void:
	if _ensure_phone_ui():
		_phone_ui.open_sms_app(contact_name)


func show_incoming_call(contact_name: String, avatar: Texture2D = null, conversation_id: String = "", dialogue_text: String = "") -> void:
	if _ensure_phone_ui():
		_phone_ui.show_incoming_call(contact_name, avatar, conversation_id, dialogue_text)


func accept_call() -> void:
	if _ensure_phone_ui():
		_phone_ui.accept_call()


func end_call() -> void:
	if _ensure_phone_ui():
		_phone_ui.end_call()


func update_contact_data(contact_name: String, avatar: Texture2D = null, dialogue_text: String = "", conversation_id: String = "") -> void:
	if _ensure_phone_ui():
		_phone_ui.update_contact_data(contact_name, avatar, dialogue_text, conversation_id)


func set_dialogue_preview_text(dialogue_text: String) -> void:
	if _ensure_phone_ui():
		_phone_ui.set_dialogue_preview_text(dialogue_text)


func reset_call_timer() -> void:
	if _ensure_phone_ui():
		_phone_ui.reset_call_timer()


func send_sms(contact_name: String, text: String) -> void:
	if _ensure_phone_ui():
		_phone_ui.send_sms(contact_name, text)


func receive_sms(contact_name: String, text: String, avatar: Texture2D = null, auto_open := false) -> void:
	if _ensure_phone_ui():
		_phone_ui.receive_sms(contact_name, text, avatar, auto_open)


func trigger_demo_call() -> void:
	show_incoming_call(DEMO_CONTACT_NAME, DEMO_CONTACT_AVATAR, DEMO_CONVERSATION_ID, DEMO_DIALOGUE_TEXT)


func is_phone_open() -> bool:
	return _phone_ui != null and _phone_ui.is_open()


func is_sms_unlocked() -> bool:
	return _phone_ui != null and _phone_ui.is_sms_unlocked()


func build_save_data() -> Dictionary:
	if not _ensure_phone_ui():
		return {}

	if _phone_ui.has_method("build_save_data"):
		var data: Variant = _phone_ui.call("build_save_data")

		if data is Dictionary:
			return (data as Dictionary).duplicate(true)

	return {}


func apply_save_data(data: Dictionary) -> void:
	if not _ensure_phone_ui():
		return

	if _phone_ui.has_method("apply_save_data"):
		_phone_ui.call("apply_save_data", data)


func reset_state() -> void:
	if _phone_ui == null or not is_instance_valid(_phone_ui):
		return

	if _phone_ui.has_method("reset_state"):
		_phone_ui.call("reset_state")


func _ensure_phone_ui() -> bool:
	if _phone_ui != null and is_instance_valid(_phone_ui):
		return true

	var phone_ui_instance := PHONE_UI_SCENE.instantiate() as PhoneUI

	if phone_ui_instance == null:
		push_warning("PhoneManager could not instantiate PhoneUI.")
		return false

	add_child(phone_ui_instance)
	_phone_ui = phone_ui_instance
	_connect_phone_ui_signals()
	return true


func _connect_phone_ui_signals() -> void:
	if _phone_ui == null:
		return

	if not _phone_ui.phone_opened.is_connected(_on_phone_opened):
		_phone_ui.phone_opened.connect(_on_phone_opened)

	if not _phone_ui.phone_closed.is_connected(_on_phone_closed):
		_phone_ui.phone_closed.connect(_on_phone_closed)

	if not _phone_ui.incoming_call_shown.is_connected(_on_incoming_call_shown):
		_phone_ui.incoming_call_shown.connect(_on_incoming_call_shown)

	if not _phone_ui.call_accepted.is_connected(_on_call_accepted):
		_phone_ui.call_accepted.connect(_on_call_accepted)

	if not _phone_ui.call_ended.is_connected(_on_call_ended):
		_phone_ui.call_ended.connect(_on_call_ended)

	if not _phone_ui.sms_unlocked.is_connected(_on_sms_unlocked):
		_phone_ui.sms_unlocked.connect(_on_sms_unlocked)

	if not _phone_ui.sms_sent.is_connected(_on_sms_sent):
		_phone_ui.sms_sent.connect(_on_sms_sent)

	if not _phone_ui.sms_received.is_connected(_on_sms_received):
		_phone_ui.sms_received.connect(_on_sms_received)


func _can_toggle_phone() -> bool:
	var player := get_tree().get_first_node_in_group("player")

	if player == null or not player.has_method("is_input_locked"):
		return true

	return not player.is_input_locked()


func _on_phone_opened() -> void:
	phone_opened.emit()


func _on_phone_closed() -> void:
	phone_closed.emit()


func _on_incoming_call_shown(contact_name: String, conversation_id: String) -> void:
	incoming_call_shown.emit(contact_name, conversation_id)


func _on_call_accepted(contact_name: String) -> void:
	call_accepted.emit(contact_name)

	if contact_name == DEMO_CONTACT_NAME:
		DialogueManager.play_demo_phone_sequence()


func _on_call_ended(contact_name: String, duration: int) -> void:
	call_ended.emit(contact_name, duration)


func _on_sms_unlocked(contact_name: String) -> void:
	sms_unlocked.emit(contact_name)


func _on_sms_sent(contact_name: String, text: String) -> void:
	sms_sent.emit(contact_name, text)


func _on_sms_received(contact_name: String, text: String) -> void:
	sms_received.emit(contact_name, text)
