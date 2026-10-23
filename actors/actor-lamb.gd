class_name ActorLamb
extends Node2D
## Placeholder lamb: smaller and creamier than a sheep. Held by the lion until dropped.

const WOOL: Color = Color(1.0, 0.97, 0.85)
const HEAD: Color = Color(0.25, 0.2, 0.2)

var radius: float = 18.0
var held: bool = false
var collected: bool = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, WOOL)
	draw_circle(Vector2(radius * 0.9, -radius * 0.2), radius * 0.4, HEAD)
