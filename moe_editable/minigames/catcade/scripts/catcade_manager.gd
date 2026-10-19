class_name CatcadeManager
extends Node2D

signal minigame_closed(final_score: int)
signal minigame_completed(final_score: int)
signal exited_to_game

const LEVEL_PATHS: Array[String] = [
	"res://moe_editable/minigames/catcade/scenes/levels/level_01.tscn",
	"res://moe_editable/minigames/catcade/scenes/levels/level_02.tscn",
	"res://moe_editable/minigames/catcade/scenes/levels/level_03.tscn"
]

const CAT_SCENE: PackedScene = preload("res://moe_editable/minigames/catcade/prefabs/cat_projectile.tscn")

@onready var level_container: Node2D = $LevelContainer
@onready var projectiles_container: Node2D = $ProjectilesContainer
@onready var slingshot: Slingshot = $Slingshot
@onready var camera: Camera2D = $Camera2D

@onready var title_panel: Control = $UI/TitlePanel
@onready var hud_panel: Control = $UI/HUD
@onready var result_panel: Control = $UI/ResultPanel

@onready var lbl_level: Label = $UI/HUD/TopBar/LblLevel
@onready var lbl_score: Label = $UI/HUD/TopBar/LblScore
@onready var lbl_cats: Label = $UI/HUD/TopBar/LblCats
@onready var lbl_enemies: Label = $UI/HUD/TopBar/LblEnemies
@onready var lbl_hint: Label = $UI/HUD/BottomHint

@onready var lbl_result_title: Label = $UI/ResultPanel/VBox/LblResultTitle
@onready var lbl_result_score: Label = $UI/ResultPanel/VBox/LblResultScore
@onready var lbl_result_stars: Label = $UI/ResultPanel/VBox/LblResultStars
@onready var btn_next: Button = $UI/ResultPanel/VBox/HBox/BtnNext
@onready var btn_retry_result: Button = $UI/ResultPanel/VBox/HBox/BtnRetryResult
@onready var btn_exit_result: Button = $UI/ResultPanel/VBox/HBox/BtnExitResult

@onready var btn_start: Button = $UI/TitlePanel/VBox/BtnStart
@onready var btn_exit_title: Button = $UI/TitlePanel/VBox/BtnExitTitle
@onready var btn_retry_hud: Button = $UI/HUD/TopBar/BtnRetry
@onready var btn_exit_hud: Button = $UI/HUD/TopBar/BtnExit

@onready var sfx_win: AudioStreamPlayer = $AudioWin
@onready var sfx_lose: AudioStreamPlayer = $AudioLose
@onready var bgm_player: AudioStreamPlayer = $AudioBGM

var current_level_idx: int = 0
var current_score: int = 0
var total_score: int = 0
var remaining_cats: Array[int] = []
var waiting_cat_sprites: Array[Sprite2D] = []
var active_enemies: int = 0
var level_ended: bool = false
var active_cat: CatProjectile = null
var camera_base_pos: Vector2 = Vector2(320, 180)
var shake_strength: float = 0.0
var is_closing: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if slingshot:
		slingshot.cat_launched.connect(_on_cat_launched)

	if btn_start:
		btn_start.pressed.connect(_on_start_pressed)
	if btn_exit_title:
		btn_exit_title.pressed.connect(_on_exit_pressed)
	if btn_retry_hud:
		btn_retry_hud.pressed.connect(restart_level)
	if btn_exit_hud:
		btn_exit_hud.pressed.connect(_on_exit_pressed)
	if btn_next:
		btn_next.pressed.connect(_on_next_level_pressed)
	if btn_retry_result:
		btn_retry_result.pressed.connect(restart_level)
	if btn_exit_result:
		btn_exit_result.pressed.connect(_on_exit_pressed)

	# Start directly in Level 1 so the player immediately plays the full-screen 3-level Battle Cats arcade
	if title_panel:
		title_panel.visible = false
	if hud_panel:
		hud_panel.visible = true
	if result_panel:
		result_panel.visible = false
	load_level(0)

func show_title_screen() -> void:
	if title_panel:
		title_panel.visible = true
	if hud_panel:
		hud_panel.visible = false
	if result_panel:
		result_panel.visible = false
	if btn_start:
		btn_start.grab_focus()

func _on_start_pressed() -> void:
	if title_panel:
		title_panel.visible = false
	if hud_panel:
		hud_panel.visible = true
	total_score = 0
	load_level(0)

