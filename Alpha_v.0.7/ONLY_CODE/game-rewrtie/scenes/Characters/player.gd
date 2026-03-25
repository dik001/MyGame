extends CharacterBody2D

const SaveDataUtils = preload("res://scenes/main/SaveDataUtils.gd")

@export var speed: float = 180.0
@export var walk_tilemap_path: NodePath
@export var interaction_point_distance: float = 28.0
@export var tile_sample_offset: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_point: Marker2D = $InteractionPoint
@onready var tile_step_tracker: TileStepTracker = $TileStepTracker

var last_direction: Vector2 = Vector2.DOWN
var _input_locked := false


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_play_animation("Idle_Front")
	_update_interaction_point()
	_connect_tile_step_tracker()

	if walk_tilemap_path.is_empty():
		return

	var tile_map_layer := get_node_or_null(walk_tilemap_path) as TileMapLayer

	if tile_map_layer == null:
		push_warning("Player could not find the walk TileMapLayer.")
		return

	set_walk_tilemap(tile_map_layer)


func _physics_process(_delta: float) -> void:
	if _input_locked:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_animation(Vector2.ZERO)
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	velocity = input_direction * speed
	move_and_slide()

	_update_animation(input_direction)
	tile_step_tracker.update_tile()


func _unhandled_input(event: InputEvent) -> void:
	if _input_locked:
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		_try_interact()


func get_stats_component() -> PlayerStatsState:
	return get_node("/root/PlayerStats") as PlayerStatsState


func get_inventory_component() -> PlayerInventoryState:
	return get_node("/root/PlayerInventory") as PlayerInventoryState


func build_save_data() -> Dictionary:
	return {
		"position": SaveDataUtils.vector2_to_dict(global_position),
		"facing_direction": SaveDataUtils.vector2_to_dict(last_direction),
	}


func apply_save_data(data: Dictionary) -> void:
	global_position = SaveDataUtils.dict_to_vector2(data.get("position", {}), global_position)
	set_facing_direction(SaveDataUtils.dict_to_vector2(data.get("facing_direction", {}), last_direction))
	set_input_locked(false)
	velocity = Vector2.ZERO


func reset_runtime_state() -> void:
	set_input_locked(false)
	velocity = Vector2.ZERO
	set_facing_direction(Vector2.DOWN)


func is_input_locked() -> bool:
	return _input_locked


func get_nearest_interactable() -> WorldInteractable:
	return _find_nearest_interactable()


func set_input_locked(is_locked: bool) -> void:
	if _input_locked == is_locked:
		return

	_input_locked = is_locked

	if _input_locked:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO)


func set_walk_tilemap(tile_map_layer: TileMapLayer) -> void:
	_connect_tile_step_tracker()
	tile_step_tracker.setup(self, tile_map_layer, tile_sample_offset)


func set_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	var resolved_direction := direction

	if absf(resolved_direction.x) > absf(resolved_direction.y):
		resolved_direction = Vector2.RIGHT if resolved_direction.x > 0.0 else Vector2.LEFT
	else:
		resolved_direction = Vector2.DOWN if resolved_direction.y > 0.0 else Vector2.UP

	_set_last_direction(resolved_direction)
	_update_animation(Vector2.ZERO)


func apply_action_tick(action_name: String, stat_delta: Dictionary) -> void:
	var stats_component := get_stats_component()

	if stats_component == null:
		return

	stats_component.apply_action_tick(StringName(action_name), stat_delta)


func _update_animation(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		if abs(last_direction.x) > abs(last_direction.y):
			if last_direction.x < 0.0:
				_play_animation("Idle_Left")
			else:
				_play_animation("Idle_Right")
		else:
			if last_direction.y < 0.0:
				_play_animation("Idle_Back")
			else:
				_play_animation("Idle_Front")
		return

	if abs(direction.x) > abs(direction.y):
		if direction.x < 0.0:
			_set_last_direction(Vector2.LEFT)
			_play_animation("Walk_Left")
		else:
			_set_last_direction(Vector2.RIGHT)
			_play_animation("Walk_Right")
	else:
		if direction.y < 0.0:
			_set_last_direction(Vector2.UP)
			_play_animation("Walk_Back")
		else:
			_set_last_direction(Vector2.DOWN)
			_play_animation("Walk_Front")


func _play_animation(animation_name: StringName) -> void:
	if animated_sprite.animation != animation_name:
		animated_sprite.play(animation_name)


func _set_last_direction(direction: Vector2) -> void:
	if last_direction == direction:
		return

	last_direction = direction
	_update_interaction_point()


func _update_interaction_point() -> void:
	interaction_point.position = last_direction * interaction_point_distance


func _connect_tile_step_tracker() -> void:
	if not tile_step_tracker.tile_changed.is_connected(_on_tile_changed):
		tile_step_tracker.tile_changed.connect(_on_tile_changed)


func _on_tile_changed(_previous_tile: Vector2i, _current_tile: Vector2i) -> void:
	var stats_component := get_stats_component()

	if stats_component == null:
		return

	stats_component.apply_movement_tick()


func _try_interact() -> void:
	var interactable := _find_nearest_interactable()

	if interactable == null:
		return

	interactable.interact(self)


func _find_nearest_interactable() -> WorldInteractable:
	var best_match: WorldInteractable
	var best_distance := INF
	var target_position := interaction_point.global_position

	for node in get_tree().get_nodes_in_group("interactable"):
		var interactable := node as WorldInteractable

		if interactable == null:
			continue

		if not interactable.can_interact(target_position):
			continue

		var distance := target_position.distance_to(interactable.get_interaction_point())

		if distance < best_distance:
			best_distance = distance
			best_match = interactable

	return best_match
