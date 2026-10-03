class_name TruckScene
extends Control
## The illustrated street scene: sky, location backdrop, the truck with its barista, weather,
## and flat people walking by. Everything is drawn from shapes in a 360-unit-tall world that
## scales to fit, so the same scene works as a big stage or a small banner.

const WORLD_H := 360.0
const LANE_Y := 331.0       ## where customers stand, just below the counter
const PASSER_Y := 317.0     ## a second lane for people walking past
const TRUCK_BOTTOM := 272.0
const GROUND_TOP := 258.0

const GROUND := {"school": Color("DCE3D0"), "beach": Color("F0DFBE"), "office": Color("D9DEE4")}

var loc_id := "school"
var weather_id := "sunny"
var progress := 0.15       ## 0 = dawn, 0.5 = midday, 1 = dusk
var ambient := false       ## when true, strangers stroll by on their own

var _world: Node2D
var _bg: _Layer
var _truck_back: _Layer
var _barista_layer: Node2D
var _truck_front: _Layer
var _people: Node2D
var _fx: _Layer
var _wv := 1184.0
var _t := 0.0
var _barista: Person
var _customer: Person
var _drops: Array = []
var _ambient_timer := 1.0
var _rng := RandomNumberGenerator.new()
var _sb := StyleBoxFlat.new()


class _Layer extends Node2D:
	var draw_fn: Callable

	func _draw() -> void:
		if draw_fn.is_valid():
			draw_fn.call(self)


func _ready() -> void:
	clip_contents = true
	_rng.randomize()
	_world = Node2D.new()
	add_child(_world)
	_bg = _layer(_draw_bg)
	_truck_back = _layer(_draw_truck_back)
	_barista_layer = Node2D.new()
	_world.add_child(_barista_layer)
	_truck_front = _layer(_draw_truck_front)
	_people = Node2D.new()
	_world.add_child(_people)
	_fx = _layer(_draw_fx)

	_barista = Person.new().setup("millennial", 7)
	_barista.is_barista = true
	_barista.facing = -1.0
	_barista.scale = Vector2(0.85, 0.85)
	_barista_layer.add_child(_barista)
	for i in 70:
		_drops.append(Vector2(_rng.randf() * 1400.0, _rng.randf() * WORLD_H))
	resized.connect(_on_resized)
	_on_resized()


func _layer(fn: Callable) -> _Layer:
	var l := _Layer.new()
	l.draw_fn = fn
	_world.add_child(l)
	return l


func _on_resized() -> void:
	if _world == null or size.y < 20.0:
		return  # not laid out yet; a bogus size would scale the whole world wrong
	var s := maxf(size.y, 1.0) / WORLD_H
	_world.scale = Vector2(s, s)
	_wv = size.x / s
	_barista.position = Vector2(_window_x(), 268.0)
	for l in [_bg, _truck_back, _truck_front, _fx]:
		l.queue_redraw()


## True once the scene has a real size (people spawned before this get nonsense positions).
func is_laid_out() -> bool:
	return size.y >= 20.0 and size.x >= 20.0


func cx() -> float:
	return _wv * 0.5


func _window_x() -> float:
	return cx() - 90.0


func set_location(id: String) -> void:
	loc_id = id
	_bg.queue_redraw()


func set_weather(id: String) -> void:
	weather_id = id
	_bg.queue_redraw()


func set_progress(p: float) -> void:
	progress = clampf(p, 0.0, 1.0)
	_bg.queue_redraw()


# --- people ----------------------------------------------------------------

## A customer walks up to the window. Returns the Person; `arrived` fires when they're there.
func spawn_customer(name: String, gen_id: String, color: Color) -> Person:
	var from_left := _rng.randf() < 0.5
	var p := Person.new().setup(gen_id, hash(name) + _rng.randi())
	p.scale = Vector2(0.95, 0.95)
	p.position = Vector2(_window_x() + (-1.0 if from_left else 1.0) * 420.0, LANE_Y)
	p.fade_in()
	_people.add_child(p)
	p.set_tag("%s" % name, color)
	p.walk_to(_window_x())
	_customer = p
	return p


## The barista hands a drink over; the customer leaves holding it.
func hand_over(p: Person, cup_color: Color) -> void:
	if not is_instance_valid(p):
		return
	_barista.arm_raise = 1.0
	p.cup_color = cup_color
	p.has_cup = true
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func(): _barista.arm_raise = 0.0)


