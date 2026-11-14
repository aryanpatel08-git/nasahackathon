extends CharacterBody2D
## The player's astronaut. Walks with WASD / arrows, talks with E.
## The node's origin is at the feet. The suit is tinted with GameState.suit_color.
##
## Directional animations by Kareem Dahrouj (assets/art/characters/astronaut/):
##   A / D : turn to 3/4 view, then walk in true side profile (left / right)
##   W     : turn away from the camera, then walk showing the back
##   S     : walk toward the camera (no turn, the idle pose already faces front)
## Releasing the key plays the turn backwards, then returns to the front idle.
## A / D win over W / S when both are held.

const SPEED := 112.0
const ACCELERATION := 1600.0
const DECELERATION := 1850.0
const REACH := 28.0

const ART := "res://assets/art/characters/astronaut/"
const FRAME_SIZE := 32
const WALK_FRAMES := 8
const WALK_FPS := 10.0

enum Facing { NONE, FRONT, RIGHT, LEFT, BACK }
enum State { IDLE, TURN_IN, WALK, TURN_OUT }

const NAMES := {
	Facing.FRONT: "front",
	Facing.RIGHT: "right",
	Facing.LEFT: "left",
	Facing.BACK: "back",
}
const TURN_ANIM := {
	Facing.RIGHT: "turn_right",
	Facing.LEFT: "turn_left",
	Facing.BACK: "turn_away",
}
const TURN_TIME := {
	Facing.RIGHT: 0.2,
	Facing.LEFT: 0.2,
	Facing.BACK: 0.3,
}

var _sprite: AnimatedSprite2D
var _prompt: Label
var _target: Node2D
var _dust: CPUParticles2D
var _state: State = State.IDLE
var _pose: Facing = Facing.FRONT
var _turn_timer: float = 0.0
var _moving: bool = false


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
	_dust.color = Color(0.85, 0.85, 0.95, 0.45)
	_dust.position = Vector2(0, -1)
	_dust.show_behind_parent = true
	add_child(_dust)

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

	_prompt = Label.new()
	_prompt.add_theme_font_size_override("font_size", 8)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.position = Vector2(-50, -55)
	_prompt.z_index = 3
	_prompt.add_theme_color_override("font_shadow_color", Color("#18182a"))
	_prompt.add_theme_constant_override("shadow_offset_y", 1)
	_prompt.size = Vector2(100, 10)
	_prompt.modulate = Color(1.0, 0.82, 0.3)
	_prompt.visible = false
	add_child(_prompt)


func _physics_process(delta: float) -> void:
	if Dialogue.is_active or MissionDirector.ui_open or SceneRouter.is_transitioning():
		velocity = Vector2.ZERO
		_dust.emitting = false
		_prompt.visible = false
		_moving = false
		if _state != State.IDLE:
			_go_idle()
		return

	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var want := _facing_for(dir)

	match _state:
		State.IDLE:
			if want != Facing.NONE:
				_begin(want)
		State.TURN_IN:
			if want != _pose:
				if want == Facing.NONE:
					_begin_turn_out()
				else:
					_begin(want)
			else:
				_turn_timer -= delta
				if _turn_timer <= 0.0:
					_start_walk()
		State.WALK:
			if want == Facing.NONE:
				_stop()
			elif want != _pose:
				_begin(want)
		State.TURN_OUT:
			if want != Facing.NONE:
				_begin(want)
			else:
				_turn_timer -= delta
				if _turn_timer <= 0.0:
					_go_idle()

	# Only walk once the turn has finished; the turn itself happens on the spot.
	var walking := _state == State.WALK and want == _pose
	var goal := dir * SPEED if walking else Vector2.ZERO
	var rate := ACCELERATION if walking else DECELERATION
	velocity = velocity.move_toward(goal, rate * delta)
	move_and_slide()

	_moving = walking and get_real_velocity().length_squared() > 25.0
	_dust.emitting = _moving
	if _state == State.WALK:
		# Freeze the walk cycle while pushing against a wall.
		_sprite.speed_scale = 1.0 if _moving else 0.0

	_update_target()


func _facing_for(dir: Vector2) -> Facing:
	if dir.x > 0.0:
		return Facing.RIGHT
	if dir.x < 0.0:
		return Facing.LEFT
	if dir.y < 0.0:
		return Facing.BACK
	if dir.y > 0.0:
		return Facing.FRONT
	return Facing.NONE


func _begin(want: Facing) -> void:
	_pose = want
	if want == Facing.FRONT:
		_start_walk()
	else:
		_state = State.TURN_IN
		_turn_timer = TURN_TIME[want]
		_sprite.speed_scale = 1.0
		_sprite.play(TURN_ANIM[want])


func _start_walk() -> void:
	_state = State.WALK
	_sprite.speed_scale = 1.0
	_sprite.play("walk_" + NAMES[_pose])


func _stop() -> void:
	if _pose == Facing.FRONT:
		_go_idle()
	else:
		_begin_turn_out()


func _begin_turn_out() -> void:
	_state = State.TURN_OUT
	_turn_timer = TURN_TIME[_pose]
	_sprite.speed_scale = 1.0
	_sprite.play_backwards(TURN_ANIM[_pose])


func _go_idle() -> void:
	_state = State.IDLE
	_pose = Facing.FRONT
	_sprite.speed_scale = 1.0
	_sprite.play(&"idle_front")


func _on_frame_changed() -> void:
	# Frames 0 and 4 of the walk cycle are the foot contacts.
	if _state == State.WALK and _moving and _sprite.frame % 4 == 0:
		Sfx.play(&"step", randf_range(0.9, 1.15))


# --- animation setup ---------------------------------------------------------

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")
	for n in ["front", "right", "left", "back"]:
		_add_single(frames, "idle_" + n, ["astronaut_%s_idle.png" % n], 5.0, true)
		_add_strip(frames, "walk_" + n, "astronaut_walk_%s_strip_256x32.png" % n)
	_add_single(frames, "turn_right", ["astronaut_turn_right_1.png"], 5.0, false)
	_add_single(frames, "turn_left", ["astronaut_turn_left_1.png"], 5.0, false)
	_add_single(frames, "turn_away", [
		"astronaut_turn_away_1.png",
		"astronaut_turn_away_2.png",
		"astronaut_turn_away_3.png",
	], 10.0, false)
	return frames


func _add_single(frames: SpriteFrames, anim: String, files: Array, fps: float, loop: bool) -> void:
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	for f in files:
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
	if Dialogue.is_active or MissionDirector.ui_open or SceneRouter.is_transitioning() or _target == null:
		return
	if event.is_action_pressed(&"interact") and not event.is_echo() and is_instance_valid(_target):
		get_viewport().set_input_as_handled()
		_target.call(&"interact")


func _update_target() -> void:
	_target = null
	var best := REACH
	for node in get_tree().get_nodes_in_group(&"interactable"):
		var other := node as Node2D
		if other == null or other.get("enabled") == false:
			continue
		var d := global_position.distance_to(other.global_position)
		if d < best:
			best = d
			_target = other
	_prompt.visible = _target != null
	if _target != null:
		var what := "Use"
		if _target.has_method(&"prompt_text"):
			what = _target.call(&"prompt_text")
		_prompt.text = "E: %s" % what
