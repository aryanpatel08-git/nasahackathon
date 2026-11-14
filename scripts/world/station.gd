class_name Station
extends Node2D
## A spot in the world the player can use by walking up and pressing E.
## Connect to `used`. Set `enabled = false` to hide its prompt.

signal used

var prompt: String = "Use"
var enabled: bool = true


func _ready() -> void:
	add_to_group(&"interactable")


func prompt_text() -> String:
	return prompt


func interact() -> void:
	if enabled:
		used.emit()
