extends SceneTree
## Headless sim checks. Run: godot --headless --path . --script tests/run_sim_tests.gd

var failures := 0


func _init() -> void:
	var content = load("res://scripts/autoload/content.gd").new()
	content._ready()
	_check_cpi(content)
	_check_economy(content)
	_check_demand(content)
	_check_generations(content)
	_check_shift(content)
	_check_upsell(content)
	_check_difficulty(content)
	print("")
	print("FAILED: %d" % failures if failures > 0 else "All sim tests passed")
	quit(1 if failures > 0 else 0)


func ok(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FAIL ") + msg)
	if not cond:
		failures += 1


func _check_cpi(c) -> void:
	print("CPI")
	ok(c.cpi.value("gasoline", "2026-01") > 0.0, "gasoline CPI exists for base month")
	ok(c.cpi.ratio("gasoline", "2026-01", "2026-01") == 1.0, "ratio at base month is 1")
	ok(c.cpi.change("gasoline", "2026-03") > 0.08, "March 2026 gas spike is in the real data")
	for e in c.events:
		var season := GameCalendar.season(int(e.start_day))
		if e.headline.to_lower().contains("spring"):
			ok(season == "spring", "event '%s' lands in spring (day %d is %s)" % [e.headline, e.start_day, season])
	ok(GameCalendar.month_key(1) == "2026-01" and GameCalendar.month_key(11) == "2026-02" and GameCalendar.month_key(31) == "2026-04", "calendar maps 10 days to a month")
	ok(GameCalendar.previous_month("2026-01") == "2025-12", "previous month wraps the year")


func _check_economy(c) -> void:
	print("Economy")
	var beach: Dictionary = c.location("beach")
	var before: float = c.economy.trip_cost(beach, "2026-02")
	var after: float = c.economy.trip_cost(beach, "2026-03")
	ok(after > before * 1.2, "beach trip cost jumps >20%% in the gas spike (%.2f -> %.2f)" % [before, after])
	var latte: Dictionary = c.drink("latte")
	ok(absf(c.economy.fair_price(latte, "2026-01") - latte.ref_price) < 0.001, "fair price equals ref price in base month")


func _offers(c, price_mult := 1.0, stock := 40) -> Array:
	var offers := []
	for d in c.drinks:
		offers.append({"drink": d, "price": c.economy.fair_price(d, "2026-01") * price_mult, "fair": c.economy.fair_price(d, "2026-01"), "stock": stock})
	return offers


func _run(c, loc_id: String, weather_id: String, price_mult := 1.0, stock := 40, seed_value := 7) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return Demand.simulate_shift(_offers(c, price_mult, stock), c.location(loc_id), c.weather.types[weather_id], 1.0, 1.0, rng, c.generations)


func _check_demand(c) -> void:
	print("Demand")
	var hot_iced := 0
	var hot_hot := 0
	var cold_iced := 0
	var cold_hot := 0
	var h := _run(c, "beach", "hot")
	var k := _run(c, "beach", "cold")
	hot_iced = h.sold.iced_matcha + h.sold.boba + h.sold.lemonade
	hot_hot = h.sold.hot_cocoa + h.sold.latte
	cold_iced = k.sold.iced_matcha + k.sold.boba + k.sold.lemonade
	cold_hot = k.sold.hot_cocoa + k.sold.latte
	ok(hot_iced > hot_hot * 3, "heat wave: iced dominates (%d iced vs %d hot)" % [hot_iced, hot_hot])
	ok(cold_hot > hot_hot, "cold weather sells more hot drinks than a heat wave (%d vs %d)" % [cold_hot, hot_hot])
	ok(_run(c, "beach", "rainy").served < _run(c, "beach", "sunny").served, "rain cuts traffic")
	var fair_rev := 0.0
	var gouge_rev := 0.0
	for seed_value in 20:
		fair_rev += _run(c, "school", "sunny", 1.0, 40, seed_value).revenue
		gouge_rev += _run(c, "school", "sunny", 2.0, 40, seed_value).revenue
	ok(gouge_rev < fair_rev, "doubling prices at the school hurts average revenue (%.0f vs %.0f over 20 days)" % [gouge_rev / 20.0, fair_rev / 20.0])
	var office := _run(c, "office", "cloudy")
	var school := _run(c, "school", "cloudy")
	ok(office.sold.latte + office.sold.iced_matcha > school.sold.latte + school.sold.iced_matcha, "office crowd buys more fancy drinks than school kids")
	var small := _run(c, "beach", "sunny", 1.0, 5)
	ok(small.lost_to_stockout > 0, "low stock produces stockout losses")
	var rich := _run(c, "beach", "sunny", 1.0, 100)
	ok(rich.served <= Demand.SHIFT_CAPACITY, "truck capacity caps service at %d" % Demand.SHIFT_CAPACITY)
	print("  info beach sunny: arrivals %d served %d revenue %.0f | school: served %d revenue %.0f | office: served %d revenue %.0f" % [rich.arrivals, rich.served, rich.revenue, school.served, school.revenue, office.served, office.revenue])


func _check_generations(c) -> void:
	print("Generations")
	var sims := []
	for seed_value in 12:
		sims.append(_run(c, "beach", "sunny", 1.0, 100, seed_value))
	var tips := {}
	var served := {}
	var chats := {}
	for r in sims:
		for g in c.generations:
			tips[g] = tips.get(g, 0.0) + r.tips_by_gen.get(g, 0.0)
			served[g] = served.get(g, 0) + r.served_by_gen.get(g, 0)
			chats[g] = chats.get(g, 0) + r.chats_by_gen.get(g, 0)
	var tip_per := {}
	var chat_rate := {}
	for g in c.generations:
		tip_per[g] = tips[g] / maxf(served[g], 1)
		chat_rate[g] = float(chats[g]) / maxf(served[g], 1)
	ok(tip_per.boomer > tip_per.gen_z, "survey data: boomers tip more per customer than Gen Z (%.2f vs %.2f)" % [tip_per.boomer, tip_per.gen_z])
	ok(chat_rate.boomer > chat_rate.gen_z * 2.0, "boomers chat far more than Gen Z (%.2f vs %.2f)" % [chat_rate.boomer, chat_rate.gen_z])
	var school_gz := 0
	var school_boom := 0
	var r := _run(c, "school", "sunny")
	school_gz = r.served_by_gen.get("gen_z", 0)
	school_boom = r.served_by_gen.get("boomer", 0)
	ok(school_gz > school_boom * 4, "school line is mostly Gen Z (%d vs %d boomers)" % [school_gz, school_boom])
	var chatty_load := _run(c, "beach", "sunny", 1.0, 200)
	ok(chatty_load.served < Demand.SHIFT_CAPACITY, "chats use up service time (%d served at capacity %d)" % [chatty_load.served, Demand.SHIFT_CAPACITY])


func _check_shift(c) -> void:
	print("Shift (hand-played)")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var shift := Shift.new(_offers(c), c.location("office"), c.weather.types["cloudy"], 1.0, 1.0, rng, c.generations)
	var customers := 0
	var cust := shift.next_customer()
	var first := cust
	while not cust.is_empty():
		customers += 1
		var out := shift.serve(cust, cust.craving, true)
		if not out.sold:
			ok(false, "serving the craving should always sell while in stock")
			break
		cust = shift.next_customer()
	ok(customers > 20 and shift.result.served == customers, "serving every craving sells to every buyer (%d)" % customers)
	ok(not first.is_empty() and first.weights.has(first.craving), "customers carry a craving and per-drink appeal")

	# Offering a drink the customer likes less than their craving can be declined.
	var declines := 0
	var trials := 0
	for seed_value in 30:
		var r2 := RandomNumberGenerator.new()
		r2.seed = seed_value
		var s2 := Shift.new(_offers(c), c.location("beach"), c.weather.types["hot"], 1.0, 1.0, r2, c.generations)
		var cu := s2.next_customer()
		if cu.is_empty():
			continue
		var worst := ""
		var worst_w := INF
		for id in cu.weights:
			if cu.weights[id] < worst_w:
				worst_w = cu.weights[id]
				worst = id
		if worst != cu.craving:
			trials += 1
			if s2.serve(cu, worst, true).declined:
				declines += 1
	ok(trials > 5 and declines > 0, "pushing a drink they don't want gets declined sometimes (%d of %d)" % [declines, trials])

	# After one "no" they stick with their order: retrying can't farm a yes.
	var stubborn := 0
	var retried := 0
	for seed_value in 40:
		var r4 := RandomNumberGenerator.new()
		r4.seed = seed_value
		var s4 := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, r4, c.generations)
		var cu4 := s4.next_customer()
		if cu4.is_empty():
			continue
		var other := ""
		var lowest := INF
		for id in cu4.weights:
			if id != cu4.craving and cu4.weights[id] < lowest:
				lowest = cu4.weights[id]
				other = id
		if s4.serve(cu4, other, true).declined:
			retried += 1
			var sold_later := false
			for attempt in 10:
				if s4.serve(cu4, other, true).sold:
					sold_later = true
			if not sold_later:
				stubborn += 1
			ok(s4.serve(cu4, cu4.craving, true).sold, "after declining, they still take their own order") if seed_value == 0 else null
	ok(retried > 3 and stubborn == retried, "after one no, ten more pitches never get a yes (%d of %d held firm)" % [stubborn, retried])

	# Engaging with a chatty customer tips better than cutting them off.
	var engaged_tips := 0.0
	var cut_tips := 0.0
	for seed_value in 60:
		for engage in [true, false]:
			var r3 := RandomNumberGenerator.new()
			r3.seed = seed_value
			var s3 := Shift.new(_offers(c), c.location("beach"), c.weather.types["sunny"], 1.0, 1.0, r3, c.generations)
			var cu3 := s3.next_customer()
			while not cu3.is_empty():
				if cu3.wants_chat:
					var o3 := s3.serve(cu3, cu3.craving, engage)
					if engage:
						engaged_tips += o3.tip
					else:
						cut_tips += o3.tip
				else:
					s3.serve(cu3, cu3.craving, true)
				cu3 = s3.next_customer()
	ok(engaged_tips > cut_tips, "chatting earns more tips than cutting people off ($%.2f vs $%.2f)" % [engaged_tips, cut_tips])

	var rng_a := RandomNumberGenerator.new()
	rng_a.seed = 5
	var auto := Demand.simulate_shift(_offers(c), c.location("school"), c.weather.types["sunny"], 1.0, 1.0, rng_a, c.generations)
	ok(auto.served > 0 and auto.tips > 0.0, "autopilot shift completes with sales and tips")


