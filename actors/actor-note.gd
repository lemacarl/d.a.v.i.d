class_name ActorNote
extends Node2D
## One harp note: a large soft glowing orb with a sparkle cross. Pooled and reused by StageRhythm.

const RADIUS: float = 56.0


func _draw() -> void:
	draw_circle(Vector2.ZERO, RADIUS * 1.55, Color(1.0, 0.85, 0.35, 0.12))
	draw_circle(Vector2.ZERO, RADIUS * 1.25, Color(1.0, 0.88, 0.45, 0.25))
	draw_circle(Vector2.ZERO, RADIUS, Color(1.0, 0.97, 0.82))
	draw_circle(Vector2.ZERO, RADIUS * 0.62, Color(1.0, 1.0, 1.0))
	draw_circle(Vector2(-RADIUS * 0.25, -RADIUS * 0.25), RADIUS * 0.18, Color(0.55, 0.8, 1.0, 0.9))
	var arm: float = RADIUS * 1.5
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), Color(1.0, 0.95, 0.7, 0.55), 5.0)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), Color(1.0, 0.95, 0.7, 0.55), 5.0)
