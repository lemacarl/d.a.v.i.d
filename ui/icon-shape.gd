class_name IconShape
extends Control
## Placeholder vector icons drawn in code: heart, stone, follower, sheep (bounces), loaf, clock, food.

enum Kind { HEART, STONE, FOLLOWER, SHEEP, LOAF, CLOCK, FOOD }

const BOUNCE_HEIGHT: float = 0.25
const BOUNCE_SPEED: float = 5.0

var kind: Kind = Kind.HEART:
	set(v):
		kind = v
		set_process(kind == Kind.SHEEP)
		queue_redraw()
var filled: bool = true:
	set(v):
		filled = v
		queue_redraw()

var _time: float = 0.0


func _init(k: Kind = Kind.HEART, edge: float = 64.0) -> void:
	custom_minimum_size = Vector2(edge, edge)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	kind = k


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	match kind:
		Kind.HEART:
			var c: Color = Color(0.9, 0.2, 0.28) if filled else Color(0.3, 0.3, 0.36)
			draw_circle(Vector2(s * 0.3, s * 0.35), s * 0.25, c)
			draw_circle(Vector2(s * 0.7, s * 0.35), s * 0.25, c)
			draw_colored_polygon(PackedVector2Array([Vector2(s * 0.07, s * 0.45), Vector2(s * 0.93, s * 0.45), Vector2(s * 0.5, s * 0.92)]), c)
		Kind.STONE:
			draw_circle(Vector2(s * 0.5, s * 0.55), s * 0.34, Color(0.62, 0.64, 0.68))
			draw_circle(Vector2(s * 0.42, s * 0.47), s * 0.1, Color(0.78, 0.8, 0.84))
		Kind.FOLLOWER:
			draw_circle(Vector2(s * 0.5, s * 0.28), s * 0.2, Color(0.9, 0.74, 0.56))
			draw_colored_polygon(PackedVector2Array([Vector2(s * 0.5, s * 0.5), Vector2(s * 0.82, s * 0.95), Vector2(s * 0.18, s * 0.95)]), Color(0.55, 0.4, 0.28))
		Kind.LOAF:
			draw_rect(Rect2(s * 0.1, s * 0.4, s * 0.8, s * 0.35), Color(0.82, 0.58, 0.28))
			draw_circle(Vector2(s * 0.3, s * 0.42), s * 0.2, Color(0.88, 0.65, 0.32))
			draw_circle(Vector2(s * 0.7, s * 0.42), s * 0.2, Color(0.88, 0.65, 0.32))
		Kind.FOOD:
			draw_circle(Vector2(s * 0.5, s * 0.58), s * 0.32, Color(0.85, 0.35, 0.18))
			draw_circle(Vector2(s * 0.42, s * 0.5), s * 0.08, Color(1.0, 0.65, 0.45))
			draw_line(Vector2(s * 0.5, s * 0.28), Vector2(s * 0.5, s * 0.14), Color(0.4, 0.28, 0.15), 4.0)
			draw_colored_polygon(PackedVector2Array([Vector2(s * 0.52, s * 0.2), Vector2(s * 0.8, s * 0.1), Vector2(s * 0.68, s * 0.32)]), Color(0.3, 0.65, 0.3))
		Kind.CLOCK:
			draw_circle(Vector2(s * 0.5, s * 0.5), s * 0.4, Color(0.9, 0.9, 0.85))
			draw_line(Vector2(s * 0.5, s * 0.5), Vector2(s * 0.5, s * 0.22), Color(0.2, 0.2, 0.25), 4.0)
			draw_line(Vector2(s * 0.5, s * 0.5), Vector2(s * 0.7, s * 0.5), Color(0.2, 0.2, 0.25), 4.0)
		Kind.SHEEP:
			var lift: float = absf(sin(_time * BOUNCE_SPEED)) * s * BOUNCE_HEIGHT
			var wool: Color = Color(0.95, 0.95, 0.92)
			var o: Vector2 = Vector2(0.0, -lift)
			draw_circle(Vector2(s * 0.35, s * 0.55) + o, s * 0.22, wool)
			draw_circle(Vector2(s * 0.55, s * 0.5) + o, s * 0.24, wool)
			draw_circle(Vector2(s * 0.5, s * 0.62) + o, s * 0.22, wool)
			draw_circle(Vector2(s * 0.8, s * 0.5) + o, s * 0.13, Color(0.2, 0.18, 0.2))
			draw_line(Vector2(s * 0.4, s * 0.8) + o, Vector2(s * 0.4, s * 0.95), Color(0.2, 0.18, 0.2), 4.0)
			draw_line(Vector2(s * 0.62, s * 0.8) + o, Vector2(s * 0.62, s * 0.95), Color(0.2, 0.18, 0.2), 4.0)
