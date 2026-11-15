class_name MissionReport
extends CanvasLayer
## The debrief: what happened, why, and how well it went.
##
##   var report := MissionReport.open(self)
##   report.chosen.connect(func(action: StringName) -> void: ...)   # &"retry", &"academy", &"stay"
##
## It reads the finished mission from ResourceSim (including its hour-by-hour history)
## and MissionDirector, and changes nothing. Three ratings, each out of three stars:
##   CREW SAFETY     how quickly everyone was behind the shield
##   POWER           whether the battery lasted and Life Support stayed on
##   FOOD + SCIENCE  what the crops and experiments got done
## The chart shows the battery over the whole shift with the sunlight underneath it,
## so a player can point at the hour their plan worked (or didn't).

signal chosen(action: StringName)

const RANKS: Array[String] = [
	"Back to the simulator", "Back to the simulator", "Cadet", "Cadet", "Junior Astronaut",
	"Junior Astronaut", "Outpost Specialist", "Outpost Specialist", "Mission Specialist", "Flight-ready Commander",
]

## Three stars for power needs at least this much battery left at the lowest point.
const POWER_RESERVE := 3.5

var _safety: int = 0
var _power: int = 0
var _yield: int = 0
var _result: String = ""
var _why: String = ""
var _best_exposure: float = 0.0
var _worst_exposure: float = 0.0
var _body: VBoxContainer
var _sources: VBoxContainer
var _first_button: Button
var _done: bool = false
var _time: float = 0.0
var _chart: Control
var _stars_view: Control


static func open(parent: Node) -> MissionReport:
	var report := MissionReport.new()
	parent.add_child(report)
	return report


## Three star counts and the headline, worked out from the finished simulation.
static func rate() -> Dictionary:
	var d := MissionDirector
	var starved := ResourceSim.hours_run - ResourceSim.life_support_ok_hours
	var safety := 0
	if d.reached_shelter:
		safety = 3 if d.hours_unsheltered <= 1 else (2 if d.hours_unsheltered <= 3 else 1)
	var power := 3
	if starved > 0:
		power = 0
	elif ResourceSim.emergency_shutoffs > 0:
		power = 1
	elif ResourceSim.battery_min < POWER_RESERVE:
		power = 2
	var crops := ResourceSim.crop_health
	var science := float(ResourceSim.science_points)
	var harvest := 0
	if crops >= 80.0 and science >= 9.0:
		harvest = 3
	elif crops >= 74.0 and science >= 7.0:
		harvest = 2
	elif crops >= 60.0 and science >= 4.0:
		harvest = 1
	return {"safety": safety, "power": power, "yield": harvest, "starved": starved}


func _ready() -> void:
	layer = 40
	MissionDirector.push_ui()
	_work_out()
	_build()


func _exit_tree() -> void:
	MissionDirector.pop_ui()


func _process(delta: float) -> void:
	_time += delta
	if _time < 2.0:
		if _stars_view != null:
			_stars_view.queue_redraw()
		if _chart != null:
			_chart.queue_redraw()


