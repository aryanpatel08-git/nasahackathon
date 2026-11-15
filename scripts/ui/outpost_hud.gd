extends CanvasLayer
## Outpost HUD: a small status strip (Sun, battery, clock), the radiation alert banner
## with its storm clock, and short "flash" messages. Reads the simulation; changes nothing.
##
## Screen map at 480 x 270 so nothing overlaps:
##   top-left   objective chip (objective_hud.gd)      top-right  minimap + pause button
##   top-centre alert banner (only during the storm)   bottom-left status strip
##   bottom     dialogue box (the strip hides while someone is talking)

var _canvas: Control
var _vignette: ColorRect
var _time: float = 0.0
var _flash_text: String = ""
var _flash_color: Color = Color.WHITE
var _flash_left: float = 0.0


func _ready() -> void:
	layer = 20
	_vignette = ColorRect.new()
	_vignette.color = Color(1.0, 0.55, 0.15, 0.0)
	_vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_hud)
	add_child(_canvas)


## A short message in the middle of the screen ("HATCH SEALED").
func flash(text: String, color: Color = UiKit.TEAL) -> void:
	_flash_text = text
	_flash_color = color
	_flash_left = 1.9


func _process(delta: float) -> void:
	_time += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	var alert := MissionDirector.stage == MissionDirector.Stage.ALERT
	_vignette.color.a = (0.05 + 0.045 * sin(_time * 5.0)) if alert else 0.0
	_canvas.queue_redraw()


func _draw_hud() -> void:
	var d := MissionDirector
	var busy := Dialogue.is_active or d.ui_open or SceneRouter.is_transitioning()
	if _flash_left > 0.0:
		_draw_flash()
	if busy:
		return
	_draw_status()
	if d.stage == d.Stage.ALERT or d.stage == d.Stage.SHELTERED:
		_draw_alert(d.stage == d.Stage.SHELTERED)


func _draw_status() -> void:
	var c := _canvas
	var illum := ResourceSim.illumination_at(ResourceSim.hour)
	var cells := ResourceSim.battery_cells()
	var total := ResourceSim.battery_cells_total()
	var sun_words := "Full sun" if illum >= 0.9 else ("Low sun" if illum > 0.0 else "Shadow")
	var hour_words := "Hour %d" % ResourceSim.hour
	var sun_w := UiKit.text_width(sun_words)
	var width := 14.0 + sun_w + 10.0 + total * 4.0 + 6.0 + 18.0 + 8.0 + UiKit.text_width(hour_words) + 6.0
	var box := Rect2(6, 251, width, 14)
	c.draw_rect(box, Color(UiKit.INK, 0.86))
	c.draw_rect(box, UiKit.LINE, false, 1.0)
	var x := box.position.x + 4.0
	var mid := box.position.y + 7.0
	# Sun: full disc with rays, half disc when low, hollow ring in shadow.
	var sun := Vector2(x + 4, mid)
	if illum >= 0.9:
		c.draw_rect(Rect2(sun - Vector2(2, 2), Vector2(5, 5)), UiKit.AMBER)
		for ray: Vector2 in [Vector2(0, -4), Vector2(0, 4), Vector2(-4, 0), Vector2(4, 0)]:
			c.draw_rect(Rect2(sun + ray, Vector2(1, 1)), UiKit.AMBER)
	elif illum > 0.0:
		c.draw_rect(Rect2(sun - Vector2(2, 0), Vector2(5, 3)), UiKit.AMBER_DIM)
		c.draw_rect(Rect2(sun - Vector2(4, -3), Vector2(9, 1)), UiKit.TEXT_DIM)
	else:
		c.draw_rect(Rect2(sun - Vector2(2, 2), Vector2(5, 5)), UiKit.LINE, false, 1.0)
	x += 12.0
	UiKit.draw_text(c, Vector2(x, mid + 3), sun_words, "small", UiKit.AMBER if illum > 0.0 else UiKit.TEXT_DIM)
	x += sun_w + 8.0
	# Battery: one block per cell. Amber when two or fewer are left.
	var low := cells <= 2
	c.draw_rect(Rect2(x - 1, mid - 4, total * 4.0 + 1, 8), UiKit.LINE, false, 1.0)
	c.draw_rect(Rect2(x + total * 4.0 + 1, mid - 2, 2, 4), UiKit.LINE)
	for i in total:
		var fill := UiKit.PANEL_HI
		if i < cells:
			fill = UiKit.AMBER if low else UiKit.TEAL
		c.draw_rect(Rect2(x + i * 4.0 + 1, mid - 2, 3, 5), fill)
	x += total * 4.0 + 6.0
	UiKit.draw_text(c, Vector2(x, mid + 3), "%d/%d" % [cells, total], "small", UiKit.AMBER if low else UiKit.TEXT)
	x += 22.0
	UiKit.draw_text(c, Vector2(x, mid + 3), hour_words, "small", UiKit.TEXT_DIM)


