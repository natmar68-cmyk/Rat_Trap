extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if body.is_in_group("Player") and GameManager.food_carried > 0:
		GameManager.deliver_food()
