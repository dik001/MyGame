class_name PlayerAppearanceController
extends Node2D

const PlayerAppearancePipelineScript := preload("res://scenes/Characters/PlayerAppearancePipeline.gd")

var _body_sprite: AnimatedSprite2D = null
var _player_equipment: Node = null
var _player_body_state: Node = null
var _connected_player_equipment: Node = null
var _connected_player_body_state: Node = null
var _layer_sprites: Dictionary = {}
var _layer_textures: Dictionary = {}
var _pipeline = PlayerAppearancePipelineScript.new()


func setup(
	body_sprite: AnimatedSprite2D,
	player_equipment: Node = null,
	player_body_state: Node = null
) -> void:
	_body_sprite = body_sprite
	_player_equipment = player_equipment
	_player_body_state = player_body_state

	if _body_sprite == null:
		return

	process_mode = Node.PROCESS_MODE_INHERIT
	_body_sprite.z_index = 0
	_ensure_layer_sprites()
	_connect_body_sprite_signals()
	_reconnect_state_signals()
	_apply_body_texture()
	refresh_visuals()
	sync_now(true)
	set_process(true)


func sync_now(_force_animation_restart := false) -> void:
	if _body_sprite == null or not is_instance_valid(_body_sprite):
		return

	# The body sprite owns animation state. Every overlay resolves its frame texture from
	# that exact animation/frame pair so clothes, dirt and future overlays can never drift.
	for layer_key in _layer_sprites.keys():
		var layer_sprite := _layer_sprites[layer_key] as Sprite2D

		if layer_sprite == null or not is_instance_valid(layer_sprite):
			continue

		_copy_body_transform(layer_sprite)
		_sync_layer_frame(layer_key, layer_sprite)


func refresh_equipment_visuals() -> void:
	for layer_name in _pipeline.get_overlay_layer_order():
		if layer_name == &"dirt" or layer_name == &"blood":
			continue

		_apply_layer_texture(
			layer_name,
			_pipeline.get_layer_texture(layer_name, _player_equipment, _player_body_state)
		)

	sync_now(true)


func refresh_body_overlays() -> void:
	_apply_layer_texture(&"dirt", _pipeline.get_layer_texture(&"dirt", _player_equipment, _player_body_state))
	_apply_layer_texture(&"blood", _pipeline.get_layer_texture(&"blood", _player_equipment, _player_body_state))

	sync_now(true)


func refresh_visuals() -> void:
	refresh_equipment_visuals()
	refresh_body_overlays()


func _ready() -> void:
	set_process(false)


func _exit_tree() -> void:
	_disconnect_state_signals()
	_disconnect_body_sprite_signals()


func _process(_delta: float) -> void:
	sync_now()


func _ensure_layer_sprites() -> void:
	for layer_key in _pipeline.get_overlay_layer_order():
		if _layer_sprites.has(layer_key):
			continue

		var layer_sprite := Sprite2D.new()
		layer_sprite.name = "%sLayer" % String(layer_key).capitalize()
		layer_sprite.z_index = _pipeline.get_layer_z_index(layer_key)
		layer_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_sprite.position = _body_sprite.position
		layer_sprite.visible = false
		add_child(layer_sprite)
		_layer_sprites[layer_key] = layer_sprite


