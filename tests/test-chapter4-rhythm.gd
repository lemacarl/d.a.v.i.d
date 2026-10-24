extends RefCounted
## Stage 4.5 (the ark comes home): arrow prompts, hits dance and add musicians and dancers up to a cap,
## misses never end the stage, 60 s wins in every mode with every Chapter 4 Blessing, and the OK rhythm
## stages 1.6 and 3.2 stay as they were.

const H := preload("res://tests/ch4-host-util.gd")
const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_data(t)
	_hits_add_figures(t)
	_wrong_direction_and_ok(t)
	_misses_never_end(t)
	_all_modes_and_blessings(t)
	_directions(t)
	_bounded(t)
	_line_gate(t)
	_through_host(t)
	_ok_stages_unchanged(t)
	for n in _made:
		n.free()
	RunState.end_run()


func _make(mode: RunModel.Mode = RunModel.Mode.NORMAL, blessing: String = "") -> Array:
	var pair: Array = H.arrow_stage(mode, blessing)
	_made.append(pair[0])
	return pair


func _data(t: TestRunner) -> void:
	var d: StageDef = H.stage_def("4-5-ark", RunModel.Mode.NORMAL)
	t.eq(d.type, &"rhythm", "4.5 is a rhythm stage")
	t.eq(d.param_string("inputs"), "arrows", "4.5 takes arrow prompts")
	t.eq(d.param_float("durationSec"), 60.0, "60 seconds")
	t.eq(d.win_kind(), &"duration-elapsed", "the win is the time running out")
	t.eq(d.lose.size(), 0, "4.5 cannot be lost")
	t.falsy(d.param_bool("missEndsStage", true), "a miss never ends the stage")
	t.truthy(d.param_bool("hitAddsDancers"), "a hit adds dancers")
	t.truthy(d.param_int("maxDancers") > 0 and d.param_int("maxMusicians") > 0, "the figure caps are data")
	t.truthy(d.param_float("notesPerMinute") > 0.0 and d.param_float("noteSpeed") > 0.0 and d.param_float("hitWindowSec") > 0.0, "the note numbers are data")
	t.eq(d.beats(&"enter").size(), 1, "one entry beat")
	t.eq(str((d.beats(&"enter")[0] as Dictionary)["line"]), "c4-5-narr", "the entry beat is David danced before the LORD")
	t.truthy(d.blessing_after, "4.5 offers Blessings after it (4.7 is the last playable stage)")


func _hits_add_figures(t: TestRunner) -> void:
	var pair: Array = _make()
	var s: StageRhythm = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	var cap_d: int = s.def.param_int("maxDancers")
	var cap_m: int = s.def.param_int("maxMusicians")
	t.truthy(s.arrows_enabled(), "arrow mode on")
	t.truthy(s.parade != null and s.room == null, "the parade replaces the harp room")
	t.eq(s.dancers + s.musicians, 0, "nobody dances before the first hit")
	var seen: int = 0
	var el: float = 0.0
	var last_total: int = 0
	var grew_by_one: bool = true
	while el < 200.0 and not s.is_finished():
		s.tick(H.STEP)
		el += H.STEP
		var d: int = s.arrow_in_window()
		if d >= 0:
			var before: int = s.dancers + s.musicians
			if s.press_arrow(StageRhythm.ARROW_NAMES[d]):
				seen += 1
				var after: int = s.dancers + s.musicians
				if after != mini(before + 1, cap_d + cap_m):
					grew_by_one = false
				last_total = after
	t.eq(int(rec["won"]), 1, "the stage was won")
	t.eq(s.hits, seen, "every pressed arrow in the window is a hit")
	t.truthy(seen >= 30, "a perfect player hits most of the arrows (%d)" % seen)
	t.truthy(grew_by_one, "each hit adds exactly one figure until the caps")
	t.truthy(s.dancers <= cap_d and s.musicians <= cap_m, "dancers %d/%d musicians %d/%d" % [s.dancers, cap_d, s.musicians, cap_m])
	t.eq(s.dancers + s.musicians, last_total, "the counts match the last hit")
	t.eq(s.parade.dancers, s.dancers, "the parade draws that many dancers")
	t.eq(s.parade.musicians, s.musicians, "...and musicians")
	t.eq(int(rec["hits"]), 0, "no heart is ever lost")
	t.truthy((rec["sfx"] as Array).has(&"harp"), "a hit plays the harp cue")
	# Past the caps more hits add nothing.
	var big: Array = _make()
	var b: StageRhythm = big[0]
	b.begin()
	for i in 700:
		b.tick(H.STEP)
		var dd: int = b.arrow_in_window()
		if dd >= 0:
			b.press_arrow(StageRhythm.ARROW_NAMES[dd])
		if b.is_finished():
			break
	t.truthy(b.hits > cap_d / 2, "many hits")
	t.eq(b.dancers, mini(b.dancers, cap_d), "still capped")
	for i in cap_d + cap_m + 5:
		b._add_figure()
	t.eq(b.dancers, cap_d, "forced extra figures stop at the dancer cap")
	t.eq(b.musicians, cap_m, "...and at the musician cap")


