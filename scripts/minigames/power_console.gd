extends Control
## Power Console — a focused panel that opens over the world.
##
## It only READS state from ResourceSim's snapshot (via EventBus.resources_changed)
## and ASKS ResourceSim to change things (set_load_enabled, paused, time_scale).
##
## training_mode = true: a scripted shadow window (FICTIONAL training scenario).
##   Goal: reach the end of the window without the battery running out.
##   Fail -> instant feedback and Retry. Pass -> Power Console certification.
## embedded = true: opened as an overlay; Close returns to the same spot in the room.
##
## Works with the mouse or the keyboard: arrows move between switches and buttons,
## E / Space / Enter flips or presses the one in focus.

signal closed

const SUN_COLOR := Color("ffc45e")
const SHADOW_COLOR := Color("27304f")
const FORECAST_HOURS := 10

var training_mode: bool = false
var embedded: bool = false

var _state: String = "ready"  # ready, running, failed, passed
var _load_buttons: Dictionary = {}  # StringName -> CheckButton
var _clock_label: Label
var _power_label: Label
var _battery_label: Label
var _battery_view: Control
var _forecast_view: Control
var _meters: Dictionary = {}        # String -> ProgressBar
var _log_label: Label
var _log_box: PanelContainer
var _retry_button: Button
var _go_button: Button
var _snapshot: Dictionary = {}
var _time: float = 0.0


func _ready() -> void:
	MissionDirector.push_ui()
	if training_mode:
		_reset_training()
	else:
		ResourceSim.paused = false
	_build_ui()
	EventBus.resources_changed.connect(_on_resources_changed)
	EventBus.brownout.connect(_on_brownout)
	EventBus.game_hour_passed.connect(_on_game_hour_passed)
	_on_resources_changed(ResourceSim.get_snapshot())


func _exit_tree() -> void:
	MissionDirector.pop_ui()


func _process(delta: float) -> void:
	_time += delta
	if _state == "running" and _forecast_view != null:
		_forecast_view.queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _input(event: InputEvent) -> void:
	# E works like Enter on whichever switch or button has the focus.
	if event is InputEventKey and event.pressed and not event.is_echo() and (event as InputEventKey).physical_keycode == KEY_E:
		var focus := get_viewport().gui_get_focus_owner() as BaseButton
		if focus != null and is_ancestor_of(focus) and not focus.disabled:
			get_viewport().set_input_as_handled()
			if focus.toggle_mode:
				focus.button_pressed = not focus.button_pressed
			else:
				focus.pressed.emit()


func _reset_training() -> void:
	_state = "ready"
	ResourceSim.paused = true
	ResourceSim.time_scale = 1.0
	ResourceSim.seconds_per_game_hour = 2.0
	ResourceSim.reset_state(0, MissionDirector.TRAINING_START_BATTERY, MissionDirector.TRAINING_PATTERN)
	if _log_label != null:
		_say(_goal_text(), UiKit.TEAL)
		_retry_button.visible = false
		_go_button.grab_focus()


func _goal_text() -> String:
	return "GOAL: the Sun is about to hide behind a ridge. Keep the battery from running out for %d hours. Switch off something that can wait, then press Go." % MissionDirector.TRAINING_HOURS


# ---------------------------------------------------------------- UI building

