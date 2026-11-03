extends Node2D
## Controlador principal del Nivel 2: "02 / VALLE DE LA SOMBRA DEL ECO" (Top-Down).
## Escena 100% editable en Godot Editor: las capas TileMapLayer y los prefabs bajo $Objects
## definen el laberinto, colisiones, rutas A*, reliquias, trampas de rencor y zonas instakill.

const PlatformerPlayerScript = preload("res://moe_editable/scripts/player.gd")
const SNOW_LEVEL_PATH := "res://moe_editable/snow_level.tscn"
const MAIN_MENU_PATH := "res://moe_editable/ui/main_menu.tscn"

const FONT_SERIF_PATH := "res://moe_editable/ui/fonts/Cinzel.ttf"
const FONT_SANS_PATH := "res://moe_editable/ui/fonts/SpaceGrotesk.ttf"

@export_group("Ajustes del Nivel 2 (Editables en Godot)")
@export var level_title: String = "02 / EL ABISMO DE LOS ECOS"
@export var starting_lives: int = 2
@export var total_required_runes: int = 3
@export var darkness_color: Color = Color(0.052, 0.048, 0.095, 1.0)
@export var enable_fog_particles: bool = true

@onready var walkways: TileMapLayer = $Walkways
@onready var abyss_cliffs: TileMapLayer = $AbyssCliffs
@onready var obstacles: TileMapLayer = $ObstaclesAndProps
@onready var objects_root: Node2D = $Objects
@onready var player: TopDownPlayer = $Player
@onready var shadow: TopDownShadowAStar = $EchoShadowAStar
@onready var darkness_modulate: CanvasModulate = $DarknessModulate
@onready var music_player: AudioStreamPlayer = $Audio/Music
@onready var sfx_player: AudioStreamPlayer = $Audio/Effect
@onready var voice_player: AudioStreamPlayer = $Audio/Voice

var font_serif: Font = null
var font_sans: Font = null

var lives: int = 2
var runes_collected: int = 0
var echoes_collected: int = 0
var deaths_count: int = 0
var elapsed_time: float = 0.0
var wisp_hint_timer: float = 0.0

var paused: bool = false
var finished: bool = false
var game_over: bool = false
var in_death_sequence: bool = false
var in_lore_modal: bool = false
var muted: bool = false
var debug_visible: bool = false

var interactables: Array[AbyssInteractable] = []
var rune_nodes: Array[AbyssInteractable] = []

# Referencias UI construidas / vinculadas sobre $HUD
var hud_layer: CanvasLayer = null
var lbl_stats: Label = null
var stamina_bar_fill: ColorRect = null
var lbl_status_tags: Label = null
var lbl_notice: Label = null
var lbl_debug: Label = null
var btn_menu: Button = null
var notice_timer: float = 0.0

# Capas narrativas (Recuerdos, Flash de Rencor, Voces al Morir y Final)
var rancor_flash_panel: Control = null
var rancor_art_canvas: Control = null
var lbl_rancor_title: Label = null
var lbl_rancor_body: Label = null
var rancor_flash_timer: float = 0.0
var rancor_art_id: int = 1

var lore_modal: Control = null
var lore_art_canvas: Control = null
var lbl_lore_kicker: Label = null
var lbl_lore_title: Label = null
var lbl_lore_body: Label = null
var lbl_lore_prompt: Label = null
var current_lore_art_mode: int = 1
var modal_is_ending: bool = false

var death_overlay: Control = null
var lbl_death_village: Label = null
var lbl_death_brother: Label = null
var lbl_death_footer: Label = null
var death_can_skip: bool = false
var death_seq_id: int = 0

var blip_village_stream: AudioStreamWAV = null
var blip_brother_stream: AudioStreamWAV = null
var rancor_chord_stream: AudioStreamWAV = null
var bell_chime_stream: AudioStreamWAV = null


func _ready() -> void:
	get_window().content_scale_size = Vector2i(640, 360)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	font_serif = load(FONT_SERIF_PATH) if ResourceLoader.exists(FONT_SERIF_PATH) else ThemeDB.fallback_font
	font_sans = load(FONT_SANS_PATH) if ResourceLoader.exists(FONT_SANS_PATH) else ThemeDB.fallback_font

	_register_input_actions()
	lives = maxi(1, starting_lives)

	# Aplicar oscuridad atmosférica en ejecución (en el editor de Godot permanece iluminado para editar cómodo)
	if darkness_modulate:
		darkness_modulate.color = darkness_color

	# Sincronizar bordes de abismo y grafo A* a partir de los TileMapLayer editables
	_sync_abyss_collisions_from_walkways()
	player.walkway_layer = walkways
	shadow.setup_navigation(walkways, obstacles, player)

	# Conectar señales del jugador
	player.player_died.connect(_on_player_died)
	player.shield_absorbed_hit.connect(_on_player_shield_absorbed)
	player.instakill_survived_with_buff.connect(_on_instakill_survived_with_buff)
	player.exhausted_started.connect(_on_player_exhausted)

	# Descubrir y conectar todos los objetos colocados en $Objects (incluyendo nuevos añadidos en Godot)
	_connect_all_interactables()

	# Audio procedural + música estilo Pueblo Lavanda (si no se asignó otra pista en el Inspector)
	_setup_audio_streams()
	if enable_fog_particles:
		_setup_ambient_fog()

	_setup_hud_and_overlays()
	_update_hud()

	# Pequeño temblor de aterrizaje tras caer del puente roto del Nivel 1
	player.shake_camera(4.5, 0.35)
	_show_notice("Caíste al Abismo · El dolor impide el Dash — [SHIFT] Correr · [E] Ocultar luz", 4.6)


func _register_input_actions() -> void:
	var bindings := {
		"moee_left": [KEY_A, KEY_LEFT],
		"moee_right": [KEY_D, KEY_RIGHT],
		"moee_up": [KEY_W, KEY_UP],
		"moee_down": [KEY_S, KEY_DOWN],
		"moee_sprint": [KEY_SHIFT],
		"moee_stealth": [KEY_E],
		"moee_accept": [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER],
		"moee_restart": [KEY_R],
		"moee_debug": [KEY_F3],
		"moee_mute": [KEY_M],
		"moee_pause": [KEY_ESCAPE],
	}
	for action in bindings.keys():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in bindings[action]:
			var already := false
			for ev in InputMap.action_get_events(action):
				if ev is InputEventKey and ev.physical_keycode == key:
					already = true
					break
			if not already:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)