func _wrong_direction_and_ok(t: TestRunner) -> void:
	var pair: Array = _make()
	var s: StageRhythm = pair[0]
	s.begin()
	var d: int = -1
	var el: float = 0.0
	while d < 0 and el < 30.0:
		s.tick(H.STEP)
		el += H.STEP
		d = s.arrow_in_window()
	t.truthy(d >= 0, "an arrow reaches the window")
	var wrong: StringName = StageRhythm.ARROW_NAMES[(d + 1) % 4]
	# Only compare when no second arrow of the wrong direction also sits in the window.
	t.falsy(s.press_arrow(wrong), "the wrong direction is not a hit")
	t.eq(s.hits, 0, "...and costs nothing")
	t.falsy(s.press_arrow(&"sideways"), "an unknown direction is ignored")
	s.on_action_press()
	s.on_action_tap()
	s.on_action_hold()
	t.eq(s.hits, 0, "OK does nothing in arrow mode")
	t.truthy(s.press_arrow(StageRhythm.ARROW_NAMES[d]), "the matching direction hits")
	t.eq(s.hits, 1, "one hit")
	t.falsy(s.press_arrow(StageRhythm.ARROW_NAMES[d]), "the same arrow cannot be hit twice")


func _misses_never_end(t: TestRunner) -> void:
	for mode in H.MODES:
		var pair: Array = _make(mode)
		var s: StageRhythm = pair[0]
		var rec: Dictionary = pair[1]
		s.begin()
		var el: float = H.play_arrows(s, 0.0)
		var k: String = RunModel.mode_key(mode)
		t.eq(int(rec["won"]), 1, "%s: pressing nothing for 60 s still wins" % k)
		t.eq(int(rec["failed"]), 0, "%s: no failure" % k)
		t.eq(int(rec["hits"]), 0, "%s: no heart taken" % k)
		t.truthy(s.misses > 20, "%s: the arrows were missed (%d)" % [k, s.misses])
		t.truthy(absf(el - 60.0) < 0.3, "%s: it ends at 60 s (%.1f)" % [k, el])
		t.eq(s.dancers + s.musicians, 0, "%s: nobody joined" % k)
		t.eq(rec["ids"], [&"c4-5-narr"], "%s: only the narrator line" % k)
		# Half skill: still a win.
		var half: Array = _make(mode)
		(half[0] as StageRhythm).begin()
		H.play_arrows(half[0], 0.5)
		t.eq(int((half[1] as Dictionary)["won"]), 1, "%s: half the arrows still wins" % k)
		t.truthy((half[0] as StageRhythm).hits > 0 and (half[0] as StageRhythm).misses > 0, "%s: some hit, some missed" % k)


func _all_modes_and_blessings(t: TestRunner) -> void:
	for mode in H.MODES:
		for b in H.blessings():
			var pair: Array = _make(mode, b)
			var s: StageRhythm = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			H.play_arrows(s, 0.7)
			var tg: String = H.tag(mode, b)
			t.eq(int(rec["won"]), 1, "%s: 4.5 won" % tg)
			t.eq(int(rec["failed"]), 0, "%s: never fails" % tg)
			t.eq(int(rec["hits"]), 0, "%s: no hit taken" % tg)
			t.eq(rec["ids"], [&"c4-5-narr"], "%s: the story line never changes" % tg)


func _directions(t: TestRunner) -> void:
	var pair: Array = _make()
	var s: StageRhythm = pair[0]
	var seen: Dictionary = {}
	var run_len: int = 0
	var prev: int = -1
	var longest: int = 0
	for i in 400:
		var d: int = s._next_dir()
		seen[d] = true
		run_len = run_len + 1 if d == prev else 1
		prev = d
		longest = maxi(longest, run_len)
	t.eq(seen.size(), 4, "all four directions come up")
	t.truthy(longest <= 2, "never the same arrow three times in a row (%d)" % longest)
	# The same seed gives the same sequence.
	var a: StageRhythm = H.arrow_stage(RunModel.Mode.NORMAL, "", 99)[0]
	var b: StageRhythm = H.arrow_stage(RunModel.Mode.NORMAL, "", 99)[0]
	_made.append(a)
	_made.append(b)
	var same: bool = true
	for i in 30:
		if a._next_dir() != b._next_dir():
			same = false
	t.truthy(same, "a seed fixes the arrow order")


func _count_nodes(n: Node) -> int:
	var c: int = 1
	for ch in n.get_children():
		c += _count_nodes(ch)
	return c


