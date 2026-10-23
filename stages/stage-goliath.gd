class_name StageGoliath
extends StagePlayBase
## Stage type `boss`, variant `weak-point` (2.6, Goliath).
## Phase 1: a shield-bearer walks in front of Goliath (stones bounce off, no stone is spent) and
## spears fly along the lanes. Phase 2: Goliath stops to laugh, tilts his head back and his forehead
## glows for glowSec; OK during the glow hits and ends the fight. That win is ALWAYS granted: no
## mode and no Blessing is consulted. OK at any other moment in phase 2 is a miss (one stone, or
## nothing where stones refill). With no stones left and the fight not won the stage fails with
## &"stones-out" (the mode decides whether that restarts the brook). Goliath never falls on screen.

enum Phase { SPEARS, LAUGH, GLOW, HIT }

const SPEAR_POOL: int = 4
const GOLIATH_POS: Vector2 = Vector2(1594, 560)
const SHIELD_OFFSET: Vector2 = Vector2(-190, 0)
const SHIELD_BOB: float = 180.0
const SHIELD_RATE: float = 0.9
const SPEAR_FROM_X: float = 1450.0
const DAVID_MAX_X: float = 1180.0
const MISS_OFFSET: Vector2 = Vector2(-330, -200)
const BAND_HEIGHT: float = 70.0

var phase: Phase = Phase.SPEARS
var stones_left: int = 0
var misses: int = 0
var spears_thrown: int = 0

var goliath: ActorGoliath = null
var shield: ActorShield = null
var spears: Array[ActorSpear] = []

var _forehead: Node2D = null
var _miss_marker: Node2D = null
var _band: ColorRect = null
var _lane_count: int = 0
var _spear_speed: float = 0.0
var _spear_interval: float = 0.0
var _laugh_sec: float = 0.0
var _glow_sec: float = 0.0
var _telegraph_sec: float = 0.0
var _spear_hit_radius: float = 0.0
var _spear_on: bool = false
var _shield_on: bool = false
var _refill: bool = false
var _phase_left: float = 0.0
var _spear_timer: float = 0.0
var _tele_left: float = 0.0
var _tele_lane: int = -1
var _last_lane: int = -1
var _round_throws: int = 0
var _stones_checked: bool = false
var _hit_pending: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_lane_count = def.param_int("phase1.spearLanes", 0)
	_spear_speed = def.param_float("phase1.spearSpeed", 0.0)
	_spear_interval = def.param_float("phase1.spearIntervalSec", 1.0)
	_laugh_sec = def.param_float("phase2.laughSec", 0.0)
	_glow_sec = def.param_float("phase2.glowSec", 0.0)
	_telegraph_sec = BalanceData.feel("spearTelegraphSec")
	_spear_hit_radius = BalanceData.feel("spearHitRadius")
	_spear_on = enemies_enabled() and _lane_count > 0
	_shield_on = enemies_enabled() and def.param_bool("phase1.shieldBearer", false)
	_refill = def.param_bool("stones.refillOnMiss", false) or stones_refill()
	stones_left = run.stones if run != null else 0
	misses = 0
	spears_thrown = 0
	_hit_pending = false
	_stones_checked = false
	_tele_left = 0.0
	_tele_lane = -1
	_last_lane = -1
	_build_scene()
	david.position = Vector2(FIELD.position.x + 200.0, GOLIATH_POS.y)
	_begin_round(false)


func _build_scene() -> void:
	backdrop.color = Color(0.36, 0.3, 0.22)
	StageUtil.make_rect(world, Rect2(FIELD.position.x, GOLIATH_POS.y + 190.0, FIELD.size.x, FIELD.end.y - GOLIATH_POS.y - 190.0), Color(0.42, 0.36, 0.26))
	_band = StageUtil.make_rect(world, Rect2(FIELD.position.x, 0.0, FIELD.size.x, BAND_HEIGHT), Color(0.9, 0.2, 0.1, 0.25))
	_band.visible = false
	goliath = ActorGoliath.new()
	goliath.position = GOLIATH_POS
	world.add_child(goliath)
	_forehead = Node2D.new()
	_forehead.position = GOLIATH_POS + ActorGoliath.FOREHEAD
	world.add_child(_forehead)
	_miss_marker = Node2D.new()
	_miss_marker.position = GOLIATH_POS + MISS_OFFSET
	world.add_child(_miss_marker)
	shield = ActorShield.new()
	shield.position = GOLIATH_POS + SHIELD_OFFSET
	shield.visible = _shield_on
	world.add_child(shield)
	spears.clear()
	for i in SPEAR_POOL:
		var sp: ActorSpear = ActorSpear.new()
		sp.visible = false
		world.add_child(sp)
		spears.append(sp)
	world.move_child(david, -1)


func _on_begin() -> void:
	_apply_visuals(play_event(&"enter"))
	if phase == Phase.LAUGH:
		_apply_visuals(play_event(&"laugh"))


## Starts a round: spears first where there are spears, otherwise straight to the laugh.
func _begin_round(announce: bool) -> void:
	_round_throws = 0
	_spear_timer = _spear_interval
	goliath.glow = false
	goliath.head_back = false
	if _spear_on:
		phase = Phase.SPEARS
		goliath.laughing = false
	else:
		_enter_laugh(announce)


