extends Node2D
## Lunar outpost — one connected, walkable map.
##   Power room (west) - central corridor - Greenhouse (east), Shelter (north).
##
## Layers are kept separate on purpose:
##   - visuals:    _draw() below (flat shapes in the game palette; no baked text or characters)
##   - collision:  built from the FLOORS / PROPS rectangles in _build_collision()
##   - interaction: three Station nodes (walk up + press E)
##   - UI:         a CanvasLayer HUD and ChoicePanel pop-ups
## All rooms share geometry between rendering and collision.

const CELL := 4
const SCALE := 1.5
const MAP := Vector2i(480, 272)

const CORRIDOR := Rect2(204, 100, 72, 150)
const POWER_ROOM := Rect2(28, 124, 148, 112)
const POWER_DOOR := Rect2(176, 162, 28, 36)
const GREEN_ROOM := Rect2(304, 124, 148, 112)
const GREEN_DOOR := Rect2(276, 162, 28, 36)
const SHELTER_ROOM := Rect2(160, 30, 160, 52)
const SHELTER_DOOR := Rect2(222, 82, 36, 18)
const FLOORS: Array[Rect2] = [CORRIDOR, POWER_ROOM, POWER_DOOR, GREEN_ROOM, GREEN_DOOR, SHELTER_ROOM, SHELTER_DOOR]
const ROOMS: Array[Rect2] = [CORRIDOR, POWER_ROOM, GREEN_ROOM, SHELTER_ROOM]

const BATTERY_BANK := Rect2(40, 124, 64, 20)
const POWER_CONSOLE := Rect2(116, 124, 44, 18)
const CRATES := Rect2(32, 212, 24, 20)
const BEDS: Array[Rect2] = [Rect2(316, 132, 44, 28), Rect2(396, 132, 44, 28), Rect2(316, 196, 44, 28), Rect2(396, 196, 44, 28)]
const WATER_TANK := Rect2(368, 124, 20, 16)
const BENCHES: Array[Rect2] = [Rect2(168, 30, 40, 12), Rect2(272, 30, 40, 12)]

const POWER_SPOT := Vector2(138, 152)
const GREEN_SPOT := Vector2(378, 150)
const SHELTER_SPOT := Vector2(240, 42)
const SPAWN := Vector2(240, 216)
const RETURN_SPOT := Vector2(240, 242)

const PLAYER_SCENE := "res://scenes/characters/player.tscn"

# Crew mates: where they work, and the route each walks to the shelter (map units).
const TANAKA_HOME := Vector2(420, 178)
const TANAKA_ROUTE: Array[Vector2] = [Vector2(290, 180), Vector2(240, 180), Vector2(240, 92), Vector2(240, 62), Vector2(292, 54)]
const RIVERA_HOME := Vector2(72, 184)
const RIVERA_ROUTE: Array[Vector2] = [Vector2(190, 180), Vector2(240, 180), Vector2(240, 92), Vector2(240, 62), Vector2(188, 54)]

const C_REGOLITH := Color(0.33, 0.31, 0.4)
const C_CRATER := Color(0.27, 0.25, 0.34)
const C_HULL := Color(0.15, 0.14, 0.28)
const C_WALL := Color(0.27, 0.27, 0.43)
const C_FLOOR := Color(0.4, 0.42, 0.52)
const C_FLOOR_LINE := Color(0.36, 0.38, 0.48)
const C_STEEL := Color(0.55, 0.57, 0.68)
const C_DARK := Color(0.09, 0.09, 0.17)
const C_TEAL := Color(0.3, 0.88, 0.82)
const C_AMBER := Color(0.98, 0.68, 0.22)
const C_GREEN := Color(0.4, 0.82, 0.42)

var _status: Label
var _alert_backdrop: ColorRect
var _readout: Label
var _power_label: Label
var _green_label: Label
var _shelter_label: Label
var _shelter_note: Label
var _alert_started: bool = false
var _blink_on: bool = true
var _blink_time: float = 0.0
var _tint: CanvasModulate
var _vignette: ColorRect
var _tanaka: CrewMember
var _rivera: CrewMember
var _fx_time: float = 0.0


