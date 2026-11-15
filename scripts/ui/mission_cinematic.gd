extends Control
## The opening story: four illustrated slides, each with a short caption.
##
## NOTHING advances on a timer. The reader presses E (or Space / Enter) when they are
## ready: the first press finishes typing the caption, the next one turns the page.
## Esc skips the whole intro. Emits `finished` when it is over.
##
## The pictures are drawn in code with whole pixels at 480 x 270.

signal finished

const SLIDES: Array[Dictionary] = [
	{
		"title": "THE MOON, SOUTH POLE",
		"text": "People are learning to live on the Moon. A small research outpost near the south pole needs one more crew member: you, {name}.",
	},
	{
		"title": "POWER IS LIFE",
		"text": "Here the Sun skims the horizon. When a ridge blocks it, the solar panels go dark and the outpost has to live on its batteries.",
	},
	{
		"title": "WEATHER FROM THE SUN",
		"text": "The Sun also throws out bursts of fast particles. NASA logged a real one on 10 May 2024. You will train with that record.",
	},
	{
		"title": "YOUR MISSION",
		"text": "Train at the academy. Keep the power on, keep the crops alive, and get the crew into the storm shelter in time.",
	},
]
const CHARS_PER_SECOND := 55.0
const SKY := Color("070b1c")
const MOON := Color("77778f")
const MOON_DARK := Color("55546e")
const MOON_LIGHT := Color("9a99b0")

var slide: int = 0

var _time: float = 0.0
var _slide_time: float = 0.0
var _reveal: float = 0.0
var _text: String = ""
var _lines: PackedStringArray = []
var _done: bool = false
var _sun_x: float = 60.0
var _sun_hidden: bool = false
var _battery: float = 0.6
var _stars: Array[Vector3] = []
var _cast: Array[TextureRect] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024
	for i in 90:
		_stars.append(Vector3(rng.randi_range(0, 479), rng.randi_range(0, 190), rng.randf_range(0.5, 2.5)))
	# The crew for the last slide: three mentors and the player's own astronaut in their suit colour.
	var faces := ["npc_commander.png", "npc_engineer.png", "npc_botanist.png", "astronaut/astronaut_front_idle.png"]
	for i in faces.size():
		var rect := TextureRect.new()
		rect.texture = load("res://assets/art/characters/" + faces[i])
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.size = Vector2(64, 64)
		rect.position = Vector2(92 + i * 78, 92)
		rect.visible = false
		if i == 3:
			var mat := ShaderMaterial.new()
			mat.shader = load("res://assets/shaders/suit_tint.gdshader")
			mat.set_shader_parameter("suit_color", GameState.suit_color)
			rect.material = mat
		add_child(rect)
		_cast.append(rect)
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.35)
	_show_slide(0)


func _show_slide(index: int) -> void:
	slide = index
	_slide_time = 0.0
	_reveal = 0.0
	_text = str(SLIDES[slide]["text"]).replace("{name}", GameState.player_name)
	_lines = _wrap(_text, 440.0)
	_text = "\n".join(_lines)
	for rect in _cast:
		rect.visible = slide == 3
	if slide == 2:
		Sfx.play(&"alert")


## Breaks the caption into lines once, so words never jump to the next line while typing.
func _wrap(text: String, width: float) -> PackedStringArray:
	var lines := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var trial := word if line.is_empty() else line + " " + word
		if UiKit.text_width(trial, "body") > width and not line.is_empty():
			lines.append(line)
			line = word
		else:
			line = trial
	if not line.is_empty():
		lines.append(line)
	return lines


func is_typing() -> bool:
	return int(_reveal) < _text.length()


func _input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed(&"ui_cancel"):
		accept_event()
		_finish()
	elif (event.is_action_pressed(&"interact") and not event.is_echo()) \
			or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		accept_event()
		advance()


## One press of E: finish typing, or go to the next slide.
func advance() -> void:
	if _done:
		return
	if is_typing():
		_reveal = float(_text.length())
		return
	Sfx.play(&"next")
	if slide + 1 >= SLIDES.size():
		_finish()
	else:
		_show_slide(slide + 1)


