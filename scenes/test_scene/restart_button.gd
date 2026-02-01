extends Button


func _ready() -> void:
	connect("pressed", Callable(self , "_on_pressed"))


func _process(delta: float) -> void:
	pass

func _on_pressed() -> void:
	var err = get_tree().change_scene_to_file("res://scenes/test_scene/test_scene.tscn")
