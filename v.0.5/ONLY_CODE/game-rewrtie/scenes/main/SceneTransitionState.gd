extends Node

var _pending_scene_path := ""
var _pending_spawn_path := NodePath()


func set_pending_spawn(target_scene_path: String, target_spawn_path: NodePath) -> void:
	_pending_scene_path = target_scene_path
	_pending_spawn_path = target_spawn_path


func consume_pending_spawn(current_scene_path: String) -> NodePath:
	if _pending_scene_path != current_scene_path:
		return NodePath()

	var spawn_path := _pending_spawn_path
	clear_pending_spawn()
	return spawn_path


func clear_pending_spawn() -> void:
	_pending_scene_path = ""
	_pending_spawn_path = NodePath()
