extends CanvasLayer
## FieldNotes — the astronaut's notebook of real space facts (autoload).
##
## Each note unlocks when the player meets the idea in the game:
##   FieldNotes.unlock(&"shelter")
## A small banner announces it; the notes are read from the pause menu or the mission report.
## Unlocked notes are stored as GameState flags ("note_<id>") so they are saved with the profile.
##
## Every fact below comes from the NASA page named in its `source`. If you edit a note,
## check it against that page. `game` says how the idea shows up (and is simplified) in play.

signal unlocked(id: StringName)

const NOTES: Array[Dictionary] = [
	{
		"id": &"polar_sun",
		"title": "Sunlight at the pole",
		"hint": "Listen to Commander Okafor's briefing.",
		"body": "Near the Moon's poles the Sun never climbs more than about 1.5 degrees above the horizon. It circles the skyline instead of rising and setting, so every ridge and crater rim throws a very long shadow. NASA chose the South Pole region for its Moon Base, and warns that those shadows can interrupt solar power.",
		"game": "The sunlight forecast on the power console is an invented pattern that copies this idea.",
		"source": "NASA SVS, Shadows near the Moon's South Pole (svs.gsfc.nasa.gov/4893). NASA, The Harsh Environment of the Lunar South Pole (nasa.gov/reference/moonbase-environment).",
	},
	{
		"id": &"batteries",
		"title": "Batteries carry the dark",
		"hint": "Use a power console.",
		"body": "The International Space Station circles Earth about every 90 minutes and passes through 16 sunrises and sunsets a day. While it is in sunlight, about 60 percent of the electricity from its solar arrays goes into charging batteries. The batteries power the station every time Earth blocks the Sun.",
		"game": "Your outpost does the same thing: bank power while the Sun is up, spend it in the shadow.",
		"source": "NASA, Sunrise Through the Solar Arrays (nasa.gov/image-feature/sunrise-through-the-solar-arrays). NASA, Space Station Facts and Figures.",
	},
	{
		"id": &"veggie",
		"title": "Salad grown in orbit",
		"hint": "Talk to Dr. Tanaka or inspect some plants.",
		"body": "On 10 August 2015 astronauts on the International Space Station ate red romaine lettuce they had grown themselves in a plant chamber called Veggie. Veggie lights its plants with red, blue and green LEDs. Red and blue do most of the growing, which is why space gardens glow pink.",
		"game": "Grow lights cost power. Conservation mode keeps crops alive but stops them growing.",
		"source": "NASA, Meals Ready to Eat: Expedition 44 Crew Members Sample Leafy Greens Grown on Space Station (2015).",
	},
	{
		"id": &"donki",
		"title": "NASA's space-weather logbook",
		"hint": "Read the space-weather desk in the academy.",
		"body": "DONKI is the Space Weather Database Of Notifications, Knowledge, Information. It was built at the Community Coordinated Modeling Center at NASA's Goddard Space Flight Center. It catalogs solar flares, coronal mass ejections, particle events and geomagnetic storms, and links the events that caused one another.",
		"game": "The radiation alert in this game replays one real DONKI record. See 'The storm we replay'.",
		"source": "NASA CCMC, DONKI (ccmc.gsfc.nasa.gov/tools/DONKI).",
	},
	{
		"id": &"may2024",
		"title": "The storm we replay",
		"hint": "Read the space-weather desk in the academy.",
		"body": "From 7 to 11 May 2024 the Sun fired strong flares and at least seven coronal mass ejections toward Earth. NASA called it the strongest solar storm to reach Earth in two decades. On 10 May at 13:35 UTC, DONKI logged a solar energetic particle event measured by a GOES satellite. That record triggers your alert.",
		"game": "The record is a detection near Earth. It is not a radiation dose on the Moon, and the game's exposure numbers are made up.",
		"source": "NASA, How NASA Tracked the Most Intense Solar Storm in Decades (science.nasa.gov). DONKI record 2024-05-10T13:35:00-SEP-001.",
	},
	{
		"id": &"sep",
		"title": "Particles from the Sun",
		"hint": "Hear a radiation alert.",
		"body": "Big eruptions on the Sun can hurl protons and other particles outward at enormous speed. They are called solar energetic particles. NASA scientists compare them to a sudden downpour: hard to predict, intense, and over in hours or days. They are a danger to astronauts who are outside Earth's protection.",
		"game": "During the alert, exposure climbs fast every hour the crew is outside the shelter.",
		"source": "NASA, How NASA Will Protect Astronauts From Space Radiation at the Moon (science.nasa.gov).",
	},
	{
		"id": &"shields",
		"title": "Earth's two shields",
		"hint": "Listen to Mission Control during an alert.",
		"body": "On Earth, a magnetic bubble called the magnetosphere turns most solar particles aside, and the atmosphere stops the ones that get through. The Moon has no thick atmosphere and no global magnetic field. A crew there has to bring its own protection: warnings, walls and a plan.",
		"game": "That is why Mission Control sends everyone to the shelter instead of telling them to wait it out.",
		"source": "NASA, How NASA Will Protect Astronauts From Space Radiation at the Moon (science.nasa.gov).",
	},
	{
		"id": &"shelter",
		"title": "Build a storm shelter",
		"hint": "Open the storm shelter hatch.",
		"body": "For a solar particle storm, NASA's Orion crews have a plan: pile stowage bags, food and water around a small space to make a dense shelter. The more mass between you and the Sun's particles, the lower your exposure.",
		"game": "The outpost shelter has thick walls lined with water tanks for the same reason. Its hatch is heavy: hold E to crank it open.",
		"source": "NASA, How NASA Will Protect Astronauts From Space Radiation at the Moon (science.nasa.gov).",
	},
	{
		"id": &"cosmic_rays",
		"title": "The steady drizzle",
		"hint": "Finish a mission.",
		"body": "A second kind of space radiation arrives all the time from far beyond the Sun: galactic cosmic rays. If solar particles are a downpour, NASA scientists call cosmic rays a steady drizzle. They are much harder to block. A shelter that stops solar particles does not keep cosmic rays out.",
		"game": "It is the small exposure that ticks up every hour, even when the crew is safe indoors.",
		"source": "NASA, How NASA Will Protect Astronauts From Space Radiation at the Moon (science.nasa.gov).",
	},
	{
		"id": &"simulation",
		"title": "What this game simplifies",
		"hint": "Finish a mission.",
		"body": "Power, battery cells, crop health and exposure are simple game units, not engineering numbers. Time is squeezed: one storm hour passes in four seconds. The sunlight pattern is invented. In real life a particle storm and a shadow have nothing to do with each other.",
		"game": "We put the storm and the shadow together on purpose, so you must protect the crew and the battery at once.",
		"source": "Lunar Life team. Settings: data/nasa/sep_replay_config.json and scripts/autoload/resource_sim.gd.",
	},
]

