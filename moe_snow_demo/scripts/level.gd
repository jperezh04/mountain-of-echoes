@tool
extends Node2D
## Change the platform rectangles below to extend this first level.
## x, y, width, height; 32 world units per 16-pixel terrain tile.
const Player = preload("res://moe_snow_demo/scripts/player.gd")
const Guardian = preload("res://moe_snow_demo/scripts/guardian.gd")
const Backdrop = preload("res://moe_snow_demo/scripts/backdrop.gd")
const TERRAIN = preload("res://moe_snow_demo/art/terrain.png")
const PLATFORMS = [
	Rect2(0, 384, 640, 320), Rect2(736, 352, 512, 352),
	Rect2(1344, 320, 576, 384), Rect2(2016, 352, 448, 352),
	Rect2(2560, 304, 448, 400), Rect2(3104, 272, 384, 432),
	Rect2(3584, 240, 736, 464),
	Rect2(320, 288, 128, 32), Rect2(896, 256, 128, 32),
	Rect2(1536, 224, 128, 32), Rect2(2192, 256, 128, 32),
	Rect2(2720, 208, 128, 32), Rect2(3744, 144, 128, 32)
]
const CHECKPOINTS = [Vector2(100, 384), Vector2(1410, 320), Vector2(2620, 304)]
const RUNES = [Vector2(1140, 320), Vector2(2370, 320), Vector2(3400, 240)]
const GUARDIAN_POSITIONS = [Vector2(950, 295), Vector2(1740, 260), Vector2(2260, 290), Vector2(2870, 250), Vector2(3280, 205), Vector2(3920, 175)]
@export_group("Vista previa del nivel")
@export var mostrar_vista_previa := true:
	set(value):
		mostrar_vista_previa = value
		queue_redraw()
@export var mostrar_radios := false:
	set(value):
		mostrar_radios = value
		queue_redraw()
var player: CharacterBody2D
var guardians: Array[CharacterBody2D] = []
var background: Node2D
var checkpoints := 0
var runes: Array[bool] = [false, false, false]
var echoes: Array[Vector2] = []
var echoes_taken: Array[bool] = []
var echoes_count := 0
var deaths := 0
var elapsed := 0.0
var finished := false
var debug_visible := false
var music_muted := false
var note := "Encuentra las 3 runas y alcanza el santuario."
var note_time := 7.0
var title_label: Label
var stats_label: Label
var hint_label: Label
var notice_label: Label
var debug_label: Label
var win_panel: Panel
var win_label: Label
var music: AudioStreamPlayer
var sound: AudioStreamPlayer
var jump_sound: AudioStreamPlayer

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_build_echoes()
	if Engine.is_editor_hint():
		# Preview only: never run input, audio, AI or window changes in the editor.
		set_physics_process(false)
		set_process_unhandled_key_input(false)
		queue_redraw()
		return
	music = AudioStreamPlayer.new()
	sound = AudioStreamPlayer.new()
	jump_sound = AudioStreamPlayer.new()
	get_window().content_scale_size = Vector2i(800, 450)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_register_input()
	var sky := CanvasLayer.new()
	sky.layer = -10
	add_child(sky)
	background = Backdrop.new()
	sky.add_child(background)
	for platform in PLATFORMS:
		var body := StaticBody2D.new()
		body.position = platform.position + platform.size / 2
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = platform.size
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	player = Player.new()
	player.position = CHECKPOINTS[0]
	player.spawn = CHECKPOINTS[0]
	player.z_index = 5
	add_child(player)
	player.hurt.connect(_on_hurt)
	player.jumped.connect(_on_jump)
	for point in GUARDIAN_POSITIONS:
		var guardian := Guardian.new()
		guardian.position = point
		guardian.target = player
		guardian.z_index = 4
		add_child(guardian)
		guardians.append(guardian)
	add_child(sound)
	add_child(jump_sound)
	jump_sound.stream = preload("res://moe_snow_demo/audio/jump.wav")
	jump_sound.volume_db = -15
	music.stream = preload("res://moe_snow_demo/audio/music.ogg")
	music.volume_db = -23
	add_child(music)
	music.finished.connect(func(): music.play())
	if DisplayServer.get_name() != "headless":
		music.play()
	_build_hud()
	queue_redraw()

func _exit_tree() -> void:
	if Engine.is_editor_hint() or not is_instance_valid(music):
		return
	music.stop()
	sound.stop()
	jump_sound.stop()
	music.stream = null

