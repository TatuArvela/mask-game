extends Node3D

var body: StaticBody3D
var alert_area: Area3D
var grab_area: Area3D

@export var hiding_spot: Marker3D
@export var idle_spot: Marker3D

@export var movement_speed: float = 10.0
@export var stop_distance: float = 0.5
@export var jump_delay_duration: float = 0.5
@export var jump_curve: Curve

enum GnomeState {
	IDLE,
	ALERT,
	GRABBED,
	WILL_JUMP_TO_IDLE,
	WILL_JUMP_TO_HIDING,
	JUMP_TO_IDLE,
	JUMP_TO_HIDING
}

var state: GnomeState = GnomeState.WILL_JUMP_TO_IDLE
var jump_delay: float = 0.0
var jump_progress: float = 0.0
var jump_start_height: float = 0.0

func _ready() -> void:
	body = $GnomeBody
	alert_area = $AlertArea
	grab_area = $GrabArea

	if not hiding_spot:
		push_error("Hiding Spot not assigned for Gnome entity.")

	if not idle_spot:
		push_error("Idle Spot not assigned for Gnome entity.")

	if hiding_spot:
		body.global_position = hiding_spot.global_position


func _process(delta: float) -> void:
	if jump_delay > 0:
		jump_delay -= delta
	if jump_delay <= 0:
		if state == GnomeState.WILL_JUMP_TO_IDLE:
			state = GnomeState.JUMP_TO_IDLE
		elif state == GnomeState.WILL_JUMP_TO_HIDING:
			state = GnomeState.JUMP_TO_HIDING
	
	if state == GnomeState.IDLE:
		pass

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
	
	if state == GnomeState.GRABBED:
		# Logic for when the gnome is grabbed can be implemented here
		pass


func _on_alert_area_body_entered(_body: Node3D) -> void:
	if state != GnomeState.GRABBED:
		state = GnomeState.WILL_JUMP_TO_HIDING
		jump_delay = jump_delay_duration
		jump_progress = 0.0
		jump_start_height = body.global_position.y


func _on_alert_area_body_exited(_body: Node3D) -> void:
	if state != GnomeState.GRABBED:
		state = GnomeState.WILL_JUMP_TO_IDLE
		jump_delay = jump_delay_duration
		jump_progress = 0.0
		jump_start_height = body.global_position.y
