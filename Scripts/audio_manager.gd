extends Node

var menu_music : AudioStreamPlayer
var game_music : AudioStreamPlayer
var bus_index  : int

func _ready() -> void:
	bus_index = AudioServer.get_bus_index("Music")

	menu_music = AudioStreamPlayer.new()
	menu_music.stream = preload("res://Assets/starostin-kitchen-chef-restaurant-bar-music-263126 (1).mp3")
	menu_music.bus = "Music"
	add_child(menu_music)

	game_music = AudioStreamPlayer.new()
	game_music.stream = preload("res://Assets/Run-Amok(chosic.com).mp3")
	game_music.bus = "Music"
	add_child(game_music)

func play_menu_music() -> void:
	game_music.stop()
	if not menu_music.playing:
		menu_music.play()

func play_game_music() -> void:
	menu_music.stop()
	if not game_music.playing:
		game_music.play()

func muffle() -> void:
	var effect := AudioEffectLowPassFilter.new()
	effect.cutoff_hz = 500.0
	AudioServer.add_bus_effect(bus_index, effect)

func unmuffle() -> void:
	for i in AudioServer.get_bus_effect_count(bus_index):
		AudioServer.remove_bus_effect(bus_index, 0)
		
