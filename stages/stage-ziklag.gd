class_name StageZiklag
extends StagePlayBase
## Stage type `boss`, variant `rescue` (3.9, Ziklag). The raiders' camp is spread over a wide field.
## Families are tied: stand next to one and press OK to free it. `obstacles` (kind ropes, count n) puts
## a rope on n of the families, spread evenly. With Goliath's Sword (`clears_obstacle(ropes)`) OK
## cuts the rope of the nearest roped family within `ropeRangePx`, from range; the Sword is a
## shortcut and the other families (and every family without the Sword) are freed by standing next
## to them.
## Otherwise OK throws a stone at the nearest raider. Raiders chase David; a stone sends one running
## off (no gore) and he comes back after `raiderStunSec` (`raiderReturnSec` overrides; 0 = he stays
## away). Every freed family follows David for the rest of the stage as a helper (`helperPerFamily`
## followers, at `helperSpeed`): it keeps a ring
## around him (scaled by `follow-distance`) and throws stones at raiders in `helperRangePx`.
## The Mighty Men companion comes from StagePlayBase.spawn_companion_if_blessed() when it exists.
## Win: every family freed (always; no mode or Blessing changes it). Normal only: `timeLimitSec` runs
## out -> fail(&"timeout"). Shepherd and Lamb ignore the timer (`timer_enabled()`); Lamb has no raiders
## (`enemies_enabled()`); Shepherd's slower raiders are written in the data (`raiderSpeed`).

const FAMILY_MAX: int = 12
const RAIDER_MAX: int = 10
const HELPER_STONES: int = 4
## Layout and fallback numbers (data params override every one of them).
const DEFAULT_RAIDER_SPEED: float = 150.0
const DEFAULT_ROPE_RANGE: float = 420.0
const DEFAULT_HELPER_THROW_SEC: float = 1.6
const DEFAULT_HELPER_RANGE: float = 500.0
const FOLLOW_BASE: float = 130.0
const FOLLOW_STEP: float = 38.0
const FOLLOW_PER_RING: int = 6
const RAIDER_START_DIST: float = 520.0
const TIED_FREE_PAD: float = 30.0

var families: Array[ActorFamily] = []
## One entry per family; null where the family has no rope.
var ropes: Array[ActorRope] = []
var roped_count: int = 0
var raiders: Array[ActorRaider] = []
var freed: int = 0
var family_total: int = 0
var repelled: int = 0
var followers_added: int = 0
var time_left: float = 0.0

var _helper_per_family: int = 1
var _time_limit: float = 0.0
var _timer_on: bool = false
var _active_elapsed: float = 0.0
var _last_counter: int = -2
var _raider_speed: float = 0.0
var _return_sec: float = 0.0
var _rope_range: float = 0.0
var _helper_speed: float = 0.0
var _helper_throw: float = 0.0
var _helper_range: float = 0.0
var _rescue_radius: float = 0.0
var _flee_speed: float = 0.0
var _margin: float = 0.0
var _gated: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	families.clear()
	ropes.clear()
	raiders.clear()
	roped_count = 0
	freed = 0
	repelled = 0
	followers_added = 0
	_active_elapsed = 0.0
	_last_counter = -2
	_gated = false
	_helper_per_family = maxi(0, def.param_int("helperPerFamily", 1))
	_time_limit = def.param_float("timeLimitSec", 0.0)
	_timer_on = timer_enabled() and _time_limit > 0.0
	time_left = _time_limit
	_raider_speed = def.param_float("raiderSpeed", DEFAULT_RAIDER_SPEED)
	_return_sec = def.param_float("raiderReturnSec", def.param_float("raiderStunSec", 0.0))
	_helper_speed = def.param_float("helperSpeed", walk_speed() * 0.9)
	_rope_range = def.param_float("ropeRangePx", DEFAULT_ROPE_RANGE)
	_helper_throw = def.param_float("helperThrowSec", DEFAULT_HELPER_THROW_SEC)
	_helper_range = def.param_float("helperRangePx", DEFAULT_HELPER_RANGE)
	_rescue_radius = BalanceData.feel("sheepRescueRadius")
	_flee_speed = BalanceData.feel("bossFleeSpeed")
	_margin = BalanceData.feel("bossOffscreenMargin")
	backdrop.color = Color(0.36, 0.3, 0.22)
	david.position = Vector2(FIELD.position.x + 140.0, FIELD.get_center().y)
	# Helpers throw with their own pooled stones (the pool is fixed; nothing is created later).
	for i in HELPER_STONES:
		var st: ActorStone = STONE_SCENE.instantiate() as ActorStone
		st.visible = false
		world.add_child(st)
		_stones.append(st)
	_build_families()
	_build_raiders()
	world.move_child(david, -1)