func _treat_offers(c, stock := 50) -> Array:
	var out := []
	for t in c.treats:
		out.append({"treat": t, "price": c.economy.fair_price(t, "2026-01"), "fair": c.economy.fair_price(t, "2026-01"), "stock": stock})
	return out


func _check_upsell(c) -> void:
	print("Upsell")
	# Preference by generation: muffins go to boomers, protein balls to millennials.
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var shift := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, rng, c.generations, _treat_offers(c))
	var boomer := {"gen_id": "boomer", "craving": "hot_cocoa", "sold_drink": "hot_cocoa"}
	var millennial := {"gen_id": "millennial", "craving": "iced_matcha", "sold_drink": "iced_matcha"}
	ok(shift.treat_chance(boomer, "muffin") > shift.treat_chance(boomer, "protein_ball"), "boomers favor muffins over protein balls")
	ok(shift.treat_chance(millennial, "protein_ball") > shift.treat_chance(millennial, "muffin"), "millennials favor protein balls over muffins")
	ok(shift.treat_chance(boomer, "cookie") > shift.treat_chance({"gen_id": "boomer", "craving": "lemonade", "sold_drink": "lemonade"}, "cookie"), "cookies pair better with a hot drink")

	# Pricing a treat higher cuts the chance.
	var pricey := _treat_offers(c)
	for t in pricey:
		t.price = t.fair * 2.0
	var s2 := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, rng, c.generations, pricey)
	ok(s2.treat_chance(boomer, "muffin") < shift.treat_chance(boomer, "muffin"), "doubling a treat's price lowers acceptance")

	# Hands-on beats autopilot, since you can pick the right treat and autopilot is less persuasive.
	var hand_rev := 0.0
	var auto_rev := 0.0
	var time_hand := 0.0
	for seed_value in 20:
		var ra := RandomNumberGenerator.new()
		ra.seed = seed_value
		var sa := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, ra, c.generations, _treat_offers(c))
		sa.auto_finish()
		auto_rev += sa.result.treat_revenue
		var rh := RandomNumberGenerator.new()
		rh.seed = seed_value
		var sh := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, rh, c.generations, _treat_offers(c))
		var cu := sh.next_customer()
		while not cu.is_empty():
			if sh.serve(cu, cu.craving, true).sold:
				var best := ""
				var best_p := 0.0
				for id in sh.treat_stock:
					var p: float = sh.treat_chance(cu, id)
					if sh.treat_stock[id] > 0 and p > best_p:
						best_p = p
						best = id
				if best != "":
					sh.upsell(cu, best)
			cu = sh.next_customer()
		hand_rev += sh.result.treat_revenue
		time_hand += sh.used
	ok(auto_rev > 0.0, "autopilot still sells some treats ($%.0f over 20 days)" % auto_rev)
	ok(hand_rev > auto_rev, "a good hand-played upsell beats autopilot ($%.0f vs $%.0f)" % [hand_rev, auto_rev])

	# Out of stock treats can't be sold.
	var s3 := Shift.new(_offers(c), c.location("beach"), c.weather.types["cloudy"], 1.0, 1.0, rng, c.generations, _treat_offers(c, 0))
	ok(not s3.has_treats_in_stock() and not s3.upsell(boomer, "muffin").accepted, "no stock, no upsell")


func _check_difficulty(c) -> void:
	print("Difficulty")
	var cash := {}
	for d in c.difficulties:
		cash[d.id] = d.cash
	ok(cash.get("easy") == 1000 and cash.get("medium") == 500 and cash.get("hard") == 100, "easy/medium/hard start with $1000/$500/$100")
	ok(c.difficulty("nonsense").id == "easy", "unknown difficulty falls back to easy")
