class_name TopDownShadowAStar
extends CharacterBody2D
## Sombra del Eco (Nivel 2 Top-Down) impulsada por búsqueda de caminos A* (AStarGrid2D).
## Construye su grafo dinámicamente desde las TileMapLayer editables en Godot, respeta pesos
## dinámicos alrededor de Faroles de Alma encendidos, se distrae con Campanas de Eco, pierde
## el rastro directo cuando el jugador se oculta con [E], y usa acecho elástico estilo FNaF.

const PlatformerPlayerScript = preload("res://moe_editable/scripts/player.gd")
const TEX_PANDA_SHADOW_TD := "res://moe_editable/art/panda_shadow_topdown.png"
const TEX_NYANKO_SHADOW_TD := "res://moe_editable/art/nyanko_shadow_topdown.png"

enum State {
	DORMANT,
	HUNT,
	SEARCH_BLIND,
	LURED,
	REPELLED,
	ENRAGED,
}

# Coordenadas de atlas en ObstaclesAndProps que bloquean el paso físico y nodos A*
const SOLID_OBSTACLE_ATLAS := [
	Vector2i(9, 1),   # Base de monolito congelado
	Vector2i(10, 1),  # Base de estatua llorona
	Vector2i(11, 0),  # Bloqueo horizontal de piedra
	Vector2i(11, 1),  # Bloqueo vertical de piedra
	Vector2i(9, 2),   # Escombros con cráneo
	Vector2i(11, 2),  # Púas de hielo afiladas
	Vector2i(10, 7),  # Base de estalagmita oscura
	Vector2i(11, 6),  # Cúmulo de cristales de hielo
]

@export_group("Velocidades y Percepción A*")
@export var stalk_speed: float = 78.0
@export var hunt_speed: float = 104.0
@export var enraged_speed: float = 128.0
@export var repath_interval: float = 0.20
@export var initial_grace_seconds: float = 3.2
@export var stealth_blind_distance: float = 74.0
@export var hideout_blind_distance: float = 36.0
@export var fnaf_relocate_distance: float = 470.0
@export var fnaf_relocate_delay: float = 5.5

var astar: AStarGrid2D = AStarGrid2D.new()
var walkway_layer: TileMapLayer = null
var obstacle_layer: TileMapLayer = null
var target_player: TopDownPlayer = null

var walkable_cells: Array[Vector2i] = []
var walkable_lookup: Dictionary = {}
var current_path: PackedVector2Array = PackedVector2Array()
var path_index: int = 0

var state: State = State.DORMANT
var state_timer: float = 0.0
var repath_timer: float = 0.0
var far_stalk_timer: float = 0.0
var attack_cooldown: float = 0.0

var spawn_position: Vector2 = Vector2.ZERO
var last_known_player_cell: Vector2i = Vector2i.ZERO
var special_target_world: Vector2 = Vector2.ZERO
var repel_origin_world: Vector2 = Vector2.ZERO
var facing_dir: Vector2 = Vector2.DOWN
var use_nyanko_visor: bool = false
var debug_draw_enabled: bool = false

# Diccionario cell(Vector2i) -> { "weight": float, "timer": float, "residual": float }
var dynamic_weighted_cells: Dictionary = {}

@onready var sprite: AnimatedSprite2D = $Sprite
var eyes_glow: Node2D = null
var debug_canvas: Node2D = null


func _ready() -> void:
	spawn_position = global_position
	state = State.DORMANT
	state_timer = initial_grace_seconds
	_setup_unshaded_overlays()
	refresh_skin()


func _setup_unshaded_overlays() -> void:
	var unshaded_mat := CanvasItemMaterial.new()
	unshaded_mat.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED

	eyes_glow = Node2D.new()
	eyes_glow.name = "EyesGlow"
	eyes_glow.material = unshaded_mat
	eyes_glow.z_index = 6
	eyes_glow.draw.connect(_draw_eyes_glow)
	add_child(eyes_glow)

	debug_canvas = Node2D.new()
	debug_canvas.name = "AStarDebugOverlay"
	debug_canvas.top_level = true
	debug_canvas.global_position = Vector2.ZERO
	debug_canvas.material = unshaded_mat
	debug_canvas.z_index = 30
	debug_canvas.visible = debug_draw_enabled
	debug_canvas.draw.connect(_draw_astar_debug)
	add_child(debug_canvas)


