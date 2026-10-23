class_name ActorGuard
extends Node2D
## 4.3: a Jebusite guard standing on the wall. Placeholder shapes. `throwing` raises his arms while a
## rock is about to fall; he never leaves his post.

const ARMOR: Color = Color(0.5, 0.5, 0.58)
const SKIN: Color = Color(0.82, 0.62, 0.45)
const HELMET: Color = Color(0.7, 0.6, 0.3)

var radius: float = 30.0
var throwing: bool = false:
	set(v):
		if throwing != v:
			throwing = v
			queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.3), ARMOR)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.45, SKIN)
	draw_rect(Rect2(-radius * 0.5, -radius * 1.05, radius, radius * 0.4), HELMET)
	var hand_y: float = -radius * 1.5 if throwing else radius * 0.3
	draw_line(Vector2(-radius * 0.7, 0.0), Vector2(-radius * 0.9, hand_y), SKIN, 6.0)
	draw_line(Vector2(radius * 0.7, 0.0), Vector2(radius * 0.9, hand_y), SKIN, 6.0)
	if throwing:
		draw_circle(Vector2(0, -radius * 1.8), radius * 0.4, Color(0.45, 0.43, 0.42))
