extends CanvasLayer

func _ready():
	GameManager.food_count_changed.connect(_on_food_count_changed)
	$FoodLabel.text = "Food: 0"

func _on_food_count_changed(new_count):
	$FoodLabel.text = "Food: " + str(new_count)
