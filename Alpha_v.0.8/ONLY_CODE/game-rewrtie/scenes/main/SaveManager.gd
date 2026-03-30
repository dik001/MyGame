extends Node


signal save_slots_changed
signal operation_succeeded(message: String)
signal operation_failed(message: String)
signal load_finished(success: bool)

const SAVE_VERSION := 4
const SAVE_DIRECTORY := "user://saves"
const AUTOSAVE_SLOT_KIND := "autosave"
const MANUAL_SLOT_KIND := "manual"
const AUTOSAVE_PATH := "user://saves/autosave.json"
const MANUAL_SLOT_PATH_TEMPLATE := "user://saves/slot_%02d.json"
const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const TITLE_SCENE_PATH := "res://scenes/main/title_screen.tscn"
const AUTOSAVE_INTERVAL_SECONDS := 15.0 * 60.0
const MAX_MANUAL_SLOTS := 10
const SNAPSHOT_TARGETS := [
	{"node_name": "GameManager", "payload_key": "game_manager"},
	{"node_name": "GameTime", "payload_key": "game_time"},
	{"node_name": "PlayerStats", "payload_key": "player_stats"},
	{"node_name": "PlayerInventory", "payload_key": "player_inventory"},
	{"node_name": "PlayerEquipment", "payload_key": "player_equipment"},
	{"node_name": "PlayerBodyState", "payload_key": "player_body_state"},
	{"node_name": "FridgeInventory", "payload_key": "fridge_inventory"},
	{"node_name": "PlayerEconomy", "payload_key": "player_economy"},
	{"node_name": "DeliveryManager", "payload_key": "delivery_manager"},
	{"node_name": "FreelanceState", "payload_key": "freelance_state"},
	{"node_name": "ApartmentRentState", "payload_key": "apartment_rent_state"},
	{"node_name": "PlayerMentalState", "payload_key": "player_mental_state"},
	{"node_name": "CashierPartTimeState", "payload_key": "cashier_part_time_state"},
	{"node_name": "StoryState", "payload_key": "story_state"},
	{"node_name": "PhoneManager", "payload_key": "phone_manager"},
]

var _autosave_elapsed_seconds := 0.0
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_ensure_save_directory_exists()


func _process(delta: float) -> void:
	if _busy:
		return

	if not _is_autosave_context_active():
		return

	_autosave_elapsed_seconds += delta

	if _autosave_elapsed_seconds < AUTOSAVE_INTERVAL_SECONDS:
		return

	_autosave_elapsed_seconds -= AUTOSAVE_INTERVAL_SECONDS
	_save_slot(AUTOSAVE_SLOT_KIND, 0, false)


func has_any_saves() -> bool:
	if has_slot(AUTOSAVE_SLOT_KIND):
		return true

	for slot_index in range(1, MAX_MANUAL_SLOTS + 1):
		if has_slot(MANUAL_SLOT_KIND, slot_index):
			return true

	return false


func has_slot(slot_kind: String, slot_index: int = 0) -> bool:
	return FileAccess.file_exists(_get_slot_path(slot_kind, slot_index))


func get_continue_summary() -> Dictionary:
	var best_summary: Dictionary = {}

	for entry in _get_existing_slots():
		var summary: Dictionary = SaveDataUtils.sanitize_dictionary(entry.get("summary", {}))

		if summary.is_empty() or bool(entry.get("is_dead", false)):
			continue

		if best_summary.is_empty() or int(entry.get("saved_at_unix", 0)) > int(best_summary.get("saved_at_unix", 0)):
			best_summary = entry.duplicate(true)

	return best_summary


func get_slot_summary(slot_kind: String, slot_index: int = 0) -> Dictionary:
	var slot_data := _load_slot_data_from_disk(slot_kind, slot_index)

	if slot_data.is_empty():
		return {}

	return {
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"saved_at_unix": int(slot_data.get("saved_at_unix", 0)),
		"is_dead": _is_slot_data_dead(slot_data),
		"summary": SaveDataUtils.sanitize_dictionary(slot_data.get("summary", {})),
	}


func save_to_manual_slot(slot_index: int) -> bool:
	return _save_slot(MANUAL_SLOT_KIND, slot_index, true)


func request_load_latest_save() -> void:
	if _busy:
		return

	var latest_summary := get_continue_summary()

	if latest_summary.is_empty():
		operation_failed.emit("Нет доступных сохранений.")
		return

	call_deferred(
		"_perform_load_request",
		String(latest_summary.get("slot_kind", "")),
		int(latest_summary.get("slot_index", 0))
	)


func request_load_slot(slot_kind: String, slot_index: int = 0) -> void:
	if _busy:
		return

	call_deferred("_perform_load_request", slot_kind, slot_index)


func request_new_game() -> void:
	if _busy:
		return

	call_deferred("_perform_new_game_request")


func return_to_title_screen() -> void:
	if _busy:
		return

	call_deferred("_perform_return_to_title_request")


