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
var _difficulty := "easy"
var _on_title := false
var _mode_buttons: Array[Button] = []
var _blurb: Label
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
var _serial := 0             ## increments per customer; stale delayed callbacks check it
var _departed_serial := -1   ## the customer we already sent away (so it happens once)
var _resolved := false       ## this customer has been served or turned away
var _scene: TruckScene
var _person: Person
var _arrived := false
var _in_service := false
var _header_stats: Label
var _feed_label: Label
var _bar: ProgressBar
var _panel: VBoxContainer
var _action_buttons: Array[Button] = []


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
	_action_buttons.clear()
	_in_service = false
	_on_title = false
	_scene = null
	_person = null


func _make_scene(height: float, ambient: bool, progress: float, loc_id: String, weather_id: String) -> TruckScene:
	var sc := TruckScene.new()
	sc.custom_minimum_size = Vector2(0, height)
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.loc_id = loc_id
	sc.weather_id = weather_id
	sc.progress = progress
	sc.ambient = ambient
	_body.add_child(sc)
	return sc


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


func _commas(n: int) -> String:
	var t := str(n)
	return t if n < 1000 else "%s,%s" % [t.substr(0, t.length() - 3), t.substr(t.length() - 3)]


## Default stock for a fresh menu, scaled to how much cash the chosen mode starts with.
func _starting_servings(treat: bool) -> int:
	var scale := GameState.start_cash / 1000.0
	if scale < 0.3:
		return 0 if treat else 3
	return int(round((10 if treat else 15) * scale))


