extends CharacterBody2D

signal hurt
signal jumped
signal dashed
signal stomped

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

# Adaptabilidad y pulido visual/game feel
var gravity_scale := 1.0
var target_gravity_scale := 1.0
var shake_intensity := 0.0
var shake_timer := 0.0
var ghost_timer := 0.0
var was_on_floor := true

func _ready() -> void:
	spawn = global_position
	if sprite.sprite_frames and sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")

func shake_camera(intensity: float = 4.0, duration: float = 0.2) -> void:
	shake_intensity = intensity
	shake_timer = duration

func on_stomp() -> void:
	shake_camera(3.5, 0.15)
	stomped.emit()

func _physics_process(delta: float) -> void:
	if locked:
		return
		
	invulnerable = maxf(0, invulnerable - delta)
	cooldown = maxf(0, cooldown - delta)
	
	var on_floor := is_on_floor()
	coyote = 0.11 if on_floor else maxf(0, coyote - delta)
	buffer = maxf(0, buffer - delta)

	# Suavizado de la escala de gravedad adaptativa
	gravity_scale = move_toward(gravity_scale, target_gravity_scale, 0.8 * delta)

	# Reducción del temblor de cámara
	if shake_timer > 0.0:
		shake_timer -= delta
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO

	var axis := Input.get_axis("moee_left", "moee_right")
	if axis != 0:
		facing = signf(axis)
		
	if Input.is_action_just_pressed("moee_jump"):
		buffer = 0.13
		
	if Input.is_action_just_pressed("moee_dash") and cooldown <= 0:
		dash_time = dash_duration
		cooldown = dash_recharge
		ghost_timer = 0.0
		dashed.emit()
		_spawn_dash_ghost()

	if dash_time > 0:
		dash_time -= delta
		velocity = Vector2(facing * dash_speed, 0)
		ghost_timer -= delta
		if ghost_timer <= 0.0:
			ghost_timer = 0.04
			_spawn_dash_ghost()
	else:
		velocity.x = move_toward(velocity.x, axis * speed, 1600 * delta)
		var current_gravity := gravity * gravity_scale
		velocity.y = minf(780, velocity.y + current_gravity * delta)
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

	# Control de animaciones
	if invulnerable > 1.2 and sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
	elif dash_time > 0 and sprite.sprite_frames.has_animation("dash"):
		sprite.play("dash")
	elif not on_floor:
		sprite.play("run")
		sprite.pause()
		if velocity.y < 0:
			sprite.frame = 3 # Ascenso
		else:
			sprite.frame = 5 # Caída
	else:
		if absf(velocity.x) > 5:
			sprite.play("run")
		else:
			sprite.play("idle")

	sprite.modulate = Color(0.65, 1.0, 1.0) if dash_time > 0 else Color.WHITE
	sprite.visible = invulnerable <= 0 or fmod(invulnerable, 0.16) < 0.08
	
	was_on_floor = on_floor
	
	if global_position.y > fall_limit:
		take_hit(true)

func _spawn_dash_ghost() -> void:
	if not sprite or not get_parent():
		return
	var ghost := Sprite2D.new()
	var current_anim := sprite.animation
	var current_frame := sprite.frame
	if sprite.sprite_frames and sprite.sprite_frames.has_animation(current_anim):
		ghost.texture = sprite.sprite_frames.get_frame_texture(current_anim, current_frame)
	if not ghost.texture:
		ghost.queue_free()
		return
	ghost.global_position = sprite.global_position
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0.4, 0.85, 1.0, 0.6)
	ghost.z_index = z_index - 1
	get_parent().add_child(ghost)
	
	var tween := create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.22)
	tween.tween_callback(ghost.queue_free)

func take_hit(force := false) -> void:
	if locked or (not force and (invulnerable > 0 or dash_time > 0)):
		return
	global_position = spawn
	velocity = Vector2.ZERO
	dash_time = 0
	coyote = 0
	buffer = 0
	invulnerable = 1.6
	shake_camera(6.0, 0.25)
	camera.reset_smoothing()
	hurt.emit()
