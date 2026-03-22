extends Node2D

const TARGET_WINDOW_SIZE := Vector2i(1920, 1080)


func _ready() -> void:
	call_deferred("_apply_launch_window_size")


func _apply_launch_window_size() -> void:
	var window := get_window()

	if window == null:
		return

	window.mode = Window.MODE_WINDOWED
	window.min_size = TARGET_WINDOW_SIZE
	window.size = TARGET_WINDOW_SIZE

	await get_tree().process_frame

	if not is_instance_valid(window):
		return

	if window.size != TARGET_WINDOW_SIZE:
		window.size = TARGET_WINDOW_SIZE