func _finish() -> void:
	if _done:
		return
	_done = true
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.25)
	tween.tween_callback(func() -> void: finished.emit())


func _process(delta: float) -> void:
	_time += delta
	_slide_time += delta
	if is_typing():
		var before := int(_reveal)
		_reveal += delta * CHARS_PER_SECOND
		if int(_reveal) / 3 != before / 3:
			Sfx.play(&"talk")
	if slide == 1:
		# The Sun crosses the sky; the demo battery charges in the light and drains behind the ridge.
		_sun_x = 60.0 + fmod(_slide_time * 0.16, 1.0) * 360.0
		_sun_hidden = _sun_x > 250.0 and _sun_x < 366.0
		_battery = clampf(_battery + (-0.42 if _sun_hidden else 0.3) * delta, 0.14, 1.0)
	queue_redraw()


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), SKY)
	for i in _stars.size():
		var star := _stars[i]
		var twinkle := 0.35 + 0.6 * absf(sin(_time * star.z + float(i)))
		draw_rect(Rect2(star.x, star.y, 1, 1), Color(0.8, 0.9, 1.0, twinkle))
	match slide:
		0: _draw_destination()
		1: _draw_power()
		2: _draw_weather()
		_: _draw_mission()
	# A quick fade at the start of each slide.
	var veil := clampf(1.0 - _slide_time / 0.25, 0.0, 1.0)
	if veil > 0.0:
		draw_rect(Rect2(0, 0, 480, 196), Color(SKY, veil))
	_draw_caption()


func _draw_caption() -> void:
	var box := Rect2(10, 198, 460, 64)
	draw_rect(box, Color(UiKit.PANEL, 0.97))
	draw_rect(box, UiKit.TEAL, false, 1.0)
	UiKit.draw_text(self, box.position + Vector2(9, 15), str(SLIDES[slide]["title"]), "title", UiKit.AMBER)
	# Typed caption. Lines were broken up front, so the text only ever grows.
	var left := int(_reveal)
	for i in _lines.size():
		if left <= 0:
			break
		var line := _lines[i]
		UiKit.draw_text(self, box.position + Vector2(9, 30 + i * 12), line.substr(0, left), "body", UiKit.TEXT)
		left -= line.length() + 1
	# Progress dots.
	for i in SLIDES.size():
		var dot := Rect2(box.end.x - 12 - (SLIDES.size() - i) * 8, box.position.y + 8, 5, 5)
		draw_rect(dot, UiKit.AMBER if i == slide else UiKit.LINE)
	# Prompts.
	UiKit.draw_text(self, Vector2(box.position.x + 9, box.end.y - 5), "Esc: skip intro", "small", UiKit.TEXT_DIM)
	var ready_to_turn := not is_typing()
	var color := UiKit.AMBER if ready_to_turn else UiKit.AMBER_DIM
	var bounce := roundf(absf(sin(_time * 5.0)) * 2.0) if ready_to_turn else 0.0
	var words := "Next" if slide + 1 < SLIDES.size() else "Begin"
	var at := Vector2(box.end.x - 60, box.end.y - 14)
	draw_rect(Rect2(at, Vector2(9, 9)), color)
	draw_string(UiKit.font_small, at + Vector2(2, 7), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_SMALL, UiKit.INK)
	UiKit.draw_text(self, at + Vector2(13, 8), words, "small", color)
	var tip := at + Vector2(42 + bounce, 4.5)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(0, -4), tip + Vector2(5, 0), tip + Vector2(0, 4)]), color)


