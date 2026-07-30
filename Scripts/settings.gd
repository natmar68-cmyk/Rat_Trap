extends Node2D
@onready var video = $VideoStreamPlayer



func _on_objective_hover_mouse_entered() -> void:
	video.visible = true
	video.play()


func _on_objective_hover_mouse_exited() -> void:
	video.stop()
	video.visible = false
