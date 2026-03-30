extends Node2D

signal food_collected(food: Area2D)
signal died

@export var speed: float = 280.0
@export var segment_spacing: float = 30.0
@export var initial_segments: int = 3
@export var body_segment_scale: float = 0.58

@onready var head_area: Area2D = $HeadArea
@onready var head_sprite: Sprite2D = $HeadArea/HeadSprite
@onready var body_container: Node2D = $BodyContainer
@onready var camera: Camera2D = $Camera2D

var arena_rect := Rect2(-500.0, -300.0, 1000.0, 600.0)
var body_segments: Array[Area2D] = []
var move_direction := Vector2.RIGHT
var is_setup := false
var is_dead := false


func _ready() -> void:
	if not head_area.is_in_group("slithario_player"):
		head_area.add_to_group("slithario_player")

	if not head_area.area_entered.is_connected(_on_head_area_entered):
		head_area.area_entered.connect(_on_head_area_entered)


func _process(delta: float) -> void:
	if not is_setup or is_dead:
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")

	if input_direction != Vector2.ZERO:
		move_direction = input_direction.normalized()

	global_position += move_direction * speed * delta
	global_position = Vector2(
		clampf(global_position.x, arena_rect.position.x, arena_rect.end.x),
		clampf(global_position.y, arena_rect.position.y, arena_rect.end.y)
	)

	_update_body_segments()


func setup(new_arena_rect: Rect2, spawn_position: Vector2) -> void:
	arena_rect = new_arena_rect
	global_position = spawn_position
	move_direction = Vector2.RIGHT
	is_dead = false
	head_area.monitoring = true
	head_area.monitorable = true
	_rebuild_body()
	_configure_camera()
	is_setup = true


func is_alive() -> bool:
	return not is_dead


func get_move_direction() -> Vector2:
	return move_direction


func die() -> void:
	if is_dead:
		return

	is_dead = true
	head_area.set_deferred("monitoring", false)
	head_area.set_deferred("monitorable", false)

	for segment in body_segments:
		if is_instance_valid(segment):
			segment.set_deferred("monitorable", false)

	died.emit()


func grow(amount: int = 1) -> void:
	if is_dead:
		return

	for _index in range(amount):
		var tail_position := global_position

		if not body_segments.is_empty():
			tail_position = body_segments[-1].global_position

		_create_body_segment(tail_position)


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

	shape.radius = 12.0
	segment.collision_layer = 2
	segment.collision_mask = 0
	segment.top_level = true
	segment.z_index = -1
	segment.global_position = world_position
	segment.add_to_group("slithario_player")

	sprite.texture = head_sprite.texture
	sprite.scale = Vector2.ONE * body_segment_scale
	sprite.centered = true

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


func _configure_camera() -> void:
	camera.limit_left = int(floor(arena_rect.position.x))
	camera.limit_top = int(floor(arena_rect.position.y))
	camera.limit_right = int(ceil(arena_rect.end.x))
	camera.limit_bottom = int(ceil(arena_rect.end.y))
	camera.reset_smoothing()


func _on_head_area_entered(area: Area2D) -> void:
	if area.is_in_group("slithario_enemy"):
		die()
		return

	if not area.is_in_group("slithario_food"):
		return

	if area.has_method("consume") and area.consume():
		call_deferred("grow")
		food_collected.emit(area)
