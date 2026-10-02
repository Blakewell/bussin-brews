extends Control
## Screen flow: title -> briefing -> planning -> (service | breeze) -> results -> next day.
## Text-first UI: people and places are identified by words and colored chips, not icons.

const PRICE_STEP := 0.25
const STOCK_STEP := 5

var _body: VBoxContainer
var _footer: VBoxContainer
var _plan_loc := "school"
var _prices := {}
var _servings := {}
var _language := "generational"
var _last_result := {}

# planning widgets
var _summary: Label
var _go_buttons: Array[Button] = []
var _price_labels := {}
var _serving_labels := {}

# service state
var _shift: Shift
var _customer := {}
var _feed := ""
var _plan_snapshot := {}
var _upsell_pending := false


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
		margin.add_theme_constant_override("margin_" + side, 20)
	add_child(margin)
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	margin.add_child(root)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_footer = VBoxContainer.new()  # pinned action area, always visible
	_footer.add_theme_constant_override("separation", 6)
	root.add_child(_footer)
	_show_title()


# --- helpers ---------------------------------------------------------------

func _reset() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	for c in _footer.get_children():
		_footer.remove_child(c)
		c.queue_free()
	_go_buttons.clear()


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


## A small colored tag, e.g. a customer's generation.
func _chip(text: String, color: Color, parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Palette.box(color, 10, Color.TRANSPARENT, 5))
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", Palette.TEXT)
	p.add_child(l)
	parent.add_child(p)
	return p


func _gen_color(gen_id: String) -> Color:
	return Color(Content.generations[gen_id].color)


func _button(text: String, parent: Node, cb: Callable, primary := false) -> Button:
	var b := Button.new()
	b.text = text
	if primary:
		Palette.make_primary(b)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _row(parent: Node = null, align := BoxContainer.ALIGNMENT_BEGIN) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = align
	r.add_theme_constant_override("separation", 10)
	(parent if parent else _body).add_child(r)
	return r


func _foot_row() -> HBoxContainer:
	return _row(_footer, BoxContainer.ALIGNMENT_END)


func _money(x: float) -> String:
	return ("-$%.2f" % absf(x)) if x < 0.0 else ("$%.2f" % x)


func _delta_money(x: float) -> String:
	return ("+$%.0f" % x) if x >= 0.0 else ("-$%.0f" % absf(x))


func _mix_text(location: Dictionary) -> String:
	var parts: Array[String] = []
	for g in location.generations:
		parts.append("%s %d%%" % [Content.generations[g].label, int(round(location.generations[g] * 100.0))])
	# Two lines so three location buttons fit across the window.
	return " · ".join(parts.slice(0, 2)) + "\n" + " · ".join(parts.slice(2))


func _space_shortcut(b: Button) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	var sc := Shortcut.new()
	sc.events = [ev]
	b.shortcut = sc


func _weather_label() -> String:
	return Content.weather.types[GameState.weather_id].label


# --- title -----------------------------------------------------------------

func _show_title() -> void:
	_reset()
	_label("Bussin Brews", 60).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	_button("Open for business", _foot_row(), func():
		GameState.new_game(0, _language)
		_prices.clear()
		_servings.clear()
		_show_briefing(), true)


# --- briefing --------------------------------------------------------------

