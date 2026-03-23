extends Node

const DEFAULT_ROOM_SCENE_PATH := "res://scenes/rooms/apartament.tscn"
const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const FALLBACK_SPAWN_MARKERS: Array[StringName] = [
	&"from_entrance",
	&"from_apartment",
	&"from_elevator",
	&"from_town",
	&"from_shop",
]

var _current_room_scene_path := DEFAULT_ROOM_SCENE_PATH
var _pending_spawn_name: StringName = &""
var _saved_player_positions: Dictionary = {}
var _game_root: Node = null
var _transition_in_progress := false


func change_scene(scene_path: String, spawn_name: StringName) -> void:
	if _transition_in_progress:
		return

	if scene_path.is_empty():
		push_warning("GameManager.change_scene received an empty scene path.")
		return

	if not ResourceLoader.exists(scene_path, "PackedScene"):
		push_warning("GameManager could not find scene: %s" % scene_path)
		return

	_current_room_scene_path = scene_path
	_pending_spawn_name = spawn_name
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


func remember_player_position(scene_path: String, player_position: Vector2) -> void:
	if scene_path.is_empty():
		return

	_saved_player_positions[scene_path] = player_position


func apply_spawn(player: Node2D, room_root: Node) -> void:
	if player == null or room_root == null:
		cancel_room_change()
		return

	var spawn_applied := false

	if not _pending_spawn_name.is_empty():
		spawn_applied = _apply_marker_spawn(player, room_root, _pending_spawn_name)

	if not spawn_applied:
		spawn_applied = _apply_saved_position(player)

	if not spawn_applied:
		spawn_applied = _apply_fallback_spawn(player, room_root)

	_pending_spawn_name = &""
	_transition_in_progress = false


func cancel_room_change() -> void:
	_pending_spawn_name = &""
	_transition_in_progress = false


func is_transition_in_progress() -> bool:
	return _transition_in_progress


func get_current_room_scene_path() -> String:
	return _current_room_scene_path


func get_default_room_scene_path() -> String:
	return DEFAULT_ROOM_SCENE_PATH


func _apply_saved_position(player: Node2D) -> bool:
	if not _saved_player_positions.has(_current_room_scene_path):
		return false

	var saved_position: Variant = _saved_player_positions.get(_current_room_scene_path)

	if not (saved_position is Vector2):
		return false

	player.global_position = saved_position
	return true


func _apply_fallback_spawn(player: Node2D, room_root: Node) -> bool:
	for marker_name in FALLBACK_SPAWN_MARKERS:
		if _apply_marker_spawn(player, room_root, marker_name):
			return true

	return false


func _apply_marker_spawn(player: Node2D, room_root: Node, marker_name: StringName) -> bool:
	if marker_name.is_empty():
		return false

	var marker := room_root.get_node_or_null(String(marker_name)) as Node2D

	if marker == null:
		return false

	player.global_position = marker.global_position
	return true
