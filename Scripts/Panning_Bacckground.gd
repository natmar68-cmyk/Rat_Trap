extends TextureRect

@export var pan_speed: float = 0.2	 # Adjust this to make it faster or slower
var time_passed: float = 0.0
var max_pan_distance: float = 0.0

func _ready():
	# Calculate how much extra width the image has compared to the screen
	var screen_width = get_viewport_rect().size.x
	
	# If the image is wider than the screen, we find the difference
	if size.x > screen_width:
		max_pan_distance = size.x - screen_width
	else:
		print("Warning: The image is smaller than the screen!")

func _process(delta):
	time_passed += delta
	
	# sin() returns a value oscillating smoothly between -1 and 1.
	var wave = sin(time_passed * pan_speed)
	
	# We mathematically adjust the wave so it goes from 0 to 1 instead
	var normalized_wave = (wave + 1.0) / 2.0
	
	# Move the image left (negative X) based on the wave
	position.x = -max_pan_distance * normalized_wave
