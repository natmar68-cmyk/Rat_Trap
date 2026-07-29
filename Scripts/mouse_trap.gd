extends Node3D

@onready var trigger: Area3D = $TrapTrigger  # the Area3D you add as a child

func _ready():
	if trigger:
		trigger.body_entered.connect(_on_body_entered)
	else:
		push_warning("No TrapTrigger Area3D found under this node")

func _on_body_entered(body):
	print("Trap hit by: ", body.name)
	if body.is_in_group("Player"):
		print("Player detected, changing scene...")
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		get_tree().change_scene_to_file.call_deferred("res://Scenes/death_screen.tscn")
