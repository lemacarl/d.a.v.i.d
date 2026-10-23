class_name ActorStone
extends Node2D
## Placeholder sling stone, pooled by the stage. Flies at a target node or in a fixed direction.

var active: bool = false
var target: Node2D = null
var dir: Vector2 = Vector2.RIGHT
var speed: float = 0.0
var travelled: float = 0.0


func launch(from: Vector2, aim: Node2D, direction: Vector2, move_speed: float) -> void:
	position = from
	target = aim
	dir = direction
	speed = move_speed
	travelled = 0.0
	active = true
	visible = true


func stop() -> void:
	active = false
	target = null
	visible = false


func _draw() -> void:
	draw_circle(Vector2.ZERO, 9.0, Color(0.7, 0.7, 0.72))
