extends RefCounted
## Harp stage clarity fixes: hits land on press, generous window, never fails, 60 s, Lamb easier.

const STEP: float = 0.05


func run(t: TestRunner) -> void:
	_press_hits(t)
	_window(t)
	_never_fails(t)
	_duration(t)
	_lamb(t)
	_visuals(t)


func _stage(mode: RunModel.Mode) -> StageRhythm:
	var d: StageDef = null
	for sd in StageDef.load_chapter(1, mode):
		if sd.id == &"1-6-harp":
			d = sd
	var s: StageRhythm = StageRhythm.new()
	var rm: RunModel = RunModel.new()
	rm.mode = mode
	s.setup(d, rm, ModifierStack.new(mode))
	s.begin()
	return s


func _until_window(s: StageRhythm) -> void:
	var guard: int = 0
	while not s.note_in_window() and guard < 2000:
		s.tick(STEP)
		guard += 1


func _press_hits(t: TestRunner) -> void:
	var s: StageRhythm = _stage(RunModel.Mode.NORMAL)
	var sfx: Array = []
	s.sfx_requested.connect(func(c: StringName) -> void: sfx.append(c))
	_until_window(s)
	s.on_action_press()
	t.eq(s.hits, 1, "a press alone is a hit")
	t.truthy(sfx.has(&"harp"), "a hit asks for the harp cue")
	s.on_action_hold()
	s.on_action_tap()
	t.eq(s.hits, 1, "the release tap after a press (or a long hold) adds no second hit")
	t.truthy(s.brightness > 0.0, "a hit brightens the room")
	t.truthy(s.room.lit_lamps() == 0, "lamps follow the smoothed brightness")
	for i in 20:
		s.tick(STEP)
	t.truthy(s.room.lit_lamps() >= 1, "a lamp is lit after a hit")
	# Lamb sends only a tap (on press).
	var l: StageRhythm = _stage(RunModel.Mode.LAMB)
	_until_window(l)
	l.on_action_tap()
	t.eq(l.hits, 1, "Lamb tap-on-press is a hit")
	s.free()
	l.free()


func _window(t: TestRunner) -> void:
	var s: StageRhythm = _stage(RunModel.Mode.NORMAL)
	var d: StageDef = s.def
	t.truthy(d.param_float("hitWindowSec", 0.0) >= 0.35, "Normal hit window is generous (data)")
	s.tick(STEP)
	var before: int = s.hits
	s.on_action_press()
	t.eq(s.hits, before, "a press with no note in the window is not a hit")
	t.eq(s.misses, 0, "an empty press costs nothing")
	s.free()


func _never_fails(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var s: StageRhythm = _stage(mode)
		var failed: Array = [0]
		var won: Array = [0]
		s.stage_failed.connect(func(_r: StringName) -> void: failed[0] += 1)
		s.stage_won.connect(func() -> void: won[0] += 1)
		var guard: int = 0
		while not s.is_finished() and guard < 4000:
			s.tick(STEP)
			guard += 1
		t.eq(failed[0], 0, "all misses never fail (mode %d)" % mode)
		t.eq(won[0], 1, "all misses still wins (mode %d)" % mode)
		t.truthy(s.misses > 0 and s.hits == 0, "misses are only counted (mode %d)" % mode)
		t.near(s.brightness, 0.0, "long misses never push brightness below dark")
		s.free()


func _duration(t: TestRunner) -> void:
	var s: StageRhythm = _stage(RunModel.Mode.NORMAL)
	var secs: float = 0.0
	while not s.is_finished() and secs < 120.0:
		s.tick(STEP)
		secs += STEP
	t.truthy(absf(secs - 60.0) <= 0.2, "rhythm lasts 60 s (got %s)" % secs)
	s.free()


func _lamb(t: TestRunner) -> void:
	var n: StageDef = null
	var l: StageDef = null
	for sd in StageDef.load_chapter(1, RunModel.Mode.NORMAL):
		if sd.id == &"1-6-harp":
			n = sd
	for sd in StageDef.load_chapter(1, RunModel.Mode.LAMB):
		if sd.id == &"1-6-harp":
			l = sd
	t.truthy(l.param_float("hitWindowSec", 0.0) > n.param_float("hitWindowSec", 0.0), "Lamb window is bigger")
	t.truthy(l.param_float("noteSpeed", 0.0) < n.param_float("noteSpeed", 0.0), "Lamb notes are slower")
	t.truthy(l.param_float("notesPerMinute", 0.0) < n.param_float("notesPerMinute", 0.0), "Lamb notes are more spaced")
	t.truthy(n.param_float("noteSpeed", 0.0) <= 300.0, "Normal notes are slow enough to read")


func _visuals(t: TestRunner) -> void:
	# Misses dim a lit room a little (Normal), never below dark and never a failure.
	var s: StageRhythm = _stage(RunModel.Mode.NORMAL)
	_until_window(s)
	s.on_action_press()
	s.on_action_tap()
	var lit: float = s.brightness
	var guard: int = 0
	while s.misses < 4 and guard < 2000:
		s.tick(STEP)
		guard += 1
	t.truthy(s.brightness < lit, "a run of misses dims the room a little")
	t.truthy(s.brightness >= 0.0, "dimming stops at dark")
	t.falsy(s.is_finished(), "a miss run does not end the stage")
	# Pooled notes: node count does not grow while the stage runs.
	var count: int = s.world.get_child_count()
	for i in 600:
		s.tick(STEP)
	t.eq(s.world.get_child_count(), count, "note nodes are reused, not created")
	s.free()