func _enter_laugh(announce: bool) -> void:
	phase = Phase.LAUGH
	_phase_left = maxf(_laugh_sec - _glow_sec, 0.0)
	goliath.laughing = true
	goliath.glow = false
	goliath.head_back = false
	shield.visible = false
	if announce:
		_apply_visuals(play_event(&"laugh"))


func _enter_glow() -> void:
	phase = Phase.GLOW
	_phase_left = _glow_sec
	goliath.head_back = true
	goliath.glow = true


## True while the forehead glows (the only moment OK hits).
func glow_active() -> bool:
	return phase == Phase.GLOW


func _step(delta: float) -> void:
	if not _stones_checked:
		_stones_checked = true
		if stones_left <= 0 and not _refill:
			fail(&"stones-out")
			return
	david.position.x = minf(david.position.x, DAVID_MAX_X)
	_move_shield()
	_spears_step(delta)
	match phase:
		Phase.SPEARS:
			_spear_phase(delta)
		Phase.LAUGH:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_enter_glow()
		Phase.GLOW:
			_phase_left -= delta
			if _phase_left <= 0.0:
				_begin_round(true)


func _move_shield() -> void:
	if not shield.visible:
		return
	shield.position.y = GOLIATH_POS.y + sin(elapsed * SHIELD_RATE) * SHIELD_BOB


# --- Spears ---

func _lane_y(i: int) -> float:
	return FIELD.position.y + (float(i) + 0.5) * FIELD.size.y / float(_lane_count)


func _spear_phase(delta: float) -> void:
	if _tele_lane >= 0:
		_tele_left -= delta
		if _tele_left <= 0.0:
			if not _throw_spear(_tele_lane):
				return
			_tele_lane = -1
			_band.visible = false
			_spear_timer = _spear_interval
		return
	if _round_throws >= _lane_count:
		# Round over once the last spear has left the field.
		for sp in spears:
			if sp.active:
				return
		_enter_laugh(true)
		return
	_spear_timer -= delta
	if _spear_timer > 0.0:
		return
	var lane: int = _rng.randi_range(0, _lane_count - 1)
	if lane == _last_lane and _lane_count > 1:
		lane = (lane + 1) % _lane_count
	_last_lane = lane
	_tele_lane = lane
	# Watchful Eyes lengthens the warning.
	_tele_left = _telegraph_sec + float(get_feature(&"enemyTelegraphSec", 0.0))
	_band.position.y = _lane_y(lane) - BAND_HEIGHT * 0.5
	_band.visible = true


## Launches a pooled spear down `lane`. False when every spear is still in flight (try again).
func _throw_spear(lane: int) -> bool:
	for sp in spears:
		if not sp.active:
			sp.launch(Vector2(SPEAR_FROM_X, _lane_y(lane)), _spear_speed)
			_round_throws += 1
			spears_thrown += 1
			return true
	return false


func _spears_step(delta: float) -> void:
	for sp in spears:
		if not sp.active:
			continue
		sp.position.x -= sp.speed * delta
		if sp.position.x + sp.length < FIELD.position.x:
			sp.stop()
			continue
		if phase == Phase.HIT:
			continue
		var dx: float = david.position.x - sp.position.x
		if dx >= -26.0 - david.radius and dx <= sp.length + david.radius \
				and absf(david.position.y - sp.position.y) <= _spear_hit_radius + david.radius * 0.5:
			_contact_hit(1)


# --- OK ---

## OK: hits during the glow, otherwise a stone bounces off the shield (phase 1, free) or misses.
func on_action_tap() -> void:
	if _finished or _hit_pending or _throw_cd > 0.0:
		return
	match phase:
		Phase.GLOW:
			_hit_pending = true
			phase = Phase.HIT
			goliath.glow = true
			_band.visible = false
			if not _launch_at(_forehead):
				_fell()
		Phase.LAUGH:
			if _launch_at(_miss_marker):
				_register_miss()
		Phase.SPEARS:
			_launch_at(shield if _shield_on else _miss_marker)


func _launch_at(target: Node2D) -> bool:
	var stone: ActorStone = _free_stone()
	if stone == null:
		return false
	stone.launch(david.position, target, (target.position - david.position).normalized(), get_modifier(&"stone-speed", _stone_speed_base))
	_throw_cd = _throw_cooldown
	report_stone_thrown()
	return true


func _on_stone_hit(target: Node2D) -> void:
	if target == _forehead and _hit_pending:
		request_sfx(&"stone-hit")
		_fell()
	elif target == shield:
		request_sfx(&"bounce")


## The one stone found the forehead. Goliath falls in the next scene (a cut-away, never drawn here).
func _fell() -> void:
	if _finished:
		return
	_apply_visuals(play_event(&"win"))
	win()


func _register_miss() -> void:
	misses += 1
	_apply_visuals(play_event(&"miss"))
	if _refill:
		return
	stones_left = maxi(stones_left - 1, 0)
	report_stone_spent()
	if stones_left <= 0:
		fail(&"stones-out")
