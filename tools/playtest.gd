extends Node
## Developer tool: automatic playthrough of the whole slice.
## Run:  Godot --path . res://tools/playtest.tscn -- rover=0 choice=2 late=0 speed=3
## Add --headless for a logic-only run. Without it, screenshots go to tools/shots/.


func _ready() -> void:
	var driver := Node.new()
	driver.name = "PlaytestDriver"
	driver.set_script(load("res://tools/playtest_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
