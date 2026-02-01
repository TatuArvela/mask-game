extends Node

var is_paused: bool = false
var is_game_over: bool = false
var total_gnomes: int = 5
var caught_gnomes: int = 0
var time_left: float = 90.0
var mouse_captured: bool = true


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%GameOverLabel.hide()
	%GameOverButtonContainer.hide()
	mouse_captured = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if not is_game_over:
			is_paused = not is_paused
			mouse_captured = not mouse_captured

	if mouse_captured:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	if not is_game_over and not is_paused:
		time_left -= delta
		time_left = max(time_left, 0.0)

	%TimeLeftLabel.text = str(roundi(time_left))
	%GnomeCountLabel.text = str(caught_gnomes) + "/" + str(total_gnomes)
	%EnergyProgressBar.value = %Player.energy

	if caught_gnomes == total_gnomes and not is_game_over:
		%BaseMusic.stop()
		%WinMusic.play()
		%GameOverLabel.text = "You're winner!"
		is_game_over = true
	
	if time_left <= 0.0 and not is_game_over:
		%BaseMusic.stop()
		%LoseSound.play(0.8)
		%GameOverLabel.text = "It's too late now..."
		is_game_over = true
	
	if is_paused:
		%GameOverLabel.text = "Paused"
	
	if is_paused or is_game_over:
		%GameOverLabel.show()
		%GameOverButtonContainer.show()
		%Gnomes.process_mode = Node.PROCESS_MODE_DISABLED

	if is_game_over:
		is_paused = false
		%GameplayContainer.hide()
	else:
		%GameplayContainer.show()

	if not is_game_over and not is_paused:
		%GameOverLabel.hide()
		%GameOverButtonContainer.hide()
		%GameplayContainer.show()
		%Gnomes.process_mode = Node.PROCESS_MODE_INHERIT


func gnome_caught() -> void:
	caught_gnomes += 1
