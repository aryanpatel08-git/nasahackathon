extends CanvasLayer
## Owns the active waypoint and map overlay across facility changes.

signal waypoint_changed(facility: String, id: String, task: String)

var floor: NavigationFloor
var target_facility := ""
var target_id := ""
var tracked_task := ""
var arrows := true
var owns_pause := false
var _closing := false
var _mini: Button
var _preview: MapDisplay
var _overlay: ColorRect
var _panel: PanelContainer
var _display: MapDisplay
var _title: Label
var _description: Label
var _status: Label
var _mini_status: Label
var _choices: OptionButton
var _close_button: Button
var _ids := PackedStringArray()
var _shown_id := ""
var _arrival_until := 0


func _ready() -> void:
	layer = 75
	process_mode = Node.PROCESS_MODE_ALWAYS
	_make_ui()
	get_tree().scene_changed.connect(_scene_changed)


func _scene_changed() -> void:
	if not is_instance_valid(floor) or floor.get_parent() != get_tree().current_scene:
		floor = null


func attach(value: NavigationFloor) -> void:
	floor = value
	floor.arrows = arrows
	update_route(floor)


func _process(_delta: float) -> void:
	var available := is_instance_valid(floor) and not SceneRouter.is_transitioning()
	if available and not tracked_task.is_empty():
		_refresh_objective()
	_mini.visible = available and not owns_pause and not get_tree().paused and not MissionDirector.ui_open and not Dialogue.is_active
	_mini_status.visible = _mini.visible and (not target_id.is_empty() or Time.get_ticks_msec() < _arrival_until)
	if _mini.visible:
		_preview.queue_redraw()
	if owns_pause:
		_display.queue_redraw()


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if owns_pause and (event.is_action_pressed(&"map_toggle") or event.is_action_pressed(&"ui_cancel")):
		get_viewport().set_input_as_handled()
		close_map()
	elif event.is_action_pressed(&"map_toggle") and can_open():
		get_viewport().set_input_as_handled()
		open_map()


func can_open() -> bool:
	return is_instance_valid(floor) and not get_tree().paused and not MissionDirector.ui_open and not Dialogue.is_active and not SceneRouter.is_transitioning()


func open_map() -> void:
	if not can_open():
		return
	owns_pause = true
	get_tree().paused = true
	_overlay.show()
	_display.reset_view()
	_title.text = "%s  /  NAVIGATION" % floor.facility.to_upper()
	_choices.clear()
	_ids.clear()
	for id: String in floor.points:
		_choices.add_item(floor.points[id].title)
		_ids.append(id)
	if floor.facility == "Academy" and MissionDirector.can_graduate():
		_choices.add_item("Lunar outpost")
		_ids.append("@Outpost")
	elif floor.facility == "Outpost" and _transit_available():
		_choices.add_item("Academy entrance")
		_ids.append("@Academy")
	_choices.select(-1)
	_shown_id = local_target()
	if _ids.has(_shown_id):
		_choices.select(_ids.find(_shown_id))
	_description.text = "Select a marker or destination to plot a route."
	_close_button.grab_focus()
	_panel.scale = Vector2(0.72, 0.72)
	_overlay.modulate.a = 0.0
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "scale", Vector2.ONE, 0.19).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_overlay, "modulate:a", 1.0, 0.15)
	_refresh_status()


func close_map() -> void:
	if _closing or not owns_pause:
		return
	_closing = true
	var tween := create_tween().set_parallel()
	tween.tween_property(_panel, "scale", Vector2(0.72, 0.72), 0.14)
	tween.tween_property(_overlay, "modulate:a", 0.0, 0.14)
	await tween.finished
	_overlay.hide()
	owns_pause = false
	_closing = false
	get_tree().paused = false


func _select(id: String) -> void:
	_shown_id = id
	if id.begins_with("@"):
		var destination := id.substr(1)
		_description.text = "Follow the route to the transit hatch, then interact to travel."
		set_waypoint(destination, "entrance")
	else:
		_description.text = floor.points[id].description
		set_waypoint(floor.facility, id)
	_choices.select(_ids.find(_shown_id))


func set_waypoint(facility: String, id: String, task: String = "") -> void:
	target_facility = facility
	target_id = id
	tracked_task = task
	_arrival_until = 0
	waypoint_changed.emit(facility, id, task)
	if is_instance_valid(floor):
		update_route(floor)


func clear_waypoint() -> void:
	target_facility = ""
	target_id = ""
	tracked_task = ""
	waypoint_changed.emit("", "", "")
	if is_instance_valid(floor):
		floor.route.clear()
		floor.queue_redraw()
	_refresh_status()


func _refresh_objective() -> void:
	for task in TaskLog.entries():
		if task.get("id", "") == tracked_task and not task.done and task.has("destination"):
			if target_id != task.destination or target_facility != task.facility:
				set_waypoint(task.facility, task.destination, tracked_task)
			return
	clear_waypoint()


