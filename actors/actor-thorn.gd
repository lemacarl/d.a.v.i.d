class_name ActorThorn
extends Node2D
## Placeholder thorn patch on the dark path (3.8). It blocks walking until Goliath's Sword clears
## it with OK. The stage hides it once cleared.

var radius: float = 50.0
var cleared: bool = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.32, 0.15, 0.85))
	for i in 10:
		var a: float = TAU * float(i) / 10.0
		draw_line(Vector2.from_angle(a) * radius * 0.3, Vector2.from_angle(a) * radius * 1.05, Color(0.45, 0.3, 0.15), 4.0)
