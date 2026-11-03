class_name AbyssInteractable
extends Area2D
## Nodo interactivo modular y 100% editable en el Inspector de Godot para el Nivel 2.
## Cubre Runas de Memoria, Faroles de Alma, Escudo Permanente, Reliquias, Mini-Bufos,
## Ecos de Rencor (trampas psicológicas), Zonas Instakill, Escondites, Campanas y Salida.

@export_enum(
	"memory_rune",
	"soul_lantern",
	"permanent_shield",
	"light_boost",
	"stamina_tonic",
	"mini_buff_ember",
	"rancor_trap",
	"instakill_zone",
	"hideout",
	"echo_bell",
	"echo_orb",
	"ascent_exit"
) var kind: String = "echo_orb"

@export var rune_id: int = 1
@export var title_text: String = ""
@export_multiline var lore_text: String = ""
@export var cooldown_duration: float = 9.5
@export var required_runes: int = 3

var activated: bool = false
var cooldown_timer: float = 0.0
var ring_wave_timer: float = 0.0
var glitch_phase: float = 0.0
var base_visual_pos: Vector2 = Vector2.ZERO

var glow_light: PointLight2D = null
var visual_root: Node2D = null


func _ready() -> void:
	glitch_phase = randf() * 10.0
	if has_node("Visual"):
		visual_root = $Visual
		base_visual_pos = visual_root.position
	if has_node("GlowLight"):
		glow_light = $GlowLight
	else:
		_create_default_light_if_needed()
	_configure_light_appearance()


func _create_default_light_if_needed() -> void:
	if kind in ["hideout", "instakill_zone"]:
		return
	glow_light = PointLight2D.new()
	glow_light.name = "GlowLight"
	add_child(glow_light)


func _configure_light_appearance() -> void:
	if not glow_light:
		return
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	var c_mid := Color(0.75, 0.58, 1.0, 0.55)
	var scale_val := 0.55
	var energy_val := 0.85

	match kind:
		"soul_lantern":
			c_mid = Color(1.0, 0.78, 0.42, 0.72) if activated else Color(0.48, 0.58, 0.85, 0.35)
			scale_val = 0.92 if activated else 0.32
			energy_val = 1.25 if activated else 0.42
		"memory_rune":
			c_mid = Color(0.76, 0.52, 1.0, 0.75)
			scale_val = 0.68 if not activated else 0.28
			energy_val = 1.10 if not activated else 0.35
		"permanent_shield":
			c_mid = Color(0.42, 0.90, 1.0, 0.80)
			scale_val = 0.65
			energy_val = 1.15
		"light_boost", "stamina_tonic":
			c_mid = Color(0.48, 0.95, 0.88, 0.72)
			scale_val = 0.56
			energy_val = 0.95
		"mini_buff_ember":
			c_mid = Color(1.0, 0.72, 0.28, 0.78)
			scale_val = 0.58
			energy_val = 1.05
		"rancor_trap":
			# Luce casi idéntico a una reliquia/runa buena desde lejos en la niebla
			c_mid = Color(0.78, 0.56, 0.98, 0.72)
			scale_val = 0.56
			energy_val = 0.95
		"echo_bell":
			c_mid = Color(0.55, 0.85, 1.0, 0.65)
			scale_val = 0.48
			energy_val = 0.80
		"echo_orb":
			c_mid = Color(0.55, 0.92, 1.0, 0.65)
			scale_val = 0.38
			energy_val = 0.75
		"ascent_exit":
			c_mid = Color(0.72, 0.88, 1.0, 0.80)
			scale_val = 1.05
			energy_val = 1.15

	grad.colors = PackedColorArray([
		Color(1.0, 0.98, 0.95, 1.0),
		c_mid,
		Color(0.0, 0.0, 0.0, 0.0)
	])
	var tex := GradientTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.gradient = grad
	glow_light.texture = tex
	glow_light.texture_scale = scale_val
	glow_light.energy = energy_val


