extends Node3D

@onready
var body: StaticBody3D = $GnomeBody
@onready
var grab_area: Area3D = $GrabArea
@onready
var gnome_mesh: Node3D = $GnomeBody/gnome
@onready
var scheming: AudioStreamPlayer3D = $Scheming

@export var alert_area: Area3D
@export var hiding_spot: Marker3D
@export var idle_spot: Marker3D

@export var movement_speed: float = 10.0
@export var stop_distance: float = 0.5
@export var jump_delay_duration: float = 0.5
@export var jump_curve: Curve

# Idle rotation randomization
@export var idle_rotation_min_interval: float = 1.0
@export var idle_rotation_max_interval: float = 3.0

enum GnomeState {
	IDLE,
	ALERT,
	WILL_JUMP_TO_IDLE,
	WILL_JUMP_TO_HIDING,
	JUMP_TO_IDLE,
	JUMP_TO_HIDING
}

var state: GnomeState = GnomeState.WILL_JUMP_TO_IDLE
var jump_delay: float = 0.0
var jump_progress: float = 0.0
var jump_start_height: float = 0.0
var debug_material: StandardMaterial3D
var player: Node3D
var rng: RandomNumberGenerator

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
	if !scheming.playing:
		scheming.play()


func is_grabbable() -> bool:
	if state == GnomeState.IDLE or state == GnomeState.WILL_JUMP_TO_HIDING or state == GnomeState.JUMP_TO_IDLE:
		return true
	return false


func _set_mesh_material(node: Node3D, material: Material) -> void:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		for i in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(i, material)
	
	for child in node.get_children():
		if child is Node3D:
			_set_mesh_material(child as Node3D, material)


func _clear_mesh_material(node: Node3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		for i in range(mesh_instance.get_surface_override_material_count()):
			mesh_instance.set_surface_override_material(i, null)
	
	for child in node.get_children():
		if child is Node3D:
			_clear_mesh_material(child as Node3D)
