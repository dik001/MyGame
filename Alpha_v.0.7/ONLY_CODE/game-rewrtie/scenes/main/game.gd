extends Node2D

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")

const RUNA_PROLOGUE_SCENE := preload("res://scenes/story/runa_prologue.tscn")

@onready var current_room_container: Node2D = $CurrentRoom
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var _current_room: Node2D
var _active_story_overlay: CanvasLayer


func _ready() -> void:
	_configure_music_player()
	call_deferred("_bootstrap_game")


func _exit_tree() -> void:
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
	GameManager.register_game_root(self)
	load_room_scene(GameManager.get_current_room_scene_path())


func build_save_data() -> Dictionary:
	var player_snapshot: Dictionary = {}

	if player != null and is_instance_valid(player) and player.has_method("build_save_data"):
		var snapshot_variant: Variant = player.call("build_save_data")

		if snapshot_variant is Dictionary:
			player_snapshot = (snapshot_variant as Dictionary).duplicate(true)

	return {
		"room_scene_path": GameManager.get_current_room_scene_path(),
		"player": player_snapshot,
	}


func apply_loaded_world_state(world_data: Dictionary) -> void:
	var room_scene_path := String(world_data.get("room_scene_path", GameManager.get_default_room_scene_path())).strip_edges()

	if room_scene_path.is_empty():
		room_scene_path = GameManager.get_default_room_scene_path()

	GameManager.apply_save_data({
		"current_room_scene_path": room_scene_path,
	})
	load_room_scene(room_scene_path)

	if player != null and is_instance_valid(player) and player.has_method("apply_save_data"):
		player.call("apply_save_data", SaveDataUtils.sanitize_dictionary(world_data.get("player", {})))

	if inventory_ui != null and is_instance_valid(inventory_ui) and inventory_ui.has_method("force_close"):
		inventory_ui.call("force_close")


func close_transient_ui() -> void:
	if inventory_ui != null and is_instance_valid(inventory_ui) and inventory_ui.has_method("force_close"):
		inventory_ui.call("force_close")

	if _active_story_overlay != null and is_instance_valid(_active_story_overlay):
		_active_story_overlay.queue_free()
		_active_story_overlay = null


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


func _configure_music_player() -> void:
	if music_player == null or not is_instance_valid(music_player):
		return

	music_player.bus = GameSettings.get_music_bus_name()
