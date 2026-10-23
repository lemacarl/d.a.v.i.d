class_name ActorRope
extends Node2D
## Placeholder rope that ties a family at Ziklag. The stage hides it when the family is freed.


func _draw() -> void:
	draw_arc(Vector2.ZERO, 46.0, 0.0, TAU, 20, Color(0.75, 0.6, 0.3), 6.0)
	draw_arc(Vector2.ZERO, 36.0, 0.0, TAU, 20, Color(0.6, 0.45, 0.22), 4.0)
