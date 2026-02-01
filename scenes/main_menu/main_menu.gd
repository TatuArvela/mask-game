extends Node3D

@onready
var phone_audio: AudioStreamPlayer = $PhoneAudio


func _ready() -> void:
	# Wait a moment to avoid audio clipping
	await get_tree().create_timer(1.0).timeout
	phone_audio.play()


func _process(delta: float) -> void:
	pass
