extends Node

var total_gnomes: int = 5
var remaining_gnomes: int = total_gnomes

var gnome_count_label: Label
var energy_progress_bar: ProgressBar
var winner_label: Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	gnome_count_label = %GnomeCountLabel
	energy_progress_bar = %EnergyProgressBar
	winner_label = %WinnerLabel
	winner_label.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	gnome_count_label.text = str(remaining_gnomes) + "/" + str(total_gnomes)
	energy_progress_bar.value = %Player.energy

	if remaining_gnomes <= 0:
		winner_label.show()


func gnome_caught() -> void:
	remaining_gnomes -= 1
	if remaining_gnomes <= 0:
		print("All gnomes caught! You win!")
