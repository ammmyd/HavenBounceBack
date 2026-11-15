extends CharacterBody2D
@onready var sprite := $AnimatedSprite2D
@onready var aimLine := $AimLine
@export var aimSteps := 60
@onready var launchSound := $LaunchSound
@onready var stickSound := $StickSound

@export var floorFrict := 800.0
@export var minLaunPwr := 500.0
@export var maxLaunPwr := 1200.0
@export var chargeTime := 1.0
@export var bounceTimes := 0
@export var maxBounces := 1
@export var bounceKeep := 0.6

var charge := 0.0
var charging := false

var stuck := false
var dead := false
var direction

func _physics_process(delta: float) -> void:
	if dead:
		return
	if not stuck and not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor():
		velocity.x = move_toward(velocity.x, 0.0, floorFrict * delta)

	if Input.is_action_just_pressed("launch") and (stuck or is_on_floor()):
		charging = true
		charge = 0.0

	if charging:
		if not (stuck or is_on_floor()):
			charging = false
		charge = minf(charge + delta / chargeTime, 1.0)

		if Input.is_action_just_released("launch"):
			direction = global_position.direction_to(get_global_mouse_position())
			velocity = direction * lerpf(minLaunPwr, maxLaunPwr, charge)
			stuck = false
			bounceTimes = 0
			charging = false
			launchSound.pitch_scale = randf_range(0.9, 1.1)
			launchSound.play()

	if not stuck:
		var impact_velocity := velocity
		move_and_slide()
		if is_on_wall() or is_on_ceiling():
			if bounceTimes < maxBounces:
				bounceTimes += 1
				var normal := get_last_slide_collision().get_normal()
				velocity = impact_velocity.bounce(normal) * bounceKeep
			else:
				stuck = true
				velocity = Vector2.ZERO
				stickSound.play()
			
	update_aim()
	update_aim()
	update_animation()
	print("Current velocity: ", velocity)
	
func die() -> void:
	if dead:
		return
	dead = true
	charging = false
	velocity = Vector2.ZERO
	aimLine.clear_points()
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("slimeDead")

	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()
			

func play_anim(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func update_animation() -> void:
	if stuck:
		play_anim("slimeSplat")
	elif is_on_floor():
		if absf(velocity.x) > 20.0:
			play_anim("slimeWalk")
		else:
			play_anim("slimeIdle")
	else:
		play_anim("slimeJump")

	if absf(velocity.x) > 10.0:
		sprite.flip_h = velocity.x < 0.0

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
