extends Node2D

const WorldGridScene = preload("res://scenes/main/WorldGrid.gd")

const RUNA_PROLOGUE_SCENE := preload("res://scenes/story/runa_prologue.tscn")
const BLACKOUT_FADE_IN_DURATION := 0.42
const BLACKOUT_FADE_OUT_DURATION := 0.52
const BLACKOUT_HOLD_DURATION := 0.12
const ELEVATOR_ROOM_SCENE_PATH := "res://scenes/rooms/elevator.tscn"

@onready var current_room_container: Node2D = $CurrentRoom
@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var inventory_ui: CanvasLayer = $InventoryUI
@onready var music_player: AudioStreamPlayer = $MusicPlayer

var _current_room: Node2D
var _world_grid: WorldGrid
var _active_story_overlay: CanvasLayer
var _stats: PlayerStatsState = null
var _blackout_retry_pending := false
var _blackout_sequence_running := false
var _blackout_overlay: CanvasLayer = null
var _blackout_fade_rect: ColorRect = null


func _ready() -> void:
	_ensure_world_grid()
	_configure_music_player()
	_resolve_stats()
	_connect_stats_signals()
	call_deferred("_bootstrap_game")


func _process(_delta: float) -> void:
	if _blackout_sequence_running:
		return

	_resolve_stats()

	if _stats == null:
		return

	if _stats.has_pending_forced_blackout():
		_blackout_retry_pending = true

	if not _blackout_retry_pending:
		return

	_attempt_forced_blackout()


func _exit_tree() -> void:
	if music_player != null and is_instance_valid(music_player):
		music_player.stop()
		music_player.stream = null

	if GameManager != null and GameManager.has_method("set_runtime_world_snapshot"):
		GameManager.set_runtime_world_snapshot(build_save_data())

	GameManager.unregister_game_root(self)


func load_room_scene(scene_path: String) -> void:
	var resolved_scene_path := scene_path

	if resolved_scene_path.is_empty():
		resolved_scene_path = GameManager.get_current_room_scene_path()

	if resolved_scene_path.is_empty():
		resolved_scene_path = GameManager.get_default_room_scene_path()

	if not ResourceLoader.exists(resolved_scene_path, "PackedScene"):
		var fallback_scene_path := GameManager.get_default_room_scene_path()

		if resolved_scene_path != fallback_scene_path and ResourceLoader.exists(fallback_scene_path, "PackedScene"):
			push_warning(
				"Game could not find room scene: %s. Falling back to default room: %s"
				% [resolved_scene_path, fallback_scene_path]
			)
			resolved_scene_path = fallback_scene_path
		else:
			push_warning("Game could not find room scene: %s" % resolved_scene_path)
			GameManager.cancel_room_change()
			return

	if _current_room != null and is_instance_valid(_current_room):
		current_room_container.remove_child(_current_room)
		_current_room.queue_free()
		_current_room = null

	var room_scene := load(resolved_scene_path) as PackedScene

	if room_scene == null:
		var fallback_scene_path := GameManager.get_default_room_scene_path()

		if resolved_scene_path != fallback_scene_path and ResourceLoader.exists(fallback_scene_path, "PackedScene"):
			push_warning(
				"Game could not load room scene: %s. Falling back to default room: %s"
				% [resolved_scene_path, fallback_scene_path]
			)
			room_scene = load(fallback_scene_path) as PackedScene
			resolved_scene_path = fallback_scene_path

		if room_scene == null:
			push_warning("Game could not load room scene: %s" % resolved_scene_path)
			GameManager.cancel_room_change()
			return

	var room_instance := room_scene.instantiate() as Node2D

	if room_instance == null:
		var fallback_scene_path := GameManager.get_default_room_scene_path()

		if resolved_scene_path != fallback_scene_path and ResourceLoader.exists(fallback_scene_path, "PackedScene"):
			push_warning(
				"Game could not instantiate room scene: %s. Falling back to default room: %s"
				% [resolved_scene_path, fallback_scene_path]
			)
			var fallback_room_scene := load(fallback_scene_path) as PackedScene

			if fallback_room_scene != null:
				room_instance = fallback_room_scene.instantiate() as Node2D
				resolved_scene_path = fallback_scene_path

		if room_instance == null:
			push_warning("Game could not instantiate room scene: %s" % resolved_scene_path)
			GameManager.cancel_room_change()
			return

	current_room_container.add_child(room_instance)
	_current_room = room_instance

	if resolved_scene_path != GameManager.get_current_room_scene_path():
		GameManager.apply_save_data({
			"current_room_scene_path": resolved_scene_path,
		})

	_configure_world_grid(room_instance)
	_configure_player_for_room(room_instance)
	GameManager.apply_spawn(player, room_instance)

	if player != null and is_instance_valid(player) and player.has_method("sync_to_world_position"):
		player.call("sync_to_world_position", player.global_position, true)

	_apply_room_movement_rules(room_instance)

	if PlayerMentalState != null and PlayerMentalState.has_method("refresh_context_modifiers"):
		PlayerMentalState.refresh_context_modifiers(true)

	_maybe_start_story(room_instance)
	_queue_blackout_retry_if_needed()