func _build_echoes() -> void:
	echoes.clear()
	for i in range(PLATFORMS.size()):
		var r: Rect2 = PLATFORMS[i]
		if i >= 7:
			for j in range(3):
				echoes.append(r.position + Vector2(25 + j * 35, -25))
		elif i > 0:
			echoes.append(r.position + Vector2(45, -28))
	echoes_taken.resize(echoes.size())
	echoes_taken.fill(false)

func _register_input() -> void:
	var bindings := {"moe_left": [KEY_A, KEY_LEFT], "moe_right": [KEY_D, KEY_RIGHT], "moe_jump": [KEY_SPACE, KEY_W, KEY_UP], "moe_dash": [KEY_SHIFT], "moe_restart": [KEY_R], "moe_debug": [KEY_F3], "moe_mute": [KEY_M], "moe_pause": [KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func _unhandled_key_input(event: InputEvent) -> void:
	if Engine.is_editor_hint():
		return
	if event.is_action_pressed("moe_debug"):
		debug_visible = not debug_visible
		for guardian in guardians:
			guardian.debug_visible = debug_visible
	if event.is_action_pressed("moe_mute"):
		music_muted = not music_muted
		music.volume_db = -80 if music_muted else -23
	if event.is_action_pressed("moe_restart"):
		if finished:
			get_tree().reload_current_scene()
		else:
			player.take_hit(true)
	if event.is_action_pressed("moe_pause") and not finished:
		# Pause simulation only; the controller remains able to receive Escape.
		player.locked = not player.locked
		player.set_physics_process(not player.locked)
		for guardian in guardians:
			guardian.set_physics_process(not player.locked)
		_show_note("PAUSA · Esc para continuar" if player.locked else "Continúa el ascenso.", 999 if player.locked else 2)

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	background.camera_x = player.camera.get_screen_center_position().x
	if not finished and not player.locked:
		elapsed += delta
		note_time = maxf(0, note_time - delta)
		for i in range(1, CHECKPOINTS.size()):
			if i > checkpoints and player.position.distance_to(CHECKPOINTS[i]) < 55:
				checkpoints = i
				player.spawn = CHECKPOINTS[i]
				_show_note("Refugio activado · Tu progreso está a salvo.", 4)
				_play(preload("res://moe_snow_demo/audio/power_up.wav"))
		for i in range(RUNES.size()):
			if not runes[i] and (player.position + Vector2(0, -16)).distance_to(RUNES[i]) < 35:
				runes[i] = true
				_show_note("Runa recuperada · %d / 3" % runes.count(true), 3)
				_play(preload("res://moe_snow_demo/audio/power_up.wav"))
		for i in range(echoes.size()):
			if not echoes_taken[i] and (player.position + Vector2(0, -16)).distance_to(echoes[i]) < 29:
				echoes_taken[i] = true
				echoes_count += 1
				_play(preload("res://moe_snow_demo/audio/coin.wav"))
		if player.position.x > 4100 and player.position.y < 260:
			if runes.count(true) == 3:
				_finish()
			else:
				_show_note("El santuario necesita las 3 runas. Puedes volver a buscarlas.", 2)
	_update_hud()
	queue_redraw()

func _on_hurt() -> void:
	deaths += 1
	for guardian in guardians:
		guardian.reset_guardian()
	_play(preload("res://moe_snow_demo/audio/hurt.wav"))
	_show_note("De vuelta al refugio · Conservas las runas y los ecos.", 3)

func _play(stream: AudioStream) -> void:
	if DisplayServer.get_name() == "headless":
		return
	sound.stream = stream
	sound.volume_db = -13
	sound.play()

func _on_jump() -> void:
	if DisplayServer.get_name() != "headless":
		jump_sound.play()

func _show_note(text: String, seconds: float) -> void:
	note = text
	note_time = seconds

func _finish() -> void:
	finished = true
	player.locked = true
	for guardian in guardians:
		guardian.set_physics_process(false)
	win_panel.show()
	win_label.text = "EL ECO HA DESPERTADO\n\nSantuario restaurado · Nivel 1 completado\n\nTiempo  %02d:%02d     Ecos  %d / %d     Reintentos  %d\n\nR para jugar otra vez" % [int(elapsed) / 60, int(elapsed) % 60, echoes_count, echoes.size(), deaths]
	_play(preload("res://moe_snow_demo/audio/power_up.wav"))

func _panel(rect: Rect2, parent: Node, opacity := 0.9) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.045, 0.09, 0.15, opacity)
	style.border_color = Color("43657a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(7)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(at: Vector2, size_px: int, parent: Node, color := Color("d8edf3")) -> Label:
	var label := Label.new()
	label.position = at
	label.add_theme_font_size_override("font_size", size_px)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.layer = 10
	add_child(hud)
	_panel(Rect2(16, 14, 768, 57), hud, 0.88)
	title_label = _label(Vector2(30, 21), 17, hud)
	title_label.text = "MOUNTAIN OF ECHOES"
	_label(Vector2(30, 44), 11, hud, Color("85b2c6")).text = "01  /  EL PASO DE LOS GUARDIANES"
	stats_label = _label(Vector2(395, 24), 14, hud)
	_label(Vector2(395, 46), 10, hud, Color("85b2c6")).text = "Tres runas para despertar el santuario"
	_panel(Rect2(16, 414, 768, 25), hud, 0.85)
	hint_label = _label(Vector2(28, 419), 11, hud)
	hint_label.text = "A/D o ←/→ mover   ESPACIO saltar   SHIFT dash   R refugio   F3 IA   M música   ESC pausa"
	notice_label = _label(Vector2(20, 84), 14, hud)
	notice_label.size.x = 760
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.add_theme_color_override("font_shadow_color", Color("102038"))
	notice_label.add_theme_constant_override("shadow_offset_y", 2)
	debug_label = _label(Vector2(25, 122), 12, hud, Color("a9fff0"))
	win_panel = _panel(Rect2(110, 130, 580, 200), hud, 0.98)
	win_label = _label(Vector2(16, 25), 18, win_panel)
	win_label.size.x = 548
	win_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	win_panel.hide()

func _update_hud() -> void:
	stats_label.text = "RUNAS %d/3     ECOS %02d/%d     %02d:%02d" % [runes.count(true), echoes_count, echoes.size(), int(elapsed) / 60, int(elapsed) % 60]
	notice_label.text = note if note_time > 0 and not finished else ""
	debug_label.visible = debug_visible and not finished
	debug_label.text = "IA · círculo: detección | línea amarilla: velocidad\nWANDER: explora · SEEK: persigue · RETURN: regresa\nPisa un guardián para aturdirlo; el dash evita daño de contacto."

func _tree(x: float, ground_y: float, size_factor: float) -> void:
	var trunk := Color("3c4a61")
	draw_rect(Rect2(x - 4 * size_factor, ground_y - 50 * size_factor, 8 * size_factor, 50 * size_factor), trunk)
	for layer in range(3):
		var y := ground_y - (105 - layer * 25) * size_factor
		var width := (23 + layer * 10) * size_factor
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - width, y + 53 * size_factor), Vector2(x + width, y + 53 * size_factor)]), Color("244654"))
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x - width * 0.72, y + 34 * size_factor), Vector2(x + width * 0.72, y + 34 * size_factor)]), Color("aecfd9"))

