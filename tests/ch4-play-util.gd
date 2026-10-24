extends RefCounted
## Shared helpers for the Chapter 4 maze, patience and search tests (the runner only loads test-*.gd).
## Stages are built from the real data/stages/ch4.json through the Chapter 3 recorder.

const U3 := preload("res://tests/ch3-camp-util.gd")
const STEP: float = 0.1


static func stage_def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(4, mode):
		if d.id == StringName(stage_id):
			return d
	return null


## The Chapter 4 Blessing pool from data, preceded by "" (no Blessing).
static func blessings() -> Array:
	var out: Array = [""]
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch4.json")
	for b in (ch.get("blessingPool", []) as Array):
		out.append(str(b))
	return out


static func modes() -> Array:
	return [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]


static func tag(mode: RunModel.Mode, blessing: String) -> String:
	return U3.tag(mode, blessing)


## Builds `s` from stage `stage_id` and returns the recorder (see ch3-camp-util `build`), with `spared` counted.
static func build(s: StageBase, stage_id: String, mode: RunModel.Mode, blessing: String = "") -> Dictionary:
	var rec: Dictionary = U3.build(s, stage_def(stage_id, mode), mode, blessing)
	rec["spared"] = 0
	s.spared.connect(func() -> void: rec["spared"] = int(rec["spared"]) + 1)
	return rec


static func walk_to(s: StagePlayBase, target: Vector2, max_secs: float = 30.0) -> void:
	var t: float = 0.0
	while t < max_secs and not s.is_finished() and s.david.position.distance_to(target) > 4.0:
		var reach: float = s.walk_speed() * STEP
		s.input_dir = ((target - s.david.position) / reach).limit_length(1.0)
		s.tick(STEP)
		t += STEP
	s.input_dir = Vector2.ZERO


static func run_for(s: Object, seconds: float) -> void:
	U3.run_for(s, seconds)