func _bootstrap_game() -> void:
	GameManager.register_game_root(self)
	var pending_runtime_restore: Dictionary = (
		GameManager.consume_runtime_world_restore()
		if GameManager != null and GameManager.has_method("consume_runtime_world_restore")
		else {}
	)

	if not pending_runtime_restore.is_empty():
		apply_loaded_world_state(pending_runtime_restore)
	else:
		load_room_scene(GameManager.get_current_room_scene_path())

	_refresh_sleep_runtime_state(false, true)
	_check_for_loaded_death_state()


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

	_refresh_sleep_runtime_state(false, true)

	if PlayerMentalState != null and PlayerMentalState.has_method("refresh_context_modifiers"):
		PlayerMentalState.refresh_context_modifiers(true)


func close_transient_ui() -> void:
	if inventory_ui != null and is_instance_valid(inventory_ui) and inventory_ui.has_method("force_close"):
		inventory_ui.call("force_close")

	if _active_story_overlay != null and is_instance_valid(_active_story_overlay):
		_active_story_overlay.queue_free()
		_active_story_overlay = null

	for node_variant in get_tree().get_nodes_in_group("runtime_transient_ui_owner"):
		var node := node_variant as Node

		if node == null or not is_instance_valid(node):
			continue

		if not is_ancestor_of(node):
			continue

		if node.has_method("force_close_transient_ui"):
			node.call("force_close_transient_ui")


func _check_for_loaded_death_state() -> void:
	_resolve_stats()

	if _stats == null:
		return

	if int(_stats.get_stats().get("hp", 0)) > 0:
		return

	if GameManager != null and GameManager.has_method("begin_game_over"):
		GameManager.begin_game_over({
			"cause": "loaded_dead_save",
			"tick_name": "loaded_dead_save",
			"absolute_minutes": (
				GameTime.get_absolute_minutes()
				if GameTime != null and GameTime.has_method("get_absolute_minutes")
				else 0
			),
			"day": GameTime.get_day() if GameTime != null and GameTime.has_method("get_day") else 1,
			"room_scene_path": GameManager.get_current_room_scene_path(),
			"stats": _stats.get_stats(),
		})


func _configure_player_for_room(room_instance: Node2D) -> void:
	var walk_tile_map := room_instance.get_node_or_null("Floor") as TileMapLayer

	if player != null and is_instance_valid(player):
		player.set_walk_tilemap(walk_tile_map)
		player.set_world_grid(_world_grid)
		player.set_input_locked(false)
		if player.has_method("set_movement_locked"):
			player.set_movement_locked(false)


func _configure_world_grid(room_instance: Node2D) -> void:
	_ensure_world_grid()

	if _world_grid == null:
		return

	var walk_tile_map := room_instance.get_node_or_null("Floor") as TileMapLayer
	_world_grid.configure_for_room(room_instance, walk_tile_map)


func _apply_room_movement_rules(room_instance: Node2D) -> void:
	if player == null or not is_instance_valid(player) or not player.has_method("set_movement_locked"):
		return

	var should_lock_movement: bool = room_instance != null and room_instance.scene_file_path == ELEVATOR_ROOM_SCENE_PATH
	player.set_movement_locked(should_lock_movement)


