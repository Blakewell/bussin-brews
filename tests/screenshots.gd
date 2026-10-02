extends Node
## Renders key screens to PNG, waiting for walking animations. Run (needs a display):
##   godot --path . tests/screenshots.tscn -- <out_dir>

func _ready() -> void:
	var out := "/tmp"
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	get_window().size = Vector2i(1280, 720)
	GameState.save_path = "user://test_save.json"  # never touch the player's real save
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _shot(out, "1_title", 3.5)
	GameState.new_game(42, "easy")
	main._show_briefing()
	await _shot(out, "2_briefing", 3.0)
	main._plan_loc = "beach"
	main._show_planning()
	await _shot(out, "3_planning_beach", 2.5)
	main._plan_loc = "school"
	main._breeze()
	await _shot(out, "4_results_day1", 2.0)
	main._show_briefing()
	main._plan_loc = "office"
	main._show_planning()
	main._restock_from_yesterday()
	main._start_service()
	await _shot(out, "5_service_walking", 0.5)
	await _shot(out, "6_service_order", 1.6)
	main._serve(main._customer.craving, true)
	await _shot(out, "7_service_upsell", 0.4)
	main._upsell(main._shift.treat_offers[1].treat.id)
	await _shot(out, "8_after_upsell", 1.3)
	for i in 3:
		main._serve(main._customer.craving, true)
		main._depart()
		await get_tree().create_timer(0.8).timeout
	await _shot(out, "9_busy", 0.8)
	get_tree().quit()


func _shot(out: String, name: String, wait: float) -> void:
	await get_tree().create_timer(wait).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, name])
	print("saved ", name)