func refresh_skin() -> void:
	if not sprite:
		return
	use_nyanko_visor = PlatformerPlayerScript.cat_skin_unlocked
	var path := TEX_NYANKO_SHADOW_TD if use_nyanko_visor else TEX_PANDA_SHADOW_TD
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
		["run_down", 1, 11.5, true],
		["idle_up", 2, 6.5, true],
		["run_up", 3, 11.5, true],
		["run_side", 4, 12.0, true],
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
	sprite.scale = Vector2(1.42, 1.42)
	sprite.modulate = Color(0.86, 0.72, 0.96, 0.92)
	sprite.play("idle_down")


func setup_navigation(walkways: TileMapLayer, obstacles: TileMapLayer, player_ref: TopDownPlayer) -> void:
	walkway_layer = walkways
	obstacle_layer = obstacles
	target_player = player_ref
	rebuild_astar_from_tilemaps()
	if is_instance_valid(target_player):
		last_known_player_cell = world_to_walkable_cell(target_player.global_position)


func rebuild_astar_from_tilemaps() -> void:
	walkable_cells.clear()
	walkable_lookup.clear()
	if not is_instance_valid(walkway_layer):
		return

	var used: Rect2i = walkway_layer.get_used_rect()
	if used.size.x <= 0 or used.size.y <= 0:
		used = Rect2i(0, 0, 96, 66)
	else:
		used = used.grow(2)

	astar = AStarGrid2D.new()
	astar.region = used
	astar.cell_size = Vector2(16.0, 16.0)
	astar.offset = Vector2(8.0, 8.0)
	astar.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	astar.update()

	for y in range(used.position.y, used.end.y):
		for x in range(used.position.x, used.end.x):
			var cell := Vector2i(x, y)
			var has_floor := walkway_layer.get_cell_source_id(cell) != -1
			var has_solid_prop := false
			if has_floor and is_instance_valid(obstacle_layer):
				if obstacle_layer.get_cell_source_id(cell) != -1:
					var obs_atlas := obstacle_layer.get_cell_atlas_coords(cell)
					if SOLID_OBSTACLE_ATLAS.has(obs_atlas):
						has_solid_prop = true

			if has_floor and not has_solid_prop:
				astar.set_point_solid(cell, false)
				walkable_cells.append(cell)
				walkable_lookup[cell] = true
			else:
				astar.set_point_solid(cell, true)

	# Reaplicar pesos dinámicos activos si se reconstruye en caliente
	for cell_key in dynamic_weighted_cells.keys():
		var c: Vector2i = cell_key
		if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
			astar.set_point_weight_scale(c, float(dynamic_weighted_cells[c]["weight"]))


func world_to_cell(world_pos: Vector2) -> Vector2i:
	if is_instance_valid(walkway_layer):
		return walkway_layer.local_to_map(walkway_layer.to_local(world_pos))
	return Vector2i(int(floor(world_pos.x / 16.0)), int(floor(world_pos.y / 16.0)))


func cell_to_world(cell: Vector2i) -> Vector2:
	if is_instance_valid(walkway_layer):
		return walkway_layer.to_global(walkway_layer.map_to_local(cell))
	return Vector2(cell.x * 16.0 + 8.0, cell.y * 16.0 + 8.0)


func world_to_walkable_cell(world_pos: Vector2) -> Vector2i:
	var c := world_to_cell(world_pos)
	if walkable_lookup.has(c):
		return c
	# Buscar celda caminable más cercana en espiral corta
	for radius in range(1, 9):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var cand := Vector2i(c.x + dx, c.y + dy)
				if walkable_lookup.has(cand):
					return cand
	if not walkable_cells.is_empty():
		return walkable_cells[0]
	return c


func compute_path_to_world(goal_world: Vector2) -> PackedVector2Array:
	if walkable_cells.is_empty():
		return PackedVector2Array()
	var start_cell := world_to_walkable_cell(global_position)
	var goal_cell := world_to_walkable_cell(goal_world)
	if not astar.is_in_boundsv(start_cell) or not astar.is_in_boundsv(goal_cell):
		return PackedVector2Array()
	var local_pts: PackedVector2Array = astar.get_point_path(start_cell, goal_cell)
	if not is_instance_valid(walkway_layer):
		return local_pts
	var out := PackedVector2Array()
	out.resize(local_pts.size())
	for i in range(local_pts.size()):
		out[i] = walkway_layer.to_global(local_pts[i])
	return out


