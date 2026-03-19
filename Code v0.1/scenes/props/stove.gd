extends WorldInteractable

@export var energy_cost: int = 10


func _ready() -> void:
	interaction_name = "stove"
	stat_delta = {
		"energy": -abs(energy_cost),
	}
	super._ready()


func _after_interact(_player: Node) -> void:
	print("Stove interaction tick applied")
