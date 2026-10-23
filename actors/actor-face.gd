class_name ActorFace
extends Node2D
## Placeholder Israelite soldier's face for the 2.7 cut-away: wide eyes, open mouth.
## A face only. No body is ever drawn.

func _draw() -> void:
	draw_circle(Vector2.ZERO, 120.0, Color(0.87, 0.68, 0.5))
	draw_circle(Vector2(-42, -20), 34.0, Color.WHITE)
	draw_circle(Vector2(42, -20), 34.0, Color.WHITE)
	draw_circle(Vector2(-42, -20), 11.0, Color(0.1, 0.1, 0.12))
	draw_circle(Vector2(42, -20), 11.0, Color(0.1, 0.1, 0.12))
	draw_arc(Vector2(-42, -62), 30.0, PI * 1.15, PI * 1.85, 12, Color(0.3, 0.2, 0.1), 6.0)
	draw_arc(Vector2(42, -62), 30.0, PI * 1.15, PI * 1.85, 12, Color(0.3, 0.2, 0.1), 6.0)
	draw_circle(Vector2(0, 55), 20.0, Color(0.3, 0.1, 0.1))
