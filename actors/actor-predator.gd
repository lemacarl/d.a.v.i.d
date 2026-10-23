class_name ActorPredator
extends Node2D
## Placeholder jackal (small, tan) or wolf (large, grey). Pooled: reused by the stage.

enum State { INACTIVE, CHASE, DRAG, FLEE }

var kind: StringName = &"jackal"
var radius: float = 26.0
var state: State = State.INACTIVE
var speed: float = 0.0
var carry: ActorSheep = null
var _color: Color = Color(0.7, 0.55, 0.3)


func activate(predator_kind: StringName, at: Vector2, move_speed: float) -> void:
	kind = predator_kind
	if kind == &"wolf":
		radius = 36.0
		_color = Color(0.45, 0.47, 0.52)
	else:
		radius = 26.0
		_color = Color(0.72, 0.55, 0.3)
	position = at
	speed = move_speed
	carry = null
	state = State.CHASE
	visible = true
	queue_redraw()


func deactivate() -> void:
	state = State.INACTIVE
	carry = null
	visible = false


func is_live() -> bool:
	return state == State.CHASE or state == State.DRAG


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius, _color)
	draw_colored_polygon(PackedVector2Array([Vector2(radius * 0.4, -radius * 0.6), Vector2(radius * 0.7, -radius * 1.3), Vector2(radius * 0.9, -radius * 0.5)]), _color)
	draw_circle(Vector2(radius * 0.45, -radius * 0.1), radius * 0.12, Color(0.9, 0.2, 0.1))
