extends CanvasLayer
## PauseMenu — Resume, Field notes, Tasks, Help and Quit (autoload).
## The menu keeps receiving input while the world and its timers are paused.
## Other screens can jump straight to a page: PauseMenu.open_page("notes").

const REST_Y := 31.0

var _open_tween: Tween

var _toggle: Button
var _shade: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _page := ""
var _direct := false            # opened on a page by another screen: Esc closes instead of going home
var _previous_focus: WeakRef
var _note_id: StringName = &""


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS

	_toggle = Button.new()
	_toggle.tooltip_text = "Pause menu (Esc or P)"
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.position = Vector2(446, 6)
	_toggle.size = Vector2(28, 20)
	_toggle.pressed.connect(_open)
	_toggle.draw.connect(func() -> void:
		for i in 3:
			_toggle.draw_rect(Rect2(9, 6 + i * 4, 10, 2), UiKit.TEXT))
	add_child(_toggle)

	_shade = ColorRect.new()
	_shade.color = Color(0.02, 0.03, 0.08, 0.7)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_shade.hide()

	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, UiKit.PANEL, 8))
	add_child(_panel)
	_panel.hide()
	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_panel.add_child(_content)


func _process(_delta: float) -> void:
	# The button only makes sense where there is a game to pause.
	var scene := get_tree().current_scene
	var in_game := scene != null and scene.name != &"TitleScreen" and scene.name != &"CreateAstronaut"
	var story := get_tree().get_first_node_in_group(&"fullscreen_story") != null
	_toggle.visible = in_game and not story and _page.is_empty() and not SceneRouter.is_transitioning() \
			and not MissionDirector.ui_open and not MapManager.owns_pause


func _input(event: InputEvent) -> void:
	if event.is_echo() or MapManager.owns_pause:
		return
	if SceneRouter.is_transitioning():
		return
	var panel_owns_escape := Dialogue.is_active or MissionDirector.ui_open
	var can_use_escape := not _page.is_empty() or (not panel_owns_escape and _toggle.visible)
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if (event.is_action_pressed(&"pause_menu") and not typing and (_toggle.visible or not _page.is_empty())) \
			or (event.is_action_pressed(&"ui_cancel") and can_use_escape):
		get_viewport().set_input_as_handled()
		if _page.is_empty():
			_open()
		else:
			_escape()


## Open the menu directly on one page ("notes", "tasks", "help"), from any screen.
func open_page(page: String) -> void:
	if not _page.is_empty():
		return
	_direct = true
	_open(page)


func _open(page: String = "home") -> void:
	if SceneRouter.is_transitioning() or get_tree().paused or get_tree().current_scene == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		_previous_focus = weakref(focus)
	get_tree().paused = true
	Sfx.play(&"open")
	_shade.show()
	_panel.show()
	_show_page(page)
	_panel.modulate.a = 0.0
	var rest := _panel.position.y
	_panel.position.y = rest - 10
	_open_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_open_tween.tween_property(_panel, "position:y", rest, 0.16)
	_open_tween.tween_property(_panel, "modulate:a", 1.0, 0.12)


func _escape() -> void:
	if _page == "home" or _direct:
		_resume()
	else:
		_show_page("home")


func _resume() -> void:
	_page = ""
	_direct = false
	_panel.hide()
	_shade.hide()
	get_tree().paused = false
	Sfx.play(&"cancel")
	if _previous_focus != null:
		var focus := _previous_focus.get_ref() as Control
		if is_instance_valid(focus) and focus.is_visible_in_tree():
			focus.grab_focus()
	_previous_focus = null


func _show_page(page: String) -> void:
	_page = page
	for node in _content.get_children():
		_content.remove_child(node)
		node.queue_free()
	var wide := page == "notes"
	if _open_tween != null and _open_tween.is_valid():
		# A page change during the opening slide must not be dragged back to the old spot.
		_open_tween.kill()
		_panel.modulate.a = 1.0
	_content.custom_minimum_size = Vector2(430 if wide else 250, 0)
	_panel.position = Vector2(16 if wide else 107, 6 if wide else REST_Y)
	var first: Control
	var back_action: Callable = _resume if _direct else _show_page.bind("home")
	var back_text := "Close" if _direct else "Back"
	match page:
		"home":
			_heading("PAUSED")
			_text(_content, "Astronaut %s" % GameState.player_name, UiKit.TEXT_DIM)
			first = _button("Resume", _resume)
			_button("Field notes  %d/%d" % [FieldNotes.unlocked_count(), FieldNotes.NOTES.size()], _show_page.bind("notes"))
			_button("Tasks", _show_page.bind("tasks"))
			_button("Help / Controls", _show_page.bind("help"))
			_button("Sound: %s" % ("off" if Sfx.muted else "on"), func() -> void:
				Sfx.set_muted(not Sfx.muted)
				_show_page("home"))
			_button("Quit", _show_page.bind("quit"))
		"help":
			_heading("FLIGHT MANUAL")
			for row: Array in [
					["WASD / arrows", "Walk (two keys at once walks diagonally)"],
					["E / Space / Enter", "Talk, use, next line"],
					["Hold E", "Crank open the storm shelter hatch"],
					["M", "Map and waypoints"],
					["Esc / P", "Pause, back, close a panel"],
					["N", "Sound on or off"]]:
				var line := HBoxContainer.new()
				_content.add_child(line)
				var key := _text(line, row[0], UiKit.AMBER)
				key.custom_minimum_size.x = 84
				_text(line, row[1])
			_text(_content, "Follow the objective in the top-left corner. A gold arrow points the way.", UiKit.TEXT_DIM)
			first = _button(back_text, back_action)
		"tasks":
			_heading("MISSION LOG")
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(250, 150)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.focus_mode = Control.FOCUS_ALL
			_content.add_child(scroll)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_theme_constant_override("separation", 3)
			scroll.add_child(rows)
			for task in TaskLog.entries():
				var done: bool = task["done"]
				_text(rows, ("%s  %s" % ["DONE" if done else "OPEN", task["title"]]), UiKit.TEAL if done else UiKit.AMBER)
				_text(rows, task["description"], UiKit.TEXT_DIM)
				if not done and task.has("destination") and is_instance_valid(MapManager.floor):
					var track := Button.new()
					track.text = "Track objective"
					track.pressed.connect(_track_objective.bind(task))
					rows.add_child(track)
			_button(back_text, back_action)
			first = scroll
		"notes":
			first = _build_notes(back_text, back_action)
		"quit":
			_heading("LEAVE LUNAR LIFE?")
			_text(_content, "Your astronaut, certificate and field notes are saved.\nA mission in progress starts again from the academy.")
			first = _button("Cancel", _show_page.bind("home"))
			_button("Quit to title", func() -> void:
				_resume()
				SceneRouter.go_to(&"title_screen"))
			_button("Quit to desktop", func() -> void: get_tree().quit())
	if first != null:
		first.grab_focus()
	# Fit the panel to the page that was just built (not the one that was removed).
	_panel.reset_size()
	_panel.reset_size.call_deferred()


