class_name ActorSaul
extends Node2D
## Placeholder King Saul. En-gedi (3.6): resting in the cave, facing the cave mouth, with a faint
## sight cone that the stage tests. Saul's camp (3.8): asleep, no cone. Saul is never hurt: the only
## change the stage can make is the cut corner of the robe. Pure drawing, no logic.

const ROBE: Color = Color(0.45, 0.2, 0.55)
const SKIN: Color = Color(0.87, 0.68, 0.5)
const CROWN: Color = Color(0.9, 0.78, 0.25)
const CONE_STEPS: int = 12

var radius: float = 44.0
var facing: Vector2 = Vector2.LEFT
var cone_range: float = 0.0
## Half the cone's opening angle, in radians.
var cone_half: float = 0.0
var asleep: bool = false:
	set(v):
		if asleep != v:
			asleep = v
			queue_redraw()
var alert: bool = false:
	set(v):
		if alert != v:
			alert = v
			queue_redraw()
var robe_cut: bool = false:
	set(v):
		if robe_cut != v:
			robe_cut = v
			queue_redraw()


func configure(range_px: float, half_angle: float, face: Vector2) -> void:
	cone_range = range_px
	cone_half = half_angle
	facing = face.normalized() if face.length_squared() > 0.0 else Vector2.LEFT
	queue_redraw()


func _draw() -> void:
	if cone_range > 0.0:
		var pts: PackedVector2Array = PackedVector2Array()
		pts.append(Vector2.ZERO)
		var base: float = facing.angle()
		for i in CONE_STEPS + 1:
			var a: float = base - cone_half + 2.0 * cone_half * float(i) / float(CONE_STEPS)
			pts.append(Vector2.from_angle(a) * cone_range)
		draw_colored_polygon(pts, Color(1.0, 0.85, 0.3, 0.2 if alert else 0.09))
	if asleep:
		draw_rect(Rect2(-radius * 1.1, -radius * 0.35, radius * 2.2, radius * 0.9), ROBE)
		draw_circle(Vector2(-radius * 1.0, -radius * 0.1), radius * 0.4, SKIN)
		draw_rect(Rect2(-radius * 1.3, -radius * 0.6, radius * 0.6, radius * 0.18), CROWN)
		return
	draw_rect(Rect2(-radius * 0.8, -radius * 0.2, radius * 1.6, radius * 1.2), ROBE)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.5, SKIN)
	draw_rect(Rect2(-radius * 0.5, -radius * 1.05, radius, radius * 0.25), CROWN)
	if robe_cut:
		draw_rect(Rect2(radius * 0.6, radius * 0.7, radius * 0.4, radius * 0.3), Color(0, 0, 0, 0.35))
	if alert:
		draw_rect(Rect2(-5, -radius * 2.5, 10, radius * 0.9), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(0, -radius * 1.3), 6.0, Color(1.0, 0.85, 0.2))
