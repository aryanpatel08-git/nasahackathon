extends CanvasLayer
## Dialogue — shows a speech box and steps through lines (autoload).
## Usage: Dialogue.play(&"commander", "Commander Okafor", lines)
## Nothing advances by itself: the reader presses E (or Space / Enter) for every line.
## The first press finishes typing the line, the next one moves on. Esc skips the rest.
## Emits EventBus.dialogue_started / dialogue_ended. "{name}" becomes the astronaut's name.

const CHARS_PER_SECOND := 60.0
## Faces shown beside the text, by dialogue id.
const PORTRAITS: Dictionary = {
	&"commander": "res://assets/art/characters/npc_commander.png",
	&"engineer": "res://assets/art/characters/npc_engineer.png",
	&"crew_rivera": "res://assets/art/characters/npc_engineer.png",
	&"botanist": "res://assets/art/characters/npc_botanist.png",
	&"crew_tanaka": "res://assets/art/characters/npc_botanist.png",
}

var is_active: bool = false

var _id: StringName = &""
var _lines: PackedStringArray = []
var _index: int = 0
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _icon: Control
var _hint: Control
var _reveal: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	layer = 50
	_panel = PanelContainer.new()
	_panel.position = Vector2(8, 206)
	_panel.size = Vector2(464, 58)
	_panel.add_theme_stylebox_override("panel", UiKit.panel_box(UiKit.TEAL, Color(UiKit.PANEL, 0.96), 5))
	_panel.visible = false
	add_child(_panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	_panel.add_child(row)

	# Who is talking: a character's face, or a radio icon for voices over the comms.
	_portrait_frame = PanelContainer.new()
	_portrait_frame.custom_minimum_size = Vector2(40, 40)
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_portrait_frame.add_theme_stylebox_override("panel", UiKit.flat_box(UiKit.INK, UiKit.LINE, 3))
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
	_portrait_frame.add_child(_portrait)
	_icon = Control.new()
	_icon.draw.connect(_draw_radio)
	_portrait_frame.add_child(_icon)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(box)

	_speaker_label = UiKit.label("", "title", UiKit.AMBER)
	box.add_child(_speaker_label)

	_text_label = UiKit.label("", "body", UiKit.TEXT)
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text_label.add_theme_constant_override("line_spacing", 1)
	box.add_child(_text_label)

	# "E >" in the corner: steady while the line types, bouncing once it can be advanced.
	_hint = Control.new()
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.position = Vector2(8 + 464 - 34, 206 + 58 - 15)
	_hint.size = Vector2(28, 11)
	_hint.draw.connect(_draw_hint)
	_hint.visible = false
	add_child(_hint)


func play(id: StringName, speaker: String, lines: PackedStringArray) -> void:
	if is_active or lines.is_empty():
		return
	_id = id
	_lines = lines
	_index = 0
	is_active = true
	_speaker_label.text = speaker
	var face: String = PORTRAITS.get(id, "")
	_portrait.texture = load(face) if face != "" else null
	_portrait.visible = face != ""
	_icon.visible = face == ""
	_panel.visible = true
	_hint.visible = true
	_show_line()
	EventBus.dialogue_started.emit(_id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed(&"interact") and not event.is_echo():
		get_viewport().set_input_as_handled()
		if is_revealing():
			# First press finishes the line; the next press moves on.
			_reveal = 100000.0
			_text_label.visible_characters = -1
			return
		_advance()


func _process(delta: float) -> void:
	if not is_active:
		return
	_time += delta
	_hint.queue_redraw()
	if _icon.visible:
		_icon.queue_redraw()
	if is_revealing():
		var before := int(_reveal)
		_reveal += delta * CHARS_PER_SECOND
		_text_label.visible_characters = int(_reveal)
		if int(_reveal) / 3 != before / 3:
			Sfx.play(&"talk")
		if int(_reveal) >= _text_label.text.length():
			_text_label.visible_characters = -1


func _advance() -> void:
	Sfx.play(&"next")
	_index += 1
	if _index >= _lines.size():
		_finish()
	else:
		_show_line()


## True while the current line is still being typed out.
func is_revealing() -> bool:
	return is_active and _text_label.visible_characters >= 0


func _show_line() -> void:
	_text_label.text = _lines[_index].replace("{name}", GameState.player_name)
	_reveal = 0.0
	_text_label.visible_characters = 0


func _finish() -> void:
	is_active = false
	_panel.visible = false
	_hint.visible = false
	EventBus.dialogue_ended.emit(_id)


func _draw_hint() -> void:
	var can_advance := not is_revealing()
	var bounce := roundf(absf(sin(_time * 5.0)) * 2.0) if can_advance else 0.0
	var color := UiKit.AMBER if can_advance else UiKit.AMBER_DIM
	_hint.draw_rect(Rect2(0, 1, 9, 9), color)
	_hint.draw_string(UiKit.font_small, Vector2(2, 8), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_SMALL, UiKit.INK)
	var tip := Vector2(15 + bounce, 5.5)
	_hint.draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(5, 0), tip + Vector2(0, 4)]), color)
	if _lines.size() > 1:
		_hint.draw_string(UiKit.font_small, Vector2(-34, 9), "%d/%d" % [_index + 1, _lines.size()], HORIZONTAL_ALIGNMENT_RIGHT, 28, UiKit.SIZE_SMALL, UiKit.TEXT_DIM)


## A little antenna with radio waves, for Mission Control and machines.
func _draw_radio() -> void:
	var c := _icon
	var mid := Vector2(17, 20)
	c.draw_rect(Rect2(mid + Vector2(-1, -6), Vector2(2, 14)), UiKit.TEXT_DIM)
	c.draw_rect(Rect2(mid + Vector2(-5, 8), Vector2(10, 2)), UiKit.TEXT_DIM)
	c.draw_rect(Rect2(mid + Vector2(-2, -9), Vector2(4, 4)), UiKit.TEAL)
	for ring in 2:
		var r := 8.0 + ring * 5.0
		var alpha := 0.9 - ring * 0.35 if int(_time * 3.0) % 3 >= ring else 0.25
		c.draw_arc(mid + Vector2(0, -7), r, -2.2, -0.95, 8, Color(UiKit.TEAL, alpha), 1.0)
