class_name BlastDoor
extends Station
## The storm shelter's blast hatch: two heavy leaves that slide into the wall.
##
## It is too heavy to tap open: the player stands at it and HOLDS E (hold_seconds).
## Once open it stays open while the player is near or inside the shelter, then closes
## by itself. During a radiation alert the outpost calls seal(): the hatch closes behind
## the crew and locks until unlock().
##
## The node's origin sits on the doorway's base line, centred, so y-sorting draws the
## frame in front of anyone walking through and behind anyone standing south of it.

signal opened
signal sealed

enum State { CLOSED, OPENING, OPEN, CLOSING }

const OPEN_TIME := 0.55
const CLOSE_TIME := 0.4
const STAY_OPEN := 1.4          # seconds with nobody near before it closes again
const NEAR := 46.0

## Doorway floor in this node's parent's coordinates (world pixels).
var passage: Rect2
## The room behind the hatch; while the player is in it the hatch stays open.
var room: Rect2
var alert: bool = false
var state: State = State.CLOSED

var _amount: float = 0.0        # 0 = shut, 1 = fully open
var _locked: bool = false
var _sealing: bool = false
var _idle: float = 0.0
var _time: float = 0.0
var _leaves: Texture2D
var _frame: Texture2D
var _shape: CollisionShape2D
var _slot: Rect2


func _ready() -> void:
	prompt = "Open shelter hatch"
	hold_seconds = 1.0
	extra_reach = 14.0
	super()
	_leaves = load("res://assets/art/world/hatch_leaves.png")
	_frame = load("res://assets/art/world/hatch_frame.png")
	position = Vector2(passage.get_center().x, passage.end.y)

	var body := StaticBody2D.new()
	_shape = CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = passage.size
	_shape.shape = box
	_shape.position = Vector2(0, -passage.size.y / 2.0)
	body.add_child(_shape)
	add_child(body)


func is_open() -> bool:
	return state == State.OPEN


func is_locked() -> bool:
	return _locked


func open_amount() -> float:
	return _amount


## Called when the player has held E long enough.
func interact() -> void:
	if not enabled or _locked or state != State.CLOSED:
		return
	open()
	used.emit()


func open() -> void:
	if _locked or state == State.OPEN or state == State.OPENING:
		return
	state = State.OPENING
	_idle = 0.0
	Sfx.play(&"hatch_open")


## Close behind the crew and lock. Emits `sealed` when fully shut.
func seal() -> void:
	_locked = true
	_sealing = true
	if state == State.CLOSED:
		_finish_close()
	else:
		_begin_close()


func unlock() -> void:
	_locked = false


func _physics_process(delta: float) -> void:
	_time += delta
	match state:
		State.OPENING:
			_amount = minf(1.0, _amount + delta / OPEN_TIME)
			if _amount >= 0.7:
				_shape.set_deferred(&"disabled", true)
			if _amount >= 1.0:
				state = State.OPEN
				opened.emit()
		State.OPEN:
			if _player_near():
				_idle = 0.0
			else:
				_idle += delta
				if _idle >= STAY_OPEN:
					_begin_close()
		State.CLOSING:
			if _someone_in_doorway() and not _sealing:
				state = State.OPENING  # never squash the player
			else:
				_amount = maxf(0.0, _amount - delta / CLOSE_TIME)
				if _amount <= 0.3:
					_shape.set_deferred(&"disabled", false)
				if _amount <= 0.0:
					_finish_close()
	enabled = state == State.CLOSED and not _locked
	queue_redraw()


func _begin_close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return
	state = State.CLOSING
	Sfx.play(&"hatch_close")


func _finish_close() -> void:
	state = State.CLOSED
	_amount = 0.0
	_shape.set_deferred(&"disabled", false)
	if _sealing:
		_sealing = false
		Sfx.play(&"hatch_seal")
		sealed.emit()


func _player() -> Node2D:
	return get_tree().get_first_node_in_group(&"player") as Node2D


func _player_near() -> bool:
	var player := _player()
	if player == null:
		return false
	return room.has_point(player.position) or passage.grow(4.0).has_point(player.position) \
			or player.position.distance_to(position) < NEAR


func _someone_in_doorway() -> bool:
	var player := _player()
	return player != null and passage.grow_individual(2.0, 6.0, 2.0, 6.0).has_point(player.position)


func _draw() -> void:
	var w := passage.size.x
	var h := passage.size.y
	var half := w / 2.0
	var slide := roundf(_amount * (half - 2.0))
	# Leaves: only the part still inside the doorway is drawn; the rest is inside the wall.
	if slide < half:
		draw_texture_rect_region(_leaves, Rect2(-half, -h, half - slide, h), Rect2(slide, 0, half - slide, h))
		draw_texture_rect_region(_leaves, Rect2(slide, -h, half - slide, h), Rect2(half, 0, half - slide, h))
	# Frame in front of the leaves.
	var frame_size := _frame.get_size()
	var frame_at := Vector2(-frame_size.x / 2.0, -frame_size.y)
	draw_texture(_frame, frame_at)
	# Status strip in the lintel: teal = shut, green = open or sealed safe, amber flash = alert.
	var blink := int(_time * 4.0) % 2 == 0
	var strip := UiKit.TEAL_DIM
	if _locked:
		strip = UiKit.GREEN
	elif state != State.CLOSED:
		strip = UiKit.GREEN if blink or state == State.OPEN else UiKit.TEAL_DIM
	elif alert:
		strip = UiKit.AMBER if blink else UiKit.AMBER_DIM
	draw_rect(Rect2(frame_at + Vector2(frame_size.x / 2.0 - 13.0, 4.0), Vector2(26, 1)), strip)
	# Beacon on top of the frame.
	var beacon := frame_at + Vector2(frame_size.x / 2.0, -3.0)
	draw_rect(Rect2(beacon + Vector2(-4, 1), Vector2(8, 3)), Color("12142a"))
	var lit := alert and blink and not _locked
	draw_rect(Rect2(beacon + Vector2(-2, -3), Vector2(4, 4)), UiKit.AMBER if lit else UiKit.AMBER_DIM)
	draw_rect(Rect2(beacon + Vector2(-1, -4), Vector2(2, 1)), Color.WHITE if lit else UiKit.AMBER_DIM)
	if lit:
		for ray: Vector2 in [Vector2(-7, -2), Vector2(6, -2), Vector2(-5, -6), Vector2(4, -6), Vector2(0, -8)]:
			draw_rect(Rect2(beacon + ray, Vector2(1, 1)), UiKit.AMBER)
