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

enum Kind { COLLECT, ROBE, CAMP }

const SLEEPER_MAX: int = 10
const THORN_MAX: int = 4
const PILLAR_MAX: int = 6
## Layout and fallback numbers for the Chapter 3 modes (data params override every one of them).
const ROBE_PILLAR_SIZE: Vector2 = Vector2(110, 170)
const ROBE_SAUL_FROM_RIGHT: float = 300.0
const DEFAULT_CONE_RANGE: float = 560.0
const DEFAULT_CONE_HALF_DEG: float = 35.0
const DEFAULT_REACH: float = 120.0
const DEFAULT_PATH_WIDTH: float = 200.0
const DEFAULT_WAKE_RADIUS: float = 130.0
const DEFAULT_CLEAR_REACH: float = 70.0
const DEFAULT_HINT_SEC: float = 8.0
const HINT_REACHED: float = 100.0
const HINT_DISTANCE: float = 110.0
## The dark path as fractions of the field; the first point is the start, the last is the far hill.
const PATH_FRACTIONS: Array[Vector2] = [Vector2(0.06, 0.86), Vector2(0.32, 0.86), Vector2(0.32, 0.5), Vector2(0.62, 0.5), Vector2(0.62, 0.2), Vector2(0.9, 0.2)]
## Where along the path (0..1) the thorn patches lie (kept away from the sleepers).
const THORN_AT: Array[float] = [0.12, 0.88, 0.3, 0.7]
const SAUL_AT: float = 0.5
const HILL_SIZE: Vector2 = Vector2(240, 240)

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

var kind: Kind = Kind.COLLECT
var notice_sec: float = 0.0
## ROBE: Saul, the pillars that block his sight (`rocks`), the reach and whether the robe was cut.
var saul: ActorSaul = null
var robe_cut: bool = false
## CAMP: sleepers, the items beside Saul, thorn patches, the far hill and the running counts.
var sleepers: Array[ActorSleeper] = []
var items: Array[ActorSleeperItem] = []
var thorns: Array[ActorThorn] = []
var goal_rect: Rect2 = Rect2()
var items_taken: int = 0
var items_required: int = 0
var sleepers_woken: int = 0
var thorns_cleared: int = 0
var path_points: PackedVector2Array = PackedVector2Array()
var path_half: float = 0.0
## Faithful Friend hint arrow: uses this stage and seconds left.
var hint_uses: int = 0
var hint_left: float = 0.0
var hint_arrow: Polygon2D = null

var _start: Vector2 = Vector2.ZERO
var _pickup_radius: float = 0.0
var _hide_reach: float = 0.0
var _hide_half_width: float = 0.0
var _cone_range: float = 0.0
var _cone_cos: float = 0.0
var _reach: float = DEFAULT_REACH
var _wake_px: float = 0.0
var _clear_reach: float = DEFAULT_CLEAR_REACH
var _hint_budget: int = 0
var _hint_sec: float = 0.0
var _hint_gate: bool = false
var _hint_index: int = 1
var _hint_points: PackedVector2Array = PackedVector2Array()
var _spared_done: bool = false
var _sight_on: bool = true
var _wakes: bool = true
var _near_saul_done: bool = false
var _food: int = 0


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
	sleepers.clear()
	items.clear()
	thorns.clear()
	saul = null
	hint_arrow = null
	robe_cut = false
	items_taken = 0
	items_required = 0
	sleepers_woken = 0
	thorns_cleared = 0
	hint_uses = 0
	hint_left = 0.0
	_hint_gate = false
	_hint_index = 1
	_spared_done = false
	_near_saul_done = false
	_food = 0
	notice_sec = def.param_float("noticeSec", sight_sec)
	kind = _detect_kind()
	if kind != Kind.COLLECT:
		_hint_budget = maxi(0, int(get_feature(&"arrowHintPerStage", 0)))
		_hint_sec = def.param_float("hintSec", DEFAULT_HINT_SEC)
		if kind == Kind.ROBE:
			_setup_robe()
		else:
			_setup_camp()
		_build_hint_arrow()
		return
	_start = Vector2(FIELD.position.x, FIELD.end.y) + START_OFFSET
	exit_rect = Rect2(FIELD.end.x - EXIT_SIZE.x, FIELD.end.y - EXIT_SIZE.y, EXIT_SIZE.x, EXIT_SIZE.y)
	david.position = _start
	_build_scenery()
	_build_scouts()
	_build_rocks()
	_build_stones()


