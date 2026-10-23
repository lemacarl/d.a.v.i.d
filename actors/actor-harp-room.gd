class_name ActorHarpRoom
extends Node2D
## Placeholder art for the harp scene: palace lamps, David with the harp, King Saul, the note
## highway with its gold hit line and pulsing hit zone, sparkles and the 60 s sun bar.
## Purely visual: StageRhythm sets the public fields every tick and this node only draws them.

const SCREEN: Vector2 = Vector2(1920, 1080)
const LAMPS: int = 6
const FLOOR_Y: float = 780.0
const HIGHWAY_TOP: float = 430.0
const HIGHWAY_H: float = 220.0
const SPARKS: int = 32
const SPARK_LIFE: float = 0.7

## Set by the stage.
var line_x: float = 620.0
var line_y: float = 540.0
var zone_radius: float = 110.0
var track_x0: float = 480.0
var track_x1: float = 1620.0
var shown: float = 0.0
var flash: float = 0.0
var approach: float = 0.0
var progress: float = 0.0
var pluck: float = 0.0
var clock: float = 0.0

var _sp_pos: PackedVector2Array = PackedVector2Array()
var _sp_vel: PackedVector2Array = PackedVector2Array()
var _sp_life: PackedFloat32Array = PackedFloat32Array()
var _sp_next: int = 0


func _init() -> void:
	_sp_pos.resize(SPARKS)
	_sp_vel.resize(SPARKS)
	_sp_life.resize(SPARKS)


## Throws a ring of sparkles from `at` (reuses a fixed pool).
func burst(at: Vector2, count: int) -> void:
	for k in count:
		var a: float = TAU * float(k) / float(maxi(1, count)) + float(_sp_next) * 0.37
		var sp: float = 260.0 + 40.0 * float(k % 3)
		_sp_pos[_sp_next] = at
		_sp_vel[_sp_next] = Vector2(cos(a), sin(a)) * sp
		_sp_life[_sp_next] = SPARK_LIFE
		_sp_next = (_sp_next + 1) % SPARKS


## Advances sparkles, flash and pluck decay, then redraws.
func step(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta * 3.5)
	pluck = maxf(0.0, pluck - delta * 4.0)
	for i in SPARKS:
		if _sp_life[i] > 0.0:
			_sp_life[i] -= delta
			_sp_pos[i] += _sp_vel[i] * delta
	queue_redraw()


func lit_lamps() -> int:
	var n: int = 0
	for i in LAMPS:
		if shown > float(i) / float(LAMPS) + 0.0001:
			n += 1
	return n


func _draw() -> void:
	var b: float = shown
	draw_rect(Rect2(0.0, FLOOR_Y, SCREEN.x, SCREEN.y - FLOOR_Y), Color(0.06, 0.045, 0.07).lerp(Color(0.34, 0.21, 0.13), b))
	draw_rect(Rect2(70.0, 0.0, 60.0, FLOOR_Y), Color(0.1, 0.08, 0.13).lerp(Color(0.45, 0.3, 0.2), b))
	draw_rect(Rect2(1790.0, 0.0, 60.0, FLOOR_Y), Color(0.1, 0.08, 0.13).lerp(Color(0.45, 0.3, 0.2), b))
	_draw_lamps()
	_draw_highway()
	_draw_progress()
	_draw_david()
	_draw_saul()
	_draw_sparks()


