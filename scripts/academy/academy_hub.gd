extends Node2D
## Astronaut Academy — one hall: three mentors, things to read, the Power Console
## training and the lander dock that leads to the outpost.
##
##   - floor plan: scripts/academy/academy_layout.gd
##   - picture:    assets/art/world/academy_bg.png (painted by tools/art/paint_world.py)
##   - live parts: _draw() below (hologram, screens, lamps, markers, lettering)
##   - people and the player live under the y-sorted "Actors" node

const NPC_SCENE := "res://scenes/characters/npc.tscn"
const PLAYER_SCENE := "res://scenes/characters/player.tscn"
const CONSOLE_SCENE := "res://scenes/minigames/power_console.tscn"
const CINEMATIC_SCRIPT := "res://scripts/ui/mission_cinematic.gd"
const ART_DIR := "res://assets/art/world/"
const COMMANDER_DATA := "res://data/npcs/commander.tres"

## Which NPCData stands where (feet position in pixels).
const NPC_SPOTS: Dictionary = {
	"res://data/npcs/commander.tres": AcademyLayout.COMMANDER_SPOT,
	"res://data/npcs/engineer.tres": AcademyLayout.ENGINEER_SPOT,
	"res://data/npcs/botanist.tres": AcademyLayout.BOTANIST_SPOT,
}

var _bg: Texture2D
var _art: Dictionary = {}
var _player: Node2D
var _hatch: Station
var _console_open: bool = false
var _cinematic_layer: CanvasLayer
var _time: float = 0.0


func _ready() -> void:
	# The outpost simulation only runs while a console is open.
	ResourceSim.paused = true
	_bg = load(ART_DIR + "academy_bg.png")
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ART_DIR + "academy_art.json"))
	if parsed is Dictionary:
		_art = parsed
	_build_walls()

	_add_landmark(AcademyLayout.BOARD_SPOT, "Read mission board", "Mission board", &"briefing", PackedStringArray([
		"Outpost plan: power room to the west, greenhouse to the east, storm shelter to the north.",
		"The pins mark the Moon's south pole. The Sun stays low there, so ridges throw long shadows across the solar panels."]),
		[&"polar_sun"])
	var record := "Tonight's drill uses a made-up alert."
	if MissionDirector.sep_is_real:
		record = "Record %s: solar energetic particles on %s, measured by %s." % [
			MissionDirector.sep_event_id(), MissionDirector.sep_time_text(), MissionDirector.sep_instrument()]
	_add_landmark(AcademyLayout.DESK_SPOT, "Use space-weather desk", "Space-weather desk", &"weather", PackedStringArray([
		"These screens show DONKI, NASA's logbook of solar flares, eruptions and particle storms.",
		record,
		"Your radiation alert replays this real record. How the outpost copes is our simulation."]),
		[&"donki", &"may2024"])
	_add_landmark(AcademyLayout.PLANT_SPOT, "Inspect plant bench", "Plant bench", &"plants", PackedStringArray([
		"Lettuce, tomatoes, wheat and herbs under grow lights.",
		"The lights cost power. In conservation mode the plants stop growing but stay healthy."]),
		[&"veggie"])

	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	var npc_scene := load(NPC_SCENE) as PackedScene
	for path: String in NPC_SPOTS:
		var npc := npc_scene.instantiate() as Npc
		npc.data = load(path) as NPCData
		npc.position = NPC_SPOTS[path]
		actors.add_child(npc)

	_hatch = Station.new()
	_hatch.objective_id = &"exit"
	_hatch.position = AcademyLayout.HATCH_SPOT
	_hatch.extra_reach = 8.0
	_hatch.used.connect(_on_hatch_used)
	add_child(_hatch)
	_refresh_hatch()

	_player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Node2D
	_player.position = AcademyLayout.HATCH_ARRIVAL if GameState.get_flag(&"outpost_visited") else AcademyLayout.SPAWN
	actors.add_child(_player)

	_add_navigation(_player)
	HabitatCamera.mount(_player, AcademyLayout.MAP)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.certification_earned.connect(func(id: StringName) -> void:
		if id == &"power_console":
			_refresh_hatch()
			_show_story_moment(0)
	)

	if MissionDirector.stage == MissionDirector.Stage.BRIEFING:
		_play_briefing.call_deferred()


func _refresh_hatch() -> void:
	_hatch.prompt = "Board the lander" if MissionDirector.can_graduate() else "Lander dock (locked)"


