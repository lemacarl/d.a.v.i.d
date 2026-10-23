class_name StageSurvivalCamp
extends StagePlayBase
## Stage type `survival-camp` (3.5, the cave of Adullam). One class for day 1, 2 and 3.
##
## Remote-only play. David walks (D-pad) around the camp:
##  - Gathering: OK next to a man in camp selects him (ring), then D-pad UP sends him to the next free
##    food spot, DOWN to the next free water spot, LEFT or RIGHT (or OK again, or `campSelectWindowSec`
##    of waiting) cancels. He walks there (`menWalkSpeed`), works `campGatherWorkSec`, and carries the
##    food or water home. One food plus one water is a meal (HUD loaf counter).
##  - Welcoming: groups of newcomers walk to the cave mouth `followersPerDay` / `campArrivalsPerDay`
##    each. OK next to a waiting group welcomes them: the data `new-follower` lines play, they join
##    (`follower_added`), and every ready meal feeds `campMealBonusMen` more men. A group nobody greets
##    within `campWelcomeWaitSec` (and every group at the end of the day) still joins, without the
##    bonus. Each join plays the lines and emits `follower_added(n)`.
##  - Patrol (`patrol.enabled`, `intervalSec`, `speed`, `noticeSec`, `scatterFraction`): a patrol walks
##    in from the right along a row, stops at `campPatrolTurnX` to look around, and leaves. It sees
##    anyone within `campPatrolSightPx` who is in the open: David unless he stands within
##    `campShelterRadius` of the cave or by a brush (`hidingSpots.count`), and every man out gathering.
##    Men in camp are always hidden. Seeing builds exposure; `noticeSec` (through the notice-time
##    modifier, Hidden in the Rock) of exposure finds the camp: `scatterFraction` of the men scatter
##    (`follower_added` with a negative count) and the patrol leaves. Exposure drains while nothing is
##    seen. No patrol when `patrol.enabled` is false or enemies are off (Lamb).
## Men are `RunModel.followers`, shown on the HUD; the stage mirrors the number in `men` and reports
## changes through `follower_added`. The day ends at `dayDurationSec`: `win.kind` `count-at-end`
## (day 3) checks `win.min`; below it the stage `fail`s with `men-below-goal-at-end` (Normal restarts
## the day), or tops up to `win.topUpTo` first (Shepherd and Lamb). Events: `enter`, `new-follower`, `win`.
## Food from `take_food_bonus()` (Gift of Abigail, a scripted grant) heals hearts and counts as food.

const NEWCOMER_POOL: int = 4
const SPOT_MAX: int = 6
const BRUSH_MAX: int = 4
const MAN_MAX: int = 4
const CAVE_RECT: Rect2 = Rect2(96, 400, 200, 280)
const CAVE_CENTER: Vector2 = Vector2(200, 540)
const CROWD_CENTER: Vector2 = Vector2(250, 840)
const MOUTH: Vector2 = Vector2(340, 540)
const NEWCOMER_START: Vector2 = Vector2(340, 80)
const HOMES: Array[Vector2] = [Vector2(470, 780), Vector2(580, 840), Vector2(690, 780), Vector2(800, 840)]
const BRUSHES: Array[Vector2] = [Vector2(960, 540), Vector2(1280, 380), Vector2(1180, 740), Vector2(1560, 560)]
const PATROL_LANES: Array[float] = [300.0, 540.0, 780.0]
const FOOD_Y: float = 160.0
const WATER_Y: float = 930.0
const SPOT_X0: float = 780.0
const SPOT_X1: float = 1660.0

var men: int = 0
var food: int = 0
var water: int = 0
var scatters: int = 0
var arrivals_joined: int = 0
var welcomed: int = 0
var day: int = 1
var patrol_phase: ActorCampPatrol.Phase = ActorCampPatrol.Phase.AWAY

var _day_sec: float = 90.0
var _goal_men: int = 0
var _per_day: int = 0
var _arrivals: int = 0
var _next_arrival: int = 0
var _meal_bonus: int = 0
var _gather_on: bool = true
var _patrol_on: bool = false
var _patrol_interval: float = 0.0
var _patrol_speed: float = 0.0
var _patrol_notice: float = 0.0
var _scatter_fraction: float = 0.0
var _patrol_timer: float = 0.0
var _turn_x: float = 0.0
var _sight_px: float = 0.0
var _man_speed: float = 0.0
var _work_sec: float = 0.0
var _select_radius: float = 0.0
var _select_window: float = 0.0
var _select_left: float = 0.0
var _welcome_radius: float = 0.0
var _arrive_sec: float = 0.0
var _welcome_wait: float = 0.0
var _shelter: float = 0.0
var _brush_radius: float = 0.0
var _crowd_radius: float = 0.0
var _crowd_max: int = 0
var _per_figure: int = 1
var _last_time_shown: int = -1
var _last_meals_shown: int = -1
var _shown_figures: int = -1

