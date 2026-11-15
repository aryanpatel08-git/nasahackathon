extends Node
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run.call_deferred()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("/tmp/pp_%s.png" % n)
func _btn(t: String) -> Button:
	for b: Button in PauseMenu.find_children("*", "Button", true, false):
		if b.text.begins_with(t) and b.is_visible_in_tree():
			return b
	return null
func _run() -> void:
	await get_tree().process_frame
	GameState.start_fresh_progress()
	MissionDirector.start_new_game()
	get_tree().change_scene_to_file("res://scenes/academy/academy_hub.tscn")
	await get_tree().create_timer(1.5).timeout
	PauseMenu.call("open_page", "home")
	await get_tree().create_timer(0.6).timeout
	await _shot("a")
	print("panel before ", PauseMenu.get("_panel").size, PauseMenu.get("_panel").position)
	_btn("Sound").pressed.emit()
	await get_tree().create_timer(0.05).timeout
	await _shot("b")
	print("panel just after ", PauseMenu.get("_panel").size, PauseMenu.get("_panel").position)
	await get_tree().create_timer(0.3).timeout
	for page in ["help", "home", "tasks", "home", "notes", "home"]:
		PauseMenu.call("_show_page", page)
		await get_tree().create_timer(0.2).timeout
		print("page ", page, " ", PauseMenu.get("_panel").size)
	_btn("Sound").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	await _shot("c")
	print("panel later ", PauseMenu.get("_panel").size, PauseMenu.get("_panel").position)
	get_tree().quit()
