extends RigidBody3D
@export var food_name: String = "Cheese"
var collected: bool = false
var _spawn_position: Vector3
var _spawn_rotation: Vector3

func _ready():
	add_to_group("food")
	_spawn_position = global_position
	_spawn_rotation = global_rotation
	GameManager.register_food()
	$Area3D.body_entered.connect(_on_pickup_zone_entered)

func _on_pickup_zone_entered(body):
	if body.is_in_group("Player") and not collected:
		collected = true
		GameManager.collect_food(food_name)
		visible = false
		# Disable BOTH collision shapes so player can't collide with either
		$CollisionShape3D.disabled = true
		$Area3D/CollisionShape3D.disabled = true
		freeze = true

func respawn():
	collected = false
	visible = true
	global_position = _spawn_position
	global_rotation = _spawn_rotation
	freeze = false
	$CollisionShape3D.disabled = false
	$Area3D/CollisionShape3D.disabled = false
