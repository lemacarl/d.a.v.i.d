class_name ActorLion
extends Node2D
## Placeholder lion: a big golden face inside a dark brown mane, with a black outline so it
## stands out from the field and from the bear. Round and golden; the bear is long and dark.

const OUTLINE: Color = Color(0.12, 0.07, 0.03)
const BODY: Color = Color(0.98, 0.76, 0.28)
const MANE: Color = Color(0.62, 0.3, 0.08)
const MANE_LIGHT: Color = Color(0.8, 0.45, 0.12)
const FLASH_SEC: float = 0.25

## Drawn size. Contact with David uses `hit_radius`.
var radius: float = 76.0
var stunned: bool = false
var _flash_left: float = 0.0
var _t: float = 0.0


func hit_radius() -> float:
	return radius * 0.8


func set_stunned(on: bool) -> void:
	stunned = on
	modulate = Color(0.85, 0.85, 1.0, 0.85) if on else Color.WHITE


## Brief white flash when a stone lands.
func flash_hit() -> void:
	_flash_left = FLASH_SEC
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_flash_left = maxf(0.0, _flash_left - delta)
	queue_redraw()
	if _flash_left <= 0.0:
		set_process(false)


func _draw() -> void:
	draw_circle(Vector2.ZERO, radius * 1.06, OUTLINE)
	draw_circle(Vector2.ZERO, radius, MANE)
	draw_circle(Vector2.ZERO, radius * 0.86, MANE_LIGHT)
	draw_circle(Vector2(-radius * 0.62, -radius * 0.66), radius * 0.22, BODY)
	draw_circle(Vector2(radius * 0.62, -radius * 0.66), radius * 0.22, BODY)
	draw_circle(Vector2.ZERO, radius * 0.6, BODY)
	draw_circle(Vector2(0, radius * 0.2), radius * 0.26, Color(1.0, 0.92, 0.7))
	draw_circle(Vector2(0, radius * 0.06), radius * 0.1, Color(0.3, 0.12, 0.1))
	draw_circle(Vector2(radius * 0.22, -radius * 0.14), radius * 0.1, Color.BLACK)
	draw_circle(Vector2(-radius * 0.22, -radius * 0.14), radius * 0.1, Color.BLACK)
	if _flash_left > 0.0:
		draw_circle(Vector2.ZERO, radius * 1.06, Color(1.0, 1.0, 1.0, 0.85 * _flash_left / FLASH_SEC))
