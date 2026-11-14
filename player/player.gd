class_name AstronautPlayer
extends CharacterBody2D
## Lunar Life astronaut with a full set of 32x32 pixel animations.
##
## Controls: A = left, D = right, W = away from camera, S = toward camera.
## Pressing A / D / W turns the astronaut first (about 0.2-0.3 s), then he walks.
## Releasing the key plays the turn backwards and returns him to the front idle.
## S needs no turn, because the sprite already faces the camera.
## A / D win over W / S when both are held.
##
## The node origin is the feet (bottom centre of the sprite).

@export var speed: float = 80.0
## Set to false for a side-scroller (ignores W / S).
@export var allow_vertical: bool = true

enum Facing { NONE, FRONT, RIGHT, LEFT, BACK }
enum State { IDLE, TURN_IN, WALK, TURN_OUT }

const ASSETS := "res://assets/astronaut/"
const FRAME_SIZE := 32
const FRAME_COUNT := 8
const WALK_FPS := 10.0

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

var state: State = State.IDLE
var pose: Facing = Facing.FRONT
var _timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	_register_keys()
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-FRAME_SIZE / 2.0, -FRAME_SIZE)
	sprite.sprite_frames = _build_frames()
	sprite.play("idle_front")


func _physics_process(delta: float) -> void:
	var dir := _read_dir()
	var want := _facing_for(dir)
	velocity = Vector2.ZERO

	match state:
		State.IDLE:
			if want != Facing.NONE:
				_begin(want)
		State.TURN_IN:
			if want != pose:
				if want == Facing.NONE:
					_begin_turn_out()
				else:
					_begin(want)
			else:
				_timer -= delta
				if _timer <= 0.0:
					_start_walk()
		State.WALK:
			if want == pose:
				velocity = dir.normalized() * speed
			elif want == Facing.NONE:
				_stop()
			else:
				_begin(want)
		State.TURN_OUT:
			if want != Facing.NONE:
				_begin(want)
			else:
				_timer -= delta
				if _timer <= 0.0:
					_go_idle()

	move_and_slide()


func _read_dir() -> Vector2:
	var y := Input.get_axis("move_up", "move_down") if allow_vertical else 0.0
	return Vector2(Input.get_axis("move_left", "move_right"), y)


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
	pose = want
	if want == Facing.FRONT:
		_start_walk()
	else:
		state = State.TURN_IN
		_timer = TURN_TIME[want]
		sprite.play(TURN_ANIM[want])


func _start_walk() -> void:
	state = State.WALK
	sprite.play("walk_" + NAMES[pose])


func _stop() -> void:
	if pose == Facing.FRONT:
		_go_idle()
	else:
		_begin_turn_out()


func _begin_turn_out() -> void:
	state = State.TURN_OUT
	_timer = TURN_TIME[pose]
	sprite.play_backwards(TURN_ANIM[pose])


func _go_idle() -> void:
	state = State.IDLE
	pose = Facing.FRONT
	sprite.play("idle_front")


# --- animation setup -------------------------------------------------------

func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

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
		frames.add_frame(anim, load(ASSETS + f))


func _add_strip(frames: SpriteFrames, anim: String, file: String) -> void:
	var strip: Texture2D = load(ASSETS + file)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, WALK_FPS)
	frames.set_animation_loop(anim, true)
	for i in FRAME_COUNT:
		var tex := AtlasTexture.new()
		tex.atlas = strip
		tex.region = Rect2(i * FRAME_SIZE, 0, FRAME_SIZE, FRAME_SIZE)
		frames.add_frame(anim, tex)


# --- input -----------------------------------------------------------------

## Adds A / D / W / S as actions if the project doesn't define them yet.
func _register_keys() -> void:
	_add_key("move_left", KEY_A)
	_add_key("move_right", KEY_D)
	_add_key("move_up", KEY_W)
	_add_key("move_down", KEY_S)


func _add_key(action: StringName, key: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
