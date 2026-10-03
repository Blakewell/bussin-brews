class_name Person
extends Node2D
## A flat-style person drawn from shapes. Feet sit at the node's origin, facing right when
## `facing` is 1. Each generation gets its own look: Gen Alpha kid-sized with a backpack, a
## backwards cap and light-up sneakers; Gen Z beanie and headphones; millennial glasses and a
## bun; Gen X flannel and a beard; boomer gray hair, visor and cane.

signal arrived

const SKIN := [Color("F3D2B3"), Color("E4B48C"), Color("C98F65"), Color("A36B47"), Color("7B4C32")]
const SHIRTS := {
	"gen_alpha": [Color("F3E3A3"), Color("A9D8E8"), Color("F2B8C6"), Color("B9E2B0")],
	"gen_z": [Color("C9BFE0"), Color("E8A5C0"), Color("9DD0C7"), Color("F2C9A5")],
	"millennial": [Color("A8C3A0"), Color("F2C9A5"), Color("9DB7C9"), Color("E5B7A8")],
	"gen_x": [Color("C98F8A"), Color("8FA7B8"), Color("B5A48A"), Color("8FAE97")],
	"boomer": [Color("F2D7A0"), Color("B8C8E0"), Color("C9D8B6"), Color("E8C4C4")],
}
const HAIR := {
	"gen_alpha": [Color("6B4B3A"), Color("3E3A3A"), Color("C8935A")],
	"gen_z": [Color("5A4A66"), Color("D68FA8"), Color("3E4A57")],
	"millennial": [Color("6B4B3A"), Color("3E3A3A"), Color("A56F4B")],
	"gen_x": [Color("6B5A48"), Color("4A4038"), Color("8A6A4A")],
	"boomer": [Color("D8D8DC"), Color("C4C4CC"), Color("E6E2DA")],
}
const PANTS := Color("5E6E80")
const SHOES := Color("3E4A57")
const INK := Color("3E4A57")

var gen_id := "millennial"
var gender := "female"          ## "female" or "male"; looks follow it (no beards on women, no buns on men)
var variant := 0
var facing := 1.0
var has_cup := false
var cup_color := Color("E58F7B")
var is_barista := false
var arm_raise := 0.0           ## 0..1, the barista reaching out with a drink

var _skin: Color
var _shirt: Color
var _hair: Color
var _phase := 0.0
var _walking := false
var _target_x := 0.0
var _speed := 330.0
var _leave_on_arrival := false
var _t := 0.0
var _fade := 1.0
var _bubble: PanelContainer
var _bubble_label: Label
var _tag: PanelContainer
var _sb := StyleBoxFlat.new()
var _size := 1.0   ## kids are drawn smaller


## Beards are only for men, buns only for women.
static func has_beard(generation: String, who: String) -> bool:
	return generation == "gen_x" and who == "male"


static func has_bun(generation: String, who: String) -> bool:
	return generation == "millennial" and who == "female"


func setup(generation: String, seed_value: int, gender_id := "") -> Person:
	gen_id = generation
	variant = absi(seed_value)
	gender = gender_id if gender_id != "" else ("female" if variant % 2 == 0 else "male")
	_skin = SKIN[variant % SKIN.size()]
	_shirt = SHIRTS[gen_id][(variant / 3) % SHIRTS[gen_id].size()]
	_hair = HAIR[gen_id][(variant / 5) % HAIR[gen_id].size()]
	if gen_id == "boomer":
		_speed = 240.0
	if gen_id == "gen_alpha":
		_size = 0.78
		_speed = 380.0
	_sb.set_corner_radius_all(11)
	return self


## Walk along the ground to x. Emits `arrived` when there; optionally frees itself after.
func walk_to(x: float, speed := -1.0, leave := false) -> void:
	_target_x = x
	if speed > 0.0:
		_speed = speed
	_leave_on_arrival = leave
	_walking = true


func is_walking() -> bool:
	return _walking


func fade_in() -> void:
	_fade = 0.0


