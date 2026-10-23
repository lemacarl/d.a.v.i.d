class_name StagePlayBase
extends StageBase
## Shared field-play plumbing for stages where David walks and slings stones:
## world node, backdrop, David, a fixed stone pool, hit cooldown, and a `tick(delta)` entry point
## that tests call directly. In the tree, `_process` feeds `tick` from the D-pad.

const FIELD: Rect2 = Rect2(96, 54, 1728, 972)
const STONE_POOL: int = 4
## Most Mighty Men that can walk with David (nodes are created once per stage).
const COMPANION_MAX: int = 3
const DAVID_SCENE: PackedScene = preload("res://actors/actor-david.tscn")
const STONE_SCENE: PackedScene = preload("res://actors/actor-stone.tscn")

## Movement input in [-1, 1]. Set by `_process` from the D-pad; tests set it directly.
var input_dir: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var world: Node2D = null
var backdrop: ColorRect = null
var david: ActorDavid = null

var _stones: Array[ActorStone] = []
var _companions: Array[ActorCompanion] = []
var _companion_throws: bool = false
var _hit_cd: float = 0.0
var _throw_cd: float = 0.0
var _invuln_sec: float = 0.0
var _walk_speed_base: float = 0.0
var _stone_speed_base: float = 0.0
var _throw_cooldown: float = 0.0
var _stone_hit_radius: float = 0.0
var _stone_max_travel: float = 0.0
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
	_companions.clear()
	_companion_throws = false
	_invuln_sec = BalanceData.invulnerable_sec()
	# Feel numbers: data/balance.json `feel`, overridable per stage in params.
	_walk_speed_base = def.param_float("walkSpeed", BalanceData.feel("walkSpeed"))
	_stone_speed_base = def.param_float("stoneSpeed", BalanceData.feel("stoneSpeed"))
	_throw_cooldown = def.param_float("throwCooldownSec", BalanceData.feel("throwCooldownSec"))
	_stone_hit_radius = BalanceData.feel("stoneHitRadius")
	_stone_max_travel = BalanceData.feel("stoneMaxTravel")
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
		if not _idle(delta):
			set_process(false)
		return
	elapsed += delta
	_hit_cd = maxf(0.0, _hit_cd - delta)
	_throw_cd = maxf(0.0, _throw_cd - delta)
	if _hit_cd <= 0.0:
		david.set_flash(false)
	_move_david(delta)
	_update_companions(delta)
	_update_stones(delta)
	_step(delta)


## Override: stage logic for one frame (not called after the stage finishes).
func _step(_delta: float) -> void:
	pass


## Override: cosmetic-only motion after the stage ended. Return true while something still
## moves; when it returns false the stage stops processing.
func _idle(_delta: float) -> bool:
	return false


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
	_companion_throw(target, dir)


## True in Lamb mode, where OK in the field plays the harp instead of throwing a stone.
func lamb_harp_mode() -> bool:
	return run != null and run.mode == RunModel.Mode.LAMB


## Hold OK (2 s): with Song of Courage, plays the harp and frightens enemies close to David
## for harpFrightenSec. No damage. Without the Blessing the hold does nothing.
func on_action_hold() -> void:
	if _finished or not bool(get_feature(&"harpFrightenEnabled", false)):
		return
	request_sfx(&"harp")
	_frighten(float(get_feature(&"harpFrightenRadiusPx", 0.0)), float(get_feature(&"harpFrightenSec", 0.0)))


## Override: frighten the enemies within `radius` px of David for `sec` seconds.
func _frighten(_radius: float, _sec: float) -> void:
	pass


## Lamb mode OK: plays the harp and shows a placeholder note ring near David.
func play_harp_tap() -> void:
	if _finished or _throw_cd > 0.0:
		return
	_throw_cd = _throw_cooldown
	request_sfx(&"harp")
	if world == null or not world.is_inside_tree():
		return
	var ring: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		pts.append(Vector2.from_angle(TAU * float(i) / 24.0) * 60.0)
	ring.polygon = pts
	ring.color = Color(1.0, 0.88, 0.45, 0.55)
	ring.position = david.position + Vector2(0, -90)
	ring.scale = Vector2(0.4, 0.4)
	world.add_child(ring)
	var tw: Tween = ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(1.6, 1.6), 0.6)
	tw.tween_property(ring, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(ring.queue_free)


## Mighty Men (companionCount / companionThrowsStones). Call once from `_on_begin()`. Spawns the
## companions beside David and returns the first one, or null when the Blessing is absent. A companion
## throws a stone with every one of David's throws (same speed, same target, same hit handler) and
## adds `companionStones` pooled stones per companion. It never changes a scripted outcome.
func spawn_companion_if_blessed() -> ActorCompanion:
	if not _companions.is_empty():
		return _companions[0]
	var n: int = mini(int(get_feature(&"companionCount", 0)), COMPANION_MAX)
	if n <= 0 or world == null or david == null:
		return null
	_companion_throws = bool(get_feature(&"companionThrowsStones", false))
	var gap: float = BalanceData.feel("companionOffsetPx")
	var per: int = int(BalanceData.feel("companionStones"))
	for i in n:
		var c: ActorCompanion = ActorCompanion.new()
		c.offset = Vector2(-gap * (1.0 + float(i >> 1)), gap * (0.6 if i % 2 == 0 else -0.6))
		c.place(david.position)
		world.add_child(c)
		_companions.append(c)
		for j in per:
			var s: ActorStone = STONE_SCENE.instantiate() as ActorStone
			s.visible = false
			world.add_child(s)
			_stones.append(s)
	return _companions[0]


## Number of companions walking with David (0 without Mighty Men).
func companion_count() -> int:
	return _companions.size()


func _update_companions(delta: float) -> void:
	var speed: float = BalanceData.feel("companionFollowSpeed")
	for c in _companions:
		c.follow(david.position, speed, delta)


## Each companion throws a stone along with David's throw (only if the Blessing says they throw).
func _companion_throw(target: Node2D, dir: Vector2) -> void:
	if not _companion_throws:
		return
	for c in _companions:
		var s: ActorStone = _free_stone()
		if s == null:
			return
		var d: Vector2 = dir
		if target != null:
			d = (target.position - c.position).normalized()
		s.launch(c.position, target, d, get_modifier(&"stone-speed", _stone_speed_base))


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
			if s.position.distance_to(s.target.position) <= _stone_hit_radius + step:
				var hit: Node2D = s.target
				s.stop()
				_on_stone_hit(hit)
		else:
			s.position += s.dir * step
			if s.travelled > _stone_max_travel:
				s.stop()


## Hit the player if the contact cooldown allows. Returns true when a hit was taken.
func _contact_hit(amount: int = 1) -> bool:
	if _hit_cd > 0.0:
		return false
	_hit_cd = _invuln_sec
	david.set_flash(true)
	take_hit(amount)
	return true


## A field point at least `min_dist` px from `from` (falls back to the farthest try).
func _random_field_point_away(from: Vector2, min_dist: float) -> Vector2:
	var best: Vector2 = _random_field_point()
	for i in 24:
		if best.distance_to(from) >= min_dist:
			break
		var p: Vector2 = _random_field_point()
		if p.distance_to(from) > best.distance_to(from):
			best = p
	return best


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
