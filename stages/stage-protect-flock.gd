class_name StageProtectFlock
extends StagePlayBase
## Protect the flock until the night ends. Predators come from the field edges; David slings
## stones at them. A predator that reaches a sheep drags it off; walking near a lost sheep returns it.

const SHEEP_SCENE: PackedScene = preload("res://actors/actor-sheep.tscn")
const PREDATOR_SCENE: PackedScene = preload("res://actors/actor-predator.tscn")
const DEFAULT_MAX_PREDATORS: int = 6
const SHEEP_SPEED: float = 120.0
const SHEEP_WANDER_RADIUS: float = 90.0
const DRIFT_RANGE: float = 520.0
const CATCH_RADIUS: float = 40.0
const RESCUE_RADIUS: float = 80.0
const FLEE_SPEED_MULT: float = 1.3
const OFFSCREEN_MARGIN: float = 120.0

var duration: float = 90.0
var min_alive_win: int = 0
var min_alive_lose: int = 0
var drift: float = 0.3

var _sheep: Array[ActorSheep] = []
var _predators: Array[ActorPredator] = []
var _spawns: Array = []
var _spawn_timers: PackedFloat32Array = PackedFloat32Array()
var _saved_event_count: int = 0
var _last_saved_event: float = -1000.0
var _saved_limit_cooldown: float = 0.0
var _saved_limit_max: int = 1000000
var _below_min_reported: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_sheep.clear()
	_predators.clear()
	_saved_event_count = 0
	_last_saved_event = -1000.0
	_below_min_reported = false
	duration = def.param_float("durationSec", 90.0)
	drift = def.param_float("sheepDriftToThreat", 0.0)
	min_alive_win = int(def.win.get("minAlive", 0))
	min_alive_lose = int(def.lose_for(&"sheep-below-min").get("min", 0))
	var limits: Dictionary = def.param_dict("eventLimits.sheep-saved")
	_saved_limit_cooldown = float(limits.get("cooldownSec", 0.0))
	_saved_limit_max = int(limits.get("maxPerStage", 1000000))
	_spawns = def.param_array("predators") if enemies_enabled() else []
	_spawn_timers.resize(_spawns.size())
	for i in _spawns.size():
		_spawn_timers[i] = float((_spawns[i] as Dictionary).get("spawnIntervalSec", 10.0))
	var total: int = def.param_int("sheepTotal", 0)
	var center: Vector2 = FIELD.get_center()
	for i in total:
		var s: ActorSheep = SHEEP_SCENE.instantiate() as ActorSheep
		var ang: float = TAU * float(i) / float(maxi(total, 1))
		s.home = center + Vector2(cos(ang), sin(ang)) * 140.0
		s.position = s.home
		s.wander_phase = float(i) * 0.9
		world.add_child(s)
		_sheep.append(s)
	var cap: int = def.param_int("maxPredators", DEFAULT_MAX_PREDATORS)
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


func _idle(delta: float) -> void:
	for p in _predators:
		if p.state == ActorPredator.State.FLEE:
			_flee_step(p, delta)


func _finish_night() -> void:
	if alive_sheep() < min_alive_win:
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
		slot.activate(StringName(str(entry.get("kind", "jackal"))), _random_edge_point(), spd)


func _free_predator() -> ActorPredator:
	for p in _predators:
		if p.state == ActorPredator.State.INACTIVE:
			return p
	return null


func _update_predators(delta: float) -> void:
	for p in _predators:
		match p.state:
			ActorPredator.State.CHASE:
				var prey: ActorSheep = _nearest_flock_sheep(p.position)
				var goal: Vector2 = david.position if prey == null else prey.position
				p.position += (goal - p.position).normalized() * p.speed * delta
				if prey != null and p.position.distance_to(prey.position) <= CATCH_RADIUS:
					prey.set_state(ActorSheep.State.LOST)
					p.carry = prey
					p.state = ActorPredator.State.DRAG
				_touch_david(p)
			ActorPredator.State.DRAG:
				var away: Vector2 = (p.position - FIELD.get_center()).normalized()
				p.position += away * p.speed * delta
				p.carry.position = p.position
				if not FIELD.grow(OFFSCREEN_MARGIN).has_point(p.position):
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
	p.position += away * p.speed * FLEE_SPEED_MULT * delta
	if not FIELD.grow(OFFSCREEN_MARGIN).has_point(p.position):
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
	var wander: float = get_modifier(&"sheep-wander", 1.0)
	for s in _sheep:
		if s.state == ActorSheep.State.GONE:
			continue
		if s.state == ActorSheep.State.LOST and _carried(s):
			continue
		s.wander_phase += delta * 0.8
		var around: Vector2 = s.home + Vector2(cos(s.wander_phase), sin(s.wander_phase * 1.3)) * SHEEP_WANDER_RADIUS * wander
		var step: Vector2 = (around - s.position).limit_length(SHEEP_SPEED * 0.3 * delta)
		if s.state == ActorSheep.State.FLOCK and drift > 0.0:
			var threat: ActorPredator = _nearest_live_predator(s.position, DRIFT_RANGE)
			if threat != null:
				step += (threat.position - s.position).normalized() * drift * SHEEP_SPEED * delta
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
		if s.position.distance_to(david.position) <= RESCUE_RADIUS:
			s.set_state(ActorSheep.State.FLOCK)
			s.home = s.position
			report_sheep_saved()
			_play_saved_event()


func _play_saved_event() -> void:
	if _saved_event_count >= _saved_limit_max:
		return
	if elapsed - _last_saved_event < _saved_limit_cooldown:
		return
	_saved_event_count += 1
	_last_saved_event = elapsed
	_apply_visuals(play_event(&"sheep-saved"))


func _check_sheep() -> void:
	if _below_min_reported or not def.has_lose(&"sheep-below-min"):
		return
	if alive_sheep() < min_alive_lose:
		_below_min_reported = true
		fail(&"sheep-below-min")


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
		_start_flee(p)
