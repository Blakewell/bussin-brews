extends Node
## Leaves the ambient banner scene running for a while so errors that need time to show up
## (people leaving, timers firing) are caught. Run: godot --path . tests/soak.tscn

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	print("[soak] sitting on the title screen for 40s")
	await get_tree().create_timer(40.0).timeout
	print("SOAK DONE")
	get_tree().quit()
