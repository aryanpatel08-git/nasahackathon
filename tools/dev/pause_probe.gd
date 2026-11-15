extends Node
func _ready() -> void:
	var d := Node.new()
	d.set_script(load("res://tools/dev/pause_probe_run.gd"))
	get_tree().root.add_child.call_deferred(d)
