class_name MainMenu
extends Control

const SNOW_LEVEL_PATH := "res://moe_editable/snow_level.tscn"
const CATCADE_SCENE := preload("res://moe_editable/minigames/catcade/catcade.tscn")
const PLAYER_SCRIPT := preload("res://moe_editable/scripts/player.gd")

const FONT_TITLE_PATH := "res://moe_editable/ui/fonts/CinzelDecorative-Bold.ttf"
const FONT_SERIF_PATH := "res://moe_editable/ui/fonts/Cinzel.ttf"
const FONT_SANS_PATH := "res://moe_editable/ui/fonts/SpaceGrotesk.ttf"

const TEX_BG_TITLE := "res://moe_editable/ui/art/bg_title.png"
const TEX_BG_SELECT := "res://moe_editable/ui/art/bg_level_select.png"
const TEX_THUMB_01 := "res://moe_editable/ui/art/thumb_level01.png"
const TEX_THUMB_02 := "res://moe_editable/ui/art/thumb_level02.png"
const TEX_THUMB_CAT := "res://moe_editable/ui/art/thumb_catapult.png"
const TEX_PANDA := "res://moe_editable/art/panda.png"
const TEX_NYANKO := "res://moe_editable/art/nyanko_ranger_skin.png"
const MUSIC_HARP_PATH := "res://Arpa de Abel.mp3"

var font_title: Font
var font_serif: Font
var font_sans: Font

var main_view: Control
var level_select_view: Control
var settings_modal: Control
var bgm_player: AudioStreamPlayer
var sfx_player: AudioStreamPlayer

var btn_new_game: Button
var btn_level_select: Button
var btn_catapult: Button
var btn_settings: Button
var btn_quit: Button
var btn_music_pill: Button
var btn_skin_card: Button

var btn_back_to_menu: Button
var btn_play_lvl_01: Button
var btn_play_lvl_02: Button
var btn_play_lvl_03: Button
var btn_play_catapult_select: Button

var btn_toggle_music: Button
var btn_toggle_skin: Button
var btn_toggle_fullscreen: Button
var btn_close_settings: Button
var slider_volume: HSlider

var lbl_skin_name: Label
var lbl_skin_sub: Label
var skin_avatar_rect: TextureRect
var lbl_runes_main: Label
var lbl_echoes_main: Label
var lbl_top_stats_select: Label
var lbl_catcade_reward: Label

var active_catcade_overlay: CanvasLayer = null
var is_music_muted: bool = false
var is_transitioning: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().content_scale_size = Vector2i(1280, 720)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP

	font_title = load(FONT_TITLE_PATH) if ResourceLoader.exists(FONT_TITLE_PATH) else ThemeDB.fallback_font
	font_serif = load(FONT_SERIF_PATH) if ResourceLoader.exists(FONT_SERIF_PATH) else ThemeDB.fallback_font
	font_sans = load(FONT_SANS_PATH) if ResourceLoader.exists(FONT_SANS_PATH) else ThemeDB.fallback_font

	_build_audio()
	_build_ui()
	_refresh_profile_ui()

func _build_audio() -> void:
	bgm_player = AudioStreamPlayer.new()
	bgm_player.name = "MusicHarp"
	if ResourceLoader.exists(MUSIC_HARP_PATH):
		var stream: AudioStream = load(MUSIC_HARP_PATH)
		if stream is AudioStreamMP3:
			stream.loop = true
		bgm_player.stream = stream
	bgm_player.volume_db = -5.0
	bgm_player.finished.connect(func() -> void:
		if not is_music_muted and active_catcade_overlay == null and is_inside_tree():
			bgm_player.play()
	)
	add_child(bgm_player)
	if DisplayServer.get_name() != "headless" and bgm_player.stream:
		bgm_player.play()

	sfx_player = AudioStreamPlayer.new()
	sfx_player.name = "SfxUI"
	sfx_player.volume_db = -10.0
	if ResourceLoader.exists("res://assets/audio/sounds/tap.wav"):
		sfx_player.stream = load("res://assets/audio/sounds/tap.wav")
	add_child(sfx_player)

func _play_click() -> void:
	if DisplayServer.get_name() != "headless" and sfx_player and sfx_player.stream:
		sfx_player.play()

