extends Node
## UiKit — the shared look of the game (autoload, loaded first).
##
## One palette, three pixel fonts and one Theme for every panel, button and label.
## The Theme is the project theme (project.godot -> gui/theme/custom). It is an empty
## resource on disk and is filled in here, in code, so the whole look lives in one file.
##
## Fonts: Galmuri by Lee Minseo (SIL Open Font License 1.1), subset to Latin glyphs.
## Pixel fonts are only crisp at their own size, so always pair them like this:
##   font_small @ 8     font_body @ 10     font_title @ 12  (or 24, 36 for big titles)

# --- Palette (art direction: indigo / steel base, teal = powered, amber = caution) ---
const INK := Color("0a1020")
const PANEL := Color("111a33")
const PANEL_HI := Color("1b2748")
const LINE := Color("33457a")
const TEXT := Color("e8eeff")
const TEXT_DIM := Color("93a2c8")
const TEAL := Color("5fe3d3")
const TEAL_DIM := Color("2c8f92")
const AMBER := Color("ffc45e")
const AMBER_DIM := Color("b27a36")
const GREEN := Color("77dd77")
const RED := Color("ff6b5e")
const VIOLET := Color("b79dff")

const SIZE_SMALL := 8
const SIZE_BODY := 10
const SIZE_TITLE := 12

const FONT_DIR := "res://assets/fonts/"

var font_small: FontFile
var font_body: FontFile
var font_title: FontFile
var theme: Theme


func _enter_tree() -> void:
	font_small = _pixel_font("Galmuri7-Latin.ttf")
	font_body = _pixel_font("Galmuri9-Latin.ttf")
	font_title = _pixel_font("Galmuri11-Bold-Latin.ttf")
	theme = ThemeDB.get_project_theme()
	if theme == null:
		# Safety net if the project setting is missing: still style direct children of the window.
		theme = Theme.new()
		get_tree().root.theme = theme
	_fill_theme()


# ---------------------------------------------------------------- helpers for scripts

