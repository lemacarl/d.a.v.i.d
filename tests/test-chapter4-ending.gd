extends RefCounted
## Chapter 4 cutscenes (4.1 quiet moment, 4.2, 4.6 gold light, 4.8 final shot and end card) and the
## game-complete flow: the end card, then the title; nothing unlocks after Chapter 4.

const H := preload("res://tests/ch4-host-util.gd")
const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_quiet_moment(t)
	_cutscene_lines(t)
	_gold_light_and_caption(t)
	_final_shot(t)
	_line_gating(t)
	_outcomes(t)
	_game_complete(t)
	_nothing_after_four(t)
	for n in _made:
		n.free()
	RunState.end_run()
	Engine.time_scale = 1.0


func _make(stage_id: String, mode: RunModel.Mode = RunModel.Mode.NORMAL, blessing: String = "") -> Array:
	var s: StageCutscene = StageCutscene.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, H.stage_def(stage_id, mode), mode, blessing)
	return [s, rec]


func _text(id: String) -> String:
	return str(LineBook.line(StringName(id)).get("text", ""))


func _quiet_moment(t: TestRunner) -> void:
	for mode in H.MODES:
		var pair: Array = _make("4-1-sad-news", mode)
		var s: StageCutscene = pair[0]
		var rec: Dictionary = pair[1]
		var music: Array = []
		s.music_requested.connect(func(c: StringName) -> void: music.append(c))
		s.begin()
		var el: float = 0.0
		while el < 60.0 and not s.quiet_active():
			s.tick(H.STEP)
			el += H.STEP
			if s.waiting == StageCutscene.Wait.LINE:
				s.on_action_tap()
		var k: String = RunModel.mode_key(mode)
		t.truthy(s.quiet_active(), "%s: 4.1 reaches the quiet moment after its lines" % k)
		t.eq(rec["ids"], [&"c4-1-narr", &"c4-1-david-1", &"c4-1-david-2"], "%s: the three lines came first, in order" % k)
		t.eq(music, [&"slow-harp-song"], "%s: the slow harp song is requested" % k)
		var quiet: float = 0.0
		var beat: int = s.beat_index
		while s.quiet_active() and quiet < 40.0:
			s.tick(H.STEP)
			quiet += H.STEP
			# No input skips it: OK, the hold and the D-pad do nothing.
			s.on_action_tap()
			s.on_action_press()
			s.on_action_hold()
			s.input_dir = Vector2.RIGHT
		t.truthy(absf(quiet - 20.0) < 0.35, "%s: the quiet moment lasts 20 s (%.1f)" % [k, quiet])
		t.eq(s.beat_index, beat + 1, "%s: OK and the D-pad never skipped it, the next beat is the one after" % k)
		t.eq(music, [&"slow-harp-song", &""], "%s: the main music is asked back when it ends" % k)
		H.play_cutscene(s)
		t.eq(int(rec["won"]), 1, "%s: 4.1 is won once" % k)
		t.eq(int(rec["failed"]), 0, "%s: 4.1 cannot fail" % k)
		t.eq(int(rec["hits"]), 0, "%s: no hearts lost" % k)
		t.falsy(s.david.visible, "%s: David stays hidden in the quiet moment" % k)
	# The data says 20 seconds and the slow harp.
	var beats: Array = H.stage_def("4-1-sad-news", RunModel.Mode.NORMAL).cutscene_beats()
	var found: bool = false
	for b in beats:
		if str((b as Dictionary).get("type", "")) == "quiet-moment":
			found = true
			t.eq(float((b as Dictionary)["seconds"]), 20.0, "the data quiet moment is 20 seconds")
			t.eq(str((b as Dictionary)["music"]), "slow-harp-song", "...with the slow harp song")
	t.truthy(found, "4.1 has a quiet-moment beat")
	t.truthy(Audio.cue_ids().has("slow-harp-song"), "audio data names the slow harp cue")


