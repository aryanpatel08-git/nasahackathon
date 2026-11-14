class_name NPCData
extends Resource
## One character the player can talk to.
## Create one .tres per NPC in res://data/npcs/ and edit it in the Inspector.

@export var id: StringName = &""
@export var display_name: String = ""
@export var role: String = ""
@export var sprite: Texture2D
## What they say, one line per speech box. "{name}" becomes the player's name.
@export var lines: PackedStringArray = []
## Optional: a SceneRouter scene id to open after the last line (e.g. a training).
@export var opens_scene: StringName = &""