func load_level(idx: int) -> void:
	current_level_idx = clampi(idx, 0, LEVEL_PATHS.size() - 1)
	level_ended = false
	current_score = 0
	active_enemies = 0
	active_cat = null

	if result_panel:
		result_panel.visible = false
	if hud_panel:
		hud_panel.visible = true

	for child in level_container.get_children():
		child.queue_free()
	for child in projectiles_container.get_children():
		child.queue_free()
	_clear_waiting_cat_Visuals()

	var level_scene: PackedScene = load(LEVEL_PATHS[current_level_idx])
	var level_inst: Node2D = level_scene.instantiate()
	level_container.add_child(level_inst)

	# 4 Basic Cats per level to match the reference screenshots (1 on slingshot + 3 waiting on grass)
	remaining_cats = [
		CatProjectile.CatType.NORMAL,
		CatProjectile.CatType.NORMAL,
		CatProjectile.CatType.NORMAL,
		CatProjectile.CatType.NORMAL
	]

	for node in level_inst.find_children("*", "", true, false):
		if node is AnimalEnemy:
			active_enemies += 1
			node.enemy_defeated.connect(_on_enemy_defeated)
		elif node is DestructibleBlock:
			node.destroyed.connect(_on_block_destroyed)

	_update_hud()
	_spawn_next_cat()

func restart_level() -> void:
	load_level(current_level_idx)

func _clear_waiting_cat_Visuals() -> void:
	for s in waiting_cat_sprites:
		if is_instance_valid(s):
			s.queue_free()
	waiting_cat_sprites.clear()

func _refresh_waiting_cat_visuals() -> void:
	_clear_waiting_cat_Visuals()
	var tex: Texture2D = load("res://moe_editable/minigames/catcade/assets/cats/cat_normal_idle.png")
	if not tex:
		return
	for i in range(remaining_cats.size()):
		var sp := Sprite2D.new()
		sp.texture = tex
		sp.scale = Vector2(0.76, 0.76)
		sp.position = Vector2(72.0 - float(i) * 24.0, 266.0)
		sp.z_index = 4
		projectiles_container.add_child(sp)
		waiting_cat_sprites.append(sp)

func _spawn_next_cat() -> void:
	if level_ended:
		return
	if remaining_cats.is_empty():
		_evaluate_turn_end()
		return

	var next_type: int = remaining_cats.pop_front()
	_refresh_waiting_cat_visuals()

	var cat: CatProjectile = CAT_SCENE.instantiate()
	cat.cat_type = next_type as CatProjectile.CatType
	projectiles_container.add_child(cat)
	active_cat = cat

	cat.cat_impacted.connect(_on_cat_impacted)
	cat.cat_stopped.connect(_on_cat_stopped)
	cat.skill_activated.connect(_on_cat_skill_activated)

	slingshot.load_cat(cat)
	_update_hud()
	if lbl_hint:
		lbl_hint.text = "Arrastra al Gato y suelta para disparar | Click en vuelo: Mordisco Turbo | [R] Reiniciar | [Q] Salir"

func _on_cat_launched(_cat: CatProjectile, _vel: Vector2) -> void:
	_update_hud()

func _on_cat_skill_activated(_cat: CatProjectile) -> void:
	trigger_shake(3.0)

func _on_cat_impacted(_cat: CatProjectile, _body: Node, speed: float) -> void:
	if speed > 140.0:
		trigger_shake(clampf(speed * 0.015, 2.0, 6.0))

func _on_cat_stopped(_cat: CatProjectile) -> void:
	if level_ended:
		return
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree() or level_ended:
		return
	if active_enemies <= 0:
		_trigger_victory()
	elif remaining_cats.size() > 0:
		_spawn_next_cat()
	else:
		_trigger_defeat()

func _on_enemy_defeated(_enemy: AnimalEnemy, points: int) -> void:
	current_score += points
	active_enemies = maxi(0, active_enemies - 1)
	trigger_shake(4.5)
	_update_hud()

	if active_enemies <= 0 and not level_ended:
		level_ended = true
		await get_tree().create_timer(0.85).timeout
		if is_inside_tree():
			_trigger_victory()

func _on_block_destroyed(points: int) -> void:
	current_score += points
	_update_hud()

func _evaluate_turn_end() -> void:
	if active_enemies <= 0:
		_trigger_victory()
	else:
		_trigger_defeat()

