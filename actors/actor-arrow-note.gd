class_name ActorArrowNote
extends ActorNote
## One arrow prompt of the ark parade (4.5): a soft disc with a bold arrow pointing up, down, left or
## right. Pooled and reused by StageRhythm; it redraws only when its direction changes.

enum Dir { UP, DOWN, LEFT, RIGHT }

const COLORS: Array[Color] = [
	Color(1.0, 0.85, 0.3), Color(0.45, 0.8, 1.0), Color(1.0, 0.55, 0.55), Color(0.6, 0.95, 0.55),
]

var dir: Dir = Dir.UP:
	set(value):
		if dir != value:
			dir = value
			queue_redraw()


func _draw() -> void:
	var c: Color = COLORS[dir]
	draw_circle(Vector2.ZERO, RADIUS * 1.5, Color(c.r, c.g, c.b, 0.16))
	draw_circle(Vector2.ZERO, RADIUS * 1.15, Color(1.0, 1.0, 1.0, 0.95))
	draw_circle(Vector2.ZERO, RADIUS * 1.0, c)
	var a: Vector2 = Vector2.UP
	match dir:
		Dir.DOWN:
			a = Vector2.DOWN
		Dir.LEFT:
			a = Vector2.LEFT
		Dir.RIGHT:
			a = Vector2.RIGHT
	var s: Vector2 = a.orthogonal()
	var r: float = RADIUS
	draw_colored_polygon(PackedVector2Array([
		a * r * 0.78, -a * r * 0.05 + s * r * 0.62, -a * r * 0.05 - s * r * 0.62]), Color(0.2, 0.15, 0.1))
	draw_line(-a * r * 0.62, a * r * 0.1, Color(0.2, 0.15, 0.1), r * 0.3)
