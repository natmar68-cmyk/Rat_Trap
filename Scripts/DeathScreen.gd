extends CanvasLayer

func _ready() -> void:
	$Button.pressed.connect(_on_retry_pressed)
	AudioManager.muffle()

func _on_retry_pressed() -> void:
	AudioManager.unmuffle()
	GameManager.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://Scenes/kitchen.tscn")