func _ensure_world_grid() -> void:
	if _world_grid != null and is_instance_valid(_world_grid):
		return

	_world_grid = WorldGridScene.new() as WorldGrid

	if _world_grid == null:
		return

	_world_grid.name = "WorldGrid"
	add_child(_world_grid)


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


func _resolve_stats() -> void:
	if _stats != null and is_instance_valid(_stats):
		return

	_stats = get_node_or_null("/root/PlayerStats") as PlayerStatsState


func _connect_stats_signals() -> void:
	if _stats == null:
		return

	if not _stats.forced_blackout_requested.is_connected(_on_forced_blackout_requested):
		_stats.forced_blackout_requested.connect(_on_forced_blackout_requested)


func _on_forced_blackout_requested() -> void:
	_blackout_retry_pending = true


func _refresh_sleep_runtime_state(
	schedule_blackout_retry := true,
	force_condition_sync := false
) -> void:
	_resolve_stats()

	if _stats == null or not _stats.has_method("refresh_sleep_runtime_state"):
		return

	_stats.refresh_sleep_runtime_state(false, force_condition_sync)

	if _stats.has_method("refresh_hunger_runtime_state"):
		_stats.refresh_hunger_runtime_state(false, force_condition_sync)

	if schedule_blackout_retry:
		_queue_blackout_retry_if_needed()


func _queue_blackout_retry_if_needed() -> void:
	_resolve_stats()

	if _stats != null and _stats.has_pending_forced_blackout():
		_blackout_retry_pending = true


func _attempt_forced_blackout() -> void:
	_resolve_stats()

	if _stats == null or not _stats.has_pending_forced_blackout():
		_blackout_retry_pending = false
		return

	_close_interruptible_blackout_ui()

	if _is_blackout_blocked():
		return

	_blackout_sequence_running = true
	_blackout_retry_pending = false
	call_deferred("_run_forced_blackout_sequence")


func _close_interruptible_blackout_ui() -> void:
	if inventory_ui != null and is_instance_valid(inventory_ui) and inventory_ui.visible and inventory_ui.has_method("force_close"):
		inventory_ui.call("force_close")

	if PhoneManager != null and PhoneManager.has_method("is_phone_open") and PhoneManager.is_phone_open():
		PhoneManager.close_phone()


func _is_blackout_blocked() -> bool:
	if _current_room == null or not is_instance_valid(_current_room):
		return true

	if GameManager != null and GameManager.has_method("is_transition_in_progress") and GameManager.is_transition_in_progress():
		return true

	if _active_story_overlay != null and is_instance_valid(_active_story_overlay):
		return true

	if DialogueManager != null and DialogueManager.has_method("is_dialogue_visible") and DialogueManager.is_dialogue_visible():
		return true

	if _has_open_sleep_dialog():
		return true

	if inventory_ui != null and is_instance_valid(inventory_ui) and inventory_ui.visible:
		return true

	if PhoneManager != null and PhoneManager.has_method("is_phone_open") and PhoneManager.is_phone_open():
		return true

	if player != null and is_instance_valid(player) and player.has_method("is_input_locked") and player.is_input_locked():
		return true

	if GameTime != null and GameTime.has_method("is_clock_paused") and GameTime.is_clock_paused():
		return true

	return false


func _has_open_sleep_dialog(root_node: Node = null) -> bool:
	var node_to_check := root_node

	if node_to_check == null:
		node_to_check = get_tree().current_scene

	if node_to_check == null:
		return false

	if node_to_check is SleepDialog:
		return true

	for child in node_to_check.get_children():
		if _has_open_sleep_dialog(child):
			return true

	return false