func _add_navigation(player: Node2D) -> void:
	var nav := NavigationFloor.new()
	nav.facility = "Academy"
	nav.bounds = Vector2(AcademyLayout.MAP)
	nav.player = player
	nav.floors = [AcademyLayout.FLOOR]
	nav.links = {"Outpost": "exit"}
	nav.add_point("entrance", "Crew lounge", "Lounge", "Where recruits arrive.", "hatch", AcademyLayout.SPAWN)
	nav.add_point("commander", "Commander Okafor", "Okafor", "Speak to the commander for your briefing.", "crew", AcademyLayout.COMMANDER_SPOT)
	nav.add_point("briefing", "Mission board", "Board", "Read about the outpost layout.", "station", AcademyLayout.BOARD_SPOT)
	nav.add_point("weather", "Space-weather desk", "Weather", "See the NASA record behind the alert.", "station", AcademyLayout.DESK_SPOT)
	nav.add_point("rivera", "Engineer Rivera", "Rivera", "Speak to Rivera to start training.", "crew", AcademyLayout.ENGINEER_SPOT)
	nav.add_point("botanist", "Dr. Tanaka", "Tanaka", "Ask the botanist about the greenhouse.", "crew", AcademyLayout.BOTANIST_SPOT)
	nav.add_point("plants", "Plant bench", "Plants", "Learn how grow lights use power.", "station", AcademyLayout.PLANT_SPOT)
	nav.add_point("exit", "Lander dock", "Lander", "Earn your certificate to unlock departure.", "hatch", AcademyLayout.HATCH_SPOT + Vector2(0, 10))
	add_child(nav)
	var objective_hud := CanvasLayer.new()
	objective_hud.set_script(load("res://scripts/ui/objective_hud.gd"))
	add_child(objective_hud)
	objective_hud.call_deferred(&"configure", nav)


func _add_landmark(at: Vector2, action: String, title: String, objective_id: StringName, lines: PackedStringArray, notes: Array) -> void:
	var station := Station.new()
	station.position = at
	station.prompt = action
	station.objective_id = objective_id
	station.used.connect(func() -> void:
		Dialogue.play(&"academy_landmark", title, lines)
		for note: StringName in notes:
			FieldNotes.unlock(note)
	)
	add_child(station)


# ---------------------------------------------------------------- story

func _play_briefing() -> void:
	if not GameState.get_flag(&"intro_cinematic_seen"):
		_start_intro_cinematic()
		return
	var data := load(COMMANDER_DATA) as NPCData
	Dialogue.play(data.id, "%s, %s" % [data.display_name, data.role], data.lines)


func _start_intro_cinematic() -> void:
	MissionDirector.push_ui()
	_cinematic_layer = CanvasLayer.new()
	_cinematic_layer.layer = 45
	add_child(_cinematic_layer)
	var cinematic := Control.new()
	cinematic.name = "MissionCinematic"
	cinematic.set_script(load(CINEMATIC_SCRIPT))
	cinematic.add_to_group(&"fullscreen_story")
	cinematic.connect(&"finished", _on_cinematic_finished)
	_cinematic_layer.add_child(cinematic)


func _on_cinematic_finished() -> void:
	MissionDirector.pop_ui()
	GameState.set_flag(&"intro_cinematic_seen")
	if is_instance_valid(_cinematic_layer):
		_cinematic_layer.queue_free()
	_cinematic_layer = null
	_play_briefing.call_deferred()


func _on_dialogue_ended(id: StringName) -> void:
	if id == &"commander":
		MissionDirector.finish_briefing()
	elif id == &"engineer" and not GameState.get_flag(&"outpost_visited"):
		_open_training()


func _open_training() -> void:
	if _console_open:
		return
	_console_open = true
	var layer := CanvasLayer.new()
	layer.layer = 30
	add_child(layer)
	var console := (load(CONSOLE_SCENE) as PackedScene).instantiate()
	console.set("training_mode", true)
	console.set("embedded", true)
	console.tree_exited.connect(func() -> void:
		_console_open = false
		if is_instance_valid(layer) and not layer.is_queued_for_deletion():
			layer.queue_free()
	)
	layer.add_child(console)


func _show_story_moment(moment_id: int) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 46
	add_child(layer)
	var moment := Control.new()
	moment.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	moment.set_script(load("res://scripts/ui/story_moment.gd"))
	moment.set("moment", moment_id)
	layer.add_child(moment)
	moment.tree_exited.connect(layer.queue_free)


func _on_hatch_used() -> void:
	if MissionDirector.can_graduate():
		if not GameState.get_flag(&"outpost_visited"):
			MissionDirector.begin_mission()
		SceneRouter.go_to(&"outpost")
	else:
		Dialogue.play(&"hatch_locked", "Lander dock", PackedStringArray([
			"LOCKED. Earn your Power Console certificate with Engineer Rivera first."]))


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()
	if GameState.get_flag(&"academy_explored") or Dialogue.is_active or MissionDirector.ui_open:
		return
	# "Explore the academy": walk near each of the three wings once.
	var zones: int = GameState.get_flag(&"academy_zones", 0)
	var visited := zones
	var spots: Array[Vector2] = [AcademyLayout.DESK_SPOT, AcademyLayout.ENGINEER_SPOT, AcademyLayout.BOTANIST_SPOT]
	for i in spots.size():
		if _player.position.distance_to(spots[i]) < 96.0:
			visited |= 1 << i
	if visited != zones:
		GameState.set_flag(&"academy_zones", visited)
		if visited == 7:
			GameState.set_flag(&"academy_explored")


