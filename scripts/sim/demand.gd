class_name Demand
extends RefCounted
## Turns location, weather, generations, prices and stock into a day's sales.

const ARRIVALS_PER_TRAFFIC := 2.4  ## shift arrivals per point of base_traffic
const WALK_AWAY_WEIGHT := 4.0      ## higher means fewer arrivals buy anything
const SHIFT_CAPACITY := 90.0       ## service slots in a shift; chatty customers use extra
const UPSELL_BASE := 0.30          ## chance a typical customer adds a treat they'd like
const UPSELL_TIME := 0.25          ## service slots each add-on offer costs (pushing slows the line)
const AUTO_UPSELL_SKILL := 0.6     ## autopilot staff are less persuasive than you


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


## Runs a whole shift on autopilot. `offers` is an Array of {drink, price, fair, stock};
## `generations` is the Content.generations dict. See Shift for the result keys.
static func simulate_shift(offers: Array, location: Dictionary, weather: Dictionary, traffic_mult: float, reputation: float, rng: RandomNumberGenerator, generations: Dictionary) -> Dictionary:
	var shift := Shift.new(offers, location, weather, traffic_mult, reputation, rng, generations)
	shift.auto_finish()
	return shift.result
