extends Node

var food_count: int = 0

signal food_count_changed(new_count)

func collect_food(food_name: String):
	food_count += 1
	food_count_changed.emit(food_count)