var _men: Array[ActorCampMan] = []
var _selected: ActorCampMan = null
var _newcomers: Array[ActorCampNewcomers] = []
var _crowd: Array[ActorFollower] = []
var _patrol: ActorCampPatrol = null
var _food_spots: PackedVector2Array = PackedVector2Array()
var _water_spots: PackedVector2Array = PackedVector2Array()
var _food_used: PackedByteArray = PackedByteArray()
var _water_used: PackedByteArray = PackedByteArray()
var _brush: PackedVector2Array = PackedVector2Array()
var _look_left: float = 0.0
var _exposure: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_read_params()
	men = 0
	food = 0
	water = 0
	scatters = 0
	arrivals_joined = 0
	welcomed = 0
	_next_arrival = 0
	_selected = null
	_select_left = 0.0
	_exposure = 0.0
	_look_left = 0.0
	_last_time_shown = -1
	_last_meals_shown = -1
	_shown_figures = -1
	patrol_phase = ActorCampPatrol.Phase.AWAY
	_build_scenery()
	_build_spots()
	_build_men()
	_build_newcomers()
	_build_crowd()
	_build_patrol()
	david.position = Vector2(380, 620)
	david.facing = Vector2.RIGHT


func _read_params() -> void:
	day = def.param_int("day", 1)
	_day_sec = maxf(def.param_float("dayDurationSec", 90.0), 1.0)
	_goal_men = def.param_int("goalMen", 0)
	_per_day = def.param_int("followersPerDay", 0)
	_arrivals = clampi(def.param_int("arrivalsPerDay", int(BalanceData.feel("campArrivalsPerDay"))), 1, NEWCOMER_POOL)
	_meal_bonus = def.param_int("mealBonusMen", int(BalanceData.feel("campMealBonusMen")))
	_gather_on = def.param_bool("foodWaterTasks", true)
	var patrol: Dictionary = def.param_dict("patrol")
	_patrol_interval = float(patrol.get("intervalSec", 0.0))
	_patrol_on = bool(patrol.get("enabled", false)) and _patrol_interval > 0.0 and enemies_enabled()
	_patrol_speed = float(patrol.get("speed", 0.0))
	_patrol_notice = float(patrol.get("noticeSec", 1.0))
	_scatter_fraction = float(patrol.get("scatterFraction", 0.0))
	_patrol_timer = _patrol_interval
	_sight_px = float(patrol.get("sightPx", BalanceData.feel("campPatrolSightPx")))
	_turn_x = float(patrol.get("turnX", BalanceData.feel("campPatrolTurnX")))
	_man_speed = def.param_float("menWalkSpeed", BalanceData.feel("walkSpeed"))
	_work_sec = BalanceData.feel("campGatherWorkSec")
	_select_radius = BalanceData.feel("campSelectRadius")
	_select_window = BalanceData.feel("campSelectWindowSec")
	_welcome_radius = BalanceData.feel("campWelcomeRadius")
	_arrive_sec = BalanceData.feel("campArriveWalkSec")
	_welcome_wait = BalanceData.feel("campWelcomeWaitSec")
	_shelter = BalanceData.feel("campShelterRadius")
	_brush_radius = BalanceData.feel("campBrushRadius")
	# Followers stay closer with Shepherd's Staff (follow-distance); the ring is data-scaled once.
	_crowd_radius = BalanceData.feel("campCrowdRadiusPx") * get_modifier(&"follow-distance", 1.0)
	_crowd_max = int(BalanceData.feel("campCrowdMax"))
	_per_figure = maxi(int(BalanceData.feel("campMenPerFigure")), 1)


func _build_scenery() -> void:
	backdrop.color = Color(0.34, 0.4, 0.26)
	StageUtil.make_rect(world, CAVE_RECT, Color(0.14, 0.11, 0.1))
	StageUtil.make_rect(world, Rect2(CAVE_RECT.position - Vector2(24, 24), Vector2(CAVE_RECT.size.x + 24, 24)), Color(0.35, 0.3, 0.27))