func _draw_alert(sheltered: bool) -> void:
	var c := _canvas
	var d := MissionDirector
	var box := Rect2(184, 6, 154, 28)
	var color := UiKit.GREEN if sheltered else UiKit.AMBER
	var blink := int(_time * 3.0) % 2 == 0
	c.draw_rect(box, Color(UiKit.INK, 0.9))
	c.draw_rect(box, color if (sheltered or blink) else UiKit.AMBER_DIM, false, 1.0)
	var title := "SHELTERED" if sheltered else "RADIATION ALERT"
	var title_w := UiKit.text_width(title, "title")
	var tx := box.position.x + (box.size.x - title_w - 14.0) / 2.0
	# Warning triangle (or a shield once safe) so the banner never relies on colour alone.
	var icon := Vector2(tx + 4, box.position.y + 8)
	if sheltered:
		c.draw_colored_polygon(PackedVector2Array([icon + Vector2(-4, -4), icon + Vector2(4, -4), icon + Vector2(4, 0), icon + Vector2(0, 5), icon + Vector2(-4, 0)]), color)
	else:
		c.draw_colored_polygon(PackedVector2Array([icon + Vector2(0, -5), icon + Vector2(5, 4), icon + Vector2(-5, 4)]), color)
		c.draw_rect(Rect2(icon + Vector2(-0.5, -2), Vector2(1, 3)), UiKit.INK)
		c.draw_rect(Rect2(icon + Vector2(-0.5, 2), Vector2(1, 1)), UiKit.INK)
	UiKit.draw_text(c, Vector2(tx + 13, box.position.y + 12), title, "title", color)
	# Storm clock: one pip per storm hour.
	var total := d.storm_hours_total()
	var pips_w := total * 7.0
	var words := "storm passing" if sheltered else "get to the shelter"
	var row_w := pips_w + 5.0 + UiKit.text_width(words)
	var px := box.position.x + (box.size.x - row_w) / 2.0
	var py := box.position.y + 18.0
	for i in total:
		var fill := UiKit.PANEL_HI
		if i < d.storm_hours_done:
			fill = UiKit.GREEN if sheltered and i >= d.hours_unsheltered else Color("ff6b5e")
		c.draw_rect(Rect2(px + i * 7.0, py, 5, 5), fill)
	UiKit.draw_text(c, Vector2(px + pips_w + 5.0, py + 6), words, "small", UiKit.TEXT)


func _draw_flash() -> void:
	var c := _canvas
	var alpha := clampf(_flash_left / 0.35, 0.0, 1.0) * clampf((1.9 - _flash_left) / 0.12, 0.0, 1.0)
	var w := UiKit.text_width(_flash_text, "title") + 22.0
	var box := Rect2(roundf((480.0 - w) / 2.0), 64, w, 20)
	c.draw_rect(box, Color(UiKit.INK, 0.9 * alpha))
	c.draw_rect(box, Color(_flash_color, alpha), false, 1.0)
	c.draw_rect(Rect2(box.position + Vector2(3, 3), Vector2(2, 14)), Color(_flash_color, alpha))
	UiKit.draw_text(c, box.position + Vector2(11, 14), _flash_text, "title", Color(_flash_color, alpha))
