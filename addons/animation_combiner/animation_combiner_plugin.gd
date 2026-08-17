@tool
extends EditorPlugin

var dock: Control


func _enter_tree() -> void:
	var scene_path: String = "res://addons/animation_combiner/animation_combiner_dock.tscn"
	if scene_path == "" or not FileAccess.file_exists(scene_path):
		printerr("Animation Combiner plugin could not find dock scene at: ", scene_path)
		return

	# Create and add the dock — bypass resource cache so edits to the TSCN are picked up immediately
	var scene: PackedScene = ResourceLoader.load(
		scene_path,
		"",
		ResourceLoader.CACHE_MODE_IGNORE
	)
	if scene == null:
		printerr("Animation Combiner plugin failed to load dock scene at: ", scene_path)
		return
	dock = scene.instantiate()
	add_control_to_dock(DOCK_SLOT_RIGHT_UL, dock)


func _exit_tree() -> void:
	# Remove the dock when plugin is disabled
	if dock:
		remove_control_from_docks(dock)
		dock.queue_free()