# ---------------------------------------------------------------- collision

func _build_walls() -> void:
	var floor_rect := AcademyLayout.FLOOR
	var size := Vector2(AcademyLayout.MAP)
	_wall(Rect2(0, 0, size.x, floor_rect.position.y))
	_wall(Rect2(0, floor_rect.end.y, size.x, size.y - floor_rect.end.y + 16))
	_wall(Rect2(-16, 0, 16 + floor_rect.position.x, size.y))
	_wall(Rect2(floor_rect.end.x, 0, size.x - floor_rect.end.x + 16, size.y))
	for blocker in AcademyLayout.blockers():
		_wall(blocker)


func _wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.position = r.get_center()
	body.add_child(shape)
	add_child(body)


# ---------------------------------------------------------------- drawing

func _rect_of(key: String, index: int = -1) -> Rect2:
	var value: Variant = _art.get(key, [])
	if index >= 0:
		value = (value as Array)[index]
	var a := value as Array
	if a.size() < 4:
		return Rect2()
	return Rect2(a[0], a[1], a[2], a[3])


func _draw() -> void:
	draw_texture(_bg, Vector2.ZERO)
	var blink := int(_time * 2.5) % 2 == 0

	# --- Lettering.
	var sign_at := _art.get("desk_sign", [62, 18]) as Array
	UiKit.draw_text(self, Vector2(sign_at[0], sign_at[1] + 6), "SPACE WEATHER  /  NASA DONKI", "small", UiKit.VIOLET)
	UiKit.draw_text(self, Vector2(AcademyLayout.TRAINING_CONSOLE.position.x - 26, 22), "POWER LAB", "small", UiKit.TEAL, 60)
	var hatch_door := AcademyLayout.HATCH_DOOR
	draw_string(UiKit.font_small, Vector2(hatch_door.position.x - 4, AcademyLayout.FLOOR.position.y + 20), "LANDER DOCK", HORIZONTAL_ALIGNMENT_CENTER, hatch_door.size.x + 8, 8, Color("b9722f"))
	draw_string(UiKit.font_small, Vector2(AcademyLayout.PLANT_BENCH.position.x, AcademyLayout.PLANT_BENCH.end.y + 14), "PLANT LAB", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("5fb86a"))
	draw_string(UiKit.font_small, Vector2(286, 334), "CREW LOUNGE", HORIZONTAL_ALIGNMENT_CENTER, 196, 8, Color("d9a066"))

	# --- Space-weather monitors: a trace, the record's time stamp and a bar display.
	var monitors := _art.get("monitors", []) as Array
	if monitors.size() >= 3:
		var m0 := _rect_of("monitors", 0)
		var trace := PackedVector2Array()
		for i in 15:
			var x := m0.position.x + 2 + i * 2
			var spike := 9.0 * exp(-pow(float(i) - 5.0 - fmod(_time * 3.0, 6.0), 2.0) * 0.5)
			trace.append(Vector2(x, m0.end.y - 5 - spike - sin(_time * 4.0 + i) * 1.0))
		draw_polyline(trace, UiKit.VIOLET, 1.0)
		var m1 := _rect_of("monitors", 1)
		draw_string(UiKit.font_small, m1.position + Vector2(2, 9), "SEP", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.VIOLET)
		var stamp := MissionDirector.sep_time_text().substr(0, 10) if MissionDirector.sep_is_real else "DRILL"
		draw_string(UiKit.font_small, m1.position + Vector2(2, 19), stamp.substr(2), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.AMBER)
		var m2 := _rect_of("monitors", 2)
		for i in 7:
			var h := 3.0 + absf(sin(_time * 1.6 + i * 0.9)) * 12.0
			draw_rect(Rect2(m2.position.x + 3 + i * 4, m2.end.y - 2 - roundf(h), 3, roundf(h)), UiKit.VIOLET if i != 3 else UiKit.AMBER)
	var leds := _art.get("rack_leds", []) as Array
	for i in leds.size():
		var on := int(_time * 3.0 + i * 1.7) % (3 + i % 4) != 0
		draw_rect(Rect2(leds[i][0], leds[i][1], 2, 1), (UiKit.TEAL if i % 5 else UiKit.AMBER) if on else Color("12142a"))

	# --- Training screen: the scripted shadow window of the lesson.
	var screen := _rect_of("training_screen")
	var pattern := MissionDirector.TRAINING_PATTERN
	for i in pattern.size():
		var h := 3.0 + roundf(pattern[i] * 16.0)
		draw_rect(Rect2(screen.position.x + 4 + i * 7, screen.end.y - 3 - h, 5, h), UiKit.AMBER if pattern[i] > 0.0 else Color("27304f"))
	draw_string(UiKit.font_small, screen.position + Vector2(4, 9), "SUNLIGHT", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiKit.TEAL)
	var cursor := int(_time * 2.0) % pattern.size()
	draw_rect(Rect2(screen.position.x + 4 + cursor * 7, screen.end.y - 2, 5, 1), Color.WHITE)

	# --- Lander dock lamp: red while locked, green once certified.
	var lamp := _rect_of("hatch_lamp")
	var open := MissionDirector.can_graduate()
	draw_rect(lamp, (UiKit.GREEN if blink else UiKit.GREEN.darkened(0.4)) if open else (UiKit.RED if blink else UiKit.RED.darkened(0.5)))

	# --- Plant bench grow light.
	var bench := _rect_of("plant_bench")
	draw_rect(_rect_of("plant_lamp"), Color("f6b7ff"))
	draw_rect(Rect2(bench.position + Vector2(3, 4), Vector2(bench.size.x - 6, bench.size.y - 12)), Color(0.96, 0.72, 1.0, 0.14 + 0.03 * sin(_time * 3.0)))

	# --- Holo table: a slowly turning Moon with the outpost site marked.
	var holo_at := _art.get("holo", [384, 215]) as Array
	var holo := Vector2(holo_at[0], holo_at[1])
	var globe := holo + Vector2(0, -22 + roundf(sin(_time * 1.5) * 1.5))
	for ring in 3:
		draw_arc(holo + Vector2(0, -2), 20.0 - ring * 5.0, PI, TAU, 16, Color(UiKit.TEAL, 0.1 + ring * 0.05), 1.0)
	draw_circle(globe, 14.0, Color(0.37, 0.89, 0.83, 0.2))
	draw_arc(globe, 14.0, 0.0, TAU, 24, Color(UiKit.TEAL, 0.9), 1.0)
	for i in 5:
		# Craters slide across the disc and wrap, which reads as rotation.
		var u := fposmod(_time * 0.12 + float(i) * 0.23, 1.0) * 2.0 - 1.0
		var v := [-0.45, 0.3, -0.1, 0.55, 0.1][i] as float
		var edge := sqrt(maxf(0.0, 1.0 - v * v))
		if absf(u) < edge:
			draw_rect(Rect2((globe + Vector2(u * 13.0, v * 13.0)).round(), Vector2(2 if absf(u) < edge * 0.7 else 1, 2)), Color(UiKit.TEAL, 0.75))
	draw_rect(Rect2(globe + Vector2(-1, 11), Vector2(2, 2)), UiKit.AMBER if blink else UiKit.AMBER_DIM)
	for y in range(-12, 13, 4):
		var half := sqrt(maxf(0.0, 196.0 - float(y * y)))
		draw_rect(Rect2(globe.x - half, globe.y + y, half * 2.0, 1), Color(UiKit.TEAL, 0.12))

	# --- Markers: where to stand, and a brighter one on the current lesson.
	for spot: Vector2 in [AcademyLayout.BOARD_SPOT, AcademyLayout.DESK_SPOT, AcademyLayout.PLANT_SPOT]:
		draw_arc(spot + Vector2(0, 2), 6.0, 0.0, TAU, 14, Color(UiKit.TEAL, 0.5), 1.0)
		draw_rect(Rect2(spot + Vector2(-1, 1), Vector2(2, 2)), Color(UiKit.TEAL, 0.7))
	var hatch_spot := AcademyLayout.HATCH_SPOT + Vector2(0, 8)
	var hatch_color := UiKit.GREEN if open else UiKit.AMBER_DIM
	draw_arc(hatch_spot, 7.0, 0.0, TAU, 14, hatch_color, 1.0)
	if MissionDirector.stage == MissionDirector.Stage.TRAINING and not Dialogue.is_active and not _console_open:
		var pulse := fmod(_time * 1.2, 1.0)
		var at := AcademyLayout.ENGINEER_SPOT + Vector2(0, -2)
		draw_arc(at, 10.0 + pulse * 8.0, 0.0, TAU, 20, Color(UiKit.TEAL, 1.0 - pulse), 1.0)
	elif open and MissionDirector.stage == MissionDirector.Stage.GRADUATED:
		var pulse := fmod(_time * 1.2, 1.0)
		draw_arc(hatch_spot, 8.0 + pulse * 8.0, 0.0, TAU, 20, Color(UiKit.GREEN, 1.0 - pulse), 1.0)
