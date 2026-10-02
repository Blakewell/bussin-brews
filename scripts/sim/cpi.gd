class_name Cpi
extends RefCounted
## Monthly Consumer Price Index lookups backed by data/cpi.json (BLS CPI-U).
## Months with no published value carry the last known value forward.

var _series: Dictionary = {}


func _init(data: Dictionary) -> void:
	_series = data.get("series", {})


func value(series_name: String, month_key: String) -> float:
	var months: Dictionary = _series.get(series_name, {})
	var keys: Array = months.keys()
	keys.sort()
	var result := -1.0
	for k in keys:
		if k > month_key:
			break
		result = months[k]
	if result < 0.0 and not keys.is_empty():
		result = months[keys[0]]
	return result


func ratio(series_name: String, month_key: String, base_key: String) -> float:
	var base := value(series_name, base_key)
	return value(series_name, month_key) / base if base > 0.0 else 1.0


## Month-over-month change as a fraction (0.05 = +5%).
func change(series_name: String, month_key: String) -> float:
	var prev := GameCalendar.previous_month(month_key)
	var before := value(series_name, prev)
	return value(series_name, month_key) / before - 1.0 if before > 0.0 else 0.0


func last_month() -> String:
	var latest := ""
	for name in _series:
		for k in _series[name]:
			if k > latest:
				latest = k
	return latest
