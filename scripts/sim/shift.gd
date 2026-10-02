class_name Shift
extends RefCounted
## One service shift, processed a customer at a time. The player can serve each buyer
## by hand, or call auto_finish() to breeze through the rest with default choices.
## Both paths use the same demand model, so manual play is a skill layer on top of it.

var offers: Array
var location: Dictionary
var weather: Dictionary
var generations: Dictionary
var rng: RandomNumberGenerator
var treat_offers: Array
var stock := {}
var sold := {}
var treat_stock := {}
var treats_sold := {}
var result := {}
var used := 0.0          ## service slots consumed (chatty customers use extra)
var arrivals := 0
var remaining := 0       ## arrivals not yet processed
var events: Array = []   ## people who didn't buy: {kind, gen_id}; drain with drain_events()


func _init(offer_list: Array, loc: Dictionary, wx: Dictionary, traffic_mult: float, reputation: float, random: RandomNumberGenerator, gens: Dictionary, treat_list: Array = []) -> void:
	offers = offer_list
	location = loc
	weather = wx
	generations = gens
	rng = random
	arrivals = int(round(loc.base_traffic * Demand.ARRIVALS_PER_TRAFFIC * wx.traffic * traffic_mult * reputation))
	remaining = arrivals
	treat_offers = treat_list
	for o in offers:
		stock[o.drink.id] = int(o.stock)
		sold[o.drink.id] = 0
	for t in treat_offers:
		treat_stock[t.treat.id] = int(t.stock)
		treats_sold[t.treat.id] = 0
	result = {
		"sold": sold, "treats_sold": treats_sold, "treat_revenue": 0.0, "upsell_attempts": 0, "upsell_declined": 0, "revenue": 0.0, "tips": 0.0, "chats": 0, "arrivals": arrivals, "served": 0,
		"lost_to_stockout": 0, "lost_to_line": 0, "walked_away": 0, "declined": 0, "skipped": 0, "cut_short": 0,
		"served_by_gen": {}, "tips_by_gen": {}, "chats_by_gen": {},
	}


## People who passed by without buying since the last call (for the street scene).
func drain_events() -> Array:
	var out := events
	events = []
	return out


func progress() -> float:
	return 1.0 - float(remaining) / maxf(arrivals, 1)


func offer(drink_id: String) -> Dictionary:
	for o in offers:
		if o.drink.id == drink_id:
			return o
	return {}


## Advances to the next customer who wants to buy. Walk-aways, stockouts and a full line
## are resolved automatically. Returns {} when the shift is over.
func next_customer() -> Dictionary:
	while remaining > 0:
		remaining -= 1
		if used >= Demand.SHIFT_CAPACITY:
			result.lost_to_line += 1
			events.append({"kind": "line", "gen_id": ""})
			continue
		var gen_id := Demand.roll_generation(location.generations, rng)
		var gen: Dictionary = generations[gen_id]
		var weights := {}
		var total_all := 0.0
		var total_stock := 0.0
		for o in offers:
			var w := Demand.appeal(o.drink, location, weather, gen, o.price, o.fair)
			weights[o.drink.id] = w
			total_all += w
			if stock[o.drink.id] > 0:
				total_stock += w
		var desire: float = total_all * gen.buy_rate
		if rng.randf() >= desire / (desire + Demand.WALK_AWAY_WEIGHT):
			result.walked_away += 1
			events.append({"kind": "walked_away", "gen_id": gen_id})
			continue
		if total_stock <= 0.0:
			result.lost_to_stockout += 1
			events.append({"kind": "stockout", "gen_id": gen_id})
			continue
		var craving := ""
		var pick := rng.randf() * total_stock
		for o in offers:
			if stock[o.drink.id] > 0:
				craving = o.drink.id
				pick -= weights[craving]
				if pick <= 0.0:
					break
		var names: Array = gen.names
		return {
			"gen_id": gen_id, "name": names[rng.randi() % names.size()], "weights": weights,
			"craving": craving, "wants_chat": rng.randf() < gen.chat_chance,
		}
	return {}


