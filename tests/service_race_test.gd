extends Node
## Regression tests for hands-on service timing: double presses, turning away a served
## customer, and retrying a declined suggestion. Run: godot --path . tests/service_race_test.tscn

var failures := 0
var main: Control


func _ready() -> void:
	GameState.save_path = "user://test_save.json"
	get_window().size = Vector2i(1280, 720)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await _wait(0.3)
	await _double_serve()
	await _turn_away_after_sale()
	await _declined_suggestion()
	GameState.delete_save()
	print("")
	print("FAILED: %d" % failures if failures > 0 else "All service race tests passed")
	get_tree().quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _start(difficulty: String) -> void:
	GameState.new_game(11, difficulty)
	main._prices.clear()
	main._servings.clear()
	main._show_planning()
	await _wait(0.2)
	main._start_service()
	await _wait_for_arrival()


func _wait_for_arrival() -> void:
	for i in 40:
		if main._arrived:
			return
		await _wait(0.1)


func _double_serve() -> void:
	print("Double serve with an empty bakery case (Hard)")
	await _start("hard")
	ok(main._shift.treat_offers.is_empty(), "hard mode starts with no baked goods")
	var first_serial: int = main._serial
	main._serve(main._customer.craving, true)
	main._serve(main._customer.craving, true)  # the second press of a double-tap
	ok(main._shift.result.served == 1, "two quick presses sell one drink (served=%d)" % main._shift.result.served)
	await _wait(0.8)
	ok(main._serial == first_serial + 1, "exactly one new customer stepped up (serial %d -> %d)" % [first_serial, main._serial])
	ok(main._shift.result.skipped == 0, "nobody was skipped")


func _turn_away_after_sale() -> void:
	print("Turn away after a sale (Easy, with baked goods)")
	await _start("easy")
	var serial: int = main._serial
	main._serve(main._customer.craving, true)
	ok(main._upsell_pending, "bakery offer is showing")
	main._turn_away()  # should be ignored: they were already served
	ok(main._shift.result.skipped == 0 and main._serial == serial, "turn away is ignored once someone is served")
	main._depart()
	main._depart()  # double press of "No add-on"
	ok(main._serial == serial + 1, "a double press of 'No add-on' moves on one customer, not two")
	await _wait_for_arrival()
	main._upsell_pending = true  # simulate the bakery panel for a pending upsell
	main._resolved = true
	main._upsell(main._shift.treat_offers[0].treat.id)
	var after_upsell: int = main._serial
	main._turn_away()
	await _wait(1.3)
	ok(main._serial == after_upsell + 1 and main._shift.result.skipped == 0, "after an add-on offer, the delayed departure fires once")


func _declined_suggestion() -> void:
	print("Declined suggestion")
	await _start("easy")
	var c: Dictionary = main._customer
	# Make one drink something they'd never want, then pitch it.
	var pitch := ""
	for id in c.weights:
		if id != c.craving and main._shift.stock[id] > 0:
			pitch = id
			break
	c.weights[pitch] = 0.0
	main._serve(pitch, true)
	ok(c.get("insists", false) and main._shift.result.declined == 1, "they said no to the %s" % pitch)
	var locked := 0
	var open := 0
	for b in main._action_buttons:
		if is_instance_valid(b) and b.text.contains("left"):
			if b.disabled:
				locked += 1
			else:
				open += 1
	ok(locked == 4 and open == 1, "other suggestions are locked after the no (%d locked, %d open)" % [locked, open])
	main._serve(pitch, true)
	ok(main._shift.result.declined == 1 and not c.has("sold_drink"), "pressing the locked drink again does nothing")
	main._serve(c.craving, true)
	ok(c.get("sold_drink", "") == c.craving, "they still buy what they asked for")