## Show a speech bubble above the head. seconds <= 0 keeps it until cleared.
func say(text: String, seconds := 0.0) -> void:
	if _bubble == null:
		_bubble = PanelContainer.new()
		_bubble.add_theme_stylebox_override("panel", Palette.box(Palette.PANEL, 14, Palette.BLUE, 8))
		_bubble.z_index = 20
		_bubble_label = Label.new()
		_bubble_label.add_theme_font_size_override("font_size", 17)
		_bubble_label.add_theme_color_override("font_color", Palette.TEXT)
		_bubble_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_bubble_label.custom_minimum_size = Vector2(200, 0)
		_bubble.add_child(_bubble_label)
		add_child(_bubble)
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.reset_size()
	# Sit above the head, centered, keeping on the right side of the scene edge.
	_bubble.position = Vector2(-_bubble.size.x * 0.5, -150.0 * _size - _bubble.size.y)
	if seconds > 0.0:
		var stamp := text
		# A tween dies with this node, so a person who walks off can't leave a dangling callback.
		var tw := create_tween()
		tw.tween_interval(seconds)
		tw.tween_callback(func():
			if _bubble != null and _bubble_label.text == stamp:
				_bubble.visible = false)


func clear_say() -> void:
	if _bubble != null:
		_bubble.visible = false


## A small name/generation tag under the feet.
func set_tag(text: String, color: Color) -> void:
	if _tag == null:
		_tag = PanelContainer.new()
		var l := Label.new()
		l.name = "L"
		l.add_theme_font_size_override("font_size", 14)
		l.add_theme_color_override("font_color", Palette.TEXT)
		_tag.add_child(l)
		add_child(_tag)
	_tag.add_theme_stylebox_override("panel", Palette.box(color, 9, Color.TRANSPARENT, 4))
	_tag.get_node("L").text = text
	_tag.reset_size()
	_tag.position = Vector2(-_tag.size.x * 0.5, 6.0)


func clear_tag() -> void:
	if _tag != null:
		_tag.queue_free()
		_tag = null


func _process(delta: float) -> void:
	_t += delta
	if _fade < 1.0:
		_fade = minf(1.0, _fade + delta * 3.0)
	modulate.a = _fade
	if _walking:
		var dx := _target_x - position.x
		var step := _speed * delta
		if absf(dx) <= step:
			position.x = _target_x
			_walking = false
			arrived.emit()
			if _leave_on_arrival:
				queue_free()
				return
		else:
			position.x += signf(dx) * step
			facing = signf(dx)
			_phase += delta * _speed / 26.0
	queue_redraw()


