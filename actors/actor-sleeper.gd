class_name ActorSleeper
extends Node2D
## Placeholder sleeping soldier in Saul's camp (3.8). `stir` shows that David is too close (a
## small restless mark); the stage owns the rules. Pure drawing, no logic.

const BODY: Color = Color(0.5, 0.25, 0.22)
const SKIN: Color = Color(0.87, 0.68, 0.5)
const HELMET: Color = Color(0.7, 0.6, 0.3)

var radius: float = 36.0
var wake_px: float = 0.0
var stir: bool = false:
	set(v):
		if stir != v:
			stir = v
			queue_redraw()


func _draw() -> void:
	if wake_px > 0.0:
		draw_arc(Vector2.ZERO, wake_px, 0.0, TAU, 28, Color(1.0, 0.4, 0.3, 0.22 if stir else 0.08), 3.0)
	draw_rect(Rect2(-radius, -radius * 0.3, radius * 1.7, radius * 0.7), BODY)
	draw_circle(Vector2(-radius, 0), radius * 0.4, SKIN)
	draw_rect(Rect2(-radius * 1.35, -radius * 0.42, radius * 0.7, radius * 0.2), HELMET)
	if stir:
		draw_circle(Vector2(0, -radius * 0.9), 6.0, Color(1.0, 0.85, 0.2))
