extends Node2D
## The little "E  Talk" tag above the astronaut's head.
## For things that need E held down it reads "E  Hold: ..." and shows a filling bar.

var hold_ratio: float = 0.0:
	set(value):
		if not is_equal_approx(value, hold_ratio):
			hold_ratio = value
			queue_redraw()

var _text: String = ""
var _needs_hold: bool = false
var _time: float = 0.0


func _ready() -> void:
	visible = false


func show_prompt(text: String, needs_hold: bool) -> void:
	if text != _text or needs_hold != _needs_hold or not visible:
		_text = text
		_needs_hold = needs_hold
		visible = true
		queue_redraw()


func hide_prompt() -> void:
	if visible:
		visible = false
		hold_ratio = 0.0


func _process(delta: float) -> void:
	if visible and _needs_hold:
		_time += delta
		queue_redraw()


func _draw() -> void:
	var label := ("Hold: " + _text) if _needs_hold else _text
	var text_w := ceilf(UiKit.text_width(label, "small"))
	var width := text_w + 21.0
	var left := -floorf(width / 2.0)
	var top := -14.0
	# Backing plate
	draw_rect(Rect2(left, top, width, 13), Color(UiKit.INK, 0.9))
	draw_rect(Rect2(left, top, width, 13), UiKit.AMBER_DIM, false, 1.0)
	# Key cap
	var cap := Rect2(left + 2, top + 2, 9, 9)
	var pressed := _needs_hold and hold_ratio > 0.0
	draw_rect(cap, UiKit.AMBER if not pressed else Color.WHITE)
	draw_rect(Rect2(cap.position + Vector2(0, 8), Vector2(9, 1)), UiKit.AMBER_DIM)
	draw_string(UiKit.font_small, cap.position + Vector2(2, 7), "E", HORIZONTAL_ALIGNMENT_LEFT, -1, UiKit.SIZE_SMALL, UiKit.INK)
	UiKit.draw_text(self, Vector2(left + 15, top + 9), label, "small", UiKit.AMBER)
	if _needs_hold:
		# Progress bar under the plate; pulses gently while idle so it reads as "hold me".
		var bar := Rect2(left, top + 14, width, 3)
		draw_rect(bar, Color(UiKit.INK, 0.9))
		if hold_ratio > 0.0:
			draw_rect(Rect2(bar.position, Vector2(roundf(width * hold_ratio), 3)), UiKit.TEAL)
		else:
			var pulse := 0.35 + 0.25 * sin(_time * 5.0)
			draw_rect(Rect2(bar.position, Vector2(3, 3)), Color(UiKit.TEAL, pulse))
