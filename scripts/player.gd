extends CharacterBody2D
## Reusable click/tap-controlled physics body. Input routing belongs to Main.

@export var speed: float = 240.0
var destination: Vector2
var moving: bool = false
var facing: Vector2 = Vector2.DOWN
var blocked_time: float = 0.0


func _ready() -> void:
	destination = global_position


func move_to(world_position: Vector2) -> void:
	destination = world_position
	moving = true
	blocked_time = 0.0


func stop() -> void:
	moving = false
	velocity = Vector2.ZERO
	blocked_time = 0.0


func _physics_process(delta: float) -> void:
	if not moving:
		return
	var offset: Vector2 = destination - global_position
	if offset.length() <= 0.5:
		stop()
		return
	facing = offset.normalized()
	velocity = facing * minf(speed, offset.length() / delta)
	var previous: Vector2 = global_position
	move_and_slide()
	if global_position.distance_to(previous) < 0.1:
		blocked_time += delta
	else:
		blocked_time = 0.0
	if blocked_time >= 0.2 or global_position.distance_to(destination) <= 0.5:
		stop()
	queue_redraw()


func _draw() -> void:
	draw_ellipse_shadow()
	draw_circle(Vector2.ZERO, 18.0, Color("172b29"))
	draw_circle(Vector2.ZERO, 14.0, Color("d9f4db"))
	draw_circle(Vector2.ZERO, 10.0, Color("73bc9a"))
	var side := facing.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		facing * 13.0, facing * 3.0 + side * 5.0, facing * 3.0 - side * 5.0
	]), Color("f5ffe9"))


func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 12), 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 20.0, Color(0.05, 0.1, 0.08, 0.3))
	draw_set_transform(Vector2.ZERO)
