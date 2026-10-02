class_name Demand
extends RefCounted
## Turns location, weather, generations, prices and stock into a day's sales.

const ARRIVALS_PER_TRAFFIC := 2.4  ## shift arrivals per point of base_traffic
const WALK_AWAY_WEIGHT := 4.0      ## higher means fewer arrivals buy anything
const SHIFT_CAPACITY := 90.0       ## service slots in a shift; chatty customers use extra


static func price_factor(price: float, fair: float, sensitivity: float) -> float:
	return clampf(exp(-sensitivity * (price / fair - 1.0)), 0.05, 1.6)


## How attractive a drink is to this crowd, generation and weather at this price.
static func appeal(drink: Dictionary, location: Dictionary, weather: Dictionary, generation: Dictionary, price: float, fair: float) -> float:
	var tag_total := 0.0
	for tag in drink.tags:
		tag_total += float(location.crowd.get(tag, 1.0)) * float(weather.tag_fit.get(tag, 1.0)) * float(generation.tag_fit.get(tag, 1.0))
	var tag_score: float = tag_total / drink.tags.size()
	return tag_score * price_factor(price, fair, location.price_sensitivity)


static func roll_generation(mix: Dictionary, rng: RandomNumberGenerator) -> String:
	var total := 0.0
	for k in mix:
		total += mix[k]
	var pick := rng.randf() * total
	var last := ""
	for k in mix:
		last = k
		pick -= mix[k]
		if pick <= 0.0:
			return k
	return last


## `offers` is an Array of {drink, price, fair, stock}; `generations` is the Content.generations dict.
## Returns {sold, revenue, tips, chats, served, arrivals, lost_to_stockout, lost_to_line, walked_away,
## served_by_gen, tips_by_gen, chats_by_gen}.
static func simulate_shift(offers: Array, location: Dictionary, weather: Dictionary, traffic_mult: float, reputation: float, rng: RandomNumberGenerator, generations: Dictionary) -> Dictionary:
	var arrivals := int(round(location.base_traffic * ARRIVALS_PER_TRAFFIC * weather.traffic * traffic_mult * reputation))
	var stock := {}
	var sold := {}
	for o in offers:
		stock[o.drink.id] = int(o.stock)
		sold[o.drink.id] = 0
	var result := {
		"sold": sold, "revenue": 0.0, "tips": 0.0, "chats": 0, "arrivals": arrivals, "served": 0,
		"lost_to_stockout": 0, "lost_to_line": 0, "walked_away": 0,
		"served_by_gen": {}, "tips_by_gen": {}, "chats_by_gen": {},
	}
	var used := 0.0

	for i in arrivals:
		if used >= SHIFT_CAPACITY:
			result.lost_to_line += 1
			continue
		var gen_id := roll_generation(location.generations, rng)
		var gen: Dictionary = generations[gen_id]
		var weights: Array[float] = []
		var total := 0.0
		var wanted_any := 0.0
		for o in offers:
			var w := appeal(o.drink, location, weather, gen, o.price, o.fair)
			wanted_any += w
			if stock[o.drink.id] > 0:
				weights.append(w)
				total += w
			else:
				weights.append(0.0)
		# Would they have bought if everything were in stock? Younger folks buy drinks more often.
		var desire: float = wanted_any * gen.buy_rate
		if rng.randf() >= desire / (desire + WALK_AWAY_WEIGHT):
			result.walked_away += 1
			continue
		if total <= 0.0:
			result.lost_to_stockout += 1
			continue
		var pick := rng.randf() * total
		for idx in offers.size():
			pick -= weights[idx]
			if pick <= 0.0 and weights[idx] > 0.0:
				var o: Dictionary = offers[idx]
				stock[o.drink.id] -= 1
				sold[o.drink.id] += 1
				result.served += 1
				result.revenue += o.price
				used += 1.0
				_add(result.served_by_gen, gen_id, 1)
				if rng.randf() < gen.tip_chance:
					var tip := snappedf(o.price * gen.tip_pct, 0.25)
					tip = maxf(tip, 0.25)
					result.tips += tip
					_add(result.tips_by_gen, gen_id, tip)
				if rng.randf() < gen.chat_chance:
					result.chats += 1
					used += gen.chat_slots
					_add(result.chats_by_gen, gen_id, 1)
				break
	return result


static func _add(dict: Dictionary, key: String, amount) -> void:
	dict[key] = dict.get(key, 0) + amount
