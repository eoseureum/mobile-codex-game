extends Node2D

@onready var player: CharacterBody2D = $Player
var active_touch: int = -1


func _ready() -> void:
	get_window().size_changed.connect(_adapt_viewport)
	_adapt_viewport()


func _adapt_viewport() -> void:
	var window := get_window()
	# Keep the short side at 540 reference pixels in both orientations.
	window.content_scale_size = Vector2i(540, 960) if window.size.y > window.size.x \
		else Vector2i(960, 540)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and active_touch == -1:
			active_touch = event.index
			_set_destination(event.position)
		elif not event.pressed and event.index == active_touch:
			active_touch = -1
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and active_touch == -1:
		_set_destination(event.position)


func _set_destination(screen_position: Vector2) -> void:
	player.move_to(get_canvas_transform().affine_inverse() * screen_position)
	get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		active_touch = -1
		if is_instance_valid(player):
			player.stop()


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if is_instance_valid(player) and player.moving:
		var target: Vector2 = player.destination
		draw_circle(target, 12.0, Color("d9f4db"), false, 2.0, true)
		draw_circle(target, 3.0, Color("d9f4db"))