func _spot_line(count: int, y: float) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var n: int = clampi(count, 0, SPOT_MAX)
	for i in n:
		var k: float = 0.5 if n == 1 else float(i) / float(n - 1)
		out.append(Vector2(lerpf(SPOT_X0, SPOT_X1, k), y))
	return out


func _build_spots() -> void:
	_food_spots = _spot_line(def.param_int("foodSpots", 0), FOOD_Y)
	_water_spots = _spot_line(def.param_int("waterSpots", 0), WATER_Y)
	_food_used.resize(_food_spots.size())
	_food_used.fill(0)
	_water_used.resize(_water_spots.size())
	_water_used.fill(0)
	for p in _food_spots:
		StageUtil.make_rect(world, Rect2(p - Vector2(40, 30), Vector2(80, 60)), Color(0.35, 0.65, 0.3))
	for p in _water_spots:
		StageUtil.make_rect(world, Rect2(p - Vector2(40, 30), Vector2(80, 60)), Color(0.3, 0.55, 0.85))
	_brush.clear()
	var n: int = clampi(int(def.param("hidingSpots.count", 0)), 0, BRUSH_MAX)
	for i in n:
		_brush.append(BRUSHES[i])
		StageUtil.make_rect(world, Rect2(BRUSHES[i] - Vector2(70, 45), Vector2(140, 90)), Color(0.2, 0.42, 0.2))


func _build_men() -> void:
	_men.clear()
	if not _gather_on:
		return
	for i in mini(int(BalanceData.feel("campGathererCount")), MAN_MAX):
		var m: ActorCampMan = ActorCampMan.new()
		m.home = HOMES[i]
		m.position = m.home
		world.add_child(m)
		_men.append(m)


func _build_newcomers() -> void:
	_newcomers.clear()
	for i in NEWCOMER_POOL:
		var g: ActorCampNewcomers = ActorCampNewcomers.new()
		g.visible = false
		world.add_child(g)
		_newcomers.append(g)


func _build_crowd() -> void:
	_crowd.clear()
	for i in _crowd_max:
		var f: ActorFollower = ActorFollower.new()
		f.tone = i
		# Golden-angle spiral: even spread around the cave, filled from the middle out.
		var r: float = sqrt((float(i) + 0.5) / float(maxi(_crowd_max, 1)))
		f.ring = Vector2.from_angle(float(i) * 2.39996) * r
		f.visible = false
		world.add_child(f)
		_crowd.append(f)
	_layout_crowd()


func _build_patrol() -> void:
	_patrol = null
	if not _patrol_on:
		return
	_patrol = ActorCampPatrol.new()
	_patrol.sight_px = _sight_px
	_patrol.visible = false
	world.add_child(_patrol)


func _on_begin() -> void:
	_apply_visuals(play_event(&"enter"))
	var start_men: int = def.param_int("startMen", 0)
	men = maxi(run.followers, start_men)
	if men > run.followers:
		add_followers(men - run.followers)
	var bonus: int = take_food_bonus()
	if bonus > 0:
		food += bonus
		report_heal(bonus)
	_layout_crowd()
	_report_hud()


# --- Input ---

func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_up"):
		choose_direction(Vector2.UP)
	elif Input.is_action_just_pressed(&"ui_down"):
		choose_direction(Vector2.DOWN)
	elif Input.is_action_just_pressed(&"ui_left"):
		choose_direction(Vector2.LEFT)
	elif Input.is_action_just_pressed(&"ui_right"):
		choose_direction(Vector2.RIGHT)
	super(delta)


## David stands still while a man is chosen, so the direction press only sends him.
func _move_david(delta: float) -> void:
	if _selected == null:
		super(delta)


## OK: welcome a waiting group next to David; else choose (or un-choose) a man in camp.
func on_action_tap() -> void:
	if _finished:
		return
	if _selected != null:
		_deselect()
		return
	var group: ActorCampNewcomers = _waiting_group_near_david()
	if group != null:
		_join(group, true)
		return
	if not _gather_on:
		return
	var best: ActorCampMan = null
	var best_d: float = _select_radius
	for m in _men:
		if m.state != ActorCampMan.State.IDLE:
			continue
		var d: float = m.position.distance_to(david.position)
		if d <= best_d:
			best_d = d
			best = m
	if best != null:
		_selected = best
		_select_left = _select_window
		best.set_state(ActorCampMan.State.SELECTED)
		request_sfx(&"pickup")


