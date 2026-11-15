class_name Station
extends Node2D
## A spot in the world the player can use by walking up and pressing E.
## Connect to `used`. Set `enabled = false` to hide its prompt.
##   prompt        : what the tag above the astronaut says ("Check power")
##   hold_seconds  : above zero, E must be held this long (heavy things like the shelter hatch)
##   extra_reach   : lets a wide object be used from further away than a point

signal used

var prompt: String = "Use"
var enabled: bool = true
var objective_id: StringName = &""
var hold_seconds: float = 0.0
var extra_reach: float = 0.0


func _ready() -> void:
	add_to_group(&"interactable")
	if objective_id != &"":
		add_to_group(&"objective_targets")


func prompt_text() -> String:
	return prompt


func get_objective_id() -> StringName:
	return objective_id


func interact() -> void:
	if enabled:
		used.emit()
