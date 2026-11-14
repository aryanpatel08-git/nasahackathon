extends CanvasLayer
## Dialogue — shows a speech box and steps through lines (autoload).
## Usage: Dialogue.play(&"commander_intro", "Commander Okafor", lines)
## Press the interact key to advance. Emits EventBus.dialogue_started / dialogue_ended.
## "{name}" in a line is replaced with the player's astronaut name.

var is_active: bool = false

var _id: StringName = &""
var _lines: PackedStringArray = []
var _index: int = 0
var _panel: PanelContainer
var _speaker_label: Label
var _text_label: Label
var _reveal: float = 0.0

const CHARS_PER_SECOND := 55.0


func _ready() -> void:
	layer = 50
	var t := Theme.new()
	t.default_font_size = 8

	_panel = PanelContainer.new()
	_panel.theme = t
	_panel.position = Vector2(8, 202)
	_panel.size = Vector2(464, 60)
	_panel.visible = false
	add_child(_panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 5)
	_panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	margin.add_child(box)

	_speaker_label = Label.new()
	_speaker_label.modulate = Color(1.0, 0.82, 0.3)
	box.add_child(_speaker_label)

	_text_label = Label.new()
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text_label)

	var hint := Label.new()
	hint.text = "E / Space: next    Esc: skip"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.modulate = Color(1, 1, 1, 0.5)
	box.add_child(hint)


func play(id: StringName, speaker: String, lines: PackedStringArray) -> void:
	if is_active or lines.is_empty():
		return
	_id = id
	_lines = lines
	_index = 0
	is_active = true
	_speaker_label.text = speaker
	_panel.visible = true
	_show_line()
	EventBus.dialogue_started.emit(_id)


func _unhandled_input(event: InputEvent) -> void:
	if not is_active:
		return
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_finish()
	elif event.is_action_pressed(&"interact"):
		get_viewport().set_input_as_handled()
		if is_revealing():
			# First press finishes the line; the next press moves on.
			_reveal = 100000.0
			_text_label.visible_characters = -1
			return
		Sfx.play(&"next")
		_index += 1
		if _index >= _lines.size():
			_finish()
		else:
			_show_line()


func _process(delta: float) -> void:
	if not is_revealing():
		return
	var before := int(_reveal)
	_reveal += delta * CHARS_PER_SECOND
	_text_label.visible_characters = int(_reveal)
	if int(_reveal) / 3 != before / 3:
		Sfx.play(&"talk")
	if int(_reveal) >= _text_label.text.length():
		_text_label.visible_characters = -1


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
	EventBus.dialogue_ended.emit(_id)