func _draw_lamps() -> void:
	for i in LAMPS:
		var x: float = 330.0 + float(i) * 250.0
		var y: float = 230.0
		draw_rect(Rect2(x - 9.0, y, 18.0, 70.0), Color(0.3, 0.25, 0.22))
		draw_rect(Rect2(x - 22.0, y - 6.0, 44.0, 12.0), Color(0.55, 0.45, 0.25))
		var power: float = clampf(shown * float(LAMPS) - float(i), 0.0, 1.0)
		if shown <= float(i) / float(LAMPS) + 0.0001:
			draw_circle(Vector2(x, y - 14.0), 8.0, Color(0.25, 0.2, 0.2))
			continue
		var flick: float = 1.0 + 0.1 * sin(clock * 9.0 + float(i) * 1.7)
		draw_circle(Vector2(x, y - 20.0), (60.0 + 80.0 * power) * flick, Color(1.0, 0.75, 0.3, 0.1 + 0.12 * power))
		draw_circle(Vector2(x, y - 20.0), 34.0 * flick, Color(1.0, 0.7, 0.2, 0.55))
		draw_circle(Vector2(x, y - 20.0), 20.0 * flick, Color(1.0, 0.9, 0.5))
		draw_circle(Vector2(x, y - 16.0), 9.0, Color(1.0, 1.0, 0.9))


func _draw_highway() -> void:
	var w: float = track_x1 - track_x0
	draw_rect(Rect2(track_x0, HIGHWAY_TOP, w, HIGHWAY_H), Color(0.1, 0.07, 0.15).lerp(Color(0.32, 0.2, 0.15), shown * 0.8))
	draw_rect(Rect2(track_x0, HIGHWAY_TOP - 6.0, w, 8.0), Color(1.0, 0.82, 0.3))
	draw_rect(Rect2(track_x0, HIGHWAY_TOP + HIGHWAY_H - 2.0, w, 8.0), Color(1.0, 0.82, 0.3))
	draw_line(Vector2(track_x0, line_y), Vector2(track_x1, line_y), Color(1.0, 0.9, 0.6, 0.25), 3.0)
	var pulse: float = 0.5 + 0.5 * sin(clock * (4.0 + 10.0 * approach))
	var r: float = zone_radius * (1.0 + 0.1 * approach * pulse + 0.18 * flash)
	var c: Vector2 = Vector2(line_x, line_y)
	draw_circle(c, r * 1.35, Color(1.0, 0.85, 0.3, 0.1 + 0.12 * approach))
	draw_circle(c, r, Color(1.0, 0.88, 0.35, 0.18 + 0.2 * approach * pulse + 0.5 * flash))
	draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.4, 0.7 + 0.3 * flash), 8.0)
	draw_rect(Rect2(line_x - 16.0, HIGHWAY_TOP - 40.0, 32.0, HIGHWAY_H + 80.0), Color(1.0, 0.85, 0.3, 0.25))
	draw_rect(Rect2(line_x - 6.0, HIGHWAY_TOP - 40.0, 12.0, HIGHWAY_H + 80.0), Color(1.0, 0.93, 0.55))
	if flash > 0.0:
		draw_arc(c, zone_radius * (1.0 + (1.0 - flash) * 0.9), 0.0, TAU, 48, Color(1.0, 1.0, 0.8, flash), 10.0)


func _draw_progress() -> void:
	var y: float = HIGHWAY_TOP + HIGHWAY_H + 100.0
	var x1: float = lerpf(line_x, track_x1, 1.0)
	draw_rect(Rect2(line_x, y - 7.0, x1 - line_x, 14.0), Color(0.2, 0.15, 0.25, 0.8))
	var px: float = lerpf(line_x, x1, clampf(progress, 0.0, 1.0))
	draw_rect(Rect2(line_x, y - 7.0, px - line_x, 14.0), Color(1.0, 0.82, 0.3))
	draw_circle(Vector2(px, y), 34.0, Color(1.0, 0.85, 0.3, 0.25))
	draw_circle(Vector2(px, y), 22.0, Color(1.0, 0.9, 0.4))
	for k in 8:
		var a: float = TAU * float(k) / 8.0
		var d: Vector2 = Vector2(cos(a), sin(a))
		draw_line(Vector2(px, y) + d * 28.0, Vector2(px, y) + d * 40.0, Color(1.0, 0.9, 0.4), 4.0)


