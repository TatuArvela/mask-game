extends Node3D

@onready
var body: StaticBody3D = $GnomeBody
@onready
var gnome_mesh: MeshInstance3D = $GnomeBody/GnomeMesh
@onready
var scheming_audio: AudioStreamPlayer3D = $SchemingAudio
@onready
var snow_whoosh_audio: AudioStreamPlayer3D = $SnowWhooshAudio

@export var alert_area: Area3D
@export var hiding_spot: Marker3D
@export var idle_spot: Marker3D

@export var movement_speed: float = 10.0
@export var stop_distance: float = 0.5
@export var jump_delay_duration: float = 0.5
@export var jump_curve: Curve
@export var texture_override_options: Array[Texture2D] = []

# Idle rotation randomization
@export var idle_rotation_min_interval: float = 1.0
@export var idle_rotation_max_interval: float = 3.0

enum GnomeState {
	IDLE,
	ALERT,
	WILL_JUMP_TO_IDLE,
	WILL_JUMP_TO_HIDING,
	JUMP_TO_IDLE,
	JUMP_TO_HIDING,
	GRABBED
}

var state: GnomeState = GnomeState.WILL_JUMP_TO_IDLE
var jump_delay: float = 0.0
var jump_progress: float = 0.0
var jump_start_height: float = 0.0
var debug_material: StandardMaterial3D
var player: Node3D
var rng: RandomNumberGenerator
var chosen_texture: Texture2D = null

# idle rotation runtime state
var idle_elapsed: float = 0.0
var idle_duration: float = 0.0
var idle_start_offset: float = 0.0
var idle_target_offset: float = 0.0
var idle_current_offset: float = 0.0


func _ready() -> void:
	if hiding_spot:
		body.global_position = hiding_spot.global_position

	# RNG and initialize idle rotation target
	rng = RandomNumberGenerator.new()
	rng.randomize()
	idle_current_offset = 0.0
	idle_start_offset = 0.0
	idle_target_offset = 0.0
	idle_elapsed = 0.0
	idle_duration = rng.randf_range(idle_rotation_min_interval, idle_rotation_max_interval)

	# Choose random texture override
	if texture_override_options.size() > 0:
		var texture_index = rng.randi_range(0, texture_override_options.size() - 1)
		chosen_texture = texture_override_options[texture_index]
		var material = StandardMaterial3D.new()
		material.albedo_texture = chosen_texture
		gnome_mesh.set_surface_override_material(0, material)

func _process(delta: float) -> void:
	if jump_delay > 0:
		jump_delay -= delta
	if jump_delay <= 0:
		if state == GnomeState.WILL_JUMP_TO_IDLE:
			state = GnomeState.JUMP_TO_IDLE
		elif state == GnomeState.WILL_JUMP_TO_HIDING:
			state = GnomeState.JUMP_TO_HIDING

	if state == GnomeState.IDLE:
		idle_elapsed += delta
		if idle_duration > 0.0 and idle_elapsed >= idle_duration:
			_play_scheming()
			_schedule_new_idle_target()

	if state == GnomeState.ALERT:
		pass

	if state == GnomeState.JUMP_TO_IDLE:
		snow_whoosh_audio.play()
		var distance = body.global_position.distance_to(idle_spot.global_position)
		if distance > stop_distance:
			jump_progress += movement_speed * delta / distance
			jump_progress = min(jump_progress, 1.0)
			
			var direction = (idle_spot.global_position - body.global_position).normalized()
			body.global_position += direction * movement_speed * delta
			
			if jump_curve:
				var curve_value = jump_curve.sample(jump_progress)
				var target_height = lerp(jump_start_height, 0.0, jump_progress)
				body.global_position.y = target_height + curve_value
		else:
			jump_progress = 0.0
			body.global_position.y = 0.0
			state = GnomeState.IDLE
	
	if state == GnomeState.JUMP_TO_HIDING:
		snow_whoosh_audio.play()
		var distance = body.global_position.distance_to(hiding_spot.global_position)
		if distance > stop_distance:
			jump_progress += movement_speed * delta / distance
			jump_progress = min(jump_progress, 1.0)
			
			var direction = (hiding_spot.global_position - body.global_position).normalized()
			body.global_position += direction * movement_speed * delta
			
			if jump_curve:
				var curve_value = jump_curve.sample(jump_progress)
				var target_height = lerp(jump_start_height, 0.0, jump_progress)
				body.global_position.y = target_height + curve_value
		else:
			jump_progress = 0.0
			body.global_position.y = 0.0
			state = GnomeState.ALERT
	
	if state == GnomeState.ALERT || state == GnomeState.WILL_JUMP_TO_HIDING:
		body.look_at(%Player.global_position, Vector3.UP)


func _schedule_new_idle_target() -> void:
	# Choose any yaw immediately (instant rotation)
	var new_yaw = rng.randf_range(-PI, PI)
	body.rotation.y = new_yaw
	idle_elapsed = 0.0
	idle_duration = rng.randf_range(idle_rotation_min_interval, idle_rotation_max_interval)


func _on_alert_area_body_entered(_body: Node3D) -> void:
	state = GnomeState.WILL_JUMP_TO_HIDING
	jump_delay = jump_delay_duration
	jump_progress = 0.0
	jump_start_height = body.global_position.y


func _on_alert_area_body_exited(_body: Node3D) -> void:
	state = GnomeState.WILL_JUMP_TO_IDLE
	jump_delay = jump_delay_duration
	jump_progress = 0.0
	jump_start_height = body.global_position.y


func _play_scheming() -> void:
	if !scheming_audio.playing:
		scheming_audio.play()


func is_grabbable() -> bool:
	if state == GnomeState.IDLE or state == GnomeState.WILL_JUMP_TO_HIDING or state == GnomeState.JUMP_TO_IDLE:
		return true
	return false


func on_grabbed() -> void:
	state = GnomeState.GRABBED