func _run_forced_blackout_sequence() -> void:
	_resolve_stats()

	if _stats == null or not _stats.begin_forced_blackout():
		_blackout_sequence_running = false
		_queue_blackout_retry_if_needed()
		return

	_set_blackout_modal_state(true)
	var sleep_started_absolute_minutes := GameTime.get_absolute_minutes()
	var sleep_effect_config := _stats.get_sleep_effect_config()
	var sleep_effects := SleepMath.calculate_sleep_effects(
		_stats,
		_stats.forced_blackout_sleep_minutes,
		float(sleep_effect_config.get("energy_per_hour", 0.0)),
		int(sleep_effect_config.get("hp_per_hour", 0)),
		int(sleep_effect_config.get("hunger_per_hour", 0)),
		float(sleep_effect_config.get("min_energy_restore_multiplier_at_zero_hp", 1.0))
	)

	await _tween_blackout_alpha(1.0, BLACKOUT_FADE_IN_DURATION)
	await get_tree().create_timer(BLACKOUT_HOLD_DURATION).timeout

	GameTime.mark_sleep_started()
	_stats.register_sleep(_stats.forced_blackout_sleep_minutes, sleep_started_absolute_minutes)
	_stats.apply_action_tick(&"forced_blackout_sleep", {
		"energy": float(sleep_effects.get("energy_change", 0.0)),
		"hp": int(sleep_effects.get("hp_change", 0)),
		"hunger": int(sleep_effects.get("hunger_change", 0)),
	})
	GameTime.advance_minutes(_stats.forced_blackout_sleep_minutes)

	if PlayerMentalState != null and PlayerMentalState.has_method("apply_event"):
		var blackout_multiplier := clampf(
			float(_stats.forced_blackout_sleep_minutes) / float(max(1, _stats.full_reset_sleep_minutes)),
			0.65,
			1.1
		)
		PlayerMentalState.apply_event(&"forced_blackout_sleep_completed", {
			"source": "forced_blackout",
			"multiplier": blackout_multiplier,
			"sleep_duration_minutes": _stats.forced_blackout_sleep_minutes,
		})

	_clear_rest_recoverable_conditions()

	await _tween_blackout_alpha(0.0, BLACKOUT_FADE_OUT_DURATION)

	if _blackout_fade_rect != null and is_instance_valid(_blackout_fade_rect):
		_blackout_fade_rect.visible = false

	_set_blackout_modal_state(false)
	_stats.finish_forced_blackout()
	_stats.refresh_sleep_runtime_state(false)
	_blackout_sequence_running = false
	_queue_blackout_retry_if_needed()


func _set_blackout_modal_state(is_active: bool) -> void:
	if player != null and is_instance_valid(player) and player.has_method("set_input_locked"):
		player.set_input_locked(is_active)

	if hud != null and is_instance_valid(hud) and hud.has_method("set_clock_paused"):
		hud.set_clock_paused(is_active)


func _ensure_blackout_overlay() -> void:
	if _blackout_overlay != null and is_instance_valid(_blackout_overlay) and _blackout_fade_rect != null and is_instance_valid(_blackout_fade_rect):
		return

	_blackout_overlay = CanvasLayer.new()
	_blackout_overlay.name = "ForcedBlackoutOverlay"
	_blackout_overlay.layer = 20
	add_child(_blackout_overlay)

	_blackout_fade_rect = ColorRect.new()
	_blackout_fade_rect.name = "Fade"
	_blackout_fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_blackout_fade_rect.offset_left = 0.0
	_blackout_fade_rect.offset_top = 0.0
	_blackout_fade_rect.offset_right = 0.0
	_blackout_fade_rect.offset_bottom = 0.0
	_blackout_fade_rect.color = Color(0.0, 0.0, 0.0, 0.0)
	_blackout_fade_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_blackout_fade_rect.visible = false
	_blackout_overlay.add_child(_blackout_fade_rect)


func _tween_blackout_alpha(target_alpha: float, duration: float) -> void:
	_ensure_blackout_overlay()

	if _blackout_fade_rect == null or not is_instance_valid(_blackout_fade_rect):
		return

	_blackout_fade_rect.visible = true
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(
		Callable(self, "_set_blackout_alpha"),
		_blackout_fade_rect.color.a,
		clampf(target_alpha, 0.0, 1.0),
		duration
	)
	await tween.finished


func _set_blackout_alpha(alpha: float) -> void:
	if _blackout_fade_rect == null or not is_instance_valid(_blackout_fade_rect):
		return

	var fade_color := _blackout_fade_rect.color
	fade_color.a = clampf(alpha, 0.0, 1.0)
	_blackout_fade_rect.color = fade_color


func _clear_rest_recoverable_conditions() -> void:
	var freelance_state := get_node_or_null("/root/FreelanceState")

	if freelance_state == null:
		return

	if not freelance_state.has_method("remove_condition_by_rest"):
		return

	freelance_state.call("remove_condition_by_rest", &"eye_strain")