func _detect_kind() -> Kind:
	if def.param_dict("actions").get("ok", "") == "cut-corner-of-robe":
		return Kind.ROBE
	if not _pickup_names().is_empty():
		return Kind.CAMP
	return Kind.COLLECT


## The camp items: `pickups` as a list, or `pickups.items`. The brook's `pickups {kind: stones}` has none.
func _pickup_names() -> Array:
	var v: Variant = def.param("pickups", null)
	if v is Array:
		return v as Array
	if v is Dictionary and (v as Dictionary).get("items") is Array:
		return (v as Dictionary)["items"] as Array
	return []


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
	if kind != Kind.COLLECT:
		_hint_step(delta)
		if kind == Kind.ROBE:
			_robe_step(delta)
		else:
			_camp_step(delta)
		return
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


# --- Chapter 3: shared ---

func _on_begin() -> void:
	if kind == Kind.COLLECT:
		return
	_hint_gate = not wait_for_lines
	if kind == Kind.CAMP:
		_eat_food()
	_apply_visuals(play_event(&"enter"))


func on_lines_drained() -> void:
	_hint_gate = true


## Food for this stage (the scripted grant from 3.7 plus Gift of Abigail) restores hearts David
## is missing. Assumption recorded in data-schema 10: food restores hearts.
func _eat_food() -> void:
	_food = take_food_bonus()
	if run == null or _food <= 0:
		return
	var eaten: int = mini(_food, maxi(0, run.hearts_max - run.hearts))
	if eaten > 0:
		_food -= eaten
		report_heal(eaten)


func on_action_tap() -> void:
	if _finished:
		return
	match kind:
		Kind.ROBE:
			_try_cut_robe()
		Kind.CAMP:
			_try_clear_thorn()
		_:
			super()


## Stealth stages have no stone and no attack: OK is the stage's one action (or nothing).
func _pick_target() -> Node2D:
	return null


## A count given as a number or as `{count: n}`.
func _count_param(path: String) -> int:
	var v: Variant = def.param(path, 0)
	if v is Dictionary:
		return int((v as Dictionary).get("count", 0))
	return int(v)


## Liang-Barsky: does the segment a-b touch the rectangle?
static func segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var t0: float = 0.0
	var t1: float = 1.0
	var d: Vector2 = b - a
	var lo: Vector2 = r.position
	var hi: Vector2 = r.end
	for axis in 2:
		var da: float = d[axis]
		var pa: float = a[axis]
		if absf(da) < 0.00001:
			if pa < lo[axis] or pa > hi[axis]:
				return false
			continue
		var ta: float = (lo[axis] - pa) / da
		var tb: float = (hi[axis] - pa) / da
		if ta > tb:
			var tmp: float = ta
			ta = tb
			tb = tmp
		t0 = maxf(t0, ta)
		t1 = minf(t1, tb)
		if t0 > t1:
			return false
	return true


func _notice_threshold() -> float:
	return get_modifier(&"notice-time", notice_sec)


func _build_hint_arrow() -> void:
	hint_arrow = Polygon2D.new()
	hint_arrow.polygon = PackedVector2Array([Vector2(-16, -20), Vector2(26, 0), Vector2(-16, 20)])
	hint_arrow.color = Color(1.0, 0.95, 0.6, 0.5)
	hint_arrow.visible = false
	world.add_child(hint_arrow)


## Faithful Friend: shows the arrow once per stage, after the entry lines, for `hintSec`.
func _hint_step(delta: float) -> void:
	if hint_arrow == null or _hint_points.size() < 2:
		return
	if _hint_gate and hint_uses == 0 and hint_uses < _hint_budget:
		hint_uses = 1
		hint_left = _hint_sec
		_hint_index = 1
	if hint_left <= 0.0:
		hint_arrow.visible = false
		return
	hint_left = maxf(0.0, hint_left - delta)
	while _hint_index < _hint_points.size() - 1 and david.position.distance_to(_hint_points[_hint_index]) < HINT_REACHED:
		_hint_index += 1
	var to: Vector2 = _hint_points[_hint_index] - david.position
	if to.length_squared() < 1.0:
		to = Vector2.RIGHT
	hint_arrow.rotation = to.angle()
	hint_arrow.position = david.position + to.normalized() * HINT_DISTANCE
	hint_arrow.visible = hint_left > 0.0


