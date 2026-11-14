extends Node
## ResourceSim — outpost power, life support, greenhouse and radiation (autoload).
##
## Advances one GAME HOUR per tick. Every tick it:
##   1. makes solar power from the current illumination,
##   2. charges or drains the battery,
##   3. sheds the least important loads if the battery is empty,
##   4. updates life support, crops, science and radiation exposure,
##   5. emits EventBus.resources_changed(snapshot).
##
## IMPORTANT: every number here is a SIMPLIFIED GAME UNIT chosen for gameplay,
## not a real engineering value. The UI must say so.

## Paths of the loads on the grid. Add a new LoadDef .tres file and list it here.
const LOAD_PATHS: Array[String] = [
	"res://data/loads/life_support.tres",
	"res://data/loads/heaters.tres",
	"res://data/loads/comms.tres",
	"res://data/loads/greenhouse.tres",
	"res://data/loads/science.tres",
	"res://data/loads/rover.tres",
]

## Simplified, repeating sunlight pattern for a south-polar site (FICTIONAL, for gameplay).
## 1.0 = arrays in full sun, 0.0 = arrays in shadow. One entry per game hour, 36-hour cycle.
## Near the lunar south pole, light comes and goes with the terrain instead of a simple
## two-week day and night. This pattern is a stand-in for that idea.
const ILLUMINATION_PATTERN: Array[float] = [
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,  # 10 h full sun
	0.6, 0.6, 0.6,                                      # sun dropping behind a ridge
	0.2, 0.2, 0.2,
	0.0, 0.0, 0.0, 0.0,                                 # 4 h in shadow
	0.3, 0.3, 0.3,
	0.7, 0.7, 0.7,
	1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0,  # 10 h full sun
]

@export var seconds_per_game_hour: float = 2.0
@export var solar_capacity: float = 16.0      # power units at full sun
@export var battery_capacity: float = 40.0    # power-unit-hours
@export var battery_cell_size: float = 5.0    # one "cell" on the console

# --- Clock ---
var hour: int = 0
var paused: bool = false
var time_scale: float = 1.0

# --- Power ---
var battery: float = 28.0
var loads: Array[LoadDef] = []
var enabled: Dictionary = {}  # StringName -> bool
var last_generation: float = 0.0
var last_demand: float = 0.0

# --- Life support, food, science ---
var life_support: Dictionary = {"oxygen": 100.0, "water": 100.0, "co2_scrub": 100.0}
var crop_health: float = 80.0
var science_points: int = 0

# --- Radiation (game units; never present these as real doses) ---
var shelter_readiness: float = 30.0  # 0-100: how much shielding the outpost has built
var exposure_log: float = 0.0        # running total, simulated game units
var sep_active: bool = false         # set by MissionEvents during a solar particle event
var crew_sheltered: bool = false     # set by MissionEvents when the player shelters the crew

var safety_incidents: int = 0

## Greenhouse lamps dimmed: half the power, crops hold steady instead of growing.
var greenhouse_conservation: bool = false
## Scripted sunlight (training). Empty = use ILLUMINATION_PATTERN.
var illumination_override: Array[float] = []
var science_progress: float = 0.0

# --- Mission statistics (reset by reset_state) ---
var battery_min: float = 28.0
var hours_run: int = 0
var life_support_ok_hours: int = 0
var emergency_shutoffs: int = 0

var _accum: float = 0.0


func _ready() -> void:
	for path in LOAD_PATHS:
		var def := load(path) as LoadDef
		if def == null:
			push_error("ResourceSim: could not load LoadDef at %s" % path)
			continue
		loads.append(def)
		enabled[def.id] = def.starts_enabled or not def.can_disable
	loads.sort_custom(func(a: LoadDef, b: LoadDef) -> bool: return a.priority < b.priority)
	last_generation = solar_capacity * illumination_at(hour)
	last_demand = current_demand()
	# Wait one frame so UI scenes have connected before the first snapshot goes out.
	_emit_changed.call_deferred()


func _process(delta: float) -> void:
	if paused:
		return
	_accum += delta * time_scale
	while _accum >= seconds_per_game_hour:
		_accum -= seconds_per_game_hour
		advance_hour()


# ---------------------------------------------------------------- public API

## Turns a load on or off. Returns false if the change isn't allowed.
func set_load_enabled(load_id: StringName, on: bool) -> bool:
	var def := get_load(load_id)
	if def == null:
		push_warning("ResourceSim: unknown load '%s'" % load_id)
		return false
	if not on and not def.can_disable:
		return false
	if enabled[load_id] == on:
		return true
	enabled[load_id] = on
	last_demand = current_demand()
	EventBus.load_toggled.emit(load_id, on)
	_emit_changed()
	return true


## Puts the whole simulation back to a clean start. Used by training and by each mission (re)start.
func reset_state(start_hour: int, start_battery: float, pattern: Array[float] = []) -> void:
	hour = start_hour
	illumination_override = pattern
	battery = clampf(start_battery, 0.0, battery_capacity)
	for def in loads:
		enabled[def.id] = def.starts_enabled or not def.can_disable
	greenhouse_conservation = false
	life_support = {"oxygen": 100.0, "water": 100.0, "co2_scrub": 100.0}
	crop_health = 70.0
	science_points = 0
	science_progress = 0.0
	exposure_log = 0.0
	sep_active = false
	crew_sheltered = false
	safety_incidents = 0
	battery_min = battery
	hours_run = 0
	life_support_ok_hours = 0
	emergency_shutoffs = 0
	_accum = 0.0
	last_generation = solar_capacity * illumination_at(hour)
	last_demand = current_demand()
	_emit_changed()


