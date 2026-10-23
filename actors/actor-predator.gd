class_name ActorPredator
extends Node2D
## Placeholder jackal (small, tan) or wolf (large, grey). Pooled: reused by the stage.

enum State { INACTIVE, CHASE, DRAG, FLEE, TELEGRAPH }

var kind: StringName = &"jackal"
var radius: float = 26.0
var state: State = State.INACTIVE
var speed: float = 0.0
var carry: ActorSheep = null
## Seconds left of a fright (harp): the predator backs away from David instead of chasing.
var afraid: float = 0.0
## While TELEGRAPH: seconds until the predator appears, and what it will be.
var telegraph_left: float = 0.0
var pending_kind: StringName = &"jackal"
var pending_speed: float = 0.0
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
	afraid = 0.0
	state = State.CHASE
	visible = true
	modulate = Color.WHITE
	queue_redraw()


## Shows only a pulsing glow at `at` for `sec` seconds; the stage calls activate() when it ends.
func telegraph(predator_kind: StringName, at: Vector2, move_speed: float, sec: float) -> void:
	pending_kind = predator_kind
	pending_speed = move_speed
	telegraph_left = sec
	kind = predator_kind
	radius = 36.0 if kind == &"wolf" else 26.0
	position = at
	carry = null
	afraid = 0.0
	state = State.TELEGRAPH
	visible = true
	modulate = Color.WHITE
	queue_redraw()


func deactivate() -> void:
	state = State.INACTIVE
	carry = null
	afraid = 0.0
	telegraph_left = 0.0
	visible = false


func is_live() -> bool:
	return state == State.CHASE or state == State.DRAG


func _draw() -> void:
	if state == State.TELEGRAPH:
		draw_circle(Vector2.ZERO, radius * 1.9, Color(1.0, 0.85, 0.3, 0.35))
		draw_arc(Vector2.ZERO, radius * 1.9, 0.0, TAU, 32, Color(1.0, 0.95, 0.6, 0.9), 6.0)
		return
	draw_circle(Vector2.ZERO, radius, _color)
	draw_colored_polygon(PackedVector2Array([Vector2(radius * 0.4, -radius * 0.6), Vector2(radius * 0.7, -radius * 1.3), Vector2(radius * 0.9, -radius * 0.5)]), _color)
	draw_circle(Vector2(radius * 0.45, -radius * 0.1), radius * 0.12, Color(0.9, 0.2, 0.1))