func lure_to_position(world_pos: Vector2, duration: float = 5.2) -> void:
	special_target_world = world_pos
	state = State.LURED
	state_timer = duration
	repath_timer = 0.0


func enrage_to_position(world_pos: Vector2, duration: float = 6.0) -> void:
	special_target_world = world_pos
	state = State.ENRAGED
	state_timer = duration
	repath_timer = 0.0


func repel_from_lantern(lantern_pos: Vector2, radius_cells: int = 4, duration: float = 5.0) -> void:
	var center_cell := world_to_cell(lantern_pos)
	for dy in range(-radius_cells, radius_cells + 1):
		for dx in range(-radius_cells, radius_cells + 1):
			if dx * dx + dy * dy > radius_cells * radius_cells:
				continue
			var c := Vector2i(center_cell.x + dx, center_cell.y + dy)
			if walkable_lookup.has(c) and astar.is_in_boundsv(c):
				var w := 28.0 if (dx * dx + dy * dy <= 4) else 14.0
				astar.set_point_weight_scale(c, w)
				dynamic_weighted_cells[c] = {
					"weight": w,
					"timer": duration,
					"residual": 4.2,
				}

	if global_position.distance_to(lantern_pos) <= 170.0:
		repel_origin_world = lantern_pos
		state = State.REPELLED
		state_timer = 1.25
	repath_timer = 0.0


func reset_after_respawn(safe_min_dist: float = 320.0) -> void:
	velocity = Vector2.ZERO
	current_path = PackedVector2Array()
	path_index = 0
	far_stalk_timer = 0.0
	state = State.DORMANT
	state_timer = 2.6

	if not is_instance_valid(target_player) or walkable_cells.is_empty():
		global_position = spawn_position
		return

	if spawn_position.distance_to(target_player.global_position) >= safe_min_dist:
		global_position = spawn_position
		return

	# Elegir una celda caminable alejada del checkpoint del jugador
	var best_cell := walkable_cells[0]
	var best_dist := -1.0
	for c in walkable_cells:
		var wp := cell_to_world(c)
		var d := wp.distance_to(target_player.global_position)
		if d > best_dist and d <= 520.0:
			best_dist = d
			best_cell = c
	global_position = cell_to_world(best_cell)


func set_debug_draw(enabled: bool) -> void:
	debug_draw_enabled = enabled
	if debug_canvas:
		debug_canvas.visible = enabled
		debug_canvas.queue_redraw()


func get_debug_summary() -> String:
	var st_names := ["DORMANT", "HUNT (A*)", "SEARCH_BLIND", "LURED (Campana)", "REPELLED (Farol)", "ENRAGED (Rencor)"]
	var sname: String = st_names[int(state)] if int(state) < st_names.size() else "HUNT"
	var dist := int(global_position.distance_to(target_player.global_position)) if is_instance_valid(target_player) else -1
	return "IA Sombra A*: %s · Nodos ruta: %d · Dist: %d px · Celdas pesadas: %d" % [
		sname, current_path.size(), dist, dynamic_weighted_cells.size()
	]


