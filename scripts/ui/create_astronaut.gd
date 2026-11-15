extends Control
## Crew registration: pick a name and a suit colour, watch your astronaut walk on the spot.
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
const SUIT_NAMES: Array[String] = ["Orange", "Red", "Yellow", "Green", "Blue", "Purple", "White"]
const ART := "res://assets/art/characters/astronaut/"
const STAGE_CENTER := Vector2(120, 150)

var _name_edit: LineEdit
var _preview: AnimatedSprite2D
var _preview_mat: ShaderMaterial
var _color: Color = SUIT_COLORS[0]
var _swatches: Array[Button] = []
var _color_label: Label
var _time: float = 0.0
var _starting: bool = false


func _ready() -> void:
	ResourceSim.paused = true

	# The astronaut, four times life size, walking on the spot and turning now and then.
	_preview = AnimatedSprite2D.new()
	_preview.sprite_frames = _build_frames()
	_preview.position = STAGE_CENTER + Vector2(0, -34)
	_preview.scale = Vector2(4, 4)
	_preview_mat = ShaderMaterial.new()
	_preview_mat.shader = load("res://assets/shaders/suit_tint.gdshader")
	_preview.material = _preview_mat
	add_child(_preview)
	_preview.play(&"front")

	var form := VBoxContainer.new()
	form.position = Vector2(232, 56)
	form.size = Vector2(216, 0)
	form.add_theme_constant_override("separation", 6)
	add_child(form)
	form.add_child(UiKit.label("CREW REGISTRATION", "title", UiKit.AMBER))
	form.add_child(UiKit.label("Lunar Life  /  Astronaut Academy", "small", UiKit.TEXT_DIM))
	form.add_child(HSeparator.new())

	form.add_child(UiKit.label("Your name", "small", UiKit.TEAL))
	_name_edit = LineEdit.new()
	_name_edit.max_length = 12
	_name_edit.placeholder_text = "Recruit"
	_name_edit.custom_minimum_size = Vector2(160, 0)
	_name_edit.text_submitted.connect(func(_text: String) -> void: _start())
	form.add_child(_name_edit)

	var color_row := HBoxContainer.new()
	form.add_child(color_row)
	color_row.add_child(UiKit.label("Suit colour", "small", UiKit.TEAL))
	_color_label = UiKit.label("", "small", UiKit.TEXT)
	_color_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	color_row.add_child(_color_label)
	var swatch_row := HBoxContainer.new()
	swatch_row.add_theme_constant_override("separation", 4)
	form.add_child(swatch_row)
	for i in SUIT_COLORS.size():
		var swatch := _make_swatch(i)
		swatch_row.add_child(swatch)
		_swatches.append(swatch)

	form.add_child(HSeparator.new())
	var start := Button.new()
	start.text = "Start training"
	start.pressed.connect(_start)
	form.add_child(start)
	form.add_child(UiKit.label("Tab moves between fields. Enter starts.", "small", UiKit.TEXT_DIM))

	_set_color(0)
	_name_edit.grab_focus()
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.3)


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for facing: String in ["front", "right", "back", "left"]:
		var strip: Texture2D = load(ART + "astronaut_walk_%s_strip_256x32.png" % facing)
		frames.add_animation(facing)
		frames.set_animation_speed(facing, 10.0)
		frames.set_animation_loop(facing, true)
		for i in 8:
			var tex := AtlasTexture.new()
			tex.atlas = strip
			tex.region = Rect2(i * 32, 0, 32, 32)
			frames.add_frame(facing, tex)
	return frames


func _process(delta: float) -> void:
	_time += delta
	# A slow turntable: front, right, back, left.
	var facing: String = ["front", "right", "back", "left"][int(_time / 2.4) % 4]
	if _preview.animation != StringName(facing):
		_preview.play(facing)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), Color("0a0f22"))
	# Suit-up bay behind the astronaut.
	var bay := Rect2(40, 34, 160, 190)
	draw_rect(bay, Color("1b1d3d"))
	draw_rect(bay, Color("3c3f6e"), false, 1.0)
	for i in 5:
		draw_rect(Rect2(bay.position.x + 8 + i * 30, bay.position.y + 6, 24, 3), UiKit.TEAL_DIM if (i + int(_time)) % 5 != 0 else UiKit.TEAL)
	for i in 6:
		draw_rect(Rect2(bay.position.x, bay.position.y + 30 + i * 26, bay.size.x, 1), Color("23254a"))
	draw_rect(Rect2(bay.position.x, bay.end.y - 46, bay.size.x, 46), Color("3a3d62"))
	draw_rect(Rect2(bay.position.x, bay.end.y - 46, bay.size.x, 1), Color("585d94"))
	# Spotlight and round platform.
	draw_colored_polygon(PackedVector2Array([Vector2(STAGE_CENTER.x - 16, bay.position.y + 10), Vector2(STAGE_CENTER.x + 16, bay.position.y + 10),
		Vector2(STAGE_CENTER.x + 52, STAGE_CENTER.y + 32), Vector2(STAGE_CENTER.x - 52, STAGE_CENTER.y + 32)]), Color(_color, 0.07))
	_ellipse(STAGE_CENTER + Vector2(0, 34), 56, 13, Color("12142a"))
	_ellipse(STAGE_CENTER + Vector2(0, 32), 54, 12, Color("555c84"))
	_ellipse(STAGE_CENTER + Vector2(0, 31), 50, 10, Color("3c3f6e"))
	_ellipse(STAGE_CENTER + Vector2(0, 31), 36, 6, Color(_color, 0.35))
	_ellipse(STAGE_CENTER + Vector2(0, 30), 26, 4, Color(0.02, 0.03, 0.08, 0.5))
	var badge := _name_edit.text.strip_edges() if _name_edit != null else ""
	UiKit.draw_text(self, Vector2(bay.position.x, bay.end.y - 8), (badge if badge != "" else "Recruit").to_upper(), "title", UiKit.TEXT, bay.size.x, HORIZONTAL_ALIGNMENT_CENTER)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 28:
		var a := TAU * float(i) / 28.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _make_swatch(index: int) -> Button:
	var c := SUIT_COLORS[index]
	var b := Button.new()
	b.custom_minimum_size = Vector2(22, 18)
	b.tooltip_text = SUIT_NAMES[index]
	for state: String in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c if state != "hover" else c.lightened(0.2)
		sb.set_border_width_all(1)
		sb.border_color = UiKit.INK
		if state == "focus":
			sb.draw_center = false
			sb.border_color = Color.WHITE
		b.add_theme_stylebox_override(state, sb)
	b.pressed.connect(func() -> void: _set_color(index))
	b.focus_entered.connect(func() -> void: _set_color(index))
	return b


func _set_color(index: int) -> void:
	_color = SUIT_COLORS[index]
	_color_label.text = SUIT_NAMES[index]
	_preview_mat.set_shader_parameter("suit_color", _color)
	for i in _swatches.size():
		# The chosen swatch sits a little higher, so the choice does not rely on colour alone.
		_swatches[i].custom_minimum_size.y = 22 if i == index else 18


func _start() -> void:
	if _starting:
		return
	_starting = true
	var chosen := _name_edit.text.strip_edges()
	GameState.player_name = chosen if chosen != "" else "Recruit"
	GameState.suit_color = _color
	GameState.set_flag(&"astronaut_created")
	MissionDirector.start_new_game()
	Sfx.play(&"confirm")
	SceneRouter.go_to(&"academy_hub")
