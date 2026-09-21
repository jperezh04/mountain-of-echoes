extends CharacterBody2D
## Standalone controller. Its actions are registered by level.gd.
signal hurt
signal jumped
var spawn := Vector2(100, 340)
var invulnerable := 0.0
var coyote := 0.0
var buffered_jump := 0.0
var dash_time := 0.0
var dash_cooldown := 0.0
var facing := 1.0
var locked := false
var sprite := AnimatedSprite2D.new()
var camera := Camera2D.new()

func _ready() -> void:
	name = "Panda"
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 5
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 26)
	collider.shape = shape
	collider.position.y = -14
	add_child(collider)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ["idle", "run"]:
		frames.add_animation(anim)
		frames.set_animation_speed(anim, 10)
		for col in range(8):
			var tile := AtlasTexture.new()
			tile.atlas = preload("res://moe_snow_demo/art/panda.png")
			tile.region = Rect2(col * 32, (0 if anim == "idle" else 2) * 32, 32, 32)
			frames.add_frame(anim, tile)
	sprite.sprite_frames = frames
	sprite.position.y = -32
	sprite.scale = Vector2(2, 2)
	add_child(sprite)
	camera.position = Vector2(90, -100)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6
	camera.limit_left = 0
	camera.limit_right = 4320
	camera.limit_top = -120
	camera.limit_bottom = 680
	add_child(camera)
	sprite.play("idle")

func _physics_process(delta: float) -> void:
	invulnerable = maxf(0, invulnerable - delta)
	dash_cooldown = maxf(0, dash_cooldown - delta)
	coyote = 0.11 if is_on_floor() else maxf(0, coyote - delta)
	buffered_jump = maxf(0, buffered_jump - delta)
	var axis := 0.0 if locked else Input.get_axis("moe_left", "moe_right")
	if axis != 0:
		facing = signf(axis)
	if not locked and Input.is_action_just_pressed("moe_jump"):
		buffered_jump = 0.13
	if not locked and Input.is_action_just_pressed("moe_dash") and dash_cooldown <= 0:
		dash_time = 0.15
		dash_cooldown = 0.8
	if dash_time > 0:
		dash_time -= delta
		velocity = Vector2(facing * 620, 0)
	else:
		velocity.x = move_toward(velocity.x, axis * 260, 1600 * delta)
		velocity.y = minf(velocity.y + 1200 * delta, 780)
		if buffered_jump > 0 and coyote > 0:
			velocity.y = -490
			buffered_jump = 0
			coyote = 0
			jumped.emit()
		if Input.is_action_just_released("moe_jump") and velocity.y < -220:
			velocity.y = -220
	move_and_slide()
	# Do not replenish coyote time immediately after initiating a jump.
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
	if position.y > 670:
		take_hit(true)

func take_hit(force: bool = false) -> void:
	if locked or (not force and (invulnerable > 0 or dash_time > 0)):
		return
	position = spawn
	velocity = Vector2.ZERO
	dash_time = 0
	coyote = 0
	buffered_jump = 0
	invulnerable = 1.6
	camera.reset_smoothing()
	hurt.emit()
