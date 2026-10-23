class_name StageSearch
extends StagePlayBase
## Stage type `search` (4.7, Lo-debar). David walks the village (D-pad) and talks to the villagers with OK
## when he stands near one. They are met in a chain: talking to the next villager in the chain points the way
## to the following one, the last one points to Mephibosheth's house. There are no hint words (the script has
## none): the hint is a pointing arrow over the villager and a soft guide arrow beside David. OK beside a
## villager who is not next in the chain, or one already met, shows that arrow again. No enemies, never fails.
## Once every villager has been met, reaching the house wins: the `win` event lines play and the `visual`
## cue (long table in the palace) swaps the village for the long-table scene.
## Params: walkSpeed, villagers (default 4), hints (optional list of villager numbers: the chain order),
## goal. Events: `enter`, `win`.

const VILLAGER_MAX: int = 6
const TALK_REACH: float = 150.0
const HOUSE_REACH: float = 130.0
const POINT_SEC: float = 4.0
const GUIDE_IDLE_SEC: float = 8.0
const GUIDE_RADIUS: float = 110.0
const DEFAULT_WALK: float = 240.0
const CHAIR_COUNT: int = 8
## Villager spots as fractions of the field, then the house and David's start.
const SPOTS: Array[Vector2] = [Vector2(0.22, 0.66), Vector2(0.38, 0.3), Vector2(0.54, 0.72), Vector2(0.7, 0.3), Vector2(0.32, 0.88), Vector2(0.62, 0.12)]
const HOUSE_SPOT: Vector2 = Vector2(0.9, 0.62)
const START_SPOT: Vector2 = Vector2(0.07, 0.5)

var villagers: Array[ActorVillager] = []
var house: ActorVillagerHouse = null
var talked_count: int = 0
var chain: Array[int] = []
var table_shown: bool = false

var _village: Node2D = null
var _table: Node2D = null
var _guide: Polygon2D = null
var _pointer: Polygon2D = null
var _point_left: float = 0.0
var _point_owner: int = -1


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_walk_speed_base = def.param_float("walkSpeed", DEFAULT_WALK)
	talked_count = 0
	table_shown = false
	_point_left = 0.0
	_point_owner = -1
	villagers.clear()
	chain.clear()
	var n: int = clampi(def.param_int("villagers", 4), 1, VILLAGER_MAX)
	_make_chain(n)
	backdrop.color = Color(0.55, 0.72, 0.85)
	_village = Node2D.new()
	world.add_child(_village)
	StageUtil.make_rect(_village, Rect2(0, 330, StageUtil.SCREEN.x, 750), Color(0.62, 0.55, 0.38))
	house = ActorVillagerHouse.new()
	house.position = field_point(HOUSE_SPOT)
	_village.add_child(house)
	for i in n:
		var v: ActorVillager = ActorVillager.new()
		v.robe_index = i
		v.position = field_point(SPOTS[i])
		_village.add_child(v)
		villagers.append(v)
	_guide = _make_arrow(Color(1.0, 0.88, 0.45, 0.85))
	_pointer = _make_arrow(Color(1.0, 0.95, 0.6, 0.95))
	_pointer.scale = Vector2(1.6, 1.6)
	_pointer.visible = false
	_build_table()
	david.position = field_point(START_SPOT)
	world.move_child(david, -1)


func _on_begin() -> void:
	spawn_companion_if_blessed()
	_apply_visuals(play_event(&"enter"))


static func field_point(frac: Vector2) -> Vector2:
	return FIELD.position + Vector2(FIELD.size.x * frac.x, FIELD.size.y * frac.y)


## The chain order: `hints` as villager numbers when it is a valid list, otherwise 0, 1, 2 ...
func _make_chain(n: int) -> void:
	var raw: Array = def.param_array("hints")
	var seen: Dictionary = {}
	for h in raw:
		if (h is int or h is float) and int(h) >= 0 and int(h) < n and not seen.has(int(h)):
			seen[int(h)] = true
			chain.append(int(h))
	if chain.size() != n:
		chain.clear()
		for i in n:
			chain.append(i)


