extends Node
## Plays one complete, tidy run of the game the way a person would: it waits long
## enough to read every line, moves the focus before choosing, and uses the 9-star plan.
## It prints a chapter list with timestamps when it finishes.

const PLAYER_NAME := "Kareem"

var _clock: float = 0.0
var _chapters: PackedStringArray = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()


func _process(delta: float) -> void:
	_clock += delta


func _chapter(title: String) -> void:
	var seconds := int(_clock)
	_chapters.append("%d:%02d %s" % [seconds / 60, seconds % 60, title])
	print("CHAPTER ", _chapters[-1])


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


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


func _walk(points: Array) -> void:
	var p := _player()
	var scale := OutpostLayout.SCALE if get_tree().current_scene.name == &"Outpost" else AcademyLayout.SCALE
	for target: Vector2 in points:
		target *= scale
		var t := 0.0
		while p.global_position.distance_to(target) > 3.0 and t < 12.0 and not MissionDirector.ui_open:
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


func _reading_time(text: String) -> float:
	return clampf(0.6 + text.length() * 0.042, 1.6, 5.5)


## Reads a conversation at a comfortable pace, pressing E for each line.
func _read() -> void:
	var guard := 0
	while Dialogue.is_active and guard < 40:
		var t := 0.0
		while Dialogue.is_revealing() and t < 8.0:
			await _wait(0.1)
			t += 0.1
		await _wait(_reading_time((Dialogue.get("_text_label") as Label).text))
		await _press(&"interact")
		await _wait(0.25)
		guard += 1


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


func _button(root: Node, text_start: String) -> Button:
	if root == null:
		return null
	for b: Button in root.find_children("*", "Button", true, false):
		if b.text.begins_with(text_start) and b.is_visible_in_tree():
			return b
	return null


## Moves the focus to a button so the viewer sees the choice, then presses it.
func _click(root: Node, text_start: String, look: float = 0.7) -> void:
	var b := _button(root, text_start)
	if b == null:
		push_error("demo: no button '%s'" % text_start)
		return
	if b.focus_mode != Control.FOCUS_NONE:
		b.grab_focus()
	await _wait(look)
	b.pressed.emit()
	await _wait(0.15)


func _choose(index: int, read_for: float) -> void:
	var t := 0.0
	while _panel() == null and t < 8.0:
		await _wait(0.1)
		t += 0.1
	var panel := _panel()
	if panel == null:
		push_error("demo: no panel to choose from")
		return
	await _wait(read_for)
	var buttons := panel.find_children("*", "Button", true, false)
	for i in index + 1:
		(buttons[i] as Button).grab_focus()
		Sfx.play(&"tick")
		await _wait(0.55)
	await _wait(0.5)
	(buttons[index] as Button).pressed.emit()
	await _wait(0.4)


