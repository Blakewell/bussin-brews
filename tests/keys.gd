extends Node
## Checks the title-screen keyboard controls. Run: godot --path . tests/keys.tscn

func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	_key(KEY_3)
	await get_tree().create_timer(0.1).timeout
	print("[keys] after pressing 3: difficulty=", main._difficulty, " pressed=", main._mode_buttons[2].button_pressed)
	_key(KEY_2)
	await get_tree().create_timer(0.1).timeout
	print("[keys] after pressing 2: difficulty=", main._difficulty, " pressed=", main._mode_buttons[1].button_pressed)
	_key(KEY_ENTER)
	await get_tree().create_timer(0.3).timeout
	print("[keys] after Enter: GameState.difficulty=", GameState.difficulty, " cash=", GameState.cash, " day=", GameState.day, " on_title=", main._on_title)
	print("KEYS DONE")
	get_tree().quit()


func _key(code: Key) -> void:
	for down in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = down
		get_viewport().push_input(ev)
