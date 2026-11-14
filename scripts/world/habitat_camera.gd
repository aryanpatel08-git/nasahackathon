class_name HabitatCamera
extends Camera2D
## Follow the interpolated player and clamp the view to the habitat.


static func mount(player: Node2D, bounds: Vector2i) -> void:
	var camera := HabitatCamera.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = bounds.x
	camera.limit_bottom = bounds.y
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 9.0
	player.add_child(camera)
	camera.reset_physics_interpolation()
	camera.reset_smoothing()
	camera.force_update_scroll()

