extends Node
## Clicks through the real UI like a player. Run (needs a display):
##   godot --path . tests/playthrough.tscn

var main: Control


func _ready() -> void:
	get_window().size = Vector2i(1280, 720)
	GameState.save_path = "user://test_save.json"  # never touch the player's real save
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.5)
	_log("title buttons: %s" % [_button_texts()])
	_log("clicked open: %s" % _press("Open for business"))
	await _wait(0.3)
	_log("clicked plan: %s" % _press("Plan the day"))
	await _wait(0.3)
	_log("plan buttons: %s" % [_button_texts()])
	_log("clicked serve: %s" % _press("Serve customers"))
	await _wait(2.5)
	_log("service buttons: %s" % [_button_texts()])
	for i in 6:
		var served := _press("Serve what they asked for")
		await _wait(0.5)
		var skipped := _press("No add-on")
		_log("round %d served=%s skipped_addon=%s" % [i, served, skipped])
		await _wait(1.8)
	_log("after 8 rounds: %s" % [_button_texts()])
	_press("Breeze through the rest")
	await _wait(0.5)
	_log("results buttons: %s" % [_button_texts()])
	_press("Next day")
	await _wait(0.3)
	_press("Plan the day")
	await _wait(0.3)
	_press("Breeze through the day")
	await _wait(0.5)
	_log("day 2 results: %s" % [_button_texts()])
	print("PLAYTHROUGH DONE")
	get_tree().quit()


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _log(msg: String) -> void:
	print("[playthrough] ", msg)


func _buttons() -> Array:
	var out := []
	for n in main.find_children("*", "Button", true, false):
		if n is Button and n.is_visible_in_tree():
			out.append(n)
	return out


func _button_texts() -> Array:
	var t := []
	for b in _buttons():
		t.append(b.text.replace("\n", " / ") + (" (disabled)" if b.disabled else ""))
	return t


## Clicks with a real mouse event at the button's center, so overlapping controls would block it.
func _press(prefix: String) -> bool:
	for b in _buttons():
		if b.text.begins_with(prefix) and not b.disabled:
			var pos: Vector2 = b.get_global_rect().get_center()
			var vp := get_viewport()
			var move := InputEventMouseMotion.new()
			move.position = pos
			move.global_position = pos
			vp.push_input(move)
			for down in [true, false]:
				var ev := InputEventMouseButton.new()
				ev.button_index = MOUSE_BUTTON_LEFT
				ev.position = pos
				ev.global_position = pos
				ev.pressed = down
				ev.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
				vp.push_input(ev)
			return true
	return false
