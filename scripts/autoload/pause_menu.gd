extends CanvasLayer
## Menu UI keeps receiving input while the world and its timers are paused.

const REST_Y := 31.0
const INK := Color("#12182d")
const TEAL := Color("#68e2d2")
const AMBER := Color("#ffc674")

var _toggle: Button
var _shade: ColorRect
var _panel: PanelContainer
var _content: VBoxContainer
var _page := ""
var _previous_focus: WeakRef


func _ready() -> void:
	layer = 80
	process_mode = Node.PROCESS_MODE_ALWAYS
	var theme_ui := Theme.new()
	theme_ui.default_font_size = 10
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var fill := Color("#222d48")
		if state == "hover":
			fill = Color("#344665")
		elif state == "pressed":
			fill = Color("#425a79")
		var style := _skin(fill, TEAL if state == "focus" else Color("#465979"))
		if state == "focus":
			style.draw_center = false
		theme_ui.set_stylebox(state, "Button", style)

	_toggle = Button.new()
	_toggle.text = "≡"
	_toggle.tooltip_text = "Pause menu (Esc)"
	_toggle.theme = theme_ui
	_toggle.focus_mode = Control.FOCUS_NONE
	_toggle.position = Vector2(442, 7)
	_toggle.size = Vector2(30, 21)
	_toggle.pressed.connect(_open)
	add_child(_toggle)

	_shade = ColorRect.new()
	_shade.color = Color(0.04, 0.07, 0.14, 0.64)
	_shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_shade)
	_shade.hide()

	_panel = PanelContainer.new()
	_panel.position = Vector2(196, REST_Y)
	_panel.theme = theme_ui
	var frame := _skin(INK, TEAL)
	frame.shadow_color = Color(0, 0, 0, 0.5)
	frame.shadow_size = 4
	_panel.add_theme_stylebox_override("panel", frame)
	add_child(_panel)
	_panel.hide()
	_content = VBoxContainer.new()
	_content.custom_minimum_size.x = 260
	_content.add_theme_constant_override("separation", 4)
	_panel.add_child(_content)


func _input(event: InputEvent) -> void:
	if event.is_echo():
		return
	if SceneRouter.is_transitioning():
		return
	var panel_owns_escape := Dialogue.is_active or (MissionDirector.ui_open and MissionDirector.stage != MissionDirector.Stage.DEBRIEF)
	var can_use_escape := not _page.is_empty() or not panel_owns_escape
	var typing := get_viewport().gui_get_focus_owner() is LineEdit
	if (event.is_action_pressed(&"pause_menu") and not typing) or (event.is_action_pressed(&"ui_cancel") and can_use_escape):
		get_viewport().set_input_as_handled()
		if _page.is_empty():
			_open()
		else:
			_escape()


func _open() -> void:
	if SceneRouter.is_transitioning() or get_tree().paused or get_tree().current_scene == null:
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		_previous_focus = weakref(focus)
	get_tree().paused = true
	_shade.show()
	_panel.show()
	_show_page("home")
	_panel.position.y = REST_Y - 16
	var tween := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_panel, "position:y", REST_Y, 0.19)


func _escape() -> void:
	if _page == "home":
		_resume()
	else:
		_show_page("home")


func _resume() -> void:
	_page = ""
	_panel.hide()
	_shade.hide()
	get_tree().paused = false
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
	_panel.reset_size()
	var first: Button
	match page:
		"home":
			_heading("LUNAR LIFE  /  PAUSED")
			first = _button("Resume", _resume)
			_button("Help / Controls", _show_page.bind("help"))
			_button("Tasks", _show_page.bind("tasks"))
			_button("Quit Game", _show_page.bind("quit"))
		"help":
			_heading("FLIGHT MANUAL")
			_text(_content, "WASD / arrows   Walk\nE / Space / Enter   Interact or advance dialogue\nEsc   Back or close the active panel\nP / menu icon   Pause any screen\nTab / arrows   Focus a button · Enter   Select")
			first = _button("Back", _show_page.bind("home"))
		"tasks":
			_heading("MISSION LOG")
			var scroll := ScrollContainer.new()
			scroll.custom_minimum_size = Vector2(260, 148)
			scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
			scroll.focus_mode = Control.FOCUS_ALL
			_content.add_child(scroll)
			var rows := VBoxContainer.new()
			rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rows.add_theme_constant_override("separation", 6)
			scroll.add_child(rows)
			for task in TaskLog.entries():
				var done: bool = task["done"]
				_text(rows, ("%s  %s" % ["DONE" if done else "OPEN", task["title"]]), TEAL if done else AMBER)
				_text(rows, task["description"])
			_button("Back", _show_page.bind("home"))
			scroll.grab_focus()
		"quit":
			_heading("LEAVE LUNAR LIFE?")
			_text(_content, "Exiting ends this run. Progress is kept while\nyou travel, but is not saved after closing.")
			first = _button("Cancel", _show_page.bind("home"))
			_button("Quit to desktop", func() -> void: get_tree().quit())
	if first != null:
		first.grab_focus()


func _heading(value: String) -> void:
	var heading := _text(_content, value, TEAL)
	heading.add_theme_font_size_override("font_size", 12)


func _text(parent: Control, value: String, color: Color = Color("#dce8ff")) -> Label:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _button(value: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = value
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size.y = 22
	button.pressed.connect(callback)
	_content.add_child(button)
	return button


func _skin(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = edge
	box.set_border_width_all(1)
	box.content_margin_left = 8
	box.content_margin_right = 8
	box.content_margin_top = 4
	box.content_margin_bottom = 4
	return box

