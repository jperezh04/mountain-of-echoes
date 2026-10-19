class_name TrajectoryPredictor
extends Node2D

@export var max_points: int = 30
@export var time_step: float = 0.045
@export var dot_radius: float = 3.2

var trajectory_points: PackedVector2Array = PackedVector2Array()
var collision_point: Vector2 = Vector2.ZERO
var has_collision: bool = false

func update_trajectory(start_pos: Vector2, initial_velocity: Vector2, gravity: float, linear_damp: float = 0.05) -> void:
	trajectory_points.clear()
	has_collision = false
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var prev_pos: Vector2 = start_pos
	trajectory_points.append(to_local(start_pos))

	for i in range(1, max_points + 1):
		var t: float = float(i) * time_step
		var damping_factor: float = clampf(1.0 - linear_damp * t * 0.5, 0.25, 1.0)
		var vx: float = initial_velocity.x * damping_factor
		var vy: float = initial_velocity.y * damping_factor

		var px: float = start_pos.x + vx * t
		var py: float = start_pos.y + vy * t + 0.5 * gravity * t * t
		var next_pos := Vector2(px, py)

		if space_state:
			var query := PhysicsRayQueryParameters2D.create(prev_pos, next_pos, 16)
			var hit: Dictionary = space_state.intersect_ray(query)
			if not hit.is_empty():
				has_collision = true
				collision_point = to_local(hit["position"])
				trajectory_points.append(collision_point)
				break

		trajectory_points.append(to_local(next_pos))
		prev_pos = next_pos
		if py > 286.0:
			break

	queue_redraw()

func clear_trajectory() -> void:
	trajectory_points.clear()
	has_collision = false
	queue_redraw()

func _draw() -> void:
	var count: int = trajectory_points.size()
	if count < 2:
		return

	for i in range(1, count):
		var ratio: float = float(i) / float(max_points)
		var alpha: float = clampf(1.0 - ratio * 0.72, 0.2, 0.95)
		var r: float = lerpf(dot_radius, 1.6, ratio)
		draw_circle(trajectory_points[i], r + 1.2, Color(0.12, 0.08, 0.04, alpha * 0.85))
		draw_circle(trajectory_points[i], r, Color(1.0, 0.95, 0.55, alpha))

	if has_collision:
		draw_circle(collision_point, 5.5, Color(1.0, 0.25, 0.2, 0.9))
		draw_arc(collision_point, 7.5, 0.0, TAU, 16, Color(1.0, 0.9, 0.2, 0.95), 1.6)
