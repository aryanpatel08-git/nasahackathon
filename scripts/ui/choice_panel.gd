class_name ChoicePanel
extends CanvasLayer
## A small focused panel: a title, some text and a few buttons.
## Opens on top of the world and closes back to it. While it is open the
## player can't move and the mission clock is stopped.
##   var panel := ChoicePanel.open(self, "TITLE", "text", ["Option A", "Option B"])
##   panel.chosen.connect(func(index: int) -> void: ...)

signal chosen(index: int)
signal closed

var _title: String = ""
var _body: String = ""
var _options: PackedStringArray = []
var _allow_close: bool = true
var _done: bool = false
var _opened_msec: int = 0


static func open(parent: Node, title: String, body: String, options: PackedStringArray, allow_close: bool = true) -> ChoicePanel:
	var panel := ChoicePanel.new()
	panel._title = title
	panel._body = body
	panel._options = options
	panel._allow_close = allow_close
	parent.add_child(panel)
	return panel


func _ready() -> void:
	layer = 40
	_opened_msec = Time.get_ticks_msec()
	MissionDirector.push_ui()
	Sfx.play(&"open")

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.08, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(400, 0)
	frame.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, UiKit.PANEL, 8))
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	frame.add_child(box)

	box.add_child(UiKit.label(_title, "title", UiKit.AMBER))
	box.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var body := UiKit.label(_body, "body", UiKit.TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.custom_minimum_size.x = 380
	scroll.add_child(body)
	# Tall text scrolls; short text keeps the panel compact.
	var lines := maxi(1, int(ceil(UiKit.text_width(_body, "body") / 376.0)) + _body.count("\n"))
	scroll.custom_minimum_size.y = clampf(lines * 12.0 + 4.0, 26.0, 250.0 - 44.0 - _options.size() * 20.0)

	var first: Button = null
	for i in _options.size():
		var b := Button.new()
		b.text = _options[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_choose.bind(i))
		box.add_child(b)
		if first == null:
			first = b
	if _options.is_empty():
		first = Button.new()
		first.text = "Close"
		first.pressed.connect(close)
		box.add_child(first)

	var hint := UiKit.label("Up / Down, then E or Enter" + ("        Esc: close" if _allow_close else ""), "small", UiKit.TEXT_DIM)
	box.add_child(hint)
	first.grab_focus.call_deferred()

	# Pop in.
	frame.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(frame, "modulate:a", 1.0, 0.12)


func _input(event: InputEvent) -> void:
	if _allow_close and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()
	elif event.is_action_pressed(&"interact") and not event.is_echo() and event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_E:
		# E confirms the focused button, like Enter and Space already do. A short guard
		# stops the same tap that opened the panel from also picking the first option.
		if Time.get_ticks_msec() - _opened_msec < 300:
			return
		var focus := get_viewport().gui_get_focus_owner() as Button
		if focus != null and is_ancestor_of(focus):
			get_viewport().set_input_as_handled()
			focus.pressed.emit()


func _exit_tree() -> void:
	MissionDirector.pop_ui()


func close() -> void:
	if _done:
		return
	_done = true
	Sfx.play(&"cancel")
	closed.emit()
	queue_free()


func _choose(index: int) -> void:
	if _done:
		return
	_done = true
	Sfx.play(&"confirm")
	chosen.emit(index)
	queue_free()
