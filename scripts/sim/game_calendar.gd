class_name GameCalendar
extends RefCounted
## Maps game days onto real calendar months so real CPI data drives prices.

const START_MONTH := "2026-01"
const DAYS_PER_MONTH := 10
const MONTH_NAMES := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]


static func month_key(day: int) -> String:
	var parts := START_MONTH.split("-")
	var index := int(parts[0]) * 12 + int(parts[1]) - 1 + (day - 1) / DAYS_PER_MONTH
	return "%04d-%02d" % [index / 12, index % 12 + 1]


static func previous_month(key: String) -> String:
	var parts := key.split("-")
	var index := int(parts[0]) * 12 + int(parts[1]) - 2
	return "%04d-%02d" % [index / 12, index % 12 + 1]


static func is_month_start(day: int) -> bool:
	return (day - 1) % DAYS_PER_MONTH == 0


static func label(day: int) -> String:
	var parts := month_key(day).split("-")
	var day_of_month := (day - 1) % DAYS_PER_MONTH + 1
	return "%s %d, %s" % [MONTH_NAMES[int(parts[1]) - 1], day_of_month, parts[0]]


static func season(day: int) -> String:
	var m := int(month_key(day).split("-")[1])
	if m == 12 or m <= 2:
		return "winter"
	if m <= 5:
		return "spring"
	if m <= 8:
		return "summer"
	return "fall"