## Serve a drink to a customer. `engage_chat` only matters when they want to chat.
## Returns {sold, price, tip, declined, engaged}.
func serve(c: Dictionary, drink_id: String, engage_chat := true) -> Dictionary:
	var out := {"sold": false, "price": 0.0, "tip": 0.0, "declined": false, "engaged": false}
	if stock.get(drink_id, 0) <= 0:
		return out
	# Offering something other than what they came for can be turned down.
	if drink_id != c.craving:
		var accept := clampf(c.weights[drink_id] / maxf(c.weights[c.craving], 0.001), 0.0, 1.0)
		if rng.randf() >= accept:
			result.declined += 1
			out.declined = true
			return out
	var o := offer(drink_id)
	var gen: Dictionary = generations[c.gen_id]
	stock[drink_id] -= 1
	sold[drink_id] += 1
	result.served += 1
	result.revenue += o.price
	used += 1.0
	_add(result.served_by_gen, c.gen_id, 1)
	out.sold = true
	out.price = o.price
	c["sold_drink"] = drink_id

	var tip_chance: float = gen.tip_chance
	if c.wants_chat:
		if engage_chat:
			tip_chance *= 1.5
			out.engaged = true
			result.chats += 1
			used += gen.chat_slots
			_add(result.chats_by_gen, c.gen_id, 1)
		else:
			tip_chance *= 0.6
			result.cut_short += 1
	if rng.randf() < tip_chance:
		var tip := maxf(snappedf(o.price * gen.tip_pct, 0.25), 0.25)
		result.tips += tip
		out.tip = tip
		_add(result.tips_by_gen, c.gen_id, tip)
	return out


func treat_offer(treat_id: String) -> Dictionary:
	for t in treat_offers:
		if t.treat.id == treat_id:
			return t
	return {}


func has_treats_in_stock() -> bool:
	for id in treat_stock:
		if treat_stock[id] > 0:
			return true
	return false


## Chance this customer adds this treat after buying a drink: generation taste, how well it
## pairs with their drink, and the price.
func treat_chance(c: Dictionary, treat_id: String) -> float:
	var t := treat_offer(treat_id)
	var p: float = Demand.UPSELL_BASE * float(t.treat.gen_fit.get(c.gen_id, 1.0))
	var drink: Dictionary = offer(c.get("sold_drink", c.craving)).drink
	for tag in drink.tags:
		p *= float(t.treat.pairs_with.get(tag, 1.0))
	p *= Demand.price_factor(t.price, t.fair, location.price_sensitivity)
	return clampf(p, 0.02, 0.9)


## Offer a treat. Each offer costs a little service time, so spamming slows the line.
func upsell(c: Dictionary, treat_id: String, skill := 1.0) -> Dictionary:
	var out := {"accepted": false, "price": 0.0}
	if treat_stock.get(treat_id, 0) <= 0:
		return out
	result.upsell_attempts += 1
	used += Demand.UPSELL_TIME
	if rng.randf() < treat_chance(c, treat_id) * skill:
		var t := treat_offer(treat_id)
		treat_stock[treat_id] -= 1
		treats_sold[treat_id] += 1
		result.revenue += t.price
		result.treat_revenue += t.price
		out.accepted = true
		out.price = t.price
	else:
		result.upsell_declined += 1
	return out


## What an autopilot cashier does: suggest the treat this customer is likeliest to take.
func auto_upsell(c: Dictionary) -> void:
	var best := ""
	var best_p := 0.1
	for id in treat_stock:
		if treat_stock[id] > 0:
			var p := treat_chance(c, id)
			if p > best_p:
				best_p = p
				best = id
	if best != "":
		upsell(c, best, Demand.AUTO_UPSELL_SKILL)


func skip(_c: Dictionary) -> void:
	result.skipped += 1


## Default play for the rest of the shift: give everyone what they asked for, chat with all.
func auto_finish() -> void:
	var c := next_customer()
	while not c.is_empty():
		if serve(c, c.craving, true).sold:
			auto_upsell(c)
		c = next_customer()


static func _add(dict: Dictionary, key: String, amount) -> void:
	dict[key] = dict.get(key, 0) + amount