func _make_stylebox(bg: Color, border: Color, border_w: int = 1, radius: int = 12, left_accent: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	if left_accent > 0:
		sb.border_width_left = left_accent
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	return sb

func _style_button(btn: Button, bg: Color, border: Color, hover_bg: Color, hover_border: Color, text_col: Color, hover_text_col: Color, font: Font, fsize: int, radius: int = 12, left_accent: int = 0) -> void:
	var normal_sb := _make_stylebox(bg, border, 1, radius, left_accent)
	var hover_sb := _make_stylebox(hover_bg, hover_border, 2, radius, maxi(left_accent, 2))
	var pressed_sb := _make_stylebox(hover_bg.darkened(0.15), hover_border, 2, radius, maxi(left_accent, 2))
	btn.add_theme_stylebox_override("normal", normal_sb)
	btn.add_theme_stylebox_override("hover", hover_sb)
	btn.add_theme_stylebox_override("pressed", pressed_sb)
	btn.add_theme_stylebox_override("focus", hover_sb)
	btn.add_theme_color_override("font_color", text_col)
	btn.add_theme_color_override("font_hover_color", hover_text_col)
	btn.add_theme_color_override("font_pressed_color", hover_text_col)
	btn.add_theme_color_override("font_focus_color", hover_text_col)
	if font:
		btn.add_theme_font_override("font", font)
	btn.add_theme_font_size_override("font_size", fsize)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

func _add_label(parent: Node, text: String, pos: Vector2, size: Vector2, font: Font, fsize: int, col: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.size = size
	lbl.horizontal_alignment = align
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if font:
		lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", fsize)
	lbl.add_theme_color_override("font_color", col)
	parent.add_child(lbl)
	return lbl

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# =========================================================================
	# 1. MAIN TITLE VIEW (Matches stitch_mountain_of_echoes_hud (1)/screen.png)
	# =========================================================================
	main_view = Control.new()
	main_view.name = "MainView"
	main_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(main_view)

	var bg_rect := TextureRect.new()
	bg_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TEX_BG_TITLE):
		bg_rect.texture = load(TEX_BG_TITLE)
	main_view.add_child(bg_rect)

	var vignette := ColorRect.new()
	vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	vignette.color = Color(0.02, 0.05, 0.1, 0.36)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	main_view.add_child(vignette)

	# Ambient snow/cyan motes
	var motes := CPUParticles2D.new()
	motes.position = Vector2(640, 360)
	motes.amount = 36
	motes.lifetime = 6.0
	motes.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	motes.emission_rect_extents = Vector2(640, 360)
	motes.gravity = Vector2(-6, -10)
	motes.scale_amount_min = 1.5
	motes.scale_amount_max = 3.2
	motes.color = Color(0.4, 0.95, 1.0, 0.35)
	main_view.add_child(motes)

	# Top-Left Header ("VERSIÓN ALPHA CREO" + "MOUNTAIN OF ECHOES")
	var badge_pill := Panel.new()
	badge_pill.position = Vector2(54, 28)
	badge_pill.size = Vector2(40, 20)
	badge_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge_pill.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.2, 0.28, 0.75), Color(0.4, 0.95, 1.0, 0.55), 1, 10))
	main_view.add_child(badge_pill)

	_add_label(main_view, "VERSIÓN ALPHA CREO", Vector2(104, 30), Vector2(240, 20), font_sans, 12, Color(0.68, 0.76, 0.85, 0.9))

	var lbl_mountain := _add_label(main_view, "MOUNTAIN", Vector2(52, 48), Vector2(520, 72), font_title, 54, Color(0.84, 0.96, 1.0, 1.0))
	lbl_mountain.add_theme_color_override("font_shadow_color", Color(0.15, 0.75, 0.95, 0.35))
	lbl_mountain.add_theme_constant_override("shadow_offset_x", 0)
	lbl_mountain.add_theme_constant_override("shadow_offset_y", 3)

	_add_label(main_view, "O F", Vector2(55, 114), Vector2(60, 28), font_serif, 15, Color(1.0, 0.82, 0.4, 1.0))

	var lbl_echoes := _add_label(main_view, "ECHOES", Vector2(104, 100), Vector2(420, 56), font_title, 44, Color(0.82, 0.75, 0.98, 1.0))
	lbl_echoes.add_theme_color_override("font_shadow_color", Color(0.66, 0.47, 1.0, 0.35))
	lbl_echoes.add_theme_constant_override("shadow_offset_y", 2)

	_add_label(main_view, "────────   › R ∩ Ɨ F - ┴ F ㅠ ‹   ────────", Vector2(54, 154), Vector2(360, 22), font_sans, 12, Color(0.45, 0.88, 0.96, 0.75))

	# Top-Right Music Pill ("Arpa de Abel")
	btn_music_pill = Button.new()
	btn_music_pill.name = "BtnMusicPill"
	btn_music_pill.position = Vector2(888, 28)
	btn_music_pill.size = Vector2(338, 36)
	btn_music_pill.text = "●   |   ♫  Arpa de Abel — Tema Principal"
	_style_button(
		btn_music_pill,
		Color(0.05, 0.09, 0.16, 0.86),
		Color(0.22, 0.34, 0.46, 0.85),
		Color(0.08, 0.15, 0.25, 0.95),
		Color(0.4, 0.95, 1.0, 0.9),
		Color(0.82, 0.9, 0.96, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		font_sans,
		12,
		10
	)
	btn_music_pill.pressed.connect(_on_toggle_music_pressed)
	main_view.add_child(btn_music_pill)

	# Left Main Menu Buttons Stack
	btn_new_game = Button.new()
	btn_new_game.name = "BtnNewGame"
	btn_new_game.position = Vector2(54, 318)
	btn_new_game.size = Vector2(448, 56)
	btn_new_game.text = "  ➜    NUEVO JUEGO"
	btn_new_game.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(
		btn_new_game,
		Color(0.28, 0.84, 0.99, 1.0),
		Color(0.65, 0.95, 1.0, 1.0),
		Color(0.48, 0.91, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.02, 0.05, 0.1, 1.0),
		Color(0.02, 0.04, 0.08, 1.0),
		font_serif,
		18,
		12
	)
	btn_new_game.pressed.connect(_on_new_game_pressed)
	main_view.add_child(btn_new_game)

	btn_level_select = Button.new()
	btn_level_select.name = "BtnLevelSelect"
	btn_level_select.position = Vector2(54, 386)
	btn_level_select.size = Vector2(448, 50)
	btn_level_select.text = "  △    SELECCIÓN DE NIVELES"
	btn_level_select.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(
		btn_level_select,
		Color(0.05, 0.09, 0.16, 0.9),
		Color(0.18, 0.3, 0.42, 0.9),
		Color(0.08, 0.16, 0.26, 0.96),
		Color(0.4, 0.95, 1.0, 1.0),
		Color(0.92, 0.96, 1.0, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		font_serif,
		15,
		12,
		4
	)
	btn_level_select.pressed.connect(_on_level_select_pressed)
	main_view.add_child(btn_level_select)

	btn_catapult = Button.new()
	btn_catapult.name = "BtnCatapult"
	btn_catapult.position = Vector2(54, 448)
	btn_catapult.size = Vector2(448, 62)
	btn_catapult.text = "  🐾    CAT-A-PULT ARCADE\n         MINIJUEGO DE PRECISIÓN"
	btn_catapult.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(
		btn_catapult,
		Color(0.08, 0.11, 0.18, 0.92),
		Color(0.72, 0.56, 0.18, 0.9),
		Color(0.14, 0.18, 0.28, 0.98),
		Color(1.0, 0.82, 0.25, 1.0),
		Color(1.0, 0.82, 0.35, 1.0),
		Color(1.0, 0.92, 0.55, 1.0),
		font_serif,
		14,
		12
	)
	btn_catapult.pressed.connect(_on_catapult_pressed)
	main_view.add_child(btn_catapult)

	btn_settings = Button.new()
	btn_settings.name = "BtnSettings"
	btn_settings.position = Vector2(54, 522)
	btn_settings.size = Vector2(448, 46)
	btn_settings.text = "  ⚙     AJUSTES & SONIDO"
	btn_settings.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(
		btn_settings,
		Color(0.05, 0.09, 0.15, 0.88),
		Color(0.16, 0.25, 0.36, 0.85),
		Color(0.09, 0.15, 0.24, 0.95),
		Color(0.4, 0.95, 1.0, 0.9),
		Color(0.8, 0.86, 0.92, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		font_serif,
		14,
		12
	)
	btn_settings.pressed.connect(_on_settings_pressed)
	main_view.add_child(btn_settings)

	btn_quit = Button.new()
	btn_quit.name = "BtnQuit"
	btn_quit.position = Vector2(54, 580)
	btn_quit.size = Vector2(448, 44)
	btn_quit.text = "  ↪     SALIR AL ESCRITORIO                                      [ESC]"
	btn_quit.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_style_button(
		btn_quit,
		Color(0.03, 0.06, 0.11, 0.85),
		Color(0.14, 0.2, 0.28, 0.8),
		Color(0.22, 0.06, 0.1, 0.92),
		Color(0.95, 0.3, 0.4, 0.95),
		Color(0.64, 0.72, 0.8, 1.0),
		Color(1.0, 0.75, 0.8, 1.0),
		font_serif,
		13,
		12
	)
	btn_quit.pressed.connect(_on_quit_pressed)
	main_view.add_child(btn_quit)

	# Bottom-Right Profile & Skin Card
	var profile_card := Panel.new()
	profile_card.position = Vector2(838, 518)
	profile_card.size = Vector2(388, 174)
	profile_card.add_theme_stylebox_override("panel", _make_stylebox(Color(0.04, 0.08, 0.14, 0.92), Color(0.16, 0.26, 0.38, 0.9), 1, 14))
	main_view.add_child(profile_card)

	var avatar_box := Panel.new()
	avatar_box.position = Vector2(18, 16)
	avatar_box.size = Vector2(50, 50)
	avatar_box.add_theme_stylebox_override("panel", _make_stylebox(Color(0.08, 0.13, 0.22, 1.0), Color(0.4, 0.95, 1.0, 0.75), 1, 10))
	profile_card.add_child(avatar_box)

	skin_avatar_rect = TextureRect.new()
	skin_avatar_rect.position = Vector2(5, 5)
	skin_avatar_rect.size = Vector2(40, 40)
	skin_avatar_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	skin_avatar_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	avatar_box.add_child(skin_avatar_rect)

	_add_label(profile_card, "SKIN ACTIVA  (CLICK PARA CAMBIAR)", Vector2(80, 14), Vector2(290, 16), font_sans, 10, Color(0.6, 0.68, 0.78, 1.0))
	lbl_skin_name = _add_label(profile_card, "PANDA DEL ECO (Red Nyanko)", Vector2(80, 30), Vector2(290, 22), font_serif, 14, Color(1.0, 1.0, 1.0, 1.0))
	lbl_skin_sub = _add_label(profile_card, "Guardián de la Cordillera", Vector2(80, 49), Vector2(290, 18), font_sans, 11, Color(0.4, 0.95, 1.0, 0.9))

	btn_skin_card = Button.new()
	btn_skin_card.name = "BtnSkinCard"
	btn_skin_card.position = Vector2(14, 12)
	btn_skin_card.size = Vector2(360, 58)
	btn_skin_card.flat = true
	btn_skin_card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	btn_skin_card.pressed.connect(_on_toggle_skin_pressed)
	profile_card.add_child(btn_skin_card)

	var box_runes := Panel.new()
	box_runes.position = Vector2(18, 82)
	box_runes.size = Vector2(170, 52)
	box_runes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_runes.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.9), Color(0.14, 0.22, 0.32, 0.8), 1, 8))
	profile_card.add_child(box_runes)
	_add_label(box_runes, "RUNAS CUMBRE", Vector2(12, 8), Vector2(146, 16), font_sans, 10, Color(0.6, 0.68, 0.78, 1.0))
	lbl_runes_main = _add_label(box_runes, "✦ x0", Vector2(12, 24), Vector2(146, 22), font_sans, 15, Color(1.0, 0.82, 0.35, 1.0))

	var box_echoes := Panel.new()
	box_echoes.position = Vector2(198, 82)
	box_echoes.size = Vector2(172, 52)
	box_echoes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box_echoes.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.9), Color(0.14, 0.22, 0.32, 0.8), 1, 8))
	profile_card.add_child(box_echoes)
	_add_label(box_echoes, "ECOS SINTONIZADOS", Vector2(12, 8), Vector2(150, 16), font_sans, 10, Color(0.6, 0.68, 0.78, 1.0))
	lbl_echoes_main = _add_label(box_echoes, "◆ x0", Vector2(12, 24), Vector2(150, 22), font_sans, 15, Color(0.4, 0.95, 1.0, 1.0))

	_add_label(profile_card, "Capítulo Actual:", Vector2(18, 144), Vector2(140, 20), font_sans, 11, Color(0.65, 0.72, 0.82, 1.0))
	_add_label(profile_card, "VII. El Altar Olvidado", Vector2(210, 144), Vector2(160, 20), font_sans, 11, Color(0.68, 0.5, 1.0, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	# =========================================================================
	# 2. LEVEL SELECT VIEW (Matches stitch_mountain_of_echoes_hud/screen.png)
	# =========================================================================
	level_select_view = Control.new()
	level_select_view.name = "LevelSelectView"
	level_select_view.visible = false
	level_select_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(level_select_view)

	var bg_sel := TextureRect.new()
	bg_sel.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg_sel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg_sel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TEX_BG_SELECT):
		bg_sel.texture = load(TEX_BG_SELECT)
	level_select_view.add_child(bg_sel)

	var sel_dim := ColorRect.new()
	sel_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	sel_dim.color = Color(0.02, 0.05, 0.1, 0.62)
	sel_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	level_select_view.add_child(sel_dim)

	# Constellation dashed line connecting the 3 stages
	var line_path := Line2D.new()
	line_path.points = PackedVector2Array([
		Vector2(280, 420),
		Vector2(490, 350),
		Vector2(770, 232)
	])
	line_path.width = 2.0
	line_path.default_color = Color(0.55, 0.45, 0.9, 0.55)
	level_select_view.add_child(line_path)

	# Top Header Bar
	var top_header := Panel.new()
	top_header.position = Vector2(0, 0)
	top_header.size = Vector2(1280, 88)
	top_header.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.92), Color(0.14, 0.24, 0.35, 0.9), 1, 0))
	level_select_view.add_child(top_header)

	btn_back_to_menu = Button.new()
	btn_back_to_menu.name = "BtnBackToMenu"
	btn_back_to_menu.position = Vector2(32, 22)
	btn_back_to_menu.size = Vector2(284, 44)
	btn_back_to_menu.text = "←    VOLVER AL MENÚ PRINCIPAL    [ESC]"
	_style_button(
		btn_back_to_menu,
		Color(0.06, 0.11, 0.18, 0.92),
		Color(0.2, 0.34, 0.46, 0.9),
		Color(0.1, 0.18, 0.28, 0.98),
		Color(0.4, 0.95, 1.0, 1.0),
		Color(0.86, 0.92, 0.98, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		font_sans,
		12,
		10
	)
	btn_back_to_menu.pressed.connect(_on_back_to_menu_pressed)
	level_select_view.add_child(btn_back_to_menu)

	_add_label(level_select_view, "CUMBRE DEL ECO / ASCENSO PRINCIPAL", Vector2(390, 18), Vector2(500, 20), font_sans, 11, Color(0.4, 0.95, 1.0, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(level_select_view, "EL SENDERO DE LA MONTAÑA", Vector2(340, 38), Vector2(600, 36), font_sans, 26, Color(0.96, 0.98, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	var stats_pill := Panel.new()
	stats_pill.position = Vector2(1002, 25)
	stats_pill.size = Vector2(246, 38)
	stats_pill.add_theme_stylebox_override("panel", _make_stylebox(Color(0.06, 0.11, 0.18, 0.92), Color(0.2, 0.34, 0.46, 0.9), 1, 18))
	level_select_view.add_child(stats_pill)
	lbl_top_stats_select = _add_label(stats_pill, "★ RUNAS x0   |   ◆ ECOS x0", Vector2(10, 8), Vector2(226, 22), font_sans, 12, Color(1.0, 0.86, 0.42, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	# --- CARD 1: 01 • El Paso de los Guardianes ---
	var card1 := Panel.new()
	card1.position = Vector2(40, 208)
	card1.size = Vector2(308, 412)
	card1.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.1, 0.17, 0.94), Color(0.4, 0.95, 1.0, 0.95), 2, 16))
	level_select_view.add_child(card1)

	_add_label(card1, "● ACTIVO • NIVEL 01", Vector2(18, 18), Vector2(160, 20), font_sans, 11, Color(0.4, 0.95, 1.0, 1.0))
	_add_label(card1, "DISPONIBLE", Vector2(170, 18), Vector2(120, 20), font_sans, 11, Color(1.0, 0.82, 0.35, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	var thumb1 := TextureRect.new()
	thumb1.position = Vector2(18, 46)
	thumb1.size = Vector2(272, 140)
	thumb1.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb1.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TEX_THUMB_01):
		thumb1.texture = load(TEX_THUMB_01)
	card1.add_child(thumb1)

	var arcade_tag := Panel.new()
	arcade_tag.position = Vector2(26, 152)
	arcade_tag.size = Vector2(142, 24)
	arcade_tag.add_theme_stylebox_override("panel", _make_stylebox(Color(0.11, 0.1, 0.06, 0.92), Color(1.0, 0.82, 0.35, 0.85), 1, 12))
	card1.add_child(arcade_tag)
	_add_label(arcade_tag, "★ Arcade Encontrada", Vector2(8, 3), Vector2(126, 18), font_sans, 10, Color(1.0, 0.82, 0.35, 1.0))

	_add_label(card1, "01 • El Paso de los Guardianes", Vector2(18, 198), Vector2(272, 26), font_sans, 17, Color(1.0, 1.0, 1.0, 1.0))
	var desc1 := _add_label(card1, "Antiguas balconadas de roca y faroles vigías sobre el cañón brumoso.", Vector2(18, 226), Vector2(272, 42), font_sans, 12, Color(0.68, 0.76, 0.85, 1.0))
	desc1.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var stats1 := Panel.new()
	stats1.position = Vector2(18, 280)
	stats1.size = Vector2(272, 38)
	stats1.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.9), Color(0.14, 0.24, 0.34, 0.8), 1, 8))
	card1.add_child(stats1)
	_add_label(stats1, "★ Runas activas", Vector2(12, 9), Vector2(120, 20), font_sans, 12, Color(1.0, 0.82, 0.35, 1.0))
	_add_label(stats1, "◆ Ecos del Paso", Vector2(140, 9), Vector2(120, 20), font_sans, 12, Color(0.4, 0.95, 1.0, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	btn_play_lvl_01 = Button.new()
	btn_play_lvl_01.name = "BtnPlayLevel01"
	btn_play_lvl_01.position = Vector2(18, 336)
	btn_play_lvl_01.size = Vector2(272, 48)
	btn_play_lvl_01.text = "INICIAR NIVEL   →"
	_style_button(
		btn_play_lvl_01,
		Color(0.4, 0.95, 1.0, 1.0),
		Color(0.75, 0.98, 1.0, 1.0),
		Color(0.58, 0.97, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.02, 0.05, 0.1, 1.0),
		Color(0.02, 0.04, 0.08, 1.0),
		font_sans,
		13,
		12
	)
	btn_play_lvl_01.pressed.connect(func() -> void: _start_main_game(0))
	card1.add_child(btn_play_lvl_01)

	# --- CARD 2: 02 • Valle de la Sombra del Eco ---
	var card2 := Panel.new()
	card2.position = Vector2(374, 240)
	card2.size = Vector2(278, 380)
	card2.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.09, 0.16, 0.92), Color(0.42, 0.32, 0.65, 0.85), 1, 14))
	level_select_view.add_child(card2)

	_add_label(card2, "● DESBLOQUEADO • NIVEL 02", Vector2(16, 16), Vector2(170, 20), font_sans, 11, Color(0.68, 0.48, 1.0, 1.0))
	_add_label(card2, "LISTO", Vector2(190, 16), Vector2(72, 20), font_sans, 10, Color(0.6, 0.68, 0.78, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	var thumb2 := TextureRect.new()
	thumb2.position = Vector2(16, 44)
	thumb2.size = Vector2(246, 124)
	thumb2.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb2.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TEX_THUMB_02):
		thumb2.texture = load(TEX_THUMB_02)
	card2.add_child(thumb2)

	_add_label(card2, "02 • Valle de la Sombra del Eco", Vector2(16, 182), Vector2(246, 24), font_sans, 15, Color(0.92, 0.95, 1.0, 1.0))
	var desc2 := _add_label(card2, "Descenso por las ciudadelas sumergidas en neblina y enredaderas góticas.", Vector2(16, 208), Vector2(246, 42), font_sans, 11, Color(0.62, 0.7, 0.8, 1.0))
	desc2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var stats2 := Panel.new()
	stats2.position = Vector2(16, 260)
	stats2.size = Vector2(246, 36)
	stats2.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.9), Color(0.16, 0.22, 0.34, 0.8), 1, 8))
	card2.add_child(stats2)
	_add_label(stats2, "★ Runas del Valle", Vector2(12, 8), Vector2(110, 20), font_sans, 11, Color(0.82, 0.86, 0.92, 1.0))
	_add_label(stats2, "◆ Ecos Sombríos", Vector2(122, 8), Vector2(110, 20), font_sans, 11, Color(0.82, 0.86, 0.92, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	btn_play_lvl_02 = Button.new()
	btn_play_lvl_02.name = "BtnPlayLevel02"
	btn_play_lvl_02.position = Vector2(16, 314)
	btn_play_lvl_02.size = Vector2(246, 44)
	btn_play_lvl_02.text = "EXPLORAR ZONA"
	_style_button(
		btn_play_lvl_02,
		Color(0.24, 0.16, 0.42, 0.85),
		Color(0.66, 0.48, 1.0, 0.85),
		Color(0.58, 0.4, 0.95, 1.0),
		Color(0.85, 0.75, 1.0, 1.0),
		Color(0.86, 0.76, 1.0, 1.0),
		Color(0.05, 0.03, 0.1, 1.0),
		font_sans,
		12,
		10
	)
	btn_play_lvl_02.pressed.connect(func() -> void: _start_main_game(1))
	card2.add_child(btn_play_lvl_02)

	# --- CARD 3: 03 • El Santuario de la Cumbre ---
	var card3 := Panel.new()
	card3.position = Vector2(676, 256)
	card3.size = Vector2(246, 336)
	card3.add_theme_stylebox_override("panel", _make_stylebox(Color(0.04, 0.07, 0.13, 0.88), Color(0.24, 0.3, 0.4, 0.8), 1, 14))
	level_select_view.add_child(card3)

	_add_label(card3, "CUMBRE • NIVEL 03", Vector2(16, 16), Vector2(180, 18), font_sans, 10, Color(0.55, 0.64, 0.74, 1.0))
	_add_label(card3, "⚡", Vector2(210, 14), Vector2(20, 20), font_sans, 12, Color(1.0, 0.82, 0.35, 0.9), HORIZONTAL_ALIGNMENT_RIGHT)

	var seal_box := Panel.new()
	seal_box.position = Vector2(16, 44)
	seal_box.size = Vector2(214, 114)
	seal_box.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.05, 0.1, 0.9), Color(0.22, 0.28, 0.38, 0.7), 1, 10))
	card3.add_child(seal_box)
	_add_label(seal_box, "⚡", Vector2(0, 24), Vector2(214, 32), font_sans, 24, Color(1.0, 0.82, 0.35, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(seal_box, "SELLO ANCESTRAL", Vector2(0, 68), Vector2(214, 20), font_sans, 10, Color(1.0, 0.82, 0.35, 0.85), HORIZONTAL_ALIGNMENT_CENTER)

	_add_label(card3, "03 • El Santuario de la Cumbre", Vector2(16, 174), Vector2(214, 22), font_sans, 13, Color(0.82, 0.88, 0.94, 1.0))
	var desc3 := _add_label(card3, "Cima helada donde resuenan los cantos eternos del monolito.", Vector2(16, 198), Vector2(214, 40), font_sans, 11, Color(0.55, 0.62, 0.72, 1.0))
	desc3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	btn_play_lvl_03 = Button.new()
	btn_play_lvl_03.name = "BtnPlayLevel03"
	btn_play_lvl_03.position = Vector2(16, 256)
	btn_play_lvl_03.size = Vector2(214, 44)
	btn_play_lvl_03.text = "ASCENDER AL SANTUARIO"
	_style_button(
		btn_play_lvl_03,
		Color(0.08, 0.11, 0.18, 0.92),
		Color(0.55, 0.42, 0.18, 0.8),
		Color(0.16, 0.2, 0.28, 0.98),
		Color(1.0, 0.82, 0.35, 1.0),
		Color(0.95, 0.82, 0.48, 1.0),
		Color(1.0, 0.92, 0.6, 1.0),
		font_sans,
		11,
		8
	)
	btn_play_lvl_03.pressed.connect(func() -> void: _start_main_game(2))
	card3.add_child(btn_play_lvl_03)

	# --- CARD 4: THE BATTLE CAT-A-PULT (Bonus Arcade Card) ---
	var card4 := Panel.new()
	card4.position = Vector2(946, 244)
	card4.size = Vector2(294, 376)
	card4.add_theme_stylebox_override("panel", _make_stylebox(Color(0.08, 0.09, 0.14, 0.95), Color(0.92, 0.72, 0.15, 0.95), 2, 16))
	level_select_view.add_child(card4)

	_add_label(card4, "🕹 SECRET ARCADE DISCOVERED", Vector2(16, 16), Vector2(200, 18), font_sans, 10, Color(1.0, 0.82, 0.3, 1.0))
	_add_label(card4, "BONUS", Vector2(226, 16), Vector2(52, 18), font_sans, 10, Color(1.0, 0.82, 0.3, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)

	var thumb4 := TextureRect.new()
	thumb4.position = Vector2(16, 42)
	thumb4.size = Vector2(262, 118)
	thumb4.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumb4.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	if ResourceLoader.exists(TEX_THUMB_CAT):
		thumb4.texture = load(TEX_THUMB_CAT)
	card4.add_child(thumb4)

	_add_label(card4, "SCORE: 99,400 PTS", Vector2(120, 138), Vector2(150, 18), font_sans, 10, Color(1.0, 0.88, 0.3, 1.0), HORIZONTAL_ALIGNMENT_RIGHT)
	_add_label(card4, "THE BATTLE CAT-A-PULT", Vector2(16, 172), Vector2(262, 22), font_sans, 15, Color(1.0, 1.0, 1.0, 1.0))
	var desc4 := _add_label(card4, "Minijuego balístico clásico rescatado en la cámara secreta del Paso.", Vector2(16, 196), Vector2(262, 38), font_sans, 11, Color(0.75, 0.8, 0.88, 1.0))
	desc4.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	var reward_box := Panel.new()
	reward_box.position = Vector2(16, 240)
	reward_box.size = Vector2(262, 50)
	reward_box.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.06, 0.1, 0.92), Color(0.55, 0.44, 0.16, 0.8), 1, 10))
	card4.add_child(reward_box)
	_add_label(reward_box, "✓   Skin Desbloqueada", Vector2(12, 6), Vector2(236, 18), font_sans, 11, Color(1.0, 0.82, 0.3, 1.0))
	lbl_catcade_reward = _add_label(reward_box, "      Nyanko Ranger Astral", Vector2(12, 24), Vector2(236, 18), font_sans, 11, Color(0.86, 0.9, 0.96, 1.0))

	btn_play_catapult_select = Button.new()
	btn_play_catapult_select.name = "BtnPlayCatapultSelect"
	btn_play_catapult_select.position = Vector2(16, 306)
	btn_play_catapult_select.size = Vector2(262, 46)
	btn_play_catapult_select.text = "JUGAR MINIJUEGO   ⚡"
	_style_button(
		btn_play_catapult_select,
		Color(0.96, 0.76, 0.12, 1.0),
		Color(1.0, 0.9, 0.45, 1.0),
		Color(1.0, 0.84, 0.25, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.04, 0.06, 0.1, 1.0),
		Color(0.02, 0.03, 0.06, 1.0),
		font_sans,
		13,
		12
	)
	btn_play_catapult_select.pressed.connect(_on_catapult_pressed)
	card4.add_child(btn_play_catapult_select)

	# =========================================================================
	# 3. SETTINGS & AUDIO MODAL (Ajustes & Sonido)
	# =========================================================================
	settings_modal = Control.new()
	settings_modal.name = "SettingsModal"
	settings_modal.visible = false
	settings_modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(settings_modal)

	var modal_dim := ColorRect.new()
	modal_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	modal_dim.color = Color(0.01, 0.03, 0.07, 0.76)
	settings_modal.add_child(modal_dim)

	var modal_card := Panel.new()
	modal_card.position = Vector2(380, 130)
	modal_card.size = Vector2(520, 460)
	modal_card.add_theme_stylebox_override("panel", _make_stylebox(Color(0.05, 0.09, 0.16, 0.97), Color(0.4, 0.95, 1.0, 0.9), 2, 16))
	settings_modal.add_child(modal_card)

	_add_label(modal_card, "⚙   AJUSTES & SONIDO", Vector2(28, 24), Vector2(464, 32), font_serif, 22, Color(0.4, 0.95, 1.0, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_add_label(modal_card, "Configuración de Audio, Apariencia y Controles", Vector2(28, 56), Vector2(464, 20), font_sans, 12, Color(0.68, 0.76, 0.85, 1.0), HORIZONTAL_ALIGNMENT_CENTER)

	_add_label(modal_card, "VOLUMEN GENERAL", Vector2(36, 98), Vector2(220, 20), font_sans, 12, Color(0.88, 0.94, 1.0, 1.0))
	slider_volume = HSlider.new()
	slider_volume.position = Vector2(240, 98)
	slider_volume.size = Vector2(244, 22)
	slider_volume.min_value = 0.0
	slider_volume.max_value = 100.0
	slider_volume.step = 1.0
	slider_volume.value = 85.0
	slider_volume.value_changed.connect(_on_volume_changed)
	modal_card.add_child(slider_volume)

	btn_toggle_music = Button.new()
	btn_toggle_music.name = "BtnToggleMusic"
	btn_toggle_music.position = Vector2(36, 138)
	btn_toggle_music.size = Vector2(448, 44)
	btn_toggle_music.text = "♫   MÚSICA (ARPA DE ABEL): ENCENDIDA"
	_style_button(
		btn_toggle_music,
		Color(0.07, 0.13, 0.22, 0.95),
		Color(0.24, 0.4, 0.56, 0.9),
		Color(0.11, 0.2, 0.32, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		Color(0.92, 0.96, 1.0, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		font_sans,
		13,
		10
	)
	btn_toggle_music.pressed.connect(_on_toggle_music_pressed)
	modal_card.add_child(btn_toggle_music)

	btn_toggle_skin = Button.new()
	btn_toggle_skin.name = "BtnToggleSkin"
	btn_toggle_skin.position = Vector2(36, 194)
	btn_toggle_skin.size = Vector2(448, 44)
	btn_toggle_skin.text = "★   SKIN ACTIVA: PANDA DEL ECO"
	_style_button(
		btn_toggle_skin,
		Color(0.08, 0.12, 0.2, 0.95),
		Color(0.7, 0.55, 0.2, 0.9),
		Color(0.14, 0.18, 0.28, 1.0),
		Color(1.0, 0.82, 0.3, 1.0),
		Color(1.0, 0.86, 0.4, 1.0),
		Color(1.0, 0.95, 0.65, 1.0),
		font_sans,
		13,
		10
	)
	btn_toggle_skin.pressed.connect(_on_toggle_skin_pressed)
	modal_card.add_child(btn_toggle_skin)

	btn_toggle_fullscreen = Button.new()
	btn_toggle_fullscreen.name = "BtnToggleFullscreen"
	btn_toggle_fullscreen.position = Vector2(36, 250)
	btn_toggle_fullscreen.size = Vector2(448, 44)
	btn_toggle_fullscreen.text = "🖥   MODO DE PANTALLA: VENTANA / COMPLETA"
	_style_button(
		btn_toggle_fullscreen,
		Color(0.07, 0.13, 0.22, 0.95),
		Color(0.24, 0.4, 0.56, 0.9),
		Color(0.11, 0.2, 0.32, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		Color(0.92, 0.96, 1.0, 1.0),
		Color(0.4, 0.95, 1.0, 1.0),
		font_sans,
		13,
		10
	)
	btn_toggle_fullscreen.pressed.connect(_on_toggle_fullscreen_pressed)
	modal_card.add_child(btn_toggle_fullscreen)

	var controls_box := Panel.new()
	controls_box.position = Vector2(36, 308)
	controls_box.size = Vector2(448, 72)
	controls_box.add_theme_stylebox_override("panel", _make_stylebox(Color(0.03, 0.06, 0.11, 0.92), Color(0.16, 0.26, 0.38, 0.8), 1, 10))
	modal_card.add_child(controls_box)
	var lbl_ctrl := _add_label(
		controls_box,
		"[A/D o ←/→] Mover   ·   [ESPACIO] Saltar   ·   [SHIFT] Dash\n[E] Jugar Cat-a-pult Arcade   ·   [R] Reiniciar   ·   [ESC] Pausa",
		Vector2(12, 14),
		Vector2(424, 48),
		font_sans,
		12,
		Color(0.76, 0.84, 0.92, 1.0),
		HORIZONTAL_ALIGNMENT_CENTER
	)
	lbl_ctrl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	btn_close_settings = Button.new()
	btn_close_settings.name = "BtnCloseSettings"
	btn_close_settings.position = Vector2(36, 394)
	btn_close_settings.size = Vector2(448, 46)
	btn_close_settings.text = "GUARDAR Y VOLVER   [ESC]"
	_style_button(
		btn_close_settings,
		Color(0.28, 0.84, 0.99, 1.0),
		Color(0.65, 0.95, 1.0, 1.0),
		Color(0.48, 0.91, 1.0, 1.0),
		Color(1.0, 1.0, 1.0, 1.0),
		Color(0.02, 0.05, 0.1, 1.0),
		Color(0.02, 0.04, 0.08, 1.0),
		font_sans,
		14,
		10
	)
	btn_close_settings.pressed.connect(func() -> void:
		_play_click()
		settings_modal.visible = false
	)
	modal_card.add_child(btn_close_settings)

func _refresh_profile_ui() -> void:
	var use_nyanko: bool = PLAYER_SCRIPT.cat_skin_unlocked
	var runes_cnt: int = PLAYER_SCRIPT.saved_runes
	var echoes_cnt: int = PLAYER_SCRIPT.saved_echoes

	if lbl_runes_main:
		lbl_runes_main.text = "✦ x%d" % runes_cnt
	if lbl_echoes_main:
		lbl_echoes_main.text = "◆ x%d" % echoes_cnt
	if lbl_top_stats_select:
		lbl_top_stats_select.text = "★ RUNAS x%d   |   ◆ ECOS x%d" % [runes_cnt, echoes_cnt]

	if use_nyanko:
		if lbl_skin_name:
			lbl_skin_name.text = "RED NYANKO RANGER (Equipada)"
		if lbl_skin_sub:
			lbl_skin_sub.text = "Héroe Sentai Felino · [Click cambiar]"
		if btn_toggle_skin:
			btn_toggle_skin.text = "★   SKIN ACTIVA: RED NYANKO RANGER"
		if lbl_catcade_reward:
			lbl_catcade_reward.text = "      Nyanko Ranger Astral (Equipada)"
		if skin_avatar_rect and ResourceLoader.exists(TEX_NYANKO):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(TEX_NYANKO)
			atlas.region = Rect2(0, 0, 64, 64)
			skin_avatar_rect.texture = atlas
	else:
		if lbl_skin_name:
			lbl_skin_name.text = "PANDA DEL ECO (Red Nyanko)"
		if lbl_skin_sub:
			lbl_skin_sub.text = "Guardián de la Cordillera · [Click cambiar]"
		if btn_toggle_skin:
			btn_toggle_skin.text = "★   SKIN ACTIVA: PANDA DEL ECO"
		if skin_avatar_rect and ResourceLoader.exists(TEX_PANDA):
			var atlas := AtlasTexture.new()
			atlas.atlas = load(TEX_PANDA)
			atlas.region = Rect2(0, 0, 32, 32)
			skin_avatar_rect.texture = atlas

func _on_new_game_pressed() -> void:
	_start_main_game(0)

func _start_main_game(zone_index: int) -> void:
	if is_transitioning:
		return
	is_transitioning = true
	_play_click()
	PLAYER_SCRIPT.start_checkpoint_index = zone_index
	get_tree().change_scene_to_file(SNOW_LEVEL_PATH)

func _on_level_select_pressed() -> void:
	_play_click()
	_refresh_profile_ui()
	main_view.visible = false
	level_select_view.visible = true
	settings_modal.visible = false

func _on_back_to_menu_pressed() -> void:
	_play_click()
	_refresh_profile_ui()
	level_select_view.visible = false
	settings_modal.visible = false
	main_view.visible = true

func _on_settings_pressed() -> void:
	_play_click()
	_refresh_profile_ui()
	settings_modal.visible = true

func _on_toggle_music_pressed() -> void:
	_play_click()
	is_music_muted = not is_music_muted
	if bgm_player:
		bgm_player.volume_db = -80.0 if is_music_muted else -5.0
	if btn_music_pill:
		btn_music_pill.text = ("○   |   ♫  Arpa de Abel (Silenciada)" if is_music_muted else "●   |   ♫  Arpa de Abel — Tema Principal")
	if btn_toggle_music:
		btn_toggle_music.text = ("♫   MÚSICA (ARPA DE ABEL): SILENCIADA" if is_music_muted else "♫   MÚSICA (ARPA DE ABEL): ENCENDIDA")

func _on_toggle_skin_pressed() -> void:
	_play_click()
	PLAYER_SCRIPT.cat_skin_unlocked = not PLAYER_SCRIPT.cat_skin_unlocked
	_refresh_profile_ui()

func _on_toggle_fullscreen_pressed() -> void:
	_play_click()
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func _on_volume_changed(val: float) -> void:
	if val <= 1.0:
		AudioServer.set_bus_volume_db(0, -80.0)
	else:
		AudioServer.set_bus_volume_db(0, linear_to_db(val / 100.0))

func _on_catapult_pressed() -> void:
	if active_catcade_overlay != null:
		return
	_play_click()
	if bgm_player:
		bgm_player.stream_paused = true

	get_window().content_scale_size = Vector2i(640, 360)
	main_view.visible = false
	level_select_view.visible = false
	settings_modal.visible = false

	var catcade = CATCADE_SCENE.instantiate()
	catcade.name = "CatcadeMain"
	catcade.exited_to_game.connect(_on_catcade_closed)
	if catcade.has_signal("minigame_completed"):
		catcade.minigame_completed.connect(func(_score: int) -> void:
			PLAYER_SCRIPT.cat_skin_unlocked = true
			_refresh_profile_ui()
		)

	var overlay := CanvasLayer.new()
	overlay.name = "CatcadeOverlay"
	overlay.layer = 100
	overlay.add_child(catcade)
	add_child(overlay)
	active_catcade_overlay = overlay

func _on_catcade_closed() -> void:
	if active_catcade_overlay and is_instance_valid(active_catcade_overlay):
		active_catcade_overlay.queue_free()
	active_catcade_overlay = null

	get_window().content_scale_size = Vector2i(1280, 720)
	main_view.visible = true
	level_select_view.visible = false
	settings_modal.visible = false
	_refresh_profile_ui()

	if bgm_player:
		bgm_player.stream_paused = false
		if DisplayServer.get_name() != "headless" and not bgm_player.playing and not is_music_muted:
			bgm_player.play()

func _on_quit_pressed() -> void:
	_play_click()
	get_tree().quit(0)

func _input(event: InputEvent) -> void:
	if active_catcade_overlay != null:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			if settings_modal and settings_modal.visible:
				_play_click()
				settings_modal.visible = false
			elif level_select_view and level_select_view.visible:
				_on_back_to_menu_pressed()
			else:
				_on_quit_pressed()
