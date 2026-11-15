extends Control
## Screen-space direction marker for the current NavigationFloor destination.

var navigation: NavigationFloor
var _pulse := 0.0


func _process(delta: float) -> void:
	_pulse += delta
	queue_redraw()


func configure(floor: NavigationFloor) -> void:
	navigation = floor


func _draw() -> void:
	if navigation == null:
		return
	var local_id := MapManager.local_target()
	if not navigation.points.has(local_id):
		return
	var point: Dictionary = navigation.points[local_id]
	var target_world: Vector2 = navigation.to_global(point.at)
	var player := navigation.player
	if not is_instance_valid(player):
		return
	var transform := get_viewport().get_canvas_transform()
	var target_screen := transform * target_world
	var player_screen := transform * player.global_position
	var viewport := get_viewport().get_visible_rect().size
	var visible := Rect2(Vector2(8, 8), viewport - Vector2(16, 16)).has_point(target_screen)
	var distance := player.global_position.distance_to(target_world)
	if visible:
		draw_arc(target_screen, 12.0 + sin(_pulse * 4.0) * 2.0, 0.0, TAU, 20, Color("6de8dc", 0.7), 1.5)
	if visible and distance < 82.0:
		return
	var direction := (target_screen - player_screen).normalized()
	if not visible:
		# Stay clear of the HUD along the top and bottom edges.
		var half := viewport * 0.5 - Vector2(18, 34)
		var center := viewport * 0.5
		var scale_to_edge := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		player_screen = center + direction * scale_to_edge
	else:
		player_screen += direction * 27.0
	var pulse := 1.0 + sin(_pulse * 5.0) * 0.12
	var tip := player_screen + direction * 7.0 * pulse
	var side := direction.orthogonal() * 4.0 * pulse
	draw_colored_polygon(PackedVector2Array([tip, player_screen - direction * 5.0 + side, player_screen - direction * 5.0 - side]), Color("ffd36f"))