func _trigger_victory() -> void:
	level_ended = true
	var bonus: int = remaining_cats.size() * 1000
	current_score += bonus
	total_score += current_score
	_update_hud()

	if active_cat and is_instance_valid(active_cat):
		active_cat.set_state(CatProjectile.State.CELEBRATING)

	if sfx_win:
		sfx_win.play()

	var has_next: bool = (current_level_idx + 1) < LEVEL_PATHS.size()

	# If all 3 levels are completed, unlock the reward skin and show final completion celebration!
	if not has_next:
		if result_panel:
			result_panel.visible = true
		if lbl_result_title:
			lbl_result_title.text = "¡CATCADE COMPLETADO! ¡SKIN NYANKO RANGER DESBLOQUEADA!"
		if lbl_result_score:
			lbl_result_score.text = "Puntaje Total: %d (Bonus Gatos: +%d)" % [total_score, bonus]
		if lbl_result_stars:
			lbl_result_stars.text = "★ ★ ★  ¡RECOMPENSA EQUIPADA EN EL JUEGO PRINCIPAL!"
		if btn_next:
			btn_next.visible = false
		if btn_exit_result:
			btn_exit_result.text = "Volver con Nueva Skin [Q]"
			btn_exit_result.grab_focus()
		minigame_completed.emit(total_score)
		return

	if result_panel:
		result_panel.visible = true
	if lbl_result_title:
		lbl_result_title.text = "¡NIVEL %d SUPERADO!" % (current_level_idx + 1)
	if lbl_result_score:
		lbl_result_score.text = "Puntos: %d (Bonus gatos: +%d)" % [current_score, bonus]

	var stars: String = "★ ☆ ☆"
	if remaining_cats.size() >= 2 or current_score >= 3500:
		stars = "★ ★ ★"
	elif remaining_cats.size() >= 1 or current_score >= 2200:
		stars = "★ ★ ☆"
	if lbl_result_stars:
		lbl_result_stars.text = "Calificación: " + stars

	if btn_next:
		btn_next.visible = true
		btn_next.grab_focus()

func _trigger_defeat() -> void:
	if active_enemies <= 0:
		_trigger_victory()
		return
	level_ended = true
	if sfx_lose:
		sfx_lose.play()
	if result_panel:
		result_panel.visible = true
	if lbl_result_title:
		lbl_result_title.text = "DERROTA FELINA..."
	if lbl_result_score:
		lbl_result_score.text = "Puntos obtenidos: %d" % current_score
	if lbl_result_stars:
		lbl_result_stars.text = "¡Aún quedan enemigos en pie!"
	if btn_next:
		btn_next.visible = false
	if btn_retry_result:
		btn_retry_result.grab_focus()

func _on_next_level_pressed() -> void:
	load_level(current_level_idx + 1)

func _on_exit_pressed() -> void:
	if is_closing:
		return
	is_closing = true
	minigame_closed.emit(total_score + current_score)
	exited_to_game.emit()

func _update_hud() -> void:
	if lbl_level:
		lbl_level.text = "NIVEL %d/%d" % [current_level_idx + 1, LEVEL_PATHS.size()]
	if lbl_score:
		lbl_score.text = "SCORE: %05d" % (total_score + current_score)
	if lbl_cats:
		var in_play: int = 1 if (active_cat and is_instance_valid(active_cat) and active_cat.current_state in [CatProjectile.State.WAITING, CatProjectile.State.AIMING]) else 0
		lbl_cats.text = "GATOS: %d" % (remaining_cats.size() + in_play)
	if lbl_enemies:
		lbl_enemies.text = "ENEMIGOS: %d" % active_enemies

func trigger_shake(amount: float) -> void:
	shake_strength = maxf(shake_strength, amount)

func _process(delta: float) -> void:
	if shake_strength > 0.0:
		shake_strength = lerpf(shake_strength, 0.0, 10.0 * delta)
		position = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		if shake_strength < 0.2:
			shake_strength = 0.0
			position = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode if event.keycode != 0 else event.physical_keycode
		if k == KEY_Q or k == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_on_exit_pressed()
		elif k == KEY_R and hud_panel and hud_panel.visible:
			get_viewport().set_input_as_handled()
			restart_level()
		elif (k == KEY_ENTER or k == KEY_SPACE) and result_panel and result_panel.visible:
			if btn_next and btn_next.visible:
				get_viewport().set_input_as_handled()
				_on_next_level_pressed()
			elif not btn_next.visible and active_enemies <= 0:
				get_viewport().set_input_as_handled()
				_on_exit_pressed()
