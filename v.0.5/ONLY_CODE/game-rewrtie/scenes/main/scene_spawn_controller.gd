extends Node

@export var player_path: NodePath


func _ready() -> void:
	call_deferred("_apply_pending_spawn")


func _apply_pending_spawn() -> void:
	if player_path.is_empty():
		push_warning("SceneSpawnController.player_path is not set.")
		return

	var transition_state := get_node_or_null("/root/SceneTransitionState")

	if transition_state == null:
		return

	var current_scene := get_tree().current_scene

	if current_scene == null:
		return

	var spawn_path: NodePath = transition_state.consume_pending_spawn(current_scene.scene_file_path)

	if spawn_path.is_empty():
		return

	var player := get_node_or_null(player_path) as Node2D

	if player == null:
		push_warning("SceneSpawnController could not find the player node.")
		return

	var spawn_marker := current_scene.get_node_or_null(spawn_path) as Node2D

	if spawn_marker == null:
		push_warning("SceneSpawnController could not find spawn marker: %s" % String(spawn_path))
		return

	player.global_position = spawn_marker.global_position
