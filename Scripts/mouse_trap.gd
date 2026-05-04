extends Area3D

func _ready():
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	print("Trap hit by: ", body.name)
	if body.is_in_group("Player"):
		print("Player detected, changing scene...")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file.call_deferred("res://Scenes/death_screen.tscn")
