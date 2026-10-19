class_name CatProjectile
extends RigidBody2D

signal cat_impacted(cat: CatProjectile, body: Node, impact_speed: float)
signal cat_stopped(cat: CatProjectile)
signal skill_activated(cat: CatProjectile)

enum CatType { NORMAL, TANK, ROCKET }
enum State { WAITING, AIMING, FLYING, HIT, CELEBRATING, DEFEATED }

@export var cat_type: CatType = CatType.NORMAL
@export var base_damage: float = 48.0
@export var damage_multiplier: float = 1.15
@export var stop_speed_threshold: float = 16.0
@export var max_flight_time: float = 6.5

var current_state: State = State.WAITING
var skill_used: bool = false
var flight_timer: float = 0.0
var settle_timer: float = 0.0
var last_velocity: Vector2 = Vector2.ZERO

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_particles: CPUParticles2D = $TrailParticles
@onready var impact_particles: CPUParticles2D = $ImpactParticles
@onready var sfx_hit: AudioStreamPlayer = $SfxHit
@onready var sfx_skill: AudioStreamPlayer = $SfxSkill

var tex_idle: Texture2D
var tex_aim: Texture2D
var tex_fly: Texture2D
var tex_hit: Texture2D
var tex_win: Texture2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 16
	freeze_mode = RigidBody2D.FREEZE_MODE_KINEMATIC
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_RAY
	can_sleep = false
	linear_damp = 0.05
	angular_damp = 0.8

	_configure_cat_type()
	body_entered.connect(_on_body_entered)
	set_state(State.WAITING)

func _configure_cat_type() -> void:
	var phys_mat := PhysicsMaterial.new()
	tex_idle = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_idle.png")
	tex_aim = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_aim.png")
	tex_fly = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_fly.png")
	tex_hit = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_hit.png")
	tex_win = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_win.png")

	match cat_type:
		CatType.NORMAL:
			mass = 2.0
			gravity_scale = 1.0
			damage_multiplier = 1.25
			phys_mat.bounce = 0.32
			phys_mat.friction = 0.55
		CatType.TANK:
			mass = 3.8
			gravity_scale = 1.08
			damage_multiplier = 2.1
			phys_mat.bounce = 0.18
			phys_mat.friction = 0.75
		CatType.ROCKET:
			mass = 1.8
			gravity_scale = 0.95
			damage_multiplier = 1.45
			phys_mat.bounce = 0.35
			phys_mat.friction = 0.45

	physics_material_override = phys_mat
	_update_visual_for_state()

func prepare_on_slingshot(anchor_pos: Vector2) -> void:
	freeze = true
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector2.ZERO
	angular_velocity = 0.0
	rotation = 0.0
	global_position = anchor_pos
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, anchor_pos))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, Vector2.ZERO)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	if sprite:
		sprite.scale = Vector2(0.85, 0.85)
		sprite.rotation = 0.0
	if trail_particles:
		trail_particles.emitting = false
	set_state(State.WAITING)

func apply_aim_deformation(stretch_ratio: float, aim_angle: float) -> void:
	set_state(State.AIMING)
	rotation = clampf(aim_angle, -0.65, 0.65)
	if sprite:
		var sx: float = 0.85 * (1.0 + stretch_ratio * 0.18)
		var sy: float = 0.85 * (1.0 - stretch_ratio * 0.12)
		sprite.scale = Vector2(sx, sy)

func launch(initial_velocity: Vector2) -> void:
	var start_pos: Vector2 = global_position
	start_pos.y = minf(start_pos.y, 262.0)
	global_position = start_pos
	if sprite:
		sprite.scale = Vector2(0.85, 0.85)
		sprite.rotation = 0.0
	collision_layer = 16
	collision_mask = 16
	freeze = false
	sleeping = false
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_TRANSFORM, Transform2D(0.0, start_pos))
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_LINEAR_VELOCITY, initial_velocity)
	PhysicsServer2D.body_set_state(get_rid(), PhysicsServer2D.BODY_STATE_ANGULAR_VELOCITY, 0.0)
	linear_velocity = initial_velocity
	last_velocity = initial_velocity
	flight_timer = 0.0
	settle_timer = 0.0
	skill_used = false
	set_state(State.FLYING)
	if trail_particles:
		trail_particles.emitting = true

