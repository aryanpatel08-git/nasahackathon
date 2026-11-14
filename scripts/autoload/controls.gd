extends Node
## Controls — registers the game's input actions in code (autoload).
## Done here instead of project.godot so the key list is easy to read and merge.
##   move_left / move_right / move_up / move_down : WASD or arrow keys
##   interact : E, Space or Enter


func _ready() -> void:
	_add(&"move_left", [KEY_A, KEY_LEFT])
	_add(&"move_right", [KEY_D, KEY_RIGHT])
	_add(&"move_up", [KEY_W, KEY_UP])
	_add(&"move_down", [KEY_S, KEY_DOWN])
	_add(&"interact", [KEY_E, KEY_SPACE, KEY_ENTER])
	_add(&"pause_menu", [KEY_P])
	_add(&"mute", [KEY_M])


func _add(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		InputMap.action_add_event(action, ev)

