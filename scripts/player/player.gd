extends CharacterBody2D
## The player's astronaut. Walks with WASD / arrows, uses things with E.
## The node's origin is at the feet. The suit is tinted with GameState.suit_color.
##
## Movement never waits for an animation: the velocity follows the keys on every
## physics tick, and two keys held together move diagonally at the same speed.
##   - The astronaut faces the most recently pressed direction that is still held.
##   - A very short turn frame plays when leaving or returning to the front view.
##   - Letting go of the keys keeps the astronaut facing the way they walked.
## Directional animations by Kareem Dahrouj (assets/art/characters/astronaut/).
##
## Interaction: the nearest thing in the "interactable" group within REACH gets a
## prompt. Things with `hold_seconds > 0` (the shelter hatch) need E held down.

const SPEED := 112.0
const ACCELERATION := 1500.0
const DECELERATION := 2000.0
const REACH := 28.0

const ART := "res://assets/art/characters/astronaut/"
const FRAME_SIZE := 32
const WALK_FRAMES := 8
const WALK_FPS := 13.0
const TURN_TIME := 0.09

enum Facing { FRONT, RIGHT, LEFT, BACK }

const NAMES := {
	Facing.FRONT: "front",
	Facing.RIGHT: "right",
	Facing.LEFT: "left",
	Facing.BACK: "back",
}
const TURN_ANIM := {
	Facing.RIGHT: &"turn_right",
	Facing.LEFT: &"turn_left",
	Facing.BACK: &"turn_away",
}
## Input action, the view it shows, and the direction it pushes.
const MOVES: Array = [
	[&"move_down", Facing.FRONT, Vector2.DOWN],
	[&"move_right", Facing.RIGHT, Vector2.RIGHT],
	[&"move_left", Facing.LEFT, Vector2.LEFT],
	[&"move_up", Facing.BACK, Vector2.UP],
]

var _sprite: AnimatedSprite2D
var _prompt: Node2D
var _target: Node2D
var _dust: CPUParticles2D
var _facing: Facing = Facing.FRONT
var _turn_left: float = 0.0
var _moving: bool = false
var _press_order: Dictionary = {}   # action -> counter value when it went down (0 = up)
var _press_count: int = 0
var _hold: float = 0.0
var _hold_armed: bool = false
var _ui_was_open: bool = false


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(&"player")

	# Little puffs of dust at the feet while walking.
	_dust = CPUParticles2D.new()
	_dust.amount = 8
	_dust.lifetime = 0.4
	_dust.local_coords = false
	_dust.emitting = false
	_dust.direction = Vector2(0, -1)
	_dust.spread = 80.0
	_dust.gravity = Vector2.ZERO
	_dust.initial_velocity_min = 4.0
	_dust.initial_velocity_max = 12.0
	_dust.scale_amount_min = 1.0
	_dust.scale_amount_max = 2.0
	_dust.color = Color(0.85, 0.85, 0.95, 0.4)
	_dust.position = Vector2(0, -1)
	_dust.show_behind_parent = true
	add_child(_dust)

	# Soft contact shadow so the astronaut sits on the floor.
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

	_sprite = AnimatedSprite2D.new()
	_sprite.sprite_frames = _build_frames()
	_sprite.position = Vector2(0, -15)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/suit_tint.gdshader")
	mat.set_shader_parameter("suit_color", GameState.suit_color)
	_sprite.material = mat
	_sprite.frame_changed.connect(_on_frame_changed)
	add_child(_sprite)
	_sprite.play(&"idle_front")

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.5
	shape.shape = circle
	shape.position = Vector2(0, -4)
	add_child(shape)

	_prompt = Node2D.new()
	_prompt.set_script(load("res://scripts/ui/interact_prompt.gd"))
	_prompt.position = Vector2(0, -40)
	_prompt.z_index = 20
	add_child(_prompt)


func _physics_process(delta: float) -> void:
	var ui_open := Dialogue.is_active or MissionDirector.ui_open or SceneRouter.is_transitioning()
	if ui_open:
		velocity = Vector2.ZERO
		_dust.emitting = false
		_moving = false
		_turn_left = 0.0
		_hold = 0.0
		_hold_armed = false
		_ui_was_open = true
		_prompt.call(&"hide_prompt")
		_play("idle_" + NAMES[_facing])
		return

	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var goal := dir * SPEED
	var rate := ACCELERATION if dir != Vector2.ZERO else DECELERATION
	velocity = velocity.move_toward(goal, rate * delta)
	move_and_slide()

	var speed := get_real_velocity().length()
	_moving = dir != Vector2.ZERO and speed > 6.0
	_dust.emitting = _moving
	_animate(dir, speed, delta)

	_update_target()
	_update_hold(delta)
	_ui_was_open = false


# --- animation ---------------------------------------------------------------

## The view to show: the newest held key that still pushes the way we are going.
func _wanted_facing(dir: Vector2) -> int:
	var best := -1
	var newest := 0
	for move: Array in MOVES:
		var action: StringName = move[0]
		if Input.is_action_pressed(action):
			if int(_press_order.get(action, 0)) == 0:
				_press_count += 1
				_press_order[action] = _press_count
		else:
			_press_order[action] = 0
		var order: int = _press_order[action]
		if order > newest and dir.dot(move[2]) > 0.1:
			newest = order
			best = move[1]
	return best


