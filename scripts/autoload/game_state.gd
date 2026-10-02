extends Node
## Run state: money, day, reputation, the day's weather and news, and the shift runner.

const MIN_PLAYABLE_CASH := 25.0

var cash := 1000.0
var start_cash := 1000.0
var difficulty := "easy"
var day := 1
var reputation := 1.0
var run_seed := 1
var weather_id := "sunny"
var headlines: Array = []   ## [{headline, body}] shown in the morning briefing
var history: Array = []     ## one result dict per finished day
var _current := {}          ## the shift in progress


func new_game(seed_value: int = 0, difficulty_id: String = "easy") -> void:
	difficulty = difficulty_id
	start_cash = float(Content.difficulty(difficulty_id).cash)
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	cash = start_cash
	day = 1
	reputation = 1.0
	history.clear()
	begin_day()


func month() -> String:
	return GameCalendar.month_key(day)


func is_game_over() -> bool:
	return cash < MIN_PLAYABLE_CASH


func begin_day() -> void:
	weather_id = _roll_weather()
	headlines = _gather_headlines()


func active_events() -> Array:
	var active: Array = []
	for e in Content.events:
		if day >= e.start_day and day < e.start_day + e.duration:
			active.append(e)
	return active


func gas_price() -> float:
	return Content.economy.gas_price(month())


func traffic_mult(location_id: String) -> float:
	return _effect_product("demand_location:" + location_id)


func _effect_product(target: String) -> float:
	var mult := 1.0
	for e in active_events():
		for fx in e.effects:
			if fx.target == target:
				mult *= fx.mult
	return mult


func _roll_weather() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + day * 7919
	for e in active_events():
		for fx in e.effects:
			if fx.target == "weather":
				return fx.force
	var odds: Dictionary = Content.weather.season_odds[GameCalendar.season(day)]
	var total := 0.0
	for k in odds:
		total += odds[k]
	var pick := rng.randf() * total
	for k in odds:
		pick -= odds[k]
		if pick <= 0.0:
			return k
	return "cloudy"


func _gather_headlines() -> Array:
	var out: Array = []
	for e in active_events():
		out.append({"headline": e.headline, "body": e.body})
	if day > 1 and GameCalendar.is_month_start(day):
		var gas := Content.cpi.change("gasoline", month())
		var groceries := Content.cpi.change("food_home", month())
		var rules: Dictionary = Content.cpi_headlines
		if gas >= rules.gasoline_spike.threshold:
			out.append(_cpi_item(rules.gasoline_spike, gas))
		elif gas <= rules.gasoline_drop.threshold:
			out.append(_cpi_item(rules.gasoline_drop, gas))
		if groceries >= rules.food_home_spike.threshold:
			out.append(_cpi_item(rules.food_home_spike, groceries))
	return out


func _cpi_item(rule: Dictionary, change: float) -> Dictionary:
	return {"headline": rule.headline, "body": rule.body % int(round(absf(change) * 100.0))}


## plan = {location_id, offers: [{drink_id, price, servings}]}. Returns the day's result.
func plan_cost(plan: Dictionary) -> float:
	var loc := Content.location(plan.location_id)
	var total := Content.economy.trip_cost(loc, month()) + float(loc.permit)
	for o in plan.offers:
		total += o.servings * Content.economy.serving_cost(Content.drink(o.drink_id), month())
	for t in plan.get("treats", []):
		total += t.servings * Content.economy.serving_cost(Content.item(t.item_id), month())
	return total


## Starts a shift: locks in the plan and returns the Shift to play (by hand or auto_finish()).
func begin_shift(plan: Dictionary) -> Shift:
	var loc := Content.location(plan.location_id)
	var weather: Dictionary = Content.weather.types[weather_id]
	var econ: Economy = Content.economy
	var offers: Array = []
	var stock_cost := 0.0
	var drink_plan := {}
	for o in plan.offers:
		var d := Content.drink(o.drink_id)
		var cost_each := econ.serving_cost(d, month())
		offers.append({"drink": d, "price": o.price, "fair": econ.fair_price(d, month()), "stock": o.servings})
		stock_cost += o.servings * cost_each
		drink_plan[d.id] = {"stocked": o.servings, "price": o.price, "cost_each": cost_each}
	var treat_offers: Array = []
	for t in plan.get("treats", []):
		var item := Content.item(t.item_id)
		var cost_each := econ.serving_cost(item, month())
		treat_offers.append({"treat": item, "price": t.price, "fair": econ.fair_price(item, month()), "stock": t.servings})
		stock_cost += t.servings * cost_each
		drink_plan[item.id] = {"stocked": t.servings, "price": t.price, "cost_each": cost_each}
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + day * 104729
	var shift := Shift.new(offers, loc, weather, traffic_mult(loc.id), reputation, rng, Content.generations, treat_offers)
	_current = {
		"shift": shift, "loc": loc, "drink_plan": drink_plan, "stock_cost": stock_cost,
		"trip": econ.trip_cost(loc, month()), "permit": float(loc.permit), "rng": rng,
	}
	return shift


