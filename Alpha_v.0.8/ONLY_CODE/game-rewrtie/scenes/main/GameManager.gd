extends Node

const DEFAULT_ROOM_SCENE_PATH := "res://scenes/rooms/apartament.tscn"
const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const GAME_OVER_SCENE_PATH := "res://scenes/main/game_over.tscn"

signal game_over_started(death_payload: Dictionary)

var _current_room_scene_path := DEFAULT_ROOM_SCENE_PATH
var _pending_target_portal_id: StringName = &""
var _game_root: Node = null
var _transition_in_progress := false
var _runtime_world_snapshot: Dictionary = {}
var _pending_runtime_world_restore: Dictionary = {}
var _session_failed := false
var _game_over_payload: Dictionary = {}


func _ready() -> void:
	_connect_player_stats_signals()


func change_scene(scene_path: String, target_portal_id: StringName = &"") -> void:
	if _session_failed:
		return

	if _transition_in_progress:
		return

	if scene_path.is_empty():
		push_warning("GameManager.change_scene received an empty scene path.")
		return

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("GameManager could not find scene: %s" % scene_path)
		return

	_current_room_scene_path = scene_path
	_pending_target_portal_id = target_portal_id
	_transition_in_progress = true

	if _game_root != null and is_instance_valid(_game_root):
		_game_root.call_deferred("load_room_scene", scene_path)
		return

	var tree := get_tree()

	if tree == null:
		_transition_in_progress = false
		return

	if tree.current_scene == null or tree.current_scene.scene_file_path != GAME_SCENE_PATH:
		if ResourceLoader.exists(GAME_SCENE_PATH, "PackedScene"):
			tree.change_scene_to_file(GAME_SCENE_PATH)
			return

	_transition_in_progress = false


func register_game_root(game_root: Node) -> void:
	_game_root = game_root


func unregister_game_root(game_root: Node) -> void:
	if _game_root == game_root:
		_game_root = null


func apply_spawn(player: Node2D, room_root: Node) -> void:
	if player == null or room_root == null:
		cancel_room_change()
		return

	_validate_room_transition_setup(room_root)

	var spawn_applied := false

	if not _pending_target_portal_id.is_empty():
		spawn_applied = _apply_portal_spawn(player, room_root, _pending_target_portal_id)

	if not spawn_applied:
		spawn_applied = _apply_scene_start_spawn(player, room_root)

	if not spawn_applied:
		push_warning("GameManager could not find a spawn target in scene: %s" % room_root.scene_file_path)

	_pending_target_portal_id = &""
	_transition_in_progress = false


func cancel_room_change() -> void:
	_pending_target_portal_id = &""
	_transition_in_progress = false


func is_transition_in_progress() -> bool:
	return _transition_in_progress


func get_current_room_scene_path() -> String:
	return _current_room_scene_path


func get_default_room_scene_path() -> String:
	return DEFAULT_ROOM_SCENE_PATH


func set_runtime_world_snapshot(snapshot: Dictionary) -> void:
	if _session_failed:
		return

	_runtime_world_snapshot = SaveDataUtils.sanitize_dictionary(snapshot)


func get_runtime_world_snapshot() -> Dictionary:
	return _runtime_world_snapshot.duplicate(true)


func has_runtime_world_snapshot() -> bool:
	return not _runtime_world_snapshot.is_empty()


func queue_runtime_world_restore(snapshot: Dictionary = {}) -> void:
	if _session_failed:
		return

	var resolved_snapshot: Dictionary = SaveDataUtils.sanitize_dictionary(snapshot)

	if resolved_snapshot.is_empty():
		resolved_snapshot = get_runtime_world_snapshot()

	_pending_runtime_world_restore = resolved_snapshot


func has_pending_runtime_world_restore() -> bool:
	return not _pending_runtime_world_restore.is_empty()


func consume_runtime_world_restore() -> Dictionary:
	var snapshot: Dictionary = _pending_runtime_world_restore.duplicate(true)
	_pending_runtime_world_restore.clear()
	return snapshot


func build_save_data() -> Dictionary:
	return {
		"current_room_scene_path": _current_room_scene_path,
	}


func apply_save_data(data: Dictionary) -> void:
	_session_failed = false
	_game_over_payload.clear()
	var next_room_scene_path := String(data.get("current_room_scene_path", DEFAULT_ROOM_SCENE_PATH)).strip_edges()

	if next_room_scene_path.is_empty():
		next_room_scene_path = DEFAULT_ROOM_SCENE_PATH

	_current_room_scene_path = next_room_scene_path
	_pending_target_portal_id = &""
	_transition_in_progress = false


func reset_state() -> void:
	_current_room_scene_path = DEFAULT_ROOM_SCENE_PATH
	_pending_target_portal_id = &""
	_transition_in_progress = false
	_runtime_world_snapshot.clear()
	_pending_runtime_world_restore.clear()
	_session_failed = false
	_game_over_payload.clear()


func is_session_failed() -> bool:
	return _session_failed


func get_game_over_payload() -> Dictionary:
	return _game_over_payload.duplicate(true)