func _draw_david() -> void:
	var bob: float = -10.0 * pluck
	var p: Vector2 = Vector2(250.0, 560.0 + bob)
	draw_circle(p + Vector2(0.0, 40.0), 70.0, Color(0.25, 0.4, 0.75))
	draw_circle(p + Vector2(0.0, -50.0), 36.0, Color(0.95, 0.75, 0.6))
	draw_circle(p + Vector2(0.0, -70.0), 30.0, Color(0.6, 0.25, 0.12))
	draw_circle(p + Vector2(-12.0, -48.0), 4.0, Color(0.1, 0.1, 0.1))
	draw_circle(p + Vector2(12.0, -48.0), 4.0, Color(0.1, 0.1, 0.1))
	var hx: Vector2 = p + Vector2(95.0, -10.0)
	var gold: Color = Color(1.0, 0.8, 0.25).lerp(Color(1.0, 1.0, 0.8), pluck)
	draw_line(hx + Vector2(0.0, 60.0), hx + Vector2(0.0, -80.0), gold, 10.0)
	draw_arc(hx + Vector2(70.0, -10.0), 90.0, PI * 0.55, PI * 1.45, 16, gold, 10.0)
	draw_line(hx + Vector2(0.0, 80.0), hx + Vector2(70.0, 80.0), gold, 10.0)
	for k in 4:
		var sx: float = 14.0 + float(k) * 16.0
		draw_line(hx + Vector2(sx, -70.0 + float(k) * 8.0), hx + Vector2(sx, 70.0), Color(1.0, 1.0, 0.85, 0.6 + 0.4 * pluck), 3.0)
	draw_circle(p + Vector2(60.0, 10.0), 14.0, Color(0.95, 0.75, 0.6))


func _draw_saul() -> void:
	var p: Vector2 = Vector2(1700.0, 570.0)
	draw_rect(Rect2(p.x - 100.0, p.y - 160.0, 200.0, 330.0), Color(0.22, 0.12, 0.1).lerp(Color(0.5, 0.3, 0.2), shown))
	draw_circle(p + Vector2(0.0, 60.0), 85.0, Color(0.3, 0.12, 0.38).lerp(Color(0.62, 0.3, 0.7), shown))
	var head: Vector2 = p + Vector2(0.0, lerpf(-5.0, -75.0, shown))
	draw_circle(head, 44.0, Color(0.9, 0.7, 0.58))
	draw_rect(Rect2(head.x - 40.0, head.y - 64.0, 80.0, 20.0), Color(1.0, 0.82, 0.25))
	for k in 3:
		var tx: float = head.x - 32.0 + float(k) * 32.0
		draw_rect(Rect2(tx - 7.0, head.y - 84.0, 14.0, 22.0), Color(1.0, 0.82, 0.25))
	draw_circle(head + Vector2(-15.0, -4.0), 4.5, Color(0.1, 0.1, 0.1))
	draw_circle(head + Vector2(15.0, -4.0), 4.5, Color(0.1, 0.1, 0.1))
	if shown > 0.65:
		draw_arc(head + Vector2(0.0, 12.0), 18.0, 0.2, PI - 0.2, 10, Color(0.5, 0.15, 0.15), 4.0)
	else:
		draw_line(head + Vector2(-14.0, 22.0), head + Vector2(14.0, 22.0), Color(0.5, 0.15, 0.15), 4.0)
	if shown < 0.5:
		draw_circle(head + Vector2(-60.0, 6.0), 17.0, Color(0.9, 0.7, 0.58))
		draw_circle(head + Vector2(60.0, 6.0), 17.0, Color(0.9, 0.7, 0.58))


func _draw_sparks() -> void:
	for i in SPARKS:
		var life: float = _sp_life[i]
		if life <= 0.0:
			continue
		var f: float = life / SPARK_LIFE
		draw_circle(_sp_pos[i], 5.0 + 9.0 * f, Color(1.0, 0.95, 0.6, f))