func _ready() -> void:
	# Safety net for opening this scene on its own from the editor.
	if MissionDirector.stage < MissionDirector.Stage.CHECKS:
		MissionDirector.begin_mission()

	GameState.set_flag(&"outpost_visited")
	_build_collision()
	_power_label = _world_label("", Vector2(POWER_ROOM.position.x + 4, POWER_ROOM.position.y - 14), C_TEAL)
	_green_label = _world_label("", Vector2(GREEN_ROOM.position.x + 4, GREEN_ROOM.position.y - 14), C_GREEN)
	_shelter_label = _world_label("", Vector2(SHELTER_ROOM.position.x + 4, SHELTER_ROOM.position.y - 14), C_AMBER)
	_shelter_note = _world_label("", Vector2(258, SHELTER_ROOM.position.y - 14), C_AMBER)

	_add_station(POWER_SPOT, "Check power", _on_power_used)
	_add_station(GREEN_SPOT, "Check crops", _on_green_used)
	_add_station(SHELTER_SPOT, "Shelter here", _on_shelter_used)
	_add_station(RETURN_SPOT, "Return to academy", _on_return_used)
	_world_label("ACADEMY TRANSIT", Vector2(211, 255), C_TEAL)

	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)
	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Node2D
	player.position = SPAWN * SCALE
	actors.add_child(player)
	HabitatCamera.mount(player, Vector2i(Vector2(MAP) * SCALE))

	# The whole outpost dims as the Sun drops behind the ridge.
	_tint = CanvasModulate.new()
	add_child(_tint)

	# Crew mates. After the storm they are already in the shelter.
	var sheltered := MissionDirector.stage >= MissionDirector.Stage.SHELTERED
	_tanaka = _add_crew(actors, "Dr. Tanaka", "res://assets/art/characters/npc_botanist.png",
		TANAKA_ROUTE[-1] if sheltered else TANAKA_HOME, _on_tanaka_used)
	_rivera = _add_crew(actors, "Engineer Rivera", "res://assets/art/characters/npc_engineer.png",
		RIVERA_ROUTE[-1] if sheltered else RIVERA_HOME, _on_rivera_used)

	_build_hud()
	MissionDirector.stage_changed.connect(_on_stage_changed)
	MissionDirector.objectives_changed.connect(_refresh)
	MissionDirector.storm_hour_passed.connect(func(_done: int, _total: int) -> void: _refresh())
	EventBus.resources_changed.connect(func(_snapshot: Dictionary) -> void: _refresh())
	_refresh()
	if MissionDirector.stage == MissionDirector.Stage.DEBRIEF:
		_show_debrief.call_deferred()


func _process(delta: float) -> void:
	_fx_time += delta
	var illum := ResourceSim.illumination_at(ResourceSim.hour)
	_tint.color = _tint.color.lerp(Color(0.56, 0.6, 0.9).lerp(Color.WHITE, illum), minf(1.0, delta * 3.0))
	var alert_now := MissionDirector.stage == MissionDirector.Stage.ALERT
	_vignette.color.a = (0.05 + 0.05 * sin(_fx_time * 5.0)) if alert_now else 0.0
	if ResourceSim.sep_active:
		queue_redraw()  # animate the particle storm outside
	if not MissionDirector.ui_open:
		_blink_time += delta
		if _blink_time >= 0.35:
			_blink_time = 0.0
			_blink_on = not _blink_on
			queue_redraw()


# ---------------------------------------------------------------- stations

func _add_station(pos: Vector2, prompt: String, handler: Callable) -> void:
	var station := Station.new()
	station.prompt = prompt
	station.position = (pos * SCALE).round()
	station.used.connect(handler)
	add_child(station)


func _add_crew(actors: Node2D, crew_name: String, sprite_path: String, at: Vector2, handler: Callable) -> CrewMember:
	var crew := CrewMember.new()
	crew.display_name = crew_name
	crew.texture = load(sprite_path)
	crew.position = (at * SCALE).round()
	crew.used.connect(handler)
	actors.add_child(crew)
	return crew


