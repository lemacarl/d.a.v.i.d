class_name ActorParade
extends Node2D
## Placeholder art for the ark parade (4.5): a hit line with a pulsing zone on a note highway, a D-pad
## cross that lights the pressed direction, the priests carrying the ark, David dancing, and up to
## `max_dancers` dancers and `max_musicians` musicians who join one by one.
## Purely visual and allocation free per frame: StageRhythm sets the public fields; this node only draws them.

const SCREEN: Vector2 = Vector2(1920, 1080)
const HIGHWAY_TOP: float = 430.0
const HIGHWAY_H: float = 220.0
const GROUND_Y: float = 800.0
const SPARKS: int = 32
const SPARK_LIFE: float = 0.7
const FIGURE_H: float = 150.0
const DPAD_POS: Vector2 = Vector2(250.0, 540.0)
const DPAD_ARM: float = 70.0
const ROW_COUNT: int = 3
const FIGURE_HARD_CAP: int = 48

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
var clock: float = 0.0
## Last pressed direction (ActorArrowNote.Dir) and how lit the D-pad cross still is (1 to 0).
var press_dir: int = 0
var press_glow: float = 0.0
var dance: float = 0.0
var max_dancers: int = 24
var max_musicians: int = 8
var dancers: int = 0:
	set(value):
		dancers = clampi(value, 0, mini(max_dancers, FIGURE_HARD_CAP))
var musicians: int = 0:
	set(value):
		musicians = clampi(value, 0, mini(max_musicians, FIGURE_HARD_CAP))

var _sp_pos: PackedVector2Array = PackedVector2Array()
var _sp_vel: PackedVector2Array = PackedVector2Array()
var _sp_life: PackedFloat32Array = PackedFloat32Array()
var _sp_next: int = 0
var _spot: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	_sp_pos.resize(SPARKS)
	_sp_vel.resize(SPARKS)
	_sp_life.resize(SPARKS)
	# Fixed standing places, nearest David first, alternating right and left, in rows going back.
	_spot.resize(FIGURE_HARD_CAP)
	for i in FIGURE_HARD_CAP:
		var row: int = i % ROW_COUNT
		var col: int = floori(float(i) / float(ROW_COUNT))
		var side: float = 1.0 if (col % 2) == 0 else -1.0
		var step: int = floori(float(col) / 2.0) + 1
		var x: float = 960.0 + side * (170.0 * float(step) + 55.0 * float(row))
		_spot[i] = Vector2(clampf(x, 90.0, 1830.0), 880.0 + 55.0 * float(row))


func burst(at: Vector2, count: int) -> void:
	for k in count:
		var a: float = TAU * float(k) / float(maxi(1, count)) + float(_sp_next) * 0.37
		var sp: float = 260.0 + 40.0 * float(k % 3)
		_sp_pos[_sp_next] = at
		_sp_vel[_sp_next] = Vector2(cos(a), sin(a)) * sp
		_sp_life[_sp_next] = SPARK_LIFE
		_sp_next = (_sp_next + 1) % SPARKS


## A direction was pressed (lights the D-pad cross).
func pressed(dir: int) -> void:
	press_dir = dir
	press_glow = 1.0


func step(delta: float) -> void:
	clock += delta
	flash = maxf(0.0, flash - delta * 3.5)
	press_glow = maxf(0.0, press_glow - delta * 3.0)
	dance = maxf(0.0, dance - delta * 2.5)
	for i in SPARKS:
		if _sp_life[i] > 0.0:
			_sp_life[i] -= delta
			_sp_pos[i] += _sp_vel[i] * delta
	queue_redraw()


## Standing place of figure `i` (tests: all inside the screen).
func spot(i: int) -> Vector2:
	return _spot[clampi(i, 0, FIGURE_HARD_CAP - 1)]


func _draw() -> void:
	draw_rect(Rect2(0.0, GROUND_Y, SCREEN.x, SCREEN.y - GROUND_Y), Color(0.4, 0.3, 0.2).lerp(Color(0.62, 0.45, 0.28), shown))
	_draw_bunting()
	_draw_highway()
	_draw_dpad()
	_draw_progress()
	_draw_ark_party()
	for i in dancers:
		_draw_dancer(_spot[i], float(i), i % 2 == 0)
	for i in musicians:
		_draw_musician(Vector2(150.0 + 1620.0 * float(i) / float(maxi(1, max_musicians - 1)), 760.0), float(i))
	_draw_david(Vector2(960.0, 930.0))
	_draw_sparks()