func _moon_ground(top: float) -> void:
	draw_rect(Rect2(0, top, 480, 196 - top), MOON)
	for i in 40:
		var x := float((i * 97 + 31) % 480)
		var y := top + 4.0 + float((i * 53 + 7) % int(maxf(8.0, 190.0 - top)))
		draw_rect(Rect2(x, y, 3 + i % 3, 1), MOON_DARK if i % 2 == 0 else MOON_LIGHT)
	for crater: Vector3 in [Vector3(70, top + 22, 14), Vector3(330, top + 34, 20), Vector3(430, top + 14, 9)]:
		_ellipse(Vector2(crater.x, crater.y), crater.z, crater.z * 0.45, MOON_DARK)
		_ellipse(Vector2(crater.x + 2, crater.y + 2), crater.z - 3, crater.z * 0.45 - 1.5, Color("47465f"))
		draw_rect(Rect2(crater.x - crater.z * 0.6, crater.y - crater.z * 0.45 - 1, crater.z * 1.2, 1), MOON_LIGHT)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 24:
		var a := TAU * float(i) / 24.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _habitat(at: Vector2, lit: bool = true) -> void:
	# Three modules and a dome, with lit windows.
	draw_rect(Rect2(at + Vector2(-34, -8), Vector2(68, 14)), Color("2c2e56"))
	draw_rect(Rect2(at + Vector2(-34, -8), Vector2(68, 2)), Color("585d94"))
	draw_rect(Rect2(at + Vector2(-12, -18), Vector2(24, 12)), Color("3c3f6e"))
	draw_rect(Rect2(at + Vector2(-12, -18), Vector2(24, 2)), Color("7d86ad"))
	for i in 5:
		draw_rect(Rect2(at + Vector2(-29 + i * 13, -3), Vector2(6, 4)), UiKit.TEAL if lit else Color("1a2440"))
	draw_rect(Rect2(at + Vector2(-6, -14), Vector2(12, 5)), UiKit.AMBER if lit else Color("1a2440"))
	draw_rect(Rect2(at + Vector2(-38, 6), Vector2(76, 2)), Color(0.05, 0.05, 0.12, 0.5))


func _solar_panel(at: Vector2, lit: float) -> void:
	draw_rect(Rect2(at + Vector2(10, 14), Vector2(3, 10)), Color("555c84"))
	draw_rect(Rect2(at, Vector2(24, 14)), Color("12142a"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(22, 12)), Color("16306e").lerp(Color("3f6cc4"), lit))
	for i in 3:
		draw_rect(Rect2(at + Vector2(1 + i * 8, 1), Vector2(1, 12)), Color("0f1f4a"))
	draw_rect(Rect2(at + Vector2(1, 1), Vector2(22, 1)), Color("5f8fe0").lerp(Color.WHITE, lit * 0.5))
	draw_rect(Rect2(at + Vector2(6, 24), Vector2(34, 2)), Color(0.05, 0.05, 0.12, 0.45))


## Slide 1: Earth far away, the outpost on the Moon, a lander on its way down.
func _draw_destination() -> void:
	var earth := Vector2(96, 62)
	_ellipse(earth, 30, 30, Color("1d3a66"))
	_ellipse(earth, 28, 28, Color("2f74c0"))
	_ellipse(earth + Vector2(-8, -6), 12, 8, Color("4cab7a"))
	_ellipse(earth + Vector2(10, 9), 8, 5, Color("4cab7a"))
	draw_rect(Rect2(earth + Vector2(-16, 10), Vector2(22, 3)), Color("e6f2fb"))
	draw_rect(Rect2(earth + Vector2(-2, -15), Vector2(18, 3)), Color("e6f2fb"))
	_moon_ground(134)
	_habitat(Vector2(300, 148))
	for i in 2:
		_solar_panel(Vector2(356 + i * 34, 128), 1.0)
	# Lander: drifts down and to the right, engine flickering.
	var t := fmod(_time * 0.12, 1.0)
	var ship := Vector2(170 + t * 60.0, 30 + t * 60.0).round()
	draw_rect(Rect2(ship + Vector2(2, 6), Vector2(20, 10)), Color("b8ad91"))
	draw_rect(Rect2(ship + Vector2(5, 2), Vector2(14, 6)), Color("d7d4c2"))
	draw_rect(Rect2(ship + Vector2(7, 3), Vector2(10, 3)), Color("5a8ba1"))
	draw_rect(Rect2(ship + Vector2(0, 14), Vector2(3, 8)), Color("9397a4"))
	draw_rect(Rect2(ship + Vector2(21, 14), Vector2(3, 8)), Color("9397a4"))
	var flame := 3 + int(absf(sin(_time * 18.0)) * 5.0)
	draw_rect(Rect2(ship + Vector2(8, 16), Vector2(3, flame)), UiKit.AMBER)
	draw_rect(Rect2(ship + Vector2(14, 16), Vector2(3, flame - 1)), Color("ff9860"))


