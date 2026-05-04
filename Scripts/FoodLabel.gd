extends CanvasLayer

@onready var food_label: Label = $FoodLabel

func _ready():
	GameManager.carried_changed.connect(_on_carried_changed)
	GameManager.delivered_changed.connect(_on_delivered_changed)
	food_label.text = "Carrying: 0 | Delivered: 0"

func _on_carried_changed(new_count):
	food_label.text = "Carrying: " + str(new_count) + " | Delivered: " + str(GameManager.food_delivered)

func _on_delivered_changed(new_count):
	food_label.text = "Carrying: " + str(GameManager.food_carried) + " | Delivered: " + str(new_count)
