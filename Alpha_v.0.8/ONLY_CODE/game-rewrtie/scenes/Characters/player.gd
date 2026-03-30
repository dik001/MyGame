extends CharacterBody2D

const PlayerAppearanceControllerScript := preload("res://scenes/Characters/PlayerAppearanceController.gd")

@export var speed: float = 180.0
@export var walk_tilemap_path: NodePath
@export var interaction_point_distance: float = 28.0
@export var tile_sample_offset: Vector2 = Vector2.ZERO

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var interaction_point: Marker2D = $InteractionPoint
@onready var tile_step_tracker: TileStepTracker = $TileStepTracker

var last_direction: Vector2 = Vector2.DOWN

var _world_grid: WorldGrid
var _input_locked: bool = false
var _movement_locked: bool = false
var _grid_cell: Vector2i = Vector2i.ZERO
var _has_grid_cell: bool = false
var _queued_direction: Vector2 = Vector2.ZERO
var _held_direction: Vector2 = Vector2.ZERO
var _pending_turn_direction: Vector2 = Vector2.ZERO
var _hold_repeat_timer: float = 0.0
var _hold_walk_started: bool = false
var _step_in_progress: bool = false
var _step_progress: float = 0.0
var _step_from_world: Vector2 = Vector2.ZERO
var _step_to_world: Vector2 = Vector2.ZERO
var _step_from_cell: Vector2i = Vector2i.ZERO
var _step_to_cell: Vector2i = Vector2i.ZERO
var _appearance_controller: Node = null


func _ready() -> void:
	if not is_in_group("player"):
		add_to_group("player")

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	velocity = Vector2.ZERO
	_ensure_appearance_controller()
	_play_animation("Idle_Front")
	_update_interaction_point()
	_connect_tile_step_tracker()

	if walk_tilemap_path.is_empty():
		return

	var tile_map_layer: TileMapLayer = get_node_or_null(walk_tilemap_path) as TileMapLayer

	if tile_map_layer == null:
		push_warning("Player could not find the walk TileMapLayer.")
		return

	set_walk_tilemap(tile_map_layer)


func _physics_process(delta: float) -> void:
	if is_input_locked():
		_apply_input_lock_state()
		_update_debug_context()
		return

	if _movement_locked:
		_apply_movement_lock_state()
		_update_debug_context()
		return

	_process_step_motion(delta)

	var input_direction: Vector2 = _resolve_input_direction()
	_update_hold_repeat_state(input_direction, delta)

	if not _step_in_progress and input_direction != Vector2.ZERO and _hold_repeat_timer <= 0.0:
		if _attempt_grid_step(input_direction):
			_hold_repeat_timer = _get_hold_repeat_interval()

	_update_debug_context()


func _unhandled_input(event: InputEvent) -> void:
	if is_input_locked():
		return

	if event.is_action_pressed("interact") and not event.is_echo():
		_try_interact()


func get_stats_component() -> PlayerStatsState:
	return get_node("/root/PlayerStats") as PlayerStatsState


func get_inventory_component() -> PlayerInventoryState:
	return get_node("/root/PlayerInventory") as PlayerInventoryState


func unequip_slot(slot: StringName) -> bool:
	if PlayerEquipment == null or not PlayerEquipment.has_method("unequip_slot"):
		return false

	return bool(PlayerEquipment.unequip_slot(slot))


func unequip_slots(slots: Array) -> void:
	if PlayerEquipment == null or not PlayerEquipment.has_method("unequip_slots"):
		return

	PlayerEquipment.unequip_slots(slots)


func unequip_all() -> void:
	if PlayerEquipment == null or not PlayerEquipment.has_method("unequip_all"):
		return

	PlayerEquipment.unequip_all()


func build_save_data() -> Dictionary:
	var save_data: Dictionary = {
		"position": SaveDataUtils.vector2_to_dict(global_position),
		"facing_direction": SaveDataUtils.vector2_to_dict(last_direction),
	}

	if _has_grid_cell:
		save_data["grid_cell"] = SaveDataUtils.vector2i_to_dict(_grid_cell)

	return save_data


func apply_save_data(data: Dictionary) -> void:
	var has_grid_cell: bool = data.has("grid_cell")
	var saved_facing: Vector2 = SaveDataUtils.dict_to_vector2(data.get("facing_direction", {}), last_direction)
	var saved_position: Vector2 = SaveDataUtils.dict_to_vector2(data.get("position", {}), global_position)

	set_facing_direction(saved_facing)
	set_input_locked(false)
	velocity = Vector2.ZERO
	_step_in_progress = false
	_hold_repeat_timer = 0.0
	_held_direction = Vector2.ZERO
	_queued_direction = Vector2.ZERO
	_pending_turn_direction = Vector2.ZERO
	_hold_walk_started = false

	if has_grid_cell and _world_grid != null:
		set_grid_cell(SaveDataUtils.dict_to_vector2i(data.get("grid_cell", {}), _grid_cell), true)
		return

	if _world_grid != null:
		sync_to_world_position(saved_position, true)
		return

	global_position = _snap_visual_position(saved_position)


