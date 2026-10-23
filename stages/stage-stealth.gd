class_name StageStealth
extends StagePlayBase
## Stage type `stealth`. Implemented for 2.5, the brook (collect variant): glowing stones lie in the
## stream, Philistine scouts walk the far bank. A scout sees David when he is within its sight
## range and not hidden behind a rock; after `sightSec` of being seen David is pushed back to the
## near bank (never a failure, no stone is lost). Each stone picked up is reported (the host adds
## it to RunModel.stones). The exit is always reachable, so a careless player can leave with fewer
## than the full count. Lamb removes the scouts. The `onSeen` values `reset-position` and
## `return-to-path-start` are handled the same way for stages 3.6 and 3.8 later.

const SCOUT_MAX: int = 6
const ROCK_MAX: int = 8
const STONE_MAX: int = 8
const SCOUT_Y: float = 190.0
const STREAM: Rect2 = Rect2(96, 300, 1728, 420)
const FAR_BANK: Rect2 = Rect2(96, 54, 1728, 246)
const ROCK_SIZE: Vector2 = Vector2(120, 70)
const START_OFFSET: Vector2 = Vector2(120, -140)
const EXIT_SIZE: Vector2 = Vector2(180, 240)
## Fractions of the sight range at which stones lie, so some stones are inside a scout's view.
const STONE_DEPTH: Array[float] = [0.5, 0.85, 1.15, 0.65, 1.0, 0.75, 1.3, 0.55]

var collected: int = 0
var stone_total: int = 0
var seen_time: float = 0.0
var pushbacks: int = 0
var sight_sec: float = 0.0
var sight_px: float = 0.0
var on_seen: String = "pushback"
var scouts: Array[ActorScout] = []
var rocks: Array[ColorRect] = []
var pickups: Array[ActorGlowStone] = []
var exit_rect: Rect2 = Rect2()

var _start: Vector2 = Vector2.ZERO
var _pickup_radius: float = 0.0
var _hide_reach: float = 0.0
var _hide_half_width: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	collected = 0
	seen_time = 0.0
	pushbacks = 0
	sight_sec = def.param_float("sightSec", 1.0)
	on_seen = def.param_string("onSeen", "pushback")
	_pickup_radius = BalanceData.feel("stonePickupRadius")
	_hide_reach = BalanceData.feel("hideReach")
	_hide_half_width = BalanceData.feel("hideHalfWidth")
	scouts.clear()
	rocks.clear()
	pickups.clear()
	_start = Vector2(FIELD.position.x, FIELD.end.y) + START_OFFSET
	exit_rect = Rect2(FIELD.end.x - EXIT_SIZE.x, FIELD.end.y - EXIT_SIZE.y, EXIT_SIZE.x, EXIT_SIZE.y)
	david.position = _start
	_build_scenery()
	_build_scouts()
	_build_rocks()
	_build_stones()


func _build_scenery() -> void:
	backdrop.color = Color(0.3, 0.46, 0.27)
	StageUtil.make_rect(world, FAR_BANK, Color(0.45, 0.4, 0.26))
	StageUtil.make_rect(world, STREAM, Color(0.22, 0.42, 0.62))
	StageUtil.make_rect(world, exit_rect, Color(0.8, 0.7, 0.4, 0.55))
	# The scouts, rocks and stones are added after the terrain so they draw on top of it.


func _build_scouts() -> void:
	if not enemies_enabled():
		return
	var cfg: Dictionary = def.param_dict("scouts")
	var n: int = mini(int(cfg.get("count", 0)), SCOUT_MAX)
	sight_px = float(cfg.get("sightRangePx", 0.0))
	var left: float = FIELD.position.x + 100.0
	var right: float = FIELD.end.x - 100.0
	for i in n:
		var s: ActorScout = ActorScout.new()
		s.configure(sight_px, left, right, float(cfg.get("speed", 0.0)), lerpf(left, right, (float(i) + 0.5) / float(n)), SCOUT_Y)
		s.dir = 1.0 if i % 2 == 0 else -1.0
		world.add_child(s)
		scouts.append(s)


