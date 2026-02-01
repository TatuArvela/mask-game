extends CharacterBody3D

@export var sneak_speed: float = 1.0
@export var base_speed: float = 4.0
@export var run_speed: float = 10.0

@export var mouse_sensitivity: float = 0.01
@export var gravity: float = 9.8

@export var grab_cooldown: float = 0.3

@export var hand_bounce_amplitude_deg: float = 3.0
@export var hand_bounce_frequency: float = 3.0
@export var hand_bounce_smooth: float = 8.0
@export var hand_bounce_run_multiplier: float = 3.0

@onready
var camera: Camera3D = $Camera3D

@onready
var sneak_audio: AudioStreamPlayer3D = $SneakAudio
@onready
var walk_audio: AudioStreamPlayer3D = $WalkAudio
@onready
var run_audio: AudioStreamPlayer3D = $RunAudio

@onready
var left_hand: Node3D = %LeftHand
@onready
var right_hand: Node3D = %RightHand

var _current_movement_audio: AudioStreamPlayer3D = null

var _hand_bounce_time: float = 0.0
var _hand_current_angle: float = 0.0

var _grab_on_cooldown: bool = false

# Run energy system
@export var max_energy: float = 100.0
@export var run_cost_per_second: float = 20.0

# Walking cadence (seconds per step scales with speed)
@export var walk_step_base_interval: float = 0.5
@export var walk_step_min_interval: float = 0.2
@export var walk_step_max_interval: float = 0.75
var _walk_step_timer: float = 0.0
@export var energy_recovery_rate: float = 10.0
@export var energy_recovery_delay: float = 2.0

var energy: float = 0.0
var _run_recovery_timer: float = 0.0
var _is_running: bool = false


func _ready() -> void:
	# Initialize energy
	energy = max_energy


func _process(delta: float) -> void:
	if Input.is_action_pressed("grab"):
		grab()

	handle_movement(delta)
	
	if not is_on_floor():
		velocity.y -= gravity * delta
	
	move_and_slide()

	_update_hand_bounce(delta)


func handle_movement(delta: float) -> void:
	# The is_paused could be exploitable in some other game, but here it's fine
	if (%GameManager.is_game_over or %GameManager.is_paused):
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
		# Run
		speed = run_speed
		_is_running = true
		energy -= run_cost_per_second * delta
		energy = max(0.0, energy)
		_run_recovery_timer = 0.0
	else:
		_is_running = false

	# Recovery when not running after delay
	if not _is_running:
		_run_recovery_timer += delta
		if _run_recovery_timer >= energy_recovery_delay:
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
	elif _is_running:
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
	# If sneaking or running, cadence shouldn't play
	if Input.is_action_pressed("sneak") or _is_running or not moving:
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


func _update_hand_bounce(delta: float) -> void:
	var horiz_speed = Vector2(velocity.x, velocity.z).length()
	var moving_factor = 0.0
	if is_on_floor():
		moving_factor = clamp(horiz_speed / max(base_speed, 0.01), 0.0, 1.0)

	if moving_factor <= 0.01:
		_hand_current_angle = lerp(_hand_current_angle, 0.0, clamp(delta * hand_bounce_smooth, 0.0, 1.0))
		left_hand.rotation_degrees.x = _hand_current_angle
		left_hand.rotation_degrees.y = _hand_current_angle
		right_hand.rotation_degrees.x = - _hand_current_angle
		right_hand.rotation_degrees.y = _hand_current_angle
		return

	_hand_bounce_time += delta
	var angle_rad = sin(_hand_bounce_time * hand_bounce_frequency * PI * 2.0)
	var target_deg = angle_rad * hand_bounce_amplitude_deg * moving_factor * (hand_bounce_run_multiplier if _is_running else 1.0)

	_hand_current_angle = lerp(_hand_current_angle, target_deg, clamp(delta * hand_bounce_smooth, 0.0, 1.0))

	left_hand.rotation_degrees.x = _hand_current_angle
	left_hand.rotation_degrees.y = _hand_current_angle
	right_hand.rotation_degrees.x = - _hand_current_angle
	right_hand.rotation_degrees.y = _hand_current_angle


func _input(event: InputEvent) -> void:
	if %GameManager.is_game_over or %GameManager.is_paused:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		grab()

	if event is InputEventMouseMotion and %GameManager.mouse_captured:
		var motion = event as InputEventMouseMotion
		
		rotate_y(-motion.relative.x * mouse_sensitivity)
		
		camera.rotate_object_local(Vector3.RIGHT, -motion.relative.y * mouse_sensitivity)
		
		var camera_rot = camera.rotation.x
		camera.rotation.x = clamp(camera_rot, -PI / 2, PI / 2)


func grab() -> void:
	if _grab_on_cooldown:
		return

	_grab_on_cooldown = true

	var audio_to_play: AudioStreamPlayer3D = $MissAudio

	var areas = $PlayerGrabArea.get_overlapping_areas()
	for area in areas:
		if area.name == "GnomeGrabArea":
			var gnome = area.get_parent().get_parent() # Gnome -> GnomeBody -> GnomeGrabArea
			if gnome.is_grabbable():
				audio_to_play = $GrabAudio
				if gnome.has_method("set_process"):
					gnome.set_process(false)
					gnome.set_physics_process(false)

				var move_node: Node = gnome

				var preserved_transform: Transform3D = move_node.global_transform
				var old_parent := move_node.get_parent()
				if old_parent:
					old_parent.remove_child(move_node)
					add_child(move_node)
					move_node.global_transform = preserved_transform

				var local_start: Vector3 = move_node.position

				var offset: float = 5.0
				var local_target: Vector3 = Vector3(offset, local_start.y, local_start.z + offset)

				var total_dur: float = 0.5
				var elapsed: float = 0.0
				var start_scale: Vector3 = move_node.scale
				while elapsed < total_dur:
					var t = elapsed / total_dur
					move_node.position = local_start.lerp(local_target, t)
					# Scale down over the whole animation
					move_node.scale = start_scale.lerp(Vector3.ZERO, t)
					await get_tree().process_frame
					elapsed += get_process_delta_time()

				move_node.position = local_target
				move_node.scale = Vector3.ZERO

				%GameManager.gnome_caught()
				gnome.queue_free()
				break

	audio_to_play.play()

	await get_tree().create_timer(grab_cooldown).timeout
	_grab_on_cooldown = false
