extends CharacterBody2D

@export var speed: float = 150.0
@export var jump_speed: float = 310.0
@export var gravity: float = 850.0

var spawn_position := Vector2.ZERO
var coyote_time: float = 0.0
var jump_buffer: float = 0.0
var sprite := AnimatedSprite2D.new()


func _ready() -> void:
	spawn_position = global_position
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 12)
	collision.shape = shape
	collision.position = Vector2(0, -6)
	add_child(collision)

	var sheet: Texture2D = preload("res://assets/player/red_panda.png")
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Filas comprobadas en el JSON del panda.
	for animation_name in ["idle", "run"]:
		frames.add_animation(animation_name)
		frames.set_animation_speed(animation_name, 10.0)
		var row: int = 0 if animation_name == "idle" else 2

		for column in range(8):
			var frame := AtlasTexture.new()
			frame.atlas = sheet
			frame.region = Rect2(column * 32, row * 32, 32, 32)
			frames.add_frame(animation_name, frame)

	sprite.sprite_frames = frames
	sprite.position = Vector2(0, -16)
	add_child(sprite)
	sprite.play("idle")

	var camera := Camera2D.new()
	camera.position = Vector2(0, -55)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	add_child(camera)


func _physics_process(delta: float) -> void:
	var direction: float = Input.get_axis("ui_left", "ui_right")
	velocity.x = move_toward(velocity.x, direction * speed, 1200.0 * delta)

	# Pequeño margen para saltar después de abandonar un borde.
	if is_on_floor():
		coyote_time = 0.10
	else:
		coyote_time = maxf(coyote_time - delta, 0.0)
		velocity.y = minf(velocity.y + gravity * delta, 600.0)

	jump_buffer = maxf(jump_buffer - delta, 0.0)
	if Input.is_action_just_pressed("ui_accept"):
		jump_buffer = 0.12

	if jump_buffer > 0.0 and coyote_time > 0.0:
		velocity.y = -jump_speed
		jump_buffer = 0.0
		coyote_time = 0.0

	# Soltar antes el botón produce un salto más corto.
	if Input.is_action_just_released("ui_accept") and velocity.y < -100.0:
		velocity.y = -100.0

	move_and_slide()

	if direction != 0.0:
		sprite.flip_h = direction < 0.0

	if not is_on_floor():
		sprite.play("run")
		sprite.pause()
		sprite.frame = 3
	elif absf(velocity.x) > 5.0:
		sprite.play("run")
	else:
		sprite.play("idle")

	if global_position.y > 650.0:
		respawn()


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	coyote_time = 0.0
	jump_buffer = 0.0
	get_viewport().get_camera_2d().reset_smoothing()