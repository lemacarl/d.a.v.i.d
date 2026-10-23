class_name ActorGoliath
extends Node2D
## Placeholder Goliath: a large bronze figure facing left. He stays standing at all times.
## Head tilts back and the forehead glows in the weak-point phase. Pure drawing, no logic.

var laughing: bool = false:
	set(v):
		if laughing != v:
			laughing = v
			queue_redraw()
var head_back: bool = false:
	set(v):
		if head_back != v:
			head_back = v
			queue_redraw()
var glow: bool = false:
	set(v):
		if glow != v:
			glow = v
			queue_redraw()

## Where the forehead is, relative to this node (the stage reads it for aiming).
const FOREHEAD: Vector2 = Vector2(-10, -250)


func _draw() -> void:
	draw_rect(Rect2(-70, -170, 140, 250), Color(0.65, 0.45, 0.2))
	draw_rect(Rect2(-90, -150, 30, 190), Color(0.55, 0.38, 0.18))
	draw_rect(Rect2(-60, 80, 50, 110), Color(0.45, 0.32, 0.2))
	draw_rect(Rect2(10, 80, 50, 110), Color(0.45, 0.32, 0.2))
	var head: Vector2 = Vector2(0, -230) + (Vector2(26, 8) if head_back else Vector2.ZERO)
	draw_circle(head, 52.0, Color(0.87, 0.68, 0.5))
	draw_rect(Rect2(head.x - 56, head.y - 62, 112, 40), Color(0.72, 0.52, 0.22))
	if glow:
		draw_circle(head + Vector2(-10, -22), 30.0, Color(1.0, 0.95, 0.4, 0.35))
		draw_circle(head + Vector2(-10, -22), 17.0, Color(1.0, 0.97, 0.6, 0.9))
	if laughing:
		draw_circle(head + Vector2(-16, 16), 16.0, Color(0.25, 0.1, 0.1))
	else:
		draw_line(head + Vector2(-30, 20), head + Vector2(0, 20), Color(0.3, 0.15, 0.1), 4.0)
	draw_circle(head + Vector2(-20, -4), 5.0, Color(0.1, 0.1, 0.1))
