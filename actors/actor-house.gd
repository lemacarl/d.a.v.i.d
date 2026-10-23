class_name ActorHouse
extends ActorScene
## 1.5: inside Jesse's house. Seven brothers stand in a row (Eliab, the eldest, is the tallest) and Samuel
## walks past each one, pausing. Gold light fills the screen. David runs in with his staff, out of breath,
## and Samuel pours oil on his head: gold sparkles. Placeholder shapes, a fixed number of nodes.

const BROTHER_COUNT: int = 7
const ROW_Y: float = 790.0
const ROW_X0: float = 560.0
const ROW_DX: float = 135.0
const FRONT_Y: float = 880.0
const SAMUEL_START_X: float = -90.0
const SAMUEL_SPEED: float = 380.0
const PAUSE_SEC: float = 0.9
const FIRST_PAUSE_SEC: float = 3.2
const DOOR_X: float = 1690.0
const DAVID_STOP_X: float = 1560.0
const RUN_SEC: float = 1.7
const POUR_RAISE_SEC: float = 0.7
const POUR_SEC: float = 1.8
const GLOW_RATE: float = 2.5
const BROTHER_HEIGHTS: Array[float] = [330.0, 255.0, 250.0, 245.0, 240.0, 235.0, 230.0]
const BROTHER_ROBES: Array[Color] = [
	Color(0.7, 0.25, 0.25), Color(0.3, 0.55, 0.4), Color(0.8, 0.55, 0.2), Color(0.35, 0.4, 0.7),
	Color(0.55, 0.35, 0.6), Color(0.25, 0.55, 0.6), Color(0.65, 0.5, 0.35)]
const BROTHER_HAIR: Array[Color] = [
	Color(0.15, 0.1, 0.08), Color(0.3, 0.2, 0.1), Color(0.2, 0.12, 0.08), Color(0.4, 0.25, 0.1),
	Color(0.12, 0.1, 0.1), Color(0.35, 0.22, 0.12), Color(0.25, 0.15, 0.1)]

enum Phase { WALKING, DAVID_IN, POURING, DONE }

var jesse: ActorFigure = null
var brothers: Array[ActorFigure] = []
var samuel: ActorFigure = null
var david: ActorFigure = null
var sparkles: ActorSparkles = null
var phase: Phase = Phase.WALKING
var glow_alpha: float = 0.0
var oil_amount: float = 0.0
var walking: bool = false

var _glow: Node2D = null
var _oil: Node2D = null
var _glow_on: bool = false
var _stop: int = 0
var _pause_left: float = 0.0
var _clock: float = 0.0
var _phase_clock: float = 0.0
var _hurry: bool = false


func _init() -> void:
	jesse = _person(Vector2(410, ROW_Y - 20.0), 270.0, Color(0.5, 0.4, 0.3), Color(0.85, 0.85, 0.82))
	jesse.beard = true
	jesse.beard_color = Color(0.85, 0.85, 0.82)
	jesse.staff = true
	jesse.scale.x = -1.0
	for i in BROTHER_COUNT:
		var b: ActorFigure = _person(Vector2(ROW_X0 + ROW_DX * float(i), ROW_Y), BROTHER_HEIGHTS[i], BROTHER_ROBES[i], BROTHER_HAIR[i])
		brothers.append(b)
	samuel = _person(Vector2(SAMUEL_START_X, FRONT_Y), 320.0, Color(0.93, 0.92, 0.88), Color(0.9, 0.9, 0.88))
	samuel.trim = Color(0.35, 0.4, 0.75)
	samuel.beard = true
	samuel.horn = true
	david = _person(Vector2(DOOR_X, FRONT_Y + 10.0), 170.0, Color(0.25, 0.4, 0.75), Color(0.45, 0.28, 0.12))
	david.staff = true
	david.visible = false
	_glow = _Glow.new()
	_glow.modulate.a = 0.0
	_glow.visible = false
	add_child(_glow)
	_oil = _OilStream.new()
	_oil.visible = false
	add_child(_oil)
	sparkles = ActorSparkles.new()
	add_child(sparkles)