func _sync_abyss_collisions_from_walkways() -> void:
	if not is_instance_valid(walkways) or not is_instance_valid(abyss_cliffs):
		return
	var used: Rect2i = walkways.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		return

	# 1. Si el usuario pintó piso nuevo sobre una celda que tenía borde/vacío, liberarla automáticamente
	for y in range(used.position.y - 2, used.end.y + 2):
		for x in range(used.position.x - 2, used.end.x + 2):
			var c := Vector2i(x, y)
			if walkways.get_cell_source_id(c) != -1 and abyss_cliffs.get_cell_source_id(c) != -1:
				abyss_cliffs.erase_cell(c)

	# 2. Garantizar muro de vacío/acantilado alrededor de toda celda caminable para no caer fuera del puente
	for y in range(used.position.y - 1, used.end.y + 1):
		for x in range(used.position.x - 1, used.end.x + 1):
			var c := Vector2i(x, y)
			if walkways.get_cell_source_id(c) != -1:
				continue
			if abyss_cliffs.get_cell_source_id(c) != -1:
				continue
			var touches_walkway := false
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dx == 0 and dy == 0:
						continue
					if walkways.get_cell_source_id(Vector2i(x + dx, y + dy)) != -1:
						touches_walkway = true
						break
				if touches_walkway:
					break
			if touches_walkway:
				var north_has_floor := walkways.get_cell_source_id(Vector2i(x, y - 1)) != -1
				if north_has_floor:
					# Acantilado con carámbanos visible justo bajo los bordes sur
					abyss_cliffs.set_cell(c, 0, Vector2i(posmod(x, 3), 6))
				else:
					# Celda transparente con colisión sólida (7,1) hacia el abismo
					abyss_cliffs.set_cell(c, 0, Vector2i(7, 1))


func _connect_all_interactables() -> void:
	interactables.clear()
	rune_nodes.clear()
	var search_root: Node = objects_root if is_instance_valid(objects_root) else self
	for node in search_root.find_children("*", "Area2D", true, false):
		if node is AbyssInteractable:
			var item := node as AbyssInteractable
			interactables.append(item)
			if item.kind == "memory_rune":
				rune_nodes.append(item)
			if not item.body_entered.is_connected(_on_interactable_entered):
				item.body_entered.connect(_on_interactable_entered.bind(item))
			if item.kind == "hideout" and not item.body_exited.is_connected(_on_hideout_exited):
				item.body_exited.connect(_on_hideout_exited.bind(item))

	if not rune_nodes.is_empty():
		total_required_runes = rune_nodes.size()


func _setup_audio_streams() -> void:
	blip_village_stream = AbyssVoiceSynth.make_village_blip(146.0)
	blip_brother_stream = AbyssVoiceSynth.make_brother_blip(282.0)
	rancor_chord_stream = AbyssVoiceSynth.make_rancor_chord()
	bell_chime_stream = AbyssVoiceSynth.make_bell_chime()

	if music_player:
		if music_player.stream == null:
			music_player.stream = AbyssVoiceSynth.make_lavender_drone_loop()
			music_player.volume_db = -11.0
		if DisplayServer.get_name() != "headless":
			music_player.play()


func _setup_ambient_fog() -> void:
	var fog_layer := CanvasLayer.new()
	fog_layer.name = "RuntimeFogLayer"
	fog_layer.layer = 4
	add_child(fog_layer)

	var fog_particles := CPUParticles2D.new()
	fog_particles.position = Vector2(320, 180)
	fog_particles.amount = 34
	fog_particles.lifetime = 6.5
	fog_particles.preprocess = 3.0
	fog_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fog_particles.emission_rect_extents = Vector2(360, 200)
	fog_particles.direction = Vector2(-1.0, -0.25)
	fog_particles.spread = 28.0
	fog_particles.gravity = Vector2(-3.5, -1.2)
	fog_particles.initial_velocity_min = 6.0
	fog_particles.initial_velocity_max = 16.0
	fog_particles.scale_amount_min = 2.0
	fog_particles.scale_amount_max = 4.5
	fog_particles.color = Color(0.66, 0.62, 0.88, 0.14)
	fog_layer.add_child(fog_particles)