func _perform_load_request(slot_kind: String, slot_index: int) -> void:
	if _busy:
		return

	var slot_data := _load_slot_data_from_disk(slot_kind, slot_index)

	if slot_data.is_empty():
		operation_failed.emit("Сохранение не найдено.")
		load_finished.emit(false)
		return

	if _is_slot_data_dead(slot_data):
		operation_failed.emit("Это сохранение недоступно.")
		load_finished.emit(false)
		return

	_busy = true
	_close_runtime_ui()
	_reset_runtime_state()
	_apply_payload(SaveDataUtils.sanitize_dictionary(slot_data.get("payload", {})))

	var world_payload := SaveDataUtils.sanitize_dictionary(
		SaveDataUtils.sanitize_dictionary(slot_data.get("payload", {})).get("world", {})
	)
	var scene_changed := await _change_scene_and_wait(GAME_SCENE_PATH)

	if not scene_changed:
		_busy = false
		operation_failed.emit("Не удалось открыть игровую сцену.")
		load_finished.emit(false)
		return

	_restore_world_state(world_payload)
	_autosave_elapsed_seconds = 0.0
	_busy = false
	load_finished.emit(true)


func _perform_new_game_request() -> void:
	if _busy:
		return

	_busy = true
	_close_runtime_ui()
	_reset_runtime_state()
	var scene_changed := await _change_scene_and_wait(GAME_SCENE_PATH)

	if not scene_changed:
		_busy = false
		operation_failed.emit("Не удалось запустить новую игру.")
		load_finished.emit(false)
		return

	_autosave_elapsed_seconds = 0.0
	_busy = false
	load_finished.emit(true)


func _perform_return_to_title_request() -> void:
	_close_runtime_ui()
	await _change_scene_and_wait(TITLE_SCENE_PATH)


func _ensure_save_directory_exists() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY))


func _is_autosave_context_active() -> bool:
	if GameManager != null and GameManager.has_method("is_session_failed") and GameManager.is_session_failed():
		return false

	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		return false

	return tree.current_scene.scene_file_path == GAME_SCENE_PATH


func _save_slot(slot_kind: String, slot_index: int, emit_feedback: bool) -> bool:
	if GameManager != null and GameManager.has_method("is_session_failed") and GameManager.is_session_failed():
		if emit_feedback:
			operation_failed.emit("Сейчас сохранение недоступно.")
		return false

	if slot_kind == MANUAL_SLOT_KIND and (slot_index < 1 or slot_index > MAX_MANUAL_SLOTS):
		if emit_feedback:
			operation_failed.emit("Неверный номер слота.")
		return false

	if slot_kind != AUTOSAVE_SLOT_KIND and slot_kind != MANUAL_SLOT_KIND:
		if emit_feedback:
			operation_failed.emit("Неизвестный тип слота.")
		return false

	var snapshot := _build_snapshot(slot_kind, slot_index)

	if snapshot.is_empty():
		if emit_feedback:
			operation_failed.emit("Сохранение доступно только из основной игровой сцены.")
		return false

	_ensure_save_directory_exists()
	var file := FileAccess.open(_get_slot_path(slot_kind, slot_index), FileAccess.WRITE)

	if file == null:
		if emit_feedback:
			operation_failed.emit("Не удалось открыть файл сохранения.")
		return false

	file.store_string(JSON.stringify(snapshot, "\t"))
	save_slots_changed.emit()

	if emit_feedback:
		operation_succeeded.emit("Сохранение записано.")

	return true


func _build_snapshot(slot_kind: String, slot_index: int) -> Dictionary:
	if not _can_build_snapshot():
		return {}

	var world_payload := _build_world_payload()

	if world_payload.is_empty():
		return {}

	var payload: Dictionary = {
		"world": world_payload,
	}

	for entry in SNAPSHOT_TARGETS:
		var node_name := String(entry.get("node_name", ""))
		var payload_key := String(entry.get("payload_key", ""))
		var target_node := get_node_or_null("/root/%s" % node_name)

		if target_node == null or not target_node.has_method("build_save_data"):
			continue

		payload[payload_key] = target_node.call("build_save_data")

	var saved_at_unix := int(Time.get_unix_time_from_system())
	var time_data := GameTime.get_current_time_data()
	var room_scene_path := String(world_payload.get("room_scene_path", GameManager.get_current_room_scene_path()))
	var summary := {
		"slot_title": "Автосейв" if slot_kind == AUTOSAVE_SLOT_KIND else "Слот %02d" % slot_index,
		"room_scene_path": room_scene_path,
		"room_name": SaveDataUtils.format_room_name(room_scene_path),
		"day": int(time_data.get("day", 1)),
		"hours": int(time_data.get("hours", 0)),
		"minutes": int(time_data.get("minutes", 0)),
		"cash_dollars": PlayerEconomy.get_cash_dollars(),
		"bank_dollars": PlayerEconomy.get_bank_dollars(),
	}

	return {
		"save_version": SAVE_VERSION,
		"slot_kind": slot_kind,
		"slot_index": slot_index,
		"saved_at_unix": saved_at_unix,
		"summary": summary,
		"payload": payload,
	}