func _animate(dir: Vector2, speed: float, delta: float) -> void:
	var want := _wanted_facing(dir)
	if want != -1 and want != _facing:
		_turn_to(want as Facing)
	if _turn_left > 0.0:
		_turn_left -= delta
		if _turn_left > 0.0:
			return
	if _moving:
		_play("walk_" + NAMES[_facing])
		_sprite.speed_scale = clampf(speed / SPEED, 0.5, 1.15)
	else:
		_play("idle_" + NAMES[_facing])


## Turn frames exist between the front view and each other view. Side-to-side and
## side-to-back changes cut straight over, which reads fine at walking speed.
func _turn_to(new_facing: Facing) -> void:
	var old := _facing
	_facing = new_facing
	_sprite.speed_scale = 1.0
	if old == Facing.FRONT:
		_sprite.play(TURN_ANIM[new_facing])
		_turn_left = TURN_TIME
	elif new_facing == Facing.FRONT:
		_sprite.play_backwards(TURN_ANIM[old])
		_turn_left = TURN_TIME
	else:
		_turn_left = 0.0


func _play(anim: String) -> void:
	if _sprite.animation != StringName(anim) or not _sprite.is_playing():
		_sprite.speed_scale = 1.0
		_sprite.play(anim)


## Turn to look at a point (used when a conversation starts).
func face_toward(point: Vector2) -> void:
	var d := point - global_position
	if absf(d.x) > absf(d.y):
		_facing = Facing.RIGHT if d.x > 0.0 else Facing.LEFT
	else:
		_facing = Facing.FRONT if d.y > 0.0 else Facing.BACK
	_turn_left = 0.0
	_play("idle_" + NAMES[_facing])


func _on_frame_changed() -> void:
	# Frames 0 and 4 of the walk cycle are the foot contacts.
	if _moving and String(_sprite.animation).begins_with("walk_") and _sprite.frame % 4 == 0:
		Sfx.play(&"step", randf_range(0.9, 1.15))


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for n: String in ["front", "right", "left", "back"]:
		_add_single(frames, "idle_" + n, ["astronaut_%s_idle.png" % n], 5.0, true)
		_add_strip(frames, "walk_" + n, "astronaut_walk_%s_strip_256x32.png" % n)
	_add_single(frames, "turn_right", ["astronaut_turn_right_1.png"], 5.0, false)
	_add_single(frames, "turn_left", ["astronaut_turn_left_1.png"], 5.0, false)
	# Three frames squeezed into TURN_TIME.
	_add_single(frames, "turn_away", [
		"astronaut_turn_away_1.png",
		"astronaut_turn_away_2.png",
		"astronaut_turn_away_3.png",
	], 3.0 / TURN_TIME, false)
	return frames


func _add_single(frames: SpriteFrames, anim: String, files: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for f: String in files:
		frames.add_frame(anim, load(ART + f))


func _add_strip(frames: SpriteFrames, anim: String, file: String) -> void:
	var strip: Texture2D = load(ART + file)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, WALK_FPS)
	frames.set_animation_loop(anim, true)
	for i in WALK_FRAMES:
		var tex := AtlasTexture.new()
		tex.atlas = strip
		tex.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim, tex)


# --- interaction -------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if Dialogue.is_active or MissionDirector.ui_open or SceneRouter.is_transitioning():
		return
	if not event.is_action_pressed(&"interact") or event.is_echo():
		return
	if not is_instance_valid(_target):
		return
	get_viewport().set_input_as_handled()
	if _hold_seconds(_target) > 0.0:
		_hold_armed = true  # a fresh press starts the hold; _update_hold() fills it
	else:
		face_toward(_target.global_position)
		_target.call(&"interact")


func _update_hold(delta: float) -> void:
	var need := _hold_seconds(_target)
	if need <= 0.0:
		_hold = 0.0
		_hold_armed = false
		return
	if not Input.is_action_pressed(&"interact"):
		_hold_armed = false
	# A key still held from closing a panel must not count: wait for a new press.
	if _hold_armed and not _ui_was_open:
		_hold += delta
		if _hold >= need:
			_hold = 0.0
			_hold_armed = false
			_target.call(&"interact")
	else:
		_hold = maxf(0.0, _hold - delta * 2.0)
	_prompt.set(&"hold_ratio", clampf(_hold / need, 0.0, 1.0))


func _hold_seconds(node: Node2D) -> float:
	if not is_instance_valid(node):
		return 0.0
	var value: Variant = node.get(&"hold_seconds")
	return float(value) if value != null else 0.0


func _update_target() -> void:
	_target = null
	var best := REACH
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var other := node as Node2D
		if other == null or other.get(&"enabled") == false:
			continue
		var reach_bonus: Variant = other.get(&"extra_reach")
		var d := global_position.distance_to(other.global_position) - (float(reach_bonus) if reach_bonus != null else 0.0)
		if d < best:
			best = d
			_target = other
	if _target == null:
		_prompt.call(&"hide_prompt")
		return
	var what := "Use"
	if _target.has_method(&"prompt_text"):
		what = _target.call(&"prompt_text")
	_prompt.call(&"show_prompt", what, _hold_seconds(_target) > 0.0)
