class_name ActorScout
extends Node2D
## Placeholder Philistine scout who walks along the far bank. Draws a faint sight disc and a
## "!" while it sees David. The stage owns the sighting rules.

const BODY: Color = Color(0.55, 0.22, 0.2)
const HELMET: Color = Color(0.72, 0.62, 0.3)

var radius: float = 34.0
var sight_px: float = 0.0
var left: float = 0.0
var right: float = 0.0
var speed: float = 0.0
var dir: float = 1.0
var alert: bool = false:
	set(v):
		if alert != v:
			alert = v
			queue_redraw()


func configure(range_px: float, min_x: float, max_x: float, walk_speed: float, start_x: float, y: float) -> void:
	sight_px = range_px
	left = min_x
	right = max_x
	speed = walk_speed
	position = Vector2(start_x, y)
	queue_redraw()


func advance(delta: float) -> void:
	position.x += dir * speed * delta
	if position.x > right:
		position.x = right
		dir = -1.0
	elif position.x < left:
		position.x = left
		dir = 1.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, sight_px, Color(1.0, 0.3, 0.2, 0.07 if not alert else 0.16))
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.3), BODY)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.45, Color(0.87, 0.68, 0.5))
	draw_rect(Rect2(-radius * 0.5, -radius * 1.05, radius, radius * 0.4), HELMET)
	if alert:
		draw_rect(Rect2(-5, -radius * 2.4, 10, radius * 0.9), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(0, -radius * 1.2), 6.0, Color(1.0, 0.85, 0.2))
