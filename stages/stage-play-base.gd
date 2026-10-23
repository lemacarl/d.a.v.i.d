class_name StagePlayBase
extends StageBase
## Shared field-play plumbing for stages where David walks and slings stones:
## world node, backdrop, David, a fixed stone pool, hit cooldown, and a `tick(delta)` entry point
## that tests call directly. In the tree, `_process` feeds `tick` from the D-pad.

const FIELD: Rect2 = Rect2(96, 54, 1728, 972)
const STONE_POOL: int = 4
const SPARK_POOL: int = 3
const SPARK_SEC: float = 0.3
const DAVID_SCENE: PackedScene = preload("res://actors/actor-david.tscn")
const STONE_SCENE: PackedScene = preload("res://actors/actor-stone.tscn")

## Movement input in [-1, 1]. Set by `_process` from the D-pad; tests set it directly.
var input_dir: Vector2 = Vector2.ZERO
var elapsed: float = 0.0
var world: Node2D = null
var backdrop: ColorRect = null
var david: ActorDavid = null

var _stones: Array[ActorStone] = []
var _sparks: Array[Polygon2D] = []
var _spark_tweens: Array[Tween] = []
var _spark_next: int = 0
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
	_sparks.clear()
	_spark_tweens.clear()
	_spark_next = 0
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


## A stone struck an animal: the `hit` cue plays on this frame (the host maps it through
## data/audio.json) and a brief gold-white burst marks the spot.
func _hit_feedback(at: Vector2) -> void:
	request_sfx(&"hit")
	if world == null or not world.is_inside_tree():
		return
	if _sparks.is_empty():
		_build_sparks()
	var i: int = _spark_next
	_spark_next = (_spark_next + 1) % SPARK_POOL
	var sp: Polygon2D = _sparks[i]
	if _spark_tweens[i] != null and _spark_tweens[i].is_valid():
		_spark_tweens[i].kill()
	sp.position = at
	sp.scale = Vector2(0.4, 0.4)
	sp.modulate.a = 1.0
	sp.visible = true
	var tw: Tween = sp.create_tween()
	tw.set_parallel(true)
	tw.tween_property(sp, "scale", Vector2(1.5, 1.5), SPARK_SEC)
	tw.tween_property(sp, "modulate:a", 0.0, SPARK_SEC)
	tw.chain().tween_callback(sp.hide)
	_spark_tweens[i] = tw


func _build_sparks() -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for k in 16:
		pts.append(Vector2.from_angle(TAU * float(k) / 16.0) * (60.0 if k % 2 == 0 else 24.0))
	for i in SPARK_POOL:
		var sp: Polygon2D = Polygon2D.new()
		sp.polygon = pts
		sp.color = Color(1.0, 0.95, 0.6, 0.9)
		sp.z_index = 5
		sp.visible = false
		world.add_child(sp)
		_sparks.append(sp)
		_spark_tweens.append(null)


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