func _cutscene_lines(t: TestRunner) -> void:
	var expect: Dictionary = {
		"4-2-hebron": [&"c4-2-narr-1", &"c4-2-narr-2", &"c4-2-elders"],
		"4-6-promise": [&"c4-6-david-1", &"c4-6-nathan", &"c4-6-david-2"],
		"4-8-ending": [&"c4-8-narr-1", &"c4-8-narr-2", &"c4-8-narr-3", &"c4-8-caption", &"c4-8-card-end"],
	}
	for id in expect:
		for mode in H.MODES:
			var pair: Array = _make(id, mode)
			var s: StageCutscene = pair[0]
			var rec: Dictionary = pair[1]
			s.begin()
			H.play_cutscene(s)
			var k: String = "%s/%s" % [id, RunModel.mode_key(mode)]
			t.eq(int(rec["won"]), 1, "%s: won once" % k)
			t.eq(int(rec["failed"]), 0, "%s: no failure" % k)
			var ids: Array = (rec["ids"] as Array).filter(func(x: StringName) -> bool: return x != &"")
			t.eq(ids, expect[id], "%s: every spoken line, in script order" % k)


func _gold_light_and_caption(t: TestRunner) -> void:
	# 4.6: God's words in gold light, on their own beat between David and David.
	var pair: Array = _make("4-6-promise")
	var s: StageCutscene = pair[0]
	var gold: Array = []
	var order: Array = []
	s.gold_light_requested.connect(func(tx: String, r: String, sec: float) -> void:
		gold.append([tx, r, sec])
		order.append("gold"))
	s.line_requested.connect(func(_sp: StringName, _tx: String, _r: String, id: StringName) -> void: order.append(str(id)))
	s.begin()
	H.play_cutscene(s)
	t.eq(gold.size(), 1, "4.6 has one gold light")
	var line: Dictionary = LineBook.line(&"c4-6-lord")
	t.eq(gold[0][0], str(line["text"]), "the gold light carries the promise verbatim")
	t.eq(gold[0][1], str(line["reference"]), "...with 2 Samuel 7:16")
	t.eq(gold[0][2], 4.0, "...for the data seconds")
	t.eq(order, ["c4-6-david-1", "c4-6-nathan", "gold", "c4-6-david-2"], "the gold light sits between Nathan and David's answer")
	# 4.8: the Luke caption rides with the third narrator line through the host queue.
	var p8: Array = _make("4-8-ending")
	var s8: StageCutscene = p8[0]
	var q: LineQueue = LineQueue.new()
	var captions: Array = []
	q.caption_started.connect(func(tx: String, r: String, _h: float) -> void: captions.append([tx, r]))
	s8.line_requested.connect(func(sp: StringName, tx: String, r: String, id: StringName) -> void: q.request(sp, tx, r, id))
	s8.begin()
	H.play_cutscene(s8)
	var el: float = 0.0
	while not q.is_idle() and el < 120.0:
		q.tick(H.STEP)
		el += H.STEP
	var cap: Dictionary = LineBook.line(&"c4-8-caption")
	t.eq(captions.size(), 1, "one Luke caption is shown")
	if captions.size() == 1:
		t.eq(captions[0][0], str(cap["text"]), "the caption text is the script's")
		t.eq(captions[0][1], str(cap["reference"]), "...with Luke 1:32-33")


