extends CharacterBody2D
@export var next_level: PackedScene
var won := false
@onready var sprite := $AnimatedSprite2D
@onready var aimLine := $AimLine
@export var aimSteps := 60
@onready var launchSound := $LaunchSound
@onready var stickSound := $StickSound
@onready var deathSound := $DeathSound

@export var crawlSpeed := 120.0
@export var crawlAccel := 1000.0
@export var stickMinSpeed := 250.0

@onready var stand_shape: CollisionShape2D = $CollisionShape2D
@onready var crawl_shape: CollisionShape2D = $Crawl
@onready var ceiling_check: RayCast2D = $CeilingCheck
var crawling := false

@export var floorFrict := 800.0
@export var minLaunPwr := 500.0
@export var maxLaunPwr := 1200.0
@export var chargeTime := 1.0
@export var bounceTimes := 0
@export var maxBounces := 1
@export var bounceKeep := 1

@export var jumpPower := 600.0
var airLaunchReady := false

var charge := 0.0
var charging := false

var stuck := false
var dead := false
var direction

func _physics_process(delta: float) -> void:
	if dead or won:
		return
	var cramped := ceiling_check.is_colliding()
	#print(cramped)
	if not stuck and not is_on_floor():
		velocity += get_gravity() * delta

	if is_on_floor():
		var move_input := Input.get_axis("moveLeft", "moveRight")
		if move_input != 0.0 and not charging and not stuck:
			velocity.x = move_toward(velocity.x, move_input * crawlSpeed, crawlAccel * delta)
		else:
			velocity.x = move_toward(velocity.x, 0.0, floorFrict * delta)
		airLaunchReady = false
		if Input.is_action_just_pressed("jump") and not charging and not stuck and not cramped:
			velocity.y = -jumpPower
			airLaunchReady = true

	var launch_blocked := is_on_floor() and (crawling or cramped)
	if Input.is_action_just_pressed("launch") and not launch_blocked and (stuck or is_on_floor() or airLaunchReady):
		charging = true
		charge = 0.0

	if charging:
		if not (stuck or is_on_floor() or airLaunchReady):
			charging = false
		charge = minf(charge + delta / chargeTime, 1.0)

		if Input.is_action_just_released("launch"):
			direction = global_position.direction_to(get_global_mouse_position())
			velocity = direction * lerpf(minLaunPwr, maxLaunPwr, charge)
			stuck = false
			bounceTimes = 0
			charging = false
			airLaunchReady = false
			launchSound.pitch_scale = randf_range(0.9, 1.1)
			launchSound.play()
		

	if not stuck:
		var impact_velocity := velocity
		move_and_slide()

		for i in get_slide_collision_count():
			var collider := get_slide_collision(i).get_collider() as Node
			if collider and collider.is_in_group("hazard"):
				die()
				return
			if collider and collider.is_in_group("nextLevelTrigger"):
				win()
				return

		if (is_on_wall() or is_on_ceiling()) and impact_velocity.length() > stickMinSpeed:
			if bounceTimes < maxBounces:
				bounceTimes += 1
				var normal := get_last_slide_collision().get_normal()
				velocity = impact_velocity.bounce(normal) * bounceKeep
			#else:
			#	stuck = true
			#	velocity = Vector2.ZERO
			#	stickSound.play()
			
	update_aim()
	update_crawl_state()
	update_animation()
	#print("Current velocity: ", velocity)
	
func die() -> void:
	if dead:
		return
	dead = true
	charging = false
	velocity = Vector2.ZERO
	aimLine.clear_points()
	stand_shape.set_deferred("disabled", true)
	crawl_shape.set_deferred("disabled", true)
	sprite.play("slimeDead")
	deathSound.play()

	await get_tree().create_timer(0.6).timeout
	get_tree().reload_current_scene()
	
func update_crawl_state() -> void:
	var crawl_input := Input.get_axis("moveLeft", "moveRight") != 0.0
	var wants_crawl := is_on_floor() and crawl_input and not charging and not stuck
	var blocked_above := ceiling_check.is_colliding()

	if wants_crawl:
		set_crawling(true)
	elif crawling and not blocked_above:
		set_crawling(false)

func set_crawling(value: bool) -> void:
	if crawling == value:
		return
	crawling = value
	stand_shape.set_deferred("disabled", value)
	crawl_shape.set_deferred("disabled", not value)

func win() -> void:
	if won or dead:
		return
	won = true
	charging = false
	velocity = Vector2.ZERO
	aimLine.clear_points()
	sprite.play("slimeEating")

	await sprite.animation_finished
	if next_level:
		get_tree().change_scene_to_packed(next_level)
	else:
		print("No next level set")

func play_anim(anim: StringName) -> void:
	if sprite.animation != anim:
		sprite.play(anim)

func update_animation() -> void:
	var move_input := Input.get_axis("moveLeft", "moveRight")

	if stuck:
		play_anim("slimeSplat")
	elif is_on_floor():
		if crawling and move_input != 0.0:
			play_anim("slimeWalk")
		else:
			play_anim("slimeIdle")
	else:
		play_anim("slimeJump")

	if is_on_floor() and move_input != 0.0 and not charging:
		sprite.flip_h = move_input < 0.0
	elif absf(velocity.x) > 10.0:
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
