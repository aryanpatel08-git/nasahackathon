extends Node2D
## Academy hub — one room, three mentors, the Power Console training and the exit hatch.
## The room is drawn with flat shapes in the game palette (indigo/steel base, amber for
## briefing and caution, teal for powered equipment, green for plants).
## Art pass: replace _build_room() with a TileMapLayer; keep the "Actors" node.

const ROOM := Vector2(480, 270)
const SCALE := 1.6
const HATCH := Vector2(424, 80)
const WALL_HEIGHT := 64.0
const NPC_SCENE := "res://scenes/characters/npc.tscn"
const PLAYER_SCENE := "res://scenes/characters/player.tscn"
const CONSOLE_SCENE := "res://scenes/minigames/power_console.tscn"
const COMMANDER_DATA := "res://data/npcs/commander.tres"

## Which NPCData goes where (feet position in pixels).
const NPC_SPOTS: Dictionary = {
	"res://data/npcs/commander.tres": Vector2(118, 106),
	"res://data/npcs/engineer.tres": Vector2(372, 150),
	"res://data/npcs/botanist.tres": Vector2(96, 196),
}

var _player: Node2D

var _console_open: bool = false


func _ready() -> void:
	# The outpost simulation only runs while a console is open.
	ResourceSim.paused = true

	_build_room()
	_add_landmark(Vector2(94, 84), "Read mission board", "Mission board", "The outpost has three branches: power west, greenhouse east, and shelter north.")
	_add_landmark(Vector2(52, 193), "Inspect plant bench", "Plant bench", "Grow lights help crops grow. Conservation mode gives the battery more time in the shade.")

	var actors := Node2D.new()
	actors.name = "Actors"
	actors.y_sort_enabled = true
	add_child(actors)

	var npc_scene := load(NPC_SCENE) as PackedScene
	for path: String in NPC_SPOTS:
		var npc := npc_scene.instantiate() as Npc
		npc.data = load(path) as NPCData
		npc.position = NPC_SPOTS[path] * SCALE
		actors.add_child(npc)

	var hatch := Station.new()
	hatch.prompt = "Travel to lunar outpost" if MissionDirector.can_graduate() else "Inspect locked exit"
	hatch.position = HATCH * SCALE
	hatch.used.connect(_on_hatch_used)
	add_child(hatch)

	var player := (load(PLAYER_SCENE) as PackedScene).instantiate() as Node2D
	player.position = (Vector2(424, 103) if GameState.get_flag(&"outpost_visited") else Vector2(240, 214)) * SCALE
	actors.add_child(player)

	_player = player
	HabitatCamera.mount(player, Vector2i(ROOM * SCALE))
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.certification_earned.connect(func(id: StringName) -> void:
		if id == &"power_console":
			hatch.prompt = "Travel to lunar outpost"
	)

	if MissionDirector.stage == MissionDirector.Stage.BRIEFING:
		_play_briefing.call_deferred()


func _add_landmark(at: Vector2, action: String, title: String, description: String) -> void:
	var station := Station.new()
	station.position = at * SCALE
	station.prompt = action
	station.used.connect(func() -> void:
		Dialogue.play(&"academy_landmark", title, PackedStringArray([description]))
	)
	add_child(station)


func _play_briefing() -> void:
	var data := load(COMMANDER_DATA) as NPCData
	Dialogue.play(data.id, "%s, %s" % [data.display_name, data.role], data.lines)


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


func _on_hatch_used() -> void:
	if MissionDirector.can_graduate():
		if not GameState.get_flag(&"outpost_visited"):
			MissionDirector.begin_mission()
		SceneRouter.go_to(&"outpost")
	else:
		Dialogue.play(&"hatch_locked", "Exit hatch", PackedStringArray([
			"LOCKED. Earn your Power Console certificate with Engineer Rivera first."]))


func _process(_delta: float) -> void:
	if GameState.get_flag(&"academy_explored") or Dialogue.is_active or MissionDirector.ui_open:
		return
	var zones: int = GameState.get_flag(&"academy_zones", 0)
	var visited := zones
	for i in NPC_SPOTS.size():
		var spot: Vector2 = NPC_SPOTS.values()[i] * SCALE
		if _player.position.distance_to(spot) < 64.0:
			visited |= 1 << i
	if visited != zones:
		GameState.set_flag(&"academy_zones", visited)
		if visited == 7:
			GameState.set_flag(&"academy_explored")


# ---------------------------------------------------------------- room drawing

