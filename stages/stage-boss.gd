class_name StageBoss
extends StagePlayBase
## Boss stages for Chapter 1: the lion (variant chase-hits) and the bear (variant charge-lanes).
## Lamb mode removes the boss (movement "absent") and wins by gathering lost lambs (gather-sheep).

enum BearState { REST, WINDUP, CHARGE, SLIPPED, STUNNED }

const BAND_ALPHA: float = 0.25
const LAMB_SCENE: PackedScene = preload("res://actors/actor-lamb.tscn")
const LION_SCENE: PackedScene = preload("res://actors/actor-lion.tscn")
const BEAR_SCENE: PackedScene = preload("res://actors/actor-bear.tscn")

var variant: String = "chase-hits"
var hits: int = 0
var hits_to_drop: int = 0
var hits_to_flee: int = 0
var contact_damage: int = 1
var boss_present: bool = true
var lamb_dropped: bool = false
var fled: bool = false
var gather_total: int = 0
var gathered: int = 0

var boss: Node2D = null
var lambs: Array[ActorLamb] = []

var _stun_base: float = 1.0
var _stun_left: float = 0.0
var _afraid_left: float = 0.0
var _boss_radius: float = 60.0
# Lion circling.
var _angle: float = 0.0
var _circle_radius: float = 1.0
var _circle_speed: float = 0.0
# Bear charging.
var _bear_state: BearState = BearState.REST
var _bear_timer: float = 0.0
var _lane_count: int = 4
var _windup_sec: float = 0.0
var _rest_sec: float = 0.0
var _charge_speed: float = 0.0
var _slip_sec: float = 0.0
var _slip_double: bool = false
var _rock_every: int = 2
var _charge_count: int = 0
var _charge_dir: float = 1.0
var _lane_y: float = 0.0
var _rock_x: float = -1.0
var _band: ColorRect = null
var _rock: ColorRect = null
var _gather_radius: float = 0.0
var _min_lamb_distance: float = 0.0
var _flee_speed: float = 0.0
var _margin: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	variant = def.param_string("variant", "chase-hits")
	hits = 0
	gathered = 0
	lamb_dropped = false
	fled = false
	hits_to_drop = def.param_int("hitsToDrop", 0)
	hits_to_flee = def.param_int("hitsToFlee", 0)
	_gather_radius = BalanceData.feel("gatherRadius")
	_min_lamb_distance = BalanceData.feel("minLambDistance")
	_flee_speed = BalanceData.feel("bossFleeSpeed")
	_margin = BalanceData.feel("bossOffscreenMargin")
	contact_damage = def.param_int("contactDamage", 1)
	_stun_base = def.param_float("stunSec", 1.0)
	_stun_left = 0.0
	_afraid_left = 0.0
	var gather: bool = def.win_kind() == &"gather-sheep"
	gather_total = int(def.win.get("count", 1)) if gather else 0
	boss_present = not gather and def.param_string("movement", "") != "absent" and enemies_enabled()
	_circle_radius = maxf(1.0, def.param_float("circleRadius", 1.0))
	_circle_speed = def.param_float("circleSpeed", 0.0)
	_lane_count = maxi(1, def.param_int("lanes", 1))
	_windup_sec = def.param_float("windupSec", 0.0)
	_rest_sec = def.param_float("restSec", 0.0)
	_charge_speed = def.param_float("chargeSpeed", 0.0)
	_slip_sec = def.param_float("slipSec", 0.0)
	_slip_double = def.param_bool("slipDoubleHit", false)
	_rock_every = maxi(1, def.param_int("rockEvery", 2))
	_charge_count = 0
	_bear_state = BearState.REST
	_bear_timer = _rest_sec
	lambs.clear()
	boss = null
	var lamb_count: int = maxi(1, gather_total) if (gather or variant == "chase-hits") else 0
	for i in lamb_count:
		var l: ActorLamb = LAMB_SCENE.instantiate() as ActorLamb
		world.add_child(l)
		lambs.append(l)
		if gather:
			l.position = _random_field_point_away(david.position, _min_lamb_distance)
			l.held = false
		else:
			l.held = true
	if boss_present:
		if variant == "charge-lanes":
			var b: ActorBear = BEAR_SCENE.instantiate() as ActorBear
			boss = b
			_boss_radius = b.radius
			world.add_child(b)
			b.visible = false
			_band = ColorRect.new()
			_band.color = Color(0.9, 0.2, 0.1, BAND_ALPHA)
			_band.size = Vector2(FIELD.size.x, 2.0 * _boss_radius)
			_band.visible = false
			world.add_child(_band)
			_rock = ColorRect.new()
			_rock.color = Color(0.45, 0.45, 0.5)
			_rock.size = Vector2(70, 50)
			_rock.visible = false
			world.add_child(_rock)
		else:
			var li: ActorLion = LION_SCENE.instantiate() as ActorLion
			boss = li
			_boss_radius = li.radius
			world.add_child(li)
			_place_lion()