func _input(event: InputEvent) -> void:
	if current_state != State.FLYING or skill_used:
		return
	var triggered: bool = false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		triggered = true
	elif event is InputEventKey and event.pressed:
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if k == KEY_SPACE or k == KEY_Z:
			triggered = true

	if triggered and flight_timer > 0.12:
		_activate_special_skill()

func _activate_special_skill() -> void:
	skill_used = true
	if sfx_skill:
		sfx_skill.play()
	if cat_type == CatType.ROCKET:
		var dir: Vector2 = linear_velocity.normalized()
		if dir.length() < 0.1:
			dir = Vector2.RIGHT
		linear_velocity = dir * 640.0 + Vector2(90.0, -45.0)
	elif cat_type == CatType.TANK:
		linear_velocity = Vector2(linear_velocity.x * 0.55, 560.0)
		damage_multiplier *= 1.35
	else:
		# Basic Cat chomp surge!
		var boost_dir: Vector2 = linear_velocity.normalized()
		if boost_dir.length() < 0.1:
			boost_dir = Vector2(1.0, -0.15).normalized()
		linear_velocity += boost_dir * 190.0
		damage_multiplier *= 1.2
	if sprite:
		var tw := create_tween()
		tw.tween_property(sprite, "scale", Vector2(1.15, 0.72), 0.07)
		tw.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.12)
	skill_activated.emit(self)

func _physics_process(delta: float) -> void:
	if current_state == State.FLYING or current_state == State.HIT:
		flight_timer += delta
		last_velocity = linear_velocity

		if current_state == State.FLYING and linear_velocity.length() > 35.0:
			rotation = clampf(linear_velocity.angle(), -0.8, 0.8)

		if linear_velocity.length() < stop_speed_threshold:
			settle_timer += delta
			if settle_timer >= 0.65:
				_finish_flight()
		else:
			settle_timer = 0.0

		if flight_timer >= max_flight_time or global_position.x > 690.0 or global_position.x < -60.0 or global_position.y > 400.0:
			_finish_flight()

func _on_body_entered(body: Node) -> void:
	if current_state != State.FLYING and current_state != State.HIT:
		return
	var impact_speed: float = last_velocity.length()
	if impact_speed > 65.0:
		if current_state == State.FLYING:
			set_state(State.HIT)
		if sfx_hit and not sfx_hit.playing:
			sfx_hit.play()
		if impact_particles:
			impact_particles.restart()
			impact_particles.emitting = true
		if sprite:
			var tween := create_tween()
			tween.tween_property(sprite, "scale", Vector2(1.12, 0.68), 0.05)
			tween.tween_property(sprite, "scale", Vector2(0.85, 0.85), 0.12)
		cat_impacted.emit(self, body, impact_speed)

func _finish_flight() -> void:
	if current_state == State.DEFEATED or current_state == State.CELEBRATING:
		return
	if trail_particles:
		trail_particles.emitting = false
	set_state(State.DEFEATED)
	cat_stopped.emit(self)

func set_state(new_state: State) -> void:
	current_state = new_state
	_update_visual_for_state()

func _update_visual_for_state() -> void:
	if not sprite:
		return
	match current_state:
		State.WAITING:
			if tex_idle:
				sprite.texture = tex_idle
		State.AIMING:
			if tex_aim:
				sprite.texture = tex_aim
		State.FLYING:
			if tex_fly:
				sprite.texture = tex_fly
		State.HIT, State.DEFEATED:
			if tex_hit:
				sprite.texture = tex_hit
		State.CELEBRATING:
			if tex_win:
				sprite.texture = tex_win
