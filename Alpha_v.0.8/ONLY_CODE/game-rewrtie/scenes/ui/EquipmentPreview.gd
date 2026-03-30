class_name EquipmentPreview
extends Control

const PlayerAppearancePipelineScript := preload("res://scenes/Characters/PlayerAppearancePipeline.gd")
const PREVIEW_PIXEL_SIZE := Vector2(192.0, 192.0)

var _layer_rects: Dictionary = {}
var _player_equipment: Node = null
var _player_body_state: Node = null
var _connected_player_equipment: Node = null
var _connected_player_body_state: Node = null
var _pipeline = PlayerAppearancePipelineScript.new()


func setup(player_equipment: Node = null, player_body_state: Node = null) -> void:
	_player_equipment = player_equipment
	_player_body_state = player_body_state
	_reconnect_state_signals()

	if is_inside_tree():
		refresh_preview()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(220.0, 320.0)
	_build_view()
	_reconnect_state_signals()
	refresh_preview()


func refresh_preview() -> void:
	for layer_name in _pipeline.get_layer_order():
		_set_layer_texture(
			layer_name,
			_pipeline.get_layer_texture(layer_name, _player_equipment, _player_body_state)
		)


func _build_view() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_layer_rects.clear()

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var sprite_container := Control.new()
	sprite_container.custom_minimum_size = PREVIEW_PIXEL_SIZE
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(sprite_container)

	for layer_name in _pipeline.get_layer_order():
		var layer_rect := TextureRect.new()
		layer_rect.name = "%sLayer" % String(layer_name).capitalize()
		layer_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		layer_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		layer_rect.stretch_mode = TextureRect.STRETCH_SCALE
		layer_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		layer_rect.visible = false
		sprite_container.add_child(layer_rect)
		_layer_rects[layer_name] = layer_rect


func _set_layer_texture(layer_name: StringName, texture: Texture2D) -> void:
	var layer_rect := _layer_rects.get(layer_name) as TextureRect

	if layer_rect == null:
		return

	layer_rect.texture = _pipeline.get_preview_texture(texture)
	layer_rect.visible = layer_rect.texture != null
	layer_rect.modulate = _pipeline.get_layer_modulate(layer_name, _player_body_state)


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


func _on_equipment_changed(_equipped_state: Dictionary) -> void:
	refresh_preview()


func _on_body_state_changed(_body_state: Dictionary) -> void:
	refresh_preview()


func _get_player_equipment() -> Node:
	return _pipeline.resolve_player_equipment(_player_equipment)


func _get_player_body_state() -> Node:
	return _pipeline.resolve_player_body_state(_player_body_state)