## Field notes: titles on the left, the chosen note on the right.
func _build_notes(back_text: String, back_action: Callable) -> Control:
	_heading("FIELD NOTES  %d/%d" % [FieldNotes.unlocked_count(), FieldNotes.NOTES.size()])
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 8)
	_content.add_child(columns)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 1)
	list.custom_minimum_size.x = 150
	columns.add_child(list)
	var page := VBoxContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.custom_minimum_size = Vector2(270, 172)
	page.add_theme_constant_override("separation", 4)
	columns.add_child(page)

	if _note_id == &"" or not FieldNotes.is_unlocked(_note_id):
		_note_id = &""
		for note in FieldNotes.NOTES:
			if FieldNotes.is_unlocked(note["id"]):
				_note_id = note["id"]
				break
	var first: Button
	for note in FieldNotes.NOTES:
		var id: StringName = note["id"]
		var open := FieldNotes.is_unlocked(id)
		var b := Button.new()
		b.text = str(note["title"]) if open else "? ? ?"
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.clip_text = true
		b.add_theme_font_override("font", UiKit.font_small)
		b.add_theme_font_size_override("font_size", UiKit.SIZE_SMALL)
		if id == _note_id:
			b.add_theme_color_override("font_color", UiKit.AMBER)
			b.add_theme_color_override("font_focus_color", UiKit.AMBER)
			first = b
		elif not open:
			b.add_theme_color_override("font_color", UiKit.TEXT_DIM)
		b.pressed.connect(func() -> void:
			_note_id = id
			_show_page("notes"))
		list.add_child(b)
	var note := FieldNotes.get_note(_note_id)
	if note.is_empty():
		_text(page, "No notes yet. They unlock as you train, explore and talk to the crew.", UiKit.TEXT_DIM)
	elif not FieldNotes.is_unlocked(_note_id):
		_text(page, "LOCKED", UiKit.TEXT_DIM)
	else:
		var title := UiKit.label(str(note["title"]), "title", UiKit.VIOLET)
		page.add_child(title)
		var body := UiKit.label(str(note["body"]), "body", UiKit.TEXT)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(body)
		var game := UiKit.label("IN THE GAME: " + str(note["game"]), "small", UiKit.TEAL)
		game.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(game)
		var source := UiKit.label("SOURCE: " + str(note["source"]), "small", UiKit.TEXT_DIM)
		source.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		page.add_child(source)
	# A locked note still says how to earn it.
	var hints := PackedStringArray()
	for other in FieldNotes.NOTES:
		if not FieldNotes.is_unlocked(other["id"]):
			hints.append(str(other["hint"]))
	var back := _button(back_text, back_action)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	if not hints.is_empty():
		# The hint shares the bottom row with the Back button to save height.
		var foot := HBoxContainer.new()
		foot.add_theme_constant_override("separation", 10)
		_content.add_child(foot)
		back.reparent(foot)
		var hint := _text(foot, "Next to find: " + hints[0], UiKit.TEXT_DIM)
		if hint != null:
			hint.autowrap_mode = TextServer.AUTOWRAP_OFF
			hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			hint.clip_text = true
	return first if first != null else back


func _track_objective(task: Dictionary) -> void:
	_resume()
	MapManager.set_waypoint(task.facility, task.destination, task.id)


func _heading(value: String) -> void:
	_content.add_child(UiKit.label(value, "title", UiKit.TEAL))
	_content.add_child(HSeparator.new())


func _text(parent: Control, value: String, color: Color = UiKit.TEXT) -> Label:
	var label := UiKit.label(value, "small", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label


func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.pressed.connect(callback)
	_content.add_child(button)
	return button
