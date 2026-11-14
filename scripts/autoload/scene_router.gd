extends Node
## SceneRouter — changes scenes with a short fade (autoload).
## Scenes never load each other directly. They call SceneRouter.go_to(&"id")
## or emit EventBus.scene_change_requested(&"id").

const SCENES: Dictionary = {
	&"create_astronaut": "res://scenes/ui/create_astronaut.tscn",
	&"academy_hub": "res://scenes/academy/academy_hub.tscn",
	&"power_console": "res://scenes/minigames/power_console.tscn",
	&"outpost": "res://scenes/outpost/outpost.tscn",
}
const FADE_TIME := 0.25

var _fade: ColorRect
var _busy: bool = false


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0.05, 0.05, 0.09, 0.0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_fade)
	EventBus.scene_change_requested.connect(go_to)


func is_transitioning() -> bool:
	return _busy


func go_to(scene_id: StringName) -> void:
	if _busy:
		return
	if not SCENES.has(scene_id):
		push_error("SceneRouter: unknown scene id '%s'" % scene_id)
		return
	_busy = true
	Sfx.play(&"travel")
	var path: String = SCENES[scene_id]
	var fade_out := create_tween()
	fade_out.tween_property(_fade, "color:a", 1.0, FADE_TIME)
	await fade_out.finished
	var err := get_tree().change_scene_to_file(path)
	if err != OK:
		push_error("SceneRouter: could not load %s" % path)
	await get_tree().process_frame
	await get_tree().process_frame
	var fade_in := create_tween()
	fade_in.tween_property(_fade, "color:a", 0.0, FADE_TIME)
	await fade_in.finished
	_busy = false
