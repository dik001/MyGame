extends Node2D

signal food_collected(food: Area2D)
signal died(enemy, drop_positions)

@export var speed: float = 220.0
@export var attack_speed_multiplier: float = 1.2
@export var segment_spacing: float = 28.0
@export var initial_segments: int = 4
@export var body_segment_scale: float = 0.5
@export var steering_speed: float = 4.5
@export var retarget_interval: float = 0.35
@export var aggression_radius: float = 1700.0
@export var attack_chance: float = 0.4
@export var min_attack_duration: float = 1.1
@export var max_attack_duration: float = 2.4
@export var attack_prediction_distance: float = 280.0
@export var attack_side_offset: float = 170.0
@export var attack_side_swap_chance: float = 0.25
@export var head_tint := Color(1.0, 0.45, 0.45, 1.0)
@export var attack_tint := Color(1.0, 0.15, 0.15, 1.0)

@onready var head_area: Area2D = $HeadArea
@onready var head_sprite: Sprite2D = $HeadArea/HeadSprite
@onready var body_container: Node2D = $BodyContainer

var arena_rect := Rect2(-500.0, -300.0, 1000.0, 600.0)
var foods_container: Node2D
var player_target = null
var body_segments: Array[Area2D] = []
var move_direction := Vector2.LEFT
var target_position := Vector2.ZERO
var retarget_time_left := 0.0
var attack_time_left := 0.0
var attack_side_sign := 1.0
var rng := RandomNumberGenerator.new()
var is_setup := false
var is_dead := false


func _ready() -> void:
	rng.randomize()
	head_area.add_to_group("slithario_enemy")
	_apply_visual_state(false)

	if not head_area.area_entered.is_connected(_on_head_area_entered):
		head_area.area_entered.connect(_on_head_area_entered)


func _process(delta: float) -> void:
	if not is_setup or is_dead:
		return

	retarget_time_left -= delta
	attack_time_left = maxf(0.0, attack_time_left - delta)

	if retarget_time_left <= 0.0:
		_pick_target()

	if _is_attacking_player():
		target_position = _get_attack_target_position()

	var desired_direction := move_direction
	var to_target := target_position - global_position

	if to_target.length() > 8.0:
		desired_direction = to_target.normalized()

	var steering_weight := clampf(delta * steering_speed, 0.0, 1.0)
	var blended_direction := move_direction.lerp(desired_direction, steering_weight)

	if blended_direction.length() > 0.001:
		move_direction = blended_direction.normalized()

	var move_speed := speed

	if _is_attacking_player():
		move_speed *= attack_speed_multiplier

	global_position += move_direction * move_speed * delta
	_keep_inside_arena()
	_update_body_segments()


func setup(new_arena_rect: Rect2, spawn_position: Vector2, new_foods_container: Node2D, new_player_target) -> void:
	arena_rect = new_arena_rect
	global_position = spawn_position
	foods_container = new_foods_container
	player_target = new_player_target
	move_direction = Vector2.LEFT.rotated(rng.randf_range(-PI, PI))
	is_dead = false
	head_area.monitoring = true
	head_area.monitorable = true
	_rebuild_body()
	_pick_target()
	is_setup = true


func grow(amount: int = 1) -> void:
	if is_dead:
		return

	for _index in range(amount):
		var tail_position := global_position

		if not body_segments.is_empty():
			tail_position = body_segments[-1].global_position

		_create_body_segment(tail_position)

	_apply_visual_state(_is_attacking_player())


func die() -> void:
	if is_dead:
		return

	is_dead = true
	head_area.set_deferred("monitoring", false)
	head_area.set_deferred("monitorable", false)

	for segment in body_segments:
		if is_instance_valid(segment):
			segment.set_deferred("monitorable", false)

	died.emit(self, _get_drop_positions())
	queue_free()


func _pick_target() -> void:
	retarget_time_left = retarget_interval + rng.randf_range(0.0, retarget_interval)

	if _should_attack_player():
		_choose_attack_side()
		attack_time_left = rng.randf_range(min_attack_duration, max_attack_duration)
		target_position = _get_attack_target_position()
		_apply_visual_state(true)
		return

	attack_time_left = 0.0
	_apply_visual_state(false)

	var nearest_food: Area2D
	var nearest_distance := INF

	if foods_container != null:
		for child in foods_container.get_children():
			var food := child as Area2D

			if food == null or not is_instance_valid(food):
				continue

			var distance := global_position.distance_to(food.global_position)

			if distance < nearest_distance:
				nearest_distance = distance
				nearest_food = food

	if nearest_food != null:
		target_position = nearest_food.global_position
		return

	target_position = Vector2(
		rng.randf_range(arena_rect.position.x, arena_rect.end.x),
		rng.randf_range(arena_rect.position.y, arena_rect.end.y)
	)


func _rebuild_body() -> void:
	for segment in body_segments:
		if is_instance_valid(segment):
			segment.queue_free()

	body_segments.clear()

	for index in range(initial_segments):
		var segment_offset := move_direction * segment_spacing * float(index + 1)
		_create_body_segment(global_position - segment_offset)