func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.position = Vector2(10, 8)
	frame.size = Vector2(460, 254)
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, UiKit.PANEL, 7))
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 4)
	frame.add_child(root)

	# Title row: name, clock, speed controls.
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 4)
	root.add_child(title_row)
	var title := UiKit.label("POWER CONSOLE TRAINING" if training_mode else "POWER CONSOLE", "title", UiKit.AMBER)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_clock_label = UiKit.label("", "small", UiKit.TEXT)
	title_row.add_child(_clock_label)
	_add_speed_button(title_row, "Pause", 0.0)
	_go_button = _add_speed_button(title_row, "Go", 1.0)
	_add_speed_button(title_row, "Fast", 4.0)
	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.visible = false
	_retry_button.pressed.connect(_reset_training)
	title_row.add_child(_retry_button)
	var close := Button.new()
	close.text = "Close"
	close.tooltip_text = "Esc"
	close.pressed.connect(_close)
	title_row.add_child(close)

	# Sunlight forecast: one bar per hour; tall and gold = full Sun, flat and dark = shadow.
	var forecast_row := HBoxContainer.new()
	forecast_row.add_theme_constant_override("separation", 8)
	root.add_child(forecast_row)
	var forecast_words := VBoxContainer.new()
	forecast_words.add_theme_constant_override("separation", 0)
	forecast_row.add_child(forecast_words)
	forecast_words.add_child(UiKit.label("SUNLIGHT FORECAST", "small", UiKit.AMBER))
	forecast_words.add_child(UiKit.label("next %d hours" % FORECAST_HOURS, "small", UiKit.TEXT_DIM))
	_forecast_view = Control.new()
	_forecast_view.custom_minimum_size = Vector2(180, 24)
	_forecast_view.draw.connect(_draw_forecast)
	forecast_row.add_child(_forecast_view)
	_power_label = UiKit.label("", "small", UiKit.TEXT)
	_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	forecast_row.add_child(_power_label)

	root.add_child(HSeparator.new())

	# Two columns: switches on the left, gauges on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	columns.add_child(left)
	left.add_child(UiKit.label("SWITCHES   1 = most important", "small", UiKit.TEAL))
	for def in ResourceSim.loads:
		_add_load_row(left, def)

	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 176
	right.add_theme_constant_override("separation", 3)
	columns.add_child(right)
	_battery_label = UiKit.label("", "small", UiKit.TEAL)
	right.add_child(_battery_label)
	_battery_view = Control.new()
	_battery_view.custom_minimum_size = Vector2(176, 22)
	_battery_view.draw.connect(_draw_battery)
	right.add_child(_battery_view)
	right.add_child(UiKit.label("LIFE SUPPORT", "small", UiKit.TEAL))
	_meters["oxygen"] = _add_meter(right, "Oxygen", UiKit.TEAL)
	_meters["water"] = _add_meter(right, "Water", Color("4aa8d8"))
	_meters["co2_scrub"] = _add_meter(right, "Air scrub", UiKit.VIOLET)
	_meters["crops"] = _add_meter(right, "Crops", UiKit.GREEN)
	right.add_child(UiKit.label("Simple game units, not real numbers.", "small", UiKit.TEXT_DIM))

	# Goal / feedback line.
	_log_box = PanelContainer.new()
	_log_box.add_theme_stylebox_override("panel", UiKit.flat_box(UiKit.INK, UiKit.TEAL_DIM, 5))
	root.add_child(_log_box)
	_log_label = UiKit.label("", "small", UiKit.TEXT)
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(430, 30)
	_log_box.add_child(_log_label)
	_say(_goal_text() if training_mode else "Tip: bank charge in the battery while the Sun is up.", UiKit.TEAL)
	_go_button.grab_focus.call_deferred()


func _say(text: String, color: Color) -> void:
	_log_label.text = text
	_log_box.add_theme_stylebox_override("panel", UiKit.flat_box(UiKit.INK, color, 5))


func _add_speed_button(parent: Control, text: String, speed: float) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func() -> void:
		if training_mode and (_state == "failed" or _state == "passed"):
			return
		ResourceSim.paused = speed == 0.0
		if speed > 0.0:
			ResourceSim.time_scale = speed
			if _state == "ready":
				_state = "running"
	)
	parent.add_child(b)
	return b


func _add_load_row(parent: Control, def: LoadDef) -> void:
	var check := CheckButton.new()
	check.text = "%d  %s  (uses %d)" % [def.priority, def.display_name, int(def.power_draw)]
	check.tooltip_text = def.why_it_matters
	if not def.can_disable:
		check.disabled = true
		check.focus_mode = Control.FOCUS_NONE
		check.text += "  always on"
	check.toggled.connect(func(on: bool) -> void:
		if not ResourceSim.set_load_enabled(def.id, on):
			check.set_pressed_no_signal(not on)
	)
	# Pointing at or focusing a switch explains what it powers.
	var explain := func() -> void:
		if _state == "ready" or not training_mode:
			_say("%s: %s" % [def.display_name.to_upper(), def.why_it_matters], UiKit.TEAL_DIM)
	check.mouse_entered.connect(explain)
	check.focus_entered.connect(explain)
	parent.add_child(check)
	_load_buttons[def.id] = check


func _add_meter(parent: Control, label_text: String, color: Color) -> ProgressBar:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	parent.add_child(row)
	var label := UiKit.label(label_text, "small", UiKit.TEXT)
	label.custom_minimum_size = Vector2(52, 0)
	row.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(90, 7)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.max_value = 100.0
	var fill := UiKit.flat_box(color, Color.TRANSPARENT, 0)
	fill.border_color = UiKit.INK
	fill.set_border_width_all(1)
	bar.add_theme_stylebox_override("fill", fill)
	row.add_child(bar)
	return bar


# ---------------------------------------------------------------- drawing