## A Label in one of the three text styles: "small", "body" or "title".
func label(text: String, kind: String = "body", color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	style_label(l, kind, color)
	return l


func style_label(l: Label, kind: String = "body", color: Color = TEXT) -> void:
	l.add_theme_font_override("font", font_for(kind))
	l.add_theme_font_size_override("font_size", size_for(kind))
	l.add_theme_color_override("font_color", color)


func font_for(kind: String) -> FontFile:
	match kind:
		"small": return font_small
		"title": return font_title
		_: return font_body


func size_for(kind: String) -> int:
	match kind:
		"small": return SIZE_SMALL
		"title": return SIZE_TITLE
		_: return SIZE_BODY


## The standard dark panel with a one-pixel coloured frame.
func panel_box(border: Color = TEAL, fill: Color = PANEL, margin: int = 6) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(margin)
	box.shadow_color = Color(0, 0, 0, 0.45)
	box.shadow_size = 2
	box.shadow_offset = Vector2(0, 2)
	box.anti_aliasing = false
	return box


## A flat box without a shadow (HUD chips, key caps, rows).
func flat_box(fill: Color, border: Color = Color.TRANSPARENT, margin: int = 3) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(0 if border.a == 0.0 else 1)
	box.set_content_margin_all(margin)
	box.anti_aliasing = false
	return box


## Draws text with a one-pixel drop shadow from a CanvasItem's _draw().
func draw_text(item: CanvasItem, at: Vector2, text: String, kind: String = "small", color: Color = TEXT,
		width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := font_for(kind)
	var s := size_for(kind)
	item.draw_string(f, at + Vector2(0, 1), text, align, width, s, Color(0.02, 0.03, 0.08, color.a * 0.85))
	item.draw_string(f, at, text, align, width, s, color)


func text_width(text: String, kind: String = "small") -> float:
	return font_for(kind).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_for(kind)).x


# ---------------------------------------------------------------- theme

func _pixel_font(file: String) -> FontFile:
	var font := load(FONT_DIR + file) as FontFile
	if font == null:
		push_error("UiKit: missing font %s" % file)
		return FontFile.new()
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.force_autohinter = false
	font.generate_mipmaps = false
	return font


func _fill_theme() -> void:
	var t := theme
	t.default_font = font_small
	t.default_font_size = SIZE_SMALL

	# Labels
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_constant(&"line_spacing", &"Label", 2)
	for variation: Array in [[&"BodyLabel", font_body, SIZE_BODY, TEXT], [&"TitleLabel", font_title, SIZE_TITLE, AMBER],
			[&"DimLabel", font_small, SIZE_SMALL, TEXT_DIM]]:
		t.set_type_variation(variation[0], &"Label")
		t.set_font(&"font", variation[0], variation[1])
		t.set_font_size(&"font_size", variation[0], variation[2])
		t.set_color(&"font_color", variation[0], variation[3])

	# Panels
	t.set_stylebox(&"panel", &"PanelContainer", panel_box())
	t.set_stylebox(&"panel", &"Panel", panel_box())
	var tip := panel_box(AMBER_DIM, INK, 4)
	t.set_stylebox(&"panel", &"TooltipPanel", tip)
	t.set_font(&"font", &"TooltipLabel", font_small)
	t.set_font_size(&"font_size", &"TooltipLabel", SIZE_SMALL)
	t.set_color(&"font_color", &"TooltipLabel", TEXT)

	# Buttons (also the base of OptionButton and CheckButton)
	for type: StringName in [&"Button", &"OptionButton"]:
		t.set_font(&"font", type, font_body)
		t.set_font_size(&"font_size", type, SIZE_BODY)
		t.set_color(&"font_color", type, TEXT)
		t.set_color(&"font_hover_color", type, Color.WHITE)
		t.set_color(&"font_pressed_color", type, INK)
		t.set_color(&"font_hover_pressed_color", type, INK)
		t.set_color(&"font_focus_color", type, Color.WHITE)
		t.set_color(&"font_disabled_color", type, TEXT_DIM.darkened(0.25))
		t.set_stylebox(&"normal", type, _button_box(PANEL_HI, LINE))
		t.set_stylebox(&"hover", type, _button_box(PANEL_HI.lightened(0.1), TEAL_DIM))
		t.set_stylebox(&"pressed", type, _button_box(TEAL, TEAL))
		t.set_stylebox(&"hover_pressed", type, _button_box(TEAL, TEAL))
		t.set_stylebox(&"disabled", type, _button_box(PANEL, LINE.darkened(0.3)))
		var focus := _button_box(Color.TRANSPARENT, TEAL)
		focus.draw_center = false
		t.set_stylebox(&"focus", type, focus)
		t.set_constant(&"h_separation", type, 4)
	t.set_icon(&"arrow", &"OptionButton", _arrow_icon())
	t.set_constant(&"arrow_margin", &"OptionButton", 4)

	# Toggles
	t.set_font(&"font", &"CheckButton", font_small)
	t.set_font_size(&"font_size", &"CheckButton", SIZE_SMALL)
	t.set_color(&"font_color", &"CheckButton", TEXT)
	t.set_color(&"font_hover_color", &"CheckButton", Color.WHITE)
	t.set_color(&"font_pressed_color", &"CheckButton", TEXT)
	t.set_color(&"font_hover_pressed_color", &"CheckButton", Color.WHITE)
	t.set_color(&"font_focus_color", &"CheckButton", Color.WHITE)
	t.set_color(&"font_disabled_color", &"CheckButton", TEXT_DIM)
	var row := flat_box(Color.TRANSPARENT, Color.TRANSPARENT, 2)
	var row_hover := flat_box(PANEL_HI, Color.TRANSPARENT, 2)
	for state: StringName in [&"normal", &"pressed", &"disabled", &"focus"]:
		t.set_stylebox(state, &"CheckButton", row)
	for state: StringName in [&"hover", &"hover_pressed"]:
		t.set_stylebox(state, &"CheckButton", row_hover)
	t.set_constant(&"h_separation", &"CheckButton", 6)
	var on := _toggle_icon(true, false)
	var off := _toggle_icon(false, false)
	var on_locked := _toggle_icon(true, true)
	var off_locked := _toggle_icon(false, true)
	for suffix: String in ["", "_mirrored"]:
		t.set_icon(StringName("checked" + suffix), &"CheckButton", on)
		t.set_icon(StringName("unchecked" + suffix), &"CheckButton", off)
		t.set_icon(StringName("checked_disabled" + suffix), &"CheckButton", on_locked)
		t.set_icon(StringName("unchecked_disabled" + suffix), &"CheckButton", off_locked)

	# Popup lists (dropdown of OptionButton)
	t.set_stylebox(&"panel", &"PopupMenu", panel_box(TEAL_DIM, INK, 3))
	t.set_stylebox(&"hover", &"PopupMenu", flat_box(PANEL_HI))
	t.set_font(&"font", &"PopupMenu", font_small)
	t.set_font_size(&"font_size", &"PopupMenu", SIZE_SMALL)
	t.set_color(&"font_color", &"PopupMenu", TEXT)
	t.set_color(&"font_hover_color", &"PopupMenu", Color.WHITE)
	t.set_constant(&"v_separation", &"PopupMenu", 3)

	# Text entry
	t.set_font(&"font", &"LineEdit", font_body)
	t.set_font_size(&"font_size", &"LineEdit", SIZE_BODY)
	t.set_color(&"font_color", &"LineEdit", TEXT)
	t.set_color(&"font_placeholder_color", &"LineEdit", TEXT_DIM.darkened(0.2))
	t.set_color(&"caret_color", &"LineEdit", TEAL)
	t.set_color(&"selection_color", &"LineEdit", TEAL_DIM)
	t.set_stylebox(&"normal", &"LineEdit", _button_box(INK, LINE))
	t.set_stylebox(&"focus", &"LineEdit", _button_box(INK, TEAL))
	t.set_stylebox(&"read_only", &"LineEdit", _button_box(INK, LINE.darkened(0.3)))

	# Meters
	var track := flat_box(INK, LINE, 0)
	var fill := flat_box(TEAL, Color.TRANSPARENT, 0)
	fill.border_color = INK
	fill.set_border_width_all(1)
	t.set_stylebox(&"background", &"ProgressBar", track)
	t.set_stylebox(&"fill", &"ProgressBar", fill)
	t.set_font(&"font", &"ProgressBar", font_small)
	t.set_font_size(&"font_size", &"ProgressBar", SIZE_SMALL)

	# Scroll bars: thin, no arrows.
	for bar: StringName in [&"VScrollBar", &"HScrollBar"]:
		t.set_stylebox(&"scroll", bar, flat_box(INK, Color.TRANSPARENT, 2))
		t.set_stylebox(&"scroll_focus", bar, flat_box(INK, Color.TRANSPARENT, 2))
		t.set_stylebox(&"grabber", bar, flat_box(LINE, Color.TRANSPARENT, 2))
		t.set_stylebox(&"grabber_highlight", bar, flat_box(TEAL_DIM, Color.TRANSPARENT, 2))
		t.set_stylebox(&"grabber_pressed", bar, flat_box(TEAL, Color.TRANSPARENT, 2))

	var rule := StyleBoxLine.new()
	rule.color = LINE
	rule.thickness = 1
	t.set_stylebox(&"separator", &"HSeparator", rule)
	t.set_constant(&"separation", &"HSeparator", 5)


func _button_box(fill: Color, border: Color) -> StyleBoxFlat:
	var box := flat_box(fill, border, 0)
	box.content_margin_left = 7
	box.content_margin_right = 7
	box.content_margin_top = 3
	box.content_margin_bottom = 3
	return box


## A pixel-art switch: a dark track with a knob on the left (off) or right (on).
func _toggle_icon(on: bool, locked: bool) -> ImageTexture:
	var img := Image.create(18, 10, false, Image.FORMAT_RGBA8)
	var track := TEAL_DIM if on else Color("1a2440")
	var edge := TEAL if on else LINE
	var knob := Color.WHITE if on else TEXT_DIM
	if locked:
		track = track.darkened(0.25)
		edge = edge.darkened(0.25)
		knob = AMBER
	img.fill_rect(Rect2i(1, 1, 16, 8), edge)
	img.fill_rect(Rect2i(2, 2, 14, 6), track)
	for corner: Vector2i in [Vector2i(1, 1), Vector2i(16, 1), Vector2i(1, 8), Vector2i(16, 8)]:
		img.set_pixelv(corner, Color.TRANSPARENT)
	img.fill_rect(Rect2i(10 if on else 3, 3, 5, 4), knob)
	return ImageTexture.create_from_image(img)


func _arrow_icon() -> ImageTexture:
	var img := Image.create(7, 4, false, Image.FORMAT_RGBA8)
	for row in 4:
		img.fill_rect(Rect2i(row, row, 7 - row * 2, 1), TEAL)
	return ImageTexture.create_from_image(img)
