class_name CrewMember
extends Station
## A crew mate who lives in the outpost: idles at a post, can be talked to, and walks a
## route when told to (for example to the shelter when the alert sounds).
## Crew don't block the player, so they can never jam a doorway.

var texture: Texture2D
var display_name: String = ""
var walk_speed: float = 95.0

var _sprite: Sprite2D
var _bubble: Label
var _path: PackedVector2Array = []
var _time: float = 0.0
var _bubble_left: float = 0.0


func _ready() -> void:
	super()
	prompt = "Talk"
	_time = randf() * 6.0

	_sprite = Sprite2D.new()
	_sprite.texture = texture
	_sprite.position = Vector2(0, -15)
	add_child(_sprite)

	var name_label := Label.new()
	name_label.text = display_name
	name_label.add_theme_font_size_override("font_size", 8)
	name_label.add_theme_color_override("font_shadow_color", Color("#0a1020"))
	name_label.add_theme_constant_override("shadow_offset_y", 1)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.position = Vector2(-50, -43)
	name_label.size = Vector2(100, 10)
	name_label.modulate = Color(1, 1, 1, 0.9)
	add_child(name_label)

	# Soft contact shadow.
	var shadow := Polygon2D.new()
	var oval := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		oval.append(Vector2(cos(a) * 8.0, sin(a) * 2.5))
	shadow.polygon = oval
	shadow.color = Color(0.02, 0.03, 0.08, 0.32)
	shadow.position = Vector2(0, -1)
	shadow.show_behind_parent = true
	add_child(shadow)
	move_child(shadow, 0)

	_bubble = Label.new()
	_bubble.add_theme_font_size_override("font_size", 8)
	_bubble.add_theme_color_override("font_shadow_color", Color("#18182a"))
	_bubble.add_theme_constant_override("shadow_offset_y", 1)
	_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.position = Vector2(-80, -55)
	_bubble.size = Vector2(160, 10)
	_bubble.modulate = Color(1.0, 0.82, 0.3)
	_bubble.z_index = 3
	_bubble.visible = false
	add_child(_bubble)


func _process(delta: float) -> void:
	_time += delta
	if _bubble_left > 0.0:
		_bubble_left -= delta
		_bubble.visible = _bubble_left > 0.0

	if _path.is_empty():
		# Idle: a small breathing bob.
		_sprite.position = Vector2(0, -15 - (1 if sin(_time * 2.4) > 0.5 else 0))
		_sprite.rotation = 0.0
		return

	var target := _path[0]
	var step := walk_speed * delta
	if position.distance_to(target) <= step:
		position = target
		_path.remove_at(0)
	else:
		var dir := (target - position).normalized()
		position += dir * step
		if absf(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0.0
	var swing := sin(_time * 14.0)
	_sprite.position = Vector2(roundf(swing), -15 - roundf(absf(swing)))
	_sprite.rotation = swing * 0.045


## Walk through these points in order (world pixels).
func walk(points: PackedVector2Array) -> void:
	_path = points


## Keep walking the current route, then continue through these points.
func walk_on(points: PackedVector2Array) -> void:
	_path.append_array(points)


func is_walking() -> bool:
	return not _path.is_empty()


## Show a short line above the head for a few seconds.
func say(text: String, seconds: float = 2.5) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_left = seconds
