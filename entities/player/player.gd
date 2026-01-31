extends CharacterBody3D

@export var sneak_speed: float = 1.0
@export var base_speed: float = 4.0
@export var run_speed: float = 10.0

@export var mouse_sensitivity: float = 0.01
@export var gravity: float = 9.8

@export var grab_cooldown: float = 0.3

var camera: Camera3D
var mouse_captured: bool = false
var _grab_on_cooldown: bool = false

# Sprint energy system
@export var max_energy: float = 100.0
@export var sprint_cost_per_second: float = 40.0
@export var energy_recovery_rate: float = 10.0
@export var energy_recovery_delay: float = 2.0

var energy: float = 0.0
var _sprint_recovery_timer: float = 0.0
var _is_sprinting: bool = false


func _ready() -> void:
	camera = $Camera3D
	
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


func _input(event: InputEvent) -> void:
	#if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
	#	grab()
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