func _physics_process(delta: float) -> void:
	_update_dynamic_weights(delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)

	if eyes_glow:
		eyes_glow.queue_redraw()
	if debug_canvas and debug_draw_enabled:
		debug_canvas.queue_redraw()

	if not is_instance_valid(target_player) or target_player.locked:
		velocity = Vector2.ZERO
		_update_animation(Vector2.ZERO, false)
		return

	var dist_to_player := global_position.distance_to(target_player.global_position)

	# Contacto directo con el jugador
	if dist_to_player <= 15.5 and attack_cooldown <= 0.0 and state != State.DORMANT and state != State.REPELLED:
		attack_cooldown = 1.1
		target_player.receive_shadow_attack(global_position)
		return

	# Máquina de estados + transiciones de percepción
	state_timer = maxf(0.0, state_timer - delta)
	match state:
		State.DORMANT:
			velocity = velocity.move_toward(Vector2.ZERO, 300.0 * delta)
			if state_timer <= 0.0:
				state = State.HUNT
				repath_timer = 0.0
			_update_animation(Vector2.ZERO, false)
			return

		State.REPELLED:
			var away := (global_position - repel_origin_world).normalized()
			if away == Vector2.ZERO:
				away = Vector2.DOWN
			velocity = away * 118.0
			move_and_slide()
			if state_timer <= 0.0:
				state = State.HUNT
				repath_timer = 0.0
			_update_animation(away, true)
			return

		State.LURED:
			if state_timer <= 0.0:
				state = State.HUNT
				repath_timer = 0.0

		State.ENRAGED:
			if state_timer <= 0.0:
				state = State.HUNT
				repath_timer = 0.0

		State.HUNT:
			if _is_player_hidden_from_shadow(dist_to_player):
				state = State.SEARCH_BLIND
				repath_timer = 0.0
			else:
				last_known_player_cell = world_to_walkable_cell(target_player.global_position)

		State.SEARCH_BLIND:
			if not _is_player_hidden_from_shadow(dist_to_player) or target_player.is_making_noise():
				state = State.HUNT
				last_known_player_cell = world_to_walkable_cell(target_player.global_position)
				repath_timer = 0.0

	# Acecho elástico estilo FNaF en mapas grandes: si queda demasiado atrás, se reubica en las sombras
	if (state == State.HUNT or state == State.SEARCH_BLIND) and dist_to_player > fnaf_relocate_distance:
		far_stalk_timer += delta
		if far_stalk_timer >= fnaf_relocate_delay:
			far_stalk_timer = 0.0
			_relocate_stalk_near_player()
	else:
		far_stalk_timer = maxf(0.0, far_stalk_timer - delta * 0.5)

	# Recalcular ruta óptima A* periódicamente
	repath_timer -= delta
	if repath_timer <= 0.0:
		repath_timer = repath_interval
		_recompute_astar_route()

	_follow_current_path(delta, dist_to_player)


func _is_player_hidden_from_shadow(dist_to_player: float) -> bool:
	if not is_instance_valid(target_player) or not target_player.is_stealth_hidden:
		return false
	var blind_limit := hideout_blind_distance if target_player.near_hideout_count > 0 else stealth_blind_distance
	return dist_to_player > blind_limit


func _recompute_astar_route() -> void:
	var goal_world := global_position
	match state:
		State.LURED:
			goal_world = special_target_world
		State.ENRAGED:
			if global_position.distance_to(special_target_world) > 48.0 and state_timer > 3.5:
				goal_world = special_target_world
			else:
				goal_world = target_player.global_position
		State.SEARCH_BLIND:
			var lk_world := cell_to_world(last_known_player_cell)
			if global_position.distance_to(lk_world) <= 22.0:
				last_known_player_cell = _pick_nearby_prowl_cell(last_known_player_cell)
				lk_world = cell_to_world(last_known_player_cell)
			goal_world = lk_world
		_:
			last_known_player_cell = world_to_walkable_cell(target_player.global_position)
			goal_world = target_player.global_position

	current_path = compute_path_to_world(goal_world)
	path_index = 1 if current_path.size() > 1 else 0


func _pick_nearby_prowl_cell(origin: Vector2i) -> Vector2i:
	if walkable_cells.is_empty():
		return origin
	var candidates: Array[Vector2i] = []
	for dy in range(-11, 12):
		for dx in range(-11, 12):
			var d2 := dx * dx + dy * dy
			if d2 < 25 or d2 > 121:
				continue
			var c := Vector2i(origin.x + dx, origin.y + dy)
			if walkable_lookup.has(c):
				candidates.append(c)
	if candidates.is_empty():
		return walkable_cells[randi() % walkable_cells.size()]
	return candidates[randi() % candidates.size()]


func _relocate_stalk_near_player() -> void:
	if not is_instance_valid(target_player) or walkable_cells.is_empty():
		return
	var candidates: Array[Vector2i] = []
	for c in walkable_cells:
		if dynamic_weighted_cells.has(c):
			continue
		var wp := cell_to_world(c)
		var d := wp.distance_to(target_player.global_position)
		# Fuera del radio de visión directa, pero en una intersección cercana (210..275 px)
		if d >= 210.0 and d <= 275.0:
			candidates.append(c)
	if candidates.is_empty():
		return
	var chosen := candidates[randi() % candidates.size()]
	global_position = cell_to_world(chosen)
	last_known_player_cell = world_to_walkable_cell(target_player.global_position)
	repath_timer = 0.0
	target_player.trigger_stalk_flicker()