func _draw() -> void:
	var swing := sin(_phase) * 8.0 if _walking else 0.0
	var bounce := absf(sin(_phase)) * 2.5 if _walking else sin(_t * 2.0) * 1.0
	# Ground shadow (not mirrored, not bounced).
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(_size, _size))
	_ellipse(Vector2(0, 0), 20.0, 4.5, Color(0.24, 0.29, 0.34, 0.14))
	draw_set_transform(Vector2(0, -bounce), 0.0, Vector2(facing * _size, _size))

	if gen_id == "gen_alpha" and not is_barista:  # backpack, behind everything else
		_sb.bg_color = _shirt.darkened(0.25)
		draw_style_box(_sb, Rect2(-27.0, -84.0, 16.0, 40.0))

	# Legs and shoes.
	for side in [-1.0, 1.0]:
		var lx: float = side * 6.0 + swing * side
		draw_rect(Rect2(lx - 4.5, -38.0, 9.0, 34.0), PANTS)
		var shoe := SHOES
		if gen_id == "gen_alpha":  # light-up sneakers
			shoe = Palette.ACCENT if fmod(_t * 3.0 + side, 2.0) < 1.0 else Palette.LAVENDER
		draw_rect(Rect2(lx - 5.5, -5.0, 12.0, 5.0), shoe)

	# Back arm (swings opposite the front arm).
	var back_swing := -swing * 0.9
	_arm(Vector2(-16.0, -78.0), Vector2(-20.0 + back_swing * 0.3, -50.0 + absf(back_swing) * 0.2))

	# Torso.
	_sb.bg_color = _shirt
	draw_style_box(_sb, Rect2(-17.0, -86.0, 34.0, 52.0))
	_torso_details()

	# Head.
	draw_circle(Vector2(0, -101.0), 15.0, _skin)
	_hair_and_accessories()
	draw_circle(Vector2(5.0, -101.0), 1.8, INK)
	draw_circle(Vector2(-4.0, -101.0), 1.8, INK)
	draw_arc(Vector2(1.0, -97.0), 4.0, 0.25 * PI, 0.75 * PI, 8, INK, 1.6)

	# Front arm and cup.
	var hand := Vector2(21.0 + swing * 0.3, -48.0)
	if has_cup:
		hand = Vector2(25.0, -64.0)
	elif arm_raise > 0.0:
		hand = Vector2(28.0 + 6.0 * arm_raise, -70.0 - 6.0 * arm_raise)
	_arm(Vector2(16.0, -78.0), hand)
	if has_cup:
		_cup(hand + Vector2(0, -2))
	elif arm_raise > 0.0 and is_barista:
		_cup(hand + Vector2(4, -2))

	if gen_id == "boomer" and not is_barista:
		draw_line(Vector2(25.0, -50.0), Vector2(27.0, 0.0), Color("9C7B58"), 3.5, true)
		draw_arc(Vector2(23.0, -52.0), 4.0, PI, TAU, 8, Color("9C7B58"), 3.5)


func _arm(from: Vector2, to: Vector2) -> void:
	draw_line(from, to, _shirt.darkened(0.06), 8.0, true)
	draw_circle(to, 4.6, _skin)


func _cup(at: Vector2) -> void:
	draw_rect(Rect2(at.x - 5.0, at.y - 15.0, 10.0, 15.0), cup_color)
	draw_rect(Rect2(at.x - 6.0, at.y - 17.0, 12.0, 3.0), Palette.PANEL)
	draw_line(Vector2(at.x + 1.0, at.y - 24.0), Vector2(at.x + 1.0, at.y - 17.0), Palette.TEXT, 1.6)


func _torso_details() -> void:
	match gen_id:
		"gen_x":  # flannel stripes
			for x in [-9.0, 0.0, 9.0]:
				draw_line(Vector2(x, -84.0), Vector2(x, -36.0), _shirt.darkened(0.14), 2.0)
			draw_line(Vector2(-15.0, -62.0), Vector2(15.0, -62.0), _shirt.darkened(0.14), 2.0)
		"gen_z":  # hoodie pocket and strings
			_sb.bg_color = _shirt.darkened(0.08)
			draw_style_box(_sb, Rect2(-11.0, -54.0, 22.0, 14.0))
			draw_line(Vector2(-4.0, -84.0), Vector2(-4.0, -70.0), Palette.PANEL, 1.6)
			draw_line(Vector2(4.0, -84.0), Vector2(4.0, -70.0), Palette.PANEL, 1.6)
		"millennial":  # tote bag for women, nothing extra for men
			if gender == "female":
				_sb.bg_color = Palette.PEACH
				draw_style_box(_sb, Rect2(-24.0, -52.0, 13.0, 16.0))
	if is_barista:
		_sb.bg_color = Palette.ACCENT.lerp(Palette.BG, 0.3)
		draw_style_box(_sb, Rect2(-14.0, -70.0, 28.0, 36.0))


