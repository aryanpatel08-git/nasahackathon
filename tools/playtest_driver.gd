extends Node
## Automatic playthrough of the whole game, start to finish, with checks at every step.
## See tools/playtest.gd for how to run it.
##   rover=0|1   keep the rover charging at the power check
##   choice=0|1|2  shelter power plan      late=N  seconds to dawdle after the alert
##   speed=N     engine time scale         quit=1  finish through the quit menu

var _args: Dictionary = {"rover": 0, "choice": 2, "late": 0, "speed": 3}
var _shots: bool = false
var _fails: int = 0
var _tag: String = ""


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


## Press and keep holding an action for some game seconds (for the shelter hatch).
func _hold(action: StringName, seconds: float) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	Input.parse_input_event(ev)
	await _wait(seconds)
	var up := InputEventAction.new()
	up.action = action
	up.pressed = false
	Input.parse_input_event(up)
	await get_tree().process_frame


func _player() -> CharacterBody2D:
	return get_tree().get_first_node_in_group(&"player") as CharacterBody2D


## Walk through points given in the current scene's map units.
## At a high engine speed one physics step covers several pixels, so "arrived" allows for that.
func _walk(points: Array, must_arrive: bool = true) -> void:
	var p := _player()
	var scale := OutpostLayout.SCALE if get_tree().current_scene.name == &"Outpost" else AcademyLayout.SCALE
	var near := maxf(3.0, 2.4 * Engine.time_scale)
	for target: Vector2 in points:
		target *= scale
		var t := 0.0
		while p.global_position.distance_to(target) > near and t < 12.0:
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
		if must_arrive:
			_check(p.global_position.distance_to(target) <= near, "walked to %s (at %s)" % [target, p.global_position.round()])


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


func _report() -> MissionReport:
	for n in get_tree().current_scene.get_children():
		if n is MissionReport and not n.is_queued_for_deletion():
			return n
	return null


func _click(root: Node, text_start: String) -> bool:
	if root == null:
		return false
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


func _target_prompt() -> String:
	var target := _player().get(&"_target") as Node2D
	return target.call(&"prompt_text") if is_instance_valid(target) else ""