func _build_world_payload() -> Dictionary:
	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		if GameManager != null and GameManager.has_method("get_runtime_world_snapshot"):
			return SaveDataUtils.sanitize_dictionary(GameManager.get_runtime_world_snapshot())

		return {}

	if tree.current_scene.scene_file_path != GAME_SCENE_PATH:
		if GameManager != null and GameManager.has_method("get_runtime_world_snapshot"):
			return SaveDataUtils.sanitize_dictionary(GameManager.get_runtime_world_snapshot())

		return {}

	var current_scene := tree.current_scene

	if current_scene.has_method("build_save_data"):
		var world_data: Variant = current_scene.call("build_save_data")

		if world_data is Dictionary:
			return (world_data as Dictionary).duplicate(true)

	return {}


func _can_build_snapshot() -> bool:
	if GameManager != null and GameManager.has_method("is_session_failed") and GameManager.is_session_failed():
		return false

	if _is_autosave_context_active():
		return true

	if GameManager != null and GameManager.has_method("has_runtime_world_snapshot"):
		return bool(GameManager.has_runtime_world_snapshot())

	return false


func _load_slot_data_from_disk(slot_kind: String, slot_index: int) -> Dictionary:
	var slot_path := _get_slot_path(slot_kind, slot_index)

	if not FileAccess.file_exists(slot_path):
		return {}

	var file := FileAccess.open(slot_path, FileAccess.READ)

	if file == null:
		return {}

	var parsed: Variant = JSON.parse_string(file.get_as_text())

	if not (parsed is Dictionary):
		return {}

	var data: Dictionary = parsed
	data["slot_kind"] = slot_kind
	data["slot_index"] = slot_index
	return data


func _is_slot_data_dead(slot_data: Dictionary) -> bool:
	var payload: Dictionary = SaveDataUtils.sanitize_dictionary(slot_data.get("payload", {}))
	var player_stats: Dictionary = SaveDataUtils.sanitize_dictionary(payload.get("player_stats", {}))
	return int(player_stats.get("hp", 1)) <= 0


func _get_existing_slots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var autosave_summary := get_slot_summary(AUTOSAVE_SLOT_KIND, 0)

	if not autosave_summary.is_empty():
		result.append(autosave_summary)

	for slot_index in range(1, MAX_MANUAL_SLOTS + 1):
		var summary := get_slot_summary(MANUAL_SLOT_KIND, slot_index)

		if summary.is_empty():
			continue

		result.append(summary)

	return result


func _get_slot_path(slot_kind: String, slot_index: int) -> String:
	if slot_kind == AUTOSAVE_SLOT_KIND:
		return AUTOSAVE_PATH

	return MANUAL_SLOT_PATH_TEMPLATE % slot_index


func _close_runtime_ui() -> void:
	if PhoneManager != null and PhoneManager.has_method("close_phone"):
		PhoneManager.close_phone()

	if DialogueManager != null and DialogueManager.has_method("hide_dialogue"):
		DialogueManager.hide_dialogue(true)

	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		return

	if tree.current_scene.has_method("close_transient_ui"):
		tree.current_scene.call("close_transient_ui")


func _reset_runtime_state() -> void:
	for entry in SNAPSHOT_TARGETS:
		var node_name := String(entry.get("node_name", ""))
		var target_node := get_node_or_null("/root/%s" % node_name)

		if target_node == null or not target_node.has_method("reset_state"):
			continue

		target_node.call("reset_state")


func _apply_payload(payload: Dictionary) -> void:
	for entry in SNAPSHOT_TARGETS:
		var node_name := String(entry.get("node_name", ""))
		var payload_key := String(entry.get("payload_key", ""))
		var target_node := get_node_or_null("/root/%s" % node_name)

		if target_node == null or not target_node.has_method("apply_save_data"):
			continue

		target_node.call("apply_save_data", SaveDataUtils.sanitize_dictionary(payload.get(payload_key, {})))


func _restore_world_state(world_payload: Dictionary) -> void:
	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		return

	if not tree.current_scene.has_method("apply_loaded_world_state"):
		return

	tree.current_scene.call("apply_loaded_world_state", world_payload)


func _change_scene_and_wait(scene_path: String) -> bool:
	var tree := get_tree()

	if tree == null:
		return false

	if tree.current_scene == null or tree.current_scene.scene_file_path != scene_path:
		var change_result := tree.change_scene_to_file(scene_path)

		if change_result != OK:
			return false

	for _attempt in range(30):
		await tree.process_frame

		if tree.current_scene != null and tree.current_scene.scene_file_path == scene_path:
			return true

	return tree.current_scene != null and tree.current_scene.scene_file_path == scene_path