## Slide 2: the Sun slides behind a ridge; the panels dim and the battery starts to drain.
func _draw_power() -> void:
	var hidden := _sun_hidden
	var sun := Vector2(roundf(_sun_x), 96)
	draw_rect(Rect2(sun - Vector2(11, 11), Vector2(22, 22)), Color("f6a64c"))
	draw_rect(Rect2(sun - Vector2(8, 8), Vector2(16, 16)), Color("ffe08a"))
	for ray in 8:
		var dir := Vector2.RIGHT.rotated(TAU * float(ray) / 8.0 + _time * 0.3)
		draw_rect(Rect2((sun + dir * 16.0).round(), Vector2(2, 2)), Color("ffc45e"))
	# The ridge that gets in the way.
	draw_colored_polygon(PackedVector2Array([Vector2(230, 122), Vector2(262, 70), Vector2(292, 96), Vector2(322, 58),
		Vector2(352, 90), Vector2(384, 122)]), MOON_DARK)
	draw_polyline(PackedVector2Array([Vector2(262, 70), Vector2(292, 96), Vector2(322, 58)]), MOON_LIGHT, 1.0)
	_moon_ground(120)
	var light := 0.0 if hidden else 1.0
	for i in 4:
		_solar_panel(Vector2(70 + i * 40, 134), light)
	_habitat(Vector2(360, 152), true)
	# Big battery gauge: fills in sunlight, drains in shadow.
	var level := _battery
	var gauge := Rect2(196, 24, 88, 22)
	draw_rect(gauge, Color("12142a"))
	draw_rect(gauge, UiKit.TEXT, false, 1.0)
	draw_rect(Rect2(gauge.end.x, gauge.position.y + 6, 4, 10), UiKit.TEXT)
	var cells := int(round(level * 8.0))
	for i in 8:
		var cell_color := UiKit.PANEL_HI
		if i < cells:
			cell_color = UiKit.AMBER if cells <= 2 else UiKit.TEAL
		draw_rect(Rect2(gauge.position.x + 3 + i * 10.5, gauge.position.y + 3, 9, 16), cell_color)
	var words := "IN SHADOW: running on battery" if hidden else "IN SUNLIGHT: charging"
	UiKit.draw_text(self, Vector2(140, 60), words, "small", UiKit.TEXT_DIM if hidden else UiKit.AMBER, 200, HORIZONTAL_ALIGNMENT_CENTER)


