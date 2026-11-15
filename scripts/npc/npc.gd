class_name Npc
extends StaticBody2D
## A character who stands in place and talks. Give it an NPCData resource.
## The node's origin is at the character's feet (so y-sorting looks right).

@export var data: NPCData

var _sprite: Sprite2D
var _time: float = 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	add_to_group(&"objective_targets")
	if data == null:
		push_error("Npc '%s' has no NPCData" % name)
		return

	_time = randf() * 6.0
	# Soft contact shadow.
	var shadow := Polygon2D.new()
	var oval := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		oval.append(Vector2(cos(a) * 8.0, sin(a) * 2.5))
	shadow.polygon = oval
	shadow.color = Color(0.02, 0.03, 0.08, 0.32)
	shadow.position = Vector2(0, -1)
	add_child(shadow)

	_sprite = Sprite2D.new()
	_sprite.texture = data.sprite
	_sprite.position = Vector2(0, -15)
	add_child(_sprite)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	shape.position = Vector2(0, -4)
	add_child(shape)

	var label := Label.new()
	label.text = data.display_name
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override("font_shadow_color", Color("#0a1020"))
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -43)
	label.size = Vector2(100, 10)
	label.modulate = Color(1, 1, 1, 0.9)
	add_child(label)


func _process(delta: float) -> void:
	if _sprite == null:
		return
	_time += delta
	# Breathing bob.
	_sprite.position.y = -15 - (1 if sin(_time * 2.4) > 0.5 else 0)
	# Turn to face the player when they come close.
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player != null and global_position.distance_to(player.global_position) < 90.0:
		_sprite.flip_h = player.global_position.x < global_position.x - 4.0
	queue_redraw()


## A bouncing "!" until the player has talked to this mentor.
func _draw() -> void:
	if data == null or GameState.get_flag(StringName("mentor_" + String(data.id))):
		return
	var at := Vector2(0, -52 - roundf(absf(sin(_time * 4.0)) * 3.0))
	draw_rect(Rect2(at + Vector2(-3, -1), Vector2(6, 10)), Color("0a1020"))
	draw_rect(Rect2(at + Vector2(-1, 0), Vector2(2, 5)), UiKit.AMBER)
	draw_rect(Rect2(at + Vector2(-1, 6), Vector2(2, 2)), UiKit.AMBER)


func prompt_text() -> String:
	return "Talk"


func get_objective_id() -> StringName:
	if data == null:
		return &""
	return &"rivera" if data.id == &"engineer" else data.id


func interact() -> void:
	if data == null or Dialogue.is_active:
		return
	Dialogue.play(data.id, "%s, %s" % [data.display_name, data.role], data.lines)
	if data.opens_scene != &"":
		await EventBus.dialogue_ended
		SceneRouter.go_to(data.opens_scene)
