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
	MissionDirector.push_ui()
	Sfx.play(&"open")

	var t := Theme.new()
	t.default_font_size = 8

	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.03, 0.08, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.theme = t
	add_child(center)

	var frame := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.13, 0.24)
	style.border_color = Color(0.3, 0.85, 0.8)
	style.set_border_width_all(1)
	style.set_content_margin_all(6)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	box.custom_minimum_size = Vector2(330, 0)
	frame.add_child(box)

	var title := Label.new()
	title.text = _title
	title.modulate = Color(1.0, 0.82, 0.3)
	box.add_child(title)

	var body := Label.new()
	body.text = _body
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(330, 0)
	box.add_child(body)

	var first: Button = null
	for i in _options.size():
		var b := Button.new()
		b.text = _options[i]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(_choose.bind(i))
		box.add_child(b)
		if first == null:
			first = b

	var hint := Label.new()
	hint.text = "Up / Down and Enter to choose." + ("  Esc: close" if _allow_close else "")
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)

	if first != null:
		first.grab_focus.call_deferred()


func _input(event: InputEvent) -> void:
	if _allow_close and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


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