func _show_briefing() -> void:
	_reset()
	var top := _row()
	_label("Day %d · %s" % [GameState.day, GameCalendar.label(GameState.day)], 34, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Cash %s    Reputation %.2f" % [_money(GameState.cash), GameState.reputation], 24, Palette.TEXT, top)

	var weather := _card(null, Palette.BLUE.lerp(Palette.BG, 0.55))
	_label("Weather: %s" % _weather_label(), 26, Palette.TEXT, weather)
	var gas_change := Content.cpi.change("gasoline", GameState.month())
	_label("Gas: %s/gal (%+.0f%% vs last month)" % [_money(GameState.gas_price()), gas_change * 100.0], 20, Palette.TEXT, weather)

	_label("The news", 24)
	if GameState.headlines.is_empty():
		_label("Quiet day. Nothing in the headlines.", 18, Palette.MUTED)
	for h in GameState.headlines:
		var n := _card(null, Palette.PEACH.lerp(Palette.BG, 0.5))
		_label(h.headline, 20, Palette.TEXT, n)
		_label(h.body, 16, Palette.MUTED, n)

	var prev := GameState.last_result()
	if not prev.is_empty():
		_label("Yesterday", 24)
		var c := _card(null, Palette.SAGE.lerp(Palette.BG, 0.6))
		var loc := Content.location(prev.location_id)
		_label("%s · %s · profit %s" % [loc.name, Content.weather.types[prev.weather_id].label, _money(prev.profit)], 18, Palette.TEXT, c)
		for line in prev.insights:
			_label("• " + line, 16, Palette.MUTED, c)

	_button("Plan the day →", _foot_row(), _show_planning, true)


# --- planning --------------------------------------------------------------

func _show_planning() -> void:
	_reset()
	_price_labels.clear()
	_serving_labels.clear()
	var econ: Economy = Content.economy
	var month := GameState.month()
	for d in Content.drinks:
		if not _prices.has(d.id):
			_prices[d.id] = snappedf(econ.fair_price(d, month), PRICE_STEP)
			_servings[d.id] = 15
	for t in Content.treats:
		if not _prices.has(t.id):
			_prices[t.id] = snappedf(econ.fair_price(t, month), PRICE_STEP)
			_servings[t.id] = 10

	var top := _row()
	_label("Plan · %s" % _weather_label(), 30, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Cash %s" % _money(GameState.cash), 24, Palette.TEXT, top)

	_label("Where to park", 22)
	var locs := _row()
	var group := ButtonGroup.new()
	for l in Content.locations:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = l.id == _plan_loc
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var last := GameState.last_visit(l.id)
		var last_text := "Never been here" if last.is_empty() else "Last: %s in %s (day %d)" % [_delta_money(last.profit), Content.weather.types[last.weather_id].label.to_lower(), last.day]
		b.text = "%s\nGas %s · permit %s · %d mi\n%s\n%s" % [l.name, _money(econ.trip_cost(l, month)), _money(float(l.permit)), l.miles, _mix_text(l), last_text]
		b.pressed.connect(func():
			_plan_loc = l.id
			_refresh_plan())
		locs.add_child(b)

	var prev := GameState.last_result()
	_menu_section("Drinks", Content.drinks, prev)
	_menu_section("Bakery case: add-ons to upsell", Content.treats, prev)

	_summary = _label("", 18, Palette.TEXT, _footer)
	var row := _foot_row()
	if not prev.is_empty():
		_button("Restock from yesterday's sales", row, _restock_from_yesterday)
	_go_buttons.append(_button("Breeze through the day", row, _breeze))
	_go_buttons.append(_button("Serve customers", row, _start_service, true))
	_refresh_plan()


func _menu_section(title: String, items: Array, prev: Dictionary) -> void:
	var econ: Economy = Content.economy
	var month := GameState.month()
	_label(title, 22)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 4)
	_body.add_child(grid)
	for h in ["Item", "Fair price", "Your price", "Cost each", "Servings", "Yesterday" if not prev.is_empty() else ""]:
		_label(h, 15, Palette.MUTED, grid)
	for d in items:
		_label(d.name, 18, Palette.TEXT, grid)
		_label(_money(econ.fair_price(d, month)), 18, Palette.MUTED, grid)
		_stepper(grid, d.id, _price_labels, -PRICE_STEP, PRICE_STEP, func(id: String, delta: float):
			_prices[id] = clampf(snappedf(_prices[id] + delta, PRICE_STEP), 0.5, 25.0))
		_label(_money(econ.serving_cost(d, month)), 18, Palette.MUTED, grid)
		_stepper(grid, d.id, _serving_labels, -STOCK_STEP, STOCK_STEP, func(id: String, delta: float):
			_servings[id] = clampi(_servings[id] + int(delta), 0, 150))
		_yesterday_cell(grid, d, prev)


## A − / value / + control for one item's price or servings.
func _stepper(parent: Node, item_id: String, labels: Dictionary, down: float, up: float, apply: Callable) -> void:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	parent.add_child(r)
	var minus := Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(38, 0)
	r.add_child(minus)
	var value := Label.new()
	value.custom_minimum_size = Vector2(64, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 18)
	r.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(38, 0)
	r.add_child(plus)
	labels[item_id] = value
	minus.pressed.connect(func():
		apply.call(item_id, down)
		_refresh_plan())
	plus.pressed.connect(func():
		apply.call(item_id, up)
		_refresh_plan())


func _yesterday_cell(parent: Node, item: Dictionary, prev: Dictionary) -> void:
	if prev.is_empty():
		_label("", 16, Palette.MUTED, parent)
		return
	var d: Dictionary = prev.drinks.get(item.id, {})
	if d.is_empty() or d.stocked == 0:
		_label("not stocked", 16, Palette.MUTED, parent)
	elif d.sold >= d.stocked:
		_label("sold out (%d) %s" % [d.sold, _delta_money(d.profit)], 16, Palette.GOOD, parent)
	else:
		var color := Palette.WARM if d.sold * 2 < d.stocked else Palette.MUTED
		_label("%d of %d sold %s" % [d.sold, d.stocked, _delta_money(d.profit)], 16, color, parent)


## Stock each item to what sold yesterday (plus room to grow if it sold out).
func _restock_from_yesterday() -> void:
	var prev := GameState.last_result()
	for id in prev.drinks:
		var y: Dictionary = prev.drinks[id]
		if y.stocked == 0:
			continue
		var target: float = y.sold * 1.1 if y.sold < y.stocked else y.stocked * 1.3
		_servings[id] = int(ceil(target / STOCK_STEP)) * STOCK_STEP
	_refresh_plan()


func _current_plan() -> Dictionary:
	var offers: Array = []
	for d in Content.drinks:
		if _servings[d.id] > 0:
			offers.append({"drink_id": d.id, "price": _prices[d.id], "servings": _servings[d.id]})
	var treats: Array = []
	for t in Content.treats:
		if _servings[t.id] > 0:
			treats.append({"item_id": t.id, "price": _prices[t.id], "servings": _servings[t.id]})
	return {"location_id": _plan_loc, "offers": offers, "treats": treats}


func _refresh_plan() -> void:
	for id in _price_labels:
		_price_labels[id].text = _money(_prices[id])
		_serving_labels[id].text = str(_servings[id])
	var plan := _current_plan()
	var cost := GameState.plan_cost(plan)
	var after := GameState.cash - cost
	_summary.text = "Upfront cost (gas + permit + stock): %s   →   cash after: %s" % [_money(cost), _money(after)]
	_summary.add_theme_color_override("font_color", Palette.TEXT if after >= 0.0 else Palette.WARM)
	for b in _go_buttons:
		b.disabled = plan.offers.is_empty() or after < 0.0


func _breeze() -> void:
	_plan_snapshot = _current_plan()
	GameState.begin_shift(_plan_snapshot).auto_finish()
	_last_result = GameState.finish_shift("auto")
	_show_results()


# --- service (serve each customer) ----------------------------------------

func _start_service() -> void:
	_plan_snapshot = _current_plan()
	_shift = GameState.begin_shift(_plan_snapshot)
	_feed = "The window is open. Here comes the first customer."
	_upsell_pending = false
	_next_customer()


func _next_customer() -> void:
	_upsell_pending = false
	_customer = _shift.next_customer()
	if _customer.is_empty():
		_finish_hands_on()
	else:
		_show_service()


func _finish_hands_on() -> void:
	_last_result = GameState.finish_shift("hands-on")
	_show_results()


func _service_header() -> void:
	var res := _shift.result
	var top := _row()
	_label("Service · %s" % Content.location(_plan_snapshot.location_id).name, 28, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Sales %s · Tips %s" % [_money(res.revenue), _money(res.tips)], 22, Palette.TEXT, top)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = _shift.progress()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.add_theme_stylebox_override("background", Palette.box(Palette.BLUE.lerp(Palette.BG, 0.5), 7, Color.TRANSPARENT, 0))
	bar.add_theme_stylebox_override("fill", Palette.box(Palette.SAGE, 7, Color.TRANSPARENT, 0))
	_body.add_child(bar)
	_label(_feed, 16, Palette.MUTED)


func _customer_card(headline: String) -> VBoxContainer:
	var c := _customer
	var gen: Dictionary = Content.generations[c.gen_id]
	var card := _card(null, Palette.PEACH.lerp(Palette.BG, 0.5))
	var who := _row(card)
	_label(c.name, 24, Palette.TEXT, who)
	_chip(gen.label, _gen_color(c.gen_id), who)
	_label(headline, 22, Palette.TEXT, card)
	return card


func _show_service() -> void:
	if _upsell_pending:
		_show_upsell()
		return
	_reset()
	_service_header()
	var c := _customer
	var voice := GameState.voice_for(c.gen_id)
	var orders: Array = Content.dialogue[voice].order
	var craving := Content.drink(c.craving)
	var res := _shift.result
	var line: String = orders[hash(c.name + str(res.served)) % orders.size()] % craving.name
	var card := _customer_card("“%s”" % line)
	if c.wants_chat:
		var chats: Array = Content.dialogue[voice].chat
		_label("They want to chat: “%s”" % chats[hash(c.name) % chats.size()], 16, Palette.MUTED, card)
	_label("Came for: %s" % craving.name, 16, Palette.MUTED, card)

	var main_row := _row()
	var pick := _button("Serve what they asked for  [Space]", main_row, func(): _serve(c.craving, true), true)
	_space_shortcut(pick)
	if c.wants_chat:
		_button("Serve and hear them out (better tip, costs time)", main_row, func(): _serve(c.craving, true))
		_button("Serve and keep it quick", main_row, func(): _serve(c.craving, false))

	_label("Or suggest a different drink (they may say no):", 16, Palette.MUTED)
	var menu := _row()
	for o in _shift.offers:
		var id: String = o.drink.id
		var left: int = _shift.stock[id]
		var b := Button.new()
		b.text = "%s\n%s · %d left" % [o.drink.name, _money(o.price), left]
		b.disabled = left <= 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _serve(id, c.wants_chat))
		menu.add_child(b)

	var bottom := _foot_row()
	_button("Turn them away", bottom, func():
		_shift.skip(_customer)
		_feed = "You waved %s along." % c.name
		_next_customer())
	_button("Breeze through the rest", bottom, func():
		_shift.auto_finish()
		_finish_hands_on())


func _serve(drink_id: String, engage: bool) -> void:
	var c := _customer
	var out := _shift.serve(c, drink_id, engage)
	var drink := Content.drink(drink_id)
	if out.declined:
		var declines: Array = Content.dialogue[GameState.voice_for(c.gen_id)].decline
		_feed = "%s said no: “%s”" % [c.name, declines[hash(c.name + drink_id) % declines.size()]]
		_show_service()  # they stay in line; try again
		return
	if not out.sold:
		_feed = "Out of %s." % drink.name
		_show_service()
		return
	var tip_text := " + %s tip" % _money(out.tip) if out.tip > 0.0 else ""
	var chat_text := " (chatted, which took a while)" if out.engaged else ""
	_feed = "Sold %s to %s: %s%s%s." % [drink.name, c.name, _money(out.price), tip_text, chat_text]
	if _shift.has_treats_in_stock():
		_upsell_pending = true
		_show_service()
	else:
		_next_customer()


## After a drink sells, you can offer one add-on from the bakery case.
func _show_upsell() -> void:
	_reset()
	_service_header()
	var c := _customer
	var drink := Content.drink(c.sold_drink)
	var card := _customer_card("Just bought a %s." % drink.name)
	_label("Offer something from the bakery case? Pushy offers cost time, and the wrong treat gets a no.", 16, Palette.MUTED, card)

	var menu := _row()
	for t in _shift.treat_offers:
		var id: String = t.treat.id
		var left: int = _shift.treat_stock[id]
		var chance := _shift.treat_chance(c, id)
		var hint := "good bet" if chance >= 0.4 else ("maybe" if chance >= 0.2 else "long shot")
		var b := Button.new()
		b.text = "%s\n%s · %d left\n%s" % [t.treat.name, _money(t.price), left, hint]
		b.disabled = left <= 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _upsell(id))
		menu.add_child(b)

	var bottom := _foot_row()
	var skip := _button("No add-on, next customer  [Space]", bottom, _next_customer, true)
	_space_shortcut(skip)


