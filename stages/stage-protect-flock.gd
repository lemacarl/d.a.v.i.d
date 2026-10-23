class_name StageProtectFlock
extends StagePlayBase
## Protect the flock until the night ends. Predators come from the field edges; David slings
## stones at them. A predator that reaches a sheep drags it off; walking near a lost sheep returns it.

const SHEEP_SCENE: PackedScene = preload("res://actors/actor-sheep.tscn")
const PREDATOR_SCENE: PackedScene = preload("res://actors/actor-predator.tscn")
const FLOCK_RING_RADIUS: float = 140.0

var duration: float = 0.0
## Fewest sheep that may be alive at sunrise (win.minAlive, also the mid-night lose threshold).
var min_alive: int = 0
var drift: float = 0.0

var _sheep: Array[ActorSheep] = []
var _predators: Array[ActorPredator] = []
var _spawns: Array = []
var _spawn_timers: PackedFloat32Array = PackedFloat32Array()
var _below_min_reported: bool = false
var _sheep_speed: float = 0.0
var _wander_radius: float = 0.0
var _drift_range: float = 0.0
var _catch_radius: float = 0.0
var _rescue_radius: float = 0.0
var _flee_mult: float = 0.0
var _margin: float = 0.0
var _follow_pull: float = 0.0
var _pulse_hz: float = 0.0
var _return_speed: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_sheep.clear()
	_predators.clear()
	_below_min_reported = false
	duration = def.param_float("durationSec", 90.0)
	drift = def.param_float("sheepDriftToThreat", 0.0)
	min_alive = int(def.win.get("minAlive", 0))
	_sheep_speed = BalanceData.feel("sheepSpeed")
	_wander_radius = BalanceData.feel("sheepWanderRadius")
	_drift_range = BalanceData.feel("sheepDriftRange")
	_catch_radius = BalanceData.feel("predatorCatchRadius")
	_rescue_radius = BalanceData.feel("sheepRescueRadius")
	_flee_mult = BalanceData.feel("predatorFleeSpeedMult")
	_margin = BalanceData.feel("offscreenMargin")
	_follow_pull = BalanceData.feel("flockFollowPullPxPerSec")
	_pulse_hz = BalanceData.feel("telegraphPulseHz")
	_return_speed = BalanceData.feel("sheepReturnSpeed")
	_spawns = def.param_array("predators") if enemies_enabled() else []
	_spawn_timers.resize(_spawns.size())
	for i in _spawns.size():
		_spawn_timers[i] = float((_spawns[i] as Dictionary).get("spawnIntervalSec", 10.0))
	var total: int = def.param_int("sheepTotal", 0)
	var center: Vector2 = FIELD.get_center()
	for i in total:
		var s: ActorSheep = SHEEP_SCENE.instantiate() as ActorSheep
		var ang: float = TAU * float(i) / float(maxi(total, 1))
		s.ring = Vector2(cos(ang), sin(ang)) * FLOCK_RING_RADIUS
		s.home = center + s.ring
		s.position = s.home
		s.wander_phase = float(i) * 0.9
		world.add_child(s)
		_sheep.append(s)
	var cap: int = def.param_int("maxPredators", 1)
	for i in cap:
		var p: ActorPredator = PREDATOR_SCENE.instantiate() as ActorPredator
		p.deactivate()
		world.add_child(p)
		_predators.append(p)


func _on_begin() -> void:
	_apply_visuals(play_event(&"start"))


func alive_sheep() -> int:
	var n: int = 0
	for s in _sheep:
		if s.is_alive():
			n += 1
	return n


func live_predators() -> int:
	var n: int = 0
	for p in _predators:
		if p.state != ActorPredator.State.INACTIVE:
			n += 1
	return n


## Predators currently showing only their warning glow (Watchful Eyes).
func telegraphing_predators() -> int:
	var n: int = 0
	for p in _predators:
		if p.state == ActorPredator.State.TELEGRAPH:
			n += 1
	return n


## Removes sheep from play (used by tests; predators do this in play).
func remove_sheep(count: int) -> void:
	for s in _sheep:
		if count <= 0:
			break
		if s.is_alive():
			s.set_state(ActorSheep.State.GONE)
			count -= 1
	_check_sheep()


