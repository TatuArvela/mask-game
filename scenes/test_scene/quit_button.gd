extends Button


func _ready() -> void:
	connect("pressed", Callable(self , "_on_pressed"))


func _process(delta: float) -> void:
	pass

func _on_pressed() -> void:
	get_tree().quit()