func _run() -> void:
	var D := MissionDirector
	print("PLAYTEST ", _tag)

	print("[title]")
	GameState.start_fresh_progress()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _wait(1.0)
	_check(get_tree().current_scene.name == &"TitleScreen", "title screen loads")
	_check(not (PauseMenu.get("_toggle") as Button).visible, "no pause button on the title screen")
	await _shot("00_title")
	_check(_click(get_tree().current_scene, "New game"), "New game starts")
	await _wait(1.2)
	_check(get_tree().current_scene.name == &"CreateAstronaut", "astronaut creation opens")
	await _wait(0.6)
	await _shot("01_create")
	var create := get_tree().current_scene
	(create.get("_name_edit") as LineEdit).text = "Tester"
	create.call("_set_color", 4)
	await _wait(0.2)
	create.call("_start")
	await _wait(1.5)

	print("[academy]")
	_check(get_tree().current_scene.name == &"AcademyHub", "academy loaded")
	var cinematic := get_tree().current_scene.find_child("MissionCinematic", true, false)
	_check(cinematic != null and D.ui_open and D.stage == D.Stage.BRIEFING, "the intro plays before control")
	await _shot("02_intro_1")
	await _wait(6.0)
	_check(is_instance_valid(cinematic) and int(cinematic.get("slide")) == 0, "the intro waits on slide 1 until E is pressed")
	for i in 3:
		await _press(&"interact")   # finish typing (or turn the page if it had finished)
		if int(cinematic.get("slide")) == i:
			await _press(&"interact")
		_check(int(cinematic.get("slide")) == i + 1, "E turns to slide %d" % (i + 2))
		await _wait(0.5)
		await _shot("02_intro_%d" % (i + 2))
	await _press(&"interact")
	if is_instance_valid(cinematic) and not cinematic.is_queued_for_deletion() and get_tree().current_scene.find_child("MissionCinematic", true, false) != null:
		await _press(&"interact")
	await _wait(0.8)
	_check(get_tree().current_scene.find_child("MissionCinematic", true, false) == null, "the intro ends after the last slide")
	_check(Dialogue.is_active and D.stage == D.Stage.BRIEFING, "the commander's briefing follows")
	await _wait(0.6)
	await _shot("02_briefing")
	var line_before: String = (Dialogue.get("_text_label") as Label).text
	await _wait(4.0)
	_check(Dialogue.is_active and (Dialogue.get("_text_label") as Label).text == line_before, "dialogue waits for E too")
	await _talk_through()
	_check(D.stage == D.Stage.TRAINING, "briefing done -> TRAINING")
	_check(FieldNotes.is_unlocked(&"polar_sun"), "the briefing unlocks a field note")
	await _press(&"interact")
	_check(not Dialogue.is_active and not D.ui_open, "E far from everything does nothing")

	# Movement: instant, diagonal, never stalls when a second key is added or released.
	var p := _player()
	var from := p.global_position
	Input.action_press(&"move_up")
	for i in 6:
		await get_tree().physics_frame
	_check(p.global_position.distance_to(from) > 2.0, "astronaut is moving within 6 physics frames of the key press")
	Input.action_press(&"move_right")
	for i in 8:
		await get_tree().physics_frame
	_check(p.velocity.x > 40.0 and p.velocity.y < -40.0, "W + D walks diagonally (velocity %s)" % p.velocity.round())
	_check(absf(p.velocity.length() - 112.0) < 6.0, "diagonal speed equals straight speed")
	Input.action_release(&"move_right")
	var slowest := 999.0
	for i in 12:
		await get_tree().physics_frame
		slowest = minf(slowest, p.velocity.length())
	_check(slowest > 80.0, "letting go of D keeps walking (slowest %d)" % int(slowest))
	Input.action_release(&"move_up")
	await _wait(0.3)

	await _walk([Vector2(384, 264), Vector2(696, 264), Vector2(696, 106)])
	_check(_target_prompt().begins_with("Lander dock"), "the dock prompt says it is locked")
	await _press(&"interact")
	_check(Dialogue.is_active and get_tree().current_scene.name == &"AcademyHub", "the lander dock is locked before certification")
	await _talk_through()

	_burst("walk", 24, 0.05)
	await _walk([Vector2(696, 144), Vector2(544, 144)])
	await _shot("03_academy_room")
	_check(_target_prompt() == "Talk", "prompt offers to talk to Rivera")
	await _press(&"interact")
	_check(Dialogue.is_active, "Rivera talks")
	await _talk_through()
	await _wait(0.4)
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
	await _wait(0.5)
	await _shot("06_training_pass")
	await _wait(2.6)
	await _press(&"ui_cancel")
	await _wait(0.3)
	_check(not D.ui_open and get_tree().current_scene.find_child("PowerConsole", true, false) == null, "Esc closes the panel")
	_check(_player().global_position.distance_to(Vector2(544, 144)) < 10.0, "player is back at the same position")

	# The things to read each unlock a field note.
	await _walk([Vector2(544, 264), Vector2(118, 264), Vector2(118, 122)])
	await _press(&"interact")
	_check(Dialogue.is_active, "the space-weather desk can be read")
	await _talk_through()
	_check(FieldNotes.is_unlocked(&"donki") and FieldNotes.is_unlocked(&"may2024"), "the desk unlocks the DONKI notes")
	await _wait(0.4)
	await _shot("06b_weather_desk")

	await _walk([Vector2(118, 264), Vector2(696, 264), Vector2(696, 106)])
	_check(_target_prompt() == "Board the lander", "the dock prompt now offers the lander")
	await _press(&"interact")
	await _wait(1.2)

	print("[outpost]")
	_check(get_tree().current_scene.name == &"Outpost" and D.stage == D.Stage.CHECKS, "outpost loaded -> CHECKS")
	await _shot("07_arrival")
	await _wait(4.0)
	_check(not D.ui_open, "the touchdown scene hands control back")
	await _shot("07_outpost")
	_check(MapManager.floor.facility == "Outpost", "outpost navigation attaches")
	MapManager.get("_mini").pressed.emit()
	await _wait(0.3)
	_check(get_tree().paused and MapManager.owns_pause, "minimap opens and pauses")
	var map_view := MapManager.get("_display") as MapDisplay
	map_view.change_zoom(1.2)
	_check(map_view.zoom > 1.0, "expanded map zooms")
	map_view.selected.emit("power")
	_check(MapManager.target_id == "power" and MapManager.floor.route.size() > 8, "selecting a destination plots a route")
	var blocked_route := false
	for point in MapManager.floor.route:
		blocked_route = blocked_route or MapManager.floor.grid.is_point_solid(Vector2i((point / NavigationFloor.CELL).floor()))
	_check(not blocked_route, "all route cells are walkable")
	await _shot("07b_map")
	await _press(&"ui_cancel")
	await _wait(0.25)
	_check(not get_tree().paused, "Escape closes map and resumes")
	await _press(&"interact")
	_check(not D.ui_open and not Dialogue.is_active, "E far from stations does nothing")
	p = _player()
	Input.action_press(&"move_left")
	await _wait(1.5)
	Input.action_release(&"move_left")
	_check(p.global_position.x > OutpostLayout.CORRIDOR.position.x * OutpostLayout.SCALE, "corridor wall blocks walking west at the entrance (x=%d)" % int(p.global_position.x))
	Input.action_press(&"move_down")
	await _wait(1.0)
	Input.action_release(&"move_down")
	_check(p.global_position.y < OutpostLayout.CORRIDOR.end.y * OutpostLayout.SCALE, "bottom wall blocks (y=%d)" % int(p.global_position.y))

	# The shelter hatch: a tap does nothing, holding E cranks it open, and inside there is nothing to "use".
	var hatch := get_tree().current_scene.find_child("ShelterHatch", true, false) as BlastDoor
	await _walk([Vector2(240, 212), Vector2(240, 140)])
	_check(_target_prompt() == "Open shelter hatch", "the hatch offers to open")
	Input.action_press(&"move_up")
	await _wait(0.5)
	Input.action_release(&"move_up")
	_check(p.global_position.y > OutpostLayout.SHELTER_DOOR.end.y * OutpostLayout.SCALE, "a shut hatch blocks the doorway")
	await _press(&"interact")
	await _wait(0.4)
	_check(hatch.state == BlastDoor.State.CLOSED, "a quick tap of E does not open the heavy hatch")
	await _shot("08a_hatch_closed")
	await _hold(&"interact", 1.3)
	_check(hatch.state != BlastDoor.State.CLOSED, "holding E cranks the hatch open")
	await _wait(0.8)
	_check(hatch.is_open(), "the hatch is fully open")
	_check(FieldNotes.is_unlocked(&"shelter"), "opening the hatch unlocks the shelter note")
	await _shot("08b_hatch_open")
	await _walk([Vector2(240, 96)])
	await _wait(0.4)
	_check(_player().get(&"_target") == null, "inside the shelter there is nothing to interact with")
	_check(D.stage == D.Stage.CHECKS and not D.ui_open, "walking in before the alert is just a visit")
	await _shot("08c_shelter_inside")
	await _walk([Vector2(240, 150), Vector2(240, 212)])
	await _wait(2.4)
	_check(hatch.state == BlastDoor.State.CLOSED, "the hatch closes by itself once you leave")

	await _walk([Vector2(150, 212), Vector2(138, 192)])
	_check(_target_prompt() == "Check power", "the prompt names the task")
	await _press(&"interact")
	await _wait(0.4)
	_check(D.ui_open, "power panel opens next to the station")
	await _shot("08_power_panel")
	await _choose(1 if _args["rover"] == 1 else 0)
	_check(MapManager.target_id.is_empty(), "arriving near the power station clears a manual waypoint")
	MapManager.set_waypoint("Academy", "entrance")
	_check(MapManager.local_target() == "return", "cross-facility route targets the transit pad")
	_check(D.power_checked and ResourceSim.is_powered(&"rover") == (_args["rover"] == 1), "power check done, rover policy applied")
	_check(D.stage == D.Stage.CHECKS, "one check does not start the alert")

	await _walk([Vector2(150, 212), Vector2(240, 212), Vector2(240, 266)])
	await _press(&"interact")
	await _wait(1.0)
	_check(get_tree().current_scene.name == &"AcademyHub", "the transit pad returns to the academy")
	_check(MapManager.target_facility == "Academy" and MapManager.local_target() == "entrance", "waypoint survives scene travel")
	MapManager.clear_waypoint()
	_check(D.power_checked and D.can_graduate() and ResourceSim.hour == 4, "academy return preserves mission and certificate")
	await _walk([Vector2(696, 106)])
	await _press(&"interact")
	await _wait(1.0)
	_check(get_tree().current_scene.name == &"Outpost" and D.power_checked, "the lander returns to the outpost")
	_check(not D.ui_open, "no touchdown scene on a return trip")
	await _walk([Vector2(240, 212)])

	await _walk([Vector2(290, 212), Vector2(378, 212), Vector2(378, 196)])
	await _shot("09_greenhouse")
	await _press(&"interact")
	await _wait(0.4)
	await _choose(0)
	_check(D.greenhouse_checked, "crop check done")
	await _wait(1.0)
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
	await _shot("16_pause")
	_check(_click(PauseMenu, "Tasks") and PauseMenu.get("_page") == "tasks", "the task log opens from the pause menu")
	var tracked_alert := false
	for button: Button in PauseMenu.find_children("*", "Button", true, false):
		if button.text == "Track objective" and button.get_index() == button.get_parent().get_child_count() - 1:
			button.pressed.emit()
			tracked_alert = MapManager.tracked_task == "Respond to the space weather alert"
			break
	_check(tracked_alert and MapManager.local_target() == "shelter", "task menu tracks the shelter objective")
	await _press(&"ui_cancel")
	_click(PauseMenu, "Tasks")
	_check(TaskLog.entries().any(func(task: Dictionary) -> bool: return task.title == "Check outpost power" and task.done), "task log records completed outpost check")
	await _shot("16_tasks")
	await _press(&"ui_cancel")
	_check(get_tree().paused and PauseMenu.get("_page") == "home", "Escape returns from Tasks")
	_check(_click(PauseMenu, "Field notes") and PauseMenu.get("_page") == "notes", "field notes open from the pause menu")
	await _wait(0.2)
	await _shot("16_notes")
	await _press(&"ui_cancel")
	_check(_click(PauseMenu, "Help"), "help opens from the pause menu")
	await _shot("16_help")
	await _press(&"ui_cancel")
	_check(_click(PauseMenu, "Quit") and PauseMenu.get("_page") == "quit", "quit requires confirmation")
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
	await _walk([Vector2(378, 212), Vector2(240, 212), Vector2(240, 140)])
	hatch = get_tree().current_scene.find_child("ShelterHatch", true, false) as BlastDoor
	_check(not D.ui_open and D.stage == D.Stage.ALERT, "reaching the hatch does not shelter anyone yet")
	await _shot("12a_at_hatch")
	await _hold(&"interact", 1.3)
	await _wait(0.7)
	_check(hatch.is_open(), "the hatch opens during the alert")
	var outside := D.hours_unsheltered
	await _walk([Vector2(240, 98)], false)   # the astronaut is held still as the hatch seals
	t = 0.0
	while _panel() == null and t < 6.0:
		await _wait(0.1)
		t += 0.1
	_check(_panel() != null and D.stage == D.Stage.ALERT, "stepping inside seals the hatch and opens the power plan by itself")
	_check(hatch.is_locked() and hatch.state == BlastDoor.State.CLOSED, "the hatch is sealed behind the crew")
	var scene := get_tree().current_scene
	var crew_in := true
	for crew: CrewMember in scene.find_children("*", "CrewMember", true, false):
		crew_in = crew_in and crew.position.y < OutpostLayout.SHELTER_ROOM.end.y * OutpostLayout.SCALE
	_check(crew_in, "both crew mates are inside the shelter")
	await _wait(0.3)
	await _shot("12_shelter_panel")
	await _choose(int(_args["choice"]))
	_check(D.stage == D.Stage.SHELTERED and ResourceSim.crew_sheltered, "sheltered")
	_check(MapManager.target_id.is_empty(), "finishing the tracked task clears its waypoint")
	D.confirm_shelter(0)
	_check(D.shelter_choice == int(_args["choice"]), "a second confirm does nothing")
	await _wait(0.6)
	await _shot("12b_sheltered")
	t = 0.0
	while D.stage != D.Stage.DEBRIEF and t < 20.0:
		await _wait(0.2)
		t += 0.2
	await _wait(1.6)
	var report := _report()
	_check(D.stage == D.Stage.DEBRIEF and report != null, "the mission report opens")
	_check(D.hours_unsheltered >= outside and D.storm_hours_done == D.storm_hours_total(), "storm ran its full %d hours" % D.storm_hours_total())
	_check(ResourceSim.history.size() == ResourceSim.hours_run, "the report has one history entry per simulated hour")
	_check(FieldNotes.is_unlocked(&"cosmic_rays"), "finishing a mission unlocks the last notes")
	await _shot("13_debrief")
	var rating := MissionReport.rate()
	print("RESULT %s: outside=%dh exposure=%.1f batt_min=%.1f ls=%d/%d shutoffs=%d crops=%d science=%d stars=%d+%d+%d" % [
		_tag, D.hours_unsheltered, ResourceSim.exposure_log, ResourceSim.battery_min,
		ResourceSim.life_support_ok_hours, ResourceSim.hours_run, ResourceSim.emergency_shutoffs,
		int(ResourceSim.crop_health), ResourceSim.science_points, rating["safety"], rating["power"], rating["yield"]])
	_check(_click(report, "Sources"), "source notes open from the report")
	await _wait(0.2)
	await _shot("14_sources")
	_check(_click(report, "Back to the report"), "back to the report")
	_check(_click(report, "Field notes") and PauseMenu.get("_page") == "notes", "field notes open from the report")
	await _wait(0.2)
	await _press(&"ui_cancel")
	_check(not get_tree().paused and _report() != null, "closing the notes returns to the report")
	_check(_click(report, "Try again"), "Try again restarts the mission")
	await _wait(1.6)
	_check(D.stage == D.Stage.CHECKS and not D.power_checked and D.storm_hours_done == 0, "retry resets the mission")
	_check(ResourceSim.hour == 4 and ResourceSim.battery == 20.0 and ResourceSim.exposure_log == 0.0 and not ResourceSim.sep_active, "retry resets the simulation")
	_check(GameState.player_name == "Tester" and D.can_graduate(), "retry keeps the astronaut profile")
	_check(not D.ui_open and _player() != null, "player is in control again")
	await _shot("15_after_retry")

	print("PLAYTEST %s: %s" % [_tag, "PASS" if _fails == 0 else "%d FAILED" % _fails])
	if _args.get("quit", 0) == 1 and _fails == 0:
		await _press(&"ui_cancel")
		if not _click(PauseMenu, "Quit") or not _click(PauseMenu, "Quit to desktop"):
			push_error("Quit confirmation was not reachable")
			get_tree().quit(1)
		else:
			print("Confirmed quit through the menu")
		return
	get_tree().quit(1 if _fails > 0 else 0)
