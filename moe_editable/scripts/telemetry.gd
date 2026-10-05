class_name TelemetryManager
extends RefCounted

## Telemetry & Mountain Adaptive System
## Aligned with issues [IA-00], [UI-01], [NAR-01]

signal adaptation_triggered(state_name: String, message: String, gravity_scale: float)

const WINDOW_DURATION := 10.0 # Ventana de observación en segundos
const GRAVITY_DEFAULT := 1.0
const GRAVITY_HIGH := 1.15   # +15% de gravedad ante juego apresurado
const GRAVITY_LOW := 0.88    # -12% de gravedad para ayudar en dificultad

# Contadores acumulados
var total_dashes := 0
var total_jumps := 0
var total_deaths := 0
var total_stomps := 0
var total_distance := 0.0

# Historial en ventana de tiempo deslizante
var dash_history: Array[float] = []
var jump_history: Array[float] = []
var death_history: Array[float] = []

# Métricas de estado
var time_in_air := 0.0
var time_on_ground := 0.0
var last_position := Vector2.ZERO
var current_speed := 0.0

# Estados de adaptación
var current_profile := "EQUILIBRADO"
var current_adaptation := "CALMA"
var gravity_multiplier := 1.0
var last_adaptation_time := -10.0
var cooldown_between_adaptations := 6.0

func record_dash(timestamp: float) -> void:
	total_dashes += 1
	dash_history.append(timestamp)

func record_jump(timestamp: float) -> void:
	total_jumps += 1
	jump_history.append(timestamp)

func record_death(timestamp: float) -> void:
	total_deaths += 1
	death_history.append(timestamp)

func record_stomp() -> void:
	total_stomps += 1

func update(delta: float, current_time: float, player: CharacterBody2D) -> void:
	if not is_instance_valid(player):
		return

	# Limpiar eventos fuera de la ventana
	var window_threshold = current_time - WINDOW_DURATION
	while not dash_history.is_empty() and dash_history[0] < window_threshold:
		dash_history.pop_front()
	while not jump_history.is_empty() and jump_history[0] < window_threshold:
		jump_history.pop_front()
	while not death_history.is_empty() and death_history[0] < window_threshold:
		death_history.pop_front()

	# Medir tiempo en aire vs suelo
	if player.is_on_floor():
		time_on_ground += delta
	else:
		time_in_air += delta

	# Medir distancia recorrida y velocidad
	if last_position != Vector2.ZERO:
		var frame_dist = player.global_position.distance_to(last_position)
		if frame_dist < 500: # Ignorar teletransporte / respawn
			total_distance += frame_dist
			current_speed = frame_dist / maxf(delta, 0.001)
	last_position = player.global_position

	_evaluate_adaptation(current_time)

func _evaluate_adaptation(current_time: float) -> void:
	if current_time - last_adaptation_time < cooldown_between_adaptations:
		return

	var recent_dashes := dash_history.size()
	var recent_deaths := death_history.size()
	
	var new_profile := "EQUILIBRADO"
	var new_adaptation := "CALMA"
	var new_scale := GRAVITY_DEFAULT
	var message := ""

	# Regla 1: Dificultad / Muerte frecuente
	if recent_deaths >= 2:
		new_profile = "EN DIFICULTAD"
		new_adaptation = "ALIENTO SERENO"
		new_scale = GRAVITY_LOW
		message = "❄️ Un aliento sereno desciende: la montaña aligera tus saltos."
	# Regla 2: Agresivo / Uso intensivo de dash
	elif recent_dashes >= 3:
		new_profile = "ÁGIL / IMPETUOSO"
		new_adaptation = "VIENTO GÉLIDO"
		new_scale = GRAVITY_HIGH
		message = "🌬️ El viento de la cumbre arrecia: la montaña se vuelve pesada."
	# Regla 3: Explorador / Calma
	else:
		new_profile = "EXPLORADOR"
		new_adaptation = "CALMA"
		new_scale = GRAVITY_DEFAULT
		if current_adaptation != "CALMA":
			message = "⛰️ La montaña recupera la calma y te observa."

	current_profile = new_profile

	if new_adaptation != current_adaptation:
		current_adaptation = new_adaptation
		gravity_multiplier = new_scale
		last_adaptation_time = current_time
		adaptation_triggered.emit(new_adaptation, message, new_scale)

## Retorna vector normalizado para entrenamiento/evaluación futura de KNN
func get_knn_feature_vector() -> Array[float]:
	var total_time = time_in_air + time_on_ground
	var air_ratio = time_in_air / maxf(total_time, 1.0)
	var dash_rate = float(dash_history.size()) / WINDOW_DURATION
	var jump_rate = float(jump_history.size()) / WINDOW_DURATION
	var death_rate = float(death_history.size()) / WINDOW_DURATION
	return [dash_rate, jump_rate, air_ratio, current_speed / 600.0, death_rate]

func get_debug_text() -> String:
	var total_time = time_in_air + time_on_ground
	var air_pct = int((time_in_air / maxf(total_time, 1.0)) * 100.0)
	var grav_text := "Normal (1.0x)"
	if gravity_multiplier > 1.0:
		grav_text = "Alta (+15%)"
	elif gravity_multiplier < 1.0:
		grav_text = "Baja (-12%)"

	return """[ TELEMETRÍA Y ADAPTACIÓN (F3) ]
Perfil detectado: %s | Estado de montaña: %s
Gravedad: %s | Dashes: %d (Ventana: %d)
Saltos: %d | Caídas/Muertes: %d | Aturdimientos: %d
Tiempo en aire: %d%% | Distancia recorrida: %d px""" % [
		current_profile,
		current_adaptation,
		grav_text,
		total_dashes,
		dash_history.size(),
		total_jumps,
		total_deaths,
		total_stomps,
		air_pct,
		int(total_distance)
	]