func _on_begin() -> void:
	_apply_visuals(play_event(&"enter"))


func _step(delta: float) -> void:
	_stun_left = maxf(0.0, _stun_left - delta)
	_afraid_left = maxf(0.0, _afraid_left - delta)
	if gather_total > 0:
		_gather_step()
		return
	if boss == null:
		return
	if variant == "charge-lanes":
		_bear_step(delta)
	else:
		_lion_step(delta)
	if boss.position.distance_to(david.position) <= _boss_radius + david.radius and _boss_dangerous():
		_contact_hit(contact_damage)


func _idle(delta: float) -> bool:
	if not fled or boss == null or not boss.visible:
		return false
	if variant == "charge-lanes":
		boss.position.x += _charge_dir * _flee_speed * delta
	else:
		boss.position.y -= _flee_speed * delta
	if not FIELD.grow(_margin).has_point(boss.position):
		boss.visible = false
		return false
	return true


func _boss_dangerous() -> bool:
	if variant == "charge-lanes":
		return _bear_state == BearState.CHARGE
	return _stun_left <= 0.0 and _afraid_left <= 0.0


# --- Lion ---

func _place_lion() -> void:
	boss.position = FIELD.get_center() + Vector2(cos(_angle), sin(_angle)) * _circle_radius
	if not lambs.is_empty() and lambs[0].held:
		lambs[0].position = boss.position + Vector2(0, -_boss_radius * 0.6)


func _lion_step(delta: float) -> void:
	if _stun_left <= 0.0 and _afraid_left <= 0.0:
		var speed: float = get_modifier(&"enemy-speed", _circle_speed)
		_angle += speed / _circle_radius * delta
		_place_lion()
		(boss as ActorLion).set_stunned(false)
	elif _afraid_left > 0.0 and _stun_left <= 0.0:
		boss.modulate = Color(0.75, 0.8, 1.0, 0.75)


# --- Bear ---

func _lane_pos(i: int) -> float:
	return FIELD.position.y + (float(i) + 0.5) * FIELD.size.y / float(_lane_count)


func _bear_step(delta: float) -> void:
	var bear: ActorBear = boss as ActorBear
	match _bear_state:
		BearState.REST, BearState.STUNNED:
			if _bear_state == BearState.STUNNED and _stun_left > 0.0:
				return
			bear.set_stunned(false)
			_bear_timer -= delta
			if _bear_timer <= 0.0:
				_begin_windup(bear)
		BearState.WINDUP:
			_bear_timer -= delta
			if _bear_timer <= 0.0:
				_bear_state = BearState.CHARGE
				_band.visible = false
		BearState.CHARGE:
			bear.position.x += _charge_dir * get_modifier(&"enemy-speed", _charge_speed) * delta
			if _slip_double and _rock_x >= 0.0 and signf(bear.position.x - _rock_x) == _charge_dir:
				_bear_state = BearState.SLIPPED
				_bear_timer = _slip_sec
				_rock.visible = false
				_rock_x = -1.0
				bear.set_stunned(true)
			elif not FIELD.grow(_margin).has_point(bear.position):
				_end_charge(bear)
		BearState.SLIPPED:
			_bear_timer -= delta
			if _bear_timer <= 0.0:
				bear.set_stunned(false)
				_end_charge(bear)


