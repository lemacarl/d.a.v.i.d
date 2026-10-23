class_name ActorLion
extends Node2D
## Placeholder lion: golden body, brown mane.

const BODY: Color = Color(0.9, 0.7, 0.25)
const MANE: Color = Color(0.55, 0.32, 0.12)

var radius: float = 54.0
var stunned: bool = false


func set_stunned(on: bool) -> void:
	stunned = on
	modulate = Color(0.8, 0.8, 1.0, 0.8) if on else Color.WHITE


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, MANE)
	draw_circle(Vector2.ZERO, radius * 0.65, BODY)
	draw_circle(Vector2(radius * 0.25, -radius * 0.1), radius * 0.1, Color.BLACK)
	draw_circle(Vector2(-radius * 0.25, -radius * 0.1), radius * 0.1, Color.BLACK)
