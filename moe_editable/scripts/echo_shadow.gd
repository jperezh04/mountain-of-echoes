extends Area2D
class_name EchoShadow

## Entidad Sombra Echo [ENM-02]
## Imita la trayectoria del jugador con un desfase temporal.
## Sirve como obstáculo dinámico y eco de acciones pasadas.

signal awakened
signal vanished

@export var delay: float = 2.2 ## Retardo en segundos respecto a la posición del jugador
@export var active: bool = false
@export var trigger_x: float = 1750.0 ## Posición X a partir de la cual la sombra despierta
@export var deactivate_x: float = 3850.0 ## Posición X donde la sombra se desvanece (cerca de la meta)

var player: CharacterBody2D
var history: Array[Dictionary] = []
var clock: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2 # Detecta al jugador (Layer 2)
	monitoring = true
	body_entered.connect(_on_body_entered)
	visible = false

func set_target(target_player: CharacterBody2D) -> void:
	player = target_player

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.locked:
		return

	clock += delta

	# Activación según posición del jugador en la montaña
	if not active:
		if player.global_position.x >= trigger_x and player.global_position.x < deactivate_x:
			activate_shadow()
		else:
			return
	else:
		if player.global_position.x >= deactivate_x:
			deactivate_shadow()
			return

	# Registrar posición del jugador
	var current_anim := "idle"
	var current_frame := 0
	if player.sprite and player.sprite.sprite_frames:
		current_anim = player.sprite.animation
		current_frame = player.sprite.frame

	history.append({
		"time": clock,
		"pos": player.global_position,
		"facing": player.facing,
		"anim": current_anim,
		"frame": current_frame
	})

	# Buscar posición en el tiempo pasado (clock - delay)
	var target_time := clock - delay
	if target_time < 0:
		return

	# Descartar registros viejos
	while history.size() > 1 and history[1]["time"] <= target_time:
		history.pop_front()

	if history.size() > 0:
		var snapshot: Dictionary = history[0]
		global_position = snapshot["pos"]
		visible = true
		
		if sprite:
			sprite.flip_h = snapshot["facing"] < 0
			if sprite.sprite_frames and sprite.sprite_frames.has_animation(snapshot["anim"]):
				sprite.play(snapshot["anim"])
				sprite.frame = snapshot["frame"]
				sprite.pause()

func activate_shadow() -> void:
	if active:
		return
	active = true
	visible = true
	history.clear()
	clock = 0.0
	awakened.emit()

func deactivate_shadow() -> void:
	if not active:
		return
	active = false
	visible = false
	history.clear()
	vanished.emit()

func reset_shadow() -> void:
	active = false
	visible = false
	history.clear()
	clock = 0.0

func _on_body_entered(body: Node2D) -> void:
	if not active:
		return
	if body == player:
		# Si el jugador no está en dash, recibe golpe
		if is_instance_valid(player) and player.dash_time <= 0 and player.invulnerable <= 0:
			player.take_hit()
			reset_shadow()
