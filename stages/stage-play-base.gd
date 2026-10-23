class_name StagePlayBase
extends StageBase
## Shared field-play plumbing for stages where David walks and slings stones:
## world node, backdrop, David, a fixed stone pool, hit cooldown, and a `tick(delta)` entry point
## that tests call directly. In the tree, `_process` feeds `tick` from the D-pad.

const FIELD: Rect2 = Rect2(96, 54, 1728, 972)
const DEFAULT_WALK_SPEED: float = 320.0
const DEFAULT_STONE_SPEED: float = 900.0
const DEFAULT_THROW_COOLDOWN: float = 0.35
const STONE_POOL: int = 4
const STONE_HIT_RADIUS: float = 40.0
const STONE_MAX_TRAVEL: float = 2400.0
const DAVID_SCENE: PackedScene = preload("res://actors/actor-david.tscn")
const STONE_SCENE: PackedScene = preload("res://actors/actor-stone.tscn")

## Movement input in [-1, 1]. Set by `_process` from the D-pad; tests set it directly.
var input_dir: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var world: Node2D = null
var backdrop: ColorRect = null
var david: ActorDavid = null

var _stones: Array[ActorStone] = []
var _hit_cd: float = 0.0
var _throw_cd: float = 0.0
var _invuln_sec: float = 1.5
var _walk_speed_base: float = DEFAULT_WALK_SPEED
var _stone_speed_base: float = DEFAULT_STONE_SPEED
var _throw_cooldown: float = DEFAULT_THROW_COOLDOWN
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## True for stages where a throw with no target should still fly (the tutorial).
var _blank_throws: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	if world != null:
		world.queue_free()
	elapsed = 0.0
	_hit_cd = 0.0
	_throw_cd = 0.0
	_stones.clear()
	_invuln_sec = BalanceData.invulnerable_sec()
	_walk_speed_base = def.param_float("walkSpeed", DEFAULT_WALK_SPEED)
	_stone_speed_base = def.param_float("stoneSpeed", DEFAULT_STONE_SPEED)
	_throw_cooldown = def.param_float("throwCooldownSec", DEFAULT_THROW_COOLDOWN)
	_rng.seed = run.rng_seed if run != null else 1
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	backdrop = StageUtil.make_backdrop(world)
	david = DAVID_SCENE.instantiate() as ActorDavid
	david.position = FIELD.get_center() + Vector2(0, FIELD.size.y * 0.25)
	world.add_child(david)
	for i in STONE_POOL:
		var s: ActorStone = STONE_SCENE.instantiate() as ActorStone
		s.visible = false
		world.add_child(s)
		_stones.append(s)


func _process(delta: float) -> void:
	input_dir = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	tick(minf(delta, 0.1))


## Advances the stage by `delta` seconds. Subclasses extend `_step`.
func tick(delta: float) -> void:
	if _finished or def == null:
		_idle(delta)
		return
	elapsed += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	if _hit_cd <= 0.0:
		david.set_flash(false)
	_move_david(delta)
	_update_stones(delta)
	_step(delta)


## Override: stage logic for one frame (not called after the stage finishes).
func _step(_delta: float) -> void:
	pass


## Override: cosmetic-only motion after the stage ended.
func _idle(_delta: float) -> void:
	pass


## Override: the node a thrown stone should chase, or null.
func _pick_target() -> Node2D:
	return null


## Override: called when a stone reaches its target.
func _on_stone_hit(_target: Node2D) -> void:
	pass


func walk_speed() -> float:
	return get_modifier(&"walk-speed", _walk_speed_base)


func _move_david(delta: float) -> void:
	if input_dir.length_squared() < 0.0001:
		return
	var dir: Vector2 = input_dir.limit_length(1.0)
	david.position = (david.position + dir * walk_speed() * delta).clamp(FIELD.position, FIELD.end)
	david.set_facing(dir)


func on_action_tap() -> void:
	if _finished or _throw_cd > 0.0:
		return
	var target: Node2D = _pick_target()
	if target == null and not _blank_throws:
		return
	var stone: ActorStone = _free_stone()
	if stone == null:
		return
	var dir: Vector2 = david.facing
	if target != null:
		dir = (target.position - david.position).normalized()
	stone.launch(david.position, target, dir, get_modifier(&"stone-speed", _stone_speed_base))
	_throw_cd = _throw_cooldown
	report_stone_thrown()


func _free_stone() -> ActorStone:
	for s in _stones:
		if not s.active:
			return s
	return null


func _update_stones(delta: float) -> void:
	for s in _stones:
		if not s.active:
			continue
		var step: float = s.speed * delta
		s.travelled += step
		if s.target != null:
			if not s.target.visible:
				s.stop()
				continue
			s.dir = (s.target.position - s.position).normalized()
			s.position += s.dir * step
			if s.position.distance_to(s.target.position) <= STONE_HIT_RADIUS + step:
				var hit: Node2D = s.target
				s.stop()
				_on_stone_hit(hit)
		else:
			s.position += s.dir * step
			if s.travelled > STONE_MAX_TRAVEL:
				s.stop()


## Hit the player if the contact cooldown allows. Returns true when a hit was taken.
func _contact_hit(amount: int = 1) -> bool:
	if _hit_cd > 0.0:
		return false
	_hit_cd = _invuln_sec
	david.set_flash(true)
	take_hit(amount)
	return true


func _random_edge_point() -> Vector2:
	match _rng.randi_range(0, 3):
		0:
			return Vector2(FIELD.position.x, _rng.randf_range(FIELD.position.y, FIELD.end.y))
		1:
			return Vector2(FIELD.end.x, _rng.randf_range(FIELD.position.y, FIELD.end.y))
		2:
			return Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), FIELD.position.y)
	return Vector2(_rng.randf_range(FIELD.position.x, FIELD.end.x), FIELD.end.y)


func _random_field_point() -> Vector2:
	var inner: Rect2 = FIELD.grow(-120.0)
	return Vector2(_rng.randf_range(inner.position.x, inner.end.x), _rng.randf_range(inner.position.y, inner.end.y))


## Applies a backdrop cue from any `visual` beats in a play_event result.
func _apply_visuals(rest: Array) -> void:
	for b in rest:
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			StageUtil.set_backdrop(backdrop, str((b as Dictionary).get("cue", "")))
