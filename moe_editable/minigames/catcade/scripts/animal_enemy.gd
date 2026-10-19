class_name AnimalEnemy
extends RigidBody2D

signal enemy_defeated(enemy: AnimalEnemy, points: int)
signal enemy_damaged(enemy: AnimalEnemy, damage: float)

enum EnemyType { DOGE, PIGGE, DUCK, BOSS_BOAR }

@export var enemy_type: EnemyType = EnemyType.DOGE
@export var max_hp: float = 35.0
@export var score_value: int = 1000
@export var min_damage_speed: float = 28.0

var current_hp: float = 35.0
var is_defeated: bool = false
var wobble_time: float = 0.0
var startup_grace: float = 0.45
var base_scale: Vector2 = Vector2(0.85, 0.85)

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var sfx_defeat: AudioStreamPlayer = $SfxDefeat

func _ready() -> void:
	collision_layer = 16
	collision_mask = 16
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = true
	wobble_time = randf() * TAU

	_configure_enemy_type()
	current_hp = max_hp
	body_entered.connect(_on_body_entered)

func _configure_enemy_type() -> void:
	var phys_mat := PhysicsMaterial.new()
	phys_mat.friction = 0.85
	phys_mat.bounce = 0.12

	var tex_path: String = "res://moe_editable/minigames/catcade/assets/enemies/enemy_doge.png"
	var radius: float = 13.0

	match enemy_type:
		EnemyType.DOGE:
			max_hp = 28.0
			mass = 1.1
			score_value = 1000
			tex_path = "res://moe_editable/minigames/catcade/assets/enemies/enemy_doge.png"
			radius = 12.0
			base_scale = Vector2(0.82, 0.82)
		EnemyType.PIGGE:
			max_hp = 52.0
			mass = 1.8
			score_value = 1800
			tex_path = "res://moe_editable/minigames/catcade/assets/enemies/enemy_pigge.png"
			radius = 14.0
			base_scale = Vector2(0.85, 0.85)
		EnemyType.DUCK:
			max_hp = 26.0
			mass = 1.0
			score_value = 1200
			tex_path = "res://moe_editable/minigames/catcade/assets/enemies/enemy_duck.png"
			radius = 12.0
			base_scale = Vector2(0.82, 0.82)
		EnemyType.BOSS_BOAR:
			max_hp = 85.0
			mass = 2.6
			score_value = 3500
			tex_path = "res://moe_editable/minigames/catcade/assets/enemies/enemy_boss_boar.png"
			radius = 16.0
			base_scale = Vector2(0.85, 0.85)

	physics_material_override = phys_mat
	if sprite and ResourceLoader.exists(tex_path):
		sprite.texture = load(tex_path)
		sprite.scale = base_scale
	if collision_shape:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision_shape.shape = circle

func _physics_process(delta: float) -> void:
	if is_defeated:
		return
	if startup_grace > 0.0:
		startup_grace -= delta
	wobble_time += delta * 4.5
	if sprite and linear_velocity.length() < 12.0:
		sprite.scale = Vector2(
			base_scale.x * (1.0 + sin(wobble_time) * 0.03),
			base_scale.y * (1.0 - sin(wobble_time) * 0.03)
		)

	# Out of bounds or knocked off the platform
	if global_position.y > 360.0 or global_position.x > 660.0 or global_position.x < -30.0:
		take_damage(9999.0)

func _on_body_entered(body: Node) -> void:
	if is_defeated or startup_grace > 0.0:
		return

	var rel_speed: float = linear_velocity.length()
	var dmg_mult: float = 1.0

	if body is RigidBody2D:
		rel_speed = (linear_velocity - body.linear_velocity).length()
		if body is CatProjectile:
			dmg_mult = body.damage_multiplier * 1.9
		else:
			dmg_mult = clampf(body.mass * 0.75, 0.6, 2.5)

	if rel_speed >= min_damage_speed:
		var dmg: float = (rel_speed - min_damage_speed * 0.6) * 0.48 * dmg_mult
		take_damage(dmg)

func take_damage(amount: float) -> void:
	if is_defeated or amount <= 0.0:
		return
	current_hp -= amount
	enemy_damaged.emit(self, amount)

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "modulate", Color(1.0, 0.25, 0.25), 0.05)
		tween.parallel().tween_property(sprite, "scale", Vector2(base_scale.x * 1.25, base_scale.y * 0.7), 0.05)
		tween.tween_property(sprite, "modulate", Color.WHITE, 0.1)
		tween.parallel().tween_property(sprite, "scale", base_scale, 0.1)

	if current_hp <= 0.0:
		_defeat()

func _defeat() -> void:
	if is_defeated:
		return
	is_defeated = true
	collision_layer = 0
	collision_mask = 0
	freeze = true

	if sfx_defeat:
		sfx_defeat.play()

	_spawn_score_popup()
	enemy_defeated.emit(self, score_value)

	if sprite:
		var tween := create_tween()
		tween.tween_property(sprite, "scale", base_scale * 1.45, 0.14)
		tween.parallel().tween_property(sprite, "rotation", TAU, 0.18)
		tween.parallel().tween_property(sprite, "modulate", Color(1, 1, 1, 0), 0.2)
		tween.tween_callback(queue_free)
	else:
		queue_free()

func _spawn_score_popup() -> void:
	var lbl := Label.new()
	lbl.text = "+%d" % score_value
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.modulate = Color(1.0, 0.92, 0.15)
	lbl.position = position + Vector2(-18, -28)
	lbl.z_index = 40
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node.add_child(lbl)
		var tw := lbl.create_tween()
		tw.tween_property(lbl, "position:y", lbl.position.y - 26.0, 0.55)
		tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.55)
		tw.tween_callback(lbl.queue_free)
	else:
		lbl.queue_free()
