extends Node2D

const FOOD_SCENE := preload("res://scenes/minigames/food.tscn")
const ENEMY_SCENE := preload("res://scenes/minigames/enemy_snake.tscn")
const DESKTOP_SCENE_PATH := "res://scenes/minigames/computer_desktop.tscn"
const SLITHARIO_SCENE_PATH := "res://scenes/minigames/slithario.tscn"
const GAME_OVER_RESTART_DELAY := 1.25

@export var arena_size := Vector2(7200.0, 4200.0)
@export var target_food_count: int = 80
@export var enemy_count: int = 10
@export var enemy_respawn_delay: float = 2.5
@export var food_spawn_padding: float = 140.0
@export var minimum_food_distance_from_player: float = 120.0
@export var minimum_food_spacing: float = 90.0
@export var minimum_enemy_distance_from_player: float = 900.0
@export var minimum_enemy_spacing: float = 520.0

@onready var arena_background: Polygon2D = $Arena/ArenaBackground
@onready var arena_border: Line2D = $Arena/ArenaBorder
@onready var foods: Node2D = $Foods
@onready var enemies: Node2D = $Enemies
@onready var player = $PlayerSnake
@onready var score_label: Label = $UI/MarginContainer/VBoxContainer/ScoreLabel
@onready var hint_label: Label = $UI/MarginContainer/VBoxContainer/HintLabel
@onready var game_over_overlay: Control = $UI/GameOverOverlay

var score := 0
var arena_rect := Rect2()
var active_foods: Array[Area2D] = []
var rng := RandomNumberGenerator.new()
var is_game_over := false
var _reward_granted := false
var _session_end_started := false
var _food_count_refresh_queued := false


func _ready() -> void:
	rng.randomize()
	arena_rect = Rect2(-arena_size * 0.5, arena_size)

	_draw_arena()
	player.setup(arena_rect, arena_rect.get_center())
	game_over_overlay.visible = false

	if not player.food_collected.is_connected(_on_player_food_collected):
		player.food_collected.connect(_on_player_food_collected)

	if not player.died.is_connected(_on_player_died):
		player.died.connect(_on_player_died)

	_ensure_enemy_count()
	_update_ui()
	_ensure_food_count()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport: Viewport = get_viewport()

		if viewport != null:
			viewport.set_input_as_handled()

		_exit_to_desktop()


func _draw_arena() -> void:
	var half_size := arena_size * 0.5
	var corners := PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y)
	])

	arena_background.polygon = corners
	arena_border.points = PackedVector2Array([
		corners[0],
		corners[1],
		corners[2],
		corners[3],
		corners[0]
	])


func _spawn_food() -> void:
	_spawn_food_at_position(_get_food_spawn_position())


func _get_food_spawn_position() -> Vector2:
	var spawn_rect := arena_rect.grow(-food_spawn_padding)

	if spawn_rect.size.x <= 0.0 or spawn_rect.size.y <= 0.0:
		return arena_rect.get_center()

	for _attempt in range(80):
		var candidate := Vector2(
			rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
			rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
		)

		if _is_food_position_valid(candidate):
			return candidate

	return spawn_rect.get_center()


func _on_player_food_collected(collected_food: Area2D) -> void:
	if is_game_over:
		return

	_remove_food_reference(collected_food)
	score += 1
	_update_ui()
	_queue_food_count_refresh()


func _on_enemy_food_collected(collected_food: Area2D) -> void:
	if is_game_over:
		return

	_remove_food_reference(collected_food)
	_queue_food_count_refresh()


func _on_enemy_died(_enemy, drop_positions) -> void:
	if is_game_over:
		return

	call_deferred("_spawn_enemy_drop_foods", drop_positions)
	_schedule_enemy_respawn()


func _ensure_enemy_count() -> void:
	while _count_alive_enemies() < enemy_count:
		_spawn_enemy()


func _spawn_enemy() -> void:
	var enemy = ENEMY_SCENE.instantiate()
	var spawn_position := _get_enemy_spawn_position()

	enemies.add_child(enemy)
	enemy.setup(arena_rect, spawn_position, foods, player)

	if not enemy.food_collected.is_connected(_on_enemy_food_collected):
		enemy.food_collected.connect(_on_enemy_food_collected)

	if not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died)


func _schedule_enemy_respawn() -> void:
	_respawn_enemy_after_delay()


func _respawn_enemy_after_delay() -> void:
	await get_tree().create_timer(enemy_respawn_delay).timeout

	if is_game_over:
		return

	_ensure_enemy_count()


