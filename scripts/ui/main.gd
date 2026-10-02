extends Control
## Screen flow: title -> briefing -> planning -> results -> (next day | game over).

var _body: VBoxContainer
var _plan_loc := "school"
var _prices := {}
var _servings := {}
var _summary: Label
var _go: Button
var _language := "generational"
var _last_result := {}


func _ready() -> void:
	theme = Palette.make_theme()
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + side, 48)
	for side in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 28)
	add_child(margin)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 14)
	margin.add_child(_body)
	_show_title()


# --- helpers ---------------------------------------------------------------

func _reset() -> void:
	for c in _body.get_children():
		c.queue_free()
		_body.remove_child(c)


func _label(text: String, size := 18, color := Palette.TEXT, parent: Node = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	var target: Node = parent if parent else _body
	# Wrapped labels collapse to one character wide inside rows and grids.
	var in_row := target is HBoxContainer or target is GridContainer
	l.autowrap_mode = TextServer.AUTOWRAP_OFF if in_row else TextServer.AUTOWRAP_WORD_SMART
	target.add_child(l)
	return l


func _card(parent: Node = null, tint := Color.TRANSPARENT) -> VBoxContainer:
	var p := PanelContainer.new()
	if tint.a > 0.0:
		p.add_theme_stylebox_override("panel", Palette.box(tint, 16, Color.TRANSPARENT, 14))
	(parent if parent else _body).add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	p.add_child(v)
	return v


func _button(text: String, parent: Node, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	if primary:
		Palette.make_primary(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _money(x: float) -> String:
	return ("-$%.2f" % absf(x)) if x < 0.0 else ("$%.2f" % x)


func _mix_text(location: Dictionary) -> String:
	var parts: Array[String] = []
	for g in location.generations:
		parts.append("%s %d%%" % [Content.generations[g].emoji, int(round(location.generations[g] * 100.0))])
	return "  ".join(parts)


# --- title -----------------------------------------------------------------

func _show_title() -> void:
	_reset()
	_label("🧋 Bussin Brews 🚚", 56, Palette.TEXT).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("A traveling drink truck. Real prices. Real weather. Real drama.", 20, Palette.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := _card(null, Palette.LAVENDER.lerp(Palette.BG, 0.5))
	_label("Language", 20, Palette.TEXT, card)
	var opt := OptionButton.new()
	opt.add_item("Generational: each age group talks like their generation", 0)
	opt.add_item("Gen Z only: everybody talks like a teenager", 1)
	opt.selected = 0 if _language == "generational" else 1
	opt.item_selected.connect(func(i: int): _language = "generational" if i == 0 else "gen_z")
	card.add_child(opt)
	_label("Start with $1,000. Prices follow the real Consumer Price Index, starting January 2026.", 16, Palette.MUTED, card)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	_body.add_child(row)
	_button("Open for business", row, func():
		GameState.new_game(0, _language)
		_prices.clear()
		_servings.clear()
		_show_briefing(), true)


# --- briefing --------------------------------------------------------------

func _show_briefing() -> void:
	_reset()
	var w: Dictionary = Content.weather.types[GameState.weather_id]
	var top := HBoxContainer.new()
	_body.add_child(top)
	var title := _label("Day %d · %s" % [GameState.day, GameCalendar.label(GameState.day)], 34, Palette.TEXT, top)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("💰 %s   ⭐ %.2f" % [_money(GameState.cash), GameState.reputation], 26, Palette.TEXT, top)

	var weather := _card(null, Palette.BLUE.lerp(Palette.BG, 0.55))
	_label("%s  %s today" % [w.emoji, w.label], 26, Palette.TEXT, weather)
	var gas_change := Content.cpi.change("gasoline", GameState.month())
	_label("⛽ Gas: %s/gal (%+.0f%% vs last month)" % [_money(GameState.gas_price()), gas_change * 100.0], 20, Palette.TEXT, weather)

	_label("📰 The news", 24)
	if GameState.headlines.is_empty():
		_label("Quiet day. Nothing in the headlines.", 18, Palette.MUTED)
	for h in GameState.headlines:
		var n := _card(null, Palette.PEACH.lerp(Palette.BG, 0.5))
		_label(h.headline, 20, Palette.TEXT, n)
		_label(h.body, 16, Palette.MUTED, n)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(row)
	_button("Plan the day →", row, _show_planning, true)


# --- planning --------------------------------------------------------------

func _show_planning() -> void:
	_reset()
	var econ: Economy = Content.economy
	var month := GameState.month()
	for d in Content.drinks:
		if not _prices.has(d.id):
			_prices[d.id] = snappedf(econ.fair_price(d, month), 0.25)
			_servings[d.id] = 15

	var top := HBoxContainer.new()
	_body.add_child(top)
	var w: Dictionary = Content.weather.types[GameState.weather_id]
	_label("Plan · %s %s" % [w.emoji, w.label], 30, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("💰 %s" % _money(GameState.cash), 26, Palette.TEXT, top)

	_label("📍 Where to park", 22)
	var locs := HBoxContainer.new()
	locs.add_theme_constant_override("separation", 12)
	_body.add_child(locs)
	var group := ButtonGroup.new()
	for l in Content.locations:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = l.id == _plan_loc
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s %s\n⛽ %s · permit %s · %d mi\n%s" % [l.emoji, l.name, _money(econ.trip_cost(l, month)), _money(float(l.permit)), l.miles, _mix_text(l)]
		b.pressed.connect(func():
			_plan_loc = l.id
			_refresh_plan())
		locs.add_child(b)

	_label("🥤 Menu", 22)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for h in ["Drink", "Fair price", "Your price", "Cost each", "Servings"]:
		_label(h, 16, Palette.MUTED, grid)
	for d in Content.drinks:
		_label("%s %s" % [d.emoji, d.name], 18, Palette.TEXT, grid)
		_label(_money(econ.fair_price(d, month)), 18, Palette.MUTED, grid)
		var price := _spin(0.5, 20.0, 0.05, _prices[d.id], func(v: float):
			_prices[d.id] = v)
		grid.add_child(price)
		_label(_money(econ.serving_cost(d, month)), 18, Palette.MUTED, grid)
		var serv := _spin(0, 120, 1, _servings[d.id], func(v: float):
			_servings[d.id] = int(v)
			_refresh_plan())
		grid.add_child(serv)

	_summary = _label("", 20, Palette.TEXT)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(row)
	_go = _button("Open the window 🚚", row, _run_day, true)
	_refresh_plan()


func _spin(min_v: float, max_v: float, step: float, value: float, cb: Callable) -> SpinBox:
	var s := SpinBox.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = value
	s.value_changed.connect(cb)
	return s


func _current_plan() -> Dictionary:
	var offers: Array = []
	for d in Content.drinks:
		if _servings[d.id] > 0:
			offers.append({"drink_id": d.id, "price": _prices[d.id], "servings": _servings[d.id]})
	return {"location_id": _plan_loc, "offers": offers}


func _refresh_plan() -> void:
	var plan := _current_plan()
	var cost := GameState.plan_cost(plan)
	var after := GameState.cash - cost
	_summary.text = "Upfront cost (gas + permit + stock): %s   →   cash after: %s" % [_money(cost), _money(after)]
	_summary.add_theme_color_override("font_color", Palette.TEXT if after >= 0.0 else Palette.WARM)
	_go.disabled = plan.offers.is_empty() or after < 0.0


func _run_day() -> void:
	_last_result = GameState.run_day(_current_plan())
	_show_results()


# --- results ---------------------------------------------------------------

func _show_results() -> void:
	_reset()
	var r := _last_result
	var loc := Content.location(r.location_id)
	var shift: Dictionary = r.shift
	_label("Day %d wrap-up · %s %s" % [r.day, loc.emoji, loc.name], 32)

	var sales := _card(null, Palette.SAGE.lerp(Palette.BG, 0.55))
	for d in Content.drinks:
		var n: int = shift.sold.get(d.id, 0)
		if n > 0:
			_label("%s %s × %d" % [d.emoji, d.name, n], 18, Palette.TEXT, sales)
	_label("🧾 Served %d of %d people who came by" % [shift.served, shift.arrivals], 16, Palette.MUTED, sales)
	if shift.lost_to_stockout > 0:
		_label("😬 %d left because you ran out of something they wanted" % shift.lost_to_stockout, 16, Palette.WARM, sales)
	if shift.lost_to_line > 0:
		_label("⏳ %d gave up on the line" % shift.lost_to_line, 16, Palette.WARM, sales)

	var money := _card(null, Palette.PANEL)
	_label("Sales %s   ·   Tips %s" % [_money(r.revenue), _money(r.tips)], 20, Palette.TEXT, money)
	_label("Gas %s   ·   Permit %s   ·   Stock %s" % [_money(r.trip_cost), _money(r.permit), _money(r.stock_cost)], 16, Palette.MUTED, money)
	_label("Profit: %s      💰 Cash: %s" % [_money(r.profit), _money(r.cash)], 26, Palette.GOOD if r.profit >= 0.0 else Palette.WARM, money)

	if not r.chatter.is_empty():
		var g: Dictionary = Content.generations[r.chatter.generation]
		var c := _card(null, Palette.LAVENDER.lerp(Palette.BG, 0.55))
		_label("%s %d customers stopped to chat, which slowed the line:" % [g.emoji, r.chatter.count], 16, Palette.MUTED, c)
		_label("“%s”" % r.chatter.line, 18, Palette.TEXT, c)

	var q: Dictionary = r.quip
	var qc := _card(null, Palette.PEACH.lerp(Palette.BG, 0.55))
	var who: Dictionary = q.character
	_label("%s %s  %s" % [who.emoji, who.name, Content.generations[who.generation].emoji], 18, Palette.MUTED, qc)
	_label("“%s”" % q.line, 20, Palette.TEXT, qc)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	_body.add_child(row)
	if GameState.is_game_over():
		_button("The truck is out of gas money. Start over", row, _show_title, true)
	else:
		_button("Next day →", row, _show_briefing, true)
