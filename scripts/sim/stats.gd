class_name Stats
extends RefCounted
## Numbers for the Stats screen, computed from GameState.history (one result per finished day).
## Pure functions over plain dictionaries, so they're testable without the UI.

## What a day can be grouped by, and the result field that holds it.
const GROUP_FIELDS := {"location": "location_id", "weather": "weather_id", "tips": "tip_mode"}

## Daily totals the graph can show. Item sales use "item:<id>".
const METRICS := ["profit", "revenue", "tips", "served"]


static func group_key(day: Dictionary, by: String) -> String:
	return str(day.get(GROUP_FIELDS.get(by, "location_id"), "jar" if by == "tips" else ""))


## One day's value for a metric. Missing data (older saves) counts as 0.
static func metric_value(day: Dictionary, metric: String) -> float:
	if metric.begins_with("item:"):
		var info: Dictionary = day.get("drinks", {}).get(metric.substr(5), {})
		return float(info.get("sold", 0))
	if metric == "served":
		if day.has("served"):
			return float(day.served)
		return float(day.get("shift", {}).get("served", 0))
	return float(day.get(metric, 0.0))


## [{day, value, group}] in day order, for the daily graph.
static func daily_series(history: Array, metric: String, by: String) -> Array:
	var out: Array = []
	for d in history:
		out.append({"day": int(d.day), "value": metric_value(d, metric), "group": group_key(d, by)})
	return out


## {group: {avg, total, days}} for a metric across all days in each group.
static func group_averages(history: Array, metric: String, by: String) -> Dictionary:
	var out := {}
	for d in history:
		var g := group_key(d, by)
		if not out.has(g):
			out[g] = {"avg": 0.0, "total": 0.0, "days": 0}
		out[g].total += metric_value(d, metric)
		out[g].days += 1
	for g in out:
		out[g].avg = out[g].total / out[g].days
	return out


## How each item sold in each group, counting only days it was on the menu (stocked > 0):
## {item_id: {group: {avg_sold, sell_through, days, sold_out}}}.
## sold_out counts days it ran out, which means real demand was higher than the sales show.
static func item_table(history: Array, by: String) -> Dictionary:
	var acc := {}
	for d in history:
		var g := group_key(d, by)
		for id in d.get("drinks", {}):
			var info: Dictionary = d.drinks[id]
			var stocked := int(info.get("stocked", 0))
			if stocked <= 0:
				continue
			var sold := int(info.get("sold", 0))
			if not acc.has(id):
				acc[id] = {}
			if not acc[id].has(g):
				acc[id][g] = {"sold": 0, "stocked": 0, "days": 0, "sold_out": 0}
			var cell: Dictionary = acc[id][g]
			cell.sold += sold
			cell.stocked += stocked
			cell.days += 1
			if sold >= stocked:
				cell.sold_out += 1
	var out := {}
	for id in acc:
		out[id] = {}
		for g in acc[id]:
			var c: Dictionary = acc[id][g]
			out[id][g] = {
				"avg_sold": float(c.sold) / c.days,
				"sell_through": float(c.sold) / c.stocked,
				"days": c.days, "sold_out": c.sold_out,
			}
	return out


## The group where an item sells the most per day, or "" when it has data in fewer than two groups.
static func best_group(row: Dictionary) -> String:
	if row.size() < 2:
		return ""
	var best := ""
	var best_avg := -1.0
	for g in row:
		if row[g].avg_sold > best_avg:
			best_avg = row[g].avg_sold
			best = g
	return best