func send_away(p: Person, sad := false) -> void:
	if not is_instance_valid(p):
		return
	p.clear_tag()
	var dir := 1.0 if _rng.randf() < 0.5 else -1.0
	p.walk_to(p.position.x + dir * 520.0, 340.0 if not sad else 200.0, true)


## Someone who doesn't stop: crosses the scene on the back lane.
func spawn_passerby(gen_id := "") -> Person:
	if _people.get_child_count() > 9:
		return null
	var gens: Array = Content.generations.keys()
	var g: String = gen_id if gen_id != "" else gens[_rng.randi() % gens.size()]
	var from_left := _rng.randf() < 0.5
	var p := Person.new().setup(g, _rng.randi())
	p.scale = Vector2(0.8, 0.8)
	var half := _wv * 0.5 + 60.0
	p.position = Vector2(cx() + (-half if from_left else half), PASSER_Y)
	p.fade_in()
	_people.add_child(p)
	p.walk_to(cx() + (half if from_left else -half), 190.0, true)
	return p


## Floating text above the window, e.g. "+$6.00".
func float_text(text: String, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 24)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Palette.PANEL)
	l.add_theme_constant_override("outline_size", 6)
	l.position = Vector2(_window_x() - 30.0, 196.0)
	l.z_index = 30
	_world.add_child(l)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", 120.0, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tw.chain().tween_callback(l.queue_free)


func _process(delta: float) -> void:
	_t += delta
	if weather_id == "rainy":
		for i in _drops.size():
			var d: Vector2 = _drops[i]
			d += Vector2(-60.0, 520.0) * delta
			if d.y > WORLD_H:
				d = Vector2(_rng.randf() * (_wv + 200.0), -10.0)
			_drops[i] = d
	_fx.queue_redraw()
	if ambient:
		_ambient_timer -= delta
		if _ambient_timer <= 0.0:
			_ambient_timer = _rng.randf_range(1.6, 3.4)
			spawn_passerby()
			if _rng.randf() < 0.35 and _customer_free():
				_ambient_customer()


func _customer_free() -> bool:
	return _customer == null or not is_instance_valid(_customer)


## For banner screens: a stranger walks up, pauses at the window, then leaves with a drink.
func _ambient_customer() -> void:
	var gens: Array = Content.generations.keys()
	var g: String = gens[_rng.randi() % gens.size()]
	var p := Person.new().setup(g, _rng.randi())
	p.scale = Vector2(0.95, 0.95)
	var from_left := _rng.randf() < 0.5
	p.position = Vector2(_window_x() + (-1.0 if from_left else 1.0) * 420.0, LANE_Y)
	p.fade_in()
	_people.add_child(p)
	p.walk_to(_window_x())
	_customer = p
	# One-shot: `arrived` fires again when they walk off, which must not restart the order.
	p.arrived.connect(func():
		var tw := create_tween()
		tw.tween_interval(0.9)
		tw.tween_callback(func(): hand_over(p, Palette.ACCENT))
		tw.tween_interval(0.5)
		tw.tween_callback(func(): send_away(p)), CONNECT_ONE_SHOT)


# --- drawing ---------------------------------------------------------------

func _rr(c: CanvasItem, rect: Rect2, color: Color, radius := 8) -> void:
	_sb.bg_color = color
	_sb.set_corner_radius_all(radius)
	c.draw_style_box(_sb, rect)


