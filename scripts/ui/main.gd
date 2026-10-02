extends Control
## Screen flow: title -> briefing -> planning -> (service | breeze) -> results -> next day.

const PRICE_STEP := 0.25
const STOCK_STEP := 5

var _body: VBoxContainer
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
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 12)
	scroll.add_child(_body)
	_show_title()


# --- helpers ---------------------------------------------------------------

func _reset() -> void:
	for c in _body.get_children():
		_body.remove_child(c)
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


func _money(x: float) -> String:
	return ("-$%.2f" % absf(x)) if x < 0.0 else ("$%.2f" % x)


func _delta_money(x: float) -> String:
	return ("+$%.0f" % x) if x >= 0.0 else ("-$%.0f" % absf(x))


func _mix_text(location: Dictionary) -> String:
	var parts: Array[String] = []
	for g in location.generations:
		parts.append("%s %d%%" % [Content.generations[g].emoji, int(round(location.generations[g] * 100.0))])
	return "  ".join(parts)


func _space_shortcut(b: Button) -> void:
	var ev := InputEventKey.new()
	ev.keycode = KEY_SPACE
	var sc := Shortcut.new()
	sc.events = [ev]
	b.shortcut = sc


# --- title -----------------------------------------------------------------

func _show_title() -> void:
	_reset()
	_label("🧋 Bussin Brews 🚚", 56).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
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
	var row := _row(null, BoxContainer.ALIGNMENT_CENTER)
	_button("Open for business", row, func():
		GameState.new_game(0, _language)
		_prices.clear()
		_servings.clear()
		_show_briefing(), true)


# --- briefing --------------------------------------------------------------