func reset_runtime_state() -> void:
	set_input_locked(false)
	velocity = Vector2.ZERO
	_step_in_progress = false
	_hold_repeat_timer = 0.0
	_held_direction = Vector2.ZERO
	_queued_direction = Vector2.ZERO
	_pending_turn_direction = Vector2.ZERO
	_hold_walk_started = false
	set_facing_direction(Vector2.DOWN)

	if _world_grid != null:
		sync_to_world_position(global_position, true)


func is_input_locked() -> bool:
	return _input_locked or _is_external_input_locked()


func get_nearest_interactable() -> WorldInteractable:
	if _world_grid == null:
		return null

	return _world_grid.find_interactable_for(
		get_grid_cell(),
		last_direction,
		self,
		_world_grid.get_player_action_pattern_id()
	)


func get_grid_cell() -> Vector2i:
	if _has_grid_cell:
		return _grid_cell

	if _world_grid != null:
		_grid_cell = _world_grid.world_to_cell(global_position)
		_has_grid_cell = true

	return _grid_cell


func set_input_locked(is_locked: bool) -> void:
	if _input_locked == is_locked:
		return

	_input_locked = is_locked

	if _input_locked:
		_apply_input_lock_state()


func set_movement_locked(is_locked: bool) -> void:
	if _movement_locked == is_locked:
		return

	_movement_locked = is_locked

	if _movement_locked:
		_apply_movement_lock_state()


func set_walk_tilemap(tile_map_layer: TileMapLayer) -> void:
	_connect_tile_step_tracker()
	tile_step_tracker.setup(self, tile_map_layer, tile_sample_offset)

	if _world_grid != null:
		sync_to_world_position(global_position, true)


func set_world_grid(world_grid: WorldGrid) -> void:
	_world_grid = world_grid

	if _world_grid == null:
		return

	sync_to_world_position(global_position, true)


func get_world_grid() -> WorldGrid:
	return _world_grid


func set_grid_cell(next_cell: Vector2i, snap_immediately: bool = true) -> void:
	_grid_cell = next_cell
	_has_grid_cell = true

	if _world_grid != null:
		_world_grid.reserve_actor_cell(self, _grid_cell, _grid_cell)

	if snap_immediately and _world_grid != null:
		global_position = _snap_visual_position(_world_grid.cell_to_world(next_cell))
		tile_step_tracker.update_tile()

	_update_debug_context()


func sync_to_world_position(world_position: Vector2, snap_immediately: bool = true) -> void:
	if _world_grid == null:
		global_position = _snap_visual_position(world_position)
		return

	var target_cell: Vector2i = _world_grid.world_to_cell(world_position)
	set_grid_cell(target_cell, snap_immediately)


func apply_spawn_world_position(spawn_position: Vector2, spawn_facing: Vector2 = last_direction) -> void:
	set_facing_direction(spawn_facing)
	sync_to_world_position(spawn_position, true)
	set_input_locked(false)
	_step_in_progress = false
	_hold_repeat_timer = 0.0
	_held_direction = Vector2.ZERO
	_queued_direction = Vector2.ZERO
	_pending_turn_direction = Vector2.ZERO
	_hold_walk_started = false


func set_facing_direction(direction: Vector2) -> void:
	if direction == Vector2.ZERO:
		return

	var resolved_direction: Vector2 = _normalize_direction(direction)
	_set_last_direction(resolved_direction)

	if not _step_in_progress:
		_update_animation(Vector2.ZERO)


func apply_action_tick(action_name: String, stat_delta: Dictionary) -> void:
	var stats_component: PlayerStatsState = get_stats_component()

	if stats_component == null:
		return

	stats_component.apply_action_tick(StringName(action_name), stat_delta)


func _process_step_motion(delta: float) -> void:
	if not _step_in_progress:
		return

	var duration: float = _get_step_duration()

	if duration <= 0.0:
		_finish_grid_step()
		return

	_step_progress = minf(1.0, _step_progress + (delta / duration))
	global_position = _snap_visual_position(_step_from_world.lerp(_step_to_world, _step_progress))

	if _step_progress >= 1.0:
		_finish_grid_step()