func _draw_forecast() -> void:
	var c := _forecast_view
	var forecast := ResourceSim.illumination_forecast(FORECAST_HOURS)
	var step := 18.0
	for i in forecast.size():
		var slot := Rect2(i * step, 0, step - 3, c.size.y - 6)
		c.draw_rect(slot, SHADOW_COLOR)
		var h := roundf(forecast[i] * slot.size.y)
		if h > 0.0:
			c.draw_rect(Rect2(slot.position.x, slot.end.y - h, slot.size.x, h), SUN_COLOR.darkened(0.25 * (1.0 - forecast[i])))
		if i == 0:
			# "Now" marker.
			var tip := Vector2(slot.position.x + slot.size.x / 2.0, c.size.y - 1)
			c.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(4, 0), tip + Vector2(-4, 0)]), Color.WHITE)
	UiKit.draw_text(c, Vector2(12, c.size.y), "now", "small", UiKit.TEXT_DIM)


func _draw_battery() -> void:
	var c := _battery_view
	if _snapshot.is_empty():
		return
	var total: int = _snapshot["battery_cells_total"]
	var capacity: float = _snapshot["battery_capacity"]
	var battery: float = _snapshot["battery"]
	var cells: int = _snapshot["battery_cells"]
	var low := cells <= 2
	var body := Rect2(0, 0, c.size.x - 6, c.size.y)
	c.draw_rect(body, UiKit.INK)
	c.draw_rect(body, UiKit.TEXT_DIM, false, 1.0)
	c.draw_rect(Rect2(body.end.x, 6, 5, c.size.y - 12), UiKit.TEXT_DIM)
	var cell_w := (body.size.x - 4.0) / float(total)
	for i in total:
		var slot := Rect2(3 + i * cell_w, 3, cell_w - 2, body.size.y - 6)
		# The last cell fills gradually, so small changes are visible.
		var fill := clampf((battery - i * (capacity / total)) / (capacity / total), 0.0, 1.0)
		c.draw_rect(slot, UiKit.PANEL_HI)
		if fill > 0.0:
			var color := UiKit.AMBER if low else UiKit.TEAL
			c.draw_rect(Rect2(slot.position, Vector2(roundf(slot.size.x * fill), slot.size.y)), color.darkened(0.2))
			c.draw_rect(Rect2(slot.position, Vector2(roundf(slot.size.x * fill), 3)), color)


# ---------------------------------------------------------------- updates

func _on_resources_changed(s: Dictionary) -> void:
	_snapshot = s
	var game_hour: int = s["hour"]
	if training_mode:
		_clock_label.text = "Hour %d of %d " % [mini(game_hour, MissionDirector.TRAINING_HOURS), MissionDirector.TRAINING_HOURS]
	else:
		_clock_label.text = "Day %d  %02d:00 " % [game_hour / 24 + 1, game_hour % 24]

	var net: float = s["generation"] - s["demand"]
	_power_label.text = "Solar %d    Use %d    Net %s%d" % [
		int(s["generation"]), int(s["demand"]), "+" if net >= 0.0 else "", int(net)]
	_power_label.add_theme_color_override("font_color", UiKit.GREEN if net >= 0.0 else UiKit.RED)
	_battery_label.text = "BATTERY   %d of %d cells" % [s["battery_cells"], s["battery_cells_total"]]
	_battery_view.queue_redraw()
	_forecast_view.queue_redraw()

	for key: String in ["oxygen", "water", "co2_scrub"]:
		_meters[key].value = s["life_support"][key]
	_meters["crops"].value = s["crop_health"]

	var enabled: Dictionary = s["enabled"]
	for id: StringName in _load_buttons:
		_load_buttons[id].set_pressed_no_signal(enabled.get(id, false))


func _on_brownout(load_id: StringName) -> void:
	var def := ResourceSim.get_load(load_id)
	var load_name: String = def.display_name if def else str(load_id)
	if training_mode:
		if _state == "failed" or _state == "passed":
			return
		_state = "failed"
		ResourceSim.paused = true
		_retry_button.visible = true
		_retry_button.grab_focus()
		_say("NOT YET: the battery ran out at hour %d, so %s was shut off in an emergency. Press Retry and switch off a load that can wait BEFORE the shadow." % [ResourceSim.hour + 1, load_name], UiKit.RED)
		return
	if load_id == &"life_support":
		_say("WARNING: no power left for Life Support! Oxygen and water are dropping.", UiKit.RED)
	else:
		_say("Battery empty! %s was shut off automatically to protect Life Support." % load_name, UiKit.AMBER)


func _on_game_hour_passed(game_hour: int) -> void:
	if not training_mode or _state != "running":
		return
	if game_hour >= MissionDirector.TRAINING_HOURS:
		_state = "passed"
		ResourceSim.paused = true
		MissionDirector.pass_training()
		_say("CERTIFIED! Life Support stayed powered through the shadow because you saved battery early. Close this panel and walk to the lander dock.", UiKit.GREEN)


func _close() -> void:
	ResourceSim.paused = true
	closed.emit()
	if embedded:
		queue_free()
	else:
		SceneRouter.go_to(&"academy_hub")
