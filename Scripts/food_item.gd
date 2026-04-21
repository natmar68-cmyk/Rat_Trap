extends RigidBody3D

@export var food_name: String = "Cheese"
var collected: bool = false

signal food_collected(food_name)

func _ready():
	$Area3D.body_entered.connect(_on_pickup_zone_entered)

func _on_pickup_zone_entered(body):
	if body.is_in_group("rat") and not collected:
		collected = true
		emit_signal("food_collected", food_name)
		queue_free()  # Remove from scene
#Sort out the spawning food in kitchen
