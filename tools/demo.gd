extends Node
## Developer tool: plays the whole game at normal speed for a walkthrough video.
## Run with Godot's movie maker:
##   godot --path . --write-movie demo.avi --fixed-fps 30 res://tools/demo.tscn


func _ready() -> void:
	var driver := Node.new()
	driver.name = "DemoDriver"
	driver.set_script(load("res://tools/demo_driver.gd"))
	get_tree().root.add_child.call_deferred(driver)