func _draw() -> void:
	var w: float = SCREEN.x
	# Wall, ceiling beam, floor.
	draw_rect(Rect2(0, 0, w, 730), Color(0.8, 0.62, 0.42))
	draw_rect(Rect2(0, 0, w, 80), Color(0.42, 0.28, 0.17))
	for x in [0.0, 640.0, 1280.0]:
		draw_rect(Rect2(x, 0, 36, 730), Color(0.5, 0.34, 0.2))
	draw_rect(Rect2(0, 730, w, SCREEN.y - 730.0), Color(0.55, 0.38, 0.24))
	for y in [800.0, 880.0, 970.0, 1060.0]:
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.45, 0.3, 0.19), 4.0)
	# A rug under the row.
	draw_colored_polygon(PackedVector2Array([Vector2(470, 760), Vector2(1560, 760), Vector2(1660, 840), Vector2(380, 840)]), Color(0.62, 0.25, 0.22))
	draw_colored_polygon(PackedVector2Array([Vector2(510, 770), Vector2(1520, 770), Vector2(1600, 830), Vector2(430, 830)]), Color(0.78, 0.55, 0.3))
	# Two small windows.
	for x in [760.0, 1060.0]:
		draw_rect(Rect2(x - 8, 142, 156, 176), Color(0.42, 0.28, 0.17))
		draw_rect(Rect2(x, 150, 140, 160), Color(0.72, 0.87, 0.95))
		draw_line(Vector2(x + 70, 150), Vector2(x + 70, 310), Color(0.42, 0.28, 0.17), 6.0)
		draw_line(Vector2(x, 230), Vector2(x + 140, 230), Color(0.42, 0.28, 0.17), 6.0)
	# The doorway on the right: bright daylight outside.
	draw_rect(Rect2(1580, 300, 230, 430), Color(0.36, 0.23, 0.13))
	draw_rect(Rect2(1600, 320, 190, 410), Color(1.0, 0.93, 0.72))
	draw_rect(Rect2(1600, 600, 190, 130), Color(0.55, 0.72, 0.4))
	# A table with bowls at the back left.
	draw_rect(Rect2(20, 610, 270, 26), Color(0.45, 0.3, 0.17))
	draw_rect(Rect2(50, 636, 22, 120), Color(0.4, 0.26, 0.15))
	draw_rect(Rect2(240, 636, 22, 120), Color(0.4, 0.26, 0.15))
	draw_circle(Vector2(110, 604), 26.0, Color(0.7, 0.4, 0.25))
	draw_circle(Vector2(210, 606), 22.0, Color(0.85, 0.7, 0.4))


func _person(pos: Vector2, height: float, robe_color: Color, hair_color: Color) -> ActorFigure:
	var f: ActorFigure = ActorFigure.new()
	f.setup(height, robe_color, hair_color)
	f.position = pos
	add_child(f)
	return f


func _stop_x(i: int) -> float:
	return ROW_X0 + ROW_DX * float(i) - 80.0


func play(action: StringName) -> void:
	match action:
		&"show":
			phase = Phase.WALKING
		&"david-runs-in":
			_enter(Phase.DAVID_IN)
			david.visible = true
			david.position = Vector2(DOOR_X, FRONT_Y + 10.0)
			_hurry = true
		&"pour-oil":
			if phase == Phase.WALKING:
				play(&"david-runs-in")
			if phase == Phase.DAVID_IN:
				_snap_david()
			_enter(Phase.POURING)


func set_glow(on: bool) -> void:
	_glow_on = on
	if on:
		_glow.visible = true


func advance(delta: float) -> void:
	_clock += delta
	_phase_clock += delta
	_move_samuel(delta)
	_move_david(delta)
	_pour(delta)
	if _glow_on:
		glow_alpha = minf(glow_alpha + GLOW_RATE * delta, 1.0)
	else:
		glow_alpha = maxf(glow_alpha - GLOW_RATE * delta, 0.0)
	_glow.modulate.a = glow_alpha
	_glow.visible = glow_alpha > 0.0
	sparkles.advance(delta)
	# The brothers and Jesse breathe a little so the row is not frozen.
	for i in BROTHER_COUNT:
		brothers[i].scale.y = 1.0 + sin(_clock * 1.5 + float(i)) * 0.006


func _enter(p: Phase) -> void:
	phase = p
	_phase_clock = 0.0


