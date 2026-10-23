class_name ActorGlowStone
extends Node2D
## Placeholder glowing stone lying in the stream. The stage hides it once picked up.

var collected: bool = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, 38.0, Color(1.0, 0.95, 0.5, 0.25))
	draw_circle(Vector2.ZERO, 26.0, Color(1.0, 0.95, 0.6, 0.35))
	draw_circle(Vector2.ZERO, 14.0, Color(0.85, 0.87, 0.9))
	draw_circle(Vector2(-4, -4), 4.0, Color(1, 1, 1, 0.9))