func _final_shot(t: TestRunner) -> void:
	var pair: Array = _make("4-8-ending")
	var s: StageCutscene = pair[0]
	var cues: Array = []
	s.visual_requested.connect(func(c: StringName) -> void: cues.append(c))
	s.begin()
	var at_card: bool = false
	var el: float = 0.0
	var shot_seen: bool = false
	while el < 300.0 and not s.is_finished():
		s.tick(H.STEP)
		el += H.STEP
		if s.waiting == StageCutscene.Wait.LINE:
			if cues.has(&"bethlehem-night-star"):
				shot_seen = shot_seen or (s._scene != null and s._scene is ActorArkNightHills)
			s.on_action_tap()
	t.eq(cues, [&"bethlehem-night-star"], "the final shot is the Bethlehem night cue")
	t.truthy(shot_seen, "the night hills scene (sheep and a star) is drawn for it")
	t.truthy(s._scene is ActorArkNightHills, "...and stays behind the end card")
	t.truthy(s._scene.get_child_count() == 0, "the scene is drawn, not built from nodes")
	t.eq(pair[1]["ids"].back(), &"c4-8-card-end", "the end card is the last line")
	# The shot comes before the end card in the data.
	var beats: Array = H.stage_def("4-8-ending", RunModel.Mode.NORMAL).cutscene_beats()
	var vi: int = -1
	var ei: int = -1
	for i in beats.size():
		var ty: String = str((beats[i] as Dictionary).get("type", ""))
		if ty == "visual":
			vi = i
		elif ty == "end-card":
			ei = i
	t.truthy(vi >= 0 and ei == beats.size() - 1 and vi < ei, "the data ends with the visual, then the end card")
	t.eq(_text("c4-8-card-end"), LineBook.line(&"c4-8-card-end")["text"], "the end card line exists")
	# The cutscene draws the scene even for a cue it does not know (flat backdrop).
	t.eq(s._scene_kind_of("no-such-cue"), &"", "an unknown cue has no scene")
	t.eq(s._scene_kind_of("bethlehem-night-star"), &"night-hills", "the night cue maps to the night hills")


## Nothing advances before the lines were shown: the host queue gates the win (as in every chapter).
func _line_gating(t: TestRunner) -> void:
	for id in ["4-1-sad-news", "4-6-promise", "4-8-ending"]:
		var pair: Array = _make(id)
		var s: StageCutscene = pair[0]
		var q: LineQueue = LineQueue.new()
		var shown: Array = []
		var advanced: Array = [0]
		q.line_started.connect(func(_sp: StringName, tx: String, _r: String, _h: float, _st: bool) -> void: shown.append(tx))
		s.line_requested.connect(func(sp: StringName, tx: String, r: String, lid: StringName) -> void: q.request(sp, tx, r, lid))
		s.gold_light_requested.connect(q.request_gold)
		s.stage_won.connect(func() -> void: q.when_drained(func() -> void: advanced[0] = int(advanced[0]) + 1))
		s.begin()
		H.play_cutscene(s)
		t.eq(int(pair[1]["won"]), 1, "%s: won" % id)
		var queued: bool = not q.is_idle()
		var el: float = 0.0
		while advanced[0] == 0 and el < 120.0:
			q.tick(H.STEP)
			el += H.STEP
		t.eq(advanced[0], 1, "%s: the run advances exactly once, after the queue drained" % id)
		t.truthy(q.is_idle(), "%s: ...only when nothing was left to show" % id)
		if id == "4-8-ending":
			t.truthy(queued or shown.size() == 4, "4.8: the end card is not skipped")
			t.eq(shown.back(), _text("c4-8-card-end"), "4.8: the last thing on screen is the end card")
			t.eq(shown.size(), 4, "4.8: three narrator lines and the end card")


func _outcomes(t: TestRunner) -> void:
	var base: Dictionary = {}
	for id in ["4-1-sad-news", "4-2-hebron", "4-6-promise", "4-8-ending"]:
		var p: Array = _make(id)
		(p[0] as StageCutscene).begin()
		H.play_cutscene(p[0])
		base[id] = (p[1]["ids"] as Array).duplicate()
	for mode in H.MODES:
		for b in H.blessings():
			for id in base:
				var pair: Array = _make(id, mode, b)
				var s: StageCutscene = pair[0]
				s.begin()
				H.play_cutscene(s)
				var tg: String = "%s %s" % [id, H.tag(mode, b)]
				t.eq(int(pair[1]["won"]), 1, "%s: won" % tg)
				t.eq(int(pair[1]["failed"]), 0, "%s: never fails" % tg)
				t.eq(pair[1]["ids"], base[id], "%s: the same lines in the same order" % tg)
				t.eq(pair[1]["grants"], [], "%s: grants nothing" % tg)


