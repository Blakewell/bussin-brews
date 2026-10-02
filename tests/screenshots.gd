extends Node
## Renders each screen to PNG. Run (needs a display):
##   godot --path . tests/screenshots.tscn -- <out_dir>

func _ready() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_window().size = Vector2i(1280, 720)
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _shot(out, "1_title")
	GameState.new_game(42, "generational")
	main._show_briefing()
	await _shot(out, "2_briefing")
	main._show_planning()
	await _shot(out, "3_planning")
	main._run_day()
	await _shot(out, "4_results")
	get_tree().quit()


func _shot(out: String, name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
