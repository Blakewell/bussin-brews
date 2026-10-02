class_name Economy
extends RefCounted
## Real-world pricing: every dollar amount scales with the matching CPI series
## relative to the base month (the month the reference prices were set in).

const BASE_GAS_PRICE := 3.10  ## Approximate US average $/gal in the base month
const TRUCK_MPG := 6.0
const SHIFT_HOURS := 6

var cpi: Cpi
var base_month: String


func _init(cpi_data: Cpi, base: String) -> void:
	cpi = cpi_data
	base_month = base


## What a drink "should" cost this month; the demand model compares your price to this.
func fair_price(drink: Dictionary, month: String) -> float:
	return drink.ref_price * cpi.ratio("food_away", month, base_month)


func serving_cost(drink: Dictionary, month: String, cost_mult: float = 1.0) -> float:
	return drink.ref_cost * cpi.ratio("food_home", month, base_month) * cost_mult


func gas_price(month: String, fuel_mult: float = 1.0) -> float:
	return BASE_GAS_PRICE * cpi.ratio("gasoline", month, base_month) * fuel_mult


func trip_cost(location: Dictionary, month: String, fuel_mult: float = 1.0) -> float:
	var round_trip_miles: float = location.miles * 2.0
	return round_trip_miles / TRUCK_MPG * gas_price(month, fuel_mult)