## Closes out the current shift: pays costs, updates reputation, records and returns the result.
func finish_shift(mode: String = "auto") -> Dictionary:
	var shift: Shift = _current.shift
	var loc: Dictionary = _current.loc
	var sh: Dictionary = shift.result
	var costs: float = _current.trip + _current.permit + _current.stock_cost
	var profit: float = sh.revenue + sh.tips - costs
	cash += profit

	var attempted: int = sh.served + sh.lost_to_stockout + sh.lost_to_line + sh.declined
	var satisfaction := float(sh.served) / attempted if attempted > 0 else 1.0
	reputation = clampf(reputation + (satisfaction - 0.8) * 0.1, 0.7, 1.5)

	var drinks := {}
	for id in _current.drink_plan:
		var dp: Dictionary = _current.drink_plan[id]
		var n: int = sh.sold.get(id, sh.treats_sold.get(id, 0))
		drinks[id] = {
			"stocked": dp.stocked, "sold": n, "price": dp.price, "cost_each": dp.cost_each,
			"profit": n * dp.price - dp.stocked * dp.cost_each,
		}

	var result := {
		"day": day, "location_id": loc.id, "weather_id": weather_id, "month": month(), "mode": mode,
		"shift": sh, "drinks": drinks, "trip_cost": _current.trip, "permit": _current.permit,
		"stock_cost": _current.stock_cost, "costs": costs, "revenue": sh.revenue, "tips": sh.tips,
		"profit": profit, "cash": cash, "reputation": reputation,
		"quip": _pick_quip(profit, satisfaction, _current.rng),
		"chatter": _pick_chatter(sh, _current.rng),
	}
	result["insights"] = insights(result)
	history.append(result)
	day += 1
	_current = {}
	if not is_game_over():
		begin_day()
	return result


## Breeze through a whole day with default choices.
func run_day(plan: Dictionary) -> Dictionary:
	begin_shift(plan).auto_finish()
	return finish_shift("auto")


func last_result() -> Dictionary:
	return history.back() if not history.is_empty() else {}


## The most recent day spent at this location (or {} if never visited).
func last_visit(location_id: String) -> Dictionary:
	for i in range(history.size() - 1, -1, -1):
		if history[i].location_id == location_id:
			return history[i]
	return {}


## Plain-language lessons from a day: what to change next time.
func insights(r: Dictionary) -> Array:
	var out: Array = []
	var best_id := ""
	var best_profit := -INF
	for id in r.drinks:
		var d: Dictionary = r.drinks[id]
		var drink := Content.item(id)
		if d.profit > best_profit:
			best_profit = d.profit
			best_id = id
		if d.stocked > 0 and d.sold >= d.stocked:
			out.append("%s sold out. People wanted more, so stock extra next time." % drink.name)
		elif d.stocked >= 8 and d.sold * 2 < d.stocked:
			var wasted: float = (d.stocked - d.sold) * d.cost_each
			out.append("%s only sold %d of %d, about %s of ingredients wasted. Stock fewer, or try another spot." % [drink.name, d.sold, d.stocked, "$%.0f" % wasted])
	if best_id != "":
		out.push_front("%s was your money-maker (%s profit)." % [Content.item(best_id).name, "$%.0f" % best_profit])
	if r.shift.lost_to_line > 3:
		out.append("%d people gave up on the line. Chatty customers and add-on offers eat up time." % r.shift.lost_to_line)
	return out.slice(0, 4)


func _tier(profit: float, satisfaction: float) -> String:
	if profit >= 250.0 and satisfaction >= 0.9:
		return "great"
	if profit < 50.0 or satisfaction < 0.7:
		return "bad"
	return "ok"


func _pick_quip(profit: float, satisfaction: float, rng: RandomNumberGenerator) -> Dictionary:
	var tier := _tier(profit, satisfaction)
	var who: Dictionary = Content.characters[rng.randi() % Content.characters.size()]
	var pool: Array = who.lines[tier]
	return {"character": who, "tier": tier, "line": pool[rng.randi() % pool.size()]}


## A line from the generation that chatted the most (null when nobody cornered you).
func _pick_chatter(shift: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var best := ""
	var best_count := 0
	for gen_id in shift.chats_by_gen:
		if shift.chats_by_gen[gen_id] > best_count:
			best = gen_id
			best_count = shift.chats_by_gen[gen_id]
	if best.is_empty():
		return {}
	var pool: Array = Content.dialogue[best].chat
	return {"generation": best, "count": shift.chats, "line": pool[rng.randi() % pool.size()]}
