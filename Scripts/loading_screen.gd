extends CanvasLayer

var next_scene_path: String = ""

func _ready() -> void:
	# Hide the loading screen by default
	hide()
	set_process(false)

func load_scene(path: String) -> void:
	if path == "":
		push_error("LoadingScreen.load_scene called with an empty path.")
		return

	next_scene_path = path
	show() # Show the loading UI
	
	# Start loading the scene in a background thread
	ResourceLoader.load_threaded_request(next_scene_path)
	
	# Turn on _process to check the loading status every frame
	set_process(true)

func _process(_delta: float) -> void:
	if next_scene_path == "":
		return
		
	# Check how the background loading is doing
	var status = ResourceLoader.load_threaded_get_status(next_scene_path)
	
	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			# The scene is fully loaded! Grab it and change to it.
			var new_scene = ResourceLoader.load_threaded_get(next_scene_path)
			get_tree().change_scene_to_packed(new_scene)
			
			# Reset and hide the loading screen
			hide()
			next_scene_path = ""
			set_process(false)
			
		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print("Error: Could not load scene at ", next_scene_path)
			set_process(false)