func _work_out() -> void:
	var d := MissionDirector
	var r := rate()
	_safety = r["safety"]
	_power = r["power"]
	_yield = r["yield"]
	var starved: int = r["starved"]
	_result = "Steady outpost"
	_why = "The shelter's mass stopped most of the storm's particles, and your power plan kept the battery above empty through the shadow."
	if not d.reached_shelter:
		_result = "Caught outside the shield"
		_why = "The crew never got behind the shelter walls, so exposure climbed every hour of the storm. Run north and hold E on the hatch as soon as the alert sounds."
	elif starved > 0:
		_result = "Life Support lost power"
		_why = "The battery emptied in the dark, so even Life Support went without power. Bank more charge before the shadow: pause the rover, dim the grow lights."
	elif ResourceSim.emergency_shutoffs > 0:
		_result = "Close call"
		_why = "The battery ran flat, so the outpost switched off %d lower-priority load(s) by itself to protect Life Support. A fuller battery before the shadow avoids that." % ResourceSim.emergency_shutoffs
	elif _safety == 3 and _power == 3 and _yield == 3:
		_result = "Textbook mission"
		_why = "Fast to shelter, battery never in danger, and the crops and experiments still got their work done. That balance is the whole job."
	if d.reached_shelter and d.hours_unsheltered >= 2:
		_why += " Every storm hour outside the shield added to the exposure."
	if d.reached_shelter and starved == 0 and ResourceSim.emergency_shutoffs == 0 and _yield <= 1 and _result != "Textbook mission":
		_why += " You had battery to spare: next time try keeping the science or the grow lights running."
	# What the exposure would have been with instant shelter, and with none (same storm).
	var shield := ResourceSim.shelter_readiness / 100.0
	var hours := float(ResourceSim.hours_run)
	var storm := float(d.storm_hours_total())
	var drizzle := hours * 0.1 * (1.0 - 0.2 * shield)
	_best_exposure = drizzle + storm * 2.0 * (1.0 - 0.9 * shield)
	_worst_exposure = drizzle + storm * 2.0


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.position = Vector2(12, 8)
	frame.size = Vector2(456, 254)
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, UiKit.PANEL, 8))
	add_child(frame)

	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 3)
	frame.add_child(_body)

	# Heading: title, headline and the overall stars.
	var head := HBoxContainer.new()
	_body.add_child(head)
	var titles := VBoxContainer.new()
	titles.add_theme_constant_override("separation", 0)
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(titles)
	titles.add_child(UiKit.label("MISSION REPORT  /  %s" % GameState.player_name.to_upper(), "small", UiKit.TEXT_DIM))
	titles.add_child(UiKit.label(_result, "title", UiKit.AMBER if (_safety + _power) >= 4 else UiKit.RED))
	_stars_view = Control.new()
	_stars_view.custom_minimum_size = Vector2(150, 24)
	_stars_view.draw.connect(_draw_total)
	head.add_child(_stars_view)

	_chart = Control.new()
	_chart.custom_minimum_size = Vector2(0, 74)
	_chart.draw.connect(_draw_chart)
	_body.add_child(_chart)

	var d := MissionDirector
	var shelter_words := "Never reached the shelter."
	if d.reached_shelter:
		shelter_words = "Shielded after %d storm hour%s." % [d.hours_unsheltered, "" if d.hours_unsheltered == 1 else "s"]
	_add_row("CREW SAFETY", _safety, UiKit.AMBER, "%s Exposure %.1f (best %.1f, worst %.1f)." % [shelter_words, ResourceSim.exposure_log, _best_exposure, _worst_exposure])
	_add_row("POWER", _power, UiKit.TEAL, "Lowest battery %d of %d units. Life Support powered %d of %d hours." % [
		int(ResourceSim.battery_min), int(ResourceSim.battery_capacity), ResourceSim.life_support_ok_hours, ResourceSim.hours_run])
	_add_row("FOOD + SCIENCE", _yield, UiKit.GREEN, "Crop health %d of 100. Science %d points." % [int(ResourceSim.crop_health), ResourceSim.science_points])

	var why := UiKit.label("WHY: " + _why, "small", UiKit.TEXT)
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.custom_minimum_size = Vector2(430, 32)
	why.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(why)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 4)
	_body.add_child(buttons)
	_first_button = _add_button(buttons, "Try again", func() -> void: _finish(&"retry"))
	_add_button(buttons, "Field notes %d/%d" % [FieldNotes.unlocked_count(), FieldNotes.NOTES.size()], func() -> void: PauseMenu.open_page("notes"))
	_add_button(buttons, "Sources", _show_sources)
	_add_button(buttons, "Look around", func() -> void: _finish(&"stay"))
	_add_button(buttons, "Academy", func() -> void: _finish(&"academy"))
	_first_button.grab_focus.call_deferred()

	# Sources page (hidden until asked for).
	_sources = VBoxContainer.new()
	_sources.visible = false
	_sources.add_theme_constant_override("separation", 5)
	frame.add_child(_sources)
	_sources.add_child(UiKit.label("SOURCE NOTES", "title", UiKit.AMBER))
	var text := "Training scenario: the solar particle event in this run is FICTIONAL."
	if d.sep_is_real:
		text = "EVENT  NASA CCMC DONKI solar energetic particle record (archived copy, retrieved %s).\nID  %s\nTIME  %s        INSTRUMENT  %s\nLINK  %s" % [
			d.sep_retrieved, d.sep_event_id(), d.sep_time_text(), d.sep_instrument(), d.sep_link()]
	text += "\n\nThis record is a detection near Earth, not a radiation dose at a lunar outpost. Exposure, battery and power are simplified game units, and time is compressed. The sunlight shadow comes from terrain and has nothing to do with the storm.\n\nRadiation background: NASA, How NASA Will Protect Astronauts From Space Radiation at the Moon (science.nasa.gov). More facts and their sources are in your Field notes."
	var source_label := UiKit.label(text, "small", UiKit.TEXT)
	source_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	source_label.custom_minimum_size = Vector2(430, 180)
	source_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sources.add_child(source_label)
	var back := Button.new()
	back.text = "Back to the report"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(_hide_sources)
	_sources.add_child(back)