func _build_rocks() -> void:
	var n: int = mini(int(def.param_int("hidingSpots.count", 0)), ROCK_MAX)
	for i in n:
		var x: float = lerpf(STREAM.position.x + 300.0, STREAM.end.x - 300.0, (float(i) + 0.5) / float(maxi(n, 1)))
		var y: float = STREAM.position.y + (110.0 if i % 2 == 0 else 250.0)
		var r: ColorRect = StageUtil.make_rect(world, Rect2(Vector2(x, y) - ROCK_SIZE * 0.5, ROCK_SIZE), Color(0.42, 0.42, 0.46))
		rocks.append(r)


func _build_stones() -> void:
	stone_total = mini(def.param_int("stoneSpots.count", 0), STONE_MAX)
	var depth_base: float = sight_px if sight_px > 0.0 else 380.0
	for i in stone_total:
		var g: ActorGlowStone = ActorGlowStone.new()
		var x: float = lerpf(STREAM.position.x + 200.0, STREAM.end.x - 200.0, (float(i) + 0.5) / float(stone_total))
		# Stones sit in the stream at different distances from the far bank.
		var y: float = clampf(SCOUT_Y + depth_base * STONE_DEPTH[i % STONE_DEPTH.size()], STREAM.position.y + 40.0, STREAM.end.y - 40.0)
		g.position = Vector2(x, y)
		world.add_child(g)
		pickups.append(g)
	# David is drawn last so he is always on top.
	world.move_child(david, -1)


func _step(delta: float) -> void:
	for s in scouts:
		s.advance(delta)
	_collect()
	_sight(delta)
	# Grown a little: David is clamped to the field edge, and Rect2.has_point excludes the far edge.
	if exit_rect.grow(2.0).has_point(david.position):
		_apply_visuals(play_event(&"win"))
		win()


func _collect() -> void:
	for g in pickups:
		if g.collected:
			continue
		if g.position.distance_to(david.position) <= _pickup_radius:
			g.collected = true
			g.visible = false
			collected += 1
			report_stone_collected()
			request_sfx(&"pickup")
			_apply_visuals(play_event(&"each-stone"))
			if collected >= stone_total:
				_apply_visuals(play_event(&"stones-complete"))


## True when David stands just below a rock, out of a scout's view.
func is_hidden() -> bool:
	var p: Vector2 = david.position
	for r in rocks:
		var bottom: float = r.position.y + r.size.y
		if p.y >= r.position.y and p.y <= bottom + _hide_reach \
				and p.x >= r.position.x - _hide_half_width and p.x <= r.position.x + r.size.x + _hide_half_width:
			return true
	return false


func _sight(delta: float) -> void:
	if scouts.is_empty():
		return
	var seen: bool = false
	if _hit_cd <= 0.0 and not is_hidden():
		var limit: float = sight_px * sight_px
		for s in scouts:
			var sees: bool = s.position.distance_squared_to(david.position) <= limit
			s.alert = sees
			seen = seen or sees
	else:
		for s in scouts:
			s.alert = false
	if seen:
		seen_time += delta
		if seen_time >= get_modifier(&"notice-time", sight_sec):
			_pushed_back()
	else:
		seen_time = maxf(seen_time - delta, 0.0)


## David was seen long enough. `pushback` sends him to the near bank where he stands; the other
## `onSeen` values send him to the start. No stone is lost and the stage does not fail.
func _pushed_back() -> void:
	seen_time = 0.0
	pushbacks += 1
	_hit_cd = _invuln_sec
	david.set_flash(true)
	request_sfx(&"bounce")
	if on_seen == "pushback":
		david.position = Vector2(david.position.x, _start.y)
	else:
		david.position = _start
	for s in scouts:
		s.alert = false
