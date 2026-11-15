extends Node
## Developer tool: jump straight to a place and save screenshots of it.
##   godot --path . res://tools/dev/peek.tscn -- scene=outpost at=240,212 stage=checks out=/tmp/peek
## Several spots:  at=240,212;138,192;378,194     (map units of that scene)

var _args: Dictionary = {"scene": "outpost", "at": "", "stage": "checks", "out": "/tmp/peek", "wait": "0.6"}


func _ready() -> void:
	if name != &"PeekDriver":
		var copy := Node.new()
		copy.name = "PeekDriver"
		copy.set_script(get_script())
		get_tree().root.add_child.call_deferred(copy)
		return
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			_args[kv[0]] = kv[1]
	_run.call_deferred()


func _shot(tag: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_%s.png" % [_args["out"], tag])


func _run() -> void:
	GameState.start_fresh_progress()
	GameState.player_name = "Kareem"
	GameState.suit_color = Color(0.95, 0.55, 0.2)
	for flag: StringName in [&"astronaut_created", &"intro_cinematic_seen", &"mentor_commander", &"outpost_arrival_seen"]:
		GameState.set_flag(flag)
	var D := MissionDirector
	D.start_new_game()
	D.finish_briefing()
	var scene: String = _args["scene"]
	if scene == "outpost":
		D.pass_training()
		D.begin_mission()
		if _args["stage"] == "alert":
			D.power_checked = true
			D.greenhouse_checked = true
			D.start_alert()
	get_tree().change_scene_to_file(SceneRouter.SCENES[StringName("academy_hub" if scene == "academy" else scene)])
	await get_tree().create_timer(1.0).timeout
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	var scale := 1.5 if scene == "outpost" else 1.6
	var spots: PackedStringArray = String(_args["at"]).split(";", false)
	if spots.is_empty():
		await _shot("0")
	for i in spots.size():
		var xy := spots[i].split(",")
		if player != null:
			player.position = Vector2(float(xy[0]), float(xy[1])) * scale
			var camera := get_viewport().get_camera_2d()
			if camera != null:
				camera.reset_smoothing()
		await get_tree().create_timer(float(_args["wait"])).timeout
		await _shot(str(i))
	get_tree().quit()
