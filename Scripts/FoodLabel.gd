extends CanvasLayer

@onready var food_label: Label = $FoodLabel

func _ready():
	GameManager.food_count_changed.connect(_on_food_count_changed)
	food_label.text = "Food: 0"

func _on_food_count_changed(new_count):
	food_label.text = "Food: " + str(new_count)
