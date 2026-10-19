class_name ArcadeMachine
extends Area2D

## ArcadeMachine: Punto de interacción del Easter Egg en el nivel principal.
## Despliega el minijuego CAT-A-PULT a pantalla completa sin alterar el estado del nivel.

signal minigame_opened
signal minigame_closed

const CatcadeScene = preload("res://moe_editable/minigames/catcade/catcade.tscn")

@onready var prompt: Label = $PromptLabel
@onready var cabinet_sprite: Sprite2D = $Sprite2D
@onready var glow_sprite: PointLight2D = get_node_or_null("PointLight2D")

var is_player_nearby: bool = false
var player_ref: CharacterBody2D = null
var active_catcade_instance: Node = null
var was_music_playing: bool = false
var original_music_volume: float = -23.0
var prev_content_scale_size: Vector2i = Vector2i(800, 450)

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detecta al jugador (Layer 2)
	monitoring = true
	
	if prompt:
		prompt.modulate.a = 0.0
		prompt.text = "[E] JUGAR CAT-A-PULT"
		
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if is_player_nearby and prompt and prompt.modulate.a > 0.0:
		var time = Time.get_ticks_msec() / 1000.0
		prompt.position.y = -68.0 + sin(time * 4.0) * 3.0

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D and body.name == "Player":
		is_player_nearby = true
		player_ref = body
		_show_prompt(true)

func _on_body_exited(body: Node2D) -> void:
	if body == player_ref:
		is_player_nearby = false
		player_ref = null
		_show_prompt(false)

func _show_prompt(show_it: bool) -> void:
	if not prompt:
		return
	var tw = create_tween()
	tw.tween_property(prompt, "modulate:a", 1.0 if show_it else 0.0, 0.2)

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_player_nearby or active_catcade_instance != null:
		return
		
	if event is InputEventKey and event.is_pressed() and not event.is_echo():
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if k == KEY_E:
			get_viewport().set_input_as_handled()
			open_catcade()

func open_catcade() -> void:
	if active_catcade_instance != null or not is_instance_valid(player_ref):
		return
		
	# 1. Bloquear movimiento del jugador y pausar enemigos del nivel principal
	player_ref.locked = true
	player_ref.velocity = Vector2.ZERO
	
	var root = get_tree().current_scene
	if root:
		if "paused" in root:
			root.paused = true
		if "guardians" in root:
			for g in root.guardians:
				if is_instance_valid(g):
					g.set_physics_process(false)
		if "shadow" in root and is_instance_valid(root.shadow):
			root.shadow.set_physics_process(false)
		var main_hud = root.get_node_or_null("HUD")
		if main_hud:
			main_hud.visible = false
	
	# 2. Ajustar resolución de escala a 640x360 para que el minijuego ocupe toda la pantalla
	prev_content_scale_size = get_window().content_scale_size
	get_window().content_scale_size = Vector2i(640, 360)
	
	# 3. Silenciar música del nivel principal mientras dura el arcade
	var music_node: AudioStreamPlayer = root.get_node_or_null("Audio/Music") if root else null
	if music_node:
		was_music_playing = music_node.playing
		original_music_volume = music_node.volume_db
		music_node.volume_db = -80.0
	
	# 4. Instanciar Catcade a pantalla completa
	var catcade = CatcadeScene.instantiate()
	active_catcade_instance = catcade
	
	_show_prompt(false)
	
	catcade.exited_to_game.connect(_on_catcade_exited)
	if catcade.has_signal("minigame_completed"):
		catcade.minigame_completed.connect(_on_catcade_completed)
	
	var overlay = CanvasLayer.new()
	overlay.name = "CatcadeOverlay"
	overlay.layer = 100
	overlay.add_child(catcade)
	root.add_child(overlay)
	
	minigame_opened.emit()

func _on_catcade_completed(_final_score: int) -> void:
	if is_instance_valid(player_ref) and player_ref.has_method("apply_cat_skin"):
		player_ref.apply_cat_skin()
	if prompt:
		prompt.text = "[E] CAT-A-PULT (SKIN EQUIPADA)"

func _on_catcade_exited() -> void:
	if not active_catcade_instance:
		return
		
	var root = get_tree().current_scene
	var overlay = root.get_node_or_null("CatcadeOverlay") if root else null
	if overlay:
		overlay.queue_free()
	active_catcade_instance = null
	
	# Restaurar resolución de escala del nivel principal
	get_window().content_scale_size = prev_content_scale_size
	
	# Restaurar música y enemigos del nivel principal
	if root:
		var music_node: AudioStreamPlayer = root.get_node_or_null("Audio/Music")
		if music_node and was_music_playing:
			var is_muted: bool = root.muted if "muted" in root else false
			music_node.volume_db = -80.0 if is_muted else original_music_volume
		if "paused" in root:
			root.paused = false
		if "guardians" in root:
			for g in root.guardians:
				if is_instance_valid(g):
					g.set_physics_process(true)
		if "shadow" in root and is_instance_valid(root.shadow):
			root.shadow.set_physics_process(true)
		var main_hud = root.get_node_or_null("HUD")
		if main_hud:
			main_hud.visible = true
		
	# Restaurar control del jugador
	if is_instance_valid(player_ref):
		player_ref.locked = false
		if is_player_nearby:
			_show_prompt(true)
			
	minigame_closed.emit()
