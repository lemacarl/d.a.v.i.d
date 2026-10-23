class_name ActorFigure
extends Node2D
## Placeholder person for cutscenes, drawn from the feet up (the node origin is the feet).
## Plain shapes only: robe, head, hair, optional beard, staff, ram's horn or harp. No logic.

const SKIN: Color = Color(0.87, 0.68, 0.5)
const DARK: Color = Color(0.12, 0.1, 0.1)
const STAFF_BROWN: Color = Color(0.5, 0.33, 0.15)
const HORN_COLOR: Color = Color(0.93, 0.82, 0.55)

var body_height: float = 240.0
var robe: Color = Color(0.4, 0.5, 0.8)
var trim: Color = Color(0.9, 0.8, 0.4)
var hair: Color = Color(0.25, 0.16, 0.1)
var beard: bool = false
var beard_color: Color = Color(0.9, 0.9, 0.88)
var staff: bool = false
var horn: bool = false
var harp: bool = false
var seated: bool = false
## Horn angle in radians (0 = held upright at the side, positive tips it toward +x).
var horn_tilt: float = 0.0:
	set(value):
		if not is_equal_approx(horn_tilt, value):
			horn_tilt = value
			queue_redraw()


func setup(height: float, robe_color: Color, hair_color: Color) -> ActorFigure:
	body_height = height
	robe = robe_color
	hair = hair_color
	queue_redraw()
	return self


## Where the open end of the horn is, in this figure's local space.
func horn_tip() -> Vector2:
	var h: float = body_height
	return Vector2(0.24 * h, -0.45 * h) + Vector2(0.0, -0.3 * h).rotated(horn_tilt)


## Top of the head, in local space (where oil lands).
func head_top() -> Vector2:
	return Vector2(0.0, -body_height * 0.86)


func _draw() -> void:
	var h: float = body_height
	if seated:
		draw_rect(Rect2(0.0, -h * 0.1, h * 0.38, h * 0.1), robe.darkened(0.15))
		draw_rect(Rect2(h * 0.34, -h * 0.1, h * 0.08, h * 0.1), SKIN)
	var body: PackedVector2Array = PackedVector2Array([
		Vector2(-0.17 * h, 0.0), Vector2(0.17 * h, 0.0), Vector2(0.12 * h, -0.62 * h), Vector2(-0.12 * h, -0.62 * h)])
	draw_colored_polygon(body, robe)
	draw_rect(Rect2(-0.17 * h, -0.05 * h, 0.34 * h, 0.05 * h), trim)
	draw_rect(Rect2(-0.12 * h, -0.6 * h, 0.24 * h, 0.04 * h), trim)
	# Arms and hands.
	draw_line(Vector2(-0.12 * h, -0.58 * h), Vector2(-0.18 * h, -0.36 * h), robe.lightened(0.1), 0.06 * h)
	draw_line(Vector2(0.12 * h, -0.58 * h), Vector2(0.2 * h, -0.4 * h), robe.lightened(0.1), 0.06 * h)
	draw_circle(Vector2(-0.18 * h, -0.34 * h), 0.032 * h, SKIN)
	draw_circle(Vector2(0.2 * h, -0.38 * h), 0.032 * h, SKIN)
	# Head, hair, face.
	draw_circle(Vector2(0.0, -0.76 * h), 0.118 * h, hair)
	draw_circle(Vector2(0.0, -0.73 * h), 0.105 * h, SKIN)
	draw_circle(Vector2(-0.038 * h, -0.74 * h), 0.013 * h, DARK)
	draw_circle(Vector2(0.038 * h, -0.74 * h), 0.013 * h, DARK)
	draw_arc(Vector2(0.0, -0.71 * h), 0.04 * h, 0.2, PI - 0.2, 8, DARK, 2.0)
	if beard:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-0.085 * h, -0.69 * h), Vector2(0.085 * h, -0.69 * h), Vector2(0.0, -0.5 * h)]), beard_color)
	if staff:
		draw_line(Vector2(0.27 * h, 0.0), Vector2(0.27 * h, -0.95 * h), STAFF_BROWN, 6.0)
		draw_circle(Vector2(0.27 * h, -0.95 * h), 0.03 * h, STAFF_BROWN)
	if harp:
		draw_line(Vector2(0.2 * h, -0.2 * h), Vector2(0.2 * h, -0.5 * h), STAFF_BROWN, 5.0)
		draw_line(Vector2(0.2 * h, -0.5 * h), Vector2(0.4 * h, -0.2 * h), STAFF_BROWN, 5.0)
		draw_line(Vector2(0.2 * h, -0.2 * h), Vector2(0.4 * h, -0.2 * h), STAFF_BROWN, 5.0)
		draw_line(Vector2(0.26 * h, -0.3 * h), Vector2(0.26 * h, -0.2 * h), Color(1, 0.95, 0.7), 2.0)
		draw_line(Vector2(0.32 * h, -0.28 * h), Vector2(0.32 * h, -0.2 * h), Color(1, 0.95, 0.7), 2.0)
	if horn:
		var base: Vector2 = Vector2(0.24 * h, -0.45 * h)
		var tip: Vector2 = Vector2(0.0, -0.3 * h).rotated(horn_tilt)
		var side: Vector2 = tip.orthogonal().normalized() * 0.035 * h
		draw_colored_polygon(PackedVector2Array([base - side * 0.5, base + side * 0.5, base + tip + side, base + tip - side]), HORN_COLOR)
		draw_line(base, base + tip, Color(0.7, 0.55, 0.3), 3.0)