func _move_samuel(delta: float) -> void:
	walking = false
	var goal: float = 0.0
	var speed: float = SAMUEL_SPEED
	if phase >= Phase.POURING:
		goal = DAVID_STOP_X - 130.0
		speed *= 3.0
	elif _stop < BROTHER_COUNT:
		if _pause_left > 0.0:
			_pause_left = maxf(_pause_left - delta, 0.0)
			return
		goal = _stop_x(_stop)
		speed *= 3.0 if _hurry else 1.0
	elif phase == Phase.DAVID_IN and _phase_clock >= RUN_SEC:
		goal = DAVID_STOP_X - 130.0
		speed *= 3.0
	else:
		return
	var dx: float = goal - samuel.position.x
	var step: float = minf(absf(dx), speed * delta)
	samuel.position.x += signf(dx) * step
	walking = step > 0.0
	samuel.position.y = FRONT_Y - (absf(sin(_clock * 9.0)) * 6.0 if walking else 0.0)
	if absf(goal - samuel.position.x) < 0.5 and phase < Phase.POURING and _stop < BROTHER_COUNT:
		_pause_left = 0.0 if _hurry else (FIRST_PAUSE_SEC if _stop == 0 else PAUSE_SEC)
		_stop += 1


func _move_david(delta: float) -> void:
	if not david.visible:
		return
	if phase == Phase.DAVID_IN:
		var k: float = clampf(_phase_clock / RUN_SEC, 0.0, 1.0)
		david.position.x = lerpf(DOOR_X, DAVID_STOP_X, k)
		# Running: quick hops.
		david.position.y = FRONT_Y + 10.0 - (absf(sin(_clock * 14.0)) * 14.0 if k < 1.0 else 0.0)
	# Out of breath: the chest heaves.
	david.scale = Vector2(1.0, 1.0 + sin(_clock * 11.0) * 0.025) if phase != Phase.DONE else Vector2.ONE


func _snap_david() -> void:
	david.position = Vector2(DAVID_STOP_X, FRONT_Y + 10.0)


func _pour(delta: float) -> void:
	if phase != Phase.POURING:
		return
	var t: float = _phase_clock
	if t < POUR_RAISE_SEC:
		samuel.horn_tilt = lerpf(0.0, 0.3, t / POUR_RAISE_SEC)
		return
	var k: float = clampf((t - POUR_RAISE_SEC) / POUR_SEC, 0.0, 1.0)
	samuel.horn_tilt = lerpf(0.3, 1.1, minf(k * 3.0, 1.0))
	oil_amount = minf(k * 3.0, 1.0)
	_oil.visible = true
	var tip: Vector2 = samuel.position + samuel.horn_tip()
	var head: Vector2 = david.position + david.head_top()
	(_oil as _OilStream).set_points(tip, head, oil_amount)
	# Sparkles keep coming while the oil falls and a little after.
	if t < POUR_RAISE_SEC + POUR_SEC + 1.2 and int(t * 12.0) != int((t - delta) * 12.0):
		sparkles.burst(head + Vector2(0, -20), 90.0, 3)
	if t >= POUR_RAISE_SEC + POUR_SEC + 1.2:
		_enter(Phase.DONE)
		_oil.visible = false


## Gold light: a warm tint over the whole screen with soft rings of light around the middle.
class _Glow extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color(1.0, 0.86, 0.4, 0.3))
		for i in 8:
			var r: float = 1000.0 - float(i) * 115.0
			draw_circle(Vector2(960, 440), r, Color(1.0, 0.92, 0.55, 0.07))


## A stream of oil from the horn tip down to David's head, with a bright cap on his hair.
class _OilStream extends Node2D:
	var _from: Vector2 = Vector2.ZERO
	var _to: Vector2 = Vector2.ZERO
	var _amount: float = 0.0

	func set_points(from: Vector2, to: Vector2, amount: float) -> void:
		_from = from
		_to = to
		_amount = amount
		queue_redraw()

	func _draw() -> void:
		var end: Vector2 = _from.lerp(_to, _amount)
		draw_line(_from, end, Color(0.95, 0.78, 0.25), 9.0)
		draw_line(_from, end, Color(1.0, 0.95, 0.6, 0.7), 3.0)
		if _amount >= 1.0:
			draw_circle(_to + Vector2(0, 2), 26.0, Color(1.0, 0.85, 0.3, 0.8))
