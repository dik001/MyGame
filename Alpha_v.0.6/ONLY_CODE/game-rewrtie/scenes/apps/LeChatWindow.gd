class_name LeChatWindow
extends PanelContainer

signal close_requested()

const CHAT_LIST_ITEM_SCENE := preload("res://scenes/apps/LeChatChatListItem.tscn")
const MESSAGE_BUBBLE_SCENE := preload("res://scenes/apps/LeChatMessageBubble.tscn")

const LANDLORD_CHAT_ID: String = "landlord"
const LANDLORD_DISPLAY_NAME: String = "Арендодатель"
const PLAYER_SENDER_ID: String = "player"
const PLAYER_DISPLAY_NAME: String = "Вы"
const LOCAL_NOTICE_SENDER_ID: String = "lechat_notice"
const LOCAL_NOTICE_DISPLAY_NAME: String = "LeChat"
const MAX_STATE_MESSAGES: int = 200
const MAX_PREVIEW_LENGTH: int = 72

@onready var search_line_edit: LineEdit = $MarginContainer/RootPanel/SidebarPanel/SidebarMargin/SidebarContent/SearchPanel/SearchMargin/SearchLineEdit
@onready var chat_list_scroll: ScrollContainer = $MarginContainer/RootPanel/SidebarPanel/SidebarMargin/SidebarContent/ChatListScroll
@onready var chat_list_container: VBoxContainer = $MarginContainer/RootPanel/SidebarPanel/SidebarMargin/SidebarContent/ChatListScroll/ChatListContainer
@onready var empty_chat_list_label: Label = $MarginContainer/RootPanel/SidebarPanel/SidebarMargin/SidebarContent/EmptyChatListLabel
@onready var chat_name_label: Label = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/HeaderPanel/HeaderMargin/HeaderRow/HeaderText/ChatNameLabel
@onready var status_label: Label = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/HeaderPanel/HeaderMargin/HeaderRow/HeaderText/StatusLabel
@onready var pay_rent_button: Button = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/HeaderPanel/HeaderMargin/HeaderRow/OptionalActionButton_PayRent
@onready var close_button: Button = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/HeaderPanel/HeaderMargin/HeaderRow/CloseButton
@onready var messages_scroll: ScrollContainer = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/MessagesPanel/MessagesMargin/MessagesScroll
@onready var messages_container: VBoxContainer = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/MessagesPanel/MessagesMargin/MessagesScroll/MessagesContainer
@onready var message_line_edit: LineEdit = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/BottomInputPanel/BottomInputMargin/BottomInputRow/MessageLineEdit
@onready var send_button: Button = $MarginContainer/RootPanel/MainChatPanel/MainChatMargin/MainChatContent/BottomInputPanel/BottomInputMargin/BottomInputRow/SendButton

var _rent_state: Node = null
var _selected_chat_id: String = LANDLORD_CHAT_ID
var _session_messages_by_chat: Dictionary = {}
var _local_message_sequence: int = 1


func _ready() -> void:
	visible = false
	close_button.text = "Закрыть"
	pay_rent_button.text = "Оплатить аренду"
	send_button.text = "Отправить"
	search_line_edit.placeholder_text = "Поиск чатов"
	message_line_edit.placeholder_text = "Напишите сообщение..."

	if not close_button.pressed.is_connected(_on_close_button_pressed):
		close_button.pressed.connect(_on_close_button_pressed)

	if not pay_rent_button.pressed.is_connected(_on_pay_rent_button_pressed):
		pay_rent_button.pressed.connect(_on_pay_rent_button_pressed)

	if not send_button.pressed.is_connected(_on_send_button_pressed):
		send_button.pressed.connect(_on_send_button_pressed)

	if not search_line_edit.text_changed.is_connected(_on_search_text_changed):
		search_line_edit.text_changed.connect(_on_search_text_changed)

	if not message_line_edit.text_changed.is_connected(_on_message_text_changed):
		message_line_edit.text_changed.connect(_on_message_text_changed)

	if not message_line_edit.text_submitted.is_connected(_on_message_line_edit_submitted):
		message_line_edit.text_submitted.connect(_on_message_line_edit_submitted)

	_resolve_rent_state()
	_connect_state_signals()
	refresh_view()


func open_window() -> void:
	visible = true
	refresh_view()

	if message_line_edit.editable:
		message_line_edit.grab_focus()
	else:
		close_button.grab_focus()


