extends Node
## Save/load checks. Uses a throwaway save file, never the player's real one.
## Run: godot --headless --path . tests/save_test.tscn

var failures := 0
const TEST_PATH := "user://test_save.json"


func _ready() -> void:
	GameState.save_path = TEST_PATH
	GameState.delete_save()
	_round_trip()
	_bad_files()
	await _ui_flow()
	GameState.delete_save()
	print("")
	print("FAILED: %d" % failures if failures > 0 else "All save tests passed")
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _plan() -> Dictionary:
	return {"location_id": "school", "offers": [
		{"drink_id": "boba", "price": 6.0, "servings": 15},
		{"drink_id": "lemonade", "price": 4.0, "servings": 15}],
		"treats": [{"item_id": "cookie", "price": 2.75, "servings": 10}]}


func _round_trip() -> void:
	print("Round trip")
	ok(not GameState.has_save(), "no save to begin with")
	GameState.new_game(7, "medium")
	for i in 3:
		GameState.run_day(_plan())
	var before := {
		"cash": GameState.cash, "day": GameState.day, "rep": GameState.reputation,
		"weather": GameState.weather_id, "hist": GameState.history.size(),
		"profit": GameState.last_result().profit, "start": GameState.start_cash,
		"visit": GameState.last_visit("school").day,
	}
	ok(GameState.save_game({"plan_loc": "beach", "prices": {"boba": 6.5}, "servings": {"boba": 12}}), "save_game succeeds")
	ok(GameState.has_save(), "save file now exists")
	var summary := GameState.save_summary()
	ok(summary.day == 4 and summary.difficulty == "medium", "summary shows day 4, medium")

	GameState.new_game(99, "hard")  # scramble everything
	var extra = GameState.load_game()
	ok(extra != null, "load_game returns the extra data")
	ok(GameState.day == before.day and is_equal_approx(GameState.cash, before.cash), "day and cash restored (day %d, $%.2f)" % [GameState.day, GameState.cash])
	ok(is_equal_approx(GameState.reputation, before.rep) and GameState.difficulty == "medium" and GameState.start_cash == before.start, "reputation, difficulty, start cash restored")
	ok(GameState.weather_id == before.weather, "today's weather is identical after loading (%s)" % GameState.weather_id)
	ok(GameState.history.size() == before.hist and is_equal_approx(GameState.last_result().profit, before.profit), "history restored, last day's profit matches")
	ok(GameState.last_visit("school").day == before.visit, "per-location last-visit lookup works after loading")
	ok(typeof(GameState.day) == TYPE_INT, "day is an int again, not a float")
	ok(extra.plan_loc == "beach" and extra.prices.boba == 6.5, "UI extras come back")
	# The game keeps working from the loaded state.
	var next := GameState.run_day(_plan())
	ok(next.day == 4 and GameState.day == 5, "can play day 4 after loading")


func _bad_files() -> void:
	print("Bad files")
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{this is not json")
	f.close()
	ok(not GameState.has_save() and GameState.load_game() == null, "corrupted file is treated as no save")
	f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 999, "cash": 1, "start_cash": 1, "difficulty": "easy", "day": 1, "reputation": 1, "run_seed": 1, "history": []}))
	f.close()
	ok(not GameState.has_save(), "a save from another version is ignored")
	f = FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "cash": 5}))
	f.close()
	ok(not GameState.has_save(), "a save missing fields is ignored")
	GameState.delete_save()
	ok(not GameState.has_save(), "delete_save removes the file")


func _ui_flow() -> void:
	print("UI flow")
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	ok(_find(main, "Open for business") != null and _find(main, "Continue") == null, "fresh title offers only 'Open for business'")
	main._difficulty = "medium"
	_find(main, "Open for business").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_find(main, "Plan the day").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	_find(main, "Breeze through the day").pressed.emit()
	await get_tree().create_timer(0.4).timeout
	ok(GameState.has_save() and GameState.save_summary().day == 2, "finishing a day autosaves (now day 2)")
	var saved_cash := GameState.cash
	main._show_title()
	await get_tree().create_timer(0.3).timeout
	ok(_find(main, "Continue") != null and _find(main, "New game") != null, "title now offers Continue and New game")
	GameState.new_game(5, "hard")  # simulate quitting and relaunching
	_find(main, "Continue").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	ok(GameState.day == 2 and is_equal_approx(GameState.cash, saved_cash) and GameState.difficulty == "medium", "Continue restores the run (day 2, $%.2f)" % GameState.cash)
	ok(_find(main, "Plan the day") != null, "Continue lands on the briefing")
	_find(main, "Plan the day").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	ok(_find(main, "Serve customers") != null, "planning works after continuing")
	# Losing the run clears the save.
	GameState.cash = 5.0
	main._autosave()
	ok(not GameState.has_save(), "game over deletes the save")
	main.queue_free()


func _find(root: Node, prefix: String) -> Button:
	for n in root.find_children("*", "Button", true, false):
		if n is Button and n.is_visible_in_tree() and n.text.begins_with(prefix):
			return n
	return null
