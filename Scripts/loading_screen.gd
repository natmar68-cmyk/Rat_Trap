extends CanvasLayer

var next_scene_path: String = ""

func _ready() -> void:
	hide()
	set_process(false)

func load_scene(path: String) -> void:
	if path == "":
		push_error("LoadingScreen.load_scene called with an empty path.")
		return

	next_scene_path = path
	show()

	if not OS.has_feature("threads"):
		# Single-threaded export (the default and most broadly compatible
		# option on web/itch.io). Yield a couple frames so the loading
		# screen actually gets painted to the canvas before the blocking
		# load freezes the tab - without this, show() never has a chance
		# to render anything.
		await get_tree().process_frame
		await get_tree().process_frame
		_load_synchronously()
		return

	ResourceLoader.load_threaded_request(next_scene_path)
	set_process(true)

func _load_synchronously() -> void:
	var new_scene = ResourceLoader.load(next_scene_path)
	if new_scene == null:
		push_error("Could not load scene at ", next_scene_path)
		hide()
		next_scene_path = ""
		return

	get_tree().change_scene_to_packed(new_scene)
	hide()
	next_scene_path = ""

func _process(_delta: float) -> void:
	if next_scene_path == "":
		return

	var status = ResourceLoader.load_threaded_get_status(next_scene_path)

	match status:
		ResourceLoader.THREAD_LOAD_LOADED:
			var new_scene = ResourceLoader.load_threaded_get(next_scene_path)
			get_tree().change_scene_to_packed(new_scene)
			hide()
			next_scene_path = ""
			set_process(false)

		ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Could not load scene at ", next_scene_path)
			hide()
			next_scene_path = ""
			set_process(false)