func close_window() -> void:
	visible = false


func refresh() -> void:
	refresh_view()


func refresh_view() -> void:
	_resolve_rent_state()
	_connect_state_signals()
	_ensure_selected_chat()

	var chats: Array[Dictionary] = _build_chat_entries()
	_rebuild_chat_list(chats)
	_refresh_header(chats)
	_rebuild_messages()
	_refresh_input_state()

	if visible:
		call_deferred("_mark_current_chat_as_read_if_needed")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return

	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		close_requested.emit()
		get_viewport().set_input_as_handled()


func _resolve_rent_state() -> void:
	_rent_state = get_node_or_null("/root/ApartmentRentState")


func _connect_state_signals() -> void:
	if _rent_state == null:
		return

	var refresh_callable: Callable = Callable(self, "_on_rent_state_changed")
	_connect_optional_signal(_rent_state, &"landlord_feed_changed", refresh_callable)
	_connect_optional_signal(_rent_state, &"rent_state_changed", refresh_callable)
	_connect_optional_signal(_rent_state, &"unread_landlord_count_changed", refresh_callable)


func _connect_optional_signal(target: Node, signal_name: StringName, callable: Callable) -> void:
	if target == null:
		return

	if not target.has_signal(signal_name):
		return

	if target.is_connected(signal_name, callable):
		return

	target.connect(signal_name, callable)


func _ensure_selected_chat() -> void:
	if _selected_chat_id.is_empty():
		_selected_chat_id = LANDLORD_CHAT_ID


func _build_chat_entries() -> Array[Dictionary]:
	var chats: Array[Dictionary] = []
	var messages: Array[Dictionary] = _get_combined_chat_messages(LANDLORD_CHAT_ID)
	var last_message: Dictionary = {}

	if not messages.is_empty():
		last_message = messages[messages.size() - 1]

	var unread_count: int = _get_unread_landlord_count()
	var preview_text: String = _build_preview_text(last_message)

	if preview_text.is_empty():
		if _rent_state == null:
			preview_text = "Состояние аренды недоступно"
		else:
			preview_text = "Сообщений пока нет"

	chats.append({
		"chat_id": LANDLORD_CHAT_ID,
		"display_name": LANDLORD_DISPLAY_NAME,
		"preview": preview_text,
		"unread_count": unread_count,
		"selected": _selected_chat_id == LANDLORD_CHAT_ID,
		"status": _build_header_status_text(),
	})

	return chats


func _rebuild_chat_list(chats: Array[Dictionary]) -> void:
	_clear_container(chat_list_container)

	var filter_text: String = search_line_edit.text.strip_edges().to_lower()
	var visible_count: int = 0

	for chat in chats:
		var title: String = String(chat.get("display_name", "")).strip_edges()

		if not filter_text.is_empty() and not title.to_lower().contains(filter_text):
			continue

		var item_scene: Node = CHAT_LIST_ITEM_SCENE.instantiate()
		var item: Control = item_scene as Control

		if item == null:
			if item_scene != null:
				item_scene.queue_free()
			continue

		if item.has_method("set_chat_data"):
			item.call("set_chat_data", chat)

		if item.has_method("set_selected"):
			item.call("set_selected", String(chat.get("chat_id", "")) == _selected_chat_id)

		_connect_optional_signal(item, &"chosen", Callable(self, "_on_chat_chosen"))

		chat_list_container.add_child(item)
		visible_count += 1

	chat_list_scroll.visible = visible_count > 0
	empty_chat_list_label.visible = visible_count <= 0

	if filter_text.is_empty():
		empty_chat_list_label.text = "Чатов пока нет"
	else:
		empty_chat_list_label.text = "Ничего не найдено"


func _refresh_header(chats: Array[Dictionary]) -> void:
	var current_chat: Dictionary = _find_chat_by_id(chats, _selected_chat_id)

	if current_chat.is_empty():
		chat_name_label.text = "LeChat"
		status_label.text = "Выберите чат"
	else:
		chat_name_label.text = String(current_chat.get("display_name", "LeChat"))
		status_label.text = String(current_chat.get("status", "")).strip_edges()

	var show_pay_button: bool = false

	if _selected_chat_id == LANDLORD_CHAT_ID:
		var snapshot: Dictionary = _get_rent_snapshot()
		show_pay_button = bool(snapshot.get("can_pay", false)) or bool(snapshot.get("is_due", false)) or bool(snapshot.get("is_overdue", false))

	pay_rent_button.visible = show_pay_button
	pay_rent_button.disabled = not show_pay_button


