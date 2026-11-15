extends Control
## Title screen: the Moon, the outpost's lights, a lander drifting past, and the menu.

const SKY := Color("070b1c")
const MOON := Color("77778f")
const MOON_DARK := Color("55546e")
const MOON_LIGHT := Color("9a99b0")

var _stars: Array[Vector3] = []
var _continue_button: Button
var _time := 0.0
var _lander: Control
var _menu: VBoxContainer


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for i in 120:
		_stars.append(Vector3(rng.randi_range(0, 479), rng.randi_range(0, 200), rng.randf_range(0.4, 2.2)))
	_lander = Control.new()
	_lander.set_script(load("res://scripts/ui/title_lander.gd"))
	_lander.position = Vector2(40, 96)
	_lander.size = Vector2(48, 40)
	add_child(_lander)

	_menu = VBoxContainer.new()
	_menu.position = Vector2(172, 96)
	_menu.size = Vector2(136, 0)
	_menu.add_theme_constant_override("separation", 3)
	add_child(_menu)
	var first := _add_button("New game", _new_game)
	_continue_button = _add_button("Continue", _continue_game)
	_continue_button.disabled = not _can_continue()
	_add_button("How to play", _show_help)
	_add_button("About and sources", _show_about)
	_add_button("Quit", _confirm_quit)
	(_continue_button if not _continue_button.disabled else first).grab_focus.call_deferred()

	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)


