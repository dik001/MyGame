extends Node2D

const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)
const RUNA_PROLOGUE_SCENE := preload("res://scenes/story/runa_prologue.tscn")

@onready var current_room_container: Node2D = $CurrentRoom
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var _current_room: Node2D
var _active_story_overlay: CanvasLayer


func _ready() -> void:
	call_deferred("_bootstrap_game")


func _exit_tree() -> void:
	if _current_room != null and is_instance_valid(_current_room) and player != null and is_instance_valid(player):
		GameManager.remember_player_position(_current_room.scene_file_path, player.global_position)

	if music_player != null and is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null

	GameManager.unregister_game_root(self)


func load_room_scene(scene_path: String) -> void:
	var resolved_scene_path := scene_path

	if resolved_scene_path.is_empty():
		resolved_scene_path = GameManager.get_current_room_scene_path()

	if resolved_scene_path.is_empty():
		resolved_scene_path = GameManager.get_default_room_scene_path()

	if not ResourceLoader.exists(resolved_scene_path, "PackedScene"):
		push_warning("Game could not find room scene: %s" % resolved_scene_path)
		GameManager.cancel_room_change()
		return

	if _current_room != null and is_instance_valid(_current_room):
		GameManager.remember_player_position(_current_room.scene_file_path, player.global_position)
		current_room_container.remove_child(_current_room)
		_current_room.queue_free()
		_current_room = null

	var room_scene := load(resolved_scene_path) as PackedScene

	if room_scene == null:
		push_warning("Game could not load room scene: %s" % resolved_scene_path)
		GameManager.cancel_room_change()
		return

	var room_instance := room_scene.instantiate() as Node2D

	if room_instance == null:
		push_warning("Game could not instantiate room scene: %s" % resolved_scene_path)
		GameManager.cancel_room_change()
		return

	current_room_container.add_child(room_instance)
	_current_room = room_instance
	_configure_player_for_room(room_instance)
	GameManager.apply_spawn(player, room_instance)
	_maybe_start_story(room_instance)


func _bootstrap_game() -> void:
	_apply_launch_window_size()
	GameManager.register_game_root(self)
	load_room_scene(GameManager.get_current_room_scene_path())


func _configure_player_for_room(room_instance: Node2D) -> void:
	var walk_tile_map := room_instance.get_node_or_null("Floor") as TileMapLayer

	if player != null and is_instance_valid(player):
		player.set_walk_tilemap(walk_tile_map)
		player.set_input_locked(false)


func _maybe_start_story(room_instance: Node2D) -> void:
	if room_instance == null or player == null or not is_instance_valid(player):
		return

	if StoryState.has_seen_runa_prologue():
		return

	if room_instance.scene_file_path != GameManager.get_default_room_scene_path():
		return

	if _active_story_overlay != null and is_instance_valid(_active_story_overlay):
		return

	var overlay := RUNA_PROLOGUE_SCENE.instantiate() as CanvasLayer

	if overlay == null:
		push_warning("Game could not instantiate the Runa prologue scene.")
		return

	add_child(overlay)
	_active_story_overlay = overlay

	if not overlay.tree_exited.is_connected(_on_story_overlay_tree_exited):
		overlay.tree_exited.connect(_on_story_overlay_tree_exited)

	if overlay.has_method("start_prologue"):
		overlay.call_deferred("start_prologue", player, hud, room_instance)


func _on_story_overlay_tree_exited() -> void:
	_active_story_overlay = null


func _apply_launch_window_size() -> void:
	var window := get_window()

	if window == null:
		return

	window.mode = Window.MODE_WINDOWED
	window.min_size = TARGET_WINDOW_SIZE
	window.size = TARGET_WINDOW_SIZE
	call_deferred("_reapply_launch_window_size")

func _reapply_launch_window_size() -> void:
	var window := get_window()

	if window == null or not is_instance_valid(window):
		return

	if window.size != TARGET_WINDOW_SIZE:
		window.size = TARGET_WINDOW_SIZE
