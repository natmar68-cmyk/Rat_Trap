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
	_check_respawn_threshold()

func deliver_food():
	food_delivered += food_carried
	food_carried = 0
	delivered_changed.emit(food_delivered)
	carried_changed.emit(0)

func _check_respawn_threshold():
	var all_food = get_tree().get_nodes_in_group("food")
	var still_active = all_food.filter(func(f): return not f.collected).size()
	if total_food > 0 and still_active <= int(total_food * 0.2):
		_respawn_all_food()

func _respawn_all_food():
	# Removed the food_carried reset — player keeps what they've collected
	for food in get_tree().get_nodes_in_group("food"):
		food.respawn()

func reset():
	food_carried = 0
	food_delivered = 0
	total_food = 0
	carried_changed.emit(0)
	delivered_changed.emit(0)