func _build_families() -> void:
	family_total = clampi(def.param_int("families", 0), 0, FAMILY_MAX)
	if family_total == 0:
		return
	var cols: int = ceili(sqrt(float(family_total) * FIELD.size.x / FIELD.size.y))
	var rows: int = ceili(float(family_total) / float(cols))
	var area: Rect2 = FIELD.grow(-170.0)
	var cell: Vector2 = Vector2(area.size.x / float(cols), area.size.y / float(rows))
	var rope_n: int = mini(_obstacle_count(&"ropes"), family_total)
	for i in family_total:
		var c: int = i % cols
		var r: int = floori(float(i) / float(cols))
		var f: ActorFamily = ActorFamily.new()
		var jitter: Vector2 = Vector2(_rng.randf_range(-0.2, 0.2) * cell.x, _rng.randf_range(-0.2, 0.2) * cell.y)
		f.position = area.position + Vector2((float(c) + 0.5) * cell.x, (float(r) + 0.5) * cell.y) + jitter
		# Keep the first family from sitting on David's starting spot.
		if f.position.distance_to(david.position) < 2.0 * _rescue_radius:
			f.position.x += 2.0 * _rescue_radius
		world.add_child(f)
		families.append(f)
		var rope: ActorRope = null
		# Ropes go on evenly spread families.
		if floori(float(i + 1) * float(rope_n) / float(family_total)) > floori(float(i) * float(rope_n) / float(family_total)):
			rope = ActorRope.new()
			rope.position = f.position
			world.add_child(rope)
			roped_count += 1
		ropes.append(rope)


## Number of obstacles of a kind in `obstacles` (`[{kind, count}]` or `{kind: n}`).
func _obstacle_count(obstacle_kind: StringName) -> int:
	var v: Variant = def.param("obstacles", null)
	var n: int = 0
	if v is Array:
		for e in (v as Array):
			if e is Dictionary and str((e as Dictionary).get("kind", "")) == String(obstacle_kind):
				n += int((e as Dictionary).get("count", 1))
	elif v is Dictionary:
		var c: Variant = (v as Dictionary).get(String(obstacle_kind), 0)
		n = int((c as Dictionary).get("count", 0)) if c is Dictionary else int(c)
	return n


func _build_raiders() -> void:
	if not enemies_enabled():
		return
	var n: int = clampi(def.param_int("raiders", 0), 0, RAIDER_MAX)
	for i in n:
		var r: ActorRaider = ActorRaider.new()
		r.position = _random_field_point_away(david.position, RAIDER_START_DIST)
		world.add_child(r)
		raiders.append(r)


func _on_begin() -> void:
	_gated = wait_for_lines
	report_counter(&"time", int(ceilf(_time_limit)) if _timer_on else -1)
	if has_method(&"spawn_companion_if_blessed"):
		call(&"spawn_companion_if_blessed")
	_apply_visuals(play_event(&"enter"))


## The host line queue showed the entry lines: the timer and the raiders start now.
func on_lines_drained() -> void:
	_gated = false


func _step(delta: float) -> void:
	_followers_step(delta)
	if not _gated:
		_raiders_step(delta)
		_timer_step(delta)
	if _finished:
		return
	if freed >= family_total:
		_finish()


func _finish() -> void:
	var rest: Array = play_event(&"win")
	for b in rest:
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "end-card":
			var l: Dictionary = LineBook.line(StringName(str((b as Dictionary).get("line", ""))))
			if not l.is_empty():
				emit_story_line(l)
	_apply_visuals(rest)
	win()


func _timer_step(delta: float) -> void:
	if not _timer_on:
		return
	_active_elapsed += delta
	time_left = maxf(0.0, _time_limit - _active_elapsed)
	var shown: int = int(ceilf(time_left))
	if shown != _last_counter:
		_last_counter = shown
		report_counter(&"time", shown)
	if time_left <= 0.0:
		fail(&"timeout")


# --- Families and helpers ---

func _nearest_tied(limit: float, roped_only: bool = false) -> int:
	var best: int = -1
	var best_d: float = limit
	for i in families.size():
		var f: ActorFamily = families[i]
		if f.freed or (roped_only and ropes[i] == null):
			continue
		var d: float = f.position.distance_to(david.position)
		if d <= best_d:
			best_d = d
			best = i
	return best


func on_action_tap() -> void:
	if _finished:
		return
	var idx: int = _nearest_tied(_rescue_radius + david.radius + TIED_FREE_PAD)
	if idx < 0 and clears_obstacle(&"ropes"):
		idx = _nearest_tied(_rope_range, true)
	if idx >= 0:
		free_family(idx)
		return
	if lamb_harp_mode():
		play_harp_tap()
		return
	super()


