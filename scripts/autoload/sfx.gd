extends Node
## Sfx — sound effects, room ambience and the music pad (autoload).
##   Sfx.play(&"confirm")
## Short bleeps are generated here in code. Longer sounds (the hatch, the alarm, the
## ambience and the pad) are synthesised by tools/audio/make_audio.py into assets/audio/.
## It listens to game signals so most scenes never call it directly. Press N to mute.

const RATE := 22050
const AUDIO_DIR := "res://assets/audio/"
## File-based sounds: name -> [file, volume in dB].
const FILES: Dictionary = {
	&"hatch_open": ["hatch_open.wav", -4.0],
	&"hatch_close": ["hatch_close.wav", -4.0],
	&"hatch_seal": ["hatch_seal.wav", -3.0],
	&"alert": ["alarm.wav", -9.0],
	&"note": ["note.wav", -8.0],
	&"success": ["success.wav", -6.0],
	&"travel": ["travel.wav", -8.0],
}
const HUM_DB := -19.0
const PAD_DB := -15.0
const SILENT_DB := -60.0

var muted: bool = false

var _streams: Dictionary = {}   # StringName -> AudioStream
var _gains: Dictionary = {}     # StringName -> float (dB)
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _alert_timer: float = 0.0
var _last_fail_msec: int = 0
var _hum: AudioStreamPlayer
var _pad: AudioStreamPlayer
var _hum_goal: float = SILENT_DB
var _pad_goal: float = SILENT_DB


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# name: [wave, volume, [[frequency Hz, seconds], ...]]
	_make(&"talk", "square", 0.07, [[560.0, 0.022]])
	_make(&"next", "square", 0.12, [[520.0, 0.04], [780.0, 0.05]])
	_make(&"open", "triangle", 0.26, [[440.0, 0.04], [660.0, 0.06]])
	_make(&"confirm", "square", 0.14, [[660.0, 0.05], [990.0, 0.08]])
	_make(&"cancel", "square", 0.12, [[440.0, 0.05], [330.0, 0.07]])
	_make(&"step", "triangle", 0.2, [[110.0, 0.03]])
	_make(&"tick", "square", 0.08, [[1200.0, 0.02]])
	_make(&"switch", "square", 0.12, [[300.0, 0.03], [450.0, 0.03]])
	_make(&"fail", "saw", 0.14, [[220.0, 0.14], [165.0, 0.24]])
	_make(&"crank", "saw", 0.1, [[95.0, 0.035], [70.0, 0.03]])
	for sound: StringName in FILES:
		var stream := load(AUDIO_DIR + String(FILES[sound][0])) as AudioStream
		if stream != null:
			_streams[sound] = stream
			_gains[sound] = float(FILES[sound][1])

	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_hum = _loop_player("ambience_habitat.wav")
	_pad = _loop_player("music_pad.wav")

	EventBus.dialogue_started.connect(func(_id: StringName) -> void: play(&"open"))
	EventBus.certification_earned.connect(func(_id: StringName) -> void: play(&"success"))
	EventBus.brownout.connect(_on_brownout)
	EventBus.load_toggled.connect(func(_id: StringName, _on: bool) -> void: play(&"switch"))
	MissionDirector.stage_changed.connect(_on_stage_changed)
	MissionDirector.storm_hour_passed.connect(func(_done: int, _total: int) -> void: play(&"tick"))


func _loop_player(file: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var stream := load(AUDIO_DIR + file) as AudioStreamWAV
	if stream != null:
		if stream.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			# The .import file normally sets the loop; this covers a reset import.
			stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
			stream.loop_begin = 0
			stream.loop_end = int(stream.get_length() * stream.mix_rate)
		player.stream = stream
	player.volume_db = SILENT_DB
	add_child(player)
	return player


func _process(delta: float) -> void:
	_update_loops(delta)
	if get_tree().paused:
		return
	# Repeating alarm while the storm clock is actually running.
	if MissionDirector.stage == MissionDirector.Stage.ALERT and not Dialogue.is_active and not MissionDirector.ui_open:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_alert_timer = 2.6
			play(&"alert")
	else:
		_alert_timer = 0.3


## Room hum inside the habitats, the pad on the menus and (quietly) in the academy.
func _update_loops(delta: float) -> void:
	var scene := get_tree().current_scene
	var where := String(scene.name) if scene != null else ""
	var storm := MissionDirector.stage == MissionDirector.Stage.ALERT
	_hum_goal = HUM_DB if where in ["AcademyHub", "Outpost"] else SILENT_DB
	match where:
		"TitleScreen", "CreateAstronaut":
			_pad_goal = PAD_DB
		"AcademyHub":
			_pad_goal = PAD_DB - 6.0
		"Outpost":
			_pad_goal = SILENT_DB if storm else PAD_DB - 9.0
		_:
			_pad_goal = SILENT_DB
	for entry: Array in [[_hum, _hum_goal], [_pad, _pad_goal]]:
		var player: AudioStreamPlayer = entry[0]
		var goal: float = entry[1]
		if player.stream == null:
			continue
		if goal > SILENT_DB and not player.playing:
			player.play()
		player.volume_db = move_toward(player.volume_db, goal, delta * 30.0)
		if goal <= SILENT_DB and player.playing and player.volume_db <= SILENT_DB + 0.5:
			player.stop()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute") and not get_viewport().gui_get_focus_owner() is LineEdit:
		set_muted(not muted)


func set_muted(value: bool) -> void:
	muted = value
	AudioServer.set_bus_mute(0, muted)
	if not muted:
		play(&"confirm")


func play(sound: StringName, pitch: float = 1.0) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
	p.volume_db = _gains.get(sound, -6.0)
	p.play()


func _on_brownout(_load_id: StringName) -> void:
	var now := Time.get_ticks_msec()
	if now - _last_fail_msec > 600:
		_last_fail_msec = now
		play(&"fail")


func _on_stage_changed(stage: int) -> void:
	if stage == MissionDirector.Stage.DEBRIEF:
		var starved := ResourceSim.hours_run - ResourceSim.life_support_ok_hours
		play(&"success" if MissionDirector.reached_shelter and starved == 0 else &"fail")


func _make(sound: StringName, wave: String, volume: float, notes: Array) -> void:
	var data := PackedByteArray()
	for note: Array in notes:
		var freq: float = note[0]
		var count := int(float(note[1]) * RATE)
		for i in count:
			var phase := fmod(freq * float(i) / RATE, 1.0)
			var v := 0.0
			match wave:
				"square":
					v = 1.0 if phase < 0.5 else -1.0
				"saw":
					v = phase * 2.0 - 1.0
				_:
					v = 1.0 - 4.0 * absf(phase - 0.5)
			# Short fade in and out so notes don't click.
			var env := minf(1.0, minf(float(i) / 60.0, float(count - i) / 200.0))
			var sample := int(clampf(v * env * volume, -1.0, 1.0) * 32000.0)
			data.append(sample & 0xFF)
			data.append((sample >> 8) & 0xFF)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	_streams[sound] = stream
	_gains[sound] = -6.0
