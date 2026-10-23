class_name ActorCompanion
extends Node2D
## Placeholder Mighty Man: a green-cloaked follower who walks beside David. Pure drawing plus a
## tiny follow step; the stage decides when it throws.

const CLOAK: Color = Color(0.3, 0.55, 0.35)
const SKIN: Color = Color(0.82, 0.62, 0.45)

var radius: float = 26.0
## Where this companion stands relative to David.
var offset: Vector2 = Vector2.ZERO


## Moves toward `target_pos` + offset at `speed` px/s without overshooting.
func follow(target_pos: Vector2, speed: float, delta: float) -> void:
	position = position.move_toward(target_pos + offset, speed * delta)


## Puts the companion at its spot beside `target_pos` at once.
func place(target_pos: Vector2) -> void:
	position = target_pos + offset


func _draw() -> void:
	draw_rect(Rect2(-radius * 0.7, -radius * 0.2, radius * 1.4, radius * 1.2), CLOAK)
	draw_circle(Vector2(0, -radius * 0.55), radius * 0.5, SKIN)
