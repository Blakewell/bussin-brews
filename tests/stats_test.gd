extends Node
## Plays a dozen days across spots and tip setups, then opens Stats from each screen,
## flips every dropdown option, and checks Back returns to the right place. Run (needs a display):
##   godot --path . tests/stats_test.tscn [-- <out_dir> to save screenshots]

var main: Control
var failures := 0


func _ready() -> void:
	var out := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_window().size = Vector2i(1280, 720)
	GameState.save_path = "user://test_save.json"  # never touch the player's real save
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	GameState.new_game(11, "easy")
	main._show_briefing()
	_check(not _has_button("Stats"), "no Stats button before the first day")
	var spots := ["school", "beach", "office"]
	for i in 12:
		main._plan_loc = spots[i % 3]
		main._tip_mode = "screen" if i % 4 == 3 else "jar"
		main._show_planning()
		main._breeze()
		if i < 11:
			main._show_briefing()
	# From results: Stats, then Back keeps the results screen
	_check(_has_button("Stats"), "results has a Stats button")
	main._show_stats(func(): main._show_results(false))
	await _wait(0.4)
	if out != "":
		await _shot(out, "stats_profit_location")
	for m in main._stats_metrics():
		for g in main.STATS_GROUPINGS:
			main._stats_metric = m[0]
			main._stats_by = g[0]
			main._render_stats()
	await _wait(0.2)
	main._stats_metric = "item:latte"
	main._stats_by = "weather"
	main._render_stats()
	await _wait(0.3)
	if out != "":
		await _shot(out, "stats_latte_weather")
	main._stats_metric = "tips"
	main._stats_by = "tips"
	main._render_stats()
	await _wait(0.3)
	if out != "":
		await _shot(out, "stats_tips_tipsetup")
		main._stats_metric = "profit"
		main._stats_by = "location"
		main._render_stats()
		await _wait(0.3)
		var sc: ScrollContainer = main.find_children("*", "ScrollContainer", true, false)[0]
		sc.scroll_vertical = 10000
		await _wait(0.3)
		await _shot(out, "stats_table_location")
		main._stats_by = "weather"
		main._render_stats()
		await _wait(0.3)
		sc.scroll_vertical = 10000
		await _wait(0.3)
		await _shot(out, "stats_table_weather")
	main._stats_back.call()
	await _wait(0.2)
	_check(_has_button("Next day"), "Back returns to results")
	main._show_briefing()
	_check(_has_button("Stats"), "briefing has a Stats button")
	main._show_planning()
	_check(_has_button("Stats"), "planning has a Stats button")
	main._show_stats(main._show_planning)
	main._stats_back.call()
	_check(_has_button("Serve customers"), "Back returns to planning")
	print("STATS TEST DONE failures=%d" % failures)
	get_tree().quit()


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func _has_button(prefix: String) -> bool:
	for b in main.find_children("*", "Button", true, false):
		if b is Button and not b.is_queued_for_deletion() and b.text.begins_with(prefix):
			return true
	return false


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _shot(out: String, name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