func set_greenhouse_conservation(on: bool) -> void:
	if greenhouse_conservation == on:
		return
	greenhouse_conservation = on
	last_demand = current_demand()
	_emit_changed()


## Power a load draws right now (greenhouse lamps use half in conservation mode).
func draw_of(def: LoadDef) -> float:
	if def.id == &"greenhouse" and greenhouse_conservation:
		return def.power_draw * 0.5
	return def.power_draw


func is_powered(load_id: StringName) -> bool:
	return enabled.get(load_id, false)


func get_load(load_id: StringName) -> LoadDef:
	for def in loads:
		if def.id == load_id:
			return def
	return null


func current_demand() -> float:
	var total := 0.0
	for def in loads:
		if enabled[def.id]:
			total += draw_of(def)
	return total


func illumination_at(game_hour: int) -> float:
	if not illumination_override.is_empty():
		return illumination_override[clampi(game_hour, 0, illumination_override.size() - 1)]
	return ILLUMINATION_PATTERN[posmod(game_hour, ILLUMINATION_PATTERN.size())]


## Sunlight for the next `count` hours, starting with the current hour.
func illumination_forecast(count: int) -> Array[float]:
	var out: Array[float] = []
	for i in count:
		out.append(illumination_at(hour + i))
	return out


func battery_cells() -> int:
	return int(floor(battery / battery_cell_size))


func battery_cells_total() -> int:
	return int(floor(battery_capacity / battery_cell_size))


## Everything the UI needs, as plain data. UI reads this; it never edits the sim directly.
func get_snapshot() -> Dictionary:
	return {
		"hour": hour,
		"illumination": illumination_at(hour),
		"generation": last_generation,
		"demand": last_demand,
		"battery": battery,
		"battery_capacity": battery_capacity,
		"battery_cells": battery_cells(),
		"battery_cells_total": battery_cells_total(),
		"enabled": enabled.duplicate(),
		"life_support": life_support.duplicate(),
		"crop_health": crop_health,
		"science_points": science_points,
		"shelter_readiness": shelter_readiness,
		"exposure_log": exposure_log,
		"sep_active": sep_active,
		"crew_sheltered": crew_sheltered,
		"safety_incidents": safety_incidents,
		"greenhouse_conservation": greenhouse_conservation,
		"battery_min": battery_min,
		"hours_run": hours_run,
		"life_support_ok_hours": life_support_ok_hours,
		"emergency_shutoffs": emergency_shutoffs,
	}


# ---------------------------------------------------------------- simulation

func advance_hour() -> void:
	var illum := illumination_at(hour)

	# 1-2. Generate, then charge or drain the battery.
	last_generation = solar_capacity * illum
	last_demand = current_demand()
	var net := last_generation - last_demand
	battery = clampf(battery + net, 0.0, battery_capacity)

	# 3. Empty battery and still short of power: shut loads off, least important first.
	if battery <= 0.0 and net < 0.0:
		_shed_loads()

	# Even after shedding, the sun may not cover the always-on loads.
	# Then life support is "on" but starved of power for this hour.
	var starved := battery <= 0.0 and last_generation < last_demand
	if starved:
		EventBus.brownout.emit(&"life_support")

	battery_min = minf(battery_min, battery)
	hours_run += 1
	if not starved:
		life_support_ok_hours += 1

	# 4. Systems respond to whether they actually had power this hour.
	_update_life_support(illum, starved)
	_update_greenhouse()
	_update_science()
	_update_radiation()

	hour += 1
	EventBus.game_hour_passed.emit(hour)
	_emit_changed()


func _shed_loads() -> void:
	# loads is sorted most-important first, so walk it backwards.
	for i in range(loads.size() - 1, -1, -1):
		if last_generation >= last_demand:
			return
		var def := loads[i]
		if enabled[def.id] and def.can_disable:
			enabled[def.id] = false
			emergency_shutoffs += 1
			last_demand = current_demand()
			EventBus.load_toggled.emit(def.id, false)
			EventBus.brownout.emit(def.id)


func _update_life_support(illum: float, starved: bool) -> void:
	var change := 3.0 if is_powered(&"life_support") and not starved else -6.0
	# Without heaters, the cold during shadow makes equipment work worse.
	if not is_powered(&"heaters") and illum < 0.3:
		change -= 2.0
	var was_ok := _life_support_ok()
	for key in life_support:
		life_support[key] = clampf(life_support[key] + change, 0.0, 100.0)
	if was_ok and not _life_support_ok():
		safety_incidents += 1


func _life_support_ok() -> bool:
	for key in life_support:
		if life_support[key] < 25.0:
			return false
	return true


func _update_greenhouse() -> void:
	# Full lamps: crops grow. Conservation: they hold steady. Lamps off: they slowly wilt.
	var change := -4.0
	if is_powered(&"greenhouse"):
		change = 0.0 if greenhouse_conservation else 2.0
	crop_health = clampf(crop_health + change, 0.0, 100.0)


func _update_science() -> void:
	# Automated experiments keep running at half speed while the crew shelters.
	if is_powered(&"science"):
		science_progress += 0.5 if crew_sheltered else 1.0
	# A charged rover brings back samples, but not during a solar particle event.
	if is_powered(&"rover") and not sep_active:
		science_progress += 0.5
	science_points = int(science_progress)


func _update_radiation() -> void:
	var shield := shelter_readiness / 100.0
	# Galactic cosmic rays: slow and steady, and shielding only helps a little.
	exposure_log += 0.1 * (1.0 - 0.2 * shield)
	# Solar particle events: intense but very shieldable. Sheltering helps a lot.
	if sep_active:
		exposure_log += 2.0 * ((1.0 - 0.9 * shield) if crew_sheltered else 1.0)


func _emit_changed() -> void:
	EventBus.resources_changed.emit(get_snapshot())