func _add_row(title: String, stars: int, color: Color, text: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_body.add_child(row)
	var name_label := UiKit.label(title, "small", color)
	name_label.custom_minimum_size.x = 76
	row.add_child(name_label)
	var view := Control.new()
	view.custom_minimum_size = Vector2(34, 10)
	view.draw.connect(func() -> void:
		for i in 3:
			_star(view, Vector2(5 + i * 11, 5), 4.5, color if i < stars else UiKit.LINE, i < stars))
	row.add_child(view)
	var detail := UiKit.label(text, "small", UiKit.TEXT)
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.clip_text = true
	row.add_child(detail)


func _add_button(parent: Control, text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(action)
	parent.add_child(b)
	return b


func _show_sources() -> void:
	_body.visible = false
	_sources.visible = true
	(_sources.get_child(_sources.get_child_count() - 1) as Button).grab_focus()


func _hide_sources() -> void:
	_sources.visible = false
	_body.visible = true
	_first_button.grab_focus()


func _finish(action: StringName) -> void:
	if _done:
		return
	_done = true
	Sfx.play(&"confirm")
	chosen.emit(action)
	queue_free()


# ---------------------------------------------------------------- drawing

func _star(item: CanvasItem, at: Vector2, radius: float, color: Color, filled: bool) -> void:
	var points := PackedVector2Array()
	for i in 10:
		var r := radius if i % 2 == 0 else radius * 0.45
		points.append(at + Vector2.UP.rotated(TAU * float(i) / 10.0) * r)
	if filled:
		item.draw_colored_polygon(points, color)
	else:
		points.append(points[0])
		item.draw_polyline(points, color, 1.0)


func _draw_total() -> void:
	var total := _safety + _power + _yield
	var c := _stars_view
	var rank := RANKS[clampi(total, 0, RANKS.size() - 1)]
	UiKit.draw_text(c, Vector2(0, 8), rank.to_upper(), "small", UiKit.TEXT, 150.0, HORIZONTAL_ALIGNMENT_RIGHT)
	for i in 9:
		# The stars pop in one after another.
		var shown := _time * 9.0 > float(i)
		var lit := i < total and shown
		_star(c, Vector2(150 - 9 * 11 + i * 11 + 5, 17), 4.5, UiKit.AMBER if lit else UiKit.LINE, lit)


func _draw_chart() -> void:
	var c := _chart
	var history := ResourceSim.history
	var area := Rect2(34, 4, c.size.x - 40, c.size.y - 22)
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), UiKit.INK)
	c.draw_rect(Rect2(0, 0, c.size.x, c.size.y), UiKit.LINE, false, 1.0)
	UiKit.draw_text(c, Vector2(4, 11), "BATTERY", "small", UiKit.TEAL)
	UiKit.draw_text(c, Vector2(4, c.size.y - 6), "SUN", "small", UiKit.AMBER)
	if history.is_empty():
		return
	var count := history.size()
	var step := area.size.x / float(count)
	var capacity := ResourceSim.battery_capacity
	# Storm hours shaded red while the crew was outside, green once sheltered.
	var storm_start := -1
	for i in count:
		var entry: Dictionary = history[i]
		var column := Rect2(area.position.x + i * step, area.position.y, step, area.size.y)
		if entry["sep"]:
			if storm_start < 0:
				storm_start = i
			c.draw_rect(column, Color(UiKit.GREEN, 0.14) if entry["sheltered"] else Color(UiKit.RED, 0.22))
		# Sunlight strip under the chart.
		var sun: float = entry["sun"]
		c.draw_rect(Rect2(column.position.x + 1, area.end.y + 4, step - 2, 6), Color("27304f").lerp(UiKit.AMBER, sun))
	# One faint line per battery cell.
	var cell := ResourceSim.battery_cell_size
	var level := cell
	while level < capacity:
		var y := area.end.y - area.size.y * (level / capacity)
		c.draw_line(Vector2(area.position.x, y), Vector2(area.end.x, y), Color(UiKit.LINE, 0.45), 1.0)
		level += cell
	c.draw_line(Vector2(area.position.x, area.end.y), Vector2(area.end.x, area.end.y), UiKit.LINE, 1.0)
	# The battery line, drawn in as the report opens.
	var points := PackedVector2Array()
	var lowest := 0
	for i in count:
		var battery: float = history[i]["battery"]
		if battery < float(history[lowest]["battery"]):
			lowest = i
		points.append(Vector2(area.position.x + (i + 0.5) * step, area.end.y - area.size.y * (battery / capacity)))
	var shown := clampi(int(_time * 22.0), 1, count)
	if shown >= 2:
		c.draw_polyline(points.slice(0, shown), UiKit.TEAL, 2.0)
	for i in shown:
		var starved: bool = history[i]["starved"]
		c.draw_rect(Rect2(points[i] - Vector2(1.5, 1.5), Vector2(3, 3)), UiKit.RED if starved else Color.WHITE)
	if shown >= count:
		var low := points[lowest]
		var label_x := 4.0 if low.x < area.end.x - 40.0 else -34.0
		UiKit.draw_text(c, low + Vector2(label_x, -4 if low.y > area.position.y + 12 else 11), "lowest", "small", UiKit.TEXT_DIM)
		if storm_start >= 0:
			var x := area.position.x + storm_start * step
			c.draw_line(Vector2(x, area.position.y), Vector2(x, area.end.y), UiKit.RED, 1.0)
			UiKit.draw_text(c, Vector2(x + 3, area.position.y + 8), "ALERT", "small", UiKit.RED)
			var d := MissionDirector
			if d.reached_shelter:
				var sx := area.position.x + (storm_start + d.hours_unsheltered) * step
				c.draw_line(Vector2(sx, area.position.y + 10), Vector2(sx, area.end.y), UiKit.GREEN, 1.0)
				UiKit.draw_text(c, Vector2(sx + 3, area.position.y + 18), "SEALED IN", "small", UiKit.GREEN)
