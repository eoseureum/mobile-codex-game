extends SceneTree
## Integration checks against the real scene tree, input routing and physics.

var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)


func frames(count: int) -> void:
	for i in range(count):
		await physics_frame
		await process_frame


func _run() -> void:
	root.size = Vector2i(960, 540)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	await frames(3)
	var player = game.get_node_or_null("Player")
	check(player is CharacterBody2D, "Player must be a CharacterBody2D")
	if player == null:
		game.queue_free()
		await process_frame
		quit(1)
		return
	var camera = player.get_node_or_null("Camera2D")
	check(camera is Camera2D, "Player needs a following Camera2D")
	var spawn: Vector2 = player.global_position
	check(root.get_canvas_transform() * spawn == root.get_visible_rect().size / 2.0,
		"Spawn must project to viewport center")
	player.move_to(spawn + Vector2(97, 0))
	await frames(45)
	check(player.global_position.distance_to(spawn + Vector2(97, 0)) < 1.0,
		"Player must reach destination without overshooting")
	check(not player.moving, "Player must stop on arrival")
	player.move_to(spawn + Vector2(200, 0))
	await frames(5)
	player.move_to(spawn)
	await frames(60)
	check(player.global_position.distance_to(spawn) < 1.0, "New target must replace old target")
	# Mouse coordinates must account for the moved camera, not just the viewport.
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = root.get_visible_rect().size / 2.0 + Vector2(0, 96)
	# push_input(..., true) uses viewport coordinates. parse_input_event expects
	# physical window pixels, which differ under headless viewport stretching.
	root.push_input(click, true)
	await frames(45)
	check(player.global_position.distance_to(spawn + Vector2(0, 96)) < 1.0,
		"Mouse must set world destination through camera transform")
	var mouse_destination: Vector2 = player.destination
	click.button_index = MOUSE_BUTTON_RIGHT
	root.push_input(click, true)
	check(player.destination == mouse_destination, "Right-click must not move player")
	var before_touch: Vector2 = player.global_position
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.pressed = true
	touch.position = root.get_visible_rect().size / 2.0 + Vector2(-96, 0)
	root.push_input(touch, true)
	await frames(45)
	check(player.global_position.distance_to(before_touch + Vector2(-96, 0)) < 1.0,
		"Touch must set world destination")
	var secondary := InputEventScreenTouch.new()
	secondary.index = 1
	secondary.pressed = true
	secondary.position = Vector2.ZERO
	var first_destination: Vector2 = player.destination
	root.push_input(secondary, true)
	check(player.destination == first_destination, "Second finger must not replace target")
	touch.pressed = false
	root.push_input(touch, true)
	secondary.pressed = false
	root.push_input(secondary, true)
	# Border begins at x=48; radius=14 must keep center at x>=62.
	player.global_position = Vector2(96, 672)
	player.move_to(Vector2(-100, 672))
	await frames(75)
	check(player.global_position.x >= 61.0, "Solid border must prevent escape")
	check(player.global_position.x < 70.0, "Player must actually approach border")
	check(not player.moving, "Blocked destination must stop instead of jittering forever")
	player.move_to(Vector2(144, 672))
	await frames(45)
	check(player.global_position.distance_to(Vector2(144, 672)) < 1.0,
		"Player must move again after collision")
	check((root.get_canvas_transform() * player.global_position).distance_to(
		root.get_visible_rect().size / 2.0) < 1.0, "Camera must keep following")
	root.size = Vector2i(390, 844)
	await frames(3)
	check(root.content_scale_size == Vector2i(540, 960), "Portrait must adapt reference size")
	check((root.get_canvas_transform() * player.global_position).distance_to(
		root.get_visible_rect().size / 2.0) < 1.0, "Portrait must keep player centered")
	root.size = Vector2i(844, 390)
	await frames(3)
	check(root.content_scale_size == Vector2i(960, 540), "Landscape must restore reference size")
	player.move_to(player.global_position + Vector2(200, 0))
	game.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not player.moving, "Losing focus must stop player")
	check(game.active_touch == -1, "Losing focus must release active finger")
	game.queue_free()
	await process_frame
	print("Integration checks complete: %d checks, %d failures" % [checks, failures])
	quit(0 if failures == 0 else 1)
