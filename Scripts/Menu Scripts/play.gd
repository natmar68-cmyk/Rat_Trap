extends Button

func _on_pressed() -> void:
	# Use the global LoadingScreen to handle the transition
	LoadingScreen.load_scene("res://Scenes/kitchen.tscn")