## Frees family `idx`: the rope goes, the family joins David as a helper. Public for tests.
func free_family(idx: int) -> void:
	var f: ActorFamily = families[idx]
	if f.freed:
		return
	f.freed = true
	f.ring_index = freed
	f.ring_angle = float(freed) * 2.399963
	f.throw_left = _helper_throw
	if ropes[idx] != null:
		ropes[idx].visible = false
	freed += 1
	request_sfx(&"pickup")
	if _helper_per_family > 0:
		followers_added += _helper_per_family
		add_followers(_helper_per_family)
	if freed >= family_total and not _finished:
		_finish()


func _followers_step(delta: float) -> void:
	if freed == 0:
		return
	var follow: float = get_modifier(&"follow-distance", 1.0)
	var speed: float = _helper_speed
	var throw_speed: float = get_modifier(&"stone-speed", _stone_speed_base)
	var can_throw: bool = enemies_enabled() and not _gated and _helper_per_family > 0
	for f in families:
		if not f.freed:
			continue
		var ring: float = (FOLLOW_BASE + FOLLOW_STEP * float(floori(float(f.ring_index) / float(FOLLOW_PER_RING)))) * follow
		var spot: Vector2 = david.position + Vector2.from_angle(f.ring_angle) * ring
		var to: Vector2 = spot - f.position
		var step: float = speed * delta
		if to.length_squared() <= step * step:
			f.position = spot
		else:
			f.position += to.normalized() * step
		f.throw_left = maxf(0.0, f.throw_left - delta)
		if can_throw and f.throw_left <= 0.0:
			var target: ActorRaider = _nearest_raider(f.position, _helper_range)
			if target != null:
				var st: ActorStone = _free_stone()
				if st != null:
					st.launch(f.position, target, (target.position - f.position).normalized(), throw_speed)
					f.throw_left = _helper_throw


# --- Raiders ---

func _nearest_raider(from: Vector2, limit: float) -> ActorRaider:
	var best: ActorRaider = null
	var best_d: float = limit
	for r in raiders:
		if not r.is_hostile() or not r.visible:
			continue
		var d: float = r.position.distance_to(from)
		if d <= best_d:
			best_d = d
			best = r
	return best


func _pick_target() -> Node2D:
	return _nearest_raider(david.position, INF)


func _raiders_step(delta: float) -> void:
	for r in raiders:
		match r.state:
			ActorRaider.State.CHASE:
				var to: Vector2 = david.position - r.position
				r.position += to.normalized() * _raider_speed * delta
				if to.length() <= r.radius + david.radius:
					_contact_hit(1)
			ActorRaider.State.AFRAID:
				r.position += (r.position - david.position).normalized() * _flee_speed * delta
				r.position = r.position.clamp(FIELD.position, FIELD.end)
				r.timer -= delta
				if r.timer <= 0.0:
					r.state = ActorRaider.State.CHASE
					r.modulate = Color.WHITE
			ActorRaider.State.AWAY:
				r.position += r.away * _flee_speed * delta
				if not FIELD.grow(_margin).has_point(r.position):
					r.state = ActorRaider.State.GONE
					r.visible = false
					r.timer = _return_sec
			ActorRaider.State.GONE:
				if _return_sec > 0.0:
					r.timer -= delta
					if r.timer <= 0.0:
						_return_raider(r)


func _return_raider(r: ActorRaider) -> void:
	r.position = _random_edge_point()
	r.state = ActorRaider.State.CHASE
	r.visible = true


func _on_stone_hit(target: Node2D) -> void:
	var r: ActorRaider = target as ActorRaider
	if r == null or not r.is_hostile():
		return
	request_sfx(&"stone-hit")
	repel(r)


## Sends a raider running away (no damage shown). Public for tests.
func repel(r: ActorRaider) -> void:
	r.state = ActorRaider.State.AWAY
	var dir: Vector2 = r.position - david.position
	r.away = dir.normalized() if dir.length_squared() > 1.0 else Vector2.RIGHT
	repelled += 1


## Song of Courage: raiders near David run away for `sec` seconds, then chase again.
func _frighten(radius: float, sec: float) -> void:
	for r in raiders:
		if r.is_hostile() and r.position.distance_to(david.position) <= radius:
			r.state = ActorRaider.State.AFRAID
			r.timer = sec
			r.modulate = Color(0.75, 0.8, 1.0, 0.75)


## Raiders still on the field and a danger to David.
func raiders_hostile() -> int:
	var n: int = 0
	for r in raiders:
		if r.is_hostile():
			n += 1
	return n