func _can_continue() -> bool:
	return GameState.has_save() and GameState.get_flag(&"astronaut_created") == true


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 480, 270), SKY)
	for i in _stars.size():
		var star := _stars[i]
		var twinkle := 0.3 + 0.65 * absf(sin(_time * star.z + float(i)))
		draw_rect(Rect2(star.x, star.y, 1, 1), Color(0.8, 0.9, 1.0, twinkle))
	# A shooting star now and then.
	var streak := fmod(_time, 7.0)
	if streak < 0.5:
		var head := Vector2(380 - streak * 300.0, 20 + streak * 110.0)
		draw_line(head, head + Vector2(18, -7), Color(1, 1, 1, 0.8 - streak), 1.0)
	# Earth.
	var earth := Vector2(404, 58)
	_ellipse(earth, 25, 25, Color("1d3a66"))
	_ellipse(earth, 23, 23, Color("2f74c0"))
	_ellipse(earth + Vector2(-7, -5), 9, 6, Color("4cab7a"))
	_ellipse(earth + Vector2(8, 8), 6, 4, Color("4cab7a"))
	draw_rect(Rect2(earth + Vector2(-14, 9), Vector2(18, 2)), Color("e6f2fb"))
	draw_rect(Rect2(earth + Vector2(-2, -13), Vector2(15, 2)), Color("e6f2fb"))
	# The Moon's limb fills the bottom of the screen.
	_ellipse(Vector2(240, 520), 560, 300, MOON_LIGHT)
	_ellipse(Vector2(240, 523), 560, 300, MOON)
	for crater: Vector3 in [Vector3(60, 246, 20), Vector3(150, 258, 11), Vector3(420, 250, 16), Vector3(330, 262, 9), Vector3(24, 262, 8)]:
		_ellipse(Vector2(crater.x, crater.y), crater.z, crater.z * 0.36, MOON_DARK)
		_ellipse(Vector2(crater.x + 2, crater.y + 1.5), crater.z - 3, crater.z * 0.36 - 1.5, Color("47465f"))
		draw_rect(Rect2(crater.x - crater.z * 0.6, crater.y - crater.z * 0.36 - 1, crater.z * 1.2, 1), MOON_LIGHT)
	# The outpost on the horizon, windows flickering, beacon blinking.
	var base := Vector2(240, 232)
	draw_rect(Rect2(base + Vector2(-46, -8), Vector2(92, 14)), Color("2c2e56"))
	draw_rect(Rect2(base + Vector2(-46, -8), Vector2(92, 2)), Color("585d94"))
	draw_rect(Rect2(base + Vector2(-16, -20), Vector2(32, 13)), Color("3c3f6e"))
	draw_rect(Rect2(base + Vector2(-16, -20), Vector2(32, 2)), Color("7d86ad"))
	for i in 6:
		var lit := (i + int(_time * 0.7)) % 7 != 0
		draw_rect(Rect2(base + Vector2(-40 + i * 14, -3), Vector2(7, 4)), UiKit.TEAL if lit else UiKit.TEAL_DIM)
	draw_rect(Rect2(base + Vector2(-8, -16), Vector2(16, 5)), UiKit.AMBER)
	draw_rect(Rect2(base + Vector2(-1, -27), Vector2(2, 7)), Color("7d86ad"))
	draw_rect(Rect2(base + Vector2(-1, -29), Vector2(2, 2)), UiKit.RED if int(_time * 2.0) % 2 == 0 else Color("5c2a2a"))
	for i in 2:
		for side: float in [-1.0, 1.0]:
			var panel := base + Vector2(side * (62 + i * 30) - 12, -18)
			draw_rect(Rect2(panel + Vector2(10, 12), Vector2(3, 10)), Color("555c84"))
			draw_rect(Rect2(panel, Vector2(24, 12)), Color("12142a"))
			draw_rect(Rect2(panel + Vector2(1, 1), Vector2(22, 10)), Color("1f3f8a"))
			draw_rect(Rect2(panel + Vector2(1, 1), Vector2(22, 1)), Color("5f8fe0"))
	# Title.
	var title_y := 52.0 + roundf(sin(_time * 1.2) * 1.5)
	draw_string(UiKit.font_title, Vector2(0, title_y + 3), "LUNAR LIFE", HORIZONTAL_ALIGNMENT_CENTER, 480, 36, Color("12142a"))
	draw_string(UiKit.font_title, Vector2(0, title_y), "LUNAR LIFE", HORIZONTAL_ALIGNMENT_CENTER, 480, 36, UiKit.TEAL)
	draw_rect(Rect2(140, 62, 200, 1), UiKit.AMBER_DIM)
	UiKit.draw_text(self, Vector2(0, 76), "JUNIOR ASTRONAUT MISSION TRAINER", "body", UiKit.AMBER, 480, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.draw_text(self, Vector2(0, 88), "Train. Power the outpost. Shelter the crew.", "small", UiKit.TEXT_DIM, 480, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.draw_text(self, Vector2(6, 265), "NASA Space Apps Challenge 2026", "small", Color(UiKit.TEXT_DIM, 0.8))
	UiKit.draw_text(self, Vector2(0, 265), "Arrows + Enter to choose", "small", Color(UiKit.TEXT_DIM, 0.8), 474, HORIZONTAL_ALIGNMENT_RIGHT)


func _ellipse(center: Vector2, rx: float, ry: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 40:
		var a := TAU * float(i) / 40.0
		points.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	draw_colored_polygon(points, color)


func _add_button(label: String, action: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(136, 0)
	button.pressed.connect(action)
	_menu.add_child(button)
	return button


func _new_game() -> void:
	if _can_continue():
		var panel := ChoicePanel.open(self, "START A NEW ASTRONAUT?", "This replaces %s's saved certificate and field notes." % GameState.player_name, PackedStringArray(["Keep my astronaut", "Start over"]))
		panel.chosen.connect(func(index: int) -> void:
			if index == 1:
				_start_fresh()
			else:
				_continue_button.grab_focus())
		panel.closed.connect(func() -> void: _continue_button.grab_focus())
		return
	_start_fresh()


func _start_fresh() -> void:
	GameState.start_fresh_progress()
	MissionDirector.start_new_game()
	SceneRouter.go_to(&"create_astronaut")


func _continue_game() -> void:
	if GameState.load_progress():
		MissionDirector.resume_from_save()
		SceneRouter.go_to(&"academy_hub")


func _show_help() -> void:
	var panel := ChoicePanel.open(self, "HOW TO PLAY", "WASD or arrow keys: walk. Two keys at once walks diagonally.\nE, Space or Enter: talk, use things, next line of text.\nHold E: crank open the storm shelter's heavy hatch.\nM: map. Esc or P: pause. N: sound on or off.\n\nFollow the objective in the top-left corner. When the radiation alert sounds, run north to the shelter.", PackedStringArray(["Got it"]))
	panel.tree_exited.connect(_refocus)


func _show_about() -> void:
	var panel := ChoicePanel.open(self, "ABOUT LUNAR LIFE", "A training game about living at the Moon's south pole: sunlight comes and goes, batteries carry the outpost through shadow, and the crew shelters from solar particle storms.\n\nThe radiation alert replays a real NASA DONKI record (solar energetic particles, 10 May 2024). Power, exposure and time are simplified game units. Every fact in the Field notes names its NASA source.\n\nFonts: Galmuri by Lee Minseo (OFL). Characters made with SpriteCook. Built in Godot.", PackedStringArray(["Back"]))
	panel.tree_exited.connect(_refocus)


func _confirm_quit() -> void:
	var panel := ChoicePanel.open(self, "LEAVE THE MOON?", "Are you sure you want to quit Lunar Life?", PackedStringArray(["Keep exploring", "Quit"]))
	panel.chosen.connect(func(index: int) -> void:
		if index == 1:
			get_tree().quit())
	panel.tree_exited.connect(_refocus)


func _refocus() -> void:
	if is_inside_tree() and get_viewport().gui_get_focus_owner() == null:
		_menu.get_child(0).grab_focus.call_deferred()