func _rebuild_messages() -> void:
	_clear_container(messages_container)

	if _selected_chat_id.is_empty():
		_add_state_label("Чат не выбран")
		return

	if _selected_chat_id != LANDLORD_CHAT_ID:
		_add_state_label("Этот чат пока не поддерживается")
		return

	if _rent_state == null:
		_add_state_label("ApartmentRentState недоступен. Чат аренды временно не загружен.")
		return

	var messages: Array[Dictionary] = _get_combined_chat_messages(_selected_chat_id)

	if messages.is_empty():
		_add_state_label("Сообщений пока нет")
		call_deferred("_scroll_messages_to_latest")
		return

	for message in messages:
		var bubble_scene: Node = MESSAGE_BUBBLE_SCENE.instantiate()
		var bubble: Control = bubble_scene as Control

		if bubble == null:
			if bubble_scene != null:
				bubble_scene.queue_free()
			continue

		if bubble.has_method("set_message_data"):
			bubble.call("set_message_data", message)

		messages_container.add_child(bubble)

	call_deferred("_scroll_messages_to_latest")


func _refresh_input_state() -> void:
	var state_available: bool = _rent_state != null
	var can_type: bool = state_available and _selected_chat_id == LANDLORD_CHAT_ID

	message_line_edit.editable = can_type
	message_line_edit.placeholder_text = "Напишите сообщение..." if can_type else "Чат недоступен"
	send_button.disabled = not can_type or message_line_edit.text.strip_edges().is_empty()
	pay_rent_button.disabled = not pay_rent_button.visible


func _send_current_message() -> void:
	if not message_line_edit.editable:
		return

	var text: String = message_line_edit.text.strip_edges()

	if text.is_empty():
		return

	_append_local_message(
		_selected_chat_id,
		_build_local_message(text, PLAYER_SENDER_ID, PLAYER_DISPLAY_NAME, "player_reply", true)
	)
	message_line_edit.clear()
	refresh_view()


func _build_local_message(
	text: String,
	sender_id: String,
	sender_display_name: String,
	message_type: String,
	is_outgoing: bool
) -> Dictionary:
	var time_data: Dictionary = _get_game_time_data()
	var sequence: int = _local_message_sequence

	_local_message_sequence += 1

	return {
		"id": "local_%d" % sequence,
		"chat_id": _selected_chat_id,
		"sender_id": sender_id,
		"sender_display_name": sender_display_name,
		"text": text,
		"type": message_type,
		"day": int(time_data.get("day", -1)),
		"absolute_minutes": int(time_data.get("absolute_minutes", -1)),
		"is_outgoing": is_outgoing,
		"sort_order": 100000 + sequence,
		"source": "session",
	}


func _append_local_notice(text: String) -> void:
	_append_local_message(
		LANDLORD_CHAT_ID,
		_build_local_message(text, LOCAL_NOTICE_SENDER_ID, LOCAL_NOTICE_DISPLAY_NAME, "local_notice", false)
	)


func _append_local_message(chat_id: String, message: Dictionary) -> void:
	var messages: Array = _session_messages_by_chat.get(chat_id, [])

	messages.append(message.duplicate(true))
	_session_messages_by_chat[chat_id] = messages


func _get_combined_chat_messages(chat_id: String) -> Array[Dictionary]:
	var combined: Array[Dictionary] = []

	if chat_id == LANDLORD_CHAT_ID:
		combined.append_array(_get_landlord_state_messages())

	var session_messages: Array = _session_messages_by_chat.get(chat_id, [])

	for message_variant in session_messages:
		if not (message_variant is Dictionary):
			continue

		var local_message: Dictionary = message_variant
		var normalized_local: Dictionary = _normalize_local_message(local_message)

		if normalized_local.is_empty():
			continue

		combined.append(normalized_local)

	combined.sort_custom(Callable(self, "_sort_messages"))
	return combined


