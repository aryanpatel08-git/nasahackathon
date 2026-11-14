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

signal closed

const SUN_COLOR := Color(1.0, 0.82, 0.3)
const SHADOW_COLOR := Color(0.12, 0.13, 0.2)
const FORECAST_HOURS := 10

var training_mode: bool = false
var embedded: bool = false

var _state: String = "ready"  # ready, running, failed, passed
var _load_buttons: Dictionary = {}  # StringName -> CheckButton
var _clock_label: Label
var _power_label: Label
var _battery_bar: ProgressBar
var _battery_label: Label
var _forecast_boxes: Array[ColorRect] = []
var _meters: Dictionary = {}        # String -> ProgressBar
var _log_label: Label
var _retry_button: Button


func _ready() -> void:
	var t := Theme.new()
	t.default_font_size = 8
	theme = t
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


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_close()


func _reset_training() -> void:
	_state = "ready"
	ResourceSim.paused = true
	ResourceSim.time_scale = 1.0
	ResourceSim.seconds_per_game_hour = 2.0
	ResourceSim.reset_state(0, MissionDirector.TRAINING_START_BATTERY, MissionDirector.TRAINING_PATTERN)
	if _log_label != null:
		_log_label.text = _goal_text()
		_retry_button.visible = false


func _goal_text() -> String:
	return "GOAL: the Sun is about to hide. Keep the battery from running out for %d hours. Switch off something that can wait, then press Go." % MissionDirector.TRAINING_HOURS


# ---------------------------------------------------------------- UI building

func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var frame := PanelContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = 10
	frame.offset_top = 8
	frame.offset_right = -10
	frame.offset_bottom = -8
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.11, 0.12, 0.22)
	style.border_color = Color(0.3, 0.85, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(5)
	frame.add_theme_stylebox_override("panel", style)
	add_child(frame)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 2)
	frame.add_child(root)

	# Title row: name, clock, speed controls.
	var title_row := HBoxContainer.new()
	root.add_child(title_row)
	var title := Label.new()
	title.text = "POWER CONSOLE TRAINING" if training_mode else "POWER CONSOLE"
	title.modulate = SUN_COLOR
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title)
	_clock_label = Label.new()
	title_row.add_child(_clock_label)
	_add_speed_button(title_row, "Pause", 0.0)
	_add_speed_button(title_row, "Go", 1.0)
	_add_speed_button(title_row, "Fast", 4.0)
	_retry_button = Button.new()
	_retry_button.text = "Retry"
	_retry_button.focus_mode = Control.FOCUS_NONE
	_retry_button.visible = false
	_retry_button.pressed.connect(_reset_training)
	title_row.add_child(_retry_button)
	var close := Button.new()
	close.text = "Close (Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(_close)
	title_row.add_child(close)

	# Sunlight forecast strip.
	var forecast_row := HBoxContainer.new()
	forecast_row.add_theme_constant_override("separation", 2)
	root.add_child(forecast_row)
	var forecast_label := Label.new()
	forecast_label.text = "Sunlight, next %d hours (yellow = sun, dark = shadow):" % FORECAST_HOURS
	forecast_row.add_child(forecast_label)
	for i in FORECAST_HOURS:
		var box := ColorRect.new()
		box.custom_minimum_size = Vector2(12, 8)
		box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		forecast_row.add_child(box)
		_forecast_boxes.append(box)

	# Two columns: loads on the left, status on the right.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(columns)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 0)
	columns.add_child(left)
	var loads_title := Label.new()
	loads_title.text = "SWITCHES  (1 = most important)"
	left.add_child(loads_title)
	for def in ResourceSim.loads:
		_add_load_row(left, def)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 2)
	columns.add_child(right)
	_power_label = Label.new()
	right.add_child(_power_label)
	_battery_label = Label.new()
	right.add_child(_battery_label)
	_battery_bar = _make_bar(right)
	_meters["oxygen"] = _add_meter(right, "Oxygen")
	_meters["water"] = _add_meter(right, "Water")
	_meters["co2_scrub"] = _add_meter(right, "CO2 scrub")
	_meters["crops"] = _add_meter(right, "Crops")
	var note := Label.new()
	note.text = "Simplified game units,\nnot real engineering numbers."
	note.modulate = Color(1, 1, 1, 0.5)
	right.add_child(note)

	# Goal / feedback line.
	_log_label = Label.new()
	_log_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log_label.custom_minimum_size = Vector2(0, 22)
	_log_label.text = _goal_text() if training_mode else "Tip: charge the battery while the Sun is up."
	root.add_child(_log_label)


