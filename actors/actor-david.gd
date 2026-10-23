class_name ActorDavid
extends Node2D
## Placeholder David: a tan head over a blue tunic with a staff. Pure drawing, no logic.

const SKIN: Color = Color(0.87, 0.68, 0.5)
const TUNIC: Color = Color(0.25, 0.4, 0.75)
const STAFF: Color = Color(0.5, 0.33, 0.15)

var radius: float = 30.0
var facing: Vector2 = Vector2.RIGHT


func set_facing(dir: Vector2) -> void:
	if dir.length_squared() < 0.01 or dir.is_equal_approx(facing):
		return
	facing = dir.normalized()
	queue_redraw()


## Blinks while invulnerable after a hit.
func set_flash(on: bool) -> void:
	modulate.a = 0.45 if on else 1.0


func _draw() -> void:
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.2), TUNIC)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.5, SKIN)
	draw_line(facing * radius * 0.9 + Vector2(0, radius), facing * radius * 0.9 + Vector2(0, -radius * 1.2), STAFF, 5.0)
