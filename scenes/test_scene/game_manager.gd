extends Node

var is_game_over: bool = false
var total_gnomes: int = 5
var caught_gnomes: int = 0
var time_left: float = 90.0


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	%LoseLabel.hide()
	%WinLabel.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not is_game_over:
		time_left -= delta
		time_left = max(time_left, 0.0)

	%TimeLeftLabel.text = str(roundi(time_left))
	%GnomeCountLabel.text = str(caught_gnomes) + "/" + str(total_gnomes)
	%EnergyProgressBar.value = %Player.energy

	if caught_gnomes == total_gnomes:
		%WinLabel.show()
		is_game_over = true
	
	if time_left <= 0.0 and not is_game_over:
		%LoseLabel.show()
		is_game_over = true


func gnome_caught() -> void:
	caught_gnomes += 1
