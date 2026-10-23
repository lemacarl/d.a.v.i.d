class_name ActorBear
extends Node2D
## Placeholder bear: a big brown body with round ears.

const FUR: Color = Color(0.4, 0.26, 0.15)

var radius: float = 70.0
var stunned: bool = false


func set_stunned(on: bool) -> void:
	stunned = on
	modulate = Color(0.8, 0.8, 1.0, 0.8) if on else Color.WHITE


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, FUR)
	draw_circle(Vector2(-radius * 0.6, -radius * 0.8), radius * 0.28, FUR)
	draw_circle(Vector2(radius * 0.6, -radius * 0.8), radius * 0.28, FUR)
	draw_circle(Vector2(radius * 0.25, -radius * 0.1), radius * 0.09, Color.BLACK)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.1), radius * 0.09, Color.BLACK)
