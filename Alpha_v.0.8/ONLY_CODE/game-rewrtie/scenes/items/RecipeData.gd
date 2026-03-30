class_name RecipeData
extends Resource

@export var id: String = ""
@export var recipe_name: String = ""
@export_multiline var description: String = ""
@export var result_item: ItemData
@export_range(1, 99, 1) var result_count: int = 1
@export var ingredients: Array[Dictionary] = []
@export var required_station_tags: PackedStringArray = PackedStringArray()


func get_display_name() -> String:
	if not recipe_name.is_empty():
		return recipe_name

	if not id.is_empty():
		return id.capitalize()

	return "Recipe"


func get_ingredients() -> Array[Dictionary]:
	return ingredients.duplicate(true)