func _step(delta: float) -> void:
	_spawn_predators(delta)
	_update_predators(delta)
	_update_sheep(delta)
	_check_rescues()
	if elapsed >= duration:
		_finish_night()


func _idle(delta: float) -> bool:
	var moving: bool = false
	for p in _predators:
		if p.state == ActorPredator.State.FLEE:
			_flee_step(p, delta)
			moving = moving or p.state == ActorPredator.State.FLEE
	return moving


func _finish_night() -> void:
	if alive_sheep() < min_alive:
		if fail(&"sheep-below-min"):
			return
	_apply_visuals(play_event(&"win"))
	win()


func _spawn_predators(delta: float) -> void:
	if _spawns.is_empty() or not enemies_enabled():
		return
	for i in _spawns.size():
		_spawn_timers[i] -= delta
		if _spawn_timers[i] > 0.0:
			continue
		var entry: Dictionary = _spawns[i] as Dictionary
		_spawn_timers[i] = float(entry.get("spawnIntervalSec", 10.0))
		var slot: ActorPredator = _free_predator()
		if slot == null:
			continue
		var spd: float = get_modifier(&"enemy-speed", float(entry.get("speed", 90.0)))
		var kind: StringName = StringName(str(entry.get("kind", "jackal")))
		var at: Vector2 = _random_edge_point()
		var warn: float = float(get_feature(&"enemyTelegraphSec", 0.0))
		if warn > 0.0:
			slot.telegraph(kind, at, spd, warn)
		else:
			slot.activate(kind, at, spd)


func _free_predator() -> ActorPredator:
	for p in _predators:
		if p.state == ActorPredator.State.INACTIVE:
			return p
	return null


func _update_predators(delta: float) -> void:
	for p in _predators:
		match p.state:
			ActorPredator.State.TELEGRAPH:
				p.telegraph_left -= delta
				p.modulate.a = 0.55 + 0.45 * sin(p.telegraph_left * TAU * _pulse_hz)
				if p.telegraph_left <= 0.0:
					p.activate(p.pending_kind, p.position, p.pending_speed)
			ActorPredator.State.CHASE:
				if p.afraid > 0.0:
					p.afraid -= delta
					_flee_step(p, delta)
					if p.afraid <= 0.0:
						p.modulate = Color.WHITE
					continue
				var prey: ActorSheep = _nearest_flock_sheep(p.position)
				var goal: Vector2 = david.position if prey == null else prey.position
				p.position += (goal - p.position).normalized() * p.speed * delta
				if prey != null and p.position.distance_to(prey.position) <= _catch_radius:
					prey.set_state(ActorSheep.State.LOST)
					p.carry = prey
					p.state = ActorPredator.State.DRAG
				_touch_david(p)
			ActorPredator.State.DRAG:
				var away: Vector2 = (p.position - FIELD.get_center()).normalized()
				p.position += away * p.speed * delta
				p.carry.position = p.position
				if not FIELD.grow(_margin).has_point(p.position):
					p.carry.set_state(ActorSheep.State.GONE)
					p.deactivate()
					_check_sheep()
				else:
					_touch_david(p)
			ActorPredator.State.FLEE:
				_flee_step(p, delta)


func _touch_david(p: ActorPredator) -> void:
	if p.position.distance_to(david.position) > p.radius + david.radius:
		return
	if _contact_hit():
		_start_flee(p)


func _start_flee(p: ActorPredator) -> void:
	if p.carry != null:
		p.carry.set_state(ActorSheep.State.LOST)
		p.carry.home = p.carry.position
		p.carry = null
	p.state = ActorPredator.State.FLEE


func _flee_step(p: ActorPredator, delta: float) -> void:
	var away: Vector2 = (p.position - david.position).normalized()
	p.position += away * p.speed * _flee_mult * delta
	if not FIELD.grow(_margin).has_point(p.position):
		p.deactivate()


