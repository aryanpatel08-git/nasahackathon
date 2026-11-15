extends Node2D
## Lunar outpost — one connected, walkable map.
##   Power room (west) - central corridor - Greenhouse (east), Storm shelter (north).
##
## Layers are kept separate on purpose:
##   - floor plan:  scripts/outpost/outpost_layout.gd (every rectangle and spot)
##   - picture:     assets/art/world/outpost_bg.png, painted from that plan by tools/art/paint_world.py
##   - live parts:  _draw() below paints what changes while you play (battery cells, lamps,
##                  screens, warning lights, the particle storm) on top of the picture
##   - collision:   built from the same plan in _build_collision()
##   - interaction: Station nodes (walk up + press E) and the shelter's BlastDoor (hold E)
##   - UI:          scripts/ui/outpost_hud.gd, ChoicePanel pop-ups and the mission report
##
## The storm shelter has no "use" spot. You crank the hatch open, step inside, and the
## hatch seals behind the crew by itself.

const CELL := 4
const PLAYER_SCENE := "res://scenes/characters/player.tscn"
const ART_DIR := "res://assets/art/world/"

const C_TEAL := Color("5fe3d3")
const C_TEAL_LO := Color("2a8f95")
const C_AMBER := Color("ffc45e")
const C_AMBER_LO := Color("b9722f")
const C_GREEN := Color("7ddc6f")
const C_DARK := Color("12142a")
const C_GROW := Color("f6b7ff")

var _bg: Texture2D
var _art: Dictionary = {}
var _player: Node2D
var _hatch: BlastDoor
var _tanaka: CrewMember
var _rivera: CrewMember
var _tint: CanvasModulate
var _hud: CanvasLayer
var _shelter_px: Rect2
var _hull_rects: Array[Rect2] = []
var _alert_started: bool = false
var _sheltering: bool = false
var _crew_phase: String = "work"   # work -> to_hatch -> waiting -> to_seat -> seated
var _call_timer: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	# Safety net for opening this scene on its own from the editor.
	if MissionDirector.stage < MissionDirector.Stage.CHECKS:
		MissionDirector.begin_mission()

	var first_arrival: bool = not GameState.get_flag(&"outpost_arrival_seen")
	GameState.set_flag(&"outpost_visited")
	if first_arrival:
		GameState.set_flag(&"outpost_arrival_seen")
		_show_arrival_moment()

	_bg = load(ART_DIR + "outpost_bg.png")
	_art = _read_art(ART_DIR + "outpost_art.json")
	_shelter_px = OutpostLayout.px_rect(OutpostLayout.SHELTER_ROOM)
	for f in OutpostLayout.floors():
		_hull_rects.append(OutpostLayout.px_rect(f).grow_individual(16, 34, 16, 20))
	_build_collision()

	_add_station(OutpostLayout.POWER_SPOT, "Check power", _on_power_used, &"power")
	_add_station(OutpostLayout.GREEN_SPOT, "Check crops", _on_green_used, &"crops")
	_add_station(OutpostLayout.RETURN_SPOT, "Return to academy", _on_return_used, &"return")

	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node2D
	_player.position = OutpostLayout.px(OutpostLayout.SPAWN)
	actors.add_child(_player)
	HabitatCamera.mount(_player, Vector2i(Vector2(OutpostLayout.MAP) * OutpostLayout.SCALE))

	_hatch = BlastDoor.new()
	_hatch.name = "ShelterHatch"
	_hatch.passage = OutpostLayout.px_rect(OutpostLayout.SHELTER_DOOR)
	_hatch.room = _shelter_px
	_hatch.opened.connect(_on_hatch_opened)
	actors.add_child(_hatch)

	# The whole outpost dims as the Sun drops behind the ridge.
	_tint = CanvasModulate.new()
	add_child(_tint)

	# Crew mates. After the storm they are already in the shelter.
	var after_storm := MissionDirector.stage >= MissionDirector.Stage.SHELTERED
	_tanaka = _add_crew(actors, "Dr. Tanaka", "res://assets/art/characters/npc_botanist.png",
		OutpostLayout.TANAKA_SEAT if after_storm else OutpostLayout.TANAKA_HOME, _on_tanaka_used)
	_rivera = _add_crew(actors, "Engineer Rivera", "res://assets/art/characters/npc_engineer.png",
		OutpostLayout.RIVERA_SEAT if after_storm else OutpostLayout.RIVERA_HOME, _on_rivera_used)
	if after_storm:
		_crew_phase = "seated"

	_add_navigation(_player)
	_hud = CanvasLayer.new()
	_hud.set_script(load("res://scripts/ui/outpost_hud.gd"))
	add_child(_hud)

	MissionDirector.stage_changed.connect(_on_stage_changed)
	if MissionDirector.stage == MissionDirector.Stage.DEBRIEF:
		_show_debrief.call_deferred()