func _scaled(route: Array[Vector2]) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in route:
		out.append((p * SCALE).round())
	return out


func _on_tanaka_used() -> void:
	var line := "Phew. Thick walls and a good plan. Nice work, {name}."
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		line = "The lettuce loves these lamps, {name}. The lamp control is by the water tank."
		if MissionDirector.greenhouse_checked:
			line = "Thanks for setting the lamps, {name}. Now we wait and watch them grow."
	Dialogue.play(&"crew_tanaka", "Dr. Tanaka", PackedStringArray([line]))


func _on_rivera_used() -> void:
	var line := "We made it through. The battery tells the story, {name}."
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		line = "We landed with the battery half empty, {name}. Check the console on the north wall."
		if MissionDirector.power_checked:
			line = "Good call at the console. Watch that sunlight forecast."
	Dialogue.play(&"crew_rivera", "Engineer Rivera", PackedStringArray([line]))


## The alert begins: crew drop everything and head for the shelter, and the camera jolts.
func _start_alert_fx() -> void:
	_tanaka.enabled = false
	_rivera.enabled = false
	_rivera.say("Alarm! Shelter, now!")
	_rivera.walk(_scaled(RIVERA_ROUTE))
	var camera := get_viewport().get_camera_2d()
	if camera != null:
		var jolt := create_tween()
		for i in 8:
			jolt.tween_property(camera, "offset", Vector2(randf_range(-3, 3), randf_range(-2, 2)), 0.04)
		jolt.tween_property(camera, "offset", Vector2.ZERO, 0.05)
	await get_tree().create_timer(0.7, false).timeout
	_tanaka.say("Coming! Follow the arrows!")
	_tanaka.walk(_scaled(TANAKA_ROUTE))


func _on_return_used() -> void:
	if (MissionDirector.stage == MissionDirector.Stage.CHECKS and not MissionDirector.checks_done()) or MissionDirector.stage == MissionDirector.Stage.DEBRIEF:
		SceneRouter.go_to(&"academy_hub")
	else:
		Dialogue.play(&"return_locked", "Transit interlock", PackedStringArray([
			"Transit is closed during the radiation emergency. Head to the shelter."]))


func _on_power_used() -> void:
	var s := ResourceSim.get_snapshot()
	var body := "Battery: %d of %d cells charged.\nSolar panels: %s.\n" % [s["battery_cells"], s["battery_cells_total"], _sun_text()]
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		body += "The Sun slips behind a ridge in about 6 hours. Rover charging uses 3 power.\nChoose the reserve policy:"
		var panel := ChoicePanel.open(self, "POWER STATION", body, PackedStringArray([
			"Fill the battery: pause rover charging",
			"Keep charging the rover (more science)"]))
		panel.chosen.connect(_on_power_choice)
	else:
		ChoicePanel.open(self, "POWER STATION", body + "Rover charging: %s." % ("on" if ResourceSim.is_powered(&"rover") else "paused"), PackedStringArray(["OK"]))


func _on_power_choice(index: int) -> void:
	ResourceSim.set_load_enabled(&"rover", index == 1)
	MissionDirector.complete_check(&"power")
	_after_check()


func _on_green_used() -> void:
	var body := "Crop health: %d of 100.\n" % int(ResourceSim.crop_health)
	if MissionDirector.stage == MissionDirector.Stage.CHECKS:
		body += "Grow lights use 3 power. Conservation mode dims them: 1.5 power, and the crops hold steady instead of growing.\nChoose the plan:"
		var panel := ChoicePanel.open(self, "GREENHOUSE", body, PackedStringArray([
			"Full grow lights (crops keep growing)",
			"Conservation mode (saves power)"]))
		panel.chosen.connect(_on_green_choice)
	else:
		ChoicePanel.open(self, "GREENHOUSE", body + "Grow lights: %s." % _lamp_text(), PackedStringArray(["OK"]))


func _on_green_choice(index: int) -> void:
	ResourceSim.set_greenhouse_conservation(index == 1)
	MissionDirector.complete_check(&"greenhouse")
	_after_check()