func _ellipse(c: CanvasItem, center: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	c.draw_colored_polygon(pts, color)


func _sky_colors() -> Array:
	var dawn := [Color("F6D5C0"), Color("FBEBD8")]
	var noon := [Color("B9D6E8"), Color("E9F1F2")]
	var dusk := [Color("E7B79A"), Color("F7DCC0")]
	var a: Array = dawn
	var b: Array = noon
	var k := progress * 2.0
	if progress > 0.5:
		a = noon
		b = dusk
		k = (progress - 0.5) * 2.0
	var top: Color = a[0].lerp(b[0], k)
	var bottom: Color = a[1].lerp(b[1], k)
	var tint := {"cloudy": Color("C9D2D8"), "rainy": Color("A9B6C4"), "cold": Color("C5D8E6"), "hot": Color("F2D9B0")}
	if tint.has(weather_id):
		var amount := 0.55 if weather_id == "rainy" else 0.4
		top = top.lerp(tint[weather_id], amount)
		bottom = bottom.lerp(tint[weather_id].lightened(0.2), amount)
	return [top, bottom]


func _draw_bg(c: CanvasItem) -> void:
	var sky := _sky_colors()
	var pts := PackedVector2Array([Vector2(0, 0), Vector2(_wv, 0), Vector2(_wv, GROUND_TOP + 4), Vector2(0, GROUND_TOP + 4)])
	c.draw_polygon(pts, PackedColorArray([sky[0], sky[0], sky[1], sky[1]]))
	_draw_sky_objects(c)
	match loc_id:
		"school": _draw_school(c)
		"beach": _draw_beach(c)
		"office": _draw_office(c)
	var ground: Color = GROUND.get(loc_id, Palette.SAGE)
	c.draw_rect(Rect2(0, GROUND_TOP, _wv, WORLD_H - GROUND_TOP), ground)
	c.draw_rect(Rect2(0, GROUND_TOP, _wv, 3.0), ground.darkened(0.08))
	# Road strip under the truck, then the sidewalk edge in front.
	c.draw_rect(Rect2(0, 274.0, _wv, 22.0), ground.darkened(0.10))
	c.draw_rect(Rect2(0, 296.0, _wv, 3.0), ground.lightened(0.25))
	for x in range(0, int(_wv), 90):
		c.draw_rect(Rect2(x + 10.0, 284.0, 40.0, 3.0), ground.lightened(0.35))


func _draw_sky_objects(c: CanvasItem) -> void:
	var sun_x := lerpf(_wv * 0.15, _wv * 0.85, progress)
	var sun_y := 130.0 - sin(progress * PI) * 70.0
	if weather_id == "sunny" or weather_id == "hot":
		var r := 34.0 if weather_id == "sunny" else 44.0
		var glow := Color("FBE3B5") if weather_id == "sunny" else Color("F7C98F")
		c.draw_circle(Vector2(sun_x, sun_y), r + 16.0, Color(glow, 0.35))
		c.draw_circle(Vector2(sun_x, sun_y), r, glow)
	if weather_id in ["cloudy", "rainy", "cold", "sunny"]:
		var count := 2 if weather_id == "sunny" else 4
		for i in count:
			var x := fposmod(_wv * (0.12 + 0.27 * i) + _t * (6.0 + 3.0 * i), _wv + 260.0) - 130.0
			_cloud(c, Vector2(x, 62.0 + 24.0 * (i % 2)), 1.0 if weather_id == "sunny" else 1.3)


func _cloud(c: CanvasItem, at: Vector2, s: float) -> void:
	var col := Color("F7F4EE") if weather_id != "rainy" else Color("D4DAE2")
	for off in [Vector2(-30, 6), Vector2(0, -6), Vector2(30, 4), Vector2(54, 10), Vector2(-52, 12)]:
		c.draw_circle(at + off * s, 22.0 * s, col)
	c.draw_rect(Rect2(at + Vector2(-56, 8) * s, Vector2(116, 24) * s), col)


func _draw_school(c: CanvasItem) -> void:
	var x0 := cx() - 560.0
	_rr(c, Rect2(x0, 116, 330, 142), Color("EBCFB4"), 6)
	c.draw_rect(Rect2(x0 - 8.0, 108, 346, 14), Color("C98F7A"))
	for row in 2:
		for col in 6:
			_rr(c, Rect2(x0 + 22.0 + col * 50.0, 138.0 + row * 50.0, 30, 34), Color("B7D1E3"), 4)
	_rr(c, Rect2(x0 + 140.0, 204, 50, 54), Color("9C7B58"), 6)
	c.draw_line(Vector2(x0 + 360.0, 258), Vector2(x0 + 360.0, 100), Color("8A8F96"), 3.0)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x0 + 362, 102), Vector2(x0 + 400, 112), Vector2(x0 + 362, 122)]), Palette.ACCENT)
	for tx in [cx() + 330.0, cx() + 470.0]:
		c.draw_rect(Rect2(tx - 6.0, 190, 12, 70), Color("A58968"))
		c.draw_circle(Vector2(tx, 168), 44.0, Color("A8C3A0"))
		c.draw_circle(Vector2(tx - 24.0, 186), 28.0, Color("98B592"))
	for fx in range(int(cx() + 200.0), int(_wv), 26):
		c.draw_rect(Rect2(fx, 226, 5, 32), Color("E7E1D3"))
	c.draw_rect(Rect2(cx() + 200.0, 236, _wv, 4), Color("E7E1D3"))


