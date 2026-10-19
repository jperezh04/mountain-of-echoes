class_name CatcadeScoreManager
extends RefCounted

## ScoreManager: Gestiona puntuaciones, bonus de eficiencia y estrellas.
## Persistencia aislada en user://catcade_scores.json sin tocar el juego principal.

const SAVE_PATH := "user://catcade_scores.json"

const STAR_THRESHOLDS := {
	1: [3000, 5000, 7500],
	2: [5000, 8000, 12000],
	3: [8000, 14000, 18000]
}

var current_score: int = 0
var destroyed_blocks: int = 0
var defeated_enemies: int = 0

func reset_score() -> void:
	current_score = 0
	destroyed_blocks = 0
	defeated_enemies = 0

func add_points(points: int) -> void:
	current_score += points

func record_block_destroyed(points: int) -> void:
	destroyed_blocks += 1
	add_points(points)

func record_enemy_defeated(points: int) -> void:
	defeated_enemies += 1
	add_points(points)

func calculate_cat_bonus(cats_remaining: int) -> int:
	# 2000 puntos por cada gato no utilizado
	var bonus := cats_remaining * 2000
	current_score += bonus
	return bonus

func get_stars(level_num: int, final_score: int) -> int:
	var thresholds: Array = STAR_THRESHOLDS.get(level_num, [3000, 5000, 7500])
	if final_score >= thresholds[2]:
		return 3
	elif final_score >= thresholds[1]:
		return 2
	elif final_score >= thresholds[0]:
		return 1
	return 1 # Completar el nivel otorga al menos 1 estrella

func get_high_score(level_num: int) -> int:
	var data := _load_save_file()
	return data.get("level_%d" % level_num, 0)

func save_high_score(level_num: int, score: int) -> bool:
	var data := _load_save_file()
	var key := "level_%d" % level_num
	var old_high = data.get(key, 0)
	if score > old_high:
		data[key] = score
		var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
		if file:
			file.store_string(JSON.stringify(data))
			file.close()
			return true
	return false

func _load_save_file() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return {}
	var content := file.get_as_text()
	file.close()
	var json = JSON.parse_string(content)
	if json is Dictionary:
		return json
	return {}
