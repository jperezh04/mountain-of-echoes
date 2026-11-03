class_name TopDownPlayer
extends CharacterBody2D
## Protagonista Top-Down para el Nivel 2 (Interior Abismal de la Montaña).
## Sin Dash (adolorido por la caída desde el Nivel 1); cuenta con Sprint por Estamina,
## Sigilo cubriendo su luz [E], Luz que se enfría, Mini-Bufo y Escudo Permanente.

const PlatformerPlayerScript = preload("res://moe_editable/scripts/player.gd")
const TEX_PANDA_TD := "res://moe_editable/art/panda_topdown.png"
const TEX_NYANKO_TD := "res://moe_editable/art/nyanko_topdown.png"

signal player_died(cause: String)
signal shield_absorbed_hit
signal instakill_survived_with_buff
signal exhausted_started

@export_group("Movimiento y Estamina")
@export var walk_speed: float = 98.0
@export var sprint_speed: float = 156.0
@export var exhausted_speed: float = 56.0
@export var stealth_speed: float = 42.0
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 34.0
@export var stamina_regen_rate: float = 24.0

@export_group("Iluminación en la Niebla")
@export var base_light_radius: float = 155.0
@export var min_light_radius: float = 68.0
@export var light_cool_rate: float = 0.016

var stamina: float = 100.0
var exhausted_timer: float = 0.0
var invulnerable_timer: float = 0.0
var panic_timer: float = 0.0
var stalk_flicker_timer: float = 0.0
var mini_buff_timer: float = 0.0
var adrenaline_timer: float = 0.0
var shake_timer: float = 0.0
var shake_intensity: float = 0.0

var light_heat: float = 1.0
var light_boost_mult: float = 1.0
var has_stamina_tonic: bool = false
var shield_active: bool = false
var is_stealth_hidden: bool = false
var near_hideout_count: int = 0
var on_ice_surface: bool = false
var locked: bool = false

var spawn_position: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2.UP
var walkway_layer: TileMapLayer = null

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var camera: Camera2D = $Camera2D
@onready var lantern_light: PointLight2D = $LanternLight
var aura_ring: Node2D = null


func _ready() -> void:
	spawn_position = global_position
	stamina = max_stamina
	shield_active = PlatformerPlayerScript.shield_unlocked
	_setup_light_texture()
	_setup_aura_ring()
	refresh_skin()