var _queue: Array[String] = []
var _banner: Control
var _showing: String = ""
var _left: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_banner = Control.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.draw.connect(_draw_banner)
	add_child(_banner)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.certification_earned.connect(func(_id: StringName) -> void: unlock(&"batteries"))
	MissionDirector.stage_changed.connect(func(stage: int) -> void:
		if stage == MissionDirector.Stage.DEBRIEF:
			unlock(&"cosmic_rays")
			unlock(&"simulation"))


func unlock(id: StringName) -> void:
	if is_unlocked(id):
		return
	var note := get_note(id)
	if note.is_empty():
		push_warning("FieldNotes: unknown note '%s'" % id)
		return
	GameState.set_flag(StringName("note_" + String(id)))
	EventBus.science_entry_unlocked.emit(id)
	unlocked.emit(id)
	_queue.append(str(note["title"]))


func is_unlocked(id: StringName) -> bool:
	return GameState.get_flag(StringName("note_" + String(id))) == true


func get_note(id: StringName) -> Dictionary:
	for note in NOTES:
		if note["id"] == id:
			return note
	return {}


func unlocked_count() -> int:
	var count := 0
	for note in NOTES:
		if is_unlocked(note["id"]):
			count += 1
	return count


func _on_dialogue_ended(id: StringName) -> void:
	match id:
		&"commander":
			unlock(&"polar_sun")
		&"botanist":
			unlock(&"veggie")
		&"alert":
			unlock(&"shields")


func _process(delta: float) -> void:
	_time += delta
	# Wait for a quiet moment: never cover a dialogue, a panel or a scene change.
	var busy := Dialogue.is_active or MissionDirector.ui_open or SceneRouter.is_transitioning() or get_tree().paused
	if _left > 0.0:
		if not busy:
			_left -= delta
		_banner.visible = not busy
		_banner.queue_redraw()
		if _left <= 0.0:
			_showing = ""
			_banner.queue_redraw()
	elif not _queue.is_empty() and not busy:
		_showing = _queue.pop_front()
		_left = 3.4
		_banner.visible = true
		Sfx.play(&"note")
		_banner.queue_redraw()


func _draw_banner() -> void:
	if _showing.is_empty():
		return
	var c := _banner
	var alpha := clampf(_left / 0.4, 0.0, 1.0) * clampf((3.4 - _left) / 0.2, 0.0, 1.0)
	var title := "FIELD NOTE"
	var w := maxf(UiKit.text_width(_showing, "body"), UiKit.text_width("Pause > Field notes")) + 34.0
	var box := Rect2(roundf((480.0 - w) / 2.0), 40.0 - roundf((1.0 - alpha) * 6.0), w, 30)
	c.draw_rect(box, Color(UiKit.INK, 0.94 * alpha))
	c.draw_rect(box, Color(UiKit.VIOLET, alpha), false, 1.0)
	# Notebook icon.
	var icon := box.position + Vector2(6, 6)
	c.draw_rect(Rect2(icon, Vector2(12, 16)), Color(UiKit.VIOLET, alpha))
	c.draw_rect(Rect2(icon + Vector2(2, 2), Vector2(8, 12)), Color(UiKit.INK, alpha))
	for row in 3:
		c.draw_rect(Rect2(icon + Vector2(3, 4 + row * 3), Vector2(6, 1)), Color(UiKit.VIOLET, alpha))
	UiKit.draw_text(c, box.position + Vector2(24, 10), title + " UNLOCKED", "small", Color(UiKit.VIOLET, alpha))
	UiKit.draw_text(c, box.position + Vector2(24, 22), _showing, "body", Color(UiKit.TEXT, alpha))
