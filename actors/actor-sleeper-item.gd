class_name ActorSleeperItem
extends Node2D
## Placeholder item lying beside sleeping Saul: the spear or the water jug (3.8). The stage hides
## it once it is taken.

var kind: StringName = &"spear"
var taken: bool = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, 40.0, Color(1.0, 0.95, 0.5, 0.2))
	if kind == &"water-jug":
		draw_circle(Vector2(0, 6), 18.0, Color(0.6, 0.4, 0.25))
		draw_rect(Rect2(-8, -22, 16, 16), Color(0.6, 0.4, 0.25))
		return
	draw_line(Vector2(-34, 20), Vector2(34, -20), Color(0.55, 0.4, 0.2), 6.0)
	draw_colored_polygon(PackedVector2Array([Vector2(34, -20), Vector2(22, -26), Vector2(28, -10)]), Color(0.75, 0.78, 0.82))