func _setup_light_texture() -> void:
	if not lantern_light:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.45, 0.78, 1.0])
	grad.colors = PackedColorArray([
		Color(1.0, 0.95, 0.86, 1.0),
		Color(0.88, 0.80, 0.96, 0.68),
		Color(0.45, 0.38, 0.68, 0.22),
		Color(0.0, 0.0, 0.0, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.gradient = grad
	lantern_light.texture = tex
	lantern_light.energy = 1.25
	lantern_light.blend_mode = Light2D.BLEND_MODE_ADD


func _setup_aura_ring() -> void:
	aura_ring = Node2D.new()
	aura_ring.name = "AuraVisual"
	aura_ring.z_index = -1
	add_child(aura_ring)


func refresh_skin() -> void:
	if not sprite:
		return
	var use_nyanko: bool = PlatformerPlayerScript.cat_skin_unlocked
	var path := TEX_NYANKO_TD if use_nyanko else TEX_PANDA_TD
	if not ResourceLoader.exists(path):
		return
	var sheet: Texture2D = load(path)
	if not sheet:
		return

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var anim_defs := [
		["idle_down", 0, 6.5, true],
		["run_down", 1, 11.0, true],
		["idle_up", 2, 6.5, true],
		["run_up", 3, 11.0, true],
		["run_side", 4, 11.5, true],
		["leap", 5, 10.0, true],
	]
	for def in anim_defs:
		var anim_name: String = def[0]
		var row_idx: int = def[1]
		var fps: float = def[2]
		var looped: bool = def[3]
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, looped)
		for col in range(6):
			var atlas := AtlasTexture.new()
			atlas.atlas = sheet
			atlas.region = Rect2(col * 32, row_idx * 32, 32, 32)
			frames.add_frame(anim_name, atlas)

	sprite.sprite_frames = frames
	sprite.scale = Vector2(1.35, 1.35)
	sprite.play("idle_up")


func shake_camera(intensity: float = 5.0, duration: float = 0.3) -> void:
	shake_intensity = intensity
	shake_timer = duration


func grant_permanent_shield() -> void:
	PlatformerPlayerScript.shield_unlocked = true
	shield_active = true


func apply_light_relic() -> void:
	light_boost_mult = 1.38
	light_heat = 1.0


func apply_stamina_tonic() -> void:
	has_stamina_tonic = true
	max_stamina = 145.0
	stamina = max_stamina
	stamina_regen_rate = 35.0


func grant_mini_buff(duration: float = 8.0) -> void:
	mini_buff_timer = maxf(mini_buff_timer, duration)
	light_heat = minf(1.0, light_heat + 0.35)


func refill_warmth(amount: float = 1.0, speed_burst: float = 0.0) -> void:
	light_heat = clampf(light_heat + amount, 0.0, 1.0)
	if speed_burst > 0.0:
		adrenaline_timer = maxf(adrenaline_timer, speed_burst)


func trigger_rancor_panic(duration: float = 5.5) -> void:
	panic_timer = maxf(panic_timer, duration)
	is_stealth_hidden = false
	shake_camera(6.5, 0.45)


func trigger_stalk_flicker() -> void:
	stalk_flicker_timer = 0.7


func is_making_noise() -> bool:
	if is_stealth_hidden:
		return false
	return velocity.length() > walk_speed * 1.12 or panic_timer > 0.0


func try_enter_instakill_zone(zone_name: String) -> bool:
	if locked or invulnerable_timer > 0.0:
		return true
	# ¡Salvada épica si el jugador entró con un Mini-Bufo activo!
	if mini_buff_timer > 0.0:
		mini_buff_timer = 0.0
		adrenaline_timer = 2.6
		invulnerable_timer = 2.0
		shake_camera(6.0, 0.35)
		instakill_survived_with_buff.emit()
		return true
	# Si no lleva Mini-Bufo, la zona prohibida es Instakill real (consume 1 vida directo)
	_die(zone_name)
	return false


func receive_shadow_attack(shadow_pos: Vector2) -> void:
	if locked or invulnerable_timer > 0.0:
		return
	if shield_active:
		shield_active = false
		invulnerable_timer = 2.2
		adrenaline_timer = 1.8
		var push_dir := (global_position - shadow_pos).normalized()
		if push_dir == Vector2.ZERO:
			push_dir = Vector2.UP
		velocity = push_dir * 210.0
		shake_camera(5.5, 0.3)
		shield_absorbed_hit.emit()
		return
	_die("shadow")


func _die(cause: String) -> void:
	locked = true
	velocity = Vector2.ZERO
	is_stealth_hidden = false
	shake_camera(8.0, 0.45)
	player_died.emit(cause)


func respawn_at_checkpoint() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	stamina = max_stamina
	exhausted_timer = 0.0
	panic_timer = 0.0
	light_heat = 1.0
	invulnerable_timer = 2.4
	is_stealth_hidden = false
	if PlatformerPlayerScript.shield_unlocked:
		shield_active = true
	locked = false
	if camera:
		camera.reset_smoothing()


func _physics_process(delta: float) -> void:
	_update_camera_shake(delta)
	_update_visual_rings()

	if locked:
		_update_light(delta)
		return

	invulnerable_timer = maxf(0.0, invulnerable_timer - delta)
	exhausted_timer = maxf(0.0, exhausted_timer - delta)
	panic_timer = maxf(0.0, panic_timer - delta)
	stalk_flicker_timer = maxf(0.0, stalk_flicker_timer - delta)
	mini_buff_timer = maxf(0.0, mini_buff_timer - delta)
	adrenaline_timer = maxf(0.0, adrenaline_timer - delta)

	# Enfriamiento progresivo de la luz en la caverna helada
	light_heat = maxf(0.0, light_heat - light_cool_rate * delta)

	# Sigilo [E]: cubrir el farol para ocultarse junto a estatuas/rincones
	if Input.is_action_just_pressed("moee_stealth"):
		is_stealth_hidden = not is_stealth_hidden

	# Detectar si pisa hielo subterráneo en el TileMap editable
	_check_ice_tile()

	var input_vec := Vector2(
		Input.get_axis("moee_left", "moee_right"),
		Input.get_axis("moee_up", "moee_down")
	)
	if input_vec.length() > 1.0:
		input_vec = input_vec.normalized()

	var wants_sprint := Input.is_action_pressed("moee_sprint") and input_vec.length() > 0.05 and exhausted_timer <= 0.0
	if wants_sprint:
		is_stealth_hidden = false

	var target_spd := walk_speed
	if is_stealth_hidden:
		target_spd = stealth_speed
	elif exhausted_timer > 0.0:
		target_spd = exhausted_speed
	elif wants_sprint:
		target_spd = sprint_speed
		var drain_mult := 0.55 if mini_buff_timer > 0.0 else 1.0
		stamina = maxf(0.0, stamina - stamina_drain_rate * drain_mult * delta)
		if stamina <= 0.0:
			exhausted_timer = 2.1
			exhausted_started.emit()

	if not wants_sprint and exhausted_timer <= 0.0:
		var regen_mult := 1.35 if input_vec.length() < 0.05 else 1.0
		stamina = minf(max_stamina, stamina + stamina_regen_rate * regen_mult * delta)

	if mini_buff_timer > 0.0:
		target_spd *= 1.18
	if adrenaline_timer > 0.0:
		target_spd *= 1.32

	var accel := 980.0
	if on_ice_surface and not has_stamina_tonic:
		accel = 260.0 # Inercia resbaladiza en sectores de permafrost
		target_spd *= 1.10

	velocity = velocity.move_toward(input_vec * target_spd, accel * delta)
	move_and_slide()

	if input_vec.length() > 0.08:
		facing_dir = input_vec.normalized()

	_update_animation(input_vec, wants_sprint)
	_update_light(delta)


func _check_ice_tile() -> void:
	on_ice_surface = false
	if not is_instance_valid(walkway_layer):
		return
	var local_pos := walkway_layer.to_local(global_position)
	var cell := walkway_layer.local_to_map(local_pos)
	var atlas := walkway_layer.get_cell_atlas_coords(cell)
	if atlas == Vector2i(8, 6) or atlas == Vector2i(9, 6):
		on_ice_surface = true


func _update_animation(input_vec: Vector2, is_sprinting: bool) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	sprite.speed_scale = 1.45 if is_sprinting else (0.72 if exhausted_timer > 0.0 else 1.0)
	var moving := input_vec.length() > 0.08

	if absf(facing_dir.x) > absf(facing_dir.y) * 1.15:
		sprite.flip_h = facing_dir.x < 0.0
		if moving:
			sprite.play("run_side")
		else:
			sprite.play("run_side")
			sprite.pause()
			sprite.frame = 2
	else:
		sprite.flip_h = false
		if facing_dir.y <= 0.0:
			sprite.play("run_up" if moving else "idle_up")
		else:
			sprite.play("run_down" if moving else "idle_down")

	# Tint feedback para estados especiales
	if invulnerable_timer > 0.0:
		sprite.visible = fmod(invulnerable_timer, 0.16) < 0.09
	else:
		sprite.visible = true

	if is_stealth_hidden:
		sprite.modulate = Color(0.42, 0.46, 0.65, 0.78)
	elif mini_buff_timer > 0.0 or adrenaline_timer > 0.0:
		sprite.modulate = Color(1.0, 0.92, 0.68, 1.0)
	elif exhausted_timer > 0.0:
		sprite.modulate = Color(0.85, 0.62, 0.66, 1.0)
	else:
		sprite.modulate = Color.WHITE


func _update_light(_delta: float) -> void:
	if not lantern_light:
		return
	var desired_r := lerpf(min_light_radius, base_light_radius * light_boost_mult, light_heat)
	if is_stealth_hidden:
		desired_r = 30.0 if near_hideout_count > 0 else 40.0
	elif panic_timer > 0.0:
		var pulse := 0.82 + 0.18 * sin(Time.get_ticks_msec() * 0.025)
		desired_r = 54.0 * pulse
	elif mini_buff_timer > 0.0:
		desired_r *= 1.22

	var target_scale := desired_r / 128.0
	lantern_light.texture_scale = lerpf(lantern_light.texture_scale, target_scale, 0.16)

	var base_e := 0.55 if is_stealth_hidden else (1.42 if mini_buff_timer > 0.0 else 1.22)
	if stalk_flicker_timer > 0.0:
		# Parpadeo inquietante tipo FNaF cuando la Sombra se reubica cerca
		base_e *= 0.25 if int(Time.get_ticks_msec() / 55) % 2 == 0 else 1.15
	elif panic_timer > 0.0:
		base_e *= 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.03)
	lantern_light.energy = base_e


func _update_camera_shake(delta: float) -> void:
	if not camera:
		return
	if shake_timer > 0.0:
		shake_timer -= delta
		camera.offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		if shake_timer <= 0.0:
			camera.offset = Vector2.ZERO


func _update_visual_rings() -> void:
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.005
	if shield_active:
		var r := 15.0 + sin(t * 2.0) * 1.2
		draw_arc(Vector2(0, 2), r, 0.0, TAU, 28, Color(0.56, 0.86, 1.0, 0.65), 1.6)
	if mini_buff_timer > 0.0:
		var rb := 18.5 + cos(t * 3.5) * 1.5
		draw_arc(Vector2(0, 2), rb, 0.0, TAU, 28, Color(1.0, 0.78, 0.35, 0.75), 1.8)
