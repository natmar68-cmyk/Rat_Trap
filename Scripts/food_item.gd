extends RigidBody3D

@export var food_name: String = "Cheese"
var collected: bool = false

func _ready():
	$Area3D.body_entered.connect(_on_pickup_zone_entered)

func _on_pickup_zone_entered(body):
	if body.is_in_group("Player") and not collected:
		collected = true
		GameManager.collect_food(food_name)
		queue_free()