func _draw_beach(c: CanvasItem) -> void:
	var sea := Rect2(0, 150, _wv, 108)
	c.draw_polygon(PackedVector2Array([sea.position, Vector2(_wv, 150), Vector2(_wv, 258), Vector2(0, 258)]),
		PackedColorArray([Color("B5D3E0"), Color("B5D3E0"), Color("8FBBD0"), Color("8FBBD0")]))
	for i in 14:
		var wx := fposmod(i * 120.0 + _t * 10.0, _wv + 100.0) - 50.0
		c.draw_arc(Vector2(wx, 190.0 + (i % 3) * 22.0), 16.0, PI * 1.1, PI * 1.9, 10, Color("E9F3F6"), 3.0)
	c.draw_rect(Rect2(0, 150, _wv, 2.0), Color("E9F3F6"))
	# Umbrella.
	var ux := cx() - 470.0
	c.draw_line(Vector2(ux, 258), Vector2(ux, 196), Color("9C7B58"), 4.0)
	for i in 6:
		var a0 := PI + PI * float(i) / 6.0
		var a1 := PI + PI * float(i + 1) / 6.0
		var wedge := PackedVector2Array([Vector2(ux, 196), Vector2(ux, 196) + Vector2(cos(a0), sin(a0)) * 46.0, Vector2(ux, 196) + Vector2(cos(a1), sin(a1)) * 46.0])
		c.draw_colored_polygon(wedge, Palette.ACCENT.lerp(Palette.BG, 0.2) if i % 2 == 0 else Palette.PANEL)
	# Palm tree.
	var px := cx() + 420.0
	c.draw_colored_polygon(PackedVector2Array([Vector2(px - 7, 258), Vector2(px + 7, 258), Vector2(px + 14, 150), Vector2(px + 4, 148)]), Color("B08D66"))
	for ang in [-2.6, -2.1, -1.6, -1.1, -0.6]:
		var tip := Vector2(px + 9.0, 148.0) + Vector2(cos(ang), sin(ang)) * 62.0 + Vector2(0, 14)
		c.draw_line(Vector2(px + 9.0, 148.0), tip, Color("8FB58F"), 9.0, true)
	c.draw_circle(Vector2(px + 4.0, 152.0), 6.0, Color("8A6E4E"))


func _draw_office(c: CanvasItem) -> void:
	var cols := [Color("C9D2E0"), Color("D5CCE0"), Color("BFD3D0"), Color("E0D2C4")]
	var heights := [150.0, 118.0, 170.0, 100.0, 140.0, 122.0, 160.0]
	var x := -20.0
	var i := 0
	while x < _wv:
		var w := 96.0 + (i % 3) * 20.0
		var h: float = heights[i % heights.size()]
		var col: Color = cols[i % cols.size()]
		c.draw_rect(Rect2(x, GROUND_TOP - h, w, h), col)
		for wy in range(int(GROUND_TOP - h + 14.0), int(GROUND_TOP - 24.0), 26):
			for wx in range(int(x + 12.0), int(x + w - 18.0), 24):
				c.draw_rect(Rect2(wx, wy, 14, 14), col.lightened(0.45))
		x += w + 8.0
		i += 1
	for tx in [cx() - 480.0, cx() + 400.0]:
		c.draw_rect(Rect2(tx - 5.0, 214, 10, 46), Color("A58968"))
		c.draw_circle(Vector2(tx, 200), 30.0, Color("A8C3A0"))