func _make_box_style(bg: Color, border: Color, bw: int = 1, radius: int = 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


func _setup_hud_and_overlays() -> void:
	hud_layer = $HUD if has_node("HUD") else CanvasLayer.new()
	if not hud_layer.is_inside_tree():
		hud_layer.name = "HUD"
		hud_layer.layer = 10
		add_child(hud_layer)

	# Limpiar placeholders previos si se recarga
	for ch in hud_layer.get_children():
		ch.queue_free()

	# 1. Panel superior izquierdo (Vidas, Runas, Ecos y Barra de Estamina)
	var top_panel := Panel.new()
	top_panel.position = Vector2(12, 10)
	top_panel.size = Vector2(276, 52)
	top_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top_panel.add_theme_stylebox_override("panel", _make_box_style(Color(0.04, 0.05, 0.11, 0.88), Color(0.44, 0.36, 0.68, 0.85), 1, 8))
	hud_layer.add_child(top_panel)

	lbl_stats = Label.new()
	lbl_stats.position = Vector2(10, 5)
	lbl_stats.size = Vector2(258, 18)
	lbl_stats.add_theme_font_override("font", font_sans)
	lbl_stats.add_theme_font_size_override("font_size", 11)
	lbl_stats.add_theme_color_override("font_color", Color(0.92, 0.90, 0.98))
	top_panel.add_child(lbl_stats)

	var stam_lbl := Label.new()
	stam_lbl.text = "ESTAMINA"
	stam_lbl.position = Vector2(10, 27)
	stam_lbl.size = Vector2(62, 16)
	stam_lbl.add_theme_font_override("font", font_sans)
	stam_lbl.add_theme_font_size_override("font_size", 9)
	stam_lbl.add_theme_color_override("font_color", Color(0.66, 0.76, 0.88))
	top_panel.add_child(stam_lbl)

	var stam_bg := ColorRect.new()
	stam_bg.position = Vector2(68, 30)
	stam_bg.size = Vector2(118, 8)
	stam_bg.color = Color(0.12, 0.14, 0.22, 0.95)
	top_panel.add_child(stam_bg)

	stamina_bar_fill = ColorRect.new()
	stamina_bar_fill.position = Vector2(68, 30)
	stamina_bar_fill.size = Vector2(118, 8)
	stamina_bar_fill.color = Color(0.42, 0.92, 1.0, 0.95)
	top_panel.add_child(stamina_bar_fill)

	lbl_status_tags = Label.new()
	lbl_status_tags.position = Vector2(192, 26)
	lbl_status_tags.size = Vector2(78, 16)
	lbl_status_tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	lbl_status_tags.add_theme_font_override("font", font_sans)
	lbl_status_tags.add_theme_font_size_override("font_size", 9)
	lbl_status_tags.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	top_panel.add_child(lbl_status_tags)

	# Botón volver al menú (arriba derecha)
	btn_menu = Button.new()
	btn_menu.name = "BtnMainMenu"
	btn_menu.position = Vector2(548, 10)
	btn_menu.size = Vector2(80, 26)
	btn_menu.text = "← MENÚ"
	btn_menu.add_theme_font_override("font", font_sans)
	btn_menu.add_theme_font_size_override("font_size", 10)
	btn_menu.add_theme_stylebox_override("normal", _make_box_style(Color(0.06, 0.08, 0.16, 0.88), Color(0.38, 0.34, 0.62, 0.85), 1, 6))
	btn_menu.add_theme_stylebox_override("hover", _make_box_style(Color(0.14, 0.16, 0.28, 0.95), Color(0.65, 0.85, 1.0, 0.95), 1, 6))
	btn_menu.pressed.connect(_return_to_main_menu)
	hud_layer.add_child(btn_menu)

	# Aviso contextual inferior
	lbl_notice = Label.new()
	lbl_notice.position = Vector2(40, 326)
	lbl_notice.size = Vector2(560, 24)
	lbl_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_notice.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_notice.add_theme_font_override("font", font_sans)
	lbl_notice.add_theme_font_size_override("font_size", 11)
	lbl_notice.add_theme_color_override("font_color", Color(0.92, 0.88, 1.0, 0.96))
	lbl_notice.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	lbl_notice.add_theme_constant_override("shadow_offset_y", 1)
	hud_layer.add_child(lbl_notice)

	# Etiqueta Debug [F3]
	lbl_debug = Label.new()
	lbl_debug.position = Vector2(12, 68)
	lbl_debug.size = Vector2(440, 48)
	lbl_debug.visible = false
	lbl_debug.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_debug.add_theme_font_override("font", font_sans)
	lbl_debug.add_theme_font_size_override("font_size", 10)
	lbl_debug.add_theme_color_override("font_color", Color(0.55, 0.98, 0.78))
	hud_layer.add_child(lbl_debug)

	# 2. Flash psicológico de Ítem Trampa ("Eco de Rencor") — no pausa el juego, ¡tienes que correr!
	rancor_flash_panel = Control.new()
	rancor_flash_panel.name = "RancorFlashOverlay"
	rancor_flash_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	rancor_flash_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rancor_flash_panel.visible = false
	hud_layer.add_child(rancor_flash_panel)

	var r_tint := ColorRect.new()
	r_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	r_tint.color = Color(0.24, 0.03, 0.11, 0.42)
	r_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rancor_flash_panel.add_child(r_tint)

	var r_card := Panel.new()
	r_card.position = Vector2(105, 38)
	r_card.size = Vector2(430, 118)
	r_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r_card.add_theme_stylebox_override("panel", _make_box_style(Color(0.06, 0.03, 0.10, 0.94), Color(0.92, 0.26, 0.44, 0.95), 2, 10))
	rancor_flash_panel.add_child(r_card)

	rancor_art_canvas = Control.new()
	rancor_art_canvas.position = Vector2(12, 12)
	rancor_art_canvas.size = Vector2(96, 94)
	rancor_art_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rancor_art_canvas.draw.connect(_draw_rancor_vignette)
	r_card.add_child(rancor_art_canvas)

	lbl_rancor_title = Label.new()
	lbl_rancor_title.position = Vector2(120, 12)
	lbl_rancor_title.size = Vector2(296, 20)
	lbl_rancor_title.add_theme_font_override("font", font_serif)
	lbl_rancor_title.add_theme_font_size_override("font_size", 12)
	lbl_rancor_title.add_theme_color_override("font_color", Color(1.0, 0.42, 0.56))
	r_card.add_child(lbl_rancor_title)

	lbl_rancor_body = Label.new()
	lbl_rancor_body.position = Vector2(120, 34)
	lbl_rancor_body.size = Vector2(296, 74)
	lbl_rancor_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_rancor_body.add_theme_font_override("font", font_sans)
	lbl_rancor_body.add_theme_font_size_override("font_size", 10)
	lbl_rancor_body.add_theme_color_override("font_color", Color(0.92, 0.86, 0.94))
	r_card.add_child(lbl_rancor_body)

	# 3. Modal de Flashback (Runas de Memoria + Escena Final en la Escalinata)
	lore_modal = Control.new()
	lore_modal.name = "LoreFlashbackModal"
	lore_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	lore_modal.visible = false
	hud_layer.add_child(lore_modal)

	var l_dim := ColorRect.new()
	l_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	l_dim.color = Color(0.02, 0.02, 0.06, 0.84)
	lore_modal.add_child(l_dim)

	var l_card := Panel.new()
	l_card.position = Vector2(68, 34)
	l_card.size = Vector2(504, 292)
	l_card.add_theme_stylebox_override("panel", _make_box_style(Color(0.05, 0.06, 0.13, 0.97), Color(0.68, 0.52, 0.98, 0.92), 2, 12))
	lore_modal.add_child(l_card)

	lbl_lore_kicker = Label.new()
	lbl_lore_kicker.position = Vector2(20, 12)
	lbl_lore_kicker.size = Vector2(464, 16)
	lbl_lore_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lore_kicker.add_theme_font_override("font", font_sans)
	lbl_lore_kicker.add_theme_font_size_override("font_size", 9)
	lbl_lore_kicker.add_theme_color_override("font_color", Color(0.55, 0.90, 1.0))
	l_card.add_child(lbl_lore_kicker)

	lbl_lore_title = Label.new()
	lbl_lore_title.position = Vector2(20, 28)
	lbl_lore_title.size = Vector2(464, 24)
	lbl_lore_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lore_title.add_theme_font_override("font", font_serif)
	lbl_lore_title.add_theme_font_size_override("font_size", 15)
	lbl_lore_title.add_theme_color_override("font_color", Color(0.98, 0.94, 1.0))
	l_card.add_child(lbl_lore_title)

	lore_art_canvas = Control.new()
	lore_art_canvas.position = Vector2(132, 56)
	lore_art_canvas.size = Vector2(240, 82)
	lore_art_canvas.draw.connect(_draw_lore_illustration)
	l_card.add_child(lore_art_canvas)

	lbl_lore_body = Label.new()
	lbl_lore_body.position = Vector2(24, 146)
	lbl_lore_body.size = Vector2(456, 108)
	lbl_lore_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_lore_body.add_theme_font_override("font", font_sans)
	lbl_lore_body.add_theme_font_size_override("font_size", 10)
	lbl_lore_body.add_theme_color_override("font_color", Color(0.86, 0.88, 0.96))
	l_card.add_child(lbl_lore_body)

	lbl_lore_prompt = Label.new()
	lbl_lore_prompt.position = Vector2(20, 262)
	lbl_lore_prompt.size = Vector2(464, 20)
	lbl_lore_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_lore_prompt.add_theme_font_override("font", font_sans)
	lbl_lore_prompt.add_theme_font_size_override("font_size", 10)
	lbl_lore_prompt.add_theme_color_override("font_color", Color(1.0, 0.84, 0.42))
	l_card.add_child(lbl_lore_prompt)

	# 4. Pantalla Negra de Muerte con Mini-Voces Estilizadas (Opción B: Rumores vs Hermano)
	death_overlay = Control.new()
	death_overlay.name = "DeathVoicesOverlay"
	death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	death_overlay.visible = false
	hud_layer.add_child(death_overlay)

	var d_black := ColorRect.new()
	d_black.set_anchors_preset(Control.PRESET_FULL_RECT)
	d_black.color = Color(0.015, 0.012, 0.028, 0.98)
	death_overlay.add_child(d_black)

	lbl_death_village = Label.new()
	lbl_death_village.position = Vector2(64, 92)
	lbl_death_village.size = Vector2(512, 68)
	lbl_death_village.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_death_village.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_death_village.add_theme_font_override("font", font_sans)
	lbl_death_village.add_theme_font_size_override("font_size", 12)
	lbl_death_village.add_theme_color_override("font_color", Color(0.84, 0.48, 0.56))
	death_overlay.add_child(lbl_death_village)

	lbl_death_brother = Label.new()
	lbl_death_brother.position = Vector2(64, 178)
	lbl_death_brother.size = Vector2(512, 82)
	lbl_death_brother.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_death_brother.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl_death_brother.add_theme_font_override("font", font_serif)
	lbl_death_brother.add_theme_font_size_override("font_size", 13)
	lbl_death_brother.add_theme_color_override("font_color", Color(0.68, 0.92, 1.0))
	death_overlay.add_child(lbl_death_brother)

	lbl_death_footer = Label.new()
	lbl_death_footer.position = Vector2(64, 298)
	lbl_death_footer.size = Vector2(512, 28)
	lbl_death_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_death_footer.add_theme_font_override("font", font_sans)
	lbl_death_footer.add_theme_font_size_override("font_size", 11)
	lbl_death_footer.add_theme_color_override("font_color", Color(0.95, 0.84, 0.48))
	death_overlay.add_child(lbl_death_footer)


func _process(delta: float) -> void:
	if not paused and not finished and not game_over and not in_death_sequence and not in_lore_modal:
		elapsed_time += delta
		_update_last_rune_whisper_hint(delta)

	if notice_timer > 0.0:
		notice_timer = maxf(0.0, notice_timer - delta)
		if notice_timer <= 0.0 and lbl_notice and not paused:
			lbl_notice.text = ""

	if rancor_flash_timer > 0.0:
		rancor_flash_timer = maxf(0.0, rancor_flash_timer - delta)
		if rancor_flash_timer <= 0.0 and rancor_flash_panel:
			rancor_flash_panel.visible = false

	_update_hud()


func _update_last_rune_whisper_hint(delta: float) -> void:
	# Brújula sutil en mapa grande: cuando solo falta 1 Runa, una chispa tenue deriva hacia ella
	if runes_collected != total_required_runes - 1 or rune_nodes.is_empty():
		return
	wisp_hint_timer += delta
	if wisp_hint_timer < 2.2:
		return
	wisp_hint_timer = 0.0
	var missing_rune: AbyssInteractable = null
	for rn in rune_nodes:
		if is_instance_valid(rn) and not rn.activated:
			missing_rune = rn
			break
	if not missing_rune:
		return

	var dir := (missing_rune.global_position - player.global_position).normalized()
	var wisp := Polygon2D.new()
	wisp.polygon = PackedVector2Array([Vector2(-2, 0), Vector2(0, -2), Vector2(3, 0), Vector2(0, 2)])
	wisp.color = Color(0.78, 0.62, 1.0, 0.80)
	wisp.global_position = player.global_position + Vector2(0, -8)
	wisp.z_index = 12
	add_child(wisp)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(wisp, "global_position", player.global_position + dir * 48.0, 1.35)
	tw.tween_property(wisp, "modulate:a", 0.0, 1.35)
	tw.chain().tween_callback(wisp.queue_free)


func _on_interactable_entered(body: Node2D, item: AbyssInteractable) -> void:
	if body != player or finished or game_over or in_death_sequence:
		return

	match item.kind:
		"memory_rune":
			if item.activated:
				return
			item.activate_permanent()
			runes_collected += 1
			PlatformerPlayerScript.saved_runes = maxi(PlatformerPlayerScript.saved_runes, runes_collected)
			player.refill_warmth(1.0)
			_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
			_open_rune_flashback(item)

		"soul_lantern":
			player.refill_warmth(1.0)
			if not item.activated:
				item.activate_permanent()
				player.spawn_position = item.global_position
				shadow.repel_from_lantern(item.global_position, 4, 5.5)
				_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
				_show_notice("🔥 Farol de Alma encendido · Refugio guardado y la Sombra esquiva esta luz", 3.6)
			else:
				player.spawn_position = item.global_position

		"permanent_shield":
			if item.activated:
				return
			item.activate_permanent()
			player.grant_permanent_shield()
			player.refill_warmth(1.0)
			_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
			_show_notice("🛡 AMULETO DE TU HERMANO OBTENIDO · Escudo Permanente activo (persiste al Nivel 3+)", 4.8)

		"light_boost":
			if item.activated:
				return
			item.activate_permanent()
			player.apply_light_relic()
			_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
			_show_notice("✦ Cristal del Faro Antiguo · Tu radio de visión aumenta permanentemente", 3.8)

		"stamina_tonic":
			if item.activated:
				return
			item.activate_permanent()
			player.apply_stamina_tonic()
			_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
			_show_notice("✦ Aliento Escarchado · +Estamina máxima y tracción firme sobre el hielo", 3.8)

		"mini_buff_ember":
			if not item.is_ready_to_use():
				return
			item.trigger_cooldown(10.0)
			player.grant_mini_buff(8.5)
			_play_sfx(preload("res://moe_editable/audio/coin.wav"))
			_show_notice("🔥 Ascua Protectora (8.5s) · Velocidad cálida + ¡Te salva de 1 Zona Prohibida!", 3.8)

		"rancor_trap":
			if item.activated:
				return
			item.activate_permanent()
			_trigger_rancor_trap(item)

		"instakill_zone":
			if not item.is_ready_to_use():
				return
			var survived := player.try_enter_instakill_zone(item.title_text if item.title_text != "" else "Nido del Abismo")
			if survived and player.adrenaline_timer > 0.0:
				item.trigger_cooldown(6.0)

		"hideout":
			player.near_hideout_count += 1
			if not player.is_stealth_hidden:
				_show_notice("Estatua Llorona · Presiona [E] para cubrir tu luz y despistar el rastro A*", 2.6)

		"echo_bell":
			if not item.is_ready_to_use():
				return
			item.trigger_cooldown(9.0)
			shadow.lure_to_position(item.global_position, 5.4)
			_play_sfx(bell_chime_stream)
			_show_notice("🔔 Campana de Eco resonando · La Sombra desvía su ruta A* hacia el sonido", 3.4)

		"echo_orb":
			if item.activated:
				return
			item.activate_permanent()
			echoes_collected += 1
			PlatformerPlayerScript.saved_echoes += 1
			player.refill_warmth(0.35)
			_play_sfx(preload("res://moe_editable/audio/coin.wav"))

		"ascent_exit":
			if runes_collected >= total_required_runes:
				_open_ending_sequence()
			else:
				var faltan := maxi(1, total_required_runes - runes_collected)
				_show_notice("Escalinata Sellada · Faltan %d Runa(s) de Memoria para abrir el ascenso." % faltan, 3.5)


func _on_hideout_exited(body: Node2D, _item: AbyssInteractable) -> void:
	if body == player:
		player.near_hideout_count = maxi(0, player.near_hideout_count - 1)


func _trigger_rancor_trap(item: AbyssInteractable) -> void:
	player.trigger_rancor_panic(5.5)
	shadow.enrage_to_position(item.global_position, 6.0)
	_play_sfx(rancor_chord_stream)

	rancor_art_id = clampi(item.rune_id, 1, 3)
	var t_title := item.title_text if item.title_text != "" else "ECO DE RENCOR — RECUERDO AMARGO"
	var t_body := item.lore_text if item.lore_text != "" else (
		"«¡Seguro fue su hermano! ¡Nadie más estaba cerca!» — Sin una sola prueba, medio pueblo que ni nos conocía empezó a tratarnos como basura."
	)
	lbl_rancor_title.text = "⚠  " + t_title
	lbl_rancor_body.text = t_body + "\n[Tu luz tiembla por la frustración · ¡La Sombra escuchó el eco!]"
	rancor_flash_panel.visible = true
	rancor_art_canvas.queue_redraw()
	rancor_flash_timer = 3.2


func _open_rune_flashback(item: AbyssInteractable) -> void:
	in_lore_modal = true
	modal_is_ending = false
	player.locked = true
	shadow.set_physics_process(false)

	current_lore_art_mode = clampi(item.rune_id, 1, 3)
	lbl_lore_kicker.text = "RUNA DE MEMORIA %d / %d  ·  VÍNCULOS EN EL PUEBLO" % [runes_collected, total_required_runes]

	var default_titles := {
		1: "I. Los Padres y el Amigo que Perdimos",
		2: "II. Los Niños que No Nos Miraban con Odio",
		3: "III. Un Sistema Podrido que Alguien Debe Cambiar",
	}
	var default_bodies := {
		1: "Cuando el mejor amigo de mi hermano falleció, mi hermano fue quien más sufrió su partida. Jamás hubo pruebas en su contra, pero al consejo le convenía señalar a alguien... Aun así, en ese valle siguen nuestros padres y cada rincón donde nuestro amigo fue feliz.",
		2: "La parte del pueblo que ni siquiera nos conocía nos cerró las puertas y murmuró pestes a nuestro paso. Da rabia recordarlo... pero entre tanta hostilidad, los niños pequeños aún se acercaban a saludarnos sin prejuicios, ajenos al veneno de los mayores.",
		3: "No todos en ese pueblo merecen pagar los platos rotos de una política corrupta. Pero si esos niños crecen bajo los mismos líderes déspotas de hoy, terminarán corrompiéndose igual. Si queremos un futuro distinto para ellos, alguien tendrá que romper ese ciclo.",
	}
	lbl_lore_title.text = item.title_text if item.title_text != "" else String(default_titles.get(current_lore_art_mode, "Vínculo Recordado"))
	lbl_lore_body.text = item.lore_text if item.lore_text != "" else String(default_bodies.get(current_lore_art_mode, ""))
	lbl_lore_prompt.text = "[ESPACIO / ENTER] Guardar recuerdo en el pecho y continuar"
	lore_modal.visible = true
	lore_art_canvas.queue_redraw()


func _open_ending_sequence() -> void:
	if finished:
		return
	finished = true
	in_lore_modal = true
	modal_is_ending = true
	player.locked = true
	shadow.set_physics_process(false)
	_play_sfx(preload("res://moe_editable/audio/power_up.wav"))

	current_lore_art_mode = 4
	lbl_lore_kicker.text = "UMBRAL DEL ABISMO SUPERADO  ·  EL INICIO REAL DE LA TRAVESÍA"
	lbl_lore_title.text = "La Promesa a Mi Hermano y la Semilla del Cambio"
	lbl_lore_body.text = (
		"«Sé cuánto te frustra, hermano —me dijo antes de partir—. Sé el rencor que da ver cómo nos tratan quienes ni nos conocen. Pero no busques venganza ni los dejes atrás por eso: hazlo por nuestros padres y por la memoria de mi mejor amigo.»\n\n"
		+ "Todavía guardo rencor, y sé que hoy subo sobre todo por cumplir el deseo de mi hermano... Pero al ver la esperanza en esos niños atrapados bajo un sistema corrupto, comprendí que quizá el cambio deba empezar conmigo —tal vez guiando algún día a ese pueblo para que nadie vuelva a sufrir esa injusticia."
	)
	lbl_lore_prompt.text = "[ENTER / ESPACIO] Ascender al Nivel 03   ·   [R] Rejugar Nivel 02   ·   [Q] Menú"
	lore_modal.visible = true
	lore_art_canvas.queue_redraw()


func _close_lore_modal() -> void:
	if not in_lore_modal:
		return
	if modal_is_ending:
		# Continuar directamente hacia el Nivel 03 (Santuario de la Cumbre) conservando el Escudo Permanente
		PlatformerPlayerScript.start_checkpoint_index = 2
		get_tree().change_scene_to_file(SNOW_LEVEL_PATH)
		return

	in_lore_modal = false
	lore_modal.visible = false
	player.locked = false
	player.invulnerable_timer = maxf(player.invulnerable_timer, 1.4)
	shadow.set_physics_process(true)
	if runes_collected >= total_required_runes:
		_show_notice("★ Las 3 Runas de Memoria brillan · ¡Dirígete a la Escalinata del Noroeste (FIN)!", 4.8)


func _on_player_shield_absorbed() -> void:
	_play_sfx(preload("res://assets/audio/sounds/explosion.wav"))
	_show_notice("🛡 ¡El Amuleto de tu hermano absorbió el zarpazo sin perder vida! (Se recarga en un Farol)", 4.0)


func _on_instakill_survived_with_buff() -> void:
	_play_sfx(preload("res://moe_editable/audio/power_up.wav"))
	_show_notice("🔥 ¡SALVADA AL LÍMITE! Tu Ascua Protectora te libró del Instakill con un impulso de adrenalina", 4.2)


func _on_player_exhausted() -> void:
	_show_notice("¡Sin aliento! Tu caída del puente aún duele... recupera estamina antes de correr.", 2.4)


func _on_player_died(cause: String) -> void:
	if in_death_sequence or finished or game_over:
		return
	deaths_count += 1
	lives = maxi(0, lives - 1)
	in_death_sequence = true
	death_can_skip = false
	death_seq_id += 1
	var my_seq := death_seq_id

	shadow.set_physics_process(false)
	_play_sfx(preload("res://moe_editable/audio/hurt.wav"))

	death_overlay.visible = true
	lbl_death_village.text = ""
	lbl_death_brother.text = ""
	lbl_death_footer.text = ""

	var village_lines := [
		"«Mírenlo... el hermano del acusado. Esa familia solo trajo ruina a nuestro pueblo...»",
		"«Aunque no lo probaran en el juicio, algo habrán hecho. Mejor tenerlos lejos de aquí...»",
	]
	var brother_lines := [
		"«No dejes que sus mentiras apaguen quién eres, hermano... Hazlo por mamá y papá. Aún te queda aliento: levántate.»",
		"«Sé que da rabia salvar a quienes nos juzgan sin conocernos... pero esos niños merecen un mañana distinto. No te rindas aquí.»",
	]
	var v_text: String = village_lines[(deaths_count - 1) % village_lines.size()]
	var b_text: String = brother_lines[(deaths_count - 1) % brother_lines.size()]
	if cause != "shadow":
		v_text = "«Se metió en la grieta prohibida sin calor... jamás saldrá de esa montaña...»"

	if DisplayServer.get_name() == "headless":
		lbl_death_village.text = v_text
		lbl_death_brother.text = b_text
		if lives > 0:
			_finish_respawn_from_death()
		else:
			game_over = true
			lbl_death_footer.text = "HAS CAÍDO EN EL ABISMO (0 VIDAS)  ·  [R] Reintentar Nivel 02  ·  [Q] Menú Principal"
		return

	_run_death_voice_typewriter(my_seq, v_text, b_text)


func _run_death_voice_typewriter(seq_id: int, v_text: String, b_text: String) -> void:
	await get_tree().create_timer(0.32).timeout
	if seq_id != death_seq_id or not is_inside_tree():
		return
	death_can_skip = true

	# 1. Murmullo frío del pueblo (timbre rasposo/disonante)
	for i in range(v_text.length()):
		if seq_id != death_seq_id or not in_death_sequence:
			return
		lbl_death_village.text = v_text.substr(0, i + 1)
		if i % 3 == 0 and v_text[i] != " ":
			_play_voice_blip(blip_village_stream, randf_range(0.92, 1.06))
		await get_tree().create_timer(0.032).timeout

	await get_tree().create_timer(0.45).timeout
	if seq_id != death_seq_id or not in_death_sequence:
		return

	# 2. Voz cálida del hermano motivándolo en la oscuridad
	for i in range(b_text.length()):
		if seq_id != death_seq_id or not in_death_sequence:
			return
		lbl_death_brother.text = b_text.substr(0, i + 1)
		if i % 3 == 0 and b_text[i] != " ":
			_play_voice_blip(blip_brother_stream, randf_range(0.96, 1.08))
		await get_tree().create_timer(0.030).timeout

	if lives > 0:
		lbl_death_footer.text = "♥ Te queda %d vida  ·  [ESPACIO / ENTER] Levantarse en el último Farol" % lives
		await get_tree().create_timer(1.55).timeout
		if seq_id == death_seq_id and in_death_sequence and lives > 0:
			_finish_respawn_from_death()
	else:
		game_over = true
		lbl_death_footer.text = "SIN VIDAS RESTANTES  ·  [R] Reintentar Nivel 02   ·   [Q] Menú Principal"


func _finish_respawn_from_death() -> void:
	death_seq_id += 1
	in_death_sequence = false
	death_overlay.visible = false
	player.respawn_at_checkpoint()
	shadow.reset_after_respawn(320.0)
	shadow.set_physics_process(true)
	_show_notice("♥ Despiertas junto al último Farol · Tus Runas y Reliquias siguen contigo (Vidas: %d)" % lives, 3.8)


func _play_voice_blip(stream: AudioStream, pitch: float = 1.0) -> void:
	if DisplayServer.get_name() == "headless" or muted or not voice_player or not stream:
		return
	voice_player.stream = stream
	voice_player.pitch_scale = pitch
	voice_player.volume_db = -9.0
	voice_player.play()


func _play_sfx(stream: AudioStream) -> void:
	if DisplayServer.get_name() == "headless" or muted or not sfx_player or not stream:
		return
	sfx_player.stream = stream
	sfx_player.play()


func _show_notice(msg: String, duration: float = 3.2) -> void:
	if lbl_notice:
		lbl_notice.text = msg
	notice_timer = duration


func _update_hud() -> void:
	if not lbl_stats:
		return
	var hearts := ""
	for i in range(maxi(starting_lives, lives)):
		hearts += "♥" if i < lives else "♡"
	lbl_stats.text = "%s Vidas   ·   ◆ Runas %d/%d   ·   ✦ Ecos x%d" % [
		hearts, runes_collected, total_required_runes, echoes_collected
	]

	if stamina_bar_fill and is_instance_valid(player):
		var ratio := clampf(player.stamina / maxf(1.0, player.max_stamina), 0.0, 1.0)
		stamina_bar_fill.size.x = 118.0 * ratio
		if player.exhausted_timer > 0.0:
			stamina_bar_fill.color = Color(0.95, 0.34, 0.44, 0.95)
		elif player.mini_buff_timer > 0.0:
			stamina_bar_fill.color = Color(1.0, 0.82, 0.35, 0.95)
		else:
			stamina_bar_fill.color = Color(0.42, 0.92, 1.0, 0.95)

	if lbl_status_tags and is_instance_valid(player):
		var tags: Array[String] = []
		if player.shield_active:
			tags.append("🛡")
		if player.mini_buff_timer > 0.0:
			tags.append("🔥%.0fs" % ceilf(player.mini_buff_timer))
		if player.is_stealth_hidden:
			tags.append("👁 SIGILO")
		lbl_status_tags.text = " ".join(tags)

	if debug_visible and lbl_debug and is_instance_valid(shadow):
		lbl_debug.text = shadow.get_debug_summary() + "\n" + (
			"Calor farol: %d%% · Hielo: %s · Escondite cerca: %s" % [
				int(player.light_heat * 100.0),
				"SÍ" if player.on_ice_surface else "NO",
				"SÍ" if player.near_hideout_count > 0 else "NO",
			]
		)


func _unhandled_key_input(event: InputEvent) -> void:
	if in_lore_modal:
		if event.is_action_pressed("moee_accept"):
			get_viewport().set_input_as_handled()
			_close_lore_modal()
			return
		if modal_is_ending:
			if event.is_action_pressed("moee_restart"):
				get_viewport().set_input_as_handled()
				get_tree().reload_current_scene()
				return
			if event is InputEventKey and event.pressed and not event.echo:
				var k_end: int = event.keycode if event.keycode != 0 else event.physical_keycode
				if k_end == KEY_Q:
					get_viewport().set_input_as_handled()
					_return_to_main_menu()
					return
		return

	if in_death_sequence:
		if game_over:
			if event.is_action_pressed("moee_restart"):
				get_viewport().set_input_as_handled()
				get_tree().reload_current_scene()
				return
			if event is InputEventKey and event.pressed and not event.echo:
				var k_go: int = event.keycode if event.keycode != 0 else event.physical_keycode
				if k_go == KEY_Q:
					get_viewport().set_input_as_handled()
					_return_to_main_menu()
					return
		elif death_can_skip and lives > 0 and event.is_action_pressed("moee_accept"):
			get_viewport().set_input_as_handled()
			_finish_respawn_from_death()
		return

	if event.is_action_pressed("moee_debug"):
		debug_visible = not debug_visible
		if lbl_debug:
			lbl_debug.visible = debug_visible
		shadow.set_debug_draw(debug_visible)

	if event.is_action_pressed("moee_mute"):
		muted = not muted
		if music_player:
			music_player.volume_db = -80.0 if muted else -11.0

	if event.is_action_pressed("moee_restart") and not paused:
		get_tree().reload_current_scene()
		return

	if event.is_action_pressed("moee_pause") and not finished:
		paused = not paused
		player.locked = paused
		shadow.set_physics_process(not paused)
		_show_notice("PAUSA · [ESC] Continuar · [Q] Menú Principal" if paused else "", 999.0 if paused else 0.1)

	if paused and event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if k == KEY_Q:
			get_viewport().set_input_as_handled()
			_return_to_main_menu()


func _return_to_main_menu() -> void:
	paused = false
	get_tree().paused = false
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


# =============================================================================
# VIÑETAS VISUALES PROCEDURALES DE LOS RECUERDOS Y TRAMPAS DE RENCOR
# =============================================================================

func _draw_rancor_vignette() -> void:
	if not rancor_art_canvas:
		return
	var s := rancor_art_canvas.size
	rancor_art_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.08, 0.03, 0.11, 1.0), true)
	rancor_art_canvas.draw_rect(Rect2(Vector2.ZERO, s), Color(0.85, 0.24, 0.42, 0.65), false, 1.0)

	# Siluetas acusadoras / discusión tensa antes de partir
	if rancor_art_id == 2:
		# Los dos hermanos discutiendo junto al portón nevado
		rancor_art_canvas.draw_circle(Vector2(30, 42), 9.0, Color(0.55, 0.78, 0.96, 0.9))
		rancor_art_canvas.draw_rect(Rect2(23, 51, 14, 28), Color(0.32, 0.50, 0.72, 0.9), true)
		rancor_art_canvas.draw_circle(Vector2(66, 48), 8.0, Color(0.92, 0.48, 0.34, 0.95))
		rancor_art_canvas.draw_rect(Rect2(60, 56, 12, 23), Color(0.76, 0.32, 0.28, 0.95), true)
		rancor_art_canvas.draw_line(Vector2(44, 34), Vector2(54, 42), Color(1.0, 0.35, 0.50, 0.9), 2.0)
	else:
		# Sombras de desconocidos señalando desde puertas cerradas
		for idx in range(3):
			var sx := 18.0 + idx * 24.0
			rancor_art_canvas.draw_circle(Vector2(sx, 38), 7.5, Color(0.24, 0.14, 0.30, 1.0))
			rancor_art_canvas.draw_rect(Rect2(sx - 6, 46, 12, 34), Color(0.18, 0.10, 0.24, 1.0), true)
			rancor_art_canvas.draw_circle(Vector2(sx + 2, 37), 1.4, Color(0.98, 0.26, 0.44, 0.95))
		rancor_art_canvas.draw_line(Vector2(24, 48), Vector2(78, 60), Color(0.95, 0.28, 0.44, 0.75), 2.0)


