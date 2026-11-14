extends Control
## Create your astronaut — pick a name and a suit colour. GREY-BOX version.
## Saves the choices to GameState, then opens the academy.

const SUIT_COLORS: Array[Color] = [
	Color(0.95, 0.55, 0.2),   # orange
	Color(0.9, 0.3, 0.3),     # red
	Color(0.95, 0.8, 0.3),    # yellow
	Color(0.4, 0.75, 0.45),   # green
	Color(0.35, 0.6, 0.95),   # blue
	Color(0.7, 0.5, 0.9),     # purple
	Color(0.92, 0.92, 0.95),  # classic white
]

var _name_edit: LineEdit
var _preview_mat: ShaderMaterial
var _color: Color = SUIT_COLORS[0]


func _ready() -> void:
	ResourceSim.paused = true
	var t := Theme.new()
	t.default_font_size = 8
	theme = t

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.08, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	center.add_child(box)

	var title := Label.new()
	title.text = "LUNAR LIFE  -  Create your astronaut"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var preview := TextureRect.new()
	preview.texture = load("res://assets/art/characters/player_astronaut.png")
	preview.custom_minimum_size = Vector2(96, 96)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_preview_mat = ShaderMaterial.new()
	_preview_mat.shader = load("res://assets/shaders/suit_tint.gdshader")
	preview.material = _preview_mat
	box.add_child(preview)

	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(name_row)
	var name_label := Label.new()
	name_label.text = "Name:"
	name_row.add_child(name_label)
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Recruit"
	_name_edit.custom_minimum_size = Vector2(90, 0)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _start())
	name_row.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	color_row.alignment = BoxContainer.ALIGNMENT_CENTER
	color_row.add_theme_constant_override("separation", 3)
	box.add_child(color_row)
	var color_label := Label.new()
	color_label.text = "Suit:"
	color_row.add_child(color_label)
	for c in SUIT_COLORS:
		color_row.add_child(_make_swatch(c))

	var start := Button.new()
	start.text = "Start training"
	start.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	start.pressed.connect(_start)
	box.add_child(start)

	_set_color(_color)
	_name_edit.grab_focus()


func _make_swatch(c: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(16, 12)
	b.focus_mode = Control.FOCUS_NONE
	for state in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if state != "hover" else c.lightened(0.2)
		sb.set_border_width_all(1)
		sb.border_color = Color(0.1, 0.1, 0.15)
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func() -> void: _set_color(c))
	return b


func _set_color(c: Color) -> void:
	_color = c
	_preview_mat.set_shader_parameter("suit_color", c)


func _start() -> void:
	var chosen := _name_edit.text.strip_edges()
	GameState.player_name = chosen if chosen != "" else "Recruit"
	GameState.suit_color = _color
	GameState.set_flag(&"astronaut_created")
	MissionDirector.start_new_game()
	SceneRouter.go_to(&"academy_hub")