func _after_check() -> void:
	_refresh()
	if MissionDirector.checks_done() and not _alert_started:
		_alert_started = true
		_alert_sequence()


func _alert_sequence() -> void:
	await get_tree().create_timer(0.4, false).timeout
	Dialogue.play(&"shift", "Mission clock", PackedStringArray([
		"Routine checks done. %d hours of the shift pass while the crew works." % int(MissionDirector.config["shift_hours_before_alert"])]))
	await EventBus.dialogue_ended
	MissionDirector.start_alert()
	var first := "RADIATION ALERT! Training scenario: this solar particle event is fictional."
	if MissionDirector.sep_is_real:
		first = "RADIATION ALERT! NASA recorded a solar particle event on %s. This is an archived record, replayed in our simulation." % MissionDirector.sep_time_text()
	Dialogue.play(&"alert", "Mission Control", PackedStringArray([
		first,
		"Walk NORTH to the SHIELDED SHELTER and press E at the hatch control. The storm clock runs while you walk."]))


func _on_shelter_used() -> void:
	match MissionDirector.stage:
		MissionDirector.Stage.ALERT:
			var s := ResourceSim.get_snapshot()
			var body := "Thick walls block most storm particles in here.\nThe Sun is also about to go behind a ridge (that is the terrain, not the storm), so power is tight.\nBattery: %d of %d cells. What stays on while the crew shelters?" % [s["battery_cells"], s["battery_cells_total"]]
			var panel := ChoicePanel.open(self, "SHELTER: you are inside the shield", body, PackedStringArray([
				"Pause science. Keep full grow lights.",
				"Keep science. Crops in conservation mode.",
				"Pause science AND conservation mode (saves most)."]))
			panel.chosen.connect(_on_shelter_choice)
		MissionDirector.Stage.CHECKS:
			Dialogue.play(&"shelter_info", "Shelter", PackedStringArray([
				"This is the most shielded room in the outpost. Come here when the radiation alert sounds."]))
		_:
			pass


func _on_shelter_choice(index: int) -> void:
	MissionDirector.confirm_shelter(index)
	_refresh()


func _on_stage_changed(stage: int) -> void:
	_refresh()
	if stage == MissionDirector.Stage.ALERT:
		_start_alert_fx()
	elif stage == MissionDirector.Stage.DEBRIEF:
		_tanaka.enabled = true
		_rivera.enabled = true
	if stage == MissionDirector.Stage.DEBRIEF:
		_show_debrief.call_deferred()


# ---------------------------------------------------------------- debrief

func _show_debrief() -> void:
	var starved_hours := ResourceSim.hours_run - ResourceSim.life_support_ok_hours
	var result := "Steady outpost"
	var why := "The shelter's shielding blocked most storm particles, and your power plan kept the battery above empty through the shadow."
	if not MissionDirector.reached_shelter:
		result = "Caught outside the shield"
		why = "The crew stayed outside the shelter for the whole storm, so exposure climbed every hour."
	elif starved_hours > 0:
		result = "Life Support lost power"
		why = "The battery emptied in the dark, so even Life Support lost power. Saving more power before the shadow prevents this."
	elif ResourceSim.emergency_shutoffs > 0:
		result = "Close call"
		why = "The battery ran out, so the outpost shut off %d lower-priority load(s) to protect Life Support." % ResourceSim.emergency_shutoffs
	if MissionDirector.reached_shelter and MissionDirector.hours_unsheltered >= 4:
		why += " Reaching the shelter sooner would lower exposure."

	var shelter_line := "Shelter: never reached"
	if MissionDirector.reached_shelter:
		shelter_line = "Shelter: reached after %d storm hour(s) outside" % MissionDirector.hours_unsheltered
	var text := "%s\nSimulated exposure: %.1f game units\nLowest battery: %.1f of %d units\nLife Support powered: %d of %d hours\nCrops: %d of 100     Science: %d points\nWHY: %s" % [
		shelter_line, ResourceSim.exposure_log, ResourceSim.battery_min, int(ResourceSim.battery_capacity),
		ResourceSim.life_support_ok_hours, ResourceSim.hours_run,
		int(ResourceSim.crop_health), ResourceSim.science_points, why]
	var panel := ChoicePanel.open(self, "DEBRIEF: " + result, text, PackedStringArray([
		"Retry the mission (keeps your astronaut)", "Source notes", "Return to the academy"]), false)
	panel.chosen.connect(_on_debrief_choice)