func _draw_bunting() -> void:
	var flags: int = 12
	for k in flags:
		var x: float = 100.0 + float(k) * 150.0
		var sag: float = 22.0 * sin(float(k) * 0.5)
		var c: Color = ActorArrowNote.COLORS[k % 4]
		draw_colored_polygon(PackedVector2Array([
			Vector2(x, 120.0 + sag), Vector2(x + 60.0, 120.0 + sag), Vector2(x + 30.0, 190.0 + sag + 6.0 * sin(clock * 3.0 + float(k)))]), c)
	draw_line(Vector2(60.0, 118.0), Vector2(1860.0, 118.0), Color(0.3, 0.2, 0.15), 5.0)


func _draw_highway() -> void:
	var w: float = track_x1 - track_x0
	draw_rect(Rect2(track_x0, HIGHWAY_TOP, w, HIGHWAY_H), Color(0.12, 0.1, 0.2, 0.85).lerp(Color(0.35, 0.22, 0.16, 0.85), shown * 0.8))
	draw_rect(Rect2(track_x0, HIGHWAY_TOP - 6.0, w, 8.0), Color(1.0, 0.82, 0.3))
	draw_rect(Rect2(track_x0, HIGHWAY_TOP + HIGHWAY_H - 2.0, w, 8.0), Color(1.0, 0.82, 0.3))
	var pulse: float = 0.5 + 0.5 * sin(clock * (4.0 + 10.0 * approach))
	var r: float = zone_radius * (1.0 + 0.1 * approach * pulse + 0.18 * flash)
	var c: Vector2 = Vector2(line_x, line_y)
	draw_circle(c, r * 1.35, Color(1.0, 0.85, 0.3, 0.1 + 0.12 * approach))
	draw_circle(c, r, Color(1.0, 0.88, 0.35, 0.18 + 0.2 * approach * pulse + 0.5 * flash))
	draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 0.9, 0.4, 0.7 + 0.3 * flash), 8.0)
	if flash > 0.0:
		draw_arc(c, zone_radius * (1.0 + (1.0 - flash) * 0.9), 0.0, TAU, 48, Color(1.0, 1.0, 0.8, flash), 10.0)


func _draw_dpad() -> void:
	draw_circle(DPAD_POS, DPAD_ARM * 1.55, Color(0.1, 0.08, 0.14, 0.6))
	for d in 4:
		var v: Vector2 = Vector2.UP
		match d:
			ActorArrowNote.Dir.DOWN:
				v = Vector2.DOWN
			ActorArrowNote.Dir.LEFT:
				v = Vector2.LEFT
			ActorArrowNote.Dir.RIGHT:
				v = Vector2.RIGHT
		var lit: float = press_glow if d == press_dir else 0.0
		var base: Color = ActorArrowNote.COLORS[d]
		var col: Color = Color(base.r, base.g, base.b, 0.35 + 0.65 * lit)
		var s: Vector2 = v.orthogonal()
		var c: Vector2 = DPAD_POS + v * DPAD_ARM * 0.8
		draw_colored_polygon(PackedVector2Array([c + v * 34.0, c - v * 22.0 + s * 34.0, c - v * 22.0 - s * 34.0]), col)


func _draw_progress() -> void:
	var y: float = HIGHWAY_TOP + HIGHWAY_H + 80.0
	draw_rect(Rect2(line_x, y - 7.0, track_x1 - line_x, 14.0), Color(0.2, 0.15, 0.25, 0.8))
	var px: float = lerpf(line_x, track_x1, clampf(progress, 0.0, 1.0))
	draw_rect(Rect2(line_x, y - 7.0, px - line_x, 14.0), Color(1.0, 0.82, 0.3))
	draw_circle(Vector2(px, y), 22.0, Color(1.0, 0.9, 0.4))