func _update_hold_repeat_state(input_direction: Vector2, delta: float) -> void:
	if input_direction == Vector2.ZERO:
		_hold_repeat_timer = 0.0
		_held_direction = Vector2.ZERO
		_queued_direction = Vector2.ZERO
		_pending_turn_direction = Vector2.ZERO
		_hold_walk_started = false

		if not _step_in_progress:
			_update_animation(Vector2.ZERO)

		return

	if _held_direction != input_direction:
		_held_direction = input_direction
		_hold_walk_started = false

		if _normalize_direction(last_direction) == input_direction:
			_pending_turn_direction = Vector2.ZERO
			_queued_direction = input_direction
			_hold_repeat_timer = 0.0
			return

		_pending_turn_direction = input_direction
		_queued_direction = Vector2.ZERO
		_hold_repeat_timer = _get_hold_repeat_initial_delay()
		_apply_pending_turn_if_ready()

		return

	_apply_pending_turn_if_ready()

	if _pending_turn_direction == Vector2.ZERO:
		_queued_direction = input_direction
	else:
		_queued_direction = Vector2.ZERO

	_hold_repeat_timer = maxf(0.0, _hold_repeat_timer - delta)


func _attempt_grid_step(direction: Vector2) -> bool:
	if _world_grid == null:
		return false

	var resolved_direction: Vector2 = _normalize_direction(direction)
	var from_cell: Vector2i = get_grid_cell()
	var target_cell: Vector2i = from_cell + Vector2i(int(resolved_direction.x), int(resolved_direction.y))
	var action_cells: Array[Vector2i] = _world_grid.resolve_pattern(
		from_cell,
		resolved_direction,
		_world_grid.get_player_action_pattern_id()
	)

	if not _world_grid.can_enter(target_cell, self):
		_hold_walk_started = false
		_update_animation(Vector2.ZERO)
		_world_grid.set_debug_context(from_cell, target_cell, true, action_cells, [])
		return false

	_step_in_progress = true
	_step_progress = 0.0
	_step_from_cell = from_cell
	_step_to_cell = target_cell
	_step_from_world = _snap_visual_position(_world_grid.cell_to_world(from_cell))
	_step_to_world = _snap_visual_position(_world_grid.cell_to_world(target_cell))
	_set_last_direction(resolved_direction)
	_pending_turn_direction = Vector2.ZERO
	_hold_walk_started = true
	_update_animation(resolved_direction)
	_world_grid.reserve_actor_cell(self, from_cell, target_cell)
	return true


func _finish_grid_step() -> void:
	_step_in_progress = false
	_step_progress = 0.0
	_grid_cell = _step_to_cell
	_has_grid_cell = true
	global_position = _snap_visual_position(_step_to_world)
	velocity = Vector2.ZERO

	if _world_grid != null:
		_world_grid.reserve_actor_cell(self, _step_from_cell, _grid_cell)

	tile_step_tracker.update_tile()
	_apply_pending_turn_if_ready()

	if _should_keep_walk_animation():
		_update_animation(last_direction)
	else:
		_update_animation(Vector2.ZERO)

	_update_debug_context()

	if is_input_locked():
		return

	if _queued_direction != Vector2.ZERO and _hold_repeat_timer <= 0.0:
		if _attempt_grid_step(_queued_direction):
			_hold_repeat_timer = _get_hold_repeat_interval()


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

	if _appearance_controller != null:
		_appearance_controller.sync_now(true)


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
	var stats_component: PlayerStatsState = get_stats_component()

	if stats_component == null:
		return

	stats_component.apply_movement_tick()


func _try_interact() -> void:
	if _step_in_progress:
		return

	var interactable: WorldInteractable = get_nearest_interactable()

	if interactable == null:
		return

	interactable.interact(self)


func _resolve_input_direction() -> Vector2:
	var input_direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction == Vector2.ZERO:
		return Vector2.ZERO

	return _normalize_direction(input_direction)


func _normalize_direction(direction: Vector2) -> Vector2:
	if direction == Vector2.ZERO:
		return Vector2.ZERO

	if _world_grid != null and _world_grid.allow_diagonal_movement:
		return Vector2(
			0.0 if is_zero_approx(direction.x) else signf(direction.x),
			0.0 if is_zero_approx(direction.y) else signf(direction.y)
		)

	if absf(direction.x) > absf(direction.y):
		return Vector2.RIGHT if direction.x > 0.0 else Vector2.LEFT

	return Vector2.DOWN if direction.y > 0.0 else Vector2.UP


