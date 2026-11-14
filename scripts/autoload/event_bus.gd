extends Node
## EventBus — the game's global signal hub (autoload).
##
## Declares signals only. Holds NO state and has NO logic.
## Rule: systems never call each other's scenes directly. They emit a signal here,
## and whoever cares connects to it. Add new signals here (one owner: the lead)
## so everyone codes against the same names.
##
## Naming: snake_case, past tense ("something_changed", "event_started").

@warning_ignore_start("unused_signal")

# --- Time & simulation (emitted by ResourceSim) ---
signal game_hour_passed(hour: int)
signal resources_changed(snapshot: Dictionary)
signal load_toggled(load_id: StringName, enabled: bool)
signal brownout(load_id: StringName)

# --- NASA data (emitted by NasaData) ---
## record: normalized SpaceWeatherRecord dictionary (see docs, "NASA Data Manager pipeline").
signal space_weather_ready(record: Dictionary)

# --- Mission events (emitted by MissionEvents) ---
signal mission_event_started(event_id: StringName)
signal mission_choice_made(event_id: StringName, choice_index: int)
signal mission_event_resolved(event_id: StringName)

# --- Progression (emitted by GameState) ---
signal flag_set(flag: StringName, value: Variant)
signal score_changed(axis: StringName, total: int)
signal certification_earned(cert_id: StringName)

# --- Dialogue, scenes, Science Library ---
signal dialogue_started(dialogue_id: StringName)
signal dialogue_ended(dialogue_id: StringName)
signal scene_change_requested(scene_id: StringName)
signal science_entry_unlocked(entry_id: StringName)

@warning_ignore_restore("unused_signal")