func _make_arrow(color: Color) -> Polygon2D:
	var a: Polygon2D = Polygon2D.new()
	a.polygon = PackedVector2Array([Vector2(-18, -9), Vector2(2, -9), Vector2(2, -20), Vector2(24, 0), Vector2(2, 20), Vector2(2, 9), Vector2(-18, 9)])
	a.color = color
	a.z_index = 4
	world.add_child(a)
	return a


func _build_table() -> void:
	_table = Node2D.new()
	_table.visible = false
	world.add_child(_table)
	StageUtil.make_rect(_table, Rect2(0, 0, StageUtil.SCREEN.x, StageUtil.SCREEN.y), Color(0.45, 0.32, 0.3))
	StageUtil.make_rect(_table, Rect2(260, 420, 1400, 240), Color(0.55, 0.36, 0.2))
	for i in CHAIR_COUNT:
		var cx: float = 360.0 + float(i / 2) * 400.0
		var cy: float = 350.0 if i % 2 == 0 else 690.0
		StageUtil.make_rect(_table, Rect2(cx, cy, 90, 60), Color(0.35, 0.22, 0.15))
		StageUtil.make_disc(_table, Vector2(cx + 45.0, 540.0 + (0.0 if i % 2 == 0 else 20.0)), 28.0, Color(0.9, 0.85, 0.7))


# ---- Play ----------------------------------------------------------------------------------------------

## The chain target now: a villager number, or -1 when every villager has been met (the house).
func current_target() -> int:
	return chain[talked_count] if talked_count < chain.size() else -1


func target_position() -> Vector2:
	var t: int = current_target()
	return house.position if t < 0 else villagers[t].position


func on_action_tap() -> void:
	if _finished:
		return
	var best: int = -1
	var best_d: float = TALK_REACH
	for i in villagers.size():
		var d: float = villagers[i].position.distance_to(david.position)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return
	request_sfx(&"pickup")
	if best == current_target():
		villagers[best].talked = true
		talked_count += 1
		house.open = talked_count >= chain.size()
	_point_from(best)


## The talking villager points toward what David should find next.
func _point_from(i: int) -> void:
	if _point_owner >= 0:
		villagers[_point_owner].bubble = false
	_point_owner = i
	villagers[i].bubble = true
	_point_left = POINT_SEC


func _step(delta: float) -> void:
	_update_arrows(delta)
	if talked_count >= chain.size() and house.position.distance_to(david.position) <= HOUSE_REACH:
		_finish()


func _update_arrows(delta: float) -> void:
	var to: Vector2 = target_position()
	var dir: Vector2 = (to - david.position).normalized()
	_guide.visible = talked_count > 0 or elapsed >= GUIDE_IDLE_SEC
	_guide.position = david.position + dir * GUIDE_RADIUS + Vector2(0.0, -40.0)
	_guide.rotation = dir.angle()
	_guide.modulate.a = 0.55 + 0.35 * sin(elapsed * 5.0)
	if _point_left > 0.0:
		_point_left -= delta
		var src: Vector2 = villagers[_point_owner].position
		var pd: Vector2 = (to - src).normalized()
		_pointer.visible = true
		_pointer.position = src + Vector2(0.0, -250.0)
		_pointer.rotation = pd.angle()
		if _point_left <= 0.0:
			_pointer.visible = false
			villagers[_point_owner].bubble = false
			_point_owner = -1


func _finish() -> void:
	var rest: Array = play_event(&"win")
	for b in rest:
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			var cue: String = str((b as Dictionary).get("cue", ""))
			if cue.contains("table"):
				_show_table()
	win()


func _show_table() -> void:
	table_shown = true
	_village.visible = false
	_guide.visible = false
	_pointer.visible = false
	david.visible = false
	for c in _companions:
		c.visible = false
	_table.visible = true
