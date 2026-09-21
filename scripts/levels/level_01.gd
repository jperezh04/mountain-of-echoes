extends Node2D

const PlayerScript = preload("res://scripts/player/player.gd")

var platforms: Array[Rect2] = [
	Rect2(-180, 220, 480, 180),
	Rect2(350, 190, 160, 210),
	Rect2(565, 145, 150, 255),
	Rect2(765, 100, 180, 300),
	Rect2(1000, 150, 220, 250),
	Rect2(1270, 100, 180, 300),
	Rect2(1500, 55, 300, 345)
]


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#182c45"))
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	for platform in platforms:
		var body := StaticBody2D.new()
		body.position = platform.position

		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = platform.size
		collision.shape = shape
		collision.position = platform.size / 2.0
		body.add_child(collision)
		add_child(body)

	var player := CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.name = "Player"
	player.position = Vector2(50, 200)
	add_child(player)

	var hud := CanvasLayer.new()
	add_child(hud)

	var instructions := Label.new()
	instructions.text = "MOUNTAIN OF ECHOES\nFlechas: mover | Espacio: saltar\nPrueba de movimiento"
	instructions.position = Vector2(12, 10)
	instructions.add_theme_font_size_override("font_size", 12)
	hud.add_child(instructions)

	queue_redraw()


func _draw() -> void:
	# Siluetas provisionales de montañas.
	for index in range(8):
		var x: float = index * 300.0 - 400.0
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x, 420),
				Vector2(x + 180, -160),
				Vector2(x + 390, 420)
			]),
			Color("#29465c")
		)
		draw_colored_polygon(
			PackedVector2Array([
				Vector2(x + 140, -30),
				Vector2(x + 180, -160),
				Vector2(x + 227, -30),
				Vector2(x + 184, -57)
			]),
			Color("#91bacb")
		)

	for platform in platforms:
		draw_rect(platform, Color("#405b70"))
		draw_rect(
			Rect2(platform.position, Vector2(platform.size.x, 7)),
			Color("#e4f6ff")
		)
		draw_rect(
			Rect2(platform.position + Vector2(0, 7),
				Vector2(platform.size.x, 4)),
			Color("#8ac5de")
		)