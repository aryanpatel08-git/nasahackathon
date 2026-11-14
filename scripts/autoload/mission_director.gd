extends Node
## MissionDirector — walks the game through its stages (autoload).
##
##   BRIEFING -> TRAINING -> GRADUATED -> CHECKS -> ALERT -> SHELTERED -> DEBRIEF
##
## Each stage only changes from a valid event (see the functions below), so rapid
## key presses can't skip a stage or finish a task twice.
##
## TIMING MODEL (kept in one place on purpose):
##   - Training: the clock runs only while the training panel is open and "Go" is pressed.
##   - Outpost routine checks: the clock is stopped. When both checks are done,
##     a fixed shift (shift_hours_before_alert) is simulated in one go.
##   - Alert: one game hour passes every seconds_per_storm_hour of real time, but
##     ONLY while the player is in control (not while a dialogue or panel is open).
##   - Sheltered: the rest of the storm is played out quickly, then the debrief opens.

enum Stage { BRIEFING, TRAINING, GRADUATED, CHECKS, ALERT, SHELTERED, DEBRIEF }

signal stage_changed(stage: int)
signal objectives_changed
signal storm_hour_passed(hours_done: int, hours_total: int)

const SEP_CACHE_PATH := "res://data/nasa/donki_sep_cached.json"
const CONFIG_PATH := "res://data/nasa/sep_replay_config.json"

## Scripted sunlight for the academy training (FICTIONAL training scenario).
const TRAINING_PATTERN: Array[float] = [1.0, 1.0, 0.5, 0.2, 0.0, 0.2, 0.5, 1.0, 1.0, 1.0]
const TRAINING_HOURS := 10
const TRAINING_START_BATTERY := 24.0

var stage: Stage = Stage.BRIEFING
var power_checked: bool = false
var greenhouse_checked: bool = false
var hours_unsheltered: int = 0
var storm_hours_done: int = 0
var reached_shelter: bool = false
var shelter_choice: int = -1

## The archived NASA record ({} if the file is missing) and whether it is real data.
var sep_record: Dictionary = {}
var sep_retrieved: String = ""
var sep_is_real: bool = false

var config: Dictionary = {
	"mission_start_hour": 4,
	"mission_start_battery": 20.0,
	"shift_hours_before_alert": 6,
	"storm_hours": 8,
	"seconds_per_storm_hour": 4.0,
	"shelter_readiness": 90.0,
}

## True while a station panel is open. Panels call push_ui() / pop_ui().
var ui_open: bool:
	get:
		return _ui_count > 0

var _ui_count: int = 0


func _ready() -> void:
	_load_data()
	EventBus.game_hour_passed.connect(_on_game_hour_passed)


func _process(_delta: float) -> void:
	# Outside the outpost the training panel controls the clock itself.
	if stage < Stage.CHECKS:
		return
	ResourceSim.paused = not (stage == Stage.ALERT and not ui_open and not Dialogue.is_active)


func push_ui() -> void:
	_ui_count += 1


func pop_ui() -> void:
	_ui_count = maxi(0, _ui_count - 1)


# ------------------------------------------------------------- stage changes

func start_new_game() -> void:
	_set_stage(Stage.BRIEFING)


func finish_briefing() -> void:
	if stage == Stage.BRIEFING:
		_set_stage(Stage.TRAINING)


func pass_training() -> void:
	if not can_graduate():
		GameState.earn_certification(&"power_console")
		GameState.add_score(&"training", 1)
	if stage == Stage.BRIEFING or stage == Stage.TRAINING:
		_set_stage(Stage.GRADUATED)


func can_graduate() -> bool:
	return &"power_console" in GameState.certifications


## Starts (or restarts) the outpost mission. Keeps the astronaut profile;
## resets every mission and simulation value.
func begin_mission() -> void:
	power_checked = false
	greenhouse_checked = false
	hours_unsheltered = 0
	storm_hours_done = 0
	reached_shelter = false
	shelter_choice = -1
	_ui_count = 0
	ResourceSim.paused = true
	ResourceSim.time_scale = 1.0
	ResourceSim.seconds_per_game_hour = float(config["seconds_per_storm_hour"])
	ResourceSim.shelter_readiness = float(config["shelter_readiness"])
	ResourceSim.reset_state(int(config["mission_start_hour"]), float(config["mission_start_battery"]))
	_set_stage(Stage.CHECKS)
	objectives_changed.emit()


