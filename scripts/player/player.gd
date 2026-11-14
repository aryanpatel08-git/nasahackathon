extends CharacterBody2D
## The player's astronaut. Walks with WASD / arrows, talks with E.
## The node's origin is at the feet. The suit is tinted with GameState.suit_color.
##
## The existing frame rocks gently with distance travelled and mirrors when turning.

const SPEED := 112.0
const ACCELERATION := 1600.0
const DECELERATION := 1850.0
const REACH := 28.0

var _sprite: Sprite2D
var _prompt: Label
var _target: Node2D
var _walk_time: float = 0.0
var _dust: CPUParticles2D
var _last_step_sign: float = 1.0


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

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/art/characters/player_astronaut.png")
	_sprite.position = Vector2(0, -15)
	var mat := ShaderMaterial.new()
	mat.shader = load("res://assets/shaders/suit_tint.gdshader")
	mat.set_shader_parameter("suit_color", GameState.suit_color)
	_sprite.material = mat
	add_child(_sprite)

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
		_sprite.position = Vector2(0, -15)
		_sprite.rotation = 0.0
		return

	var dir := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	var rate := DECELERATION if dir.is_zero_approx() else ACCELERATION
	velocity = velocity.move_toward(dir * SPEED, rate * delta)
	move_and_slide()

	if get_real_velocity().length_squared() > 25.0:
		_walk_time += get_position_delta().length() / SPEED
		var step := sin(_walk_time * 14.0)
		_dust.emitting = true
		if signf(step) != _last_step_sign:
			_last_step_sign = signf(step)
			Sfx.play(&"step", randf_range(0.9, 1.15))
		_sprite.position = Vector2(roundf(step), -15 - roundf(absf(step)))
		_sprite.rotation = step * 0.045
		if dir.x != 0.0:
			_sprite.flip_h = dir.x < 0.0
	else:
		_dust.emitting = false
		_walk_time = 0.0
		_sprite.position = Vector2(0, -15)
		_sprite.rotation = 0.0

	_update_target()


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
