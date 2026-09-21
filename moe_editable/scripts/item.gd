extends Area2D
## Scene kind controls interaction. Duplicate the scene to add another object.
@export_enum("rune", "echo", "checkpoint", "exit") var kind := "rune"
var activated := false

func activate() -> void:
	activated = true
	if kind in ["rune", "echo"]:
		hide()
		set_deferred("monitoring", false)
	elif kind == "checkpoint":
		$Visual/Flame.color = Color("ffdb95")
