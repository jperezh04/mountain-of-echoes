extends Node2D
var camera_x := 0.0
var elapsed := 0.0
var flakes: Array[Vector3] = []

var wind_factor := 1.0

func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2048
	for i in range(75):
		flakes.append(Vector3(rng.randf_range(0, 850), rng.randf_range(0, 450), rng.randf_range(0.4, 1.5)))

func _process(delta: float) -> void:
	elapsed += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 800, 450), Color("101f38"))
	for y in range(0, 450, 6):
		draw_rect(Rect2(0, y, 800, 6), Color("101f38").lerp(Color("567c91"), float(y) / 580))
	draw_circle(Vector2(641, 82), 44, Color(0.7, 0.9, 1, 0.035))
	draw_circle(Vector2(641, 82), 29, Color("c6e9ee"))
	for layer in range(3):
		var spacing := 245.0 - layer * 25
		var offset := fposmod(camera_x * (0.06 + layer * 0.055), spacing)
		for i in range(-1, 6):
			var x := i * spacing - offset
			var peak := 95.0 + layer * 68 + sin(i * 8.0 + layer) * 35
			var base := 380.0 + layer * 55
			var mountain_color: Color = [Color("2c4964"), Color("365e76"), Color("24455e")][layer]
			draw_colored_polygon(PackedVector2Array([Vector2(x - 130, base), Vector2(x + 70, peak), Vector2(x + 270, base)]), mountain_color)
			draw_colored_polygon(PackedVector2Array([Vector2(x + 70, peak), Vector2(x + 115, peak + 65), Vector2(x + 84, peak + 49), Vector2(x + 61, peak + 64), Vector2(x + 26, peak + 67)]), Color("aac5d5").darkened(layer * 0.17))
	# Thin drifting cloud bands, behind all gameplay.
	for i in range(4):
		draw_rect(Rect2(fposmod(i * 273 - elapsed * 4 * wind_factor - camera_x * 0.03, 1050) - 200, 114 + i * 52, 240, 2), Color(0.75, 0.93, 1, 0.06))
	for flake in flakes:
		var x := fposmod(flake.x + elapsed * 14 * flake.z * wind_factor - camera_x * 0.07, 820) - 10
		var y := fposmod(flake.y + elapsed * 22 * flake.z * (0.8 + 0.2 * wind_factor), 450)
		draw_rect(Rect2(x, y, flake.z * 2, flake.z * 2), Color(0.85, 0.96, 1, 0.5))

