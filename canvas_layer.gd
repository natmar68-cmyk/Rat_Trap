extends CanvasLayer

func _ready():
	$Button.pressed.connect(_on_retry_pressed)

func _on_retry_pressed():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://Scenes/kitchen.tscn")
