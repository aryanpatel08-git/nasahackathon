extends Node

var _args: Dictionary = {"rover": 0, "choice": 2, "late": 0, "speed": 3}
var _shots: bool = false
var _fails: int = 0
var _tag: String = ""
const ACADEMY_SCALE := 1.6
const OUTPOST_SCALE := 1.5


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2:
			_args[kv[0]] = int(kv[1])
	_shots = DisplayServer.get_name() != "headless"
	_tag = "r%d_c%d_l%d" % [_args["rover"], _args["choice"], _args["late"]]
	Engine.time_scale = float(_args["speed"])
	_run.call_deferred()


func _check(ok: bool, what: String) -> void:
	if ok:
		print("  ok    ", what)
	else:
		_fails += 1
		print("  FAIL  ", what)


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


func _shot(shot_name: String) -> void:
	if not _shots:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path("res://tools/shots/%s_%s.png" % [_tag, shot_name]))


func _burst(prefix: String, frames: int, gap: float) -> void:
	if not _shots:
		return
	for i in frames:
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(ProjectSettings.globalize_path("res://tools/shots/clip_%s_%02d.png" % [prefix, i]))
		await _wait(gap)


func _press(action: StringName) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await get_tree().process_frame
	await get_tree().process_frame
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame
	await get_tree().process_frame


func _player() -> CharacterBody2D:
	var actors := get_tree().current_scene.find_child("Actors", true, false)
	for n in actors.get_children():
		if n is CharacterBody2D:
			return n
	return null


func _walk(points: Array) -> void:
	var p := _player()
	for target: Vector2 in points:
		target *= ACADEMY_SCALE if get_tree().current_scene.name == "AcademyHub" else OUTPOST_SCALE
		var t := 0.0
		while p.global_position.distance_to(target) > 3.0 and t < 12.0:
			var d := target - p.global_position
			for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
				Input.action_release(a)
			if d.x < -1.5:
				Input.action_press(&"move_left")
			elif d.x > 1.5:
				Input.action_press(&"move_right")
			if d.y < -1.5:
				Input.action_press(&"move_up")
			elif d.y > 1.5:
				Input.action_press(&"move_down")
			await get_tree().physics_frame
			t += get_physics_process_delta_time()
		for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
			Input.action_release(a)
		_check(p.global_position.distance_to(target) <= 3.0, "walked to %s (at %s)" % [target, p.global_position.round()])


func _talk_through(max_lines: int = 40) -> void:
	var n := 0
	while Dialogue.is_active and n < max_lines:
		await _press(&"interact")
		await _wait(0.1)
		n += 1


func _panel() -> ChoicePanel:
	for n in get_tree().current_scene.get_children():
		if n is ChoicePanel and not n.is_queued_for_deletion():
			return n
	return null


func _click(root: Node, text_start: String) -> bool:
	for b: Button in root.find_children("*", "Button", true, false):
		if b.text.begins_with(text_start) and b.is_visible_in_tree():
			b.pressed.emit()
			return true
	return false


func _choose(index: int) -> void:
	var panel := _panel()
	_check(panel != null, "a panel is open")
	if panel == null:
		return
	var buttons := panel.find_children("*", "Button", true, false)
	(buttons[index] as Button).pressed.emit()
	await _wait(0.2)