func _follow_current_path(delta: float, dist_to_player: float) -> void:
	var spd := stalk_speed
	if state == State.ENRAGED:
		spd = enraged_speed
	elif state == State.LURED:
		spd = hunt_speed * 1.06
	elif state == State.HUNT:
		if target_player.is_making_noise() or dist_to_player < 165.0:
			spd = hunt_speed
		else:
			spd = stalk_speed

	var move_dir := Vector2.ZERO
	if not current_path.is_empty() and path_index < current_path.size():
		var wp := current_path[path_index]
		if global_position.distance_to(wp) <= 6.5 and path_index + 1 < current_path.size():
			path_index += 1
			wp = current_path[path_index]
		var diff := wp - global_position
		if diff.length() > 2.0:
			move_dir = diff.normalized()
	elif state == State.HUNT and dist_to_player < 64.0:
		move_dir = (target_player.global_position - global_position).normalized()

	velocity = velocity.move_toward(move_dir * spd, 720.0 * delta)
	move_and_slide()

	if move_dir.length() > 0.08:
		facing_dir = move_dir
	_update_animation(move_dir, spd >= hunt_speed)


func _update_dynamic_weights(delta: float) -> void:
	if dynamic_weighted_cells.is_empty():
		return
	var finished_keys: Array[Vector2i] = []
	for cell_key in dynamic_weighted_cells.keys():
		var c: Vector2i = cell_key
		var info: Dictionary = dynamic_weighted_cells[c]
		var t_left: float = float(info["timer"]) - delta
		if t_left <= 0.0:
			var res: float = float(info["residual"])
			if astar.is_in_boundsv(c) and not astar.is_point_solid(c):
				astar.set_point_weight_scale(c, res)
			finished_keys.append(c)
		else:
			info["timer"] = t_left
	for k in finished_keys:
		dynamic_weighted_cells.erase(k)


func _update_animation(move_dir: Vector2, fast: bool) -> void:
	if not sprite or not sprite.sprite_frames:
		return
	sprite.speed_scale = 1.35 if fast else 0.95
	var moving := move_dir.length() > 0.08

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


func _draw_eyes_glow() -> void:
	if state == State.DORMANT or not is_instance_valid(target_player):
		return
	var dist := global_position.distance_to(target_player.global_position)
	if dist > 275.0:
		return
	var alpha := clampf(1.0 - (dist - 70.0) / 205.0, 0.14, 0.95)
	if state == State.ENRAGED:
		alpha = minf(1.0, alpha + 0.25)
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.012)
	var eye_col := Color(1.0, 0.22, 0.40, alpha * pulse)
	var halo_col := Color(0.95, 0.12, 0.34, alpha * 0.28 * pulse)

	var y_off := -7.0 if facing_dir.y <= 0.2 else -5.0
	if use_nyanko_visor:
		# Visor carmesí rasgado del Shadow Nyanko en la penumbra
		eyes_glow.draw_circle(Vector2(0, y_off), 6.0, halo_col)
		eyes_glow.draw_rect(Rect2(-4.5, y_off - 1.2, 9.0, 2.2), eye_col, true)
	else:
		# Dos pupilas carmesí brillantes del Eco del Panda en la niebla
		eyes_glow.draw_circle(Vector2(-3.2, y_off), 3.4, halo_col)
		eyes_glow.draw_circle(Vector2(3.2, y_off), 3.4, halo_col)
		eyes_glow.draw_circle(Vector2(-3.2, y_off), 1.45, eye_col)
		eyes_glow.draw_circle(Vector2(3.2, y_off), 1.45, eye_col)


func _draw_astar_debug() -> void:
	if not debug_draw_enabled:
		return
	# Dibujar celdas con alto peso dinámico alrededor de faroles
	for cell_key in dynamic_weighted_cells.keys():
		var c: Vector2i = cell_key
		var wp := cell_to_world(c)
		debug_canvas.draw_rect(Rect2(wp - Vector2(7, 7), Vector2(14, 14)), Color(1.0, 0.78, 0.25, 0.26), true)

	# Dibujar polilínea de la ruta óptima A* actual
	if current_path.size() >= 2:
		var line_col := Color(1.0, 0.28, 0.46, 0.88) if state != State.LURED else Color(0.38, 0.92, 1.0, 0.88)
		debug_canvas.draw_polyline(current_path, line_col, 2.0)
		for i in range(path_index, current_path.size()):
			debug_canvas.draw_circle(current_path[i], 2.2, line_col)
		var goal := current_path[current_path.size() - 1]
		debug_canvas.draw_arc(goal, 7.0, 0.0, TAU, 20, Color(1.0, 0.92, 0.35, 0.95), 1.6)
