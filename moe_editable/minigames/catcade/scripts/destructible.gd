class_name DestructibleBlock
extends RigidBody2D

signal destroyed(points: int)

enum MaterialType { WOOD, STONE, ICE }
enum BlockShape { BEAM_H, BEAM_V, BOX, TRIANGLE }

@export var material_type: MaterialType = MaterialType.WOOD
@export var block_shape: BlockShape = BlockShape.BEAM_V
@export var max_hp: float = 55.0
@export var score_value: int = 120
@export var custom_size: Vector2 = Vector2.ZERO

var current_hp: float = 55.0
var is_destroyed: bool = false
var startup_grace: float = 0.45

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	collision_layer = 16
	collision_mask = 16
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	can_sleep = true

	var phys_mat := PhysicsMaterial.new()
	match material_type:
		MaterialType.WOOD:
			max_hp = 50.0
			mass = 1.4
			score_value = 120
			phys_mat.friction = 0.85
			phys_mat.bounce = 0.05
		MaterialType.STONE:
			max_hp = 110.0
			mass = 3.2
			score_value = 250
			phys_mat.friction = 0.92
			phys_mat.bounce = 0.02
		MaterialType.ICE:
			max_hp = 30.0
			mass = 0.9
			score_value = 150
			phys_mat.friction = 0.65
			phys_mat.bounce = 0.08

	physics_material_override = phys_mat
	current_hp = max_hp
	_apply_visuals()
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float) -> void:
	if startup_grace > 0.0:
		startup_grace -= delta
	if global_position.y > 420.0 and not is_destroyed:
		_destroy()

func _apply_visuals() -> void:
	if not sprite or not collision_shape:
		return
	var tex_path: String = ""
	var default_size: Vector2 = Vector2(64, 16)

	match material_type:
		MaterialType.WOOD:
			match block_shape:
				BlockShape.BEAM_H:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/wood_beam_h.png"
					default_size = Vector2(64, 14)
				BlockShape.BEAM_V:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/wood_beam_v.png"
					default_size = Vector2(14, 64)
				BlockShape.BOX, BlockShape.TRIANGLE:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/wood_box.png"
					default_size = Vector2(28, 28)
		MaterialType.STONE:
			match block_shape:
				BlockShape.BEAM_H:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/stone_beam_h.png"
					default_size = Vector2(64, 14)
				BlockShape.BEAM_V:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/stone_beam_v.png"
					default_size = Vector2(14, 64)
				BlockShape.BOX, BlockShape.TRIANGLE:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/stone_box.png"
					default_size = Vector2(28, 28)
		MaterialType.ICE:
			match block_shape:
				BlockShape.BEAM_H:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/ice_beam_h.png"
					default_size = Vector2(64, 14)
				BlockShape.BEAM_V:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/ice_beam_v.png"
					default_size = Vector2(14, 64)
				BlockShape.BOX:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/ice_box.png"
					default_size = Vector2(28, 28)
				BlockShape.TRIANGLE:
					tex_path = "res://moe_editable/minigames/catcade/assets/structures/ice_triangle.png"
					default_size = Vector2(36, 32)

	var target_size: Vector2 = custom_size if custom_size != Vector2.ZERO else default_size

	if ResourceLoader.exists(tex_path):
		var tex: Texture2D = load(tex_path)
		sprite.texture = tex
		if tex:
			sprite.scale = Vector2(target_size.x / float(tex.get_width()), target_size.y / float(tex.get_height()))

	if block_shape == BlockShape.TRIANGLE:
		var poly := ConvexPolygonShape2D.new()
		var hw: float = target_size.x * 0.48
		var hh: float = target_size.y * 0.48
		poly.points = PackedVector2Array([
			Vector2(0.0, -hh),
			Vector2(hw, hh),
			Vector2(-hw, hh)
		])
		collision_shape.shape = poly
	else:
		var rect := RectangleShape2D.new()
		rect.size = target_size
		collision_shape.shape = rect

func _on_body_entered(body: Node) -> void:
	if is_destroyed or startup_grace > 0.0:
		return
	var rel_speed: float = linear_velocity.length()
	var impact_mult: float = 1.0
	if body is RigidBody2D:
		rel_speed = (linear_velocity - body.linear_velocity).length()
		if body is CatProjectile:
			impact_mult = body.damage_multiplier * 1.45
		else:
			impact_mult = clampf(body.mass * 0.45, 0.4, 2.0)

	if rel_speed > 55.0:
		var dmg: float = (rel_speed - 45.0) * 0.24 * impact_mult
		take_damage(dmg)

func take_damage(amount: float) -> void:
	if is_destroyed or amount <= 0.0:
		return
	current_hp -= amount
	var ratio: float = clampf(current_hp / max_hp, 0.0, 1.0)
	if sprite:
		if material_type == MaterialType.ICE:
			sprite.modulate = Color(0.8 + 0.2 * ratio, 0.9 + 0.1 * ratio, 1.0, 0.65 + 0.35 * ratio)
		else:
			sprite.modulate = Color(1.0, 0.55 + 0.45 * ratio, 0.55 + 0.45 * ratio)
	if current_hp <= 0.0:
		_destroy()

func _destroy() -> void:
	if is_destroyed:
		return
	is_destroyed = true
	destroyed.emit(score_value)
	queue_free()
