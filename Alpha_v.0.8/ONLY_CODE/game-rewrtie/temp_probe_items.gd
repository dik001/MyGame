extends SceneTree

func _init() -> void:
	var room_scene: PackedScene = load("res://scenes/rooms/apartament.tscn") as PackedScene
	var room: Node2D = room_scene.instantiate() as Node2D
	root.add_child(room)
	var grid_script: GDScript = load("res://scenes/main/WorldGrid.gd") as GDScript
	var grid: WorldGrid = grid_script.new() as WorldGrid
	root.add_child(grid)
	grid.configure_for_room(room, room.get_node("Floor") as TileMapLayer)
	for path in ["Props/Bed", "Props/Fridge", "Props/ComputerDesk"]:
		var node: Node2D = room.get_node(path) as Node2D
		print(path, " pos=", node.global_position, " anchor=", node.call("get_grid_anchor_cell", grid), " occupied=", node.call("get_occupied_cells", grid), " interact=", node.call("get_interaction_cells", grid))
	quit()