func _connect_body_sprite_signals() -> void:
	_disconnect_body_sprite_signals()

	if _body_sprite == null or not is_instance_valid(_body_sprite):
		return

	if (
		_body_sprite.has_signal(&"frame_changed")
		and not _body_sprite.frame_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.frame_changed.connect(_on_body_visual_state_changed)

	if (
		_body_sprite.has_signal(&"animation_changed")
		and not _body_sprite.animation_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.animation_changed.connect(_on_body_visual_state_changed)

	if (
		_body_sprite.has_signal(&"sprite_frames_changed")
		and not _body_sprite.sprite_frames_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.sprite_frames_changed.connect(_on_body_visual_state_changed)


func _disconnect_body_sprite_signals() -> void:
	if _body_sprite == null or not is_instance_valid(_body_sprite):
		return

	if (
		_body_sprite.has_signal(&"frame_changed")
		and _body_sprite.frame_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.frame_changed.disconnect(_on_body_visual_state_changed)

	if (
		_body_sprite.has_signal(&"animation_changed")
		and _body_sprite.animation_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.animation_changed.disconnect(_on_body_visual_state_changed)

	if (
		_body_sprite.has_signal(&"sprite_frames_changed")
		and _body_sprite.sprite_frames_changed.is_connected(_on_body_visual_state_changed)
	):
		_body_sprite.sprite_frames_changed.disconnect(_on_body_visual_state_changed)


func _copy_body_transform(layer_sprite: Sprite2D) -> void:
	layer_sprite.position = _body_sprite.position
	layer_sprite.centered = _body_sprite.centered
	layer_sprite.offset = _body_sprite.offset
	layer_sprite.scale = _body_sprite.scale
	layer_sprite.rotation = _body_sprite.rotation
	layer_sprite.skew = _body_sprite.skew
	layer_sprite.flip_h = _body_sprite.flip_h
	layer_sprite.flip_v = _body_sprite.flip_v
	layer_sprite.modulate = _body_sprite.modulate
	layer_sprite.self_modulate = _body_sprite.self_modulate
	layer_sprite.texture_filter = _body_sprite.texture_filter


func _sync_layer_frame(layer_key: StringName, layer_sprite: Sprite2D) -> void:
	var texture := _layer_textures.get(layer_key) as Texture2D

	if texture == null:
		layer_sprite.texture = null
		layer_sprite.visible = false
		return

	var frame_texture := _pipeline.get_frame_texture(
		texture,
		_body_sprite.animation,
		_body_sprite.frame,
		layer_key
	)
	layer_sprite.texture = frame_texture
	layer_sprite.visible = frame_texture != null and _body_sprite.visible
	_apply_layer_visual_style(layer_key, layer_sprite)


func _reconnect_state_signals() -> void:
	_disconnect_state_signals()

	_connected_player_equipment = _pipeline.resolve_player_equipment(_player_equipment)

	if (
		_connected_player_equipment != null
		and _connected_player_equipment.has_signal(&"equipment_changed")
		and not _connected_player_equipment.equipment_changed.is_connected(_on_equipment_changed)
	):
		_connected_player_equipment.equipment_changed.connect(_on_equipment_changed)

	_connected_player_body_state = _pipeline.resolve_player_body_state(_player_body_state)

	if (
		_connected_player_body_state != null
		and _connected_player_body_state.has_signal(&"body_state_changed")
		and not _connected_player_body_state.body_state_changed.is_connected(_on_body_state_changed)
	):
		_connected_player_body_state.body_state_changed.connect(_on_body_state_changed)


func _disconnect_state_signals() -> void:
	if (
		_connected_player_equipment != null
		and is_instance_valid(_connected_player_equipment)
		and _connected_player_equipment.has_signal(&"equipment_changed")
		and _connected_player_equipment.equipment_changed.is_connected(_on_equipment_changed)
	):
		_connected_player_equipment.equipment_changed.disconnect(_on_equipment_changed)

	if (
		_connected_player_body_state != null
		and is_instance_valid(_connected_player_body_state)
		and _connected_player_body_state.has_signal(&"body_state_changed")
		and _connected_player_body_state.body_state_changed.is_connected(_on_body_state_changed)
	):
		_connected_player_body_state.body_state_changed.disconnect(_on_body_state_changed)

	_connected_player_equipment = null
	_connected_player_body_state = null


func _apply_body_texture() -> void:
	if _body_sprite == null:
		return

	_body_sprite.sprite_frames = _pipeline.get_sprite_frames(
		_pipeline.get_layer_texture(&"body", _player_equipment, _player_body_state)
	)
	_body_sprite.visible = _body_sprite.sprite_frames != null


func _apply_layer_texture(layer_key: StringName, texture: Texture2D) -> void:
	var layer_sprite := _layer_sprites.get(layer_key) as Sprite2D

	if layer_sprite == null:
		return

	if texture != null and not _pipeline.validate_layer_texture(texture, layer_key):
		texture = null

	_layer_textures[layer_key] = texture
	_sync_layer_frame(layer_key, layer_sprite)


func _apply_layer_visual_style(layer_key: StringName, layer_sprite: Sprite2D) -> void:
	if _body_sprite == null or layer_sprite == null:
		return

	var layer_modulate: Color = _pipeline.get_layer_modulate(layer_key, _player_body_state)
	var resolved_modulate: Color = _body_sprite.modulate
	resolved_modulate.r *= layer_modulate.r
	resolved_modulate.g *= layer_modulate.g
	resolved_modulate.b *= layer_modulate.b
	resolved_modulate.a *= layer_modulate.a
	layer_sprite.modulate = resolved_modulate


func _on_equipment_changed(_equipped_state: Dictionary) -> void:
	refresh_equipment_visuals()


func _on_body_state_changed(_body_state: Dictionary) -> void:
	refresh_body_overlays()


func _on_body_visual_state_changed() -> void:
	sync_now()
