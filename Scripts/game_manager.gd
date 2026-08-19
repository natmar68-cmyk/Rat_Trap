extends Node

const SAVE_PATH := "user://highscore.save"

var food_carried: int = 0
var food_delivered: int = 0
var total_food: int = 0
var high_score: int = 0

signal carried_changed(new_count)
signal delivered_changed(new_count)
signal high_score_changed(new_high_score)

func _ready():
	_load_high_score()

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

	if food_delivered > high_score:
		high_score = food_delivered
		high_score_changed.emit(high_score)
		_save_high_score()

func _check_respawn_threshold():
	var all_food = get_tree().get_nodes_in_group("food")
	var still_active = all_food.filter(func(f): return not f.collected).size()
	if total_food > 0 and still_active <= int(total_food * 0.2):
		_respawn_all_food()

func _respawn_all_food():
	for food in get_tree().get_nodes_in_group("food"):
		food.respawn()

func reset():
	food_carried = 0
	food_delivered = 0
	total_food = 0
	carried_changed.emit(0)
	delivered_changed.emit(0)

func _load_high_score() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		high_score = 0
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		high_score = 0
		return
	var value = file.get_var()
	file.close()
	high_score = int(value) if value != null else 0

func _save_high_score() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_var(high_score)
	file.close()
