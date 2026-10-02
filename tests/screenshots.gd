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
	main._breeze()
	await _shot(out, "4_results_day1")
	main._show_briefing()
	await _shot(out, "5_briefing_day2")
	main._plan_loc = "office"
	main._show_planning()
	main._restock_from_yesterday()
	await _shot(out, "6_planning_day2")
	main._start_service()
	for i in 6:
		if main._customer.is_empty():
			break
		main._serve(main._customer.craving, true)
	await _shot(out, "7_service")
	main._shift.auto_finish()
	main._last_result = GameState.finish_shift("hands-on")
	main._show_results()
	await _shot(out, "8_results_day2")
	get_tree().quit()


func _shot(out: String, name: String) -> void:
	for i in 3:
		await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