func _run() -> void:
	var D := MissionDirector
	print("PLAYTEST ", _tag)
	get_tree().change_scene_to_file("res://scenes/ui/create_astronaut.tscn")
	await _wait(0.6)
	await _shot("01_create")
	var create := get_tree().current_scene
	(create.get("_name_edit") as LineEdit).text = "Tester"
	create.call("_set_color", Color(0.35, 0.6, 0.95))
	create.call("_start")
	await _wait(1.5)

	print("[academy]")
	_check(get_tree().current_scene.name == "AcademyHub", "academy loaded")
	_check(Dialogue.is_active and D.stage == D.Stage.BRIEFING, "briefing plays before control")
	await _shot("02_briefing")
	await _talk_through()
	_check(D.stage == D.Stage.TRAINING, "briefing done -> TRAINING")
	await _press(&"interact")
	_check(not Dialogue.is_active and not D.ui_open, "E far from everything does nothing")

	await _walk([Vector2(240, 172), Vector2(240, 90), Vector2(424, 88)])
	await _press(&"interact")
	_check(Dialogue.is_active and get_tree().current_scene.name == "AcademyHub", "hatch is locked before certification")
	await _talk_through()

	_burst("walk", 24, 0.05)
	await _walk([Vector2(346, 90), Vector2(360, 152)])
	await _shot("03_academy_room")
	await _press(&"interact")
	_check(Dialogue.is_active, "Rivera talks")
	await _talk_through()
	await _wait(0.3)
	var console := get_tree().current_scene.find_child("PowerConsole", true, false)
	_check(console != null and D.ui_open, "training console opened as a panel")
	await _shot("04_training_ready")
	_click(console, "Fast")
	var t := 0.0
	while console.get("_state") == "running" and t < 30.0:
		await _wait(0.2)
		t += 0.2
	_check(console.get("_state") == "failed", "all loads on -> training fails (state %s)" % console.get("_state"))
	_check(not D.can_graduate(), "no certificate after a fail")
	await _shot("05_training_fail")
	_click(console, "Retry")
	await _wait(0.2)
	_check(ResourceSim.hour == 0 and ResourceSim.battery == D.TRAINING_START_BATTERY, "retry resets the training")
	for cb: CheckButton in console.find_children("*", "CheckButton", true, false):
		if cb.text.contains("Rover"):
			cb.button_pressed = false
	_check(not ResourceSim.is_powered(&"rover"), "rover switch postponed")
	_click(console, "Fast")
	t = 0.0
	while console.get("_state") == "running" and t < 30.0:
		await _wait(0.2)
		t += 0.2
	_check(console.get("_state") == "passed", "rover postponed -> training passes (state %s)" % console.get("_state"))
	_check(D.can_graduate() and D.stage == D.Stage.GRADUATED, "certificate earned -> GRADUATED")
	await _shot("06_training_pass")
	await _press(&"ui_cancel")
	await _wait(0.3)
	_check(not D.ui_open and get_tree().current_scene.find_child("PowerConsole", true, false) == null, "Esc closes the panel")
	_check(_player().global_position.distance_to(Vector2(360, 152) * ACADEMY_SCALE) < 6.0, "player is back at the same position")

	await _walk([Vector2(346, 90), Vector2(424, 88)])
	await _press(&"interact")
	await _wait(1.5)

	print("[outpost]")
	_check(get_tree().current_scene.name == "Outpost" and D.stage == D.Stage.CHECKS, "outpost loaded -> CHECKS")
	await _shot("07_outpost")
	await _press(&"interact")
	_check(not D.ui_open and not Dialogue.is_active, "E far from stations does nothing")
	var p := _player()
	Input.action_press(&"move_left")
	await _wait(1.5)
	Input.action_release(&"move_left")
	_check(p.global_position.x > 204.0 * OUTPOST_SCALE, "corridor wall blocks walking west at the entrance (x=%d)" % int(p.global_position.x))
	Input.action_press(&"move_down")
	await _wait(1.0)
	Input.action_release(&"move_down")
	_check(p.global_position.y < 252.0 * OUTPOST_SCALE, "bottom wall blocks (y=%d)" % int(p.global_position.y))

	await _walk([Vector2(240, 180), Vector2(150, 180), Vector2(138, 164)])
	await _press(&"interact")
	await _wait(0.2)
	_check(D.ui_open, "power panel opens next to the station")
	await _shot("08_power_panel")
	await _choose(1 if _args["rover"] == 1 else 0)
	_check(D.power_checked and ResourceSim.is_powered(&"rover") == (_args["rover"] == 1), "power check done, rover policy applied")
	_check(D.stage == D.Stage.CHECKS, "one check does not start the alert")

	await _walk([Vector2(150, 180), Vector2(240, 180), Vector2(240, 237)])
	await _press(&"interact")
	await _wait(1.0)
	_check(get_tree().current_scene.name == "AcademyHub", "south hatch returns to the academy")
	_check(D.power_checked and D.can_graduate() and ResourceSim.hour == 4, "academy return preserves mission and certificate")
	await _walk([Vector2(424, 88)])
	await _press(&"interact")
	await _wait(1.0)
	_check(get_tree().current_scene.name == "Outpost" and D.power_checked, "academy hatch resumes the outpost")
	await _walk([Vector2(240, 180)])

	await _walk([Vector2(150, 180), Vector2(378, 180), Vector2(378, 162)])
	await _shot("09_greenhouse")
	await _press(&"interact")
	await _wait(0.2)
	await _choose(0)
	_check(D.greenhouse_checked, "crop check done")
	await _wait(0.8)
	_check(Dialogue.is_active and D.stage == D.Stage.CHECKS, "shift message shows")
	if Dialogue.is_revealing():
		await _press(&"interact")
	await _press(&"interact")
	await _wait(0.3)
	_check(D.stage == D.Stage.ALERT and Dialogue.is_active, "alert started, Mission Control speaks")
	_check(ResourceSim.hour == 10 and ResourceSim.sep_active, "alert begins at hour 10 with the SEP active (hour %d)" % ResourceSim.hour)
	await _shot("10_alert_dialogue")
	var hours_before := D.storm_hours_done
	await _wait(3.0)
	_check(D.storm_hours_done == hours_before, "storm clock is stopped while the dialogue is open")
	await _talk_through()
	await _press(&"ui_cancel")
	_check(get_tree().paused, "Escape pauses the game")
	var paused_at := _player().position
	var paused_hour := ResourceSim.hour
	Input.action_press(&"move_left")
	await _wait(4.5)
	Input.action_release(&"move_left")
	_check(_player().position == paused_at and ResourceSim.hour == paused_hour, "pause freezes movement and storm clock")
	await _press(&"ui_down")
	await _press(&"ui_down")
	await _press(&"ui_accept")
	_check(PauseMenu.get("_page") == "tasks", "Down and Enter open the task log")
	_check(TaskLog.entries().any(func(task: Dictionary) -> bool: return task.title == "Check outpost power" and task.done), "task log records completed outpost check")
	await _shot("16_tasks")
	await _press(&"ui_cancel")
	_check(get_tree().paused and PauseMenu.get("_page") == "home", "Escape returns from Tasks")
	_check(_click(PauseMenu, "Help"), "help opens from the pause menu")
	await _press(&"ui_cancel")
	_check(_click(PauseMenu, "Quit Game") and PauseMenu.get("_page") == "quit", "quit requires confirmation")
	_check(_click(PauseMenu, "Cancel") and get_tree().paused, "cancel quit stays paused")
	await _press(&"ui_cancel")
	_check(not get_tree().paused, "Escape resumes the mission")
	D.start_alert()
	_check(D.stage == D.Stage.ALERT and ResourceSim.hour <= 11, "a second start_alert does nothing")
	await _wait(0.5)
	await _shot("11_alert_route")
	if _args["late"] > 0:
		await _wait(float(_args["late"]))

	_burst("alert", 60, 0.1)  # frames for a short clip of the run to the shelter
	await _walk([Vector2(378, 180), Vector2(240, 180), Vector2(240, 58)])
	await _press(&"interact")
	await _wait(0.2)
	_check(D.ui_open and D.stage == D.Stage.ALERT, "shelter panel opens inside the shelter")
	await _shot("12_shelter_panel")
	var outside := D.hours_unsheltered
	await _choose(int(_args["choice"]))
	_check(D.stage == D.Stage.SHELTERED and ResourceSim.crew_sheltered, "sheltered")
	D.confirm_shelter(0)
	_check(D.shelter_choice == int(_args["choice"]), "a second confirm does nothing")
	t = 0.0
	while D.stage != D.Stage.DEBRIEF and t < 20.0:
		await _wait(0.2)
		t += 0.2
	await _wait(0.4)
	_check(D.stage == D.Stage.DEBRIEF and _panel() != null, "debrief opens")
	_check(D.hours_unsheltered == outside and D.storm_hours_done == D.storm_hours_total(), "storm ran its full %d hours" % D.storm_hours_total())
	await _shot("13_debrief")
	print("RESULT %s: outside=%dh exposure=%.1f batt_min=%.1f ls=%d/%d shutoffs=%d crops=%d science=%d" % [
		_tag, D.hours_unsheltered, ResourceSim.exposure_log, ResourceSim.battery_min,
		ResourceSim.life_support_ok_hours, ResourceSim.hours_run, ResourceSim.emergency_shutoffs,
		int(ResourceSim.crop_health), ResourceSim.science_points])
	await _choose(1)
	await _shot("14_sources")
	await _choose(0)
	_check(_panel() != null, "back to debrief")
	await _choose(0)
	await _wait(1.6)
	_check(D.stage == D.Stage.CHECKS and not D.power_checked and D.storm_hours_done == 0, "retry resets the mission")
	_check(ResourceSim.hour == 4 and ResourceSim.battery == 20.0 and ResourceSim.exposure_log == 0.0 and not ResourceSim.sep_active, "retry resets the simulation")
	_check(GameState.player_name == "Tester" and D.can_graduate(), "retry keeps the astronaut profile")
	_check(not D.ui_open and _player() != null, "player is in control again")
	await _shot("15_after_retry")

	print("PLAYTEST %s: %s" % [_tag, "PASS" if _fails == 0 else "%d FAILED" % _fails])
	if _args.get("quit", 0) == 1 and _fails == 0:
		await _press(&"ui_cancel")
		if not _click(PauseMenu, "Quit Game") or not _click(PauseMenu, "Quit to desktop"):
			push_error("Quit confirmation was not reachable")
			get_tree().quit(1)
		else:
			print("Confirmed quit through the menu")
		return
	get_tree().quit(1 if _fails > 0 else 0)
