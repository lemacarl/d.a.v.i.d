class_name ActorShield
extends Node2D
## Placeholder shield-bearer who walks in front of Goliath. Stones bounce off the shield.

func _draw() -> void:
	draw_circle(Vector2(0, -70), 26.0, Color(0.87, 0.68, 0.5))
	draw_rect(Rect2(-26, -45, 52, 90), Color(0.5, 0.25, 0.2))
	draw_rect(Rect2(-60, -80, 40, 160), Color(0.7, 0.55, 0.2))
	draw_rect(Rect2(-54, -74, 28, 148), Color(0.82, 0.68, 0.3))