func complete_check(check_id: StringName) -> void:
	if stage != Stage.CHECKS:
		return
	if check_id == &"power":
		power_checked = true
	elif check_id == &"greenhouse":
		greenhouse_checked = true
	objectives_changed.emit()


func checks_done() -> bool:
	return power_checked and greenhouse_checked


## Simulates the routine shift, then starts the solar particle alert.
func start_alert() -> void:
	if stage != Stage.CHECKS or not checks_done():
		return
	for i in int(config["shift_hours_before_alert"]):
		ResourceSim.advance_hour()
	ResourceSim.sep_active = true
	_set_stage(Stage.ALERT)


## choice: 0 = pause science, 1 = crops in conservation mode, 2 = pause both.
func confirm_shelter(choice: int) -> void:
	if stage != Stage.ALERT:
		return
	reached_shelter = true
	shelter_choice = choice
	ResourceSim.crew_sheltered = true
	ResourceSim.set_load_enabled(&"rover", false)  # nobody drives during a storm
	ResourceSim.set_load_enabled(&"greenhouse", true)
	ResourceSim.set_load_enabled(&"science", choice == 1)
	ResourceSim.set_greenhouse_conservation(choice != 0)
	_set_stage(Stage.SHELTERED)
	_run_sheltered()


func storm_hours_total() -> int:
	return int(config["storm_hours"])


# ------------------------------------------------------------- NASA record text

func sep_event_id() -> String:
	return str(sep_record.get("sepID", "no record"))


func sep_time_text() -> String:
	# "2024-05-10T13:35Z" -> "2024-05-10 at 13:35 UTC"
	var t := str(sep_record.get("eventTime", ""))
	if t.length() >= 16:
		return "%s at %s UTC" % [t.substr(0, 10), t.substr(11, 5)]
	return "an unknown time"


func sep_instrument() -> String:
	var list: Array = sep_record.get("instruments", [])
	if list.is_empty():
		return "unknown instrument"
	return str((list[0] as Dictionary).get("displayName", "unknown instrument"))


func sep_link() -> String:
	return str(sep_record.get("link", ""))


# ------------------------------------------------------------- internals

func _set_stage(new_stage: Stage) -> void:
	stage = new_stage
	stage_changed.emit(stage)


func _on_game_hour_passed(_hour: int) -> void:
	if stage != Stage.ALERT:
		return
	hours_unsheltered += 1
	storm_hours_done += 1
	storm_hour_passed.emit(storm_hours_done, storm_hours_total())
	if storm_hours_done >= storm_hours_total():
		_finish_storm()


func _run_sheltered() -> void:
	while storm_hours_done < storm_hours_total():
		await get_tree().create_timer(0.45, false).timeout
		if stage != Stage.SHELTERED:
			return  # the mission was restarted meanwhile
		ResourceSim.advance_hour()
		storm_hours_done += 1
		storm_hour_passed.emit(storm_hours_done, storm_hours_total())
	await get_tree().create_timer(0.45, false).timeout
	if stage == Stage.SHELTERED:
		_finish_storm()


func _finish_storm() -> void:
	ResourceSim.sep_active = false
	_set_stage(Stage.DEBRIEF)


func _load_data() -> void:
	var cfg: Variant = _read_json(CONFIG_PATH)
	if cfg is Dictionary:
		for key: String in config.keys():
			if (cfg as Dictionary).has(key):
				config[key] = (cfg as Dictionary)[key]
	var cache: Variant = _read_json(SEP_CACHE_PATH)
	if cache is Dictionary and (cache as Dictionary).get("record") is Dictionary:
		sep_record = (cache as Dictionary)["record"]
		sep_retrieved = str((cache as Dictionary).get("_retrieved_utc", ""))
		sep_is_real = str((cache as Dictionary).get("_provenance", "")) == "ARCHIVED"
	else:
		push_warning("MissionDirector: no cached NASA record; the alert will be labelled fictional.")


func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	return JSON.parse_string(text)
