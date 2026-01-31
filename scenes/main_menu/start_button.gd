extends Button


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	connect("pressed", Callable(self, "_on_pressed"))


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/test_scene/test_scene.tscn")
	if err != OK:
		push_error("Failed to change scene to res://scenes/test_scene/test_scene.tscn (error=%s)" % err)
