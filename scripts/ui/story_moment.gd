extends Control
## Two short story pictures: the certificate badge (graduation) and the lander's
## touchdown at the outpost (arrival). Each fades in, plays for a few seconds and frees
## itself. The arrival holds the astronaut still until the lander is down.

enum Moment { GRADUATION, ARRIVAL }

const SKY := Color("070b1c")
const MOON := Color("77778f")
const MOON_DARK := Color("55546e")
const MOON_LIGHT := Color("9a99b0")

var moment: Moment = Moment.GRADUATION
var _elapsed := 0.0
var _duration := 2.6
var _holding := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if moment == Moment.ARRIVAL:
		_duration = 3.4
		_holding = true
		MissionDirector.push_ui()
		add_to_group(&"fullscreen_story")
		Sfx.play(&"travel")
	modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.22)
	tween.tween_interval(_duration - 0.6)
	tween.tween_property(self, "modulate:a", 0.0, 0.38)
	tween.tween_callback(queue_free)


func _exit_tree() -> void:
	if _holding:
		MissionDirector.pop_ui()


func _process(delta: float) -> void:
	_elapsed += delta
	queue_redraw()


func _draw() -> void:
	if moment == Moment.ARRIVAL:
		_draw_arrival()
	else:
		_draw_graduation()


func _draw_arrival() -> void:
	draw_rect(Rect2(0, 0, 480, 270), SKY)
	for i in 70:
		var x := float((i * 83 + 29) % 480)
		var y := float((i * 47 + 17) % 170)
		draw_rect(Rect2(x, y, 1, 1), Color(0.8, 0.9, 1.0, 0.4 + 0.5 * absf(sin(_elapsed * 2.0 + i))))
	# Earth, small and far away.
	draw_circle(Vector2(392, 52), 17.0, Color("1d3a66"))
	draw_circle(Vector2(392, 52), 15.0, Color("2f74c0"))
	draw_rect(Rect2(382, 46, 12, 5), Color("4cab7a"))
	draw_rect(Rect2(390, 57, 14, 2), Color("e6f2fb"))
	# Ground with a ridge line, craters and the outpost.
	draw_colored_polygon(PackedVector2Array([Vector2(0, 186), Vector2(60, 172), Vector2(130, 184), Vector2(210, 170),
		Vector2(290, 182), Vector2(380, 168), Vector2(480, 180), Vector2(480, 270), Vector2(0, 270)]), MOON_DARK)
	draw_rect(Rect2(0, 196, 480, 74), MOON)
	for i in 30:
		draw_rect(Rect2(float((i * 97 + 13) % 480), 200.0 + float((i * 37) % 60), 4, 1), MOON_DARK if i % 2 == 0 else MOON_LIGHT)
	for crater: Vector3 in [Vector3(70, 236, 16), Vector3(210, 252, 11), Vector3(440, 226, 9)]:
		draw_rect(Rect2(crater.x - crater.z, crater.y - crater.z * 0.3, crater.z * 2.0, crater.z * 0.6), MOON_DARK)
		draw_rect(Rect2(crater.x - crater.z + 2, crater.y - crater.z * 0.3 - 1, crater.z * 2.0 - 4, 1), MOON_LIGHT)
	var base := Vector2(338, 204)
	draw_rect(Rect2(base + Vector2(-52, -10), Vector2(104, 18)), Color("2c2e56"))
	draw_rect(Rect2(base + Vector2(-52, -10), Vector2(104, 2)), Color("585d94"))
	draw_rect(Rect2(base + Vector2(-18, -24), Vector2(36, 16)), Color("3c3f6e"))
	draw_rect(Rect2(base + Vector2(-18, -24), Vector2(36, 2)), Color("7d86ad"))
	for i in 7:
		draw_rect(Rect2(base + Vector2(-46 + i * 14, -4), Vector2(7, 5)), UiKit.TEAL if (i + int(_elapsed * 2.0)) % 5 != 0 else UiKit.TEAL_DIM)
	draw_rect(Rect2(base + Vector2(-9, -19), Vector2(18, 6)), UiKit.AMBER)
	for i in 2:
		var panel := base + Vector2(62 + i * 34, -22)
		draw_rect(Rect2(panel + Vector2(12, 14), Vector2(3, 12)), Color("555c84"))
		draw_rect(Rect2(panel, Vector2(28, 14)), Color("12142a"))
		draw_rect(Rect2(panel + Vector2(1, 1), Vector2(26, 12)), Color("1f3f8a"))
		draw_rect(Rect2(panel + Vector2(1, 1), Vector2(26, 1)), Color("5f8fe0"))
	# Landing pad and lander: eases down, engine cuts at touchdown, dust rolls out.
	var pad := Vector2(150, 218)
	draw_rect(Rect2(pad + Vector2(-34, 0), Vector2(68, 4)), Color("3a3d62"))
	for i in 5:
		draw_rect(Rect2(pad + Vector2(-32 + i * 15, 1), Vector2(6, 2)), UiKit.AMBER if (i + int(_elapsed * 5.0)) % 2 == 0 else Color("12142a"))
	var t := clampf(_elapsed / 2.1, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 2.2)
	var ship := (Vector2(96, 10).lerp(pad + Vector2(-17, -40), eased)).round()
	draw_rect(Rect2(ship + Vector2(3, 10), Vector2(28, 16)), Color("b8ad91"))
	draw_rect(Rect2(ship + Vector2(3, 10), Vector2(28, 2)), Color("d7d4c2"))
	draw_rect(Rect2(ship + Vector2(8, 3), Vector2(18, 8)), Color("d7d4c2"))
	draw_rect(Rect2(ship + Vector2(11, 5), Vector2(12, 4)), Color("5a8ba1"))
	draw_rect(Rect2(ship + Vector2(6, 15), Vector2(6, 6)), Color("687487"))
	draw_rect(Rect2(ship + Vector2(7, 16), Vector2(4, 1)), UiKit.TEAL)
	draw_rect(Rect2(ship + Vector2(0, 24), Vector2(4, 14)), Color("9397a4"))
	draw_rect(Rect2(ship + Vector2(30, 24), Vector2(4, 14)), Color("9397a4"))
	draw_rect(Rect2(ship + Vector2(-2, 38), Vector2(9, 2)), Color("d5c69d"))
	draw_rect(Rect2(ship + Vector2(27, 38), Vector2(9, 2)), Color("d5c69d"))
	if t < 1.0:
		var flame := 5 + int(absf(sin(_elapsed * 18.0)) * 9.0)
		draw_rect(Rect2(ship + Vector2(11, 26), Vector2(4, flame)), Color("ffd16e"))
		draw_rect(Rect2(ship + Vector2(19, 26), Vector2(4, flame - 2)), Color("ff9860"))
	if t > 0.75:
		var spread := (t - 0.75) / 0.25 * 40.0 + maxf(0.0, _elapsed - 2.1) * 26.0
		var fade := clampf(1.0 - (_elapsed - 2.1) / 1.0, 0.0, 1.0)
		for side: float in [-1.0, 1.0]:
			for i in 5:
				var puff := pad + Vector2(side * (8.0 + spread * (0.4 + i * 0.15)), -2.0 - i * 2.0)
				draw_rect(Rect2(puff.round(), Vector2(5 - i * 0.5, 3)), Color(0.85, 0.85, 0.93, 0.5 * fade))
	# Caption.
	var caption := clampf((_elapsed - 0.3) / 0.3, 0.0, 1.0)
	draw_rect(Rect2(0, 236, 480, 34), Color(UiKit.INK, 0.9 * caption))
	draw_rect(Rect2(0, 236, 480, 1), Color(UiKit.TEAL, caption))
	var words := "TOUCHDOWN" if t >= 1.0 else "DESCENDING TO THE LUNAR OUTPOST"
	UiKit.draw_text(self, Vector2(14, 251), words, "title", Color(UiKit.TEAL, caption))
	UiKit.draw_text(self, Vector2(14, 263), "South pole region  /  crew of three", "small", Color(UiKit.TEXT_DIM, caption))