func activate_permanent() -> void:
	activated = true
	if kind == "soul_lantern":
		_configure_light_appearance()
		if visual_root:
			visual_root.modulate = Color(1.0, 0.92, 0.72, 1.0)
	elif kind == "memory_rune":
		_configure_light_appearance()
		if visual_root:
			visual_root.modulate = Color(0.55, 0.50, 0.72, 0.45)
	else:
		if visual_root:
			visual_root.visible = false
		if glow_light:
			glow_light.enabled = false
		set_deferred("monitoring", false)
	queue_redraw()


func trigger_cooldown(custom_time: float = -1.0) -> void:
	cooldown_timer = custom_time if custom_time > 0.0 else cooldown_duration
	if kind == "echo_bell":
		ring_wave_timer = 0.85
	if visual_root and kind == "mini_buff_ember":
		visual_root.modulate = Color(0.45, 0.42, 0.52, 0.35)
	if glow_light and kind == "mini_buff_ember":
		glow_light.energy = 0.22
	queue_redraw()


func is_ready_to_use() -> bool:
	return not activated and cooldown_timer <= 0.0


func _process(delta: float) -> void:
	if cooldown_timer > 0.0:
		cooldown_timer = maxf(0.0, cooldown_timer - delta)
		if cooldown_timer <= 0.0 and kind == "mini_buff_ember":
			if visual_root:
				visual_root.modulate = Color.WHITE
			if glow_light:
				glow_light.energy = 1.05

	if ring_wave_timer > 0.0:
		ring_wave_timer = maxf(0.0, ring_wave_timer - delta)
		queue_redraw()

	var t := Time.get_ticks_msec() * 0.001 + glitch_phase
	if visual_root and visual_root.visible:
		if kind == "rancor_trap" and not activated:
			# Señal sutil de cerca: cada ~1.8s tirita 0.13s con destello carmesí
			var cyc := fmod(t, 1.85)
			if cyc < 0.13:
				visual_root.position = base_visual_pos + Vector2(randf_range(-1.8, 1.8), randf_range(-1.5, 1.5))
				visual_root.modulate = Color(1.0, 0.36, 0.50, 0.96)
			else:
				visual_root.position = base_visual_pos + Vector2(0.0, sin(t * 2.8) * 1.6)
				visual_root.modulate = Color.WHITE
		elif kind in ["memory_rune", "permanent_shield", "light_boost", "stamina_tonic", "mini_buff_ember", "echo_orb"] and not activated:
			visual_root.position = base_visual_pos + Vector2(0.0, sin(t * 2.8) * 1.8)

	if kind in ["soul_lantern", "instakill_zone", "mini_buff_ember", "ascent_exit"]:
		queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.004 + glitch_phase
	if kind == "soul_lantern" and activated:
		var r := 5.5 + sin(t * 2.2) * 1.0
		draw_circle(Vector2(0, -5), r, Color(1.0, 0.78, 0.32, 0.55))
		draw_circle(Vector2(0, -6), 2.8, Color(1.0, 0.96, 0.80, 0.95))
	elif kind == "mini_buff_ember" and cooldown_timer <= 0.0:
		var r2 := 8.5 + sin(t * 2.6) * 1.3
		draw_arc(Vector2.ZERO, r2, 0.0, TAU, 20, Color(1.0, 0.76, 0.28, 0.65), 1.4)
	elif kind == "instakill_zone" and cooldown_timer <= 0.0:
		# Pupilas abismales que parpadean levemente en las grietas de la zona prohibida
		var blink := 0.35 + 0.55 * maxf(0.0, sin(t * 0.9))
		draw_circle(Vector2(-7, -4), 1.4, Color(0.96, 0.20, 0.38, blink))
		draw_circle(Vector2(-3, -4), 1.4, Color(0.96, 0.20, 0.38, blink))
		draw_circle(Vector2(6, 5), 1.3, Color(0.96, 0.20, 0.38, blink * 0.85))
		draw_circle(Vector2(10, 5), 1.3, Color(0.96, 0.20, 0.38, blink * 0.85))
	elif kind == "echo_bell" and ring_wave_timer > 0.0:
		var prog := 1.0 - (ring_wave_timer / 0.85)
		draw_arc(Vector2.ZERO, lerpf(6.0, 56.0, prog), 0.0, TAU, 28, Color(0.52, 0.92, 1.0, 1.0 - prog), 2.0)
