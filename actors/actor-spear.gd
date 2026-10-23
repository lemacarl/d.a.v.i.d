class_name ActorSpear
extends Node2D
## Placeholder spear thrown by Goliath along a lane, pointing left. Pooled by the boss stage.

var active: bool = false
var speed: float = 0.0
var length: float = 200.0


func launch(from: Vector2, move_speed: float) -> void:
	position = from
	speed = move_speed
	active = true
	visible = true


func stop() -> void:
	active = false
	visible = false


func _draw() -> void:
	draw_line(Vector2.ZERO, Vector2(length, 0), Color(0.45, 0.3, 0.15), 8.0)
	draw_colored_polygon(PackedVector2Array([Vector2(-26, 0), Vector2(6, -14), Vector2(6, 14)]), Color(0.75, 0.75, 0.8))
