extends RefCounted
## Shared helpers for the Chapter 4 rhythm, ending and flow tests (not a test file: the runner only
## loads test-*.gd). Stages come from the real data/stages/ch4.json.

const U := preload("res://tests/ch3-camp-util.gd")
const STEP: float = 0.1
const MODES: Array = [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB, RunModel.Mode.HARD]


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


static func tag(mode: RunModel.Mode, blessing: String) -> String:
	return "%s/%s" % [RunModel.mode_key(mode), blessing if not blessing.is_empty() else "none"]


## A rhythm stage in arrow mode, set up (not begun) with a recorder.
static func arrow_stage(mode: RunModel.Mode, blessing: String = "", seed_value: int = 7) -> Array:
	var s: StageRhythm = StageRhythm.new()
	var rec: Dictionary = U.build(s, stage_def("4-5-ark", mode), mode, blessing, null, seed_value)
	return [s, rec]


## Plays the arrow stage with a bot: presses the arrow that is in the window (`skill` 1.0 = every
## one, 0.0 = none). Returns the simulated seconds.
static func play_arrows(s: StageRhythm, skill: float = 1.0, limit: float = 200.0) -> float:
	var el: float = 0.0
	var n: int = 0
	var was_in: bool = false
	while el < limit and not s.is_finished():
		s.tick(STEP)
		el += STEP
		var d: int = s.arrow_in_window()
		if d >= 0 and not was_in:
			n += 1
		was_in = d >= 0
		if d >= 0 and float((n * 7) % 10) < skill * 10.0:
			s.press_arrow(StageRhythm.ARROW_NAMES[d])
	return el


## Plays a cutscene, tapping OK on every line. Returns the simulated seconds.
static func play_cutscene(s: StageCutscene, limit: float = 300.0) -> float:
	var el: float = 0.0
	while el < limit and not s.is_finished():
		s.tick(STEP)
		el += STEP
		if s.waiting == StageCutscene.Wait.LINE:
			s.on_action_tap()
	return el
