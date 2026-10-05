@tool
extends CharacterBody2D
## Reynolds-style steering: wander on a projected circle; seek toward the player.
## State switching adds sight, hysteresis, terrain collision and a home leash.
enum State { WANDER, SEEK, RETURN, STUNNED }
@export var detect_radius := 210.0
@export var lose_radius := 310.0
@export var max_speed := 165.0
@export var max_acceleration := 360.0
@export var home_leash := 370.0
@export var patrol_half_size := Vector2(125, 55)
@export var show_detection_in_editor := false:
	set(value):
		show_detection_in_editor = value
		queue_redraw()
var state := State.WANDER
var home := Vector2.ZERO
var target: CharacterBody2D
var roam_bounds := Rect2()
var wander_angle := 0.0
var wander_target := Vector2.ZERO
var heading := Vector2.RIGHT
var lost_time := 0.0
var stunned_time := 0.0
var debug_visible := false
var clock := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	if Engine.is_editor_hint():
		set_physics_process(false)
		queue_redraw()
		return
	home = global_position
	rng.seed = int(home.x * 17 + home.y)
	collision_layer = 4
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if roam_bounds.size == Vector2.ZERO:
		roam_bounds = Rect2(home - patrol_half_size, patrol_half_size * 2)

func can_see_player() -> bool:
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position + Vector2(0, -16), 1)
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	clock += delta
	if not is_instance_valid(target):
		return
	var player_point := target.global_position + Vector2(0, -16)
	var distance := global_position.distance_to(player_point)
	var visible_target: bool = distance < lose_radius and can_see_player() and not target.locked
	var aim := home
	var speed := max_speed
	if state == State.STUNNED:
		stunned_time -= delta
		velocity = velocity.move_toward(Vector2.ZERO, max_acceleration * delta)
		if stunned_time <= 0:
			state = State.RETURN
	else:
		if state == State.WANDER and distance < detect_radius and visible_target:
			state = State.SEEK
			lost_time = 0
		if state == State.SEEK:
			lost_time = 0.0 if visible_target else lost_time + delta
			if lost_time > 0.8 or global_position.distance_to(home) > home_leash:
				state = State.RETURN
		if state == State.RETURN and global_position.distance_to(home) < 22:
			state = State.WANDER
		if state == State.WANDER:
			# Smooth random angular changes; a circle ahead of the current heading.
			wander_angle += rng.randf_range(-2.8, 2.8) * sqrt(delta)
			if velocity.length() > 8:
				heading = velocity.normalized()
			wander_target = global_position + heading * 65 + Vector2.from_angle(wander_angle) * 42
			wander_target.x = clampf(wander_target.x, roam_bounds.position.x, roam_bounds.end.x)
			wander_target.y = clampf(wander_target.y, roam_bounds.position.y, roam_bounds.end.y)
			aim = wander_target
			speed = max_speed * 0.42
		elif state == State.SEEK:
			aim = player_point
		else:
			aim = home
			speed *= minf(global_position.distance_to(home) / 65, 1)
		var desired_velocity := (aim - global_position).normalized() * speed
		var steering := ((desired_velocity - velocity) / 0.25).limit_length(max_acceleration)
		velocity = (velocity + steering * delta).limit_length(speed)
	move_and_slide()
	if get_slide_collision_count() > 0:
		heading = heading.bounce(get_slide_collision(0).get_normal())
		wander_angle += PI * 0.6
	# Stomp to stun; dashing grants contact immunity via the player's controller.
	if state != State.STUNNED and distance < 33 and not target.locked:
		if target.velocity.y > 70 and target.global_position.y < global_position.y - 5:
			stun()
			target.velocity.y = -370
			if target.has_method("on_stomp"):
				target.on_stomp()
		else:
			target.take_hit()
	queue_redraw()

func stun() -> void:
	state = State.STUNNED
	stunned_time = 3.5
	if has_node("Visual"):
		var tw := create_tween()
		tw.tween_property($Visual, "scale", Vector2(1.45, 0.55), 0.08)
		tw.tween_property($Visual, "scale", Vector2.ONE, 0.16)

func reset_guardian() -> void:
	global_position = home
	velocity = Vector2.ZERO
	state = State.WANDER
	lost_time = 0
	if has_node("Visual"):
		$Visual.scale = Vector2.ONE

func _draw() -> void:
	var tint := Color("81e7df")
	if state == State.SEEK:
		tint = Color("ff8e80")
	elif state == State.STUNNED:
		tint = Color("7488a4")
	var bob := sin(clock * 4) * 3
	if has_node("Visual") and not Engine.is_editor_hint():
		$Visual.position.y = bob
		$Visual/Body.color = tint
	if state == State.SEEK:
		draw_string(ThemeDB.fallback_font, Vector2(-3, -32 + bob), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 19, tint)
	if debug_visible or (Engine.is_editor_hint() and show_detection_in_editor):
		draw_arc(Vector2.ZERO, detect_radius, 0, TAU, 64, Color(tint, 0.3), 1)
		draw_line(Vector2.ZERO, velocity * 0.5, Color.YELLOW, 2)
		if state == State.WANDER:
			if not Engine.is_editor_hint():
				draw_circle(to_local(wander_target), 4, Color.YELLOW)
		draw_string(ThemeDB.fallback_font, Vector2(-30, -44), ["WANDER", "SEEK", "RETURN", "STUNNED"][state], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)
