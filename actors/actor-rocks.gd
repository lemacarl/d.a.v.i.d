class_name ActorRocks
extends Node2D
## Placeholder pile of rocks the bear can slip on: three grey boulders with dark outlines.

const OUTLINE: Color = Color(0.1, 0.1, 0.12)
const STONE: Color = Color(0.58, 0.58, 0.64)
const LIGHT: Color = Color(0.78, 0.78, 0.84)


func _draw() -> void:
	for r in [[Vector2(-34, 8), 40.0], [Vector2(30, 14), 34.0], [Vector2(0, -22), 36.0]]:
		var c: Vector2 = r[0]
		var rad: float = r[1]
		draw_circle(c, rad + 5.0, OUTLINE)
		draw_circle(c, rad, STONE)
		draw_circle(c + Vector2(-rad * 0.25, -rad * 0.3), rad * 0.4, LIGHT)