func _add_speed_button(parent: Control, text: String, speed: float) -> void:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
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


func _add_load_row(parent: Control, def: LoadDef) -> void:
	var check := CheckButton.new()
	check.text = "%d  %s  (uses %s)" % [def.priority, def.display_name, _fmt(def.power_draw)]
	check.tooltip_text = def.why_it_matters
	check.focus_mode = Control.FOCUS_NONE
	if not def.can_disable:
		check.disabled = true
		check.text += "  always on"
	check.toggled.connect(func(on: bool) -> void:
		if not ResourceSim.set_load_enabled(def.id, on):
			check.set_pressed_no_signal(not on)
	)
	parent.add_child(check)
	_load_buttons[def.id] = check


func _add_meter(parent: Control, label_text: String) -> ProgressBar:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = label_text
	label.custom_minimum_size = Vector2(48, 0)
	row.add_child(label)
	var bar := _make_bar(row)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return bar


func _make_bar(parent: Control) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(80, 6)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.max_value = 100.0
	parent.add_child(bar)
	return bar


# ---------------------------------------------------------------- updates

func _on_resources_changed(s: Dictionary) -> void:
	var game_hour: int = s["hour"]
	if training_mode:
		_clock_label.text = "Hour %d of %d  " % [mini(game_hour, MissionDirector.TRAINING_HOURS), MissionDirector.TRAINING_HOURS]
	else:
		_clock_label.text = "Day %d  %02d:00  " % [game_hour / 24 + 1, game_hour % 24]

	var forecast := ResourceSim.illumination_forecast(FORECAST_HOURS)
	for i in _forecast_boxes.size():
		_forecast_boxes[i].color = SHADOW_COLOR.lerp(SUN_COLOR, forecast[i])

	var net: float = s["generation"] - s["demand"]
	_power_label.text = "Solar %s   Use %s   Net %s%s" % [
		_fmt(s["generation"]), _fmt(s["demand"]), "+" if net >= 0.0 else "", _fmt(net)]
	_battery_label.text = "Battery  %d / %d cells" % [s["battery_cells"], s["battery_cells_total"]]
	_battery_bar.max_value = s["battery_capacity"]
	_battery_bar.value = s["battery"]

	for key in ["oxygen", "water", "co2_scrub"]:
		_meters[key].value = s["life_support"][key]
	_meters["crops"].value = s["crop_health"]

	var enabled: Dictionary = s["enabled"]
	for id in _load_buttons:
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
		_log_label.text = "NOT YET: the battery ran out at hour %d, so %s was shut off in an emergency. Press Retry and switch off a load that can wait BEFORE the shadow." % [ResourceSim.hour + 1, load_name]
		return
	if load_id == &"life_support":
		_log_label.text = "WARNING: no power left for Life Support! Oxygen and water are dropping."
	else:
		_log_label.text = "Battery empty! %s was shut off automatically to protect life support." % load_name


func _on_game_hour_passed(game_hour: int) -> void:
	if not training_mode or _state != "running":
		return
	if game_hour >= MissionDirector.TRAINING_HOURS:
		_state = "passed"
		ResourceSim.paused = true
		MissionDirector.pass_training()
		_log_label.text = "CERTIFIED! Life Support stayed powered through the shadow because you saved battery early. Close this panel and walk to the exit hatch."


func _close() -> void:
	ResourceSim.paused = true
	closed.emit()
	if embedded:
		queue_free()
	else:
		SceneRouter.go_to(&"academy_hub")


func _fmt(value: float) -> String:
	return "%.1f" % value
