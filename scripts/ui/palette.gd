class_name Palette
extends RefCounted
## Soothing pastel palette and the shared Theme. No pure black or pure white anywhere.

const BG := Color("F6F1E7")        # warm cream
const PANEL := Color("FBF8F1")     # soft off-white
const SAGE := Color("A8C3A0")
const BLUE := Color("9DB7C9")
const PEACH := Color("F2C9A5")
const LAVENDER := Color("C9BFE0")
const ACCENT := Color("E58F7B")    # soft coral, used sparingly for key actions
const TEXT := Color("3E4A57")      # dark slate
const MUTED := Color("7A8794")
const GOOD := Color("7FA88A")
const WARM := Color("D9A066")      # urgency without alarm red


static func box(color: Color, radius := 14, border := Color.TRANSPARENT, pad := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(pad)
	if border.a > 0.0:
		sb.set_border_width_all(2)
		sb.border_color = border
	return sb


static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, 16, BLUE.lerp(BG, 0.4), 14))

	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var c := BLUE.lerp(BG, 0.35)
		match state:
			"hover": c = BLUE.lerp(BG, 0.15)
			"pressed": c = SAGE
			"disabled": c = BG.darkened(0.04)
		t.set_stylebox(state, "Button", box(c, 12, Color.TRANSPARENT, 10) if state != "focus" else box(Color.TRANSPARENT, 12, ACCENT, 10))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_pressed_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", TEXT)
	t.set_color("font_disabled_color", "Button", MUTED)

	t.set_stylebox("normal", "LineEdit", box(PANEL, 8, BLUE, 6))
	t.set_color("font_color", "LineEdit", TEXT)
	return t


## The one coral call-to-action button style.
static func make_primary(b: Button) -> void:
	for state in ["normal", "hover", "pressed"]:
		var c := ACCENT.lerp(BG, 0.25)
		if state == "hover":
			c = ACCENT.lerp(BG, 0.1)
		elif state == "pressed":
			c = ACCENT
		b.add_theme_stylebox_override(state, box(c, 14, Color.TRANSPARENT, 12))
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_font_size_override("font_size", 22)
