extends SceneTree
func _init():
    var tests = [
        "res://Scenes/menu.tscn",
        "res://Scenes/settings.tscn",
        "res://Scenes/death_screen.tscn",
        "res://Scenes/loading_screen.tscn",
        "res://Scenes/kitchen.tscn"
    ]
    for p in tests:
        print("TRY ", p)
        var res = ResourceLoader.load(p)
        if res == null:
            print("LOAD_FAILED: ", p)
        else:
            print("LOAD_OK: ", p)
    quit()