func _build_room() -> void:
	var indigo := Color(0.16, 0.15, 0.29)
	var steel := Color(0.3, 0.31, 0.45)
	var amber := Color(0.96, 0.66, 0.25)
	var teal := Color(0.3, 0.85, 0.8)

	_rect(Rect2(0, 0, ROOM.x, WALL_HEIGHT), indigo)                               # back wall
	_rect(Rect2(0, WALL_HEIGHT - 5, ROOM.x, 5), Color(0.1, 0.1, 0.2))             # skirting
	_rect(Rect2(0, WALL_HEIGHT, ROOM.x, ROOM.y - WALL_HEIGHT), Color(0.25, 0.25, 0.36))  # steel floor
	_rect(Rect2(0, 150, ROOM.x, 44), Color(0.62, 0.48, 0.36))                     # warm walkway
	_rect(Rect2(214, WALL_HEIGHT, 52, ROOM.y - WALL_HEIGHT), Color(0.62, 0.48, 0.36))
	_rect(Rect2(0, 150, ROOM.x, 1), amber.darkened(0.3))
	_rect(Rect2(0, 193, ROOM.x, 1), amber.darkened(0.3))

	# Mission map board (amber = briefing).
	_rect(Rect2(70, 12, 96, 42), amber.darkened(0.45))
	_rect(Rect2(73, 15, 90, 36), Color(0.2, 0.22, 0.4))
	_rect(Rect2(98, 20, 40, 26), Color(0.62, 0.62, 0.7))
	for dot: Vector2 in [Vector2(108, 28), Vector2(122, 36), Vector2(130, 24)]:
		_rect(Rect2(dot, Vector2(3, 3)), Color(0.9, 0.3, 0.3))
	_label("MISSION MAP", Vector2(70, 2), amber)

	# Large lunar window with Earth.
	_rect(Rect2(196, 6, 88, 50), steel)
	_rect(Rect2(200, 10, 80, 42), Color(0.04, 0.04, 0.1))
	_rect(Rect2(200, 38, 80, 14), Color(0.55, 0.55, 0.62))
	_rect(Rect2(212, 34, 26, 5), Color(0.5, 0.5, 0.58))
	_rect(Rect2(256, 16, 10, 10), Color(0.3, 0.55, 0.95))
	_rect(Rect2(259, 18, 4, 4), Color(0.45, 0.8, 0.55))

	# Exit hatch (amber/black caution stripes + label).
	_rect(Rect2(400, 14, 48, 50), steel)
	_rect(Rect2(406, 22, 36, 42), Color(0.12, 0.12, 0.2))
	for i in 6:
		_rect(Rect2(400 + i * 8, 14, 4, 6), amber)
	_rect(Rect2(422, 22, 2, 42), steel)
	_label("EXIT HATCH", Vector2(398, 2), amber)

	# Rivera's training console (teal = powered equipment).
	_rect(Rect2(392, 112, 52, 20), steel)
	_rect(Rect2(396, 115, 30, 10), teal.darkened(0.2))
	_rect(Rect2(430, 116, 10, 4), amber)
	_label("POWER TRAINING", Vector2(380, 100), teal)
	_wall(Rect2(392, 112, 52, 20))

	# Dr. Tanaka's plant bench (green = crops).
	_rect(Rect2(28, 204, 44, 16), steel)
	for i in 4:
		_rect(Rect2(32 + i * 10, 198, 6, 8), Color(0.35, 0.75, 0.4))
	_label("PLANT LAB", Vector2(26, 222), Color(0.5, 0.9, 0.55))
	_wall(Rect2(28, 204, 44, 16))

	_add_details(steel, amber, teal)

	# Invisible walls so nobody walks out of the room.
	_wall(Rect2(0, 0, ROOM.x, WALL_HEIGHT + 8))
	_wall(Rect2(0, ROOM.y, ROOM.x, 16))
	_wall(Rect2(-16, 0, 16, ROOM.y))
	_wall(Rect2(ROOM.x, 0, 16, ROOM.y))


func _add_details(steel: Color, amber: Color, teal: Color) -> void:
	for x in range(8, 480, 16):
		if x < 214 or x > 266:
			_rect(Rect2(x, 73, 1, 75), steel.darkened(0.25))
			_rect(Rect2(x, 196, 1, 74), steel.darkened(0.25))
	for y in [87, 108, 129, 212, 234, 256]:
		_rect(Rect2(4, y, 208, 1), steel.darkened(0.25))
		_rect(Rect2(268, y, 208, 1), steel.darkened(0.25))
	for x in [6, 42, 172, 288, 336, 370, 458]:
		_rect(Rect2(x, 6, 14, 48), steel.darkened(0.26))
		_rect(Rect2(x + 2, 8, 2, 41), steel.lightened(0.12))
		_rect(Rect2(x + 3, 55, 9, 3), teal.darkened(0.3))
	for x in range(8, 480, 20):
		_rect(Rect2(x, 168, 14, 1), amber.darkened(0.45))
	for y in [76, 198, 257]:
		_rect(Rect2(218, y, 43, 1), amber.darkened(0.35))
	for x in [8, 272, 448]:
		_rect(Rect2(x, 72, 24, 4), steel.darkened(0.58))
		_rect(Rect2(x + 2, 72, 20, 1), teal.darkened(0.35))
		for i in 5:
			_rect(Rect2(x + 3 + i * 4, 74, 2, 1), steel.lightened(0.14))
	for x in [162, 296]:
		_rect(Rect2(x, 224, 34, 20), steel.darkened(0.4))
		_rect(Rect2(x + 2, 224, 30, 13), Color("#805c64"))
		_rect(Rect2(x + 2, 225, 30, 3), Color("#b78481"))
		_wall(Rect2(x, 224, 34, 20))
	_label("CREW LOUNGE", Vector2(222, 242), amber)
	_label("BRIEFING", Vector2(113, 82), amber)
	for x in [400, 432]:
		_rect(Rect2(x, 120, 4, 3), amber)
		var glow := get_child(get_child_count() - 1) as ColorRect
		var tween := glow.create_tween().set_loops()
		tween.tween_property(glow, "modulate:a", 0.35, 0.8)
		tween.tween_property(glow, "modulate:a", 1.0, 1.15)


func _rect(r: Rect2, color: Color) -> void:
	var c := ColorRect.new()
	c.position = (r.position * SCALE).round()
	c.size = (r.end * SCALE).round() - c.position
	c.color = color
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)


func _label(text: String, pos: Vector2, color: Color) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 8)
	l.position = (pos * SCALE).round()
	l.modulate = color
	add_child(l)


func _wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size * SCALE
	shape.shape = box
	body.position = r.get_center() * SCALE
	body.add_child(shape)
	add_child(body)
