class_name ActorHazard
extends Node2D
## Placeholder road hazard (cart, goat, rolling rock). It slides back and forth along one axis;
## the delivery stage reads `radius` for bumps. Pooled: built once, never freed during play.

var kind: StringName = &"cart"
var radius: float = 40.0
var origin: Vector2 = Vector2.ZERO
var axis: Vector2 = Vector2.DOWN
var span: float = 200.0
var speed: float = 100.0

var _offset: float = 0.0
var _dir: float = 1.0


## Sets the shape and the sliding line. `start` is the starting offset along the axis.
func configure(hazard_kind: StringName, line_origin: Vector2, line_axis: Vector2, half_span: float, move_speed: float, start: float) -> void:
	kind = hazard_kind
	origin = line_origin
	axis = line_axis.normalized()
	span = half_span
	speed = move_speed
	_offset = clampf(start, -span, span)
	_dir = 1.0 if start >= 0.0 else -1.0
	match kind:
		&"goat":
			radius = 36.0
		&"rolling-rock":
			radius = 44.0
		_:
			radius = 56.0
	position = origin + axis * _offset
	queue_redraw()


func advance(delta: float) -> void:
	_offset += _dir * speed * delta
	if _offset > span:
		_offset = span
		_dir = -1.0
	elif _offset < -span:
		_offset = -span
		_dir = 1.0
	position = origin + axis * _offset
	if kind == &"rolling-rock":
		rotation = _offset / radius


func _draw() -> void:
	match kind:
		&"goat":
			draw_circle(Vector2.ZERO, radius * 0.8, Color(0.86, 0.84, 0.78))
			draw_circle(Vector2(radius * 0.7, -radius * 0.25), radius * 0.35, Color(0.78, 0.74, 0.68))
			draw_line(Vector2(radius * 0.7, -radius * 0.5), Vector2(radius * 0.55, -radius * 1.0), Color(0.3, 0.25, 0.2), 4.0)
			draw_line(Vector2(radius * 0.85, -radius * 0.5), Vector2(radius * 0.95, -radius * 1.0), Color(0.3, 0.25, 0.2), 4.0)
		&"rolling-rock":
			draw_circle(Vector2.ZERO, radius, Color(0.5, 0.5, 0.54))
			draw_circle(Vector2(-radius * 0.3, -radius * 0.2), radius * 0.25, Color(0.4, 0.4, 0.44))
			draw_circle(Vector2(radius * 0.35, radius * 0.3), radius * 0.18, Color(0.4, 0.4, 0.44))
		_:
			draw_rect(Rect2(-radius, -radius * 0.55, radius * 2.0, radius * 1.1), Color(0.55, 0.36, 0.18))
			draw_rect(Rect2(-radius * 0.8, -radius * 0.95, radius * 1.6, radius * 0.45), Color(0.8, 0.65, 0.3))
			draw_circle(Vector2(-radius * 0.6, radius * 0.6), radius * 0.3, Color(0.2, 0.15, 0.1))
			draw_circle(Vector2(radius * 0.6, radius * 0.6), radius * 0.3, Color(0.2, 0.15, 0.1))