func _hair_and_accessories() -> void:
	var head := Vector2(0, -101.0)
	var girl := gender == "female"
	match gen_id:
		"gen_alpha":
			if girl:  # ponytail and a bow
				_dome(head + Vector2(0, -2.0), 15.5, _hair)
				draw_circle(Vector2(-16.0, -98.0), 6.5, _hair)
				draw_colored_polygon(PackedVector2Array([Vector2(-10, -116), Vector2(-2, -112), Vector2(-10, -108)]), Palette.ACCENT)
				draw_colored_polygon(PackedVector2Array([Vector2(6, -116), Vector2(-2, -112), Vector2(6, -108)]), Palette.ACCENT)
			else:  # backwards cap
				_dome(head + Vector2(0, -2.0), 15.5, _hair)
				_dome(head + Vector2(0, -4.0), 16.0, _shirt.darkened(0.2))
				draw_rect(Rect2(-22.0, -108.0, 10.0, 4.0), _shirt.darkened(0.3))
		"gen_z":  # beanie and headphones; long hair shows underneath for women
			if girl:
				draw_rect(Rect2(-16.0, -104.0, 6.0, 22.0), _hair)
				draw_rect(Rect2(10.0, -104.0, 6.0, 22.0), _hair)
			_dome(head + Vector2(0, -3.0), 16.5, Palette.LAVENDER.darkened(0.05) if variant % 2 == 0 else Palette.SAGE)
			draw_rect(Rect2(-16.5, -108.0, 33.0, 5.0), Palette.TEXT.lerp(Palette.PANEL, 0.35))
			draw_arc(head + Vector2(0, -2.0), 17.5, PI * 1.02, PI * 1.98, 18, INK, 3.0)
			draw_circle(Vector2(-17.0, -100.0), 4.5, INK)
			draw_circle(Vector2(17.0, -100.0), 4.5, INK)
		"millennial":  # glasses for everyone; a bun for women, short hair for men
			_dome(head + Vector2(0, -2.0), 15.5, _hair)
			if has_bun(gen_id, gender):
				draw_circle(Vector2(-3.0, -121.0), 6.5, _hair)
			for ex in [-4.0, 5.0]:
				draw_arc(Vector2(ex, -101.0), 4.8, 0.0, TAU, 14, INK, 1.4)
			draw_line(Vector2(0.5, -101.0), Vector2(0.8, -101.0), INK, 1.4)
		"gen_x":
			_dome(head + Vector2(0, -3.0), 15.5, _hair)
			if girl:  # shoulder-length hair
				draw_rect(Rect2(-16.0, -104.0, 5.0, 18.0), _hair)
				draw_rect(Rect2(11.0, -104.0, 5.0, 18.0), _hair)
			if has_beard(gen_id, gender):
				var beard := PackedVector2Array([Vector2(-11, -96), Vector2(11, -96), Vector2(7, -84), Vector2(0, -81), Vector2(-7, -84)])
				draw_colored_polygon(beard, _hair.darkened(0.05))
				draw_arc(Vector2(1.0, -97.0), 4.0, 0.25 * PI, 0.75 * PI, 8, Palette.PANEL, 1.6)
		"boomer":
			if girl:  # curly gray hair
				draw_circle(Vector2(-12.0, -103.0), 5.5, _hair)
				draw_circle(Vector2(12.0, -103.0), 5.5, _hair)
				_dome(head + Vector2(0, -6.0), 13.0, _hair)
			else:  # thinning on top, gray at the sides, a mustache
				draw_circle(Vector2(-13.0, -100.0), 4.0, _hair)
				draw_circle(Vector2(13.0, -100.0), 4.0, _hair)
				draw_line(Vector2(-4.0, -95.5), Vector2(6.0, -95.5), _hair.darkened(0.15), 2.5)
			if variant % 2 == 0 and not is_barista:  # sun visor
				_ellipse(Vector2(3, -113.0), 21.0, 4.0, Palette.PEACH.darkened(0.08))
				draw_rect(Rect2(-15.0, -117.0, 30.0, 5.0), Palette.PEACH.darkened(0.08))


func _dome(center: Vector2, r: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		pts.append(center + Vector2(cos(a), sin(a)) * r)
	draw_colored_polygon(pts, color)


func _ellipse(c: Vector2, rx: float, ry: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * float(i) / 20.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(pts, color)
