class_name StatsChart
extends Control
## Daily bar graph: one bar per day, colored by group (location, weather, ...). Hover a bar for details.

var points: Array = []       ## [{day, value, group}] from Stats.daily_series
var colors := {}             ## group -> Color
var labels := {}             ## group -> display name, for tooltips
var money := true            ## format values as dollars

const PAD_LEFT := 56.0
const PAD_BOTTOM := 24.0
const PAD_TOP := 10.0
const MAX_BAR := 36.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS  # let the scroll wheel reach the page
	tooltip_text = "day"  # non-empty so Godot asks _get_tooltip for the hovered bar


func set_data(p: Array, c: Dictionary, l: Dictionary, is_money: bool) -> void:
	points = p
	colors = c
	labels = l
	money = is_money
	queue_redraw()


func _fmt(v: float) -> String:
	if not money:
		return str(int(round(v)))
	return ("-$%d" % int(round(absf(v)))) if v < 0.0 else ("$%d" % int(round(v)))


## Value range, always including zero, rounded out to a friendly step.
func _range() -> Vector3:
	var lo := 0.0
	var hi := 0.0
	for p in points:
		lo = minf(lo, p.value)
		hi = maxf(hi, p.value)
	if hi - lo < 1.0:
		hi = lo + (10.0 if money else 5.0)
	var raw := (hi - lo) / 4.0
	var mag := pow(10.0, floor(log(raw) / log(10.0)))
	var step := mag
	for m in [1.0, 2.0, 2.5, 5.0, 10.0]:
		if m * mag >= raw:
			step = m * mag
			break
	return Vector3(floor(lo / step) * step, ceil(hi / step) * step, step)


func _plot() -> Rect2:
	return Rect2(PAD_LEFT, PAD_TOP, maxf(10.0, size.x - PAD_LEFT - 8.0), maxf(10.0, size.y - PAD_TOP - PAD_BOTTOM))


func _y(v: float, r: Vector3, plot: Rect2) -> float:
	return plot.end.y - (v - r.x) / (r.y - r.x) * plot.size.y


func _slot() -> float:
	return _plot().size.x / maxf(1.0, points.size())


func _draw() -> void:
	var font := get_theme_default_font()
	var plot := _plot()
	if points.is_empty():
		draw_string(font, Vector2(plot.position.x, plot.get_center().y), "Finish a day to start the graph.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Palette.MUTED)
		return
	var r := _range()
	# gridlines and y labels
	var v := r.x
	while v <= r.y + 0.001:
		var y := _y(v, r, plot)
		var line_col := Palette.TEXT if is_zero_approx(v) else Palette.MUTED.lerp(Palette.BG, 0.7)
		draw_line(Vector2(plot.position.x, y), Vector2(plot.end.x, y), line_col, 1.0)
		draw_string(font, Vector2(0, y + 5), _fmt(v), HORIZONTAL_ALIGNMENT_RIGHT, PAD_LEFT - 8, 13, Palette.MUTED)
		v += r.z
	# bars
	var slot := _slot()
	var bar := minf(MAX_BAR, slot * 0.72)
	var zero := _y(0.0, r, plot)
	var label_every := maxi(1, int(ceil(28.0 / slot)))
	for i in points.size():
		var p: Dictionary = points[i]
		var cx := plot.position.x + slot * (i + 0.5)
		var top := _y(p.value, r, plot)
		var rect := Rect2(cx - bar / 2.0, minf(top, zero), bar, maxf(1.5, absf(zero - top)))
		draw_rect(rect, colors.get(p.group, Palette.MUTED))
		if p.value < 0.0:
			draw_rect(rect, Palette.WARM, false, 2.0)
		if i % label_every == 0 or i == points.size() - 1:
			draw_string(font, Vector2(cx - 20, size.y - 6), str(p.day), HORIZONTAL_ALIGNMENT_CENTER, 40, 12, Palette.MUTED)


func _get_tooltip(at: Vector2) -> String:
	if points.is_empty():
		return ""
	var i := int((at.x - _plot().position.x) / _slot())
	if i < 0 or i >= points.size():
		return ""
	var p: Dictionary = points[i]
	return "Day %d · %s\n%s" % [p.day, labels.get(p.group, p.group), _fmt(p.value)]
