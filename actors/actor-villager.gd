class_name ActorVillager
extends Node2D
## 4.7: a villager of Lo-debar. The node origin is the feet. `talked` marks the ones David has spoken
## to (a soft gold ring); `bubble` shows a speech bubble of three dots (no words). Placeholder shapes.

const SKIN: Color = Color(0.85, 0.66, 0.48)
const ROBES: Array[Color] = [Color(0.7, 0.4, 0.3), Color(0.35, 0.55, 0.5), Color(0.6, 0.5, 0.25), Color(0.5, 0.4, 0.65), Color(0.4, 0.5, 0.7), Color(0.65, 0.35, 0.5)]

var body_height: float = 170.0
var robe_index: int = 0
var talked: bool = false:
	set(v):
		if talked != v:
			talked = v
			queue_redraw()
var bubble: bool = false:
	set(v):
		if bubble != v:
			bubble = v
			queue_redraw()


func _draw() -> void:
	var h: float = body_height
	var robe: Color = ROBES[robe_index % ROBES.size()]
	if talked:
		draw_arc(Vector2(0.0, 6.0), h * 0.3, 0.0, TAU, 24, Color(1.0, 0.88, 0.45, 0.8), 5.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-0.17 * h, 0.0), Vector2(0.17 * h, 0.0), Vector2(0.12 * h, -0.62 * h), Vector2(-0.12 * h, -0.62 * h)]), robe)
	draw_circle(Vector2(0.0, -0.74 * h), 0.12 * h, SKIN)
	draw_rect(Rect2(-0.13 * h, -0.88 * h, 0.26 * h, 0.07 * h), robe.darkened(0.3))
	if bubble:
		var c: Vector2 = Vector2(0.0, -1.15 * h)
		draw_circle(c, 0.2 * h, Color(1, 1, 1, 0.92))
		for i in 3:
			draw_circle(c + Vector2(float(i - 1) * 0.09 * h, 0.0), 0.03 * h, Color(0.25, 0.25, 0.3))
