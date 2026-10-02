extends Node
## Draws every location x weather x time-of-day combination and plays a few seeds of the UI flow,
## so any runtime script error shows up in the log. Run (needs a display):
##   godot --path . tests/sweep.tscn

func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.4)
	var combos := 0
	for loc in ["school", "beach", "office"]:
		for wx in ["sunny", "hot", "cloudy", "rainy", "cold"]:
			for p in [0.0, 0.5, 1.0]:
				var sc := TruckScene.new()
				sc.custom_minimum_size = Vector2(1184, 300)
				sc.loc_id = loc
				sc.weather_id = wx
				sc.progress = p
				sc.ambient = true
				main.add_child(sc)
				await _wait(0.12)
				sc.queue_free()
				combos += 1
	print("[sweep] scene combos drawn: ", combos)
	# Many fresh games with random seeds through the real buttons, every difficulty.
	for diff in ["easy", "medium", "hard"]:
		for run in 4:
			main._difficulty = diff
			main._show_title()
			await _wait(0.1)
			_press(main, "Open for business")
			await _wait(0.15)
			var seen: String = GameState.weather_id
			_press(main, "Plan the day")
			await _wait(0.15)
			_press(main, "Serve customers")
			await _wait(1.6)
			for i in 3:
				_press(main, "Serve what they asked for")
				await _wait(0.4)
				_press(main, "No add-on")
				await _wait(1.5)
			_press(main, "Breeze through the rest")
			await _wait(0.4)
			print("[sweep] ", diff, " run ", run, " weather=", seen, " ok")
	print("SWEEP DONE")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _press(main: Node, prefix: String) -> bool:
	for n in main.find_children("*", "Button", true, false):
		if n is Button and n.is_visible_in_tree() and n.text.begins_with(prefix) and not n.disabled:
			n.pressed.emit()
			return true
	return false
