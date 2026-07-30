extends CanvasLayer

@onready var food_label: Label = $FoodLabel
@onready var timer_label: Label = $TimerLabel

@export var starting_time: float = 60.0
@export var time_bonus_per_item: float = 5.0
@export var popup_font: Font   # drag a .ttf/.otf here in the Inspector to use a custom font

signal time_expired

var time_left: float = 0.0
var is_running: bool = true
var _last_delivered_count: int = 0

func _ready():
	GameManager.carried_changed.connect(_on_carried_changed)
	GameManager.delivered_changed.connect(_on_delivered_changed)
	time_expired.connect(_on_time_expired)
	food_label.text = "Carrying: 0 | Delivered: 0"

	_last_delivered_count = GameManager.food_delivered

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

	var items_delivered = new_count - _last_delivered_count
	_last_delivered_count = new_count

	if items_delivered <= 0:
		return

	var bonus = items_delivered * time_bonus_per_item
	time_left += bonus
	_update_timer_label()
	_show_time_bonus_popup(bonus)

func _on_time_expired():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_file("res://Scenes/death_screen.tscn")

func _update_timer_label():
	var total = int(ceil(time_left))
	var minutes = total / 60
	var seconds = total % 60
	timer_label.text = "%d:%02d" % [minutes, seconds]

func _show_time_bonus_popup(amount: float) -> void:
	var popup := Label.new()
	popup.text = "+%d" % int(amount)
	popup.add_theme_color_override("font_color", Color(0.25, 1.0, 0.35))
	popup.add_theme_font_size_override("font_size", 32)

	if popup_font:
		popup.add_theme_font_override("font", popup_font)
	else:
		popup.add_theme_constant_override("outline_size", 4)
		popup.add_theme_color_override("font_outline_color", Color(0, 0.3, 0.1))

	popup.z_index = 10
	add_child(popup)

	popup.position = timer_label.position + Vector2(timer_label.size.x + 4, 4)
	popup.scale = Vector2(0.4, 0.4)
	popup.modulate.a = 1.0

	var pop_tween := create_tween()
	pop_tween.tween_property(popup, "scale", Vector2(1.3, 1.3), 0.15) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(popup, "scale", Vector2(1.0, 1.0), 0.1) \
		.set_trans(Tween.TRANS_SINE)

	var float_tween := create_tween()
	float_tween.set_parallel(true)
	float_tween.tween_property(popup, "position:y", popup.position.y - 50, 0.8) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	float_tween.tween_property(popup, "modulate:a", 0.0, 0.5).set_delay(0.3)
	float_tween.chain().tween_callback(popup.queue_free)
