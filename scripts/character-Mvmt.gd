extends CharacterBody2D
@onready var aim_line := $AimLine
@export var aim_steps := 60
@onready var launch_sound := $LaunchSound
@onready var stick_sound := $StickSound

@export var floor_friction := 800.0
@export var min_launch_power := 250.0
@export var max_launch_power := 700.0
@export var charge_time := 1.0

var charge := 0.0
var charging := false

var stuck := false

func _physics_process(delta: float) -> void:
	# 1. Gravity pulls the slime down, but not while it's stuck to a wall
	if not stuck and not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Slow the slime down when it slides along the floor
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, floor_friction * delta)

	# 3. Click to launch, but only from a wall or the floor
		# 3. Hold to charge, release to launch
	if Input.is_action_just_pressed("launch") and (stuck or is_on_floor()):
		charging = true
		charge = 0.0

	if charging:
		if not (stuck or is_on_floor()):
			charging = false
		charge = minf(charge + delta / charge_time, 1.0)

		if Input.is_action_just_released("launch"):
			var direction := global_position.direction_to(get_global_mouse_position())
			velocity = direction * lerpf(min_launch_power, max_launch_power, charge)
			stuck = false
			charging = false
			launch_sound.pitch_scale = randf_range(0.9, 1.1)
			launch_sound.play()

	# 4. Move, and stick if we hit a wall
	if not stuck:
		move_and_slide()
		if is_on_wall() or is_on_ceiling():
			stuck = true
			velocity = Vector2.ZERO
			stick_sound.play()
			
	update_aim()
			
func update_aim() -> void:
	aim_line.clear_points()
	if not charging:
		return

	var step := 1.0 / 60.0
	var direction := global_position.direction_to(get_global_mouse_position())
	var vel := direction * lerpf(min_launch_power, max_launch_power, charge)
	var pos := global_position
	var space := get_world_2d().direct_space_state

	aim_line.add_point(aim_line.to_local(pos))

	for i in aim_steps:
		vel += get_gravity() * step
		var next_pos := pos + vel * step

		var query := PhysicsRayQueryParameters2D.create(pos, next_pos)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)

		if hit:
			aim_line.add_point(aim_line.to_local(hit.position))
			return

		aim_line.add_point(aim_line.to_local(next_pos))
		pos = next_pos