func _get_landlord_state_messages() -> Array[Dictionary]:
	var result: Array[Dictionary] = []

	if _rent_state == null:
		return result

	if not _rent_state.has_method("get_landlord_messages"):
		return result

	var raw_messages: Variant = _rent_state.call("get_landlord_messages", MAX_STATE_MESSAGES)

	if not (raw_messages is Array):
		return result

	var raw_array: Array = raw_messages

	for index in range(raw_array.size()):
		var entry_variant: Variant = raw_array[index]

		if not (entry_variant is Dictionary):
			continue

		var entry: Dictionary = entry_variant
		var normalized: Dictionary = _normalize_state_message(entry, index)

		if normalized.is_empty():
			continue

		result.append(normalized)

	return result


func _normalize_state_message(entry: Dictionary, index: int) -> Dictionary:
	var text: String = String(entry.get("text", "")).strip_edges()

	if text.is_empty():
		return {}

	var sender_id: String = String(entry.get("sender_id", LANDLORD_CHAT_ID)).strip_edges()
	var display_name: String = String(entry.get("sender_display_name", LANDLORD_DISPLAY_NAME)).strip_edges()

	if display_name.is_empty():
		display_name = LANDLORD_DISPLAY_NAME

	return {
		"id": String(entry.get("id", "landlord_%d" % index)),
		"chat_id": LANDLORD_CHAT_ID,
		"sender_id": sender_id,
		"sender_display_name": display_name,
		"text": text,
		"type": String(entry.get("type", "message")),
		"day": int(entry.get("day", -1)),
		"absolute_minutes": int(entry.get("absolute_minutes", -1)),
		"is_outgoing": false,
		"sort_order": index,
		"source": "rent_state",
	}


func _normalize_local_message(entry: Dictionary) -> Dictionary:
	var text: String = String(entry.get("text", "")).strip_edges()

	if text.is_empty():
		return {}

	return {
		"id": String(entry.get("id", "local_message")),
		"chat_id": String(entry.get("chat_id", LANDLORD_CHAT_ID)),
		"sender_id": String(entry.get("sender_id", PLAYER_SENDER_ID)),
		"sender_display_name": String(entry.get("sender_display_name", PLAYER_DISPLAY_NAME)),
		"text": text,
		"type": String(entry.get("type", "player_reply")),
		"day": int(entry.get("day", -1)),
		"absolute_minutes": int(entry.get("absolute_minutes", -1)),
		"is_outgoing": bool(entry.get("is_outgoing", false)),
		"sort_order": int(entry.get("sort_order", 100000)),
		"source": String(entry.get("source", "session")),
	}


func _sort_messages(left: Dictionary, right: Dictionary) -> bool:
	var left_minutes: int = int(left.get("absolute_minutes", -1))
	var right_minutes: int = int(right.get("absolute_minutes", -1))

	if left_minutes != right_minutes:
		return left_minutes < right_minutes

	return int(left.get("sort_order", 0)) < int(right.get("sort_order", 0))


func _build_preview_text(message: Dictionary) -> String:
	if message.is_empty():
		return ""

	var sender_id: String = String(message.get("sender_id", "")).strip_edges()
	var text: String = String(message.get("text", "")).strip_edges()

	if text.is_empty():
		return ""

	text = text.replace("\n", " ")

	if sender_id == PLAYER_SENDER_ID:
		text = "Вы: %s" % text

	if text.length() > MAX_PREVIEW_LENGTH:
		text = "%s..." % text.substr(0, MAX_PREVIEW_LENGTH)

	return text


func _build_header_status_text() -> String:
	if _rent_state == null:
		return "Источник аренды недоступен"

	var snapshot: Dictionary = _get_rent_snapshot()

	if snapshot.is_empty():
		return "Система аренды подключена"

	var amount: int = int(snapshot.get("rent_amount", snapshot.get("current_rent_amount", 0)))
	var unread_count: int = _get_unread_landlord_count()

	if bool(snapshot.get("is_overdue", false)):
		return "Просрочка %d д. - $%d" % [max(1, int(snapshot.get("days_overdue", 1))), max(0, amount)]

	if bool(snapshot.get("is_due", false)):
		return "Оплата сегодня - $%d" % max(0, amount)

	if bool(snapshot.get("can_pay", false)):
		return "Счёт активен - $%d" % max(0, amount)

	var due_day: int = int(snapshot.get("due_day", 0))

	if unread_count > 0:
		return "Новых сообщений: %d" % unread_count

	if due_day > 0:
		return "Следующая аренда: день %d" % due_day

	return "Диалог по аренде"


