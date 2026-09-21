extends Node2D
## The scene owns the layout. This script only connects existing nodes.
@export var level_title := "01 / EL PASO DE LOS GUARDIANES"
@export var fall_limit := 680.0
@onready var player = $Player
@onready var ground: TileMapLayer = $Ground
@onready var music: AudioStreamPlayer = $Audio/Music
@onready var sound: AudioStreamPlayer = $Audio/Effect
@onready var jump_sound: AudioStreamPlayer = $Audio/Jump
@onready var stats: Label = $HUD/Stats
@onready var notice: Label = $HUD/Notice
@onready var win_panel: Panel = $HUD/WinPanel
@onready var win_label: Label = $HUD/WinPanel/WinText
var guardians: Array[Node] = []
var items: Array[Node] = []
var total_runes := 0
var total_echoes := 0
var runes := 0
var echoes := 0
var deaths := 0
var elapsed := 0.0
var note_time := 6.0
var finished := false
var paused := false
var debug_visible := false
var muted := false
var active_checkpoint: Node2D

func _ready() -> void:
	$HUD.show()
	$Backdrop.show()
	get_window().content_scale_size = Vector2i(800, 450)
	get_window().content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	get_window().content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_register_input()
	player.fall_limit = fall_limit
	# Find descendants, so duplicates and reorganized folders are supported.
	for node in find_children("*", "CharacterBody2D", true, false):
		if node.has_method("reset_guardian"):
			guardians.append(node)
			node.target = player
	for node in find_children("*", "Area2D", true, false):
		if node.has_method("activate"):
			items.append(node)
			if node.kind == "rune":
				total_runes += 1
			elif node.kind == "echo":
				total_echoes += 1
			node.body_entered.connect(_on_item_entered.bind(node))
	player.hurt.connect(_on_hurt)
	player.jumped.connect(func():
		if DisplayServer.get_name() != "headless":
			jump_sound.play())
	$HUD/Subtitle.text = level_title
	_show_note("Recoge las %d runas y alcanza el santuario." % total_runes, 6)
	$HUD/Objective.text = "Recupera las runas para despertar el santuario"
	win_panel.hide()
	if DisplayServer.get_name() != "headless":
		music.play()
	_update_hud()

func _register_input() -> void:
	var bindings := {"moee_left": [KEY_A, KEY_LEFT], "moee_right": [KEY_D, KEY_RIGHT], "moee_jump": [KEY_SPACE, KEY_W, KEY_UP], "moee_dash": [KEY_SHIFT], "moee_restart": [KEY_R], "moee_debug": [KEY_F3], "moee_mute": [KEY_M], "moee_pause": [KEY_ESCAPE]}
	for action in bindings:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			for key in bindings[action]:
				var event := InputEventKey.new()
				event.physical_keycode = key
				InputMap.action_add_event(action, event)

func _process(delta: float) -> void:
	if not paused and not finished:
		elapsed += delta
		note_time = maxf(0, note_time - delta)
		if note_time <= 0:
			notice.text = ""
	if is_instance_valid(player):
		$Backdrop/Background.camera_x = player.camera.get_screen_center_position().x
	_update_hud()

func _on_item_entered(body: Node2D, item: Area2D) -> void:
	if body != player or finished or item.activated:
		return
	match item.kind:
		"rune":
			item.activate()
			runes += 1
			_play(preload("res://moe_editable/audio/power_up.wav"))
			_show_note("Runa recuperada · %d / %d" % [runes, total_runes], 3)
		"echo":
			item.activate()
			echoes += 1
			_play(preload("res://moe_editable/audio/coin.wav"))
		"checkpoint":
			item.activate()
			active_checkpoint = item
			player.spawn = item.global_position
			_play(preload("res://moe_editable/audio/power_up.wav"))
			_show_note("Refugio activado. Conservas tu progreso al caer.", 3)
		"exit":
			if runes == total_runes:
				_finish()
			else:
				_show_note("Faltan %d runas. Vuelve a buscarlas." % (total_runes - runes), 4)

func _on_hurt() -> void:
	deaths += 1
	for guardian in guardians:
		guardian.reset_guardian()
	_play(preload("res://moe_editable/audio/hurt.wav"))
	_show_note("De vuelta al refugio · Las runas y ecos se conservan.", 3)

func _play(stream: AudioStream) -> void:
	if DisplayServer.get_name() != "headless":
		sound.stream = stream
		sound.play()

func _show_note(text: String, duration: float) -> void:
	notice.text = text
	note_time = duration

func _update_hud() -> void:
	stats.text = "RUNAS %d/%d    ECOS %02d/%d    %02d:%02d" % [runes, total_runes, echoes, total_echoes, int(elapsed) / 60, int(elapsed) % 60]

func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("moee_debug"):
		debug_visible = not debug_visible
		$HUD/Debug.visible = debug_visible
		for guardian in guardians:
			guardian.debug_visible = debug_visible
	if event.is_action_pressed("moee_mute"):
		muted = not muted
		music.volume_db = -80 if muted else -23
	if event.is_action_pressed("moee_restart"):
		if finished:
			get_tree().reload_current_scene()
		elif not paused:
			player.take_hit(true)
	if event.is_action_pressed("moee_pause") and not finished:
		paused = not paused
		player.locked = paused
		for guardian in guardians:
			guardian.set_physics_process(not paused)
		_show_note("PAUSA · Esc para continuar" if paused else "Continúa el ascenso.", 999 if paused else 2)

func _finish() -> void:
	finished = true
	player.locked = true
	for guardian in guardians:
		guardian.set_physics_process(false)
	win_panel.show()
	win_label.text = "EL ECO HA DESPERTADO\n\nSantuario restaurado · Nivel completado\n\nTiempo %02d:%02d   Ecos %d/%d   Reintentos %d\n\nR para jugar otra vez" % [int(elapsed) / 60, int(elapsed) % 60, echoes, total_echoes, deaths]
	_play(preload("res://moe_editable/audio/power_up.wav"))