func _run() -> void:
	var D := MissionDirector
	Engine.time_scale = 1.0
	GameState.start_fresh_progress()
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
	await _wait(0.2)
	_chapter("Title")
	await _wait(3.5)
	await _click(get_tree().current_scene, "New game", 0.8)
	await _wait(1.4)

	_chapter("Create your astronaut")
	var create := get_tree().current_scene
	var edit := create.get("_name_edit") as LineEdit
	await _wait(1.0)
	for i in PLAYER_NAME.length():
		edit.text = PLAYER_NAME.substr(0, i + 1)
		edit.caret_column = i + 1
		edit.text_changed.emit(edit.text)
		Sfx.play(&"tick")
		await _wait(0.14)
	await _wait(0.6)
	for color in [1, 2, 4]:
		create.call("_set_color", color)
		await _wait(0.7)
	await _wait(0.8)
	create.call("_start")
	await _wait(1.6)

	_chapter("Mission briefing (press E to turn each page)")
	var cinematic := get_tree().current_scene.find_child("MissionCinematic", true, false)
	var slides := 0
	while is_instance_valid(cinematic) and not cinematic.is_queued_for_deletion() and slides < 4:
		var t := 0.0
		while cinematic.call("is_typing") and t < 12.0:
			await _wait(0.1)
			t += 0.1
		await _wait(2.6)
		await _press(&"interact")
		await _wait(0.5)
		slides += 1
	await _wait(1.0)
	await _read()
	await _wait(0.6)

	_chapter("Academy: power console training")
	# A short free walk first: straight, then diagonal.
	await _walk([Vector2(384, 264), Vector2(470, 264), Vector2(544, 190), Vector2(544, 144)])
	await _wait(0.5)
	await _press(&"interact")
	await _wait(0.4)
	await _read()
	await _wait(0.8)
	var console := get_tree().current_scene.find_child("PowerConsole", true, false)
	await _wait(4.5)
	# First try: leave everything on and watch it fail.
	await _click(console, "Fast", 0.8)
	var t2 := 0.0
	while console.get("_state") == "running" and t2 < 30.0:
		await _wait(0.1)
		t2 += 0.1
	await _wait(5.0)
	await _click(console, "Retry", 0.8)
	await _wait(1.5)
	# Second try: the rover can wait.
	for cb: CheckButton in console.find_children("*", "CheckButton", true, false):
		if cb.text.contains("Rover"):
			cb.grab_focus()
			await _wait(2.4)
			cb.button_pressed = false
			await _wait(1.4)
	await _click(console, "Go", 0.8)
	await _wait(5.0)
	await _click(console, "Fast", 0.5)
	t2 = 0.0
	while console.get("_state") == "running" and t2 < 30.0:
		await _wait(0.1)
		t2 += 0.1
	await _wait(6.5)
	await _press(&"ui_cancel")
	await _wait(0.8)

	_chapter("Academy: the space-weather desk")
	await _walk([Vector2(544, 264), Vector2(118, 264), Vector2(118, 122)])
	await _wait(0.4)
	await _press(&"interact")
	await _wait(0.3)
	await _read()
	await _wait(2.2)
	await _walk([Vector2(118, 264), Vector2(696, 264), Vector2(696, 106)])
	await _wait(0.5)
	await _press(&"interact")
	await _wait(1.5)

	_chapter("Landing at the lunar outpost")
	var t3 := 0.0
	while D.ui_open and t3 < 10.0:
		await _wait(0.1)
		t3 += 0.1
	await _wait(1.5)
	# A look at the map.
	MapManager.open_map()
	await _wait(0.6)
	(MapManager.get("_display") as MapDisplay).selected.emit("power")
	await _wait(3.2)
	await _press(&"ui_cancel")
	await _wait(0.5)
	if get_tree().paused:
		MapManager.call("close_map")
		await _wait(0.3)

	_chapter("Power check")
	await _walk([Vector2(240, 212), Vector2(150, 212), Vector2(138, 192)])
	await _wait(0.5)
	await _press(&"interact")
	await _choose(1, 5.5)
	await _wait(1.2)

	_chapter("Greenhouse check")
	await _walk([Vector2(150, 212), Vector2(290, 212), Vector2(378, 212), Vector2(378, 196)])
	await _wait(0.5)
	await _press(&"interact")
	await _choose(0, 5.5)
	await _wait(1.4)

	_chapter("Radiation alert")
	await _read()          # end-of-shift message
	await _wait(0.6)
	await _read()          # Mission Control: the alert
	# No dawdling: every storm hour outside the shield counts.
	await _walk([Vector2(378, 212), Vector2(240, 212), Vector2(240, 140)])
	_chapter("Hold E to open the shelter hatch")
	await _hold(&"interact", 1.25)
	await _wait(0.55)
	await _walk([Vector2(240, 98)])
	print("DEMO storm hours outside so far: ", D.storm_hours_done)
	await _choose(2, 7.0)
	# Stretch the legs inside the shelter while the storm passes.
	await _wait(3.0)
	await _walk([Vector2(206, 92), Vector2(206, 84)])
	await _wait(5.0)
	await _walk([Vector2(274, 92), Vector2(274, 84)])
	await _wait(4.0)
	await _walk([Vector2(240, 96)])

	_chapter("Sheltered while the storm passes")
	var t4 := 0.0
	while D.stage != D.Stage.DEBRIEF and t4 < 60.0:
		await _wait(0.2)
		t4 += 0.2
	t4 = 0.0
	while _report() == null and t4 < 8.0:
		await _wait(0.1)
		t4 += 0.1

	_chapter("Mission report")
	var report := _report()
	await _wait(9.0)
	await _click(report, "Sources", 0.8)
	await _wait(6.5)
	await _click(report, "Back to the report", 0.8)
	await _wait(0.6)
	_chapter("Field notes")
	await _click(report, "Field notes", 0.8)
	await _wait(5.5)
	for title: String in ["The storm we replay", "Build a storm shelter"]:
		await _click(PauseMenu, title, 0.5)
		await _wait(5.5)
	await _press(&"ui_cancel")
	await _wait(3.0)

	var rating := MissionReport.rate()
	print("DEMO RESULT outside=%dh stars=%d+%d+%d" % [D.hours_unsheltered, rating["safety"], rating["power"], rating["yield"]])
	print("CHAPTERS\n" + "\n".join(_chapters))
	print("DEMO DONE %.1f s" % _clock)
	get_tree().quit()
