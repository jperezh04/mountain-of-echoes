extends CharacterBody2D
signal hurt
signal jumped
@export_range(50, 600) var speed := 260.0
@export_range(100, 900) var jump_speed := 490.0
@export_range(100, 2500) var gravity := 1200.0
@export var fall_limit := 680.0
@export var dash_speed := 620.0
@export var dash_duration := 0.15
@export var dash_recharge := 0.8
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D
var spawn := Vector2.ZERO
var invulnerable := 0.0
var coyote := 0.0
var buffer := 0.0
var dash_time := 0.0
var cooldown := 0.0
var facing := 1.0
var locked := false

func _ready() -> void:
	spawn = global_position
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	if locked:
		return
	invulnerable = maxf(0, invulnerable - delta)
	cooldown = maxf(0, cooldown - delta)
	coyote = 0.11 if is_on_floor() else maxf(0, coyote - delta)
	buffer = maxf(0, buffer - delta)
	var axis := Input.get_axis("moee_left", "moee_right")
	if axis != 0:
		facing = signf(axis)
	if Input.is_action_just_pressed("moee_jump"):
		buffer = 0.13
	if Input.is_action_just_pressed("moee_dash") and cooldown <= 0:
		dash_time = dash_duration
		cooldown = dash_recharge
	if dash_time > 0:
		dash_time -= delta
		velocity = Vector2(facing * dash_speed, 0)
	else:
		velocity.x = move_toward(velocity.x, axis * speed, 1600 * delta)
		velocity.y = minf(780, velocity.y + gravity * delta)
		if coyote > 0 and buffer > 0:
			velocity.y = -jump_speed
			coyote = 0
			buffer = 0
			jumped.emit()
		if Input.is_action_just_released("moee_jump") and velocity.y < -220:
			velocity.y = -220
	move_and_slide()
	if velocity.y < 0:
		coyote = 0
	sprite.flip_h = facing < 0
	if not is_on_floor():
		sprite.play("run")
		sprite.pause()
		sprite.frame = 3
	else:
		sprite.play("run" if absf(velocity.x) > 5 else "idle")
	sprite.modulate = Color(0.5, 1, 1) if dash_time > 0 else Color.WHITE
	sprite.visible = invulnerable <= 0 or fmod(invulnerable, 0.16) < 0.08
	if global_position.y > fall_limit:
		take_hit(true)

func take_hit(force := false) -> void:
	if locked or (not force and (invulnerable > 0 or dash_time > 0)):
		return
	global_position = spawn
	velocity = Vector2.ZERO
	dash_time = 0
	coyote = 0
	buffer = 0
	invulnerable = 1.6
	camera.reset_smoothing()
	hurt.emit()
