extends CharacterBody2D

@export var speed := 60.0
var dir := 1.0
@onready var sprite := $AnimatedSprite2D

func _ready() -> void:
	sprite.play("default")

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	velocity.x = dir * speed
	move_and_slide()

	if is_on_wall():
		turn_around()

func turn_around() -> void:
	dir = -dir
	sprite.flip_h = dir > 0.0