func _on_debrief_choice(index: int) -> void:
	if index == 0:
		MissionDirector.begin_mission()
		SceneRouter.go_to(&"outpost")
	elif index == 1:
		_show_sources()
	else:
		SceneRouter.go_to(&"academy_hub")


func _show_sources() -> void:
	var text := "Training scenario: the solar particle event in this run is FICTIONAL."
	if MissionDirector.sep_is_real:
		text = "Event: NASA CCMC DONKI solar energetic particle record (ARCHIVED copy, retrieved %s).\nID: %s\nTime: %s. Instrument: %s.\nLink: %s" % [
			MissionDirector.sep_retrieved, MissionDirector.sep_event_id(), MissionDirector.sep_time_text(),
			MissionDirector.sep_instrument(), MissionDirector.sep_link()]
	text += "\nThis record is a detection near Earth, NOT a radiation dose at a lunar outpost. Exposure, battery and power are simplified game units, and time is compressed. The sunlight shadow comes from terrain, not from the storm."
	var panel := ChoicePanel.open(self, "SOURCE NOTES", text, PackedStringArray(["Back to debrief"]), false)
	panel.chosen.connect(func(_i: int) -> void: _show_debrief())


# ---------------------------------------------------------------- HUD

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	# Soft amber pulse over the whole screen during the alert.
	_vignette = ColorRect.new()
	_vignette.color = Color(1.0, 0.6, 0.15, 0.0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_vignette)
	for r: Rect2 in [Rect2(4, 4, 138, 24), Rect2(164, 5, 152, 24)]:
		var back := ColorRect.new()
		back.color = Color(0.05, 0.05, 0.12, 0.8)
		back.position = r.position
		back.size = r.size
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(back)
		if r.position.x > 100:
			_alert_backdrop = back
			back.hide()
	_status = Label.new()
	_status.position = Vector2(169, 5)
	_status.add_theme_font_size_override("font_size", 9)
	_status.modulate = C_AMBER
	layer.add_child(_status)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 8)
	_readout.add_theme_constant_override("line_spacing", -2)
	_readout.position = Vector2(8, 4)
	layer.add_child(_readout)


func _refresh() -> void:
	var d := MissionDirector
	_status.text = ""
	if d.stage == d.Stage.ALERT:
		_status.text = "RADIATION ALERT  •  SHELTER NORTH\nStorm hour %d/%d" % [d.storm_hours_done, d.storm_hours_total()]
	elif d.stage == d.Stage.SHELTERED:
		_status.text = "SHELTERING  •  Hour %d/%d" % [d.storm_hours_done, d.storm_hours_total()]
	_alert_backdrop.visible = not _status.text.is_empty()
	_readout.text = "Hour %d   Battery %d/%d cells\nSun: %s" % [
		ResourceSim.hour, ResourceSim.battery_cells(), ResourceSim.battery_cells_total(), _sun_text()]
	_power_label.text = "POWER   %sRover: %s" % ["[x] " if d.power_checked else "", "charging" if ResourceSim.is_powered(&"rover") else "paused"]
	_green_label.text = "GREENHOUSE   %sLamps: %s" % ["[x] " if d.greenhouse_checked else "", _lamp_text()]
	_shelter_label.text = "SHELTER"
	_shelter_note.text = "GO HERE!" if d.stage == d.Stage.ALERT else "shielded"
	queue_redraw()


func _sun_text() -> String:
	var illum := ResourceSim.illumination_at(ResourceSim.hour)
	if illum >= 0.9:
		return "full sun"
	if illum > 0.0:
		return "low sun"
	return "in shadow"


func _lamp_text() -> String:
	if not ResourceSim.is_powered(&"greenhouse"):
		return "off"
	return "saving" if ResourceSim.greenhouse_conservation else "full"


