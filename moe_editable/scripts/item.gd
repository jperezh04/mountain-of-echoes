extends Area2D
## Scene kind controls interaction. Duplicate the scene to add another object.
@export_enum("rune", "echo", "checkpoint", "exit") var kind := "rune"
var activated := false
var initial_pos_y := 0.0
var time_offset := 0.0

func _ready() -> void:
	initial_pos_y = position.y
	time_offset = randf_range(0.0, 6.28)

func _process(delta: float) -> void:
	if kind in ["rune", "echo"] and not activated:
		var time := Time.get_ticks_msec() / 1000.0 + time_offset
		position.y = initial_pos_y + sin(time * 3.5) * 3.0
		if has_node("Visual"):
			var pulse := 0.9 + 0.1 * sin(time * 5.0)
			$Visual.scale = Vector2(pulse, pulse)
	elif kind == "checkpoint" and activated:
		if has_node("Visual/Flame"):
			var flicker := 1.0 + 0.12 * sin(Time.get_ticks_msec() * 0.015)
			$Visual/Flame.scale = Vector2(flicker, flicker)

func activate() -> void:
	activated = true
	if kind in ["rune", "echo"]:
		hide()
		set_deferred("monitoring", false)
	elif kind == "checkpoint":
		if has_node("Visual/Flame"):
			$Visual/Flame.color = Color("ffdb95")
			var tw := create_tween()
			tw.tween_property($Visual/Flame, "scale", Vector2(1.8, 1.8), 0.15)
			tw.tween_property($Visual/Flame, "scale", Vector2(1.0, 1.0), 0.2)