func _ensure_food_count() -> void:
	_cleanup_food_references()

	while active_foods.size() < target_food_count:
		_spawn_food()


func _cleanup_food_references() -> void:
	var valid_foods: Array[Area2D] = []

	for food in active_foods:
		if is_instance_valid(food):
			valid_foods.append(food)

	active_foods = valid_foods


func _remove_food_reference(food: Area2D) -> void:
	_cleanup_food_references()
	active_foods.erase(food)


func _spawn_food_at_position(world_position: Vector2) -> void:
	var food = FOOD_SCENE.instantiate()

	foods.add_child(food)
	food.setup_at(world_position)
	active_foods.append(food as Area2D)


func _get_enemy_spawn_position() -> Vector2:
	var spawn_rect := arena_rect.grow(-food_spawn_padding * 2.0)

	if spawn_rect.size.x <= 0.0 or spawn_rect.size.y <= 0.0:
		return arena_rect.get_center()

	for _attempt in range(120):
		var candidate := Vector2(
			rng.randf_range(spawn_rect.position.x, spawn_rect.end.x),
			rng.randf_range(spawn_rect.position.y, spawn_rect.end.y)
		)

		if _is_enemy_spawn_position_valid(candidate):
			return candidate

	return spawn_rect.get_center()


func _is_enemy_spawn_position_valid(candidate: Vector2) -> bool:
	if candidate.distance_to(player.global_position) < minimum_enemy_distance_from_player:
		return false

	for enemy in enemies.get_children():
		if not is_instance_valid(enemy):
			continue

		if candidate.distance_to(enemy.global_position) < minimum_enemy_spacing:
			return false

	return true


func _count_alive_enemies() -> int:
	var alive_count := 0

	for enemy in enemies.get_children():
		if is_instance_valid(enemy):
			alive_count += 1

	return alive_count


func _is_food_position_valid(candidate: Vector2) -> bool:
	if candidate.distance_to(player.global_position) < minimum_food_distance_from_player:
		return false

	for enemy in enemies.get_children():
		if candidate.distance_to(enemy.global_position) < minimum_food_distance_from_player:
			return false

	for food in active_foods:
		if not is_instance_valid(food):
			continue

		if candidate.distance_to(food.global_position) < minimum_food_spacing:
			return false

	return true


func _update_ui() -> void:
	score_label.text = "\u0421\u0447\u0451\u0442: %d" % score
	hint_label.visible = not is_game_over
	hint_label.text = "Esc - \u043d\u0430 \u0440\u0430\u0431\u043e\u0447\u0438\u0439 \u0441\u0442\u043e\u043b"


func _on_player_died() -> void:
	if is_game_over or _session_end_started:
		return

	is_game_over = true
	_freeze_gameplay()
	_show_game_over_overlay()
	_update_ui()
	_restart_after_game_over()


func _exit_to_desktop() -> void:
	if _session_end_started:
		return

	_session_end_started = true
	is_game_over = true
	_grant_reward_once()
	get_tree().change_scene_to_file(DESKTOP_SCENE_PATH)


func _restart_after_game_over() -> void:
	if _session_end_started:
		return

	_session_end_started = true
	_grant_reward_once()
	_restart_round_after_delay(GAME_OVER_RESTART_DELAY)


func _grant_reward_once() -> void:
	if _reward_granted:
		return

	_reward_granted = true

	if score <= 0:
		return

	PlayerEconomy.add_dollars(score)


func _restart_round_after_delay(delay_seconds: float) -> void:
	if delay_seconds > 0.0:
		await get_tree().create_timer(delay_seconds).timeout

	get_tree().change_scene_to_file(SLITHARIO_SCENE_PATH)


func _show_game_over_overlay() -> void:
	if game_over_overlay != null:
		game_over_overlay.visible = true


func _freeze_gameplay() -> void:
	for enemy in enemies.get_children():
		if enemy != null and is_instance_valid(enemy):
			enemy.set_process(false)


func _queue_food_count_refresh() -> void:
	if _food_count_refresh_queued:
		return

	_food_count_refresh_queued = true
	call_deferred("_flush_food_count_refresh")


func _flush_food_count_refresh() -> void:
	_food_count_refresh_queued = false

	if is_game_over:
		return

	_ensure_food_count()


func _spawn_enemy_drop_foods(drop_positions: Array[Vector2]) -> void:
	if is_game_over:
		return

	for drop_position in drop_positions:
		_spawn_food_at_position(drop_position)