func _get_rent_snapshot() -> Dictionary:
	if _rent_state == null:
		return {}

	if not _rent_state.has_method("get_current_rent_snapshot"):
		return {}

	var snapshot_variant: Variant = _rent_state.call("get_current_rent_snapshot")

	if snapshot_variant is Dictionary:
		return snapshot_variant

	return {}


func _get_unread_landlord_count() -> int:
	if _rent_state == null:
		return 0

	if not _rent_state.has_method("get_unread_landlord_count"):
		return 0

	return int(_rent_state.call("get_unread_landlord_count"))


func _find_chat_by_id(chats: Array[Dictionary], chat_id: String) -> Dictionary:
	for chat in chats:
		if String(chat.get("chat_id", "")) == chat_id:
			return chat

	return {}


func _get_game_time_data() -> Dictionary:
	var game_time: Node = get_node_or_null("/root/GameTime")

	if game_time == null:
		return {}

	if game_time.has_method("get_current_time_data"):
		var time_variant: Variant = game_time.call("get_current_time_data")

		if time_variant is Dictionary:
			return time_variant

	var day: int = int(game_time.call("get_day")) if game_time.has_method("get_day") else -1
	var absolute_minutes: int = int(game_time.call("get_absolute_minutes")) if game_time.has_method("get_absolute_minutes") else -1

	return {
		"day": day,
		"absolute_minutes": absolute_minutes,
	}


func _add_state_label(text: String) -> void:
	var label: Label = Label.new()

	label.custom_minimum_size = Vector2(0, 220)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 24)
	label.add_theme_color_override("font_color", Color(0.72, 0.82, 0.90, 1.0))
	label.text = text
	messages_container.add_child(label)


func _clear_container(container: Node) -> void:
	for child in container.get_children():
		child.queue_free()


func _scroll_messages_to_latest() -> void:
	if messages_scroll == null:
		return

	var scroll_bar: VScrollBar = messages_scroll.get_v_scroll_bar()

	if scroll_bar == null:
		return

	messages_scroll.scroll_vertical = int(scroll_bar.max_value)


func _mark_current_chat_as_read_if_needed() -> void:
	if not visible:
		return

	if _selected_chat_id != LANDLORD_CHAT_ID:
		return

	if _rent_state == null:
		return

	if not _rent_state.has_method("mark_all_landlord_messages_read"):
		return

	if _get_unread_landlord_count() <= 0:
		return

	_rent_state.call("mark_all_landlord_messages_read")


func _on_chat_chosen(chat_id: String) -> void:
	if chat_id.is_empty():
		return

	if _selected_chat_id == chat_id:
		if visible:
			call_deferred("_mark_current_chat_as_read_if_needed")
		return

	_selected_chat_id = chat_id
	refresh_view()


func _on_close_button_pressed() -> void:
	close_requested.emit()


func _on_send_button_pressed() -> void:
	_send_current_message()


func _on_message_line_edit_submitted(_submitted_text: String) -> void:
	_send_current_message()


func _on_search_text_changed(_new_text: String) -> void:
	_rebuild_chat_list(_build_chat_entries())


func _on_message_text_changed(_new_text: String) -> void:
	_refresh_input_state()


func _on_pay_rent_button_pressed() -> void:
	if _rent_state == null:
		_append_local_notice("Оплата аренды сейчас недоступна.")
		refresh_view()
		return

	if not _rent_state.has_method("pay_current_rent"):
		_append_local_notice("Система оплаты аренды не найдена.")
		refresh_view()
		return

	var result_variant: Variant = _rent_state.call("pay_current_rent")
	var result: Dictionary = result_variant if result_variant is Dictionary else {}

	if bool(result.get("success", false)):
		refresh_view()
		return

	var error_code: String = String(result.get("error", "")).strip_edges()
	var message: String = String(result.get("message", "")).strip_edges()

	if error_code == "insufficient_funds":
		var required_amount: int = int(result.get("required_amount", 0))
		var current_dollars: int = int(result.get("current_dollars", 0))
		message = "Не хватает денег для аренды: нужно $%d, сейчас $%d." % [max(0, required_amount), max(0, current_dollars)]
	elif message.is_empty():
		message = "Оплату аренды сейчас выполнить не удалось."

	_append_local_notice(message)
	refresh_view()


func _on_rent_state_changed(_arg1: Variant = null) -> void:
	refresh_view()
