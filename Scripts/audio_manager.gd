extends Node

var menu_music : AudioStreamPlayer
var bus_index  : int

func _ready() -> void:
	bus_index = AudioServer.get_bus_index("Music")

	menu_music = AudioStreamPlayer.new()
	menu_music.stream = preload("res://Assets/starostin-kitchen-chef-restaurant-bar-music-263126 (1).mp3")
	menu_music.bus = "Music"
	menu_music.autoplay = true
	add_child(menu_music)

func play_menu_music() -> void:
	if not menu_music.playing:
		menu_music.play()

func stop_music() -> void:
	menu_music.stop()

func muffle() -> void:
	var effect := AudioEffectLowPassFilter.new()
	effect.cutoff_hz = 500.0
	AudioServer.add_bus_effect(bus_index, effect)

func unmuffle() -> void:
	for i in AudioServer.get_bus_effect_count(bus_index):
		AudioServer.remove_bus_effect(bus_index, 0)
