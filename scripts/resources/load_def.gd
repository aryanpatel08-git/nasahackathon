class_name LoadDef
extends Resource
## One power consumer on the outpost grid.
## Create one .tres per load in res://data/loads/ and edit it in the Inspector.
## All numbers are SIMPLIFIED GAME UNITS, not real engineering values.

@export var id: StringName = &""
@export var display_name: String = ""
## Power the load draws each game hour, in game power units.
@export_range(0.0, 20.0, 0.5) var power_draw: float = 1.0
## 1 = most important. When the battery runs out, the highest number is shut off first.
@export_range(1, 10) var priority: int = 5
## Life support can't be switched off by the player.
@export var can_disable: bool = true
@export var starts_enabled: bool = true
## Shown as a tooltip on the console. Keep it to one kid-friendly sentence.
@export_multiline var why_it_matters: String = ""