## Sends the chosen man: UP = food, DOWN = water, LEFT / RIGHT = cancel. Returns true when he left.
func choose_direction(dir: Vector2) -> bool:
	if _finished or _selected == null:
		return false
	if absf(dir.y) < 0.5:
		_deselect()
		return false
	var m: ActorCampMan = _selected
	var is_food: bool = dir.y < 0.0
	var spots: PackedVector2Array = _food_spots if is_food else _water_spots
	var used: PackedByteArray = _food_used if is_food else _water_used
	for i in spots.size():
		if used[i] == 0:
			used[i] = 1
			m.spot = i
			m.goal = spots[i]
			m.kind = &"food" if is_food else &"water"
			_selected = null
			m.set_state(ActorCampMan.State.OUT)
			return true
	_deselect()
	return false


func _deselect() -> void:
	if _selected != null:
		_selected.set_state(ActorCampMan.State.IDLE)
	_selected = null


func _waiting_group_near_david() -> ActorCampNewcomers:
	for g in _newcomers:
		if g.active and g.arrived() and g.position.distance_to(david.position) <= _welcome_radius:
			return g
	return null


# --- Frame ---

func _step(delta: float) -> void:
	if _selected != null:
		_select_left -= delta
		if _select_left <= 0.0:
			_deselect()
	_step_arrivals(delta)
	_step_men(delta)
	if _patrol_on:
		_step_patrol(delta)
	if elapsed >= _day_sec:
		_end_of_day()
		return
	_report_hud()


func _step_arrivals(delta: float) -> void:
	if _next_arrival < _arrivals and elapsed >= _day_sec * float(_next_arrival + 1) / float(_arrivals + 1):
		for g in _newcomers:
			if not g.active:
				g.reset(NEWCOMER_START, MOUTH, _group_size(_next_arrival))
				_next_arrival += 1
				break
	for g in _newcomers:
		if not g.active:
			continue
		g.advance(delta, _arrive_sec)
		if g.arrived() and g.waited >= _welcome_wait:
			_join(g, false)


## Men in arrival group `i` (the last one takes the remainder of followersPerDay).
func _group_size(i: int) -> int:
	var base: int = int(float(_per_day) / float(_arrivals))
	if i == _arrivals - 1:
		return _per_day - base * (_arrivals - 1)
	return base


func _join(g: ActorCampNewcomers, greeted: bool) -> void:
	var n: int = g.size_men
	if greeted:
		var meals: int = mini(food, water)
		n += meals * _meal_bonus
		food -= meals
		water -= meals
		welcomed += 1
	g.dismiss()
	arrivals_joined += 1
	men += n
	add_followers(n)
	request_sfx(&"harp")
	for b in play_event(&"new-follower"):
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			StageUtil.set_backdrop(backdrop, str((b as Dictionary).get("cue", "")))
	_layout_crowd()


func _step_men(delta: float) -> void:
	for m in _men:
		match m.state:
			ActorCampMan.State.OUT:
				if _walk(m, m.goal, delta):
					m.work_left = _work_sec
					m.set_state(ActorCampMan.State.WORK)
			ActorCampMan.State.WORK:
				m.work_left -= delta
				if m.work_left <= 0.0:
					_free_spot(m)
					m.set_state(ActorCampMan.State.BACK)
			ActorCampMan.State.BACK:
				if _walk(m, m.home, delta):
					if m.kind == &"food":
						food += 1
					else:
						water += 1
					request_sfx(&"pickup")
					m.set_state(ActorCampMan.State.IDLE)


func _walk(m: ActorCampMan, to: Vector2, delta: float) -> bool:
	m.position = m.position.move_toward(to, _man_speed * delta)
	return m.position.is_equal_approx(to)


func _free_spot(m: ActorCampMan) -> void:
	if m.spot < 0:
		return
	if m.kind == &"food":
		_food_used[m.spot] = 0
	else:
		_water_used[m.spot] = 0
	m.spot = -1


# --- Patrol ---