func _world_label(text: String, pos: Vector2, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.position = (pos * SCALE).round()
	l.modulate = color
	l.z_index = 1
	add_child(l)
	return l


# ---------------------------------------------------------------- collision

func _build_collision() -> void:
	var cols := MAP.x / CELL
	var rows := MAP.y / CELL
	var props: Array[Rect2] = [BATTERY_BANK, POWER_CONSOLE, CRATES, WATER_TANK]
	props.append_array(BEDS)
	props.append_array(BENCHES)

	# 1 = walkable floor cell.
	var grid := PackedByteArray()
	grid.resize(cols * rows)
	for row in rows:
		for col in cols:
			var p := Vector2(col * CELL + CELL * 0.5, row * CELL + CELL * 0.5)
			var walkable := false
			for f in FLOORS:
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
				box.size = Vector2((col - run_start) * CELL, CELL) * SCALE
				shape.shape = box
				shape.position = Vector2(run_start * CELL, row * CELL) * SCALE + box.size * 0.5
				body.add_child(shape)
				run_start = -1


# ---------------------------------------------------------------- drawing

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * SCALE)
	var stage := MissionDirector.stage
	var alert := stage == MissionDirector.Stage.ALERT

	# Lunar ground.
	draw_rect(Rect2(0, 0, MAP.x, MAP.y), C_REGOLITH)
	for crater: Vector3 in [Vector3(60, 60, 16), Vector3(420, 70, 12), Vector3(110, 255, 10), Vector3(360, 258, 8), Vector3(455, 30, 6), Vector3(20, 100, 7)]:
		draw_circle(Vector2(crater.x, crater.y), crater.z, C_CRATER)
		draw_arc(Vector2(crater.x, crater.y), crater.z, 0.0, TAU, 20, C_REGOLITH.lightened(0.12), 1.0)

	for i in 150:
		var p := Vector2((i * 139 + 17) % MAP.x, (i * 83 + 11) % MAP.y)
		draw_rect(Rect2(p, Vector2(2, 1)), C_REGOLITH.lightened(0.07 if i % 3 == 0 else 0.02))

	# Rover parked outside the power room. Its cable and light show whether it is charging.
	var rover := Vector2(60, 252)
	if ResourceSim.is_powered(&"rover"):
		draw_line(rover + Vector2(-9, -1), Vector2(40, 243), C_AMBER.darkened(0.2), 1.0)
	draw_rect(Rect2(rover + Vector2(-9, -5), Vector2(18, 8)), C_STEEL)
	draw_rect(Rect2(rover + Vector2(-6, -9), Vector2(8, 4)), C_WALL.lightened(0.25))
	for wheel_x in [-8, -1, 6]:
		draw_rect(Rect2(rover + Vector2(wheel_x, 3), Vector2(3, 3)), C_DARK)
	if ResourceSim.is_powered(&"rover"):
		draw_rect(Rect2(rover + Vector2(6, -8), Vector2(2, 2)), C_TEAL if _blink_on else C_DARK)

	# Solar particle storm: fast streaks across the open ground (a visualisation; real particles are invisible).
	if ResourceSim.sep_active:
		for i in 80:
			var sx := fmod(i * 97.0 + _fx_time * 520.0, MAP.x + 40.0) - 20.0
			var sy := fmod(i * 53.0 + i * i * 7.0 + _fx_time * 300.0, MAP.y + 40.0) - 20.0
			draw_line(Vector2(sx, sy), Vector2(sx - 7, sy - 4), Color(1.0, 0.85, 0.5, 0.6), 1.0)

	# Hulls. The shelter gets a much thicker shell with caution stripes.
	var thick := SHELTER_ROOM.grow_individual(12, 24, 12, 10)
	draw_rect(thick, C_HULL.lightened(0.08))
	for i in int(thick.size.x / 8.0):
		if i % 2 == 0:
			draw_rect(Rect2(thick.position.x + i * 8, thick.position.y, 8, 3), C_AMBER)
	for f in FLOORS:
		draw_rect(f.grow_individual(9, 19, 9, 10), C_DARK)
		draw_rect(f.grow_individual(7, 18, 7, 7), C_HULL)
		draw_rect(Rect2(f.position.x - 6, f.end.y + 3, f.size.x + 12, 1), C_STEEL.darkened(0.35))
	for room in ROOMS:
		draw_rect(Rect2(room.position.x, room.position.y - 14, room.size.x, 14), C_WALL)
		draw_rect(Rect2(room.position.x, room.position.y - 14, room.size.x, 2), C_STEEL.darkened(0.24))
		draw_rect(Rect2(room.position.x, room.position.y - 2, room.size.x, 2), C_DARK)

	# Floors (low contrast) with faint tile lines.
	for f in FLOORS:
		draw_rect(f, C_FLOOR)
		var x := f.position.x + 16.0
		while x < f.end.x:
			draw_line(Vector2(x, f.position.y), Vector2(x, f.end.y), C_FLOOR_LINE, 1.0)
			x += 16.0
		var y := f.position.y + 16.0
		while y < f.end.y:
			draw_line(Vector2(f.position.x, y), Vector2(f.end.x, y), C_FLOOR_LINE, 1.0)
			y += 16.0

	for room in ROOMS:
		for i in range(4, int(room.size.x) - 6, 16):
			var p := room.position + Vector2(i, -13)
			draw_rect(Rect2(p, Vector2(12, 12)), C_HULL.lightened(0.06), false, 1.0)
			draw_rect(Rect2(p + Vector2(1, 1), Vector2(1, 2)), C_STEEL.darkened(0.25))
	for y in range(114, 244, 16):
		for x in [208, 268]:
			draw_rect(Rect2(x, y, 3, 7), C_TEAL.darkened(0.35 if _blink_on or y % 3 == 0 else 0.52))

	# Door thresholds (amber).
	for door: Rect2 in [POWER_DOOR, GREEN_DOOR]:
		draw_rect(Rect2(door.position.x, door.position.y, 2, door.size.y), C_AMBER)
		draw_rect(Rect2(door.end.x - 2, door.position.y, 2, door.size.y), C_AMBER)
	for i in 5:
		draw_rect(Rect2(SHELTER_DOOR.position.x + 2 + i * 7, SHELTER_DOOR.position.y + 6, 4, 6), C_AMBER if i % 2 == 0 else C_DARK)
	# Entry airlock at the bottom of the corridor.
	draw_rect(Rect2(222, 250, 36, 5), C_STEEL)
	draw_rect(Rect2(226, 251, 6, 3), C_TEAL)
	draw_rect(Rect2(248, 251, 6, 3), C_TEAL)

	# --- Power room: battery bank shows the real charge, console with amber switches.
	draw_rect(BATTERY_BANK, C_DARK)
	var cells := ResourceSim.battery_cells()
	for i in ResourceSim.battery_cells_total():
		var cell := Rect2(BATTERY_BANK.position.x + 1 + i * 8, BATTERY_BANK.position.y + 3, 6, 14)
		var cell_color := C_TEAL if i < cells else C_HULL.lightened(0.1)
		if i == cells and ResourceSim.last_generation > ResourceSim.last_demand and _blink_on:
			cell_color = C_TEAL.darkened(0.5)  # the next cell pulses while charging
		draw_rect(cell, cell_color)
		draw_rect(Rect2(cell.position.x + 2, cell.position.y - 2, 2, 2), C_STEEL)
	draw_rect(POWER_CONSOLE, C_STEEL)
	draw_rect(Rect2(POWER_CONSOLE.position.x + 3, POWER_CONSOLE.position.y + 2, 22, 9), C_TEAL.darkened(0.25))
	for i in 4:
		draw_rect(Rect2(POWER_CONSOLE.position.x + 28 + i * 4, POWER_CONSOLE.position.y + 4, 2, 6), C_AMBER)
	# Lightning bolt symbol on the console screen.
	draw_colored_polygon(PackedVector2Array([
		Vector2(130, 127), Vector2(126, 131), Vector2(129, 131), Vector2(127, 135), Vector2(132, 130), Vector2(129, 130)]), C_AMBER)
	draw_rect(CRATES, C_WALL.lightened(0.1))
	draw_rect(Rect2(CRATES.position + Vector2(2, 2), Vector2(9, 16)), C_STEEL.darkened(0.2))
	draw_rect(Rect2(CRATES.position + Vector2(13, 2), Vector2(9, 16)), C_STEEL.darkened(0.2))

	for crate_x in [33, 45]:
		draw_line(Vector2(crate_x, 217), Vector2(crate_x + 9, 217), C_AMBER.darkened(0.4), 1.0)
	# --- Greenhouse: beds, grow lamps that dim in conservation mode, water tank control.
	var lamps_on := ResourceSim.is_powered(&"greenhouse")
	var saving := ResourceSim.greenhouse_conservation
	var plant := C_GREEN
	var lamp := Color(1.0, 0.95, 0.6)
	if not lamps_on:
		plant = Color(0.36, 0.45, 0.3)
		lamp = C_DARK
	elif saving:
		plant = C_GREEN.darkened(0.25)
		lamp = C_AMBER.darkened(0.35)
	for bed in BEDS:
		draw_rect(bed, C_STEEL.darkened(0.3))
		draw_rect(bed.grow(-2), Color(0.3, 0.22, 0.18))
		for rowi in 3:
			for coli in 5:
				var seed := bed.position + Vector2(6 + coli * 8, 6 + rowi * 7)
				draw_rect(Rect2(seed + Vector2(0, 1), Vector2(4, 4)), plant.darkened(0.35))
				draw_rect(Rect2(seed + Vector2(1, 0), Vector2(3, 3)), plant)
				draw_rect(Rect2(seed + Vector2(2, 0), Vector2(1, 1)), plant.lightened(0.26))
		draw_rect(Rect2(bed.position.x + 4, bed.position.y, bed.size.x - 8, 2), lamp)
	draw_rect(WATER_TANK, C_STEEL)
	draw_rect(WATER_TANK.grow(-3), C_TEAL.darkened(0.1))
	draw_rect(Rect2(WATER_TANK.position.x + 8, WATER_TANK.end.y - 3, 4, 3), C_AMBER)

	# --- Shelter: benches, hatch control and beacon (flashes during an alert).
	for bench in BENCHES:
		draw_rect(bench, Color(0.75, 0.42, 0.25))
		draw_rect(Rect2(bench.position.x, bench.end.y - 3, bench.size.x, 3), Color(0.5, 0.28, 0.2))
	draw_rect(Rect2(228, 18, 24, 11), C_STEEL)
	draw_rect(Rect2(231, 20, 18, 7), C_AMBER if (alert and _blink_on) else C_AMBER.darkened(0.4))
	# Shield symbol on the hatch control.
	draw_colored_polygon(PackedVector2Array([
		Vector2(236, 21), Vector2(244, 21), Vector2(244, 24), Vector2(240, 27), Vector2(236, 24)]), C_DARK)
	var beacon := Vector2(240, 10)
	draw_circle(beacon, 4.0, C_AMBER if (not alert or _blink_on) else C_DARK)
	if alert and _blink_on:
		draw_arc(beacon, 7.0, 0.0, TAU, 16, C_AMBER, 1.0)

	# --- Station floor markers (shape + colour, so they don't rely on colour alone).
	for spot: Vector2 in [POWER_SPOT, GREEN_SPOT, SHELTER_SPOT, RETURN_SPOT]:
		draw_arc(spot, 7.0, 0.0, TAU, 16, C_TEAL, 1.0)
		draw_rect(Rect2(spot - Vector2(1, 1), Vector2(2, 2)), C_TEAL)

	# --- Alert route: chevrons up the corridor to the shelter.
	if alert and _blink_on:
		var cy := 232.0
		while cy > 60.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(240, cy - 5), Vector2(246, cy + 2), Vector2(243, cy + 2), Vector2(240, cy - 1), Vector2(237, cy + 2), Vector2(234, cy + 2)]), C_AMBER)
			cy -= 18.0
