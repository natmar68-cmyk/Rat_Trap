extends Node3D

var time = 0.0
var start_y = 0.0

func _ready():
	start_y = position.y

func _process(delta):
	time += delta
	# Bob up and down
	position.y = start_y + sin(time * 2.0) * 0.1
	# Rotate around Y axis
	rotation_degrees.y += 45.0 * delta