func _game_complete(t: TestRunner) -> void:
	var tmp: String = "user://test-ch4-save.json"
	var old_path: String = SaveData.save_path
	var old_model: SaveModel = SaveData.model
	SaveData.save_path = tmp
	SaveData.model = SaveModel.new()
	SaveData.model.chapters_unlocked = 4
	RunState.start_chapter(4, RunModel.Mode.NORMAL)
	U.go_to(RunState, "4-8-ending")
	t.eq(U.cur(RunState), "4-8-ending", "the run reaches the ending")
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	t.root.add_child(main)
	RunState.advance()
	t.eq(main.get("_screen"), 5, "after 4.8 the summary screen is up")
	var summary: Control = main.get("_current") as Control
	t.truthy(bool(summary.get("game_complete")), "...as the game-complete card")
	var texts: PackedStringArray = PackedStringArray()
	_collect_text(summary, texts)
	t.truthy(texts.has(_text("c4-8-card-end")), "it shows the end card line")
	var joined: String = "\n".join(texts)
	t.falsy(joined.contains("Sheep saved"), "...and not a chapter stats line")
	var ok: Button = _first_button(summary)
	t.truthy(ok != null and ok.has_focus(), "OK is focused on the card")
	ok.pressed.emit()
	t.eq(main.get("_screen"), 1, "OK returns to the title")
	t.eq(RunState.current_stage, null, "the run is over")
	t.falsy(RunState.model.sword_unlocked, "...and nothing is carried out of it")
	t.eq(SaveData.model.chapters_unlocked, 4, "finishing Chapter 4 unlocks nothing more")
	# Back on the card also leaves for the title.
	RunState.chapter_completed.emit(4)
	t.eq(main.get("_screen"), 5, "the card again")
	main.set("_last_back_msec", -1000)
	main.call("_handle_back")
	t.eq(main.get("_screen"), 1, "Back on the end card also returns to the title")
	# An earlier chapter still goes back to the chapter select.
	RunState.chapter_completed.emit(3)
	var s3: Control = main.get("_current") as Control
	t.falsy(bool(s3.get("game_complete")), "Chapter 3's card is the normal summary")
	_first_button(s3).pressed.emit()
	t.eq(main.get("_screen"), 2, "Continue after Chapter 3 returns to the chapter select")
	main.free()
	RunState.end_run()
	SaveData.model = old_model
	SaveData.save_path = old_path
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)


func _collect_text(n: Node, out: PackedStringArray) -> void:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_collect_text(c, out)


func _first_button(n: Node) -> Button:
	if n is Button:
		return n as Button
	for c in n.get_children():
		var b: Button = _first_button(c)
		if b != null:
			return b
	return null


func _nothing_after_four(t: TestRunner) -> void:
	var m: SaveModel = SaveModel.new()
	m.chapters_unlocked = 3
	t.truthy(m.unlock_after(3, "normal", true), "completing Chapter 3 unlocks Chapter 4")
	t.eq(m.chapters_unlocked, 4, "...and nothing beyond")
	t.falsy(m.unlock_after(4, "normal", true), "completing Chapter 4 unlocks nothing")
	t.eq(m.chapters_unlocked, 4, "all four chapters stay unlocked")
	t.falsy(m.is_unlocked(5), "there is no Chapter 5")
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch4.json")
	t.eq(int((ch["unlock"] as Dictionary)["requires"]["chapterComplete"]), 3, "Chapter 4 requires Chapter 3")
	t.eq(str(ch["completeCard"]), "c4-8-card-end", "the Chapter 4 complete card is the end card")
