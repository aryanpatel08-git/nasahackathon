extends Node
## Sfx — tiny retro sound effects, generated in code (autoload). No audio files needed.
##   Sfx.play(&"confirm")
## Listens to game signals so most scenes never call it directly. Press M to mute.

const RATE := 22050

var muted: bool = false

var _streams: Dictionary = {}   # StringName -> AudioStreamWAV
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _alert_timer: float = 0.0
var _last_fail_msec: int = 0


func _ready() -> void:
	# name: [wave, volume, [[frequency Hz, seconds], ...]]
	_make(&"talk", "square", 0.10, [[620.0, 0.025]])
	_make(&"next", "square", 0.16, [[520.0, 0.04], [780.0, 0.05]])
	_make(&"open", "triangle", 0.30, [[440.0, 0.04], [660.0, 0.06]])
	_make(&"confirm", "square", 0.18, [[660.0, 0.05], [990.0, 0.08]])
	_make(&"cancel", "square", 0.16, [[440.0, 0.05], [330.0, 0.07]])
	_make(&"step", "triangle", 0.22, [[120.0, 0.03]])
	_make(&"tick", "square", 0.10, [[1200.0, 0.02]])
	_make(&"switch", "square", 0.14, [[300.0, 0.03], [450.0, 0.03]])
	_make(&"success", "square", 0.18, [[523.0, 0.09], [659.0, 0.09], [784.0, 0.09], [1047.0, 0.2]])
	_make(&"fail", "saw", 0.16, [[220.0, 0.14], [165.0, 0.24]])
	_make(&"alert", "triangle", 0.34, [[740.0, 0.22], [555.0, 0.22], [740.0, 0.22], [555.0, 0.22]])
	_make(&"travel", "triangle", 0.26, [[200.0, 0.08], [300.0, 0.08], [450.0, 0.12]])

	for i in 8:
		var p := AudioStreamPlayer.new()
		p.volume_db = -6.0
		add_child(p)
		_players.append(p)

	EventBus.dialogue_started.connect(func(_id: StringName) -> void: play(&"open"))
	EventBus.certification_earned.connect(func(_id: StringName) -> void: play(&"success"))
	EventBus.brownout.connect(_on_brownout)
	EventBus.load_toggled.connect(func(_id: StringName, _on: bool) -> void: play(&"switch"))
	MissionDirector.stage_changed.connect(_on_stage_changed)
	MissionDirector.storm_hour_passed.connect(func(_done: int, _total: int) -> void: play(&"tick"))


func _process(delta: float) -> void:
	# Repeating alarm while the storm clock is actually running.
	if MissionDirector.stage == MissionDirector.Stage.ALERT and not Dialogue.is_active and not MissionDirector.ui_open:
		_alert_timer -= delta
		if _alert_timer <= 0.0:
			_alert_timer = 2.4
			play(&"alert")
	else:
		_alert_timer = 0.3


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"mute") and not get_viewport().gui_get_focus_owner() is LineEdit:
		muted = not muted
		if not muted:
			play(&"confirm")


func play(sound: StringName, pitch: float = 1.0) -> void:
	if muted or not _streams.has(sound):
		return
	var p := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	p.stream = _streams[sound]
	p.pitch_scale = pitch
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
	elif stage == MissionDirector.Stage.SHELTERED:
		play(&"confirm")


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