func _upsell(treat_id: String) -> void:
	var c := _customer
	var treat := Content.item(treat_id)
	var out := _shift.upsell(c, treat_id)
	var voice := GameState.voice_for(c.gen_id)
	if out.accepted:
		var yes: Array = Content.dialogue[voice].upsell_yes
		_feed = "Added a %s for %s. %s: “%s”" % [treat.name, _money(out.price), c.name, yes[hash(c.name + treat_id) % yes.size()]]
	else:
		var no: Array = Content.dialogue[voice].upsell_no
		_feed = "No %s. %s: “%s”" % [treat.name, c.name, no[hash(c.name + treat_id) % no.size()]]
	_next_customer()


# --- results ---------------------------------------------------------------

func _show_results() -> void:
	_reset()
	var r := _last_result
	var prev := {}
	if GameState.history.size() >= 2:
		prev = GameState.history[GameState.history.size() - 2]
	var loc := Content.location(r.location_id)
	var shift: Dictionary = r.shift
	_label("Day %d wrap-up · %s" % [r.day, loc.name], 32)

	var cols := _row()
	cols.add_theme_constant_override("separation", 14)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 10)
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 10)
	cols.add_child(right)

	# Left: what sold, compared with yesterday
	var sales := _card(left, Palette.SAGE.lerp(Palette.BG, 0.55))
	for item in Content.drinks + Content.treats:
		var info: Dictionary = r.drinks.get(item.id, {})
		if info.is_empty():
			continue
		var text := "%s × %d of %d" % [item.name, info.sold, info.stocked]
		if not prev.is_empty() and prev.drinks.has(item.id) and prev.drinks[item.id].stocked > 0:
			var diff: int = info.sold - prev.drinks[item.id].sold
			text += "   %s" % ("▲ +%d" % diff if diff > 0 else ("▼ %d" % diff if diff < 0 else "="))
		_label(text, 17, Palette.TEXT, sales)
	_label("Served %d of %d who came by (%s)" % [shift.served, shift.arrivals, "hands-on" if r.mode == "hands-on" else "breezed through"], 16, Palette.MUTED, sales)
	if shift.treat_revenue > 0.0:
		_label("Add-ons brought in %s (%d offers, %d turned down)" % [_money(shift.treat_revenue), shift.upsell_attempts, shift.upsell_declined], 16, Palette.MUTED, sales)
	if shift.lost_to_stockout > 0:
		_label("%d left: ran out of something they wanted" % shift.lost_to_stockout, 16, Palette.WARM, sales)
	if shift.lost_to_line > 0:
		_label("%d gave up on the line" % shift.lost_to_line, 16, Palette.WARM, sales)
	if shift.declined > 0:
		_label("%d turned down a drink you pushed" % shift.declined, 16, Palette.WARM, sales)

	var lessons := _card(left, Palette.LAVENDER.lerp(Palette.BG, 0.55))
	_label("What to try next", 18, Palette.TEXT, lessons)
	for line in r.insights:
		_label("• " + line, 16, Palette.TEXT, lessons)

	# Right: the money, day over day
	var money := _card(right, Palette.PANEL)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	money.add_child(grid)
	for h in ["", "Today", "Yesterday", "Change"]:
		_label(h, 16, Palette.MUTED, grid)
	_compare_row(grid, "Sales", r.revenue, prev.get("revenue"), true)
	_compare_row(grid, "Tips", r.tips, prev.get("tips"), true)
	_compare_row(grid, "Costs", r.costs, prev.get("costs"), false)
	_compare_row(grid, "Profit", r.profit, prev.get("profit"), true)
	_label("Cash: %s" % _money(r.cash), 26, Palette.GOOD if r.profit >= 0.0 else Palette.WARM, money)
	_label("Gas %s · Permit %s · Stock %s" % [_money(r.trip_cost), _money(r.permit), _money(r.stock_cost)], 14, Palette.MUTED, money)
	if prev.is_empty():
		_label("Come back tomorrow to see how today compares.", 14, Palette.MUTED, money)
	elif prev.location_id != r.location_id or prev.weather_id != r.weather_id:
		var pl := Content.location(prev.location_id)
		_label("Different from yesterday: %s, %s → %s, %s" % [pl.name, Content.weather.types[prev.weather_id].label.to_lower(), loc.name, Content.weather.types[r.weather_id].label.to_lower()], 14, Palette.MUTED, money)

	if not r.chatter.is_empty():
		var c := _card(right, Palette.LAVENDER.lerp(Palette.BG, 0.55))
		var chead := _row(c)
		_chip(Content.generations[r.chatter.generation].label, _gen_color(r.chatter.generation), chead)
		_label("%d customers chatted:" % r.chatter.count, 14, Palette.MUTED, chead)
		_label("“%s”" % r.chatter.line, 16, Palette.TEXT, c)
	var q: Dictionary = r.quip
	var qc := _card(right, Palette.PEACH.lerp(Palette.BG, 0.55))
	var who: Dictionary = q.character
	var qhead := _row(qc)
	_label(who.name, 16, Palette.TEXT, qhead)
	_chip(Content.generations[who.generation].label, _gen_color(who.generation), qhead)
	_label("“%s”" % q.line, 18, Palette.TEXT, qc)

	var row := _foot_row()
	if GameState.is_game_over():
		_button("The truck is out of gas money. Start over", row, _show_title, true)
	else:
		_button("Next day →", row, _show_briefing, true)


func _compare_row(grid: Node, name: String, today: float, yesterday, higher_is_better: bool) -> void:
	_label(name, 18, Palette.TEXT, grid)
	_label(_money(today), 18, Palette.TEXT, grid)
	if yesterday == null:
		_label("—", 18, Palette.MUTED, grid)
		_label("", 18, Palette.MUTED, grid)
		return
	_label(_money(yesterday), 18, Palette.MUTED, grid)
	var diff: float = today - yesterday
	var good := diff >= 0.0 if higher_is_better else diff <= 0.0
	_label("%s %s" % ["▲" if diff >= 0.0 else "▼", _delta_money(diff)], 18, Palette.GOOD if good else Palette.WARM, grid)
