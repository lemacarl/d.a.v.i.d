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


func _process(_delta: float) -> void:
	# Redraw while flying so the trail follows the direction and the spin turns.
	if active:
		queue_redraw()


func _draw() -> void:
	# A short fading trail behind the stone makes the flight easy to follow on a TV.
	if active:
		for i in 3:
			var back: Vector2 = -dir * float(i + 1) * 14.0
			draw_circle(back, 10.0 - float(i) * 2.5, Color(0.85, 0.85, 0.88, 0.35 - float(i) * 0.1))
	draw_circle(Vector2.ZERO, 13.0, Color(0.25, 0.25, 0.28))
	draw_circle(Vector2.ZERO, 10.5, Color(0.72, 0.72, 0.75))
	var spin: Vector2 = Vector2.from_angle(travelled * 0.03) * 5.0
	draw_circle(spin, 3.5, Color(0.9, 0.9, 0.92))
