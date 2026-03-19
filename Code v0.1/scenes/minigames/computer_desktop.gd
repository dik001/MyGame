extends Control

const GAME_SCENE_PATH := "res://scenes/main/game.tscn"
const SLITHARIO_SCENE_PATH := "res://scenes/minigames/slithario.tscn"

@onready var slithario_button: TextureButton = $DesktopRoot/ShortcutLayer/SlitharioShortcut/SlitharioIconButton
@onready var shop_button: TextureButton = $DesktopRoot/ShortcutLayer/ShopShortcut/ShopIconButton
@onready var delivery_button: TextureButton = $DesktopRoot/ShortcutLayer/DeliveryShortcut/DeliveryIconButton
@onready var shop_window: Control = $DesktopRoot/WindowsLayer/ShopWindow
@onready var delivery_tracker_window: Control = $DesktopRoot/WindowsLayer/DeliveryTrackerWindow


func _ready() -> void:
	var close_windows_callable: Callable = Callable(self, "_close_all_windows")

	if not slithario_button.pressed.is_connected(_on_slithario_icon_button_pressed):
		slithario_button.pressed.connect(_on_slithario_icon_button_pressed)

	if not shop_button.pressed.is_connected(_on_shop_button_pressed):
		shop_button.pressed.connect(_on_shop_button_pressed)

	if not delivery_button.pressed.is_connected(_on_delivery_button_pressed):
		delivery_button.pressed.connect(_on_delivery_button_pressed)

	if shop_window.has_signal("close_requested") and not shop_window.is_connected("close_requested", close_windows_callable):
		shop_window.connect("close_requested", close_windows_callable)

	if delivery_tracker_window.has_signal("close_requested") and not delivery_tracker_window.is_connected("close_requested", close_windows_callable):
		delivery_tracker_window.connect("close_requested", close_windows_callable)

	_close_all_windows()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		var viewport: Viewport = get_viewport()

		if viewport != null:
			viewport.set_input_as_handled()

		if _has_open_window():
			_close_all_windows()
		else:
			get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_slithario_icon_button_pressed() -> void:
	get_tree().change_scene_to_file(SLITHARIO_SCENE_PATH)


func _on_shop_button_pressed() -> void:
	if delivery_tracker_window.has_method("close_window"):
		delivery_tracker_window.call("close_window")

	if shop_window.has_method("open_window"):
		shop_window.call("open_window")


func _on_delivery_button_pressed() -> void:
	if shop_window.has_method("close_window"):
		shop_window.call("close_window")

	if delivery_tracker_window.has_method("open_window"):
		delivery_tracker_window.call("open_window")


func _close_all_windows() -> void:
	if shop_window.has_method("close_window"):
		shop_window.call("close_window")

	if delivery_tracker_window.has_method("close_window"):
		delivery_tracker_window.call("close_window")


func _has_open_window() -> bool:
	return shop_window.visible or delivery_tracker_window.visible