func _diamond(pos: Vector2, radius: float, color: Color) -> void:
	draw_circle(pos, radius * 2.3, Color(color, 0.08))
	draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -radius), pos + Vector2(radius * 0.65, 0), pos + Vector2(0, radius), pos + Vector2(-radius * 0.65, 0)]), color)
	draw_line(pos + Vector2(0, -radius + 2), pos, Color.WHITE, 2)

func _draw() -> void:
	if Engine.is_editor_hint() and not mostrar_vista_previa:
		return
	var clock := elapsed
	for i in range(7):
		var r: Rect2 = PLATFORMS[i]
		_tree(r.position.x + 60, r.position.y, 0.9)
		_tree(r.end.x - 55, r.position.y, 1.35)
		_tree(r.end.x - 100, r.position.y, 0.7)
	for r in PLATFORMS:
		# Rock understructure plus actual winter tiles along the walkable top.
		draw_rect(r, Color("263e53"))
		for x in range(int(r.position.x), int(r.end.x), 32):
			for y in range(int(r.position.y) + 32, int(r.end.y), 32):
				draw_texture_rect_region(TERRAIN, Rect2(x, y, 32, 32), Rect2(112, 16, 16, 16), Color("809bb7"))
			draw_texture_rect_region(TERRAIN, Rect2(x, r.position.y, 32, 32), Rect2(112, 0, 16, 16))
		# A soft underside shadow anchors the floating shelves.
		draw_rect(Rect2(r.position.x, r.end.y - 5, r.size.x, 5), Color(0.04, 0.08, 0.15, 0.4))
	for i in range(CHECKPOINTS.size()):
		var pos: Vector2 = CHECKPOINTS[i]
		draw_rect(Rect2(pos.x - 5, pos.y - 57, 10, 57), Color("5e6475"))
		var c := Color("facd8b") if i <= checkpoints else Color("7390a2")
		draw_circle(pos + Vector2(0, -53), 29, Color(c, 0.1))
		draw_rect(Rect2(pos.x - 12, pos.y - 67, 24, 24), Color("233949"))
		draw_rect(Rect2(pos.x - 8, pos.y - 63, 16, 16), c)
		draw_string(ThemeDB.fallback_font, pos + Vector2(-25, -79), "REFUGIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("d5e9ee"))
	for i in range(RUNES.size()):
		if not runes[i]:
			_diamond(RUNES[i] + Vector2(0, sin(clock * 3 + i) * 5), 17, Color("88fff0"))
	for i in range(echoes.size()):
		if not echoes_taken[i]:
			_diamond(echoes[i] + Vector2(0, sin(clock * 4 + i) * 3), 7, Color("ffdb95"))
	# Shrine and its three rune sockets.
	var gate := Vector2(4150, 240)
	draw_rect(Rect2(gate + Vector2(-47, -110), Vector2(18, 110)), Color("819aaf"))
	draw_rect(Rect2(gate + Vector2(29, -110), Vector2(18, 110)), Color("819aaf"))
	draw_rect(Rect2(gate + Vector2(-57, -124), Vector2(114, 22)), Color("d1e3e9"))
	draw_rect(Rect2(gate + Vector2(-29, -102), Vector2(58, 102)), Color(0.35, 0.95, 0.85, 0.28 if runes.count(true) == 3 else 0.04))
	for i in range(3):
		_diamond(gate + Vector2(-25 + i * 25, -113), 7, Color("8fffea") if runes[i] else Color("475772"))
	draw_string(ThemeDB.fallback_font, gate + Vector2(-40, -140), "SANTUARIO", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("e0f0f4"))
	# Local route markers and atmospheric snow on foreground ledges.
	for x in [550, 1820, 2890, 4000]:
		var y := 384 if x == 550 else (320 if x == 1820 else (304 if x == 2890 else 240))
		draw_rect(Rect2(x, y - 40, 4, 40), Color("625c64"))
		draw_colored_polygon(PackedVector2Array([Vector2(x - 12, y - 40), Vector2(x + 19, y - 40), Vector2(x + 27, y - 32), Vector2(x + 19, y - 24), Vector2(x - 12, y - 24)]), Color("bc9985"))
		draw_line(Vector2(x - 4, y - 32), Vector2(x + 16, y - 32), Color("334457"), 2)
	if Engine.is_editor_hint():
		_draw_editor_actors()

func _draw_editor_actors() -> void:
	# Static counterparts of runtime actors, without instantiating non-tool scripts.
	var spawn: Vector2 = CHECKPOINTS[0]
	draw_texture_rect_region(preload("res://moe_snow_demo/art/panda.png"), Rect2(spawn + Vector2(-32, -64), Vector2(64, 64)), Rect2(0, 0, 32, 32))
	draw_string(ThemeDB.fallback_font, spawn + Vector2(-35, 23), "INICIO / PANDA", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("ffc989"))
	for point in GUARDIAN_POSITIONS:
		var tint := Color("81e7df")
		draw_circle(point, 25, Color(tint, 0.14))
		var polygon := PackedVector2Array()
		for offset in [Vector2(-14, 6), Vector2(-13, -10), Vector2(0, -23), Vector2(13, -10), Vector2(14, 6), Vector2(7, 3), Vector2(0, 10), Vector2(-7, 3)]:
			polygon.append(point + offset)
		draw_colored_polygon(polygon, tint)
		draw_rect(Rect2(point + Vector2(-9, -9), Vector2(18, 9)), Color("203552"))
		draw_rect(Rect2(point + Vector2(-6, -7), Vector2(3, 3)), Color.WHITE)
		draw_rect(Rect2(point + Vector2(3, -7), Vector2(3, 3)), Color.WHITE)
		draw_string(ThemeDB.fallback_font, point + Vector2(-38, -35), "GUARDIAN", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, tint)
		if mostrar_radios:
			draw_arc(point, 210, 0, TAU, 64, Color(tint, 0.35), 1)
	draw_string(ThemeDB.fallback_font, Vector2(20, 55), "VISTA PREVIA  /  F6 para jugar", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("cfeaf0"))
