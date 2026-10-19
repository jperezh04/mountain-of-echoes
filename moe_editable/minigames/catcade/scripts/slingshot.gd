class_name Slingshot
extends Node2D

signal cat_launched(cat: CatProjectile, initial_velocity: Vector2)

@export var max_pull_distance: float = 78.0
@export var min_pull_distance: float = 12.0
@export var launch_power_multiplier: float = 9.2
@export var gravity_value: float = 520.0

@onready var anchor_point: Marker2D = $AnchorPoint
@onready var band_back: Line2D = $BandBack
@onready var band_front: Line2D = $BandFront
@onready var predictor: TrajectoryPredictor = $TrajectoryPredictor
@onready var sfx_stretch: AudioStreamPlayer = $SfxStretch
@onready var sfx_launch: AudioStreamPlayer = $SfxLaunch

var current_cat: CatProjectile = null
var is_dragging: bool = false
var current_pull_vector: Vector2 = Vector2.ZERO

func _ready() -> void:
	_reset_bands()
	if predictor:
		predictor.clear_trajectory()

func load_cat(cat: CatProjectile) -> void:
	current_cat = cat
	is_dragging = false
	current_pull_vector = Vector2.ZERO
	if current_cat and anchor_point:
		current_cat.prepare_on_slingshot(anchor_point.global_position)
	_reset_bands()
	if predictor:
		predictor.clear_trajectory()

func _input(event: InputEvent) -> void:
	if not current_cat or not is_instance_valid(current_cat):
		return
	if current_cat.current_state != CatProjectile.State.WAITING and current_cat.current_state != CatProjectile.State.AIMING:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos: Vector2 = to_global(make_input_local(event).position)
		if event.pressed and not is_dragging:
			var dist_to_cat: float = mouse_pos.distance_to(current_cat.global_position)
			var dist_to_anchor: float = mouse_pos.distance_to(anchor_point.global_position)
			if dist_to_cat <= 68.0 or dist_to_anchor <= 75.0:
				is_dragging = true
				current_cat.set_state(CatProjectile.State.AIMING)
				if sfx_stretch and not sfx_stretch.playing:
					sfx_stretch.play()
				_update_drag(mouse_pos)
		elif not event.pressed and is_dragging:
			_release_slingshot()

	elif event is InputEventMouseMotion and is_dragging:
		var mouse_pos: Vector2 = to_global(make_input_local(event).position)
		_update_drag(mouse_pos)

func _process(_delta: float) -> void:
	if not is_dragging:
		return
	if not current_cat or not is_instance_valid(current_cat):
		is_dragging = false
		_reset_bands()
		return

func _update_drag(mouse_pos: Vector2) -> void:
	if not current_cat or not anchor_point:
		return
	var raw_drag: Vector2 = mouse_pos - anchor_point.global_position
	var pull_len: float = minf(raw_drag.length(), max_pull_distance)
	if raw_drag.length() > 0.001:
		current_pull_vector = raw_drag.normalized() * pull_len
	else:
		current_pull_vector = Vector2.ZERO

	var cat_pos: Vector2 = anchor_point.global_position + current_pull_vector
	cat_pos.y = minf(cat_pos.y, 295.0)
	current_pull_vector = cat_pos - anchor_point.global_position

	current_cat.global_position = cat_pos
	var stretch_ratio: float = clampf(current_pull_vector.length() / max_pull_distance, 0.0, 1.0)
	current_cat.apply_aim_deformation(stretch_ratio, -current_pull_vector.angle())

	_update_bands(cat_pos)

	if current_pull_vector.length() >= min_pull_distance:
		var launch_vel: Vector2 = calculate_launch_velocity()
		var damp: float = current_cat.linear_damp if current_cat.linear_damp > 0.0 else 0.05
		var traj_start := Vector2(cat_pos.x, minf(cat_pos.y, 262.0))
		if predictor:
			predictor.update_trajectory(traj_start, launch_vel, gravity_value * current_cat.gravity_scale, damp)
	else:
		if predictor:
			predictor.clear_trajectory()

func calculate_launch_velocity() -> Vector2:
	var launch_dir: Vector2 = -current_pull_vector.normalized()
	var pull_magnitude: float = current_pull_vector.length()
	var speed: float = pull_magnitude * launch_power_multiplier
	return launch_dir * speed

func _release_slingshot() -> void:
	is_dragging = false
	if predictor:
		predictor.clear_trajectory()
	_reset_bands()

	if not current_cat or not is_instance_valid(current_cat):
		return

	if current_pull_vector.length() >= min_pull_distance:
		var launch_vel: Vector2 = calculate_launch_velocity()
		var launched_cat: CatProjectile = current_cat
		current_cat = null
		if sfx_launch:
			sfx_launch.play()
		launched_cat.launch(launch_vel)
		cat_launched.emit(launched_cat, launch_vel)
	else:
		current_cat.prepare_on_slingshot(anchor_point.global_position)

func _update_bands(cat_global_pos: Vector2) -> void:
	var local_cat: Vector2 = to_local(cat_global_pos)
	if band_back:
		band_back.clear_points()
		band_back.add_point(Vector2(-7, -26))
		band_back.add_point(local_cat)
	if band_front:
		band_front.clear_points()
		band_front.add_point(Vector2(7, -26))
		band_front.add_point(local_cat)

func _reset_bands() -> void:
	var rest_pos: Vector2 = anchor_point.position if anchor_point else Vector2(0, -26)
	if band_back:
		band_back.clear_points()
		band_back.add_point(Vector2(-7, -26))
		band_back.add_point(rest_pos)
	if band_front:
		band_front.clear_points()
		band_front.add_point(Vector2(7, -26))
		band_front.add_point(rest_pos)
