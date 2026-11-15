extends Node
## Developer check for movement feel: time from key press to motion, diagonals, facing.

func _ready() -> void:
	if name != &"MoveDriver":
		# Run from a copy that sits beside the scene, so changing scenes does not free it.
		var copy := Node.new()
		copy.name = "MoveDriver"
		copy.set_script(get_script())
		get_tree().root.add_child.call_deferred(copy)
		return
	_run.call_deferred()

func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group(&"player") as CharacterBody2D

func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame

func _run() -> void:
	GameState.start_fresh_progress()
	GameState.set_flag(&"intro_cinematic_seen")
	MissionDirector.start_new_game()
	MissionDirector.finish_briefing()
	MissionDirector.stage = MissionDirector.Stage.TRAINING
	get_tree().change_scene_to_file("res://scenes/academy/academy_hub.tscn")
	await get_tree().create_timer(0.5).timeout
	var p := _player()
	var sprite := p.get("_sprite") as AnimatedSprite2D
	var start := p.global_position
	# 1. Press W: how many physics frames until the astronaut has moved?
	Input.action_press(&"move_up")
	var frames_to_move := 0
	while p.global_position.distance_to(start) < 1.0 and frames_to_move < 120:
		await get_tree().physics_frame
		frames_to_move += 1
	print("frames until moving after W: ", frames_to_move, "  anim=", sprite.animation)
	await _frames(20)
	print("after 20 more frames: vel=", p.velocity.round(), " anim=", sprite.animation)
	# 2. Add D while holding W: diagonal immediately?
	var before := p.global_position
	Input.action_press(&"move_right")
	await _frames(6)
	var d := p.global_position - before
	print("6 frames after adding D: delta=", d.round(), " vel=", p.velocity.round(), " anim=", sprite.animation)
	await _frames(20)
	print("diagonal speed=", snappedf(p.velocity.length(), 0.1), " (straight speed is 112)  anim=", sprite.animation)
	# 3. Release D: keeps going up without stopping?
	Input.action_release(&"move_right")
	var slowest := 999.0
	for i in 20:
		await get_tree().physics_frame
		slowest = minf(slowest, p.velocity.length())
	print("slowest speed in 20 frames after releasing D: ", snappedf(slowest, 0.1), " anim=", sprite.animation)
	Input.action_release(&"move_up")
	await _frames(20)
	print("stopped: vel=", p.velocity.round(), " anim=", sprite.animation)
	get_tree().quit()
