extends Node
## Renders the title screen and the first plan screen on Hard. Run:
##   godot --path . tests/difficulty_shots.tscn -- <out_dir>

func _ready() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _shot(out, "d1_title", 1.5)
	main._difficulty = "hard"
	GameState.new_game(42, "hard")
	main._prices.clear()
	main._servings.clear()
	main._show_planning()
	await _shot(out, "d2_hard_plan", 1.0)
	main._difficulty = "easy"
	GameState.new_game(42, "easy")
	main._prices.clear()
	main._servings.clear()
	main._show_planning()
	await _shot(out, "d3_easy_plan", 0.8)
	var tabs: TabContainer = main.find_children("*", "TabContainer", true, false)[0]
	tabs.current_tab = 1
	await _shot(out, "d4_bakery_tab", 0.5)
	get_tree().quit()


func _shot(out: String, name: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
