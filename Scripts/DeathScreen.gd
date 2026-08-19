extends CanvasLayer

@onready var score_label: Label = $ScoreLabel
@onready var high_score_label: Label = $HighScoreLabel

func _ready() -> void:
	$RetryButton.pressed.connect(_on_retry_pressed)
	AudioManager.muffle()

	score_label.text = "Delivered: %d" % GameManager.food_delivered
	high_score_label.text = "Best: %d" % GameManager.high_score

func _on_retry_pressed() -> void:
	AudioManager.unmuffle()
	GameManager.reset()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	LoadingScreen.load_scene("res://Scenes/kitchen.tscn")

func _on_main_menu_pressed() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	LoadingScreen.load_scene("res://Scenes/menu.tscn")

func _on_button_2_pressed() -> void:
	pass # Replace with function body.