func _nearest_flock_sheep(from: Vector2) -> ActorSheep:
	var best: ActorSheep = null
	var best_d: float = INF
	for s in _sheep:
		if s.state != ActorSheep.State.FLOCK:
			continue
		var d: float = from.distance_squared_to(s.position)
		if d < best_d:
			best_d = d
			best = s
	return best


func _nearest_live_predator(from: Vector2, max_dist: float) -> ActorPredator:
	var best: ActorPredator = null
	var best_d: float = max_dist * max_dist
	for p in _predators:
		if not p.is_live():
			continue
		var d: float = from.distance_squared_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _update_sheep(delta: float) -> void:
	var follow: float = get_modifier(&"follow-distance", 1.0)
	var wander: float = get_modifier(&"sheep-wander", 1.0) * follow
	var pull: float = _follow_pull * maxf(0.0, 1.0 - follow) * delta
	for s in _sheep:
		if s.state == ActorSheep.State.GONE:
			continue
		if s.state == ActorSheep.State.LOST and _carried(s):
			continue
		if s.state == ActorSheep.State.FLOCK and pull > 0.0:
			# Shepherd's Staff: the flock's resting spot slides toward David.
			var goal: Vector2 = (david.position + s.ring).clamp(FIELD.position, FIELD.end)
			s.home = s.home.move_toward(goal, pull)
		if s.returning:
			# In the tree the sheep walks itself; outside it (tests) the stage steps it.
			if not s.is_inside_tree():
				s.advance_return(delta)
			continue
		s.wander_phase += delta * 0.8
		var around: Vector2 = s.home + Vector2(cos(s.wander_phase), sin(s.wander_phase * 1.3)) * _wander_radius * wander
		var step: Vector2 = (around - s.position).limit_length(_sheep_speed * 0.3 * delta)
		if s.state == ActorSheep.State.FLOCK and drift > 0.0:
			var threat: ActorPredator = _nearest_live_predator(s.position, _drift_range)
			if threat != null:
				step += (threat.position - s.position).normalized() * drift * follow * _sheep_speed * delta
		s.position += step


func _carried(s: ActorSheep) -> bool:
	for p in _predators:
		if p.carry == s:
			return true
	return false


func _check_rescues() -> void:
	for s in _sheep:
		if s.state != ActorSheep.State.LOST or _carried(s):
			continue
		if s.position.distance_to(david.position) <= _rescue_radius:
			s.rescue(_flock_spot(s), _return_speed)
			report_sheep_saved()
			_apply_visuals(play_event(&"sheep-saved"))


## Where a rescued sheep rejoins the flock (the Staff keeps the flock around David).
func _flock_spot(s: ActorSheep) -> Vector2:
	if get_modifier(&"follow-distance", 1.0) < 1.0:
		return (david.position + s.ring).clamp(FIELD.position, FIELD.end)
	return FIELD.get_center() + s.ring


func _check_sheep() -> void:
	if _below_min_reported or not def.has_lose(&"sheep-below-min"):
		return
	if alive_sheep() < min_alive:
		_below_min_reported = true
		fail(&"sheep-below-min")


func on_action_tap() -> void:
	if lamb_harp_mode():
		play_harp_tap()
		return
	super()


func _pick_target() -> Node2D:
	var best: ActorPredator = null
	var best_d: float = INF
	for p in _predators:
		if not p.is_live():
			continue
		var d: float = david.position.distance_squared_to(p.position)
		if d < best_d:
			best_d = d
			best = p
	return best


func _on_stone_hit(target: Node2D) -> void:
	var p: ActorPredator = target as ActorPredator
	if p != null and p.is_live():
		_hit_feedback(p.position)
		p.flash_hit()
		_start_flee(p)


## Song of Courage: live predators near David back away for `sec` seconds; one dragging a sheep
## lets it go and runs off. Nothing is damaged.
func _frighten(radius: float, sec: float) -> void:
	var r2: float = radius * radius
	for p in _predators:
		if not p.is_live() or p.position.distance_squared_to(david.position) > r2:
			continue
		if p.state == ActorPredator.State.DRAG:
			_start_flee(p)
		else:
			p.afraid = sec
			p.modulate = Color(0.75, 0.8, 1.0, 0.75)
