extends CharacterBody3D

@export var sneak_speed: float = 1.0
@export var base_speed: float = 4.0
@export var run_speed: float = 10.0

@export var mouse_sensitivity: float = 0.01
@export var gravity: float = 9.8

@export var grab_cooldown: float = 0.3

@onready
var camera: Camera3D = $Camera3D

@onready
var sneak_audio: AudioStreamPlayer3D = $SneakAudio
@onready
var walk_audio: AudioStreamPlayer3D = $WalkAudio
@onready
var run_audio: AudioStreamPlayer3D = $RunAudio

var _current_movement_audio: AudioStreamPlayer3D = null

var mouse_captured: bool = false
var _grab_on_cooldown: bool = false

# Sprint energy system
@export var max_energy: float = 100.0
@export var sprint_cost_per_second: float = 40.0

# Walking cadence (seconds per step scales with speed)
@export var walk_step_base_interval: float = 0.5
@export var walk_step_min_interval: float = 0.2
@export var walk_step_max_interval: float = 0.75
var _walk_step_timer: float = 0.0
@export var energy_recovery_rate: float = 10.0
@export var energy_recovery_delay: float = 2.0

var energy: float = 0.0
var _sprint_recovery_timer: float = 0.0
var _is_sprinting: bool = false


func _ready() -> void:
	# Initialize energy
	energy = max_energy

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if mouse_captured:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			mouse_captured = false
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true

	if Input.is_action_pressed("grab"):
		grab()

	handle_movement(delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_and_slide()



func handle_movement(delta: float) -> void:
	if (%GameManager.is_game_over):
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var input_dir = Vector3.ZERO

	if Input.is_action_pressed("forward"):
		input_dir.z -= 1
	if Input.is_action_pressed("backward"):
		input_dir.z += 1
	if Input.is_action_pressed("left"):
		input_dir.x -= 1
	if Input.is_action_pressed("right"):
		input_dir.x += 1

	var is_moving = input_dir.length() > 0
	if is_moving:
		input_dir = input_dir.normalized()

	var speed = base_speed

	if Input.is_action_pressed("sneak"):
		speed = sneak_speed
	elif Input.is_action_pressed("run") and is_moving and energy > 0.0:
		# Sprint
		speed = run_speed
		_is_sprinting = true
		energy -= sprint_cost_per_second * delta
		energy = max(0.0, energy)
		_sprint_recovery_timer = 0.0
	else:
		_is_sprinting = false

	# Recovery when not sprinting after delay
	if not _is_sprinting:
		_sprint_recovery_timer += delta
		if _sprint_recovery_timer >= energy_recovery_delay:
			energy = min(max_energy, energy + energy_recovery_rate * delta)

	var forward = camera.global_transform.basis.z
	var right = camera.global_transform.basis.x

	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()

	var move_dir = (forward * input_dir.z + right * input_dir.x) * speed
	velocity.x = move_dir.x
	velocity.z = move_dir.z

	var should_play = is_moving
	_update_movement_audio(should_play)
	_handle_walk_cadence(get_process_delta_time())


func _update_movement_audio(should_play: bool) -> void:
	var desired: AudioStreamPlayer3D = null
	if not should_play:
		desired = null
	elif Input.is_action_pressed("sneak"):
		desired = sneak_audio
	elif _is_sprinting:
		desired = run_audio
	else:
		# Walking footsteps are handled by cadence; don't play continuous walk audio
		desired = null

	# Stop current if we no longer want it
	if desired == null:
		if _current_movement_audio != null and _current_movement_audio.is_playing():
			_current_movement_audio.stop()
		_current_movement_audio = null
		return

	# If switching, stop previous
	if _current_movement_audio == desired:
		if not desired.is_playing():
			desired.play()
		return

	if _current_movement_audio != null and _current_movement_audio.is_playing():
		_current_movement_audio.stop()

	_current_movement_audio = desired
	if not desired.is_playing():
		desired.play()


func _handle_walk_cadence(delta: float) -> void:
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	var moving = horiz_speed > 0.1 and is_on_floor()
	# If sneaking or sprinting, cadence shouldn't play
	if Input.is_action_pressed("sneak") or _is_sprinting or not moving:
		if walk_audio.is_playing():
			walk_audio.stop()
		_walk_step_timer = 0.0
		return

	var interval = walk_step_base_interval * (base_speed / max(horiz_speed, 0.01))
	interval = clamp(interval, walk_step_min_interval, walk_step_max_interval)

	_walk_step_timer -= delta
	if _walk_step_timer <= 0.0:
		walk_audio.play()
		_walk_step_timer = interval


func _input(event: InputEvent) -> void:
	if %GameManager.is_game_over:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		grab()

	if event is InputEventMouseMotion and mouse_captured:
		var motion = event as InputEventMouseMotion
		
		rotate_y(-motion.relative.x * mouse_sensitivity)
		
		camera.rotate_object_local(Vector3.RIGHT, -motion.relative.y * mouse_sensitivity)
		
		var camera_rot = camera.rotation.x
		camera.rotation.x = clamp(camera_rot, -PI / 2, PI / 2)


func grab() -> void:
	if _grab_on_cooldown:
		return

	_grab_on_cooldown = true

	var areas = $PlayerGrabArea.get_overlapping_areas()
	for area in areas:
		if area.name == "GnomeGrabArea":
			# Gnome -> GnomeBody -> GnomeGrabArea
			var gnome = area.get_parent().get_parent()
			if gnome.is_grabbable():
				%GameManager.gnome_caught()
				gnome.queue_free()
				break

	await get_tree().create_timer(grab_cooldown).timeout
	_grab_on_cooldown = false
