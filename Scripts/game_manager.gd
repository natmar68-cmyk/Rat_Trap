extends Node

var food_carried: int = 0
var food_delivered: int = 0
var total_food: int = 0

signal carried_changed(new_count)
signal delivered_changed(new_count)

func register_food():
	total_food += 1

func collect_food(_food_name: String):
	food_carried += 1
	carried_changed.emit(food_carried)

func deliver_food():
	food_delivered += food_carried
	food_carried = 0
	delivered_changed.emit(food_delivered)
	carried_changed.emit(0)

func reset():
	food_carried = 0
	food_delivered = 0
	total_food = 0
	carried_changed.emit(0)
	delivered_changed.emit(0)