## True while the Faithful Friend arrow is on screen.
func hint_visible() -> bool:
	return hint_arrow != null and hint_arrow.visible


# --- Chapter 3: En-gedi (3.6) ---

func _setup_robe() -> void:
	backdrop.color = Color(0.1, 0.09, 0.12)
	var c: Vector2 = FIELD.get_center()
	StageUtil.make_rect(world, FIELD.grow(-24.0), Color(0.19, 0.16, 0.17))
	_start = Vector2(FIELD.position.x + 120.0, c.y)
	david.position = _start
	_sight_on = def.param_bool("sightEnabled", true)
	_cone_range = def.param_float("saulSightRangePx", def.param_float("sightRangePx", DEFAULT_CONE_RANGE))
	var half: float = deg_to_rad(def.param_float("sightConeDeg", DEFAULT_CONE_HALF_DEG))
	_cone_cos = cos(half)
	_reach = def.param_float("reachPx", DEFAULT_REACH)
	var spos: Vector2 = Vector2(FIELD.end.x - ROBE_SAUL_FROM_RIGHT, c.y)
	# David's men hide deep inside the cave, behind Saul.
	for i in 3:
		StageUtil.make_rect(world, Rect2(Vector2(FIELD.end.x - 150.0 + float(i) * 40.0, FIELD.position.y + 70.0 + float(i % 2) * 40.0), Vector2(30, 56)), Color(0.12, 0.12, 0.2))
	var n: int = mini(def.param_int("hidingSpots.count", 0), PILLAR_MAX)
	for i in n:
		var x: float = lerpf(_start.x + 380.0, spos.x - 220.0, (float(i) + 0.5) / float(maxi(n, 1)))
		var y: float = c.y + (-140.0 if i % 2 == 0 else 140.0)
		rocks.append(StageUtil.make_rect(world, Rect2(Vector2(x, y) - ROBE_PILLAR_SIZE * 0.5, ROBE_PILLAR_SIZE), Color(0.3, 0.28, 0.3)))
	saul = ActorSaul.new()
	saul.position = spos
	saul.configure(_cone_range if (enemies_enabled() and _sight_on) else 0.0, half, Vector2.LEFT)
	world.add_child(saul)
	world.move_child(david, -1)
	# The safe route: along the cave wall, then up to Saul from behind.
	_hint_points = PackedVector2Array([_start, Vector2(_start.x + 380.0, FIELD.position.y + 110.0), Vector2(spos.x + 260.0, FIELD.position.y + 110.0), spos + Vector2(_reach * 0.6, -40.0)])


func _robe_step(delta: float) -> void:
	var seen: bool = false
	if enemies_enabled() and _sight_on and _hit_cd <= 0.0:
		seen = saul_sees()
	saul.alert = seen
	if seen:
		seen_time += delta
		if seen_time >= _notice_threshold():
			saul.alert = false
			_pushed_back()
	else:
		seen_time = maxf(seen_time - delta, 0.0)


## True when Saul's cone reaches David and no pillar is between them.
func saul_sees() -> bool:
	var d: Vector2 = david.position - saul.position
	var dist2: float = d.length_squared()
	if dist2 > _cone_range * _cone_range:
		return false
	if dist2 > 1.0 and d.dot(saul.facing) < sqrt(dist2) * _cone_cos:
		return false
	for r in rocks:
		if segment_hits_rect(saul.position, david.position, Rect2(r.position, r.size)):
			return false
	return true


func _try_cut_robe() -> void:
	if robe_cut or saul.position.distance_to(david.position) > _reach:
		return
	robe_cut = true
	saul.robe_cut = true
	request_sfx(&"pickup")
	# Saul is spared in every mode with every Blessing; Mercy turns this into a heart (host).
	report_spared()
	_apply_visuals(play_event(&"spare"))
	_apply_visuals(play_event(&"win"))
	win()


# --- Chapter 3: Saul's camp (3.8) ---

