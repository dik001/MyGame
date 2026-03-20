extends Control
class_name TimeWidget

const HOURS_PER_DAY := 24
const MINUTES_PER_HOUR := 60
const MINUTES_PER_DAY := HOURS_PER_DAY * MINUTES_PER_HOUR
const PANEL_VISIBLE_REGION := Rect2(0, 17, 64, 30)

const PANEL_TEXTURE := preload("res://art/ui/time/ui_time_panel.png")
const COLON_TEXTURE := preload("res://art/ui/time/ui_time_colon.png")
const DIGIT_TEXTURES := [
	preload("res://art/ui/time/ui_time_digit_0.png"),
	preload("res://art/ui/time/ui_time_digit_1.png"),
	preload("res://art/ui/time/ui_time_digit_2.png"),
	preload("res://art/ui/time/ui_time_digit_3.png"),
	preload("res://art/ui/time/ui_time_digit_4.png"),
	preload("res://art/ui/time/ui_time_digit_5.png"),
	preload("res://art/ui/time/ui_time_digit_6.png"),
	preload("res://art/ui/time/ui_time_digit_7.png"),
	preload("res://art/ui/time/ui_time_digit_8.png"),
	preload("res://art/ui/time/ui_time_digit_9.png"),
]

@export_range(0, 23) var initial_hours := 7
@export_range(0, 59) var initial_minutes := 25

@onready var panel: TextureRect = $Panel
@onready var hour_tens: TextureRect = $HourTens
@onready var hour_ones: TextureRect = $HourOnes
@onready var colon: TextureRect = $Colon
@onready var minute_tens: TextureRect = $MinuteTens
@onready var minute_ones: TextureRect = $MinuteOnes

var _hours := 7
var _minutes := 25


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.texture = _create_panel_texture()
	colon.texture = COLON_TEXTURE
	_hours = clampi(initial_hours, 0, 23)
	_minutes = clampi(initial_minutes, 0, 59)
	_refresh_display()


func set_time(hours: int, minutes: int) -> void:
	_hours = clampi(hours, 0, 23)
	_minutes = clampi(minutes, 0, 59)

	if hour_tens != null:
		_refresh_display()


func set_total_minutes(total_minutes: int) -> void:
	var normalized_total := total_minutes

	if normalized_total < 0:
		normalized_total = 0

	normalized_total %= MINUTES_PER_DAY

	var hours := int(normalized_total / MINUTES_PER_HOUR)
	var minutes := normalized_total % MINUTES_PER_HOUR

	set_time(hours, minutes)


func _refresh_display() -> void:
	_set_digit(hour_tens, int(_hours / 10))
	_set_digit(hour_ones, _hours % 10)
	_set_digit(minute_tens, int(_minutes / 10))
	_set_digit(minute_ones, _minutes % 10)


func _set_digit(target: TextureRect, digit: int) -> void:
	target.texture = DIGIT_TEXTURES[clampi(digit, 0, DIGIT_TEXTURES.size() - 1)]


func _create_panel_texture() -> AtlasTexture:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = PANEL_TEXTURE
	atlas_texture.region = PANEL_VISIBLE_REGION
	return atlas_texture