func _step_patrol(delta: float) -> void:
	_patrol_timer = maxf(_patrol_timer - delta, 0.0)
	match patrol_phase:
		ActorCampPatrol.Phase.AWAY:
			if _patrol_timer <= 0.0:
				_patrol.lane_y = PATROL_LANES[_rng.randi_range(0, PATROL_LANES.size() - 1)]
				_patrol.position = Vector2(FIELD.end.x, _patrol.lane_y)
				_patrol.visible = true
				_exposure = 0.0
				_set_patrol_phase(ActorCampPatrol.Phase.IN)
		ActorCampPatrol.Phase.IN:
			_patrol.position.x = maxf(_patrol.position.x - _patrol_speed * delta, _turn_x)
			if _patrol.position.x <= _turn_x:
				_look_left = BalanceData.feel("campPatrolPauseSec")
				_set_patrol_phase(ActorCampPatrol.Phase.LOOK)
		ActorCampPatrol.Phase.LOOK:
			_look_left -= delta
			if _look_left <= 0.0:
				_set_patrol_phase(ActorCampPatrol.Phase.OUT)
		ActorCampPatrol.Phase.OUT:
			_patrol.position.x += _patrol_speed * delta
			if _patrol.position.x >= FIELD.end.x:
				_patrol.visible = false
				_patrol_timer = _patrol_interval
				_set_patrol_phase(ActorCampPatrol.Phase.AWAY)
	if patrol_phase == ActorCampPatrol.Phase.AWAY or patrol_phase == ActorCampPatrol.Phase.OUT:
		_exposure = 0.0
		_patrol.modulate = Color.WHITE
		return
	var notice: float = get_modifier(&"notice-time", _patrol_notice)
	if _patrol_sees():
		_exposure += delta
	else:
		_exposure = maxf(_exposure - delta, 0.0)
	var k: float = clampf(_exposure / maxf(notice, 0.01), 0.0, 1.0)
	_patrol.modulate = Color(1.0, 1.0 - 0.6 * k, 1.0 - 0.6 * k)
	if _exposure >= notice:
		_scatter()


func _set_patrol_phase(p: ActorCampPatrol.Phase) -> void:
	patrol_phase = p
	_patrol.phase = p


## True when the patrol can see David or a man out in the open.
func _patrol_sees() -> bool:
	var reach_sq: float = _sight_px * _sight_px
	if not david_hidden() and _patrol.position.distance_squared_to(david.position) <= reach_sq:
		return true
	for m in _men:
		if m.is_out() and _patrol.position.distance_squared_to(m.position) <= reach_sq:
			return true
	return false


## David is hidden in the cave's shelter or standing by a brush.
func david_hidden() -> bool:
	if david.position.distance_to(CAVE_CENTER) <= _shelter:
		return true
	for b in _brush:
		if david.position.distance_to(b) <= _brush_radius:
			return true
	return false


## The patrol found the camp: a fraction of the men scatter and the patrol leaves.
func _scatter() -> void:
	scatters += 1
	var lost: int = mini(int(round(float(men) * _scatter_fraction)), men)
	if lost > 0:
		men -= lost
		add_followers(-lost)
	_exposure = 0.0
	_set_patrol_phase(ActorCampPatrol.Phase.OUT)
	request_sfx(&"bump")
	_layout_crowd()


## Starts a patrol right away (tests and tools).
func summon_patrol() -> void:
	if _patrol != null and patrol_phase == ActorCampPatrol.Phase.AWAY:
		_patrol_timer = 0.0


func patrol_enabled() -> bool:
	return _patrol_on


## Seconds of being seen so far on the current patrol visit.
func exposure() -> float:
	return _exposure


func meals() -> int:
	return mini(food, water)


# --- End of the day ---

func _end_of_day() -> void:
	for g in _newcomers:
		if g.active:
			_join(g, false)
	if def.win_kind() == &"count-at-end":
		var need: int = int(def.win.get("min", _goal_men))
		if men < need:
			var top: int = int(def.win.get("topUpTo", 0))
			if top > men:
				var add: int = top - men
				men = top
				add_followers(add)
				_layout_crowd()
			elif fail(&"men-below-goal-at-end"):
				return
	_apply_visuals(play_event(&"win"))
	win()


# --- Display ---

func crowd_radius() -> float:
	return _crowd_radius


func visible_figures() -> int:
	return clampi(ceili(float(men) / float(_per_figure)), 0, _crowd.size())


func _layout_crowd() -> void:
	var shown: int = visible_figures()
	for i in _crowd.size():
		var f: ActorFollower = _crowd[i]
		f.visible = i < shown
		f.position = CROWD_CENTER + f.ring * _crowd_radius


func _report_hud() -> void:
	var left: int = ceili(maxf(_day_sec - elapsed, 0.0))
	if left != _last_time_shown:
		_last_time_shown = left
		report_counter(&"time", left)
	var m: int = meals()
	if m != _last_meals_shown:
		_last_meals_shown = m
		report_counter(&"loaves", m)