func _setup_camp() -> void:
	backdrop.color = Color(0.16, 0.19, 0.17)
	path_half = def.param_float("darkPath.widthPx", DEFAULT_PATH_WIDTH) * 0.5
	_wake_px = def.param_float("wakeRadiusPx", DEFAULT_WAKE_RADIUS)
	_wakes = def.param_bool("sleepers.wakes", true)
	_clear_reach = def.param_float("clearReachPx", DEFAULT_CLEAR_REACH)
	path_points = PackedVector2Array()
	for f in PATH_FRACTIONS:
		path_points.append(FIELD.position + FIELD.size * f)
	_start = path_points[0]
	david.position = _start
	_hint_points = path_points
	var line: Line2D = Line2D.new()
	line.points = path_points
	line.width = path_half * 2.0
	line.default_color = Color(0.06, 0.06, 0.08)
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	world.add_child(line)
	goal_rect = Rect2(path_points[path_points.size() - 1] - HILL_SIZE * 0.5, HILL_SIZE)
	StageUtil.make_rect(world, goal_rect, Color(0.5, 0.45, 0.3, 0.55))
	var total: float = _path_length()
	var saul_pos: Vector2 = _off_path_point(total * SAUL_AT, 1.0, _wake_px + 10.0)
	saul = ActorSaul.new()
	saul.asleep = true
	saul.position = saul_pos
	world.add_child(saul)
	# The spear and the water jug lie on the path, one on each side of where Saul sleeps.
	var names: Array = _pickup_names()
	var need: Variant = def.win.get("requireItems", null)
	items_required = 0
	if need is Array:
		items_required = mini((need as Array).size(), names.size())
	elif need != null:
		items_required = mini(names.size(), 2)
	for i in mini(names.size(), 2):
		var it: ActorSleeperItem = ActorSleeperItem.new()
		it.kind = StringName(str(names[i]))
		it.position = _path_point_at(total * SAUL_AT + (-70.0 if i == 0 else 70.0))
		world.add_child(it)
		items.append(it)
	var sn: int = mini(_count_param("sleepers"), SLEEPER_MAX)
	for i in sn:
		var frac: float = lerpf(0.36, 0.64, (float(i) + 0.5) / float(maxi(sn, 1)))
		if absf(frac - SAUL_AT) < 0.03:
			frac += 0.04
		var sl: ActorSleeper = ActorSleeper.new()
		sl.wake_px = _wake_px if (enemies_enabled() and _wakes) else 0.0
		sl.position = _off_path_point(total * frac, 1.0 if i % 2 == 0 else -1.0, _wake_px + 10.0)
		world.add_child(sl)
		sleepers.append(sl)
	_build_thorns(total)
	world.move_child(david, -1)


## Thorn patches from `obstacles`: a list of `{kind: thorns, count: n}` or `{thorns: n}`.
func _build_thorns(total: float) -> void:
	var n: int = 0
	var obstacles: Variant = def.param("obstacles", null)
	if obstacles is Dictionary:
		n = _kind_count(obstacles as Dictionary, "thorns")
	elif obstacles is Array:
		for e in (obstacles as Array):
			if e is Dictionary and str((e as Dictionary).get("kind", "")) == "thorns":
				n += int((e as Dictionary).get("count", 1))
	n = mini(n, THORN_MAX)
	for i in n:
		var th: ActorThorn = ActorThorn.new()
		# A patch fills half the path's width, so there is always room to walk around it.
		th.radius = path_half * 0.5
		th.position = _path_point_at(total * THORN_AT[i])
		world.add_child(th)
		thorns.append(th)


static func _kind_count(d: Dictionary, key: String) -> int:
	var v: Variant = d.get(key, 0)
	if v is Dictionary:
		return int((v as Dictionary).get("count", 0))
	return int(v)


func _path_length() -> float:
	var total: float = 0.0
	for i in path_points.size() - 1:
		total += path_points[i].distance_to(path_points[i + 1])
	return total


func _path_point_at(dist: float) -> Vector2:
	var left: float = maxf(dist, 0.0)
	for i in path_points.size() - 1:
		var seg: float = path_points[i].distance_to(path_points[i + 1])
		if left <= seg:
			return path_points[i].lerp(path_points[i + 1], left / maxf(seg, 0.001))
		left -= seg
	return path_points[path_points.size() - 1]


## Distance from `p` to the path's centre line.
func path_distance(p: Vector2) -> float:
	var best: float = INF
	for i in path_points.size() - 1:
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[i + 1])
		best = minf(best, p.distance_to(q))
	return best


