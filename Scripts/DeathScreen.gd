extends CanvasLayer

func _ready() -> void:
	$RetryButton.pressed.connect(_on_retry_pressed)
	AudioManager.muffle()

func _on_retry_pressed() -> void:
	AudioManager.unmuffle()
	GameManager.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Replace change_scene_to_file with your new Autoload
	LoadingScreen.load_scene("res://Scenes/kitchen.tscn")

func _on_main_menu_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LoadingScreen.load_scene("res://Scenes/menu.tscn")

func _on_button_2_pressed() -> void:
	pass # Replace with function body.