func _draw_lore_illustration() -> void:
	if not lore_art_canvas:
		return
	var w := lore_art_canvas.size.x
	var h := lore_art_canvas.size.y
	lore_art_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.07, 0.08, 0.16, 1.0), true)
	lore_art_canvas.draw_rect(Rect2(0, 0, w, h), Color(0.52, 0.44, 0.82, 0.7), false, 1.0)

	match current_lore_art_mode:
		1:
			# Hogar cálido: ventana dorada, padres, hermano y el mejor amigo sonriendo
			lore_art_canvas.draw_circle(Vector2(w * 0.5, h * 0.48), 34.0, Color(1.0, 0.76, 0.36, 0.22))
			lore_art_canvas.draw_rect(Rect2(w * 0.5 - 18, 12, 36, 26), Color(1.0, 0.82, 0.45, 0.65), true)
			var xs := [74.0, 102.0, 134.0, 162.0]
			var cols := [Color(0.55, 0.68, 0.88), Color(0.62, 0.76, 0.94), Color(0.92, 0.58, 0.36), Color(0.75, 0.88, 0.68)]
			for i in range(xs.size()):
				var hh := 22.0 if i == 2 else 28.0
				lore_art_canvas.draw_circle(Vector2(xs[i], h - hh - 10), 6.5, cols[i])
				lore_art_canvas.draw_rect(Rect2(xs[i] - 5, h - hh - 3, 10, hh), cols[i], true)
		2:
			# Niños del pueblo tendiendo la mano con esperanza frente a muros grises
			lore_art_canvas.draw_rect(Rect2(18, 14, 38, 56), Color(0.16, 0.18, 0.28), true)
			lore_art_canvas.draw_rect(Rect2(184, 14, 38, 56), Color(0.16, 0.18, 0.28), true)
			lore_art_canvas.draw_circle(Vector2(96, 46), 7.0, Color(0.92, 0.56, 0.34))
			lore_art_canvas.draw_rect(Rect2(90, 53, 12, 22), Color(0.84, 0.48, 0.30), true)
			# Dos niños pequeños acercando una luz cálida
			lore_art_canvas.draw_circle(Vector2(138, 52), 5.5, Color(0.68, 0.92, 1.0))
			lore_art_canvas.draw_rect(Rect2(133, 58, 10, 17), Color(0.52, 0.80, 0.95), true)
			lore_art_canvas.draw_circle(Vector2(156, 54), 5.0, Color(0.78, 0.94, 0.78))
			lore_art_canvas.draw_rect(Rect2(152, 59, 8, 16), Color(0.60, 0.84, 0.68), true)
			lore_art_canvas.draw_circle(Vector2(120, 52), 4.0, Color(1.0, 0.86, 0.42, 0.95))
		3:
			# Estandartes torcidos del sistema corrupto proyectando sombra sobre las futuras generaciones
			for bx in [52.0, 120.0, 188.0]:
				lore_art_canvas.draw_rect(Rect2(bx - 12, 8, 24, 36), Color(0.36, 0.16, 0.28, 0.95), true)
				lore_art_canvas.draw_line(Vector2(bx, 8), Vector2(bx, 74), Color(0.55, 0.32, 0.48), 2.0)
			lore_art_canvas.draw_circle(Vector2(120, 56), 16.0, Color(0.48, 0.88, 1.0, 0.22))
			lore_art_canvas.draw_circle(Vector2(120, 54), 6.5, Color(0.94, 0.62, 0.38))
			lore_art_canvas.draw_rect(Rect2(114, 61, 12, 16), Color(0.94, 0.62, 0.38), true)
		4:
			# Despedida del hermano y escalinata luminosa hacia la cumbre
			for step in range(5):
				var sw := 96.0 - step * 14.0
				lore_art_canvas.draw_rect(Rect2(w * 0.5 - sw * 0.5, h - 10 - step * 11, sw, 9), Color(0.46 + step * 0.08, 0.62 + step * 0.07, 0.88, 0.85), true)
			lore_art_canvas.draw_circle(Vector2(w * 0.5, 16), 14.0, Color(0.75, 0.95, 1.0, 0.55))
			# Hermano apoyando la mano en el hombro del protagonista
			lore_art_canvas.draw_circle(Vector2(88, 44), 7.5, Color(0.62, 0.86, 1.0))
			lore_art_canvas.draw_rect(Rect2(82, 52, 12, 24), Color(0.48, 0.72, 0.94), true)
			lore_art_canvas.draw_circle(Vector2(110, 49), 6.8, Color(0.94, 0.58, 0.36))
			lore_art_canvas.draw_rect(Rect2(104, 56, 12, 20), Color(0.86, 0.48, 0.30), true)