func begin_game_over(death_payload: Dictionary = {}) -> bool:
	if _session_failed:
		return false

	_session_failed = true
	_game_over_payload = SaveDataUtils.sanitize_dictionary(death_payload)
	_pending_target_portal_id = &""
	_transition_in_progress = false
	_runtime_world_snapshot.clear()
	_pending_runtime_world_restore.clear()

	if GameTime != null and GameTime.has_method("set_clock_paused"):
		GameTime.set_clock_paused(true)

	_close_runtime_ui_for_session_end()
	game_over_started.emit(_game_over_payload.duplicate(true))
	call_deferred("_open_game_over_scene")
	return true


func _apply_portal_spawn(player: Node2D, room_root: Node, target_portal_id: StringName) -> bool:
	if target_portal_id.is_empty():
		return false

	var portal := _find_portal_by_id(room_root, target_portal_id)

	if portal == null:
		push_warning(
			"GameManager could not find portal '%s' in scene: %s" % [String(target_portal_id), room_root.scene_file_path]
		)
		return false

	portal.apply_spawn_to(player)
	return true


func _apply_scene_start_spawn(player: Node2D, room_root: Node) -> bool:
	var start_point := _find_scene_start_point(room_root)

	if start_point == null:
		push_warning("GameManager could not find SceneStartPoint in scene: %s" % room_root.scene_file_path)
		return false

	if player.has_method("apply_spawn_world_position"):
		player.call("apply_spawn_world_position", start_point.get_spawn_position(), start_point.get_spawn_facing())
	else:
		player.global_position = start_point.get_spawn_position()

		if player.has_method("set_facing_direction"):
			player.call("set_facing_direction", start_point.get_spawn_facing())

	return true


func _validate_room_transition_setup(room_root: Node) -> void:
	var seen_portal_ids: Dictionary = {}
	var start_point_count := 0
	start_point_count = _validate_room_transition_setup_recursive(room_root, seen_portal_ids, start_point_count)

	if start_point_count == 0:
		push_warning("Scene is missing SceneStartPoint: %s" % room_root.scene_file_path)
	elif start_point_count > 1:
		push_warning("Scene has more than one SceneStartPoint: %s" % room_root.scene_file_path)


func _validate_room_transition_setup_recursive(node: Node, seen_portal_ids: Dictionary, start_point_count: int) -> int:
	if node is PortalEndpoint:
		var portal := node as PortalEndpoint
		var portal_id := portal.get_portal_id()

		if portal_id.is_empty():
			push_warning("Portal is missing portal_id: %s" % node.get_path())
		elif seen_portal_ids.has(portal_id):
			push_warning("Duplicate portal_id '%s' in scene %s" % [String(portal_id), _current_room_scene_path])
		else:
			seen_portal_ids[portal_id] = true

	if node is SceneStartPoint:
		start_point_count += 1

	for child in node.get_children():
		start_point_count = _validate_room_transition_setup_recursive(child, seen_portal_ids, start_point_count)

	return start_point_count


func _find_portal_by_id(room_root: Node, target_portal_id: StringName) -> PortalEndpoint:
	if room_root is PortalEndpoint:
		var root_portal := room_root as PortalEndpoint

		if root_portal.get_portal_id() == target_portal_id:
			return root_portal

	for child in room_root.get_children():
		var nested_portal := _find_portal_by_id(child, target_portal_id)

		if nested_portal != null:
			return nested_portal

	return null


func _find_scene_start_point(room_root: Node) -> SceneStartPoint:
	if room_root is SceneStartPoint:
		return room_root as SceneStartPoint

	for child in room_root.get_children():
		var nested_start_point := _find_scene_start_point(child)

		if nested_start_point != null:
			return nested_start_point

	return null


func _connect_player_stats_signals() -> void:
	var player_stats := get_node_or_null("/root/PlayerStats")

	if player_stats == null or not player_stats.has_signal(&"death_occurred"):
		return

	if not player_stats.death_occurred.is_connected(_on_player_death_occurred):
		player_stats.death_occurred.connect(_on_player_death_occurred)


func _on_player_death_occurred(death_payload: Dictionary) -> void:
	begin_game_over(death_payload)


func _close_runtime_ui_for_session_end() -> void:
	if PhoneManager != null and PhoneManager.has_method("close_phone"):
		PhoneManager.close_phone()

	if DialogueManager != null and DialogueManager.has_method("hide_dialogue"):
		DialogueManager.hide_dialogue(true)

	var tree := get_tree()

	if tree == null or tree.current_scene == null:
		return

	if tree.current_scene.has_method("close_transient_ui"):
		tree.current_scene.call("close_transient_ui")


func _open_game_over_scene() -> void:
	if not _session_failed:
		return

	var tree := get_tree()

	if tree == null:
		return

	if tree.current_scene != null and tree.current_scene.scene_file_path == GAME_OVER_SCENE_PATH:
		return

	if not ResourceLoader.exists(GAME_OVER_SCENE_PATH, "PackedScene"):
		push_warning("GameManager could not find the game over scene: %s" % GAME_OVER_SCENE_PATH)
		return

	tree.change_scene_to_file(GAME_OVER_SCENE_PATH)
