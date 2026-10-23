extends RefCounted
## Shared helpers for the Chapter 2 tests (not a test file: the runner only loads test-*.gd).

const STEP: float = 0.1


static func stage_def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(2, mode):
		if d.id == StringName(stage_id):
			return d
	return null


static func stack(mode: RunModel.Mode, blessing: String) -> ModifierStack:
	var ms: ModifierStack = ModifierStack.new(mode)
	if not blessing.is_empty():
		ms.add_blessing(BalanceData.blessing_card(StringName(blessing)))
	return ms


## The Chapter 2 Blessing pool from data, preceded by "" (no Blessing).
static func blessings() -> Array:
	var out: Array = [""]
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch2.json")
	for b in (ch.get("blessingPool", []) as Array):
		out.append(str(b))
	return out


static func modes() -> Array:
	return [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]


static func tag(mode: RunModel.Mode, blessing: String) -> String:
	return "%s/%s" % [RunModel.mode_key(mode), blessing if not blessing.is_empty() else "none"]


## Calls setup on `s` (not begin) and returns a recorder dictionary wired to its signals.
static func build(s: StageBase, d: StageDef, mode: RunModel.Mode, blessing: String = "", stones: int = 0, seed_value: int = 7) -> Dictionary:
	var rec: Dictionary = {"won": 0, "failed": 0, "reason": &"", "hits": 0, "ids": [], "sfx": [], "spent": 0, "collected": 0, "counters": [], "visuals": [], "shown": []}
	s.stage_won.connect(func() -> void: rec["won"] = int(rec["won"]) + 1)
	s.stage_failed.connect(func(r: StringName) -> void:
		rec["failed"] = int(rec["failed"]) + 1
		rec["reason"] = r)
	s.hit_taken.connect(func(_n: int) -> void: rec["hits"] = int(rec["hits"]) + 1)
	s.line_requested.connect(func(_sp: StringName, _tx: String, _r: String, id: StringName) -> void: (rec["ids"] as Array).append(id))
	s.sfx_requested.connect(func(cue: StringName) -> void: (rec["sfx"] as Array).append(cue))
	s.stone_spent.connect(func() -> void: rec["spent"] = int(rec["spent"]) + 1)
	s.stone_collected.connect(func() -> void: rec["collected"] = int(rec["collected"]) + 1)
	s.counter_changed.connect(func(k: StringName, v: int) -> void: (rec["counters"] as Array).append([k, v]))
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	rm.rng_seed = seed_value
	rm.stones = stones
	s.setup(d, rm, stack(mode, blessing))
	return rec


static func run_for(s: Object, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds and not (s as StageBase).is_finished():
		s.call("tick", STEP)
		t += STEP


static func new_run_state() -> Node:
	var rs: Node = load("res://autoload/run-state.gd").new() as Node
	rs.call("set_seed", 4242)
	return rs


## Advances a RunState (skipping Blessing picks) until `stage_id` is current.
static func go_to(rs: Node, stage_id: String) -> void:
	var guard: int = 0
	while String((rs.get("current_stage") as StageDef).id) != stage_id and guard < 30:
		rs.call("advance")
		if rs.get("awaiting_blessing"):
			rs.call("skip_blessing")
		guard += 1


static func cur(rs: Node) -> String:
	return String((rs.get("current_stage") as StageDef).id)
