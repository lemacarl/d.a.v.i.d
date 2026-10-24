class_name ActorArkNightHills
extends ActorScene
## 4.8 final shot: the hills of Bethlehem at night, sheep resting, a star overhead (placeholder shapes).
## Purely visual; the cutscene shows it for the visual cue and feeds it time.

const HORIZON_Y: float = 640.0
const STAR_POS: Vector2 = Vector2(960.0, 230.0)
const STAR_RAYS: int = 8
const STARS: int = 40
const SHEEP_SPOTS: Array[Vector2] = [
	Vector2(520, 850), Vector2(700, 905), Vector2(880, 840), Vector2(1080, 910), Vector2(1260, 860), Vector2(1440, 900)]

var _clock: float = 0.0
var _star_pts: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	_star_pts.resize(STARS)
	for i in STARS:
		_star_pts[i] = Vector2(
			fposmod(float(i) * 197.0 + 53.0, SCREEN.x),
			fposmod(float(i) * 83.0 + 31.0, HORIZON_Y - 120.0) + 30.0)


func advance(delta: float) -> void:
	_clock += delta
	queue_redraw()


func _draw() -> void:
	var w: float = SCREEN.x
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, HORIZON_Y + 60.0), Vector2(0, HORIZON_Y + 60.0)]),
		PackedColorArray([Color(0.03, 0.04, 0.14), Color(0.03, 0.04, 0.14), Color(0.16, 0.18, 0.4), Color(0.16, 0.18, 0.4)]))
	for i in STARS:
		var tw: float = 0.5 + 0.5 * sin(_clock * 1.7 + float(i))
		draw_circle(_star_pts[i], 2.0 + 1.5 * tw, Color(1.0, 1.0, 0.9, 0.35 + 0.4 * tw))
	_draw_star()
	draw_colored_polygon(_hill(0.4, 120.0, 2.0, 70.0), Color(0.08, 0.12, 0.2))
	draw_colored_polygon(_hill(2.1, 90.0, 3.0, 20.0), Color(0.06, 0.1, 0.16))
	draw_rect(Rect2(0.0, HORIZON_Y + 40.0, w, SCREEN.y - HORIZON_Y - 40.0), Color(0.07, 0.13, 0.12))
	for i in SHEEP_SPOTS.size():
		_draw_sheep(SHEEP_SPOTS[i], float(i))


func _draw_star() -> void:
	var pulse: float = 1.0 + 0.06 * sin(_clock * 2.0)
	draw_circle(STAR_POS, 150.0 * pulse, Color(1.0, 0.92, 0.55, 0.1))
	draw_circle(STAR_POS, 95.0 * pulse, Color(1.0, 0.92, 0.55, 0.2))
	for k in STAR_RAYS:
		var a: float = TAU * float(k) / float(STAR_RAYS) + 0.2 * sin(_clock * 0.5)
		var d: Vector2 = Vector2.from_angle(a)
		var long: float = 120.0 if k % 2 == 0 else 70.0
		draw_line(STAR_POS + d * 26.0, STAR_POS + d * long * pulse, Color(1.0, 0.95, 0.7, 0.9), 6.0)
	draw_circle(STAR_POS, 30.0, Color(1.0, 0.97, 0.8))


## A resting sheep: a white body on the grass, a dark head tucked in front, a slow breath.
func _draw_sheep(at: Vector2, phase: float) -> void:
	var breath: float = 1.0 + 0.03 * sin(_clock * 1.4 + phase)
	draw_circle(at + Vector2(0.0, 6.0), 44.0 * breath, Color(0.55, 0.57, 0.65))
	draw_circle(at + Vector2(-18.0, -4.0), 34.0 * breath, Color(0.88, 0.89, 0.92))
	draw_circle(at + Vector2(16.0, -6.0), 36.0 * breath, Color(0.9, 0.9, 0.93))
	draw_circle(at + Vector2(46.0, 4.0), 17.0, Color(0.16, 0.16, 0.2))


func _hill(phase: float, amp: float, freq: float, lift: float) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var steps: int = 24
	for i in steps + 1:
		var x: float = SCREEN.x * float(i) / float(steps)
		pts.append(Vector2(x, HORIZON_Y + 80.0 - lift - amp * (0.5 + 0.5 * sin(x / SCREEN.x * freq * PI + phase))))
	pts.append(Vector2(SCREEN.x, HORIZON_Y + 100.0))
	pts.append(Vector2(0.0, HORIZON_Y + 100.0))
	return pts