func _draw_graduation() -> void:
	var fade := clampf(1.0 - (_elapsed - (_duration - 0.6)) / 0.5, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 480, 270), Color(0.02, 0.03, 0.08, 0.72 * fade))
	var center := Vector2(240, 110)
	var grow := clampf(_elapsed / 0.25, 0.0, 1.0)
	var badge := Color(UiKit.AMBER, fade)
	# Rays behind the badge.
	for i in 12:
		var angle := TAU * float(i) / 12.0 + _elapsed * 0.4
		var from := center + Vector2.RIGHT.rotated(angle) * 40.0 * grow
		var to := center + Vector2.RIGHT.rotated(angle) * (52.0 + 6.0 * sin(_elapsed * 4.0 + i)) * grow
		draw_line(from, to, Color(UiKit.AMBER, 0.6 * fade), 2.0)
	draw_circle(center, 34.0 * grow, Color(UiKit.PANEL, fade))
	draw_arc(center, 34.0 * grow, 0.0, TAU, 40, badge, 2.0)
	draw_arc(center, 29.0 * grow, 0.0, TAU, 40, Color(UiKit.AMBER_DIM, fade), 1.0)
	if grow >= 1.0:
		# Lightning bolt: the Power Console certificate.
		draw_colored_polygon(PackedVector2Array([center + Vector2(4, -20), center + Vector2(-10, 3), center + Vector2(-1, 3),
			center + Vector2(-5, 20), center + Vector2(10, -4), center + Vector2(1, -4)]), badge)
		for i in 14:
			var angle := TAU * float(i) / 14.0
			var distance := 46.0 + fposmod(_elapsed * 34.0 + i * 9.0, 30.0)
			draw_rect(Rect2((center + Vector2.RIGHT.rotated(angle) * distance).round(), Vector2(2, 2)), Color(UiKit.TEAL, fade))
	UiKit.draw_text(self, Vector2(0, 170), "CERTIFICATE EARNED", "title", Color(UiKit.AMBER, fade), 480, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.draw_text(self, Vector2(0, 185), "%s  /  Power Console Operator" % GameState.player_name, "body", Color(UiKit.TEXT, fade), 480, HORIZONTAL_ALIGNMENT_CENTER)
	UiKit.draw_text(self, Vector2(0, 200), "The lander dock is now unlocked.", "small", Color(UiKit.TEXT_DIM, fade), 480, HORIZONTAL_ALIGNMENT_CENTER)
