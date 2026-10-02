extends Node
## Run state: money, day, reputation, the day's weather and news, and the shift runner.

const START_CASH := 1000.0
const MIN_PLAYABLE_CASH := 25.0

var cash := START_CASH
var day := 1
var reputation := 1.0
var run_seed := 1
var weather_id := "sunny"
var headlines: Array = []   ## [{headline, body}] shown in the morning briefing
var history: Array = []     ## one result dict per finished day
var language_mode := "generational"  ## "generational" (each age group speaks its own slang) or "gen_z" (everyone talks Gen Z)


func new_game(seed_value: int = 0, language: String = "generational") -> void:
	language_mode = language
	run_seed = seed_value if seed_value != 0 else int(Time.get_unix_time_from_system())
	cash = START_CASH
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
	return total


func run_day(plan: Dictionary) -> Dictionary:
	var loc := Content.location(plan.location_id)
	var weather: Dictionary = Content.weather.types[weather_id]
	var econ: Economy = Content.economy
	var trip := econ.trip_cost(loc, month())
	var permit := float(loc.permit)
	var offers: Array = []
	var stock_cost := 0.0
	for o in plan.offers:
		var d := Content.drink(o.drink_id)
		offers.append({"drink": d, "price": o.price, "fair": econ.fair_price(d, month()), "stock": o.servings})
		stock_cost += o.servings * econ.serving_cost(d, month())

	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed + day * 104729
	var shift := Demand.simulate_shift(offers, loc, weather, traffic_mult(loc.id), reputation, rng, Content.generations)

	var costs := trip + permit + stock_cost
	var profit: float = shift.revenue + shift.tips - costs
	cash += profit

	var attempted: int = shift.served + shift.lost_to_stockout + shift.lost_to_line
	var satisfaction := float(shift.served) / attempted if attempted > 0 else 1.0
	reputation = clampf(reputation + (satisfaction - 0.8) * 0.1, 0.7, 1.5)

	var result := {
		"day": day, "location_id": loc.id, "weather_id": weather_id, "month": month(),
		"shift": shift, "trip_cost": trip, "permit": permit, "stock_cost": stock_cost,
		"revenue": shift.revenue, "tips": shift.tips, "profit": profit, "cash": cash, "reputation": reputation,
		"quip": _pick_quip(profit, satisfaction, rng),
		"chatter": _pick_chatter(shift, rng),
	}
	history.append(result)
	day += 1
	if not is_game_over():
		begin_day()
	return result


## Which voice a generation uses: its own, or Gen Z for everyone in "gen_z" mode.
func voice_for(generation: String) -> String:
	return generation if language_mode == "generational" else "gen_z"


func _tier(profit: float, satisfaction: float) -> String:
	if profit >= 250.0 and satisfaction >= 0.9:
		return "great"
	if profit < 50.0 or satisfaction < 0.7:
		return "bad"
	return "ok"


func _pick_quip(profit: float, satisfaction: float, rng: RandomNumberGenerator) -> Dictionary:
	var tier := _tier(profit, satisfaction)
	var who: Dictionary = Content.characters[rng.randi() % Content.characters.size()]
	var pool: Array = who.lines[tier] if language_mode == "generational" else Content.dialogue.gen_z[tier]
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
	var pool: Array = Content.dialogue[voice_for(best)].chat
	return {"generation": best, "count": shift.chats, "line": pool[rng.randi() % pool.size()]}
