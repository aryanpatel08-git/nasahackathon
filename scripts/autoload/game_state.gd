extends Node
## GameState — player profile, progression flags, certifications and score (autoload).
## Other systems READ from here; they change it only through the functions below,
## so every change is announced on the EventBus.

const SCORE_AXES: Array[StringName] = [
	&"crew_safety", &"sustainability", &"science", &"efficiency", &"training",
]

var player_name: String = "Recruit"
var suit_color: Color = Color(0.95, 0.55, 0.2)
var certifications: Array[StringName] = []
var flags: Dictionary = {}   # StringName -> Variant
var scores: Dictionary = {}  # StringName -> int


func _ready() -> void:
	for axis in SCORE_AXES:
		scores[axis] = 0
	# Example of decoupling: the simulation never touches the score directly.
	# It announces a brownout; GameState decides what that costs.
	EventBus.brownout.connect(_on_brownout)


func set_flag(flag: StringName, value: Variant = true) -> void:
	flags[flag] = value
	EventBus.flag_set.emit(flag, value)


func get_flag(flag: StringName, default: Variant = false) -> Variant:
	return flags.get(flag, default)


func add_score(axis: StringName, amount: int) -> void:
	if not scores.has(axis):
		push_warning("GameState: unknown score axis '%s'" % axis)
		return
	scores[axis] += amount
	EventBus.score_changed.emit(axis, scores[axis])


func earn_certification(cert_id: StringName) -> void:
	if cert_id in certifications:
		return
	certifications.append(cert_id)
	EventBus.certification_earned.emit(cert_id)


func _on_brownout(_load_id: StringName) -> void:
	add_score(&"crew_safety", -1)