func _show_briefing() -> void:
	_reset()
	var w: Dictionary = Content.weather.types[GameState.weather_id]
	var top := _row()
	_label("Day %d · %s" % [GameState.day, GameCalendar.label(GameState.day)], 34, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	var prev := GameState.last_result()
	if not prev.is_empty():
		_label("📒 Yesterday", 24)
		var c := _card(null, Palette.SAGE.lerp(Palette.BG, 0.6))
		var loc := Content.location(prev.location_id)
		_label("%s %s · %s · profit %s" % [loc.emoji, loc.name, Content.weather.types[prev.weather_id].emoji, _money(prev.profit)], 18, Palette.TEXT, c)
		for line in prev.insights:
			_label("• " + line, 16, Palette.MUTED, c)

	var row := _row(null, BoxContainer.ALIGNMENT_END)
	_button("Plan the day →", row, _show_planning, true)


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

	var top := _row()
	var w: Dictionary = Content.weather.types[GameState.weather_id]
	_label("Plan · %s %s" % [w.emoji, w.label], 30, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("💰 %s" % _money(GameState.cash), 26, Palette.TEXT, top)

	_label("📍 Where to park", 22)
	var locs := _row()
	var group := ButtonGroup.new()
	for l in Content.locations:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = l.id == _plan_loc
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var last := GameState.last_visit(l.id)
		var last_text := "Never been here" if last.is_empty() else "Last: %s %s (day %d)" % [_delta_money(last.profit), Content.weather.types[last.weather_id].emoji, last.day]
		b.text = "%s %s\n⛽ %s · permit %s · %d mi\n%s\n%s" % [l.emoji, l.name, _money(econ.trip_cost(l, month)), _money(float(l.permit)), l.miles, _mix_text(l), last_text]
		b.pressed.connect(func():
			_plan_loc = l.id
			_refresh_plan())
		locs.add_child(b)

	var prev := GameState.last_result()
	_label("🥤 Menu" + ("   (right column: how each did yesterday)" if not prev.is_empty() else ""), 22)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	_body.add_child(grid)
	for h in ["Drink", "Fair price", "Your price", "Cost each", "Servings", "Yesterday" if not prev.is_empty() else ""]:
		_label(h, 16, Palette.MUTED, grid)
	for d in Content.drinks:
		_label("%s %s" % [d.emoji, d.name], 18, Palette.TEXT, grid)
		_label(_money(econ.fair_price(d, month)), 18, Palette.MUTED, grid)
		_stepper(grid, d.id, _price_labels, -PRICE_STEP, PRICE_STEP, func(id: String, delta: float):
			_prices[id] = clampf(snappedf(_prices[id] + delta, PRICE_STEP), 0.5, 25.0))
		_label(_money(econ.serving_cost(d, month)), 18, Palette.MUTED, grid)
		_stepper(grid, d.id, _serving_labels, -STOCK_STEP, STOCK_STEP, func(id: String, delta: float):
			_servings[id] = clampi(_servings[id] + int(delta), 0, 150))
		_yesterday_cell(grid, d, prev)

	_summary = _label("", 20)
	var row := _row(null, BoxContainer.ALIGNMENT_END)
	if not prev.is_empty():
		_button("Restock from yesterday's sales", row, _restock_from_yesterday)
	_go_buttons.append(_button("Breeze through the day ⏩", row, _breeze))
	_go_buttons.append(_button("Serve customers 🧋", row, _start_service, true))
	_refresh_plan()


## A − / value / + control for one drink's price or servings.
func _stepper(parent: Node, drink_id: String, labels: Dictionary, down: float, up: float, apply: Callable) -> void:
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
	labels[drink_id] = value
	minus.pressed.connect(func():
		apply.call(drink_id, down)
		_refresh_plan())
	plus.pressed.connect(func():
		apply.call(drink_id, up)
		_refresh_plan())


func _yesterday_cell(parent: Node, drink: Dictionary, prev: Dictionary) -> void:
	if prev.is_empty():
		_label("", 16, Palette.MUTED, parent)
		return
	var d: Dictionary = prev.drinks.get(drink.id, {})
	if d.is_empty() or d.stocked == 0:
		_label("not on the menu", 16, Palette.MUTED, parent)
	elif d.sold >= d.stocked:
		_label("sold out! (%d) %s" % [d.sold, _delta_money(d.profit)], 16, Palette.GOOD, parent)
	else:
		var color := Palette.WARM if d.sold * 2 < d.stocked else Palette.MUTED
		_label("%d of %d sold %s" % [d.sold, d.stocked, _delta_money(d.profit)], 16, color, parent)


## Stock each drink to what sold yesterday (plus room to grow if it sold out).
func _restock_from_yesterday() -> void:
	var prev := GameState.last_result()
	for d in Content.drinks:
		var y: Dictionary = prev.drinks.get(d.id, {})
		if y.is_empty() or y.stocked == 0:
			continue
		var target: float = y.sold * 1.1 if y.sold < y.stocked else y.stocked * 1.3
		_servings[d.id] = int(ceil(target / STOCK_STEP)) * STOCK_STEP
	_refresh_plan()


func _current_plan() -> Dictionary:
	var offers: Array = []
	for d in Content.drinks:
		if _servings[d.id] > 0:
			offers.append({"drink_id": d.id, "price": _prices[d.id], "servings": _servings[d.id]})
	return {"location_id": _plan_loc, "offers": offers}


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
	_feed = "The window is open. Here comes the first customer!"
	_next_customer()


func _next_customer() -> void:
	_customer = _shift.next_customer()
	if _customer.is_empty():
		_last_result = GameState.finish_shift("hands-on")
		_show_results()
	else:
		_show_service()


func _show_service() -> void:
	_reset()
	var c := _customer
	var gen: Dictionary = Content.generations[c.gen_id]
	var res := _shift.result

	var top := _row()
	_label("🚚 Service · %s" % Content.location(_plan_snapshot.location_id).name, 28, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
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

	# The customer
	var card := _card(null, Palette.PEACH.lerp(Palette.BG, 0.5))
	var voice := GameState.voice_for(c.gen_id)
	var orders: Array = Content.dialogue[voice].order
	var craving := Content.drink(c.craving)
	var order_line: String = orders[hash(c.name + str(res.served)) % orders.size()] % craving.name
	_label("%s %s  ·  %s" % [gen.emoji, c.name, gen.label], 22, Palette.TEXT, card)
	_label("“%s”" % order_line, 22, Palette.TEXT, card)
	if c.wants_chat:
		var chats: Array = Content.dialogue[voice].chat
		_label("💬 They want to chat: “%s”" % chats[hash(c.name) % chats.size()], 16, Palette.MUTED, card)
	_label("Came for %s %s" % [craving.emoji, craving.name], 16, Palette.MUTED, card)

	# What to serve
	var main_row := _row()
	var pick := _button("Serve what they asked for ⏎ (space)", main_row, func(): _serve(c.craving, true), true)
	_space_shortcut(pick)
	if c.wants_chat:
		_button("Serve & hear them out 💬 (better tip, costs time)", main_row, func(): _serve(c.craving, true))
		_button("Serve & keep it quick ⏱", main_row, func(): _serve(c.craving, false))

	_label("Or suggest something else (they may say no):", 16, Palette.MUTED)
	var menu := _row()
	for o in _shift.offers:
		var id: String = o.drink.id
		var left: int = _shift.stock[id]
		var b := Button.new()
		b.text = "%s %s\n%s · %d left" % [o.drink.emoji, o.drink.name, _money(o.price), left]
		b.disabled = left <= 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): _serve(id, c.wants_chat))
		menu.add_child(b)

	var bottom := _row(null, BoxContainer.ALIGNMENT_END)
	_button("Turn them away", bottom, func():
		_shift.skip(_customer)
		_feed = "You waved %s along." % c.name
		_next_customer())
	_button("Breeze through the rest ⏩", bottom, func():
		_shift.auto_finish()
		_last_result = GameState.finish_shift("hands-on")
		_show_results())


func _serve(drink_id: String, engage: bool) -> void:
	var c := _customer
	var out := _shift.serve(c, drink_id, engage)
	var drink := Content.drink(drink_id)
	if out.declined:
		var declines: Array = Content.dialogue[GameState.voice_for(c.gen_id)].decline
		_feed = "✋ %s: “%s”" % [c.name, declines[hash(c.name + drink_id) % declines.size()]]
		# They stay in line and you try again.
		_show_service()
		return
	if not out.sold:
		_feed = "Out of %s %s!" % [drink.emoji, drink.name]
		_show_service()
		return
	var tip_text := " + %s tip!" % _money(out.tip) if out.tip > 0.0 else ""
	var chat_text := " (chatted, which took a while)" if out.engaged else ""
	_feed = "✔ %s %s to %s: %s%s%s" % [drink.emoji, drink.name, c.name, _money(out.price), tip_text, chat_text]
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
	_label("Day %d wrap-up · %s %s" % [r.day, loc.emoji, loc.name], 32)

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
	for d in Content.drinks:
		var info: Dictionary = r.drinks.get(d.id, {})
		if info.is_empty():
			continue
		var text := "%s %s × %d of %d" % [d.emoji, d.name, info.sold, info.stocked]
		if not prev.is_empty() and prev.drinks.has(d.id) and prev.drinks[d.id].stocked > 0:
			var diff: int = info.sold - prev.drinks[d.id].sold
			text += "   %s" % ("▲ +%d" % diff if diff > 0 else ("▼ %d" % diff if diff < 0 else "="))
		_label(text, 18, Palette.TEXT, sales)
	_label("🧾 Served %d of %d who came by (%s)" % [shift.served, shift.arrivals, "hands-on" if r.mode == "hands-on" else "breezed through"], 16, Palette.MUTED, sales)
	if shift.lost_to_stockout > 0:
		_label("😬 %d left: ran out of something they wanted" % shift.lost_to_stockout, 16, Palette.WARM, sales)
	if shift.lost_to_line > 0:
		_label("⏳ %d gave up on the line" % shift.lost_to_line, 16, Palette.WARM, sales)
	if shift.declined > 0:
		_label("✋ %d turned down a drink you pushed" % shift.declined, 16, Palette.WARM, sales)

	var lessons := _card(left, Palette.LAVENDER.lerp(Palette.BG, 0.55))
	_label("💡 What to try next", 18, Palette.TEXT, lessons)
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
		_label("Different from yesterday: %s %s %s → %s %s %s" % [pl.emoji, Content.weather.types[prev.weather_id].emoji, pl.name, loc.emoji, Content.weather.types[r.weather_id].emoji, loc.name], 14, Palette.MUTED, money)

	if not r.chatter.is_empty():
		var g: Dictionary = Content.generations[r.chatter.generation]
		var c := _card(right, Palette.LAVENDER.lerp(Palette.BG, 0.55))
		_label("%s %d customers chatted:" % [g.emoji, r.chatter.count], 14, Palette.MUTED, c)
		_label("“%s”" % r.chatter.line, 16, Palette.TEXT, c)
	var q: Dictionary = r.quip
	var qc := _card(right, Palette.PEACH.lerp(Palette.BG, 0.55))
	var who: Dictionary = q.character
	_label("%s %s  %s" % [who.emoji, who.name, Content.generations[who.generation].emoji], 14, Palette.MUTED, qc)
	_label("“%s”" % q.line, 18, Palette.TEXT, qc)

	var row := _row(null, BoxContainer.ALIGNMENT_END)
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