func _read_art(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("Outpost: could not read %s" % path)
	return {}


func _show_arrival_moment() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 46
	add_child(layer)
	var moment := Control.new()
	moment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moment.set_script(load("res://scripts/ui/story_moment.gd"))
	moment.set("moment", 1)
	layer.add_child(moment)
	moment.tree_exited.connect(layer.queue_free)


func _add_navigation(player: Node2D) -> void:
	var nav := NavigationFloor.new()
	nav.facility = "Outpost"
	nav.bounds = Vector2(OutpostLayout.MAP) * OutpostLayout.SCALE
	nav.player = player
	for walkable in OutpostLayout.floors():
		nav.floors.append(OutpostLayout.px_rect(walkable))
	nav.links = {"Academy": "return"}
	nav.add_point("entrance", "Outpost entrance", "Entry", "Arrival corridor from the academy.", "hatch", OutpostLayout.px(OutpostLayout.SPAWN))
	nav.add_point("return", "Academy transit pad", "Transit", "Return to the academy before the alert.", "hatch", OutpostLayout.px(OutpostLayout.RETURN_SPOT))
	nav.add_point("power", "West power room", "Power", "Check battery reserves and rover charging.", "station", OutpostLayout.px(OutpostLayout.POWER_SPOT))
	nav.add_point("crops", "East greenhouse", "Crops", "Set the grow-light power plan.", "station", OutpostLayout.px(OutpostLayout.GREEN_SPOT))
	nav.add_point("shelter", "Storm shelter hatch", "Shelter", "Hold E to open the hatch, then step inside.", "hatch", OutpostLayout.px(OutpostLayout.HATCH_SPOT + Vector2(0, 16)))
	nav.add_point("rivera", "Engineer Rivera", "Rivera", "Ask Rivera about outpost power.", "crew", _rivera.position, _rivera)
	nav.add_point("tanaka", "Dr. Tanaka", "Tanaka", "Ask Tanaka about the greenhouse.", "crew", _tanaka.position, _tanaka)
	add_child(nav)
	var objective_hud := CanvasLayer.new()
	objective_hud.set_script(load("res://scripts/ui/objective_hud.gd"))
	add_child(objective_hud)
	objective_hud.call_deferred(&"configure", nav)


func _process(delta: float) -> void:
	_time += delta
	var illum := ResourceSim.illumination_at(ResourceSim.hour)
	_tint.color = _tint.color.lerp(Color(0.66, 0.7, 0.96).lerp(Color.WHITE, illum), minf(1.0, delta * 3.0))
	_hatch.alert = MissionDirector.stage == MissionDirector.Stage.ALERT
	_update_crew(delta)
	_update_shelter()
	queue_redraw()


# ---------------------------------------------------------------- stations and crew

func _add_station(pos: Vector2, prompt: String, handler: Callable, objective_id: StringName) -> void:
	var station := Station.new()
	station.prompt = prompt
	station.objective_id = objective_id
	station.position = OutpostLayout.px(pos)
	station.used.connect(handler)
	add_child(station)


func _add_crew(actors: Node2D, crew_name: String, sprite_path: String, at: Vector2, handler: Callable) -> CrewMember:
	var crew := CrewMember.new()
	crew.display_name = crew_name
	crew.texture = load(sprite_path)
	crew.position = OutpostLayout.px(at)
	crew.used.connect(handler)
	actors.add_child(crew)
	return crew


func _route(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p: Vector2 in points:
		out.append(OutpostLayout.px(p))
	return out


func _on_tanaka_used() -> void:
	var line := "Phew. Thick walls and a good plan. Nice work, {name}."
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		line = "The lettuce loves these lamps, {name}. The lamp control is under the water tank."
		if MissionDirector.greenhouse_checked:
			line = "Thanks for setting the lamps, {name}. Now we wait and watch them grow."
	FieldNotes.unlock(&"veggie")
	Dialogue.play(&"crew_tanaka", "Dr. Tanaka", PackedStringArray([line]))


func _on_rivera_used() -> void:
	var line := "We made it through. The battery tells the story, {name}."
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		line = "We landed with the battery half empty, {name}. Check the console on the north wall."
		if MissionDirector.power_checked:
			line = "Good call at the console. Watch that sunlight forecast on the wall screen."
	Dialogue.play(&"crew_rivera", "Engineer Rivera", PackedStringArray([line]))


## The alert begins: crew drop everything and run for the hatch, and the camera jolts.
func _start_alert_fx() -> void:
	_tanaka.enabled = false
	_rivera.enabled = false
	_crew_phase = "to_hatch"
	_rivera.say("Alarm! Shelter, now!")
	_rivera.walk(_route([OutpostLayout.POWER_DOOR.get_center(), OutpostLayout.HALL_JUNCTION, OutpostLayout.RIVERA_WAIT]))
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var jolt := create_tween()
		for i in 8:
			jolt.tween_property(camera, "offset", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.04)
		jolt.tween_property(camera, "offset", Vector2.ZERO, 0.05)
	await get_tree().create_timer(0.7, false).timeout
	if _crew_phase != "to_hatch":
		return
	_tanaka.say("Coming!")
	_tanaka.walk(_route([OutpostLayout.GREEN_DOOR.get_center(), OutpostLayout.HALL_JUNCTION, OutpostLayout.TANAKA_WAIT]))


func _update_crew(delta: float) -> void:
	match _crew_phase:
		"to_hatch":
			if _hatch.is_open():
				_send_crew_inside()
			elif not _rivera.is_walking() and not _tanaka.is_walking():
				_crew_phase = "waiting"
				_call_timer = 0.0
		"waiting":
			if _hatch.is_open():
				_send_crew_inside()
				return
			_call_timer -= delta
			if _call_timer <= 0.0:
				_call_timer = 3.2
				_rivera.say("Hold E on the hatch, {0}!".format([GameState.player_name]), 2.2)
		"to_seat":
			if not _rivera.is_walking() and not _tanaka.is_walking():
				_crew_phase = "seated"


func _send_crew_inside() -> void:
	_crew_phase = "to_seat"
	var door := OutpostLayout.SHELTER_DOOR.get_center()
	var inside := door - Vector2(0, 22)
	# Each one finishes whatever is left of the walk to the hatch, then goes through it.
	for entry: Array in [
			[_rivera, OutpostLayout.POWER_DOOR, OutpostLayout.RIVERA_WAIT, OutpostLayout.RIVERA_SEAT],
			[_tanaka, OutpostLayout.GREEN_DOOR, OutpostLayout.TANAKA_WAIT, OutpostLayout.TANAKA_SEAT]]:
		var crew: CrewMember = entry[0]
		var points: Array = []
		if not crew.is_walking() and crew.position.distance_to(OutpostLayout.px(entry[2])) > 40.0:
			# Still at their post: leave through their own door first.
			points = [(entry[1] as Rect2).get_center(), OutpostLayout.HALL_JUNCTION]
		points.append_array([entry[2], door, inside, entry[3]])
		crew.walk_on(_route(points))
	_tanaka.say("Go, go, go!", 1.6)


func _on_hatch_opened() -> void:
	FieldNotes.unlock(&"shelter")


## Stepping into the shelter during the alert is the whole interaction: the hatch seals
## behind the crew and the power decision opens by itself.
func _update_shelter() -> void:
	if _sheltering or MissionDirector.stage != MissionDirector.Stage.ALERT:
		return
	if MissionDirector.ui_open or Dialogue.is_active:
		return
	if not _shelter_px.grow_individual(0, 0, 0, -3).has_point(_player.position):
		return
	_sheltering = true
	_seal_and_decide()


func _seal_and_decide() -> void:
	MissionDirector.push_ui()   # freezes the astronaut and the storm clock for the short scene
	if _crew_phase != "seated":
		# Crew who are still on their way are hurried through the door.
		_rivera.walk_speed = 240.0
		_tanaka.walk_speed = 240.0
		if _crew_phase != "to_seat":
			_send_crew_inside()
		var waited := 0.0
		while (_crew_outside(_rivera) or _crew_outside(_tanaka)) and waited < 2.5:
			await get_tree().create_timer(0.1, false).timeout
			waited += 0.1
		for crew: CrewMember in [_rivera, _tanaka]:
			if _crew_outside(crew):
				crew.walk(PackedVector2Array())
				crew.position = OutpostLayout.px(OutpostLayout.RIVERA_SEAT if crew == _rivera else OutpostLayout.TANAKA_SEAT)
	_hatch.seal()
	if _hatch.state != BlastDoor.State.CLOSED:
		await _hatch.sealed
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var thud := create_tween()
		thud.tween_property(camera, "offset", Vector2(0, 3), 0.05)
		thud.tween_property(camera, "offset", Vector2.ZERO, 0.12)
	_hud.call(&"flash", "HATCH SEALED", UiKit.GREEN)
	await get_tree().create_timer(0.7, false).timeout
	MissionDirector.pop_ui()
	if MissionDirector.stage != MissionDirector.Stage.ALERT:
		return
	_open_shelter_panel()


func _crew_outside(crew: CrewMember) -> bool:
	return crew.position.y > _shelter_px.end.y - 2.0


func _open_shelter_panel() -> void:
	var s := ResourceSim.get_snapshot()
	var body := "You are behind the shelter's thick, water-lined walls. Mass between the crew and the Sun's particles is what protects you.\n\nThe Sun is also about to slip behind a ridge, so the battery must last. Life Support stays on. What should wait?   Battery: %d of %d cells." % [s["battery_cells"], s["battery_cells_total"]]
	var panel := ChoicePanel.open(self, "SHELTER SEALED  -  choose the power plan", body, PackedStringArray([
		"Pause science. Keep full grow lights.",
		"Keep science. Dim the grow lights.",
		"Pause science AND dim the lights. Saves the most power."]), false)
	panel.chosen.connect(_on_shelter_choice)


func _on_shelter_choice(index: int) -> void:
	MissionDirector.confirm_shelter(index)
	_tanaka.say("Shielded. Now we wait.", 3.0)


func _on_return_used() -> void:
	if (MissionDirector.stage == MissionDirector.Stage.CHECKS and not MissionDirector.checks_done()) or MissionDirector.stage == MissionDirector.Stage.DEBRIEF:
		SceneRouter.go_to(&"academy_hub")
	else:
		Dialogue.play(&"return_locked", "Transit interlock", PackedStringArray([
			"Transit is closed during the radiation emergency. Head to the shelter."]))


func _on_power_used() -> void:
	var s := ResourceSim.get_snapshot()
	var body := "Battery: %d of %d cells charged.\nSolar panels: %s.\n" % [s["battery_cells"], s["battery_cells_total"], sun_text()]
	FieldNotes.unlock(&"batteries")
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		body += "The wall screen shows the Sun slipping behind a ridge in about 6 hours. Charging the rover uses 3 power.\n\nChoose the reserve plan:"
		var panel := ChoicePanel.open(self, "POWER STATION", body, PackedStringArray([
			"Fill the battery: pause rover charging",
			"Keep charging the rover (more science)"]))
		panel.chosen.connect(_on_power_choice)
	else:
		ChoicePanel.open(self, "POWER STATION", body + "Rover charging: %s." % ("on" if ResourceSim.is_powered(&"rover") else "paused"), PackedStringArray(["OK"]))


func _on_power_choice(index: int) -> void:
	ResourceSim.set_load_enabled(&"rover", index == 1)
	MissionDirector.complete_check(&"power")
	_hud.call(&"flash", "POWER CHECK DONE", UiKit.TEAL)
	_after_check()


func _on_green_used() -> void:
	var body := "Crop health: %d of 100.\n" % int(ResourceSim.crop_health)
	FieldNotes.unlock(&"veggie")
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		body += "Grow lights use 3 power. Conservation mode dims them to 1.5 power: the crops stop growing but stay healthy.\n\nChoose the plan:"
		var panel := ChoicePanel.open(self, "GREENHOUSE", body, PackedStringArray([
			"Full grow lights (crops keep growing)",
			"Conservation mode (saves power)"]))
		panel.chosen.connect(_on_green_choice)
	else:
		ChoicePanel.open(self, "GREENHOUSE", body + "Grow lights: %s." % lamp_text(), PackedStringArray(["OK"]))


func _on_green_choice(index: int) -> void:
	ResourceSim.set_greenhouse_conservation(index == 1)
	MissionDirector.complete_check(&"greenhouse")
	_hud.call(&"flash", "CROP CHECK DONE", UiKit.GREEN)
	_after_check()


func _after_check() -> void:
	if MissionDirector.checks_done() and not _alert_started:
		_alert_started = true
		_alert_sequence()


func _alert_sequence() -> void:
	await get_tree().create_timer(0.6, false).timeout
	Dialogue.play(&"shift", "Mission clock", PackedStringArray([
		"Routine checks done. %d hours of the shift pass while the crew works..." % int(MissionDirector.config["shift_hours_before_alert"])]))
	await EventBus.dialogue_ended
	MissionDirector.start_alert()
	FieldNotes.unlock(&"sep")
	var first := "RADIATION ALERT! Training scenario: this solar particle event is fictional."
	if MissionDirector.sep_is_real:
		first = "RADIATION ALERT! NASA logged a solar particle event on %s. We are replaying that real record." % MissionDirector.sep_time_text()
	Dialogue.play(&"alert", "Mission Control", PackedStringArray([
		first,
		"Fast particles from the Sun can harm people. The Moon has no thick air or global magnetic field to stop them.",
		"Run NORTH to the storm shelter. Hold E to crank the hatch open, then get inside. The storm clock is running!"]))


func _on_stage_changed(stage: int) -> void:
	match stage:
		MissionDirector.Stage.ALERT:
			_start_alert_fx()
		MissionDirector.Stage.DEBRIEF:
			_tanaka.enabled = true
			_rivera.enabled = true
			_hatch.unlock()
			_show_debrief.call_deferred()


# ---------------------------------------------------------------- debrief

func _show_debrief() -> void:
	var report := MissionReport.open(self)
	report.chosen.connect(_on_debrief_choice)


func _on_debrief_choice(action: StringName) -> void:
	match action:
		&"retry":
			MissionDirector.begin_mission()
			SceneRouter.go_to(&"outpost")
		&"academy":
			SceneRouter.go_to(&"academy_hub")
		&"stay":
			_hatch.open()


# ---------------------------------------------------------------- text helpers (also used by the HUD)

static func sun_text() -> String:
	var illum := ResourceSim.illumination_at(ResourceSim.hour)
	if illum >= 0.9:
		return "full sun"
	if illum > 0.0:
		return "low sun"
	return "in shadow"


static func lamp_text() -> String:
	if not ResourceSim.is_powered(&"greenhouse"):
		return "off"
	return "saving" if ResourceSim.greenhouse_conservation else "full"


# ---------------------------------------------------------------- collision

func _build_collision() -> void:
	var cols := OutpostLayout.MAP.x / CELL
	var rows := OutpostLayout.MAP.y / CELL
	var floors := OutpostLayout.floors()
	var props := OutpostLayout.blockers()

	# 1 = walkable floor cell.
	var grid := PackedByteArray()
	grid.resize(cols * rows)
	for row in rows:
		for col in cols:
			var p := Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)
			var walkable := false
			for f in floors:
				if f.has_point(p):
					walkable = true
					break
			if walkable:
				for prop in props:
					if prop.has_point(p):
						walkable = false
						break
			grid[row * cols + col] = 1 if walkable else 0

	var body := StaticBody2D.new()
	body.name = "Walls"
	add_child(body)
	for row in rows:
		var run_start := -1
		for col in cols + 1:
			var blocked := false
			if col < cols and grid[row * cols + col] == 0:
				# Only cells next to floor need a wall.
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var c := col + dx
						var r := row + dy
						if c >= 0 and c < cols and r >= 0 and r < rows and grid[r * cols + c] == 1:
							blocked = true
			if blocked and run_start < 0:
				run_start = col
			elif not blocked and run_start >= 0:
				var shape := CollisionShape2D.new()
				var box := RectangleShape2D.new()
				box.size = Vector2((col - run_start) * CELL, CELL) * OutpostLayout.SCALE
				shape.shape = box
				shape.position = Vector2(run_start * CELL, row * CELL) * OutpostLayout.SCALE + box.size * 0.5
				body.add_child(shape)
				run_start = -1


# ---------------------------------------------------------------- drawing

func _rect_of(key: String, index: int = -1) -> Rect2:
	var value: Variant = _art.get(key, [])
	if index >= 0:
		value = (value as Array)[index]
	var a := value as Array
	if a.size() < 4:
		return Rect2()
	return Rect2(a[0], a[1], a[2], a[3])


func _point_of(key: String) -> Vector2:
	var a := _art.get(key, [0, 0]) as Array
	return Vector2(a[0], a[1])


func _draw() -> void:
	draw_texture(_bg, Vector2.ZERO)
	var d := MissionDirector
	var alert := d.stage == d.Stage.ALERT
	var blink := int(_time * 2.8) % 2 == 0
	var illum := ResourceSim.illumination_at(ResourceSim.hour)

	# --- Outside: solar panels darken in shadow, small lamps blink, the rover charges.
	if illum < 0.95:
		for i in (_art.get("solar_panels", []) as Array).size():
			draw_rect(_rect_of("solar_panels", i).grow(-1), Color(0.02, 0.03, 0.1, 0.55 * (1.0 - illum)))
	draw_rect(Rect2(_point_of("dish_light"), Vector2(1, 1)), C_AMBER if blink else C_AMBER_LO)
	draw_rect(Rect2(_point_of("junction_light"), Vector2(1, 1)), C_TEAL if illum > 0.0 else C_DARK)
	for light: Array in _art.get("path_lights", []):
		draw_rect(Rect2(light[0], light[1], 1, 1), C_AMBER if int(_time * 1.5 + light[0]) % 2 == 0 else C_AMBER_LO)
	if ResourceSim.is_powered(&"rover"):
		var port := _point_of("hull_port")
		var plug := _point_of("rover_port")
		draw_polyline(PackedVector2Array([port, port + Vector2(0, 8), Vector2(plug.x - 6, port.y + 12), plug]), C_AMBER_LO, 1.0)
		draw_rect(Rect2(_point_of("rover_lamp"), Vector2(2, 2)), C_TEAL if blink else C_TEAL_LO)

	# --- Solar particle storm over open ground (a picture of something invisible in real life).
	if ResourceSim.sep_active:
		for i in 110:
			var sx := fmod(i * 97.0 + _time * 620.0, _bg.get_width() + 60.0) - 30.0
			var sy := fmod(i * 53.0 + i * i * 7.0 + _time * 340.0, _bg.get_height() + 40.0) - 20.0
			var at := Vector2(sx, sy)
			if sy < OutpostLayout.HORIZON * OutpostLayout.SCALE or _inside_hull(at):
				continue
			draw_line(at, at - Vector2(9, 5), Color(1.0, 0.86, 0.5, 0.75), 1.0)
			draw_rect(Rect2(at, Vector2(1, 1)), Color(1.0, 0.97, 0.85))

	# --- Corridor lamps: calm teal normally, amber and chasing north during the alert.
	var lights := _art.get("corridor_lights", []) as Array
	for i in lights.size():
		var r := Rect2(lights[i][0], lights[i][1], lights[i][2], lights[i][3])
		var row := i / 2
		var color := C_TEAL_LO
		if alert:
			var rows := lights.size() / 2
			color = C_AMBER if (rows - row + int(_time * 9.0)) % 4 == 0 else C_AMBER_LO.darkened(0.3)
		elif (row + int(_time * 0.8)) % 5 == 0:
			color = C_TEAL
		draw_rect(r.grow(-1) if r.size.x > 2 else r, color)

	# --- Door signs and floor lettering.
	var power_door := OutpostLayout.px_rect(OutpostLayout.POWER_DOOR)
	var green_door := OutpostLayout.px_rect(OutpostLayout.GREEN_DOOR)
	UiKit.draw_text(self, Vector2(power_door.position.x + 9, power_door.position.y - 8), "POWER", "small", C_TEAL)
	UiKit.draw_text(self, Vector2(green_door.position.x + 10, green_door.position.y - 8), "CROPS", "small", C_GREEN)
	var hatch_px := OutpostLayout.px_rect(OutpostLayout.SHELTER_DOOR)
	draw_string(UiKit.font_small, Vector2(hatch_px.position.x + 10, hatch_px.end.y + 16), "SHELTER", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, C_AMBER if (alert and blink) else C_AMBER_LO)

	# --- Power room: the battery bank shows the real charge; the wall screen is the sunlight forecast.
	var cells := ResourceSim.battery_cells()
	var total := ResourceSim.battery_cells_total()
	var charging := ResourceSim.last_generation > ResourceSim.last_demand
	var low := cells <= 2
	for i in mini(total, (_art.get("battery_cells", []) as Array).size()):
		var cell := _rect_of("battery_cells", i)
		if i < cells:
			var fill := C_AMBER if low else C_TEAL
			draw_rect(cell, fill.darkened(0.25))
			draw_rect(Rect2(cell.position, Vector2(cell.size.x, 3)), fill)
			draw_rect(Rect2(cell.position + Vector2(1, 4), Vector2(1, cell.size.y - 6)), fill.lightened(0.35))
		elif i == cells and charging and blink:
			draw_rect(Rect2(cell.position + Vector2(0, cell.size.y - 4), Vector2(cell.size.x, 4)), C_TEAL_LO)
	var forecast := ResourceSim.illumination_forecast(10)
	var screen := _rect_of("power_screen")
	for i in forecast.size():
		var bar_h := 2.0 + roundf(forecast[i] * (screen.size.y - 5.0))
		var bar := Rect2(screen.position.x + 3 + i * 5, screen.end.y - 1 - bar_h, 3, bar_h)
		draw_rect(bar, C_AMBER if forecast[i] > 0.0 else Color("27304f"))
		if i == 0 and blink:
			draw_rect(Rect2(bar.position.x, screen.position.y + 1, 3, 1), Color.WHITE)

	# --- Greenhouse: lamps and a wash of grow light over each bed, by lamp mode.
	var lamps_on := ResourceSim.is_powered(&"greenhouse")
	var saving := ResourceSim.greenhouse_conservation
	var lamp := C_GROW
	var wash := Color(C_GROW, 0.16 + 0.03 * sin(_time * 3.0))
	if not lamps_on:
		lamp = C_DARK
		wash = Color(0.05, 0.06, 0.16, 0.42)
	elif saving:
		lamp = C_AMBER_LO
		wash = Color(0.05, 0.06, 0.16, 0.2)
	for i in (_art.get("beds", []) as Array).size():
		var bed := _rect_of("beds", i)
		draw_rect(Rect2(bed.position + Vector2(3, 4), Vector2(bed.size.x - 6, bed.size.y - 13)), wash)
		draw_rect(_rect_of("bed_lamps", i), lamp)
		draw_rect(Rect2(bed.position + Vector2(bed.size.x - 9, bed.size.y - 6), Vector2(4, 2)), C_GREEN if lamps_on and not saving else (C_AMBER if lamps_on else C_DARK))
	draw_rect(_rect_of("green_screen").grow(-1), lamp if lamps_on else Color("27304f"))
	var tank := _rect_of("water_tank")
	for i in 3:
		var rise := fmod(_time * (5.0 + i * 2.0) + i * 7.0, tank.size.y - 2.0)
		draw_rect(Rect2(tank.position.x + 3 + i * 7, tank.end.y - 2 - rise, 1, 1), Color("d7f6ff"))

	# --- Shelter: the wall monitor shows the particle count rising during the storm.
	var rad := _rect_of("rad_screen")
	for i in 9:
		var level := 0.12 + 0.06 * sin(_time * 2.0 + i)
		var color := C_GREEN
		if ResourceSim.sep_active:
			level = 0.55 + 0.4 * absf(sin(_time * 6.0 + i * 1.7))
			color = C_AMBER if level < 0.8 else Color("ff6b5e")
			if ResourceSim.crew_sheltered:
				level *= 0.22
				color = C_GREEN
		var bar_h := maxf(1.0, roundf(level * (rad.size.y - 4.0)))
		draw_rect(Rect2(rad.position.x + 3 + i * 3, rad.end.y - 1 - bar_h, 2, bar_h), color)

	# --- Station markers: a pulsing ring until the check is done, then a quiet tick.
	_marker(OutpostLayout.px(OutpostLayout.POWER_SPOT), d.power_checked, C_TEAL)
	_marker(OutpostLayout.px(OutpostLayout.GREEN_SPOT), d.greenhouse_checked, C_GREEN)
	var pad := _point_of("transit_pad")
	draw_arc(pad, 5.0 + sin(_time * 3.0), 0.0, TAU, 14, Color(C_TEAL, 0.7), 1.0)

	# --- Alert route: chevrons up the corridor to the hatch.
	if alert:
		var corridor := OutpostLayout.px_rect(OutpostLayout.CORRIDOR)
		var cx := corridor.get_center().x - 22.0
		var cy := corridor.end.y - 46.0
		var step := 0
		while cy > corridor.position.y + 26.0:
			if (step + int(_time * 6.0)) % 3 == 0:
				for side: float in [0.0, 44.0]:
					draw_colored_polygon(PackedVector2Array([
						Vector2(cx + side, cy - 5), Vector2(cx + side + 6, cy + 2), Vector2(cx + side + 3, cy + 2),
						Vector2(cx + side, cy - 1), Vector2(cx + side - 3, cy + 2), Vector2(cx + side - 6, cy + 2)]), C_AMBER)
			cy -= 16.0
			step += 1


func _marker(at: Vector2, done: bool, color: Color) -> void:
	if done:
		draw_arc(at, 7.0, 0.0, TAU, 16, Color(color, 0.35), 1.0)
		draw_polyline(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(-1, 2), at + Vector2(3, -2)]), Color(color, 0.8), 1.0)
		return
	var pulse := fmod(_time * 1.2, 1.0)
	draw_arc(at, 6.0 + pulse * 5.0, 0.0, TAU, 18, Color(color, 1.0 - pulse), 1.0)
	draw_arc(at, 6.0, 0.0, TAU, 16, color, 1.0)
	draw_rect(Rect2(at - Vector2(1, 1), Vector2(2, 2)), color)


func _inside_hull(point: Vector2) -> bool:
	for r in _hull_rects:
		if r.has_point(point):
			return true
	return false