func local_target() -> String:
	if not is_instance_valid(floor) or target_id.is_empty():
		return ""
	if target_facility == floor.facility:
		return target_id
	if not _transit_available():
		return ""
	return floor.links.get(target_facility, "")


func _transit_available() -> bool:
	if floor.facility == "Academy":
		return MissionDirector.can_graduate()
	return MissionDirector.stage == MissionDirector.Stage.CHECKS and not MissionDirector.checks_done()


func update_route(current: NavigationFloor) -> void:
	if current != floor:
		return
	var id := local_target()
	if not floor.points.has(id):
		floor.route.clear()
	elif floor.facility == target_facility and tracked_task.is_empty() and not owns_pause and floor.player.position.distance_to(floor.points[id].at) < 34.0:
		var label: String = floor.points[id].title
		clear_waypoint()
		_mini_status.text = "Arrived: " + label
		_show_arrival()
	else:
		floor.route = floor.find_route(floor.points[id].at)
	floor.queue_redraw()
	_refresh_status()


func _show_arrival() -> void:
	_arrival_until = Time.get_ticks_msec() + 2600


func _refresh_status() -> void:
	var label := target_facility
	var local := local_target()
	if is_instance_valid(floor) and floor.points.has(local):
		label = floor.points[local].title
	if target_id.is_empty():
		_status.text = "NO WAYPOINT"
	elif local.is_empty() or floor.route.is_empty():
		_status.text = "TRANSIT OR ROUTE UNAVAILABLE"
	else:
		_status.text = "TRACKING  /  " + label
	if not target_id.is_empty():
		_mini_status.text = label
	elif Time.get_ticks_msec() >= _arrival_until:
		_mini_status.text = ""


func _make_ui() -> void:
	_mini = Button.new()
	_mini.position = Vector2(344, 6)
	_mini.size = Vector2(98, 56)
	_mini.tooltip_text = "Open navigation map (M)"
	_mini.focus_mode = Control.FOCUS_NONE
	_mini.pressed.connect(open_map)
	add_child(_mini)
	_preview = MapDisplay.new()
	_preview.position = Vector2(1, 1)
	_preview.size = Vector2(96, 54)
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mini.add_child(_preview)
	_mini_status = Label.new()
	_mini_status.position = Vector2(306, 64)
	_mini_status.size.x = 132
	_mini_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_mini_status.add_theme_font_size_override("font_size", 8)
	_mini_status.add_theme_color_override("font_color", UiKit.TEXT)
	_mini_status.add_theme_color_override("font_shadow_color", UiKit.INK)
	_mini_status.add_theme_constant_override("shadow_offset_y", 1)
	_mini_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_mini_status)
	_overlay = ColorRect.new()
	_overlay.color = Color(0.025, 0.04, 0.08, 0.88)
	add_child(_overlay)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.hide()
	_panel = PanelContainer.new()
	_panel.position = Vector2(12, 12)
	_panel.size = Vector2(456, 246)
	_panel.pivot_offset = Vector2(420, 20)
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, UiKit.PANEL, 7))
	_overlay.add_child(_panel)
	var layout := VBoxContainer.new()
	_panel.add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	_title = UiKit.label("", "title", UiKit.TEAL)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_close_button = _button(header, "Close (M)", close_map)
	var body := HBoxContainer.new()
	layout.add_child(body)
	_display = MapDisplay.new()
	_display.expanded = true
	_display.clip_contents = true
	_display.custom_minimum_size = Vector2(290, 172)
	_display.selected.connect(_select)
	body.add_child(_display)
	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 146
	body.add_child(side)
	_choices = OptionButton.new()
	_choices.fit_to_longest_item = false
	_choices.item_selected.connect(func(index: int) -> void: _select(_ids[index]))
	side.add_child(_choices)
	_description = Label.new()
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	side.add_child(_description)
	var zoom_controls := HBoxContainer.new()
	side.add_child(zoom_controls)
	_button(zoom_controls, "-", func() -> void: _display.change_zoom(1.0 / 1.2))
	_button(zoom_controls, "+", func() -> void: _display.change_zoom(1.2))
	_button(side, "Clear waypoint", clear_waypoint)
	var toggle := CheckButton.new()
	toggle.text = "Ground arrows"
	toggle.button_pressed = true
	toggle.toggled.connect(func(value: bool) -> void:
		arrows = value
		if is_instance_valid(floor):
			floor.arrows = value
			floor.queue_redraw())
	side.add_child(toggle)
	_status = UiKit.label("", "small", UiKit.TEAL)
	layout.add_child(_status)
	layout.add_child(UiKit.label("Dot: you    Circle: crew    Diamond: station    Square: hatch    Scroll to zoom, drag to pan", "small", UiKit.TEXT_DIM))


func _button(parent: Control, title: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = title
	button.pressed.connect(callback)
	parent.add_child(button)
	return button