func _draw_truck_back(c: CanvasItem) -> void:
	var x := cx()
	var body := Palette.PEACH.lerp(Palette.BG, 0.15)
	var trim := Palette.SAGE
	# Box body and cab.
	_rr(c, Rect2(x - 200, 128, 290, 146), body, 16)
	_rr(c, Rect2(x + 78, 176, 96, 98), body.darkened(0.04), 14)
	c.draw_colored_polygon(PackedVector2Array([Vector2(x + 96, 188), Vector2(x + 140, 188), Vector2(x + 162, 224), Vector2(x + 96, 224)]), Color("BFD6E4"))
	c.draw_rect(Rect2(x - 200, 244, 374, 6), trim)
	# Service window (dark interior).
	_rr(c, Rect2(x - 154, 160, 128, 72), Color("7D8A93").lerp(Palette.TEXT, 0.3), 8)
	# Roof sign.
	_rr(c, Rect2(x - 178, 92, 190, 40), Palette.PANEL, 12)
	_rr(c, Rect2(x - 178, 92, 190, 40), Color.TRANSPARENT, 12)
	c.draw_string(ThemeDB.fallback_font, Vector2(x - 178, 120), "BUSSIN BREWS", HORIZONTAL_ALIGNMENT_CENTER, 190, 26, Palette.TEXT)
	c.draw_rect(Rect2(x - 150, 130, 6, 8), Palette.TEXT.lerp(Palette.BG, 0.5))
	c.draw_rect(Rect2(x - 20, 130, 6, 8), Palette.TEXT.lerp(Palette.BG, 0.5))


func _draw_truck_front(c: CanvasItem) -> void:
	var x := cx()
	var body := Palette.PEACH.lerp(Palette.BG, 0.15)
	# Panel below the window hides the barista's legs, plus the counter ledge.
	c.draw_rect(Rect2(x - 200, 234, 290, 14), body)
	_rr(c, Rect2(x - 166, 228, 152, 9), Color("B08D66"), 4)
	# Awning with stripes.
	var stripes := 8
	var aw_x := x - 166.0
	var aw_w := 152.0
	for i in stripes:
		var x0 := aw_x + aw_w * float(i) / stripes
		var x1 := aw_x + aw_w * float(i + 1) / stripes
		var col := Palette.ACCENT.lerp(Palette.BG, 0.25) if i % 2 == 0 else Palette.PANEL
		c.draw_colored_polygon(PackedVector2Array([Vector2(x0, 152), Vector2(x1, 152), Vector2(x1 + 3.0, 172), Vector2(x0 - 3.0, 172)]), col)
	# Wheels.
	for wx in [x - 126.0, x + 128.0]:
		c.draw_circle(Vector2(wx, TRUCK_BOTTOM), 26.0, Palette.TEXT.lerp(Palette.BG, 0.2))
		c.draw_circle(Vector2(wx, TRUCK_BOTTOM), 12.0, Palette.BG.darkened(0.08))
	# String lights.
	var bulbs := 12
	for i in bulbs:
		var bx := aw_x - 20.0 + (aw_w + 40.0) * float(i) / (bulbs - 1)
		var by := 150.0 + sin(float(i) / (bulbs - 1) * PI) * 9.0
		var warm := 0.65 + 0.35 * sin(_t * 2.0 + i)
		c.draw_circle(Vector2(bx, by), 3.4, Color(1.0, 0.9, 0.62, warm))


func _draw_fx(c: CanvasItem) -> void:
	if weather_id == "rainy":
		for d in _drops:
			c.draw_line(d, d + Vector2(-5.0, 14.0), Color(0.55, 0.65, 0.78, 0.55), 1.8)
		c.draw_rect(Rect2(0, 0, _wv, WORLD_H), Color(0.45, 0.52, 0.62, 0.10))
	elif weather_id == "cold":
		c.draw_rect(Rect2(0, 0, _wv, WORLD_H), Color(0.62, 0.74, 0.88, 0.12))
	elif weather_id == "hot":
		c.draw_rect(Rect2(0, 0, _wv, WORLD_H), Color(1.0, 0.82, 0.55, 0.10))
		for i in 6:
			var sx := _wv * (0.1 + 0.16 * i)
			c.draw_arc(Vector2(sx, 236.0), 20.0, 0.0, PI, 10, Color(1.0, 0.9, 0.7, 0.35 + 0.2 * sin(_t * 3.0 + i)), 2.0)
	# Dusk and dawn warmth.
	var warm := absf(progress - 0.5) * 2.0
	c.draw_rect(Rect2(0, 0, _wv, WORLD_H), Color(1.0, 0.72, 0.5, 0.09 * warm * warm))
