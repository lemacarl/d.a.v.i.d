class_name ActorCampNewcomers
extends Node2D
## A small group of people who came to join David. Walks to the cave mouth and waits to be welcomed.

const CLOAK: Color = Color(0.45, 0.4, 0.5)
const SKIN: Color = Color(0.82, 0.62, 0.45)
const GLOW: Color = Color(1.0, 0.9, 0.5, 0.5)

var radius: float = 24.0
var start: Vector2 = Vector2.ZERO
var mouth: Vector2 = Vector2.ZERO
var walked: float = 0.0
var waited: float = 0.0
var active: bool = false
## Men this group brings before supplies.
var size_men: int = 0

var _arrived: bool = false


func reset(from: Vector2, to: Vector2, men: int) -> void:
	start = from
	mouth = to
	position = from
	walked = 0.0
	waited = 0.0
	size_men = men
	active = true
	_arrived = false
	visible = true
	queue_redraw()


func arrived() -> bool:
	return _arrived


func advance(delta: float, walk_sec: float) -> void:
	if not _arrived:
		walked += delta
		var k: float = clampf(walked / maxf(walk_sec, 0.01), 0.0, 1.0)
		position = start.lerp(mouth, k)
		if k >= 1.0:
			_arrived = true
			queue_redraw()
	else:
		waited += delta


func dismiss() -> void:
	active = false
	visible = false


func _draw() -> void:
	if _arrived:
		draw_arc(Vector2.ZERO, radius * 2.2, 0.0, TAU, 24, GLOW, 6.0)
	for i in 3:
		var o: Vector2 = Vector2((float(i) - 1.0) * radius * 1.3, absf(float(i) - 1.0) * 10.0)
		draw_rect(Rect2(o.x - radius * 0.6, o.y - radius * 0.2, radius * 1.2, radius * 1.0), CLOAK)
		draw_circle(o + Vector2(0, -radius * 0.5), radius * 0.45, SKIN)