func _bounded(t: TestRunner) -> void:
	var pair: Array = _make()
	var s: StageRhythm = pair[0]
	s.begin()
	var before: int = _count_nodes(s)
	H.play_arrows(s, 1.0)
	t.eq(_count_nodes(s), before, "no node is added while hits add dancers")
	t.truthy(before < 60, "the stage is a small tree (%d nodes)" % before)
	t.truthy(s.parade.dancers + s.parade.musicians <= ActorParade.FIGURE_HARD_CAP, "the parade has a hard figure cap")
	for i in ActorParade.FIGURE_HARD_CAP:
		var p: Vector2 = s.parade.spot(i)
		t.truthy(p.x > 0.0 and p.x < 1920.0 and p.y > 0.0 and p.y < 1080.0, "figure spot %d is on screen" % i)


## The arrows wait for the host line queue; nothing moves before the entry line was shown.
func _line_gate(t: TestRunner) -> void:
	var pair: Array = _make()
	var s: StageRhythm = pair[0]
	s.wait_for_lines = true
	s.begin()
	for i in 100:
		s.tick(H.STEP)
	t.near(s.elapsed, 0.0, "no time runs before the entry line was shown")
	t.eq(s.active_notes(), 0, "no arrow before the line was shown")
	t.falsy(s.press_arrow(&"up"), "no press counts before the line was shown")
	s.on_lines_drained()
	for i in 20:
		s.tick(H.STEP)
	t.truthy(s.elapsed > 1.9, "after the queue drained the stage runs")
	t.truthy(s.active_notes() > 0, "...and the first arrow flies")
	# Without the host flag nothing waits.
	var free_pair: Array = _make()
	var f: StageRhythm = free_pair[0]
	f.begin()
	f.tick(H.STEP)
	t.truthy(f.elapsed > 0.0, "no gate without the host flag")


func _through_host(t: TestRunner) -> void:
	RunState.start_chapter(4, RunModel.Mode.NORMAL)
	U.go_to(RunState, "4-5-ark")
	t.eq(U.cur(RunState), "4-5-ark", "the run reaches 4.5")
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.load_stage(RunState.current_stage)
	var s: StageRhythm = host._stage as StageRhythm
	t.truthy(s != null and s.arrows_enabled(), "the host builds the rhythm scene in arrow mode")
	var el: float = 0.0
	var offered: Array = []
	RunState.blessing_offered.connect(func(o: Array) -> void: offered.append(o))
	while el < 200.0 and not s.is_finished():
		host._process(0.1)
		s.tick(0.1)
		var d: int = s.arrow_in_window()
		if d >= 0:
			s.press_arrow(StageRhythm.ARROW_NAMES[d])
		el += 0.1
	t.truthy(s.is_finished(), "the stage won through the host")
	t.truthy(el > 61.0, "the host held the arrows until the narrator line was shown (%.1f s)" % el)
	t.truthy(s.hits > 10, "the bot hit the arrows (%d)" % s.hits)
	for i in 100:
		host._process(0.1)
	t.eq(offered.size(), 1, "the Blessing cards follow 4.5 once the lines are shown")
	t.truthy(RunState.awaiting_blessing, "...and the run waits for the pick")
	host.clear_stage()
	host.free()
	RunState.end_run()


func _ok_stages_unchanged(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var s: StageRhythm = StageRhythm.new()
		_made.append(s)
		var rec: Dictionary = U.build(s, _stage1("1-6-harp", 1, mode), mode)
		s.begin()
		t.falsy(s.arrows_enabled(), "1.6 stays on the single OK input")
		t.truthy(s.room != null and s.parade == null, "1.6 keeps the harp room")
		var el: float = 0.0
		var hit_total: int = 0
		while el < 100.0 and not s.is_finished():
			s.tick(U.STEP)
			el += U.STEP
			if s.note_in_window():
				if mode == RunModel.Mode.LAMB:
					s.on_action_tap()
				else:
					s.on_action_press()
					s.on_action_tap()
				hit_total += 1
			s.press_arrow(&"up")
		t.eq(int(rec["won"]), 1, "%s: 1.6 still wins" % RunModel.mode_key(mode))
		t.truthy(s.hits > 10 and s.hits == hit_total, "%s: OK hits land on press (%d)" % [RunModel.mode_key(mode), s.hits])
		t.eq(s.dancers + s.musicians, 0, "%s: OK stages never add dancers" % RunModel.mode_key(mode))
	var sp: StageRhythm = StageRhythm.new()
	_made.append(sp)
	var rec2: Dictionary = U.build(sp, U.stage_def("3-2-spear", RunModel.Mode.NORMAL), RunModel.Mode.NORMAL)
	sp.begin()
	t.falsy(sp.arrows_enabled(), "3.2 is not in arrow mode")
	t.truthy(sp.spears_enabled(), "3.2 still throws spears")
	sp.step_lane(1)
	t.eq(sp.lane, 1, "3.2 left/right still steps the lane")
	t.falsy(sp.press_arrow(&"left"), "press_arrow is a no-op outside 4.5")
	t.eq(int(rec2["won"]), 0, "(3.2 is still running)")


func _stage1(stage_id: String, chapter: int, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(chapter, mode):
		if d.id == StringName(stage_id):
			return d
	return null
