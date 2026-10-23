class_name ActorBear
extends Node2D
## Placeholder bear: long, dark and shaggy with a lighter snout, drawn side-on and facing the way it
## runs. Poses (all drawn, no words): `windup` (0..1) leans back, reddens and rumbles; `charging`
## leans forward; `slipped` tilts and stumbles with a golden glow marking the double-hit window.

const OUTLINE: Color = Color(0.07, 0.04, 0.03)
const FUR: Color = Color(0.36, 0.2, 0.1)
const FUR_LIGHT: Color = Color(0.5, 0.31, 0.17)
const SNOUT: Color = Color(0.8, 0.64, 0.45)
const ANGRY: Color = Color(0.95, 0.15, 0.1)
const GLOW: Color = Color(1.0, 0.82, 0.2)
const FLASH_SEC: float = 0.25
const RUMBLE_PX: float = 5.0
const LEAN_BACK: float = 0.3
const LEAN_FWD: float = 0.12
const BODY_STRETCH: float = 1.3

## Drawn size. Contact with David uses `hit_radius`.
var radius: float = 100.0
var stunned: bool = false
## 1.0 faces and runs right, -1.0 left.
var facing: float = 1.0
var windup: float = 0.0
var charging: bool = false
var slipped: bool = false
var _flash_left: float = 0.0
var _t: float = 0.0


func hit_radius() -> float:
	return radius * 0.72


func set_stunned(on: bool) -> void:
	stunned = on
	modulate = Color(0.85, 0.85, 1.0, 0.85) if on else Color.WHITE


## Poses the bear. `wind` 0 = none, up to 1 = full windup.
func pose(dir: float, wind: float, charge: bool, slip: bool) -> void:
	facing = dir
	windup = wind
	charging = charge
	slipped = slip
	set_process(true)
	queue_redraw()


func clear_pose() -> void:
	pose(facing, 0.0, false, false)


## Brief white flash when a stone lands.
func flash_hit() -> void:
	_flash_left = FLASH_SEC
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	_flash_left = maxf(0.0, _flash_left - delta)
	queue_redraw()
	if _flash_left <= 0.0 and windup <= 0.0 and not slipped and not charging:
		set_process(false)


func _draw() -> void:
	var f: float = facing
	var lean: float = 0.0
	var shake: Vector2 = Vector2.ZERO
	if windup > 0.0:
		lean = -f * LEAN_BACK * windup
		shake = Vector2(sin(_t * 85.0), cos(_t * 63.0)) * RUMBLE_PX * windup
	elif slipped:
		lean = f * (0.42 + 0.1 * sin(_t * 14.0))
	elif charging:
		lean = f * LEAN_FWD
	if slipped:
		var pulse: float = 0.5 + 0.5 * sin(_t * 9.0)
		draw_circle(Vector2.ZERO, radius * (1.45 + 0.1 * pulse), Color(GLOW.r, GLOW.g, GLOW.b, 0.22 + 0.2 * pulse))
		draw_arc(Vector2.ZERO, radius * 1.5, 0.0, TAU, 40, Color(GLOW.r, GLOW.g, GLOW.b, 0.7 + 0.3 * pulse), 10.0)
	draw_set_transform(shake + Vector2(0, radius * 0.5), lean, Vector2.ONE)
	var tint: float = windup * 0.55
	var fur: Color = FUR.lerp(ANGRY, tint)
	var fur_light: Color = FUR_LIGHT.lerp(ANGRY, tint)
	var pu: float = 0.0
	if charging:
		pu = sin(_t * 22.0) * 6.0
	# Legs.
	for lx in [-0.8, -0.4, 0.45, 0.85]:
		draw_circle(Vector2(f * radius * float(lx), radius * 0.38 + (pu if lx > 0.0 else -pu)), radius * 0.26, OUTLINE)
		draw_circle(Vector2(f * radius * float(lx), radius * 0.38 + (pu if lx > 0.0 else -pu)), radius * 0.2, fur)
	# Body (an ellipse) with outline.
	draw_set_transform(shake + Vector2(0, radius * 0.5), lean, Vector2(BODY_STRETCH, 1.0))
	draw_circle(Vector2(0, -radius * 0.5), radius * 0.86, OUTLINE)
	draw_circle(Vector2(0, -radius * 0.5), radius * 0.78, fur)
	draw_circle(Vector2(0, -radius * 0.3), radius * 0.5, fur_light)
	draw_set_transform(shake + Vector2(0, radius * 0.5), lean, Vector2.ONE)
	# Shoulder hump, head, snout, ears, eye.
	draw_circle(Vector2(f * radius * 0.5, -radius * 1.0), radius * 0.4, fur)
	var head: Vector2 = Vector2(f * radius * 1.1, -radius * 0.75)
	draw_circle(head, radius * 0.5, OUTLINE)
	draw_circle(head, radius * 0.44, fur_light)
	draw_circle(head + Vector2(-f * radius * 0.28, -radius * 0.38), radius * 0.18, OUTLINE)
	draw_circle(head + Vector2(f * radius * 0.12, -radius * 0.42), radius * 0.18, OUTLINE)
	draw_circle(head + Vector2(-f * radius * 0.28, -radius * 0.38), radius * 0.12, fur)
	draw_circle(head + Vector2(f * radius * 0.12, -radius * 0.42), radius * 0.12, fur)
	draw_circle(head + Vector2(f * radius * 0.42, radius * 0.1), radius * 0.24, SNOUT)
	draw_circle(head + Vector2(f * radius * 0.6, radius * 0.04), radius * 0.08, Color.BLACK)
	draw_circle(head + Vector2(f * radius * 0.18, -radius * 0.1), radius * 0.1, Color.WHITE if windup <= 0.0 else Color(1, 0.9, 0.2))
	draw_circle(head + Vector2(f * radius * 0.2, -radius * 0.1), radius * 0.05, Color.BLACK if windup <= 0.0 else ANGRY)
	if _flash_left > 0.0:
		draw_set_transform(shake + Vector2(0, radius * 0.5), lean, Vector2(BODY_STRETCH, 1.0))
		draw_circle(Vector2(0, -radius * 0.5), radius * 0.86, Color(1.0, 1.0, 1.0, 0.85 * _flash_left / FLASH_SEC))
		draw_set_transform(shake + Vector2(0, radius * 0.5), lean, Vector2.ONE)
		draw_circle(head, radius * 0.5, Color(1.0, 1.0, 1.0, 0.85 * _flash_left / FLASH_SEC))
