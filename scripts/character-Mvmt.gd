class_name MovementCpt
extends CharacterBody2D
@onready var aimLine := $AimLine
@export var aimSteps := 60
@onready var launchSound := $LaunchSound
@onready var stickSound := $StickSound

@export var floorFrict := 800.0
@export var minLaunPwr := 250.0
@export var maxLaunPwr := 700.0
@export var chargeTime := 1.0

var charge := 0.0
var charging := false

var stuck := false

func _physics_process(delta: float) -> void:
	# 1. Gravity pulls the slime down, but not while it's stuck to a wall
	if not stuck and not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Slow the slime down when it slides along the floor
	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, floorFrict * delta)

	# 3. Click to launch, but only from a wall or the floor
		# 3. Hold to charge, release to launch
	if Input.is_action_just_pressed("launch") and (stuck or is_on_floor()):
		charging = true
		charge = 0.0

	if charging:
		if not (stuck or is_on_floor()):
			charging = false
		charge = minf(charge + delta / chargeTime, 1.0)

		if Input.is_action_just_released("launch"):
			var direction := global_position.direction_to(get_global_mouse_position())
			velocity = direction * lerpf(minLaunPwr, maxLaunPwr, charge)
			stuck = false
			charging = false
			launchSound.pitch_scale = randf_range(0.9, 1.1)
			launchSound.play()

	# 4. Move, and stick if we hit a wall
	if not stuck:
		move_and_slide()
		if is_on_wall() or is_on_ceiling():
			stuck = true
			velocity = Vector2.ZERO
			stickSound.play()
			
	update_aim()
			
func update_aim() -> void:
	aimLine.clear_points()
	if not charging:
		return

	var step := 1.0 / 60.0
	var direction := global_position.direction_to(get_global_mouse_position())
	var vel := direction * lerpf(minLaunPwr, maxLaunPwr, charge)
	var pos := global_position
	var space := get_world_2d().direct_space_state

	aimLine.add_point(aimLine.to_local(pos))

	for i in aimSteps:
		vel += get_gravity() * step
		var next_pos := pos + vel * step

		var query := PhysicsRayQueryParameters2D.create(pos, next_pos)
		query.exclude = [get_rid()]
		var hit := space.intersect_ray(query)

		if hit:
			aimLine.add_point(aimLine.to_local(hit.position))
			return

		aimLine.add_point(aimLine.to_local(next_pos))
		pos = next_pos