func _create_body_segment(world_position: Vector2) -> void:
	var segment := Area2D.new()
	var sprite := Sprite2D.new()
	var collision := CollisionShape2D.new()
	var shape := CircleShape2D.new()

	shape.radius = 10.0
	segment.collision_layer = 4
	segment.collision_mask = 0
	segment.top_level = true
	segment.z_index = -1
	segment.global_position = world_position
	segment.add_to_group("slithario_enemy")

	sprite.texture = head_sprite.texture
	sprite.scale = Vector2.ONE * body_segment_scale
	sprite.centered = true
	sprite.modulate = head_tint

	collision.shape = shape

	segment.add_child(sprite)
	segment.add_child(collision)
	body_container.add_child(segment)
	body_segments.append(segment)


func _update_body_segments() -> void:
	var previous_position := global_position

	for segment in body_segments:
		var offset := previous_position - segment.global_position

		if offset.length() > segment_spacing:
			segment.global_position = previous_position - offset.normalized() * segment_spacing

		previous_position = segment.global_position


func _keep_inside_arena() -> void:
	global_position = Vector2(
		clampf(global_position.x, arena_rect.position.x, arena_rect.end.x),
		clampf(global_position.y, arena_rect.position.y, arena_rect.end.y)
	)

	if global_position.x <= arena_rect.position.x + 64.0 \
	or global_position.x >= arena_rect.end.x - 64.0 \
	or global_position.y <= arena_rect.position.y + 64.0 \
	or global_position.y >= arena_rect.end.y - 64.0:
		move_direction = (arena_rect.get_center() - global_position).normalized()
		target_position = arena_rect.get_center()
		attack_time_left = 0.0
		_apply_visual_state(false)


func _get_drop_positions() -> Array[Vector2]:
	var drop_positions: Array[Vector2] = []

	drop_positions.append(global_position)

	for segment in body_segments:
		if is_instance_valid(segment):
			drop_positions.append(segment.global_position)

	return drop_positions


func _should_attack_player() -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false

	if not _player_is_alive():
		return false

	var player_position: Vector2 = player_target.global_position
	var distance_to_player: float = global_position.distance_to(player_position)

	if distance_to_player > aggression_radius:
		return false

	if distance_to_player < aggression_radius * 0.38:
		return true

	return rng.randf() <= attack_chance


func _is_attacking_player() -> bool:
	if attack_time_left <= 0.0:
		return false

	if player_target == null or not is_instance_valid(player_target):
		return false

	if not _player_is_alive():
		return false

	return true


func _player_is_alive() -> bool:
	if player_target == null or not is_instance_valid(player_target):
		return false

	if player_target.has_method("is_alive"):
		return bool(player_target.call("is_alive"))

	return true


func _choose_attack_side() -> void:
	var player_direction := _get_player_direction()

	if player_direction == Vector2.ZERO:
		attack_side_sign = -1.0 if rng.randf() < 0.5 else 1.0
		return

	var player_position: Vector2 = player_target.global_position
	var offset_from_player: Vector2 = global_position - player_position
	var cross_value: float = player_direction.cross(offset_from_player)

	if abs(cross_value) <= 0.001:
		attack_side_sign = -1.0 if rng.randf() < 0.5 else 1.0
	else:
		attack_side_sign = sign(cross_value)

	if rng.randf() < attack_side_swap_chance:
		attack_side_sign *= -1.0


func _get_player_direction() -> Vector2:
	if player_target == null or not is_instance_valid(player_target):
		return Vector2.ZERO

	if player_target.has_method("get_move_direction"):
		var direction = player_target.call("get_move_direction")

		if direction is Vector2:
			var player_direction: Vector2 = direction

			if player_direction.length() > 0.001:
				return player_direction.normalized()

	return Vector2.ZERO


func _get_attack_target_position() -> Vector2:
	if player_target == null or not is_instance_valid(player_target):
		return target_position

	var player_position: Vector2 = player_target.global_position
	var player_direction := _get_player_direction()

	if player_direction == Vector2.ZERO:
		player_direction = (player_position - global_position).normalized()

		if player_direction == Vector2.ZERO:
			player_direction = move_direction

	var side_direction: Vector2 = player_direction.orthogonal() * attack_side_sign
	var distance_to_player: float = global_position.distance_to(player_position)
	var forward_offset := attack_prediction_distance
	var side_offset := attack_side_offset

	if distance_to_player < 340.0:
		forward_offset = 110.0
		side_offset = attack_side_offset * 0.85

	var attack_target: Vector2 = player_position + player_direction * forward_offset + side_direction * side_offset

	return Vector2(
		clampf(attack_target.x, arena_rect.position.x, arena_rect.end.x),
		clampf(attack_target.y, arena_rect.position.y, arena_rect.end.y)
	)


func _apply_visual_state(is_attacking: bool) -> void:
	var color := head_tint

	if is_attacking:
		color = attack_tint

	head_sprite.modulate = color

	for segment in body_segments:
		if not is_instance_valid(segment):
			continue

		var sprite := segment.get_node_or_null("Sprite2D") as Sprite2D

		if sprite != null:
			sprite.modulate = color


func _on_head_area_entered(area: Area2D) -> void:
	if is_dead:
		return

	if area.is_in_group("slithario_player"):
		die()
		return

	if not area.is_in_group("slithario_food"):
		return

	if area.has_method("consume") and area.consume():
		call_deferred("grow")
		food_collected.emit(area)