func _get_step_duration() -> float:
	var base_duration: float

	if _world_grid != null:
		base_duration = maxf(0.01, _world_grid.step_duration)
	else:
		if speed <= 0.0:
			base_duration = 0.14
		else:
			base_duration = maxf(0.01, 32.0 / speed)

	var movement_speed_multiplier := 1.0
	var stats_component: PlayerStatsState = get_stats_component()

	if stats_component != null and stats_component.has_method("get_movement_speed_multiplier"):
		movement_speed_multiplier = maxf(0.01, float(stats_component.get_movement_speed_multiplier()))

	return maxf(0.01, base_duration / movement_speed_multiplier)


func _get_hold_repeat_initial_delay() -> float:
	if _world_grid != null:
		return maxf(0.01, _world_grid.hold_repeat_initial_delay)

	return 0.18


func _get_hold_repeat_interval() -> float:
	if _world_grid != null:
		return maxf(0.01, _world_grid.hold_repeat_interval)

	return 0.10


func _apply_pending_turn_if_ready() -> void:
	if _step_in_progress or _pending_turn_direction == Vector2.ZERO:
		return

	set_facing_direction(_pending_turn_direction)
	_pending_turn_direction = Vector2.ZERO


func _should_keep_walk_animation() -> bool:
	if is_input_locked() or _step_in_progress or not _hold_walk_started:
		return false

	if _held_direction == Vector2.ZERO or _pending_turn_direction != Vector2.ZERO:
		return false

	return _normalize_direction(_held_direction) == _normalize_direction(last_direction)


func _update_debug_context() -> void:
	if _world_grid == null:
		return

	var actor_cell: Vector2i = get_grid_cell()
	var target_cell: Vector2i = actor_cell
	var has_target_cell: bool = false

	if _held_direction != Vector2.ZERO:
		target_cell = actor_cell + Vector2i(int(_held_direction.x), int(_held_direction.y))
		has_target_cell = true

	var pattern_cells: Array[Vector2i] = _world_grid.resolve_pattern(
		actor_cell,
		last_direction,
		_world_grid.get_player_action_pattern_id()
	)
	var interactable: WorldInteractable = get_nearest_interactable()
	var interaction_cells: Array[Vector2i] = []

	if interactable != null:
		interaction_cells = interactable.get_interaction_cells(_world_grid)

	_world_grid.set_debug_context(actor_cell, target_cell, has_target_cell, pattern_cells, interaction_cells)


func _is_external_input_locked() -> bool:
	return DialogueManager != null and DialogueManager.has_method("is_dialogue_visible") and DialogueManager.is_dialogue_visible()


func _apply_input_lock_state() -> void:
	_apply_movement_lock_state()


func _apply_movement_lock_state() -> void:
	_hold_repeat_timer = 0.0
	_held_direction = Vector2.ZERO
	_queued_direction = Vector2.ZERO
	_pending_turn_direction = Vector2.ZERO
	_hold_walk_started = false
	velocity = Vector2.ZERO

	if _step_in_progress:
		_interrupt_active_step()
	else:
		_update_animation(Vector2.ZERO)


func _interrupt_active_step() -> void:
	var snapped_to_target: bool = _step_progress >= 0.5
	var snapped_cell: Vector2i = _step_to_cell if snapped_to_target else _step_from_cell
	var snapped_world: Vector2 = _step_to_world if snapped_to_target else _step_from_world

	_step_in_progress = false
	_step_progress = 0.0
	_step_from_cell = snapped_cell
	_step_to_cell = snapped_cell
	_step_from_world = snapped_world
	_step_to_world = snapped_world
	_grid_cell = snapped_cell
	_has_grid_cell = true
	global_position = _snap_visual_position(snapped_world)

	if _world_grid != null:
		_world_grid.reserve_actor_cell(self, _grid_cell, _grid_cell)

	tile_step_tracker.update_tile()
	_update_animation(Vector2.ZERO)


func _ensure_appearance_controller() -> void:
	if _appearance_controller != null and is_instance_valid(_appearance_controller):
		return

	_appearance_controller = PlayerAppearanceControllerScript.new()

	if _appearance_controller == null:
		return

	_appearance_controller.name = "AppearanceController"
	add_child(_appearance_controller)
	move_child(_appearance_controller, get_children().find(animated_sprite) + 1)
	_appearance_controller.setup(animated_sprite, PlayerEquipment, PlayerBodyState)


func _snap_visual_position(world_position: Vector2) -> Vector2:
	# Keep the layered player renderer on whole pixels so parent motion cannot
	# introduce half-pixel drift between the body sprite and synced overlays.
	return Vector2(roundf(world_position.x), roundf(world_position.y))