func _mix_text(location: Dictionary, compact := false) -> String:
	var short := {"gen_alpha": "Alpha", "gen_z": "Z", "millennial": "Mill.", "gen_x": "X", "boomer": "Boomer"}
	var parts: Array[String] = []
	for g in location.generations:
		var label: String = Content.generations[g].label
		if compact and short.has(g):
			label = short[g]
		parts.append("%s %d%%" % [label, int(round(location.generations[g] * 100.0))])
	if compact:
		return " · ".join(parts)
	# Two lines so three buttons fit across a row.
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
	_make_scene(250, true, 0.35, "school", "sunny")
	_label("Bussin Brews", 50).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label("A traveling drink truck. Real prices. Real weather. Real drama.", 20, Palette.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var card := _card(null, Palette.LAVENDER.lerp(Palette.BG, 0.5))
	_label("Choose your start", 20, Palette.TEXT, card)
	var modes := _row(card)
	var group := ButtonGroup.new()
	var blurb := _label("", 16, Palette.MUTED, card)
	_blurb = blurb
	_mode_buttons.clear()
	_on_title = true
	for d in Content.difficulties:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = d.id == _difficulty
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.text = "%s\n$%s" % [d.label, _commas(int(d.cash))]
		b.pressed.connect(func():
			_difficulty = d.id
			blurb.text = d.blurb)
		modes.add_child(b)
		_mode_buttons.append(b)
	blurb.text = Content.difficulty(_difficulty).blurb
	_label("Prices follow the real Consumer Price Index, starting January 2026. Keyboard: 1, 2, 3 pick a mode; Enter starts.", 15, Palette.MUTED, card)

	var saved := GameState.save_summary()
	if saved.is_empty():
		_button("Open for business", _foot_row(), _start_game, true)
	else:
		var d := Content.difficulty(saved.difficulty)
		_label("Saved game: day %d · cash %s · %s" % [saved.day, _money(saved.cash), d.label], 16, Palette.MUTED, _footer)
		var row := _foot_row()
		_button("New game", row, _confirm_new_game)
		_button("Continue", row, _continue_game, true)


func _confirm_new_game() -> void:
	var dlg := ConfirmationDialog.new()
	dlg.title = "Start a new game?"
	dlg.dialog_text = "This erases your saved game."
	dlg.ok_button_text = "Erase and start"
	dlg.cancel_button_text = "Keep my save"
	dlg.confirmed.connect(func():
		GameState.delete_save()
		_start_game())
	dlg.canceled.connect(dlg.queue_free)
	dlg.confirmed.connect(dlg.queue_free)
	add_child(dlg)
	dlg.popup_centered()


func _continue_game() -> void:
	var extra = GameState.load_game()
	if extra == null:
		_blurb.text = "Couldn't read the saved game. Start a new one."
		return
	_on_title = false
	_plan_loc = str(extra.get("plan_loc", "school"))
	_prices.clear()
	_servings.clear()
	# JSON turns whole numbers into floats, so restore the types the UI expects.
	for id in extra.get("prices", {}):
		_prices[id] = float(extra.prices[id])
	for id in extra.get("servings", {}):
		_servings[id] = int(extra.servings[id])
	_show_briefing()


## Saves at the end of each day, or clears the save when the run is over.
func _autosave() -> void:
	if GameState.is_game_over():
		GameState.delete_save()
	else:
		GameState.save_game({"plan_loc": _plan_loc, "prices": _prices, "servings": _servings})


func _start_game() -> void:
	_on_title = false
	GameState.new_game(0, _difficulty)
	_prices.clear()
	_servings.clear()
	_show_briefing()


## Keyboard fallback on the title screen: 1/2/3 choose a mode, Enter starts.
func _unhandled_key_input(event: InputEvent) -> void:
	if not _on_title or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	var idx := -1
	match event.keycode:
		KEY_1, KEY_KP_1: idx = 0
		KEY_2, KEY_KP_2: idx = 1
		KEY_3, KEY_KP_3: idx = 2
		KEY_ENTER, KEY_KP_ENTER:
			if GameState.has_save():
				_continue_game()
			else:
				_start_game()
			get_viewport().set_input_as_handled()
			return
	if idx >= 0 and idx < Content.difficulties.size():
		_difficulty = Content.difficulties[idx].id
		_blurb.text = Content.difficulties[idx].blurb
		for i in _mode_buttons.size():
			_mode_buttons[i].button_pressed = (i == idx)
		get_viewport().set_input_as_handled()


# --- briefing --------------------------------------------------------------

func _show_briefing() -> void:
	_reset()
	var top := _row()
	_label("Day %d · %s" % [GameState.day, GameCalendar.label(GameState.day)], 34, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Cash %s    Reputation %.2f" % [_money(GameState.cash), GameState.reputation], 24, Palette.TEXT, top)

	_make_scene(190, true, 0.3, _plan_loc, GameState.weather_id)
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
			_servings[d.id] = _starting_servings(false)
	for t in Content.treats:
		if not _prices.has(t.id):
			_prices[t.id] = snappedf(econ.fair_price(t, month), PRICE_STEP)
			_servings[t.id] = _starting_servings(true)

	var top := _row()
	_label("Plan · %s" % _weather_label(), 30, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label("Cash %s" % _money(GameState.cash), 24, Palette.TEXT, top)

	_scene = _make_scene(115, true, 0.3, _plan_loc, GameState.weather_id)

	# Two columns: where to park on the left, the menu in tabs on the right.
	var cols := _row()
	cols.add_theme_constant_override("separation", 18)
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(330, 0)
	left.add_theme_constant_override("separation", 8)
	cols.add_child(left)
	_label("Where to park", 20, Palette.TEXT, left)
	var group := ButtonGroup.new()
	for l in Content.locations:
		var b := Button.new()
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = l.id == _plan_loc
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		var last := GameState.last_visit(l.id)
		var last_text := "Never been here" if last.is_empty() else "Last: %s in %s (day %d)" % [_delta_money(last.profit), Content.weather.types[last.weather_id].label.to_lower(), last.day]
		b.text = "%s\nGas %s · permit %s · %d mi\n%s\n%s" % [l.name, _money(econ.trip_cost(l, month)), _money(float(l.permit)), l.miles, _mix_text(l, true), last_text]
		b.add_theme_font_size_override("font_size", 14)
		b.pressed.connect(func():
			_plan_loc = l.id
			_scene.set_location(l.id)
			_refresh_plan())
		left.add_child(b)

	var prev := GameState.last_result()
	var tabs := TabContainer.new()
	tabs.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(tabs)
	_menu_tab(tabs, "Drinks", Content.drinks, prev)
	_menu_tab(tabs, "Baked goods (upsells)", Content.treats, prev)

	_summary = _label("", 18, Palette.TEXT, _footer)
	var row := _foot_row()
	if not prev.is_empty():
		_button("Restock from yesterday's sales", row, _restock_from_yesterday)
	_go_buttons.append(_button("Breeze through the day", row, _breeze))
	_go_buttons.append(_button("Serve customers", row, _start_service, true))
	_refresh_plan()


func _menu_tab(tabs: TabContainer, title: String, items: Array, prev: Dictionary) -> void:
	var econ: Economy = Content.economy
	var month := GameState.month()
	var page := VBoxContainer.new()
	page.name = title
	tabs.add_child(page)
	if items == Content.treats:
		_label("After a drink sells, offer one of these. Older customers like muffins and cookies, millennials like protein balls.", 14, Palette.MUTED, page)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 3)
	page.add_child(grid)
	for h in ["Item", "Fair", "Your price", "Cost", "Servings", "Yesterday" if not prev.is_empty() else ""]:
		_label(h, 14, Palette.MUTED, grid)
	for d in items:
		_label(d.name, 17, Palette.TEXT, grid)
		_label(_money(econ.fair_price(d, month)), 17, Palette.MUTED, grid)
		_stepper(grid, d.id, _price_labels, -PRICE_STEP, PRICE_STEP, func(id: String, delta: float):
			_prices[id] = clampf(snappedf(_prices[id] + delta, PRICE_STEP), 0.5, 25.0))
		_label(_money(econ.serving_cost(d, month)), 17, Palette.MUTED, grid)
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
	minus.custom_minimum_size = Vector2(32, 0)
	r.add_child(minus)
	var value := Label.new()
	value.custom_minimum_size = Vector2(56, 0)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	value.add_theme_font_size_override("font_size", 17)
	r.add_child(value)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(32, 0)
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
	_feed = "The window is open."
	_reset()
	_in_service = true
	var top := _row()
	_label("Service · %s" % Content.location(_plan_snapshot.location_id).name, 28, Palette.TEXT, top).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_header_stats = _label("", 22, Palette.TEXT, top)
	_scene = _make_scene(250, false, 0.05, _plan_snapshot.location_id, GameState.weather_id)
	_bar = ProgressBar.new()
	_bar.max_value = 1.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.add_theme_stylebox_override("background", Palette.box(Palette.BLUE.lerp(Palette.BG, 0.5), 6, Color.TRANSPARENT, 0))
	_bar.add_theme_stylebox_override("fill", Palette.box(Palette.SAGE, 6, Color.TRANSPARENT, 0))
	_body.add_child(_bar)
	_feed_label = _label("", 16, Palette.MUTED)
	_panel = VBoxContainer.new()
	_panel.add_theme_constant_override("separation", 8)
	_body.add_child(_panel)

	var bottom := _foot_row()
	_button("Turn them away", bottom, _turn_away)
	_button("Breeze through the rest", bottom, func():
		_shift.auto_finish()
		_finish_hands_on())
	# Wait for the layout pass so the first customer walks to the right spot.
	var guard := 0
	while not _scene.is_laid_out() and guard < 10:
		await get_tree().process_frame
		guard += 1
	if _in_service:
		_next_customer()


func _update_header() -> void:
	var res := _shift.result
	_header_stats.text = "Sales %s · Tips %s" % [_money(res.revenue), _money(res.tips)]
	_bar.value = _shift.progress()
	_feed_label.text = _feed
	_scene.set_progress(_shift.progress())


func _later(seconds: float, fn: Callable) -> void:
	get_tree().create_timer(seconds).timeout.connect(func():
		if _in_service:
			fn.call())


## Like _later, but dropped if a different customer is at the window by then.
func _later_for_customer(seconds: float, fn: Callable) -> void:
	var serial := _serial
	_later(seconds, func():
		if serial == _serial:
			fn.call())


func _next_customer() -> void:
	_upsell_pending = false
	_resolved = false
	_serial += 1
	_customer = _shift.next_customer()
	for e in _shift.drain_events():
		var p := _scene.spawn_passerby(e.gen_id)
		if p != null and e.kind == "stockout":
			p.say("Aw, you're out!", 2.0)
	_update_header()
	if _customer.is_empty():
		_clear_panel()
		_later(0.9, _finish_hands_on)
		return
	var c := _customer
	_arrived = false
	_person = _scene.spawn_customer(c.name, c.gen_id, _gen_color(c.gen_id))
	_person.arrived.connect(_on_arrived.bind(c), CONNECT_ONE_SHOT)
	_build_order_panel()


func _on_arrived(c: Dictionary) -> void:
	if c != _customer:
		return
	_arrived = true
	var voice: String = c.gen_id
	var orders: Array = Content.dialogue[voice].order
	var craving := Content.drink(c.craving)
	_person.say(orders[hash(c.name + str(_shift.result.served)) % orders.size()] % craving.name)
	for b in _action_buttons:
		if is_instance_valid(b):
			b.disabled = false


func _finish_hands_on() -> void:
	_last_result = GameState.finish_shift("hands-on")
	_show_results()


func _clear_panel() -> void:
	for ch in _panel.get_children():
		_panel.remove_child(ch)
		ch.queue_free()
	_action_buttons.clear()


func _act_button(text: String, parent: Node, cb: Callable, primary := false) -> Button:
	var b := _button(text, parent, cb, primary)
	b.disabled = not _arrived
	_action_buttons.append(b)
	return b


func _build_order_panel() -> void:
	_clear_panel()
	var c := _customer
	var craving := Content.drink(c.craving)
	var info := _row(_panel)
	_label("%s wants %s." % [c.name, craving.name], 18, Palette.TEXT, info)
	_chip(Content.generations[c.gen_id].label, _gen_color(c.gen_id), info)
	if c.wants_chat:
		var voice: String = c.gen_id
		var chats: Array = Content.dialogue[voice].chat
		_label("They look like they want to chat: “%s”" % chats[hash(c.name) % chats.size()], 15, Palette.MUTED, _panel)

	var main_row := _row(_panel)
	var pick := _act_button("Serve what they asked for  [Space]", main_row, func(): _serve(c.craving, true), true)
	_space_shortcut(pick)
	if c.wants_chat:
		_act_button("Serve and hear them out (better tip, costs time)", main_row, func(): _serve(c.craving, true))
		_act_button("Serve and keep it quick", main_row, func(): _serve(c.craving, false))

	_label("Or suggest a different drink (they may say no):", 15, Palette.MUTED, _panel)
	var menu := _row(_panel)
	for o in _shift.offers:
		var id: String = o.drink.id
		var left: int = _shift.stock[id]
		var b := _act_button("%s\n%s · %d left" % [o.drink.name, _money(o.price), left], menu, func(): _serve(id, c.wants_chat))
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# Sold out, or they already said no to a suggestion and want what they ordered.
		if left <= 0 or (c.get("insists", false) and id != c.craving):
			b.set_meta("sold_out", true)
	for b in _action_buttons:
		if b.has_meta("sold_out"):
			b.disabled = true


func _cup_color(drink_id: String) -> Color:
	var palette := [Palette.ACCENT, Palette.BLUE, Palette.SAGE, Palette.LAVENDER, Palette.PEACH]
	for i in Content.drinks.size():
		if Content.drinks[i].id == drink_id:
			return palette[i % palette.size()]
	return Palette.ACCENT


func _serve(drink_id: String, engage: bool) -> void:
	if _resolved or not _arrived or _customer.is_empty():
		return  # already served (e.g. a double press) or still walking up
	var c := _customer
	var out := _shift.serve(c, drink_id, engage)
	var drink := Content.drink(drink_id)
	if out.declined:
		var declines: Array = Content.dialogue[c.gen_id].decline
		var line: String = declines[hash(c.name + drink_id) % declines.size()]
		_person.say(line, 2.4)
		_feed = "%s said no to the %s and will stick with what they ordered." % [c.name, drink.name]
		_update_header()
		_build_order_panel()
		return
	if not out.sold:
		_feed = "Out of %s." % drink.name
		_update_header()
		return
	var tip_text := " + %s tip" % _money(out.tip) if out.tip > 0.0 else ""
	var chat_text := " (chatted, which took a while)" if out.engaged else ""
	_resolved = true
	_feed = "Sold %s to %s: %s%s%s." % [drink.name, c.name, _money(out.price), tip_text, chat_text]
	_person.clear_say()
	_scene.hand_over(_person, _cup_color(drink_id))
	_scene.float_text("+%s%s" % [_money(out.price), tip_text.replace(" + ", " +").replace(" tip", " tip")], Palette.GOOD)
	_update_header()
	if _shift.has_treats_in_stock():
		_upsell_pending = true
		_build_upsell_panel()
	else:
		_clear_panel()
		_later_for_customer(0.5, _depart)


## The customer leaves with their cup and the next one steps up.
func _depart(sad := false) -> void:
	# Only a customer who has been served or turned away leaves, and only once. This makes a
	# double press (or a late timer) harmless: the next customer hasn't been served yet.
	if not _resolved or _departed_serial == _serial:
		return
	_departed_serial = _serial
	if is_instance_valid(_person):
		_scene.send_away(_person, sad)
	_next_customer()


func _turn_away() -> void:
	# Only someone still waiting to be served can be turned away.
	if _customer.is_empty() or not is_instance_valid(_person) or _resolved or not _arrived:
		return
	_resolved = true
	_shift.skip(_customer)
	_feed = "You waved %s along." % _customer.name
	_person.say("Oh. Okay.", 1.0)
	_depart(true)


## After a drink sells, you can offer one add-on from the bakery case.
func _build_upsell_panel() -> void:
	_clear_panel()
	var c := _customer
	var drink := Content.drink(c.sold_drink)
	var info := _row(_panel)
	_label("%s has their %s. Offer something from the bakery case?" % [c.name, drink.name], 18, Palette.TEXT, info)
	_chip(Content.generations[c.gen_id].label, _gen_color(c.gen_id), info)
	_label("(Pushy offers cost time, and the wrong treat gets a no.)", 14, Palette.MUTED, info)

	var menu := _row(_panel)
	for t in _shift.treat_offers:
		var id: String = t.treat.id
		var left: int = _shift.treat_stock[id]
		var chance := _shift.treat_chance(c, id)
		var hint := "good bet" if chance >= 0.4 else ("maybe" if chance >= 0.2 else "long shot")
		var b := _button("%s\n%s · %d left · %s" % [t.treat.name, _money(t.price), left, hint], menu, func(): _upsell(id))
		b.disabled = left <= 0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var skip := _button("No add-on, next customer  [Space]", _panel, _depart, true)
	_space_shortcut(skip)


func _upsell(treat_id: String) -> void:
	if not _upsell_pending:
		return
	_upsell_pending = false
	var c := _customer
	var treat := Content.item(treat_id)
	var out := _shift.upsell(c, treat_id)
	var voice: String = c.gen_id
	_clear_panel()
	if out.accepted:
		var yes: Array = Content.dialogue[voice].upsell_yes
		_person.say(yes[hash(c.name + treat_id) % yes.size()], 1.6)
		_scene.float_text("+%s %s" % [_money(out.price), treat.name], Palette.GOOD)
		_feed = "Added a %s for %s." % [treat.name, _money(out.price)]
	else:
		var no: Array = Content.dialogue[voice].upsell_no
		_person.say(no[hash(c.name + treat_id) % no.size()], 1.6)
		_feed = "%s passed on the %s." % [c.name, treat.name]
	_update_header()
	_later_for_customer(1.0, _depart)


# --- results ---------------------------------------------------------------

func _show_results() -> void:
	_reset()
	_autosave()
	var r := _last_result
	var prev := {}
	if GameState.history.size() >= 2:
		prev = GameState.history[GameState.history.size() - 2]
	var loc := Content.location(r.location_id)
	var shift: Dictionary = r.shift
	_label("Day %d wrap-up · %s" % [r.day, loc.name], 32)
	_make_scene(170, true, 0.95, r.location_id, r.weather_id)

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

	if not GameState.is_game_over():
		_label("Progress saved.", 14, Palette.MUTED, _footer)
	var row := _foot_row()
	if GameState.is_game_over():
		_button("The truck is out of gas money. Start over", row, func():
			_difficulty = "easy"
			_show_title(), true)
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
