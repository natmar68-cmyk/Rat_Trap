extends CanvasLayer

@onready var food_label: Label = $FoodLabel
@onready var timer_label: Label = $TimerLabel

@export var starting_time: float = 60.0
@export var time_bonus_on_delivery: float = 5.0

signal time_expired

var time_left: float = 0.0
var is_running: bool = true

func _ready():
	GameManager.carried_changed.connect(_on_carried_changed)
	GameManager.delivered_changed.connect(_on_delivered_changed)
	food_label.text = "Carrying: 0 | Delivered: 0"

	time_left = starting_time
	_update_timer_label()

func _process(delta):
	if not is_running:
		return

	time_left -= delta

	if time_left <= 0:
		time_left = 0
		is_running = false
		_update_timer_label()
		emit_signal("time_expired")
		return

	_update_timer_label()

func _on_carried_changed(new_count):
	food_label.text = "Carrying: " + str(new_count) + " | Delivered: " + str(GameManager.food_delivered)

func _on_delivered_changed(new_count):
	food_label.text = "Carrying: " + str(GameManager.food_carried) + " | Delivered: " + str(new_count)
	time_left += time_bonus_on_delivery
	_update_timer_label()

func _update_timer_label():
	var total = int(ceil(time_left))
	var minutes = total / 60
	var seconds = total % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]
