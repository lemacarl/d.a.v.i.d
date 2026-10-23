class_name StageDelivery
extends StagePlayBase
## Stage type `delivery` (2.2): David walks the road to the camp carrying a basket of loaves.
## Carts, goats and rolling rocks (hazards, not enemies; they stay in Lamb) knock a loaf out of
## the basket when bumped. Win at the camp with enough loaves. Lose on loaves-zero and timeout
## only where the mode allows failure; elsewhere loaves never go below the floor and the time
## limit is ignored. All numbers come from the stage params.

const MAX_HAZARDS: int = 16
const GOAL_MARGIN: float = 150.0
const START_MARGIN: float = 90.0
const HAZARD_FIRST_GAP: float = 260.0
const ROAD_HALF_HEIGHT: float = 380.0
const GOAT_SPAN: float = 160.0
const ROCK_AXIS: Vector2 = Vector2(0.35, 1.0)

var loaves: int = 0
var loaves_start: int = 0
var loaves_floor: int = 0
var loss_per_drop: int = 0
var min_loaves: int = 0
var time_limit: float = 0.0
var halfway_at: float = 0.0
var progress: float = 0.0
var bumps: int = 0
var halfway_done: bool = false
var hazards: Array[ActorHazard] = []

var _timer_on: bool = false
var _time_shown: int = -1
var _start_x: float = 0.0
var _goal_x: float = 0.0
var _knockback: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	loaves_start = def.param_int("loavesStart", 1)
	loaves_floor = def.param_int("loavesFloor", 0)
	loss_per_drop = maxi(def.param_int("lossPerDrop", 1), 1)
	min_loaves = int(def.win.get("minLoaves", 1))
	time_limit = def.param_float("timeLimitSec", 0.0)
	halfway_at = def.param_float("halfwayAt", 1.0)
	loaves = loaves_start
	progress = 0.0
	bumps = 0
	halfway_done = false
	_knockback = BalanceData.feel("bumpKnockbackPx")
	_timer_on = timer_enabled() and def.has_lose(&"timeout") and time_limit > 0.0
	_time_shown = -1
	_start_x = FIELD.position.x + START_MARGIN
	_goal_x = FIELD.end.x - GOAL_MARGIN
	_build_scenery()
	_build_hazards()
	world.move_child(david, -1)
	david.position = Vector2(_start_x, FIELD.get_center().y)


func _build_scenery() -> void:
	backdrop.color = Color(0.32, 0.5, 0.28)
	var cy: float = FIELD.get_center().y
	StageUtil.make_rect(world, Rect2(FIELD.position.x, cy - ROAD_HALF_HEIGHT - 20.0, FIELD.size.x, ROAD_HALF_HEIGHT * 2.0 + 40.0), Color(0.62, 0.5, 0.33))
	# The camp: a row of tents at the end of the road.
	for i in 3:
		var base: Vector2 = Vector2(_goal_x + 60.0, cy - 200.0 + float(i) * 200.0)
		var tent: Polygon2D = Polygon2D.new()
		tent.polygon = PackedVector2Array([base + Vector2(-80, 70), base + Vector2(0, -70), base + Vector2(80, 70)])
		tent.color = Color(0.9, 0.85, 0.7)
		world.add_child(tent)
	# The basket David carries.
	var basket: ColorRect = ColorRect.new()
	basket.position = Vector2(-22, -6)
	basket.size = Vector2(44, 26)
	basket.color = Color(0.7, 0.5, 0.2)
	basket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	david.add_child(basket)


func _build_hazards() -> void:
	hazards.clear()
	var queues: Array = []
	for e in def.param_array("hazards"):
		if e is Dictionary:
			queues.append([StringName(str((e as Dictionary).get("kind", "cart"))), int((e as Dictionary).get("count", 0)), float((e as Dictionary).get("speed", 0.0))])
	# Round-robin over the kinds so neighbours differ and the road is evenly covered.
	var order: Array = []
	var left: int = 1
	while left > 0 and order.size() < MAX_HAZARDS:
		left = 0
		for q in queues:
			var qa: Array = q as Array
			if int(qa[1]) > 0 and order.size() < MAX_HAZARDS:
				order.append([qa[0], qa[2]])
				qa[1] = int(qa[1]) - 1
			left += int(qa[1])
	var n: int = order.size()
	var cy: float = FIELD.get_center().y
	var x0: float = _start_x + HAZARD_FIRST_GAP
	var x1: float = _goal_x - HAZARD_FIRST_GAP * 0.5
	for i in n:
		var kind: StringName = (order[i] as Array)[0]
		var speed: float = float((order[i] as Array)[1])
		var h: ActorHazard = ActorHazard.new()
		world.add_child(h)
		var x: float = lerpf(x0, x1, (float(i) + 0.5) / float(n))
		var start: float = _rng.randf_range(-1.0, 1.0)
		var axis: Vector2 = Vector2.DOWN
		var span: float = ROAD_HALF_HEIGHT - 60.0
		var origin: Vector2 = Vector2(x, cy)
		if kind == &"goat":
			axis = Vector2.RIGHT
			span = GOAT_SPAN
			origin = Vector2(x, cy + _rng.randf_range(-ROAD_HALF_HEIGHT + 80.0, ROAD_HALF_HEIGHT - 80.0))
			start *= span
		elif kind == &"rolling-rock":
			axis = ROCK_AXIS
			start *= span
		else:
			start *= span
		h.configure(kind, origin, axis, span, speed, start)
		hazards.append(h)


func _on_begin() -> void:
	report_counter(&"loaves", loaves)
	report_counter(&"time", int(ceilf(time_limit)) if _timer_on else -1)
	_apply_visuals(play_event(&"start"))


func _step(delta: float) -> void:
	for h in hazards:
		h.advance(delta)
	_check_bump()
	if _finished:
		return
	var span: float = _goal_x - _start_x
	progress = clampf((david.position.x - _start_x) / span, 0.0, 1.0)
	if not halfway_done and progress >= halfway_at:
		halfway_done = true
		_apply_visuals(play_event(&"halfway"))
	if david.position.x >= _goal_x and loaves >= min_loaves:
		_apply_visuals(play_event(&"win"))
		win()
		return
	if _timer_on:
		_update_timer()


func _update_timer() -> void:
	var left: float = maxf(time_limit - elapsed, 0.0)
	var shown: int = int(ceilf(left))
	if shown != _time_shown:
		_time_shown = shown
		report_counter(&"time", shown)
	if left <= 0.0:
		fail(&"timeout")


func _check_bump() -> void:
	if _hit_cd > 0.0:
		return
	for h in hazards:
		var reach: float = h.radius + david.radius
		if h.position.distance_squared_to(david.position) <= reach * reach:
			_bump(h, reach)
			return


## Knocks a loaf out, pushes David clear of the hazard and gives him a moment of invulnerability.
func _bump(h: ActorHazard, reach: float) -> void:
	_hit_cd = _invuln_sec
	david.set_flash(true)
	bumps += 1
	request_sfx(&"bump")
	var away: Vector2 = david.position - h.position
	away = Vector2.LEFT if away.length_squared() < 0.01 else away.normalized()
	david.position = (h.position + away * (reach + _knockback)).clamp(FIELD.position, FIELD.end)
	loaves = maxi(loaves - loss_per_drop, 0)
	if loaves <= 0 and def.has_lose(&"loaves-zero"):
		report_counter(&"loaves", loaves)
		if fail(&"loaves-zero"):
			return
	loaves = maxi(loaves, loaves_floor)
	report_counter(&"loaves", loaves)
