class_name CookingRecipeRow
extends Button

signal recipe_selected(recipe_id: String)

const STATUS_COLOR_READY := Color(0.66, 1.0, 0.76, 1.0)
const STATUS_COLOR_MISSING_INGREDIENTS := Color(1.0, 0.84, 0.52, 1.0)
const STATUS_COLOR_MISSING_STATION := Color(1.0, 0.70, 0.70, 1.0)
const STATUS_COLOR_DEFAULT := Color(0.85, 0.90, 0.96, 1.0)

@onready var icon_texture_rect: TextureRect = $MarginContainer/ContentRow/IconPanel/IconTextureRect
@onready var fallback_label: Label = $MarginContainer/ContentRow/IconPanel/FallbackLabel
@onready var name_label: Label = $MarginContainer/ContentRow/TextContent/NameLabel
@onready var status_label: Label = $MarginContainer/ContentRow/TextContent/StatusLabel

var _recipe_id := ""
var _recipe_report: Dictionary = {}


func _ready() -> void:
	if not _recipe_report.is_empty():
		_refresh_view()


func bind_row(recipe_report: Dictionary) -> void:
	_recipe_report = recipe_report.duplicate(true)
	_recipe_id = String(_recipe_report.get("recipe_id", "")).strip_edges()

	if is_node_ready():
		_refresh_view()


func get_recipe_id() -> String:
	return _recipe_id


func set_selected(is_selected: bool) -> void:
	button_pressed = is_selected


func _pressed() -> void:
	if _recipe_id.is_empty():
		return

	recipe_selected.emit(_recipe_id)


func _refresh_view() -> void:
	var recipe := _recipe_report.get("recipe") as RecipeData
	var result_item := _recipe_report.get("result_item") as ItemData
	var icon := result_item.icon if result_item != null else null
	var display_name := String(_recipe_report.get("display_name", "Рецепт")).strip_edges()
	var short_status_text := String(_recipe_report.get("short_status_text", "")).strip_edges()
	var detailed_status_text := String(_recipe_report.get("detailed_status_text", "")).strip_edges()
	var description := String(_recipe_report.get("description", "")).strip_edges()

	if display_name.is_empty() and recipe != null:
		display_name = recipe.get_display_name()

	name_label.text = display_name
	status_label.text = short_status_text
	status_label.modulate = _resolve_status_color()
	icon_texture_rect.texture = icon
	icon_texture_rect.visible = icon != null
	fallback_label.visible = icon == null
	fallback_label.text = _get_fallback_text(result_item, display_name)

	var tooltip_lines: Array[String] = [display_name]

	if not description.is_empty():
		tooltip_lines.append(description)

	if not detailed_status_text.is_empty():
		tooltip_lines.append(detailed_status_text)

	tooltip_text = "\n".join(tooltip_lines)


func _resolve_status_color() -> Color:
	if bool(_recipe_report.get("is_available", false)):
		return STATUS_COLOR_READY

	if bool(_recipe_report.get("needs_station", false)):
		return STATUS_COLOR_MISSING_STATION

	if bool(_recipe_report.get("needs_ingredients", false)):
		return STATUS_COLOR_MISSING_INGREDIENTS

	return STATUS_COLOR_DEFAULT


func _get_fallback_text(item_data: ItemData, display_name: String) -> String:
	if item_data != null:
		var item_name := item_data.get_display_name().strip_edges()

		if not item_name.is_empty():
			return item_name.substr(0, min(2, item_name.length())).to_upper()

	if display_name.is_empty():
		return "?"

	return display_name.substr(0, min(2, display_name.length())).to_upper()