func _begin_windup(bear: ActorBear) -> void:
	var best: int = 0
	var best_d: float = INF
	for i in _lane_count:
		var d: float = absf(_lane_pos(i) - david.position.y)
		if d < best_d:
			best_d = d
			best = i
	_lane_y = _lane_pos(best)
	_charge_dir = 1.0 if _rng.randi_range(0, 1) == 0 else -1.0
	bear.position = Vector2(FIELD.position.x - 80.0 if _charge_dir > 0.0 else FIELD.end.x + 80.0, _lane_y)
	bear.visible = true
	_band.position = Vector2(FIELD.position.x, _lane_y - _boss_radius)
	_band.visible = true
	_charge_count += 1
	_rock_x = -1.0
	if _slip_double and _charge_count % _rock_every == 0:
		_rock_x = _rng.randf_range(FIELD.position.x + FIELD.size.x * 0.3, FIELD.position.x + FIELD.size.x * 0.7)
		_rock.position = Vector2(_rock_x - 35.0, _lane_y - 25.0)
		_rock.visible = true
	_bear_state = BearState.WINDUP
	# Watchful Eyes: a longer, brighter warning before the charge.
	var warn: float = float(get_feature(&"enemyTelegraphSec", 0.0))
	_band.color.a = 0.55 if warn > 0.0 else BAND_ALPHA
	_bear_timer = _windup_sec + warn


func _end_charge(bear: ActorBear) -> void:
	bear.visible = false
	_rock.visible = false
	_rock_x = -1.0
	_bear_state = BearState.REST
	_bear_timer = _rest_sec


# --- Gather (Lamb mode) ---

func _gather_step() -> void:
	for l in lambs:
		if l.collected:
			continue
		if l.position.distance_to(david.position) <= _gather_radius:
			l.collected = true
			l.visible = false
			gathered += 1
			report_sheep_saved()
	if gathered >= gather_total:
		_apply_visuals(play_event(&"win"))
		win()


# --- Hits ---

func on_action_tap() -> void:
	if lamb_harp_mode():
		play_harp_tap()
		return
	super()


func _pick_target() -> Node2D:
	if boss == null or fled or _stun_left > 0.0 or not boss.visible:
		return null
	return boss


func _on_stone_hit(target: Node2D) -> void:
	if target != boss or fled:
		return
	request_sfx(&"stone-hit")
	var weight: int = 1
	if variant == "charge-lanes" and _bear_state == BearState.SLIPPED and _slip_double:
		weight = 2
	_stun_left = get_modifier(&"stun-time", _stun_base)
	if variant == "charge-lanes":
		_bear_state = BearState.STUNNED
		_band.visible = false
		(boss as ActorBear).set_stunned(true)
		_bear_timer = _rest_sec
	else:
		(boss as ActorLion).set_stunned(true)
	register_hits(weight)


## Song of Courage: the lion stops and cannot hurt David for `sec` seconds, or the bear abandons a
## charge, if it is within `radius` of David. It counts as no hit, and the boss can still be hit.
func _frighten(radius: float, sec: float) -> void:
	if boss == null or fled or not boss.visible:
		return
	if boss.position.distance_to(david.position) > radius:
		return
	if variant == "charge-lanes":
		if _bear_state == BearState.WINDUP or _bear_state == BearState.CHARGE:
			_band.visible = false
			_end_charge(boss as ActorBear)
	else:
		_afraid_left = maxf(_afraid_left, sec)
		boss.modulate = Color(0.75, 0.8, 1.0, 0.75)


## Counts hits and runs the data triggers `drop` (hitsToDrop reached), `flee` (hitsToFlee reached)
## and `win`. Public so tests can drive it.
func register_hits(n: int) -> void:
	hits += n
	if not lamb_dropped and hits_to_drop > 0 and hits >= hits_to_drop:
		lamb_dropped = true
		_apply_visuals(play_event(&"drop"))
		if not lambs.is_empty():
			lambs[0].held = false
	if hits_to_flee > 0 and hits >= hits_to_flee:
		fled = true
		_apply_visuals(play_event(&"flee"))
		_apply_visuals(play_event(&"win"))
		win()