## Four priests carry the ark (a gold box on poles) across the back of the parade.
func _draw_ark_party() -> void:
	var bob: float = 4.0 * sin(clock * 3.0)
	var ark: Vector2 = Vector2(960.0, 720.0 + bob)
	draw_rect(Rect2(ark.x - 90.0, ark.y - 50.0, 180.0, 70.0), Color(0.95, 0.78, 0.25))
	draw_rect(Rect2(ark.x - 90.0, ark.y - 50.0, 180.0, 12.0), Color(1.0, 0.92, 0.55))
	draw_line(ark + Vector2(-130.0, 40.0), ark + Vector2(130.0, 40.0), Color(0.5, 0.33, 0.15), 8.0)
	for k in 4:
		var px: float = ark.x - 130.0 + 86.6 * float(k)
		_person(Vector2(px, 790.0 + bob), 105.0, Color(0.92, 0.9, 0.85), 0.0)
	for k in 2:
		var cx: float = ark.x - 28.0 + 56.0 * float(k)
		draw_colored_polygon(PackedVector2Array([Vector2(cx - 22.0, ark.y - 50.0), Vector2(cx + 22.0, ark.y - 50.0), Vector2(cx, ark.y - 95.0)]), Color(1.0, 0.9, 0.5))


func _draw_david(at: Vector2) -> void:
	var lift: float = 1.0 + dance
	var hop: float = absf(sin(clock * 7.0)) * 26.0 * lift
	_person(at + Vector2(0.0, -hop), FIGURE_H * 1.25, Color(0.25, 0.4, 0.75), 1.0 + dance, press_dir if press_glow > 0.0 else -1)


func _draw_dancer(at: Vector2, phase: float, flip: bool) -> void:
	var hop: float = absf(sin(clock * 6.0 + phase * 0.9)) * 18.0
	var robe: Color = ActorArrowNote.COLORS[int(phase) % 4].darkened(0.25)
	_person(at + Vector2(0.0, -hop), FIGURE_H * (0.9 if flip else 0.82), robe, 1.0)


func _draw_musician(at: Vector2, phase: float) -> void:
	var sway: float = sin(clock * 3.0 + phase)
	_person(at + Vector2(sway * 6.0, 0.0), FIGURE_H * 0.7, Color(0.55, 0.4, 0.2), 0.0)
	var h: float = FIGURE_H * 0.7
	if int(phase) % 2 == 0:
		draw_line(at + Vector2(0.15 * h, -0.55 * h), at + Vector2(0.45 * h, -0.8 * h + sway * 4.0), Color(0.93, 0.82, 0.55), 6.0)
	else:
		draw_arc(at + Vector2(0.2 * h, -0.45 * h), 0.14 * h, 0.0, TAU, 14, Color(0.9, 0.75, 0.3), 4.0)


## A simple person: robe, head, arms (raised `arms`: 0 down, 1 up; `pose` 0..3 = the pressed D-pad direction or -1).
func _person(at: Vector2, h: float, robe: Color, arms: float, pose: int = -1) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(-0.17 * h, 0.0), at + Vector2(0.17 * h, 0.0), at + Vector2(0.12 * h, -0.62 * h), at + Vector2(-0.12 * h, -0.62 * h)]), robe)
	draw_circle(at + Vector2(0.0, -0.76 * h), 0.115 * h, Color(0.87, 0.68, 0.5))
	var l: Vector2 = Vector2(-0.18 * h, -0.34 * h)
	var r: Vector2 = Vector2(0.2 * h, -0.38 * h)
	if arms > 0.0:
		l = Vector2(-0.3 * h, -0.95 * h)
		r = Vector2(0.3 * h, -0.95 * h)
	match pose:
		ActorArrowNote.Dir.DOWN:
			l = Vector2(-0.26 * h, -0.2 * h)
			r = Vector2(0.26 * h, -0.2 * h)
		ActorArrowNote.Dir.LEFT:
			l = Vector2(-0.5 * h, -0.62 * h)
			r = Vector2(-0.2 * h, -0.95 * h)
		ActorArrowNote.Dir.RIGHT:
			l = Vector2(0.2 * h, -0.95 * h)
			r = Vector2(0.5 * h, -0.62 * h)
	draw_line(at + Vector2(-0.12 * h, -0.58 * h), at + l, robe.lightened(0.15), 0.06 * h)
	draw_line(at + Vector2(0.12 * h, -0.58 * h), at + r, robe.lightened(0.15), 0.06 * h)
	draw_circle(at + l, 0.035 * h, Color(0.87, 0.68, 0.5))
	draw_circle(at + r, 0.035 * h, Color(0.87, 0.68, 0.5))


func _draw_sparks() -> void:
	for i in SPARKS:
		var life: float = _sp_life[i]
		if life <= 0.0:
			continue
		var f: float = life / SPARK_LIFE
		draw_circle(_sp_pos[i], 5.0 + 9.0 * f, Color(1.0, 0.95, 0.6, f))