## A point beside the path at arc length `dist`, `min_dist` or more from the centre line. `side` is
## +1 or -1; the other side is tried when this one runs into another stretch of the path.
func _off_path_point(dist: float, side: float, min_dist: float) -> Vector2:
	var a: Vector2 = _path_point_at(dist - 5.0)
	var b: Vector2 = _path_point_at(dist + 5.0)
	var centre: Vector2 = _path_point_at(dist)
	var normal: Vector2 = (b - a).normalized().orthogonal()
	var offset: float = maxf(path_half + 0.5 * _wake_px, min_dist)
	var best: Vector2 = centre + normal * side * offset
	var best_d: float = path_distance(best)
	for k in 4:
		var sgn: float = side if k % 2 == 0 else -side
		var p: Vector2 = (centre + normal * sgn * (offset + 40.0 * float(k >> 1))).clamp(FIELD.position + Vector2(40, 40), FIELD.end - Vector2(40, 40))
		var d: float = path_distance(p)
		if d >= min_dist:
			return p
		if d > best_d:
			best = p
			best_d = d
	return best


func _camp_step(delta: float) -> void:
	var near_sleeper: bool = false
	var off_path: bool = false
	if enemies_enabled() and _hit_cd <= 0.0:
		for sl in sleepers:
			var near: bool = _wakes and sl.position.distance_to(david.position) <= _wake_px
			sl.stir = near
			near_sleeper = near_sleeper or near
		off_path = path_distance(david.position) > path_half
	else:
		for sl in sleepers:
			sl.stir = false
	if near_sleeper or off_path:
		seen_time += delta
		if seen_time >= _notice_threshold():
			if near_sleeper:
				sleepers_woken += 1
			for sl in sleepers:
				sl.stir = false
			_pushed_back()
	else:
		seen_time = maxf(seen_time - delta, 0.0)
	_take_items()
	if not _near_saul_done and saul.position.distance_to(david.position) <= _wake_px * 2.0:
		_near_saul_done = true
		_apply_visuals(play_event(&"reach-saul"))
	if goal_rect.grow(2.0).has_point(david.position) and items_taken >= items_required:
		_apply_visuals(play_event(&"win"))
		win()


func _take_items() -> void:
	for it in items:
		if it.taken or it.position.distance_to(david.position) > _pickup_radius:
			continue
		it.taken = true
		it.visible = false
		items_taken += 1
		request_sfx(&"pickup")
		if items_taken >= items.size():
			_apply_visuals(play_event(&"pickups-complete"))
			# Both items taken and nobody woke: Saul and his men were spared.
			if sleepers_woken == 0 and not _spared_done:
				_spared_done = true
				report_spared()
				_apply_visuals(play_event(&"spare"))


func _blocked(p: Vector2) -> bool:
	for th in thorns:
		if not th.cleared and th.position.distance_to(p) < th.radius + david.radius * 0.5:
			return true
	return false


## Thorn patches block David (CAMP only; the other modes walk as in StagePlayBase).
func _move_david(delta: float) -> void:
	if kind != Kind.CAMP or thorns.is_empty():
		super(delta)
		return
	if input_dir.length_squared() < 0.0001:
		return
	var dir: Vector2 = input_dir.limit_length(1.0)
	var from: Vector2 = david.position
	var to: Vector2 = (from + dir * walk_speed() * delta).clamp(FIELD.position, FIELD.end)
	if not _blocked(to):
		david.position = to
	else:
		var slide_x: Vector2 = Vector2(to.x, from.y)
		var slide_y: Vector2 = Vector2(from.x, to.y)
		if slide_x != from and not _blocked(slide_x):
			david.position = slide_x
		elif slide_y != from and not _blocked(slide_y):
			david.position = slide_y
	david.set_facing(dir)


## Goliath's Sword: OK clears the adjacent thorn patch. Without the Sword OK does nothing here.
func _try_clear_thorn() -> void:
	if not clears_obstacle(&"thorns"):
		return
	var best: ActorThorn = null
	var best_d: float = INF
	for th in thorns:
		if th.cleared:
			continue
		var d: float = th.position.distance_to(david.position)
		if d <= th.radius + david.radius + _clear_reach and d < best_d:
			best = th
			best_d = d
	if best == null:
		return
	best.cleared = true
	best.visible = false
	thorns_cleared += 1
	request_sfx(&"thud")