## Slide 3: an eruption on the Sun sends particles across to the Moon. The card is the real record.
func _draw_weather() -> void:
	var sun := Vector2(64, 96)
	draw_rect(Rect2(sun - Vector2(34, 34), Vector2(68, 68)), Color("f6a64c"))
	draw_rect(Rect2(sun - Vector2(28, 28), Vector2(56, 56)), Color("ffd878"))
	draw_rect(Rect2(sun + Vector2(4, -14), Vector2(10, 7)), Color("c9772f"))
	draw_rect(Rect2(sun + Vector2(-16, 6), Vector2(7, 5)), Color("c9772f"))
	# Eruption loop.
	var flare := 0.5 + 0.5 * sin(_time * 3.0)
	draw_arc(sun + Vector2(34, -6), 13.0 + flare * 4.0, -1.9, 1.9, 14, Color("ff8a4a"), 3.0)
	draw_arc(sun + Vector2(34, -6), 8.0 + flare * 3.0, -1.9, 1.9, 12, Color("ffe08a"), 2.0)
	# Particle stream.
	for i in 46:
		var travel := fposmod(_time * (150.0 + float(i % 7) * 26.0) + float(i) * 37.0, 310.0)
		var y := 60.0 + float((i * 29) % 76) + sin(travel * 0.03 + float(i)) * 3.0
		var x := sun.x + 44.0 + travel
		draw_rect(Rect2(roundf(x), roundf(y), 4, 1), Color(1.0, 0.86, 0.5, 0.9))
		draw_rect(Rect2(roundf(x) + 4, roundf(y), 1, 1), Color.WHITE)
	# The Moon and the outpost, with a flashing warning.
	_ellipse(Vector2(408, 102), 40, 40, MOON)
	_ellipse(Vector2(394, 88), 9, 7, MOON_DARK)
	_ellipse(Vector2(424, 118), 12, 9, MOON_DARK)
	_habitat(Vector2(408, 70), true)
	if int(_time * 3.0) % 2 == 0:
		var tri := Vector2(408, 34)
		draw_colored_polygon(PackedVector2Array([tri + Vector2(0, -9), tri + Vector2(9, 7), tri + Vector2(-9, 7)]), UiKit.AMBER)
		draw_rect(Rect2(tri + Vector2(-1, -4), Vector2(2, 6)), UiKit.INK)
		draw_rect(Rect2(tri + Vector2(-1, 4), Vector2(2, 2)), UiKit.INK)
	# Data card.
	var card := Rect2(150, 150, 180, 38)
	draw_rect(card, Color(UiKit.INK, 0.94))
	draw_rect(card, UiKit.VIOLET, false, 1.0)
	UiKit.draw_text(self, card.position + Vector2(6, 11), "NASA DONKI  /  ARCHIVED RECORD", "small", UiKit.VIOLET)
	if MissionDirector.sep_is_real:
		UiKit.draw_text(self, card.position + Vector2(6, 22), "Solar energetic particles", "small", UiKit.TEXT)
		UiKit.draw_text(self, card.position + Vector2(6, 33), MissionDirector.sep_time_text(), "small", UiKit.AMBER)
	else:
		UiKit.draw_text(self, card.position + Vector2(6, 26), "Training scenario (fictional)", "small", UiKit.TEXT)


## Slide 4: the crew you will meet, and the three jobs.
func _draw_mission() -> void:
	draw_rect(Rect2(60, 60, 360, 110), Color("1b1d3d"))
	draw_rect(Rect2(60, 60, 360, 110), Color("3c3f6e"), false, 1.0)
	draw_rect(Rect2(60, 150, 360, 20), Color("3a3d62"))
	draw_rect(Rect2(60, 150, 360, 1), Color("585d94"))
	for i in 4:
		draw_rect(Rect2(76 + i * 96, 66, 44, 3), UiKit.TEAL_DIM)
	var names := ["Cmdr Okafor", "Eng. Rivera", "Dr. Tanaka", GameState.player_name]
	for i in names.size():
		var x := 92.0 + i * 78.0
		UiKit.draw_text(self, Vector2(x - 12, 166), names[i], "small", UiKit.AMBER if i == 3 else UiKit.TEXT, 88, HORIZONTAL_ALIGNMENT_CENTER)
	# Power, crops, shelter.
	var jobs := [["POWER", UiKit.TEAL], ["CROPS", UiKit.GREEN], ["SHELTER", UiKit.AMBER]]
	for i in jobs.size():
		var box := Rect2(108 + i * 96, 24, 74, 22)
		var color: Color = jobs[i][1]
		var pop := clampf((_slide_time - 0.3 - i * 0.25) / 0.2, 0.0, 1.0)
		if pop <= 0.0:
			continue
		draw_rect(box, Color(UiKit.INK, 0.9))
		draw_rect(box, color, false, 1.0)
		var icon := box.position + Vector2(10, 11)
		match i:
			0:
				draw_colored_polygon(PackedVector2Array([icon + Vector2(2, -7), icon + Vector2(-4, 1), icon + Vector2(0, 1), icon + Vector2(-2, 7), icon + Vector2(4, -1), icon + Vector2(0, -1)]), color)
			1:
				_ellipse(icon + Vector2(0, -1), 5, 3.5, color)
				draw_rect(Rect2(icon + Vector2(-1, 2), Vector2(2, 5)), color)
			_:
				draw_colored_polygon(PackedVector2Array([icon + Vector2(-5, -6), icon + Vector2(5, -6), icon + Vector2(5, 0), icon + Vector2(0, 7), icon + Vector2(-5, 0)]), color)
		UiKit.draw_text(self, box.position + Vector2(22, 14), jobs[i][0], "small", color)
