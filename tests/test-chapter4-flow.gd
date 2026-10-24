extends RefCounted
## Chapter 4 run flow: start and restart stages, Blessings per chapter, the Sword carried from Chapter 3,
## no Blessing after the last playable stage, the chapter select card, and the host's scene mapping.

const H := preload("res://tests/ch4-host-util.gd")
const U := preload("res://tests/ch3-camp-util.gd")

const ORDER: Array[String] = ["4-1-sad-news", "4-2-hebron", "4-3-jerusalem", "4-4-rephaim", "4-5-ark", "4-6-promise", "4-7-lo-debar", "4-8-ending"]


func run(t: TestRunner) -> void:
	_start_and_order(t)
	_restart(t)
	_blessings(t)
	_sword(t)
	_last_playable_stage(t)
	_scene_mapping(t)
	_chapter_select(t)
	_unlock_flow(t)
	_host_music(t)
	RunState.end_run()


func _start_and_order(t: TestRunner) -> void:
	for mode in H.MODES:
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 4, mode)
		var k: String = RunModel.mode_key(mode)
		t.eq(U.cur(rs), "4-1-sad-news", "%s: Chapter 4 starts at 4.1" % k)
		var seen: Array[String] = [U.cur(rs)]
		var done: Array = []
		rs.connect("chapter_completed", func(c: int) -> void: done.append(c))
		var guard: int = 0
		while done.is_empty() and guard < 40:
			rs.call("advance")
			if rs.get("awaiting_blessing"):
				rs.call("skip_blessing")
			if done.is_empty() and U.cur(rs) != seen.back():
				seen.append(U.cur(rs))
			guard += 1
		t.eq(seen, ORDER, "%s: the stages follow the script order" % k)
		t.eq(done, [4], "%s: finishing 4.8 completes Chapter 4 once" % k)
		rs.free()


func _restart(t: TestRunner) -> void:
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.HARD]:
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 4, mode)
		U.go_to(rs, "4-5-ark")
		rs.call("restart_chapter")
		t.eq(U.cur(rs), "4-3-jerusalem", "%s: a chapter restart lands on 4.3, not the cutscenes" % RunModel.mode_key(mode))
		t.eq((rs.get("model") as RunModel).blessings.size(), 0, "...with no Blessings")
		rs.free()
	var d: Dictionary = BalanceData.read_json("res://data/chapters/ch4.json")
	t.eq(str(d["restartStage"]), "4-3-jerusalem", "the data names 4.3 as the restart stage")
	# 4.5 cannot fail, so it has no restart of its own.
	var s: StageRhythm = H.arrow_stage(RunModel.Mode.NORMAL)[0]
	t.eq(s.def.on_lose.size(), 0, "4.5 has no onLose")
	s.free()


func _blessings(t: TestRunner) -> void:
	var pool: Array = BalanceData.read_json("res://data/chapters/ch4.json")["blessingPool"]
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	U.go_to(rs, "4-5-ark")
	for card in rs.call("available_blessings"):
		var id: String = str((card as Dictionary)["id"])
		t.truthy(pool.has(id), "%s is in the Chapter 4 pool" % id)
		var in_four: bool = false
		for ch in ((card as Dictionary)["chapters"] as Array):
			in_four = in_four or int(ch) == 4
		t.truthy(in_four, "%s is a Chapter 4 card" % id)
	t.falsy(_ids(rs.call("available_blessings")).has("shepherds-staff"), "a Chapter 1 and 3 card is not offered")
	t.falsy(_ids(rs.call("available_blessings")).has("gift-of-abigail"), "...nor a Chapter 3 card")
	t.falsy(_ids(rs.call("available_blessings")).has("goliaths-sword"), "the Sword card needs the unlock")
	# 4.5 offers cards, picks last until the chapter ends and reset on a new chapter.
	rs.call("advance")
	t.truthy(rs.get("awaiting_blessing"), "cards are offered after 4.5")
	var first: StringName = &"quick-feet"
	rs.call("add_blessing", first)
	t.eq((rs.get("model") as RunModel).blessings, [first], "the pick is kept")
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	t.eq((rs.get("model") as RunModel).blessings.size(), 0, "a new chapter attempt starts without Blessings")
	rs.free()


func _ids(cards: Array) -> Array:
	var out: Array = []
	for c in cards:
		out.append(str((c as Dictionary)["id"]) if c is Dictionary else str(c))
	return out


func _sword(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs, "3-5-day-1")
	var model: RunModel = rs.get("model")
	t.truthy(model.sword_unlocked, "clearing 3.4 unlocks Goliath's Sword")
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	t.truthy(model.sword_unlocked, "the Sword carries from Chapter 3 into Chapter 4")
	U.go_to(rs, "4-5-ark")
	t.truthy(_ids(rs.call("available_blessings")).has("goliaths-sword"), "...and its card can be offered in Chapter 4")
	rs.call("restart_chapter")
	t.truthy(model.sword_unlocked, "a Chapter 4 restart keeps the Sword")
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	t.falsy(model.sword_unlocked, "starting another chapter drops it")
	rs.call("start_chapter", 4, RunModel.Mode.NORMAL)
	t.falsy(model.sword_unlocked, "Chapter 4 without Chapter 3 first has no Sword")
	t.falsy(_ids(rs.call("available_blessings")).has("goliaths-sword"), "...and no Sword card")
	model.sword_unlocked = true
	rs.call("end_run")
	t.falsy(model.sword_unlocked, "the end of the run clears the Sword")
	rs.free()


func _last_playable_stage(t: TestRunner) -> void:
	var defs: Array[StageDef] = StageDef.load_chapter(4, RunModel.Mode.NORMAL)
	var by_id: Dictionary = {}
	for d in defs:
		by_id[String(d.id)] = d
	for id in ["4-1-sad-news", "4-2-hebron", "4-6-promise", "4-7-lo-debar", "4-8-ending"]:
		t.falsy((by_id[id] as StageDef).blessing_after, "%s offers no Blessing" % id)
	for id in ["4-3-jerusalem", "4-4-rephaim", "4-5-ark"]:
		t.truthy((by_id[id] as StageDef).blessing_after, "%s offers a Blessing" % id)
	t.eq((by_id["4-8-ending"] as StageDef).next_id, &"", "4.8 ends the chapter")
	for mode in H.MODES:
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 4, mode)
		U.go_to(rs, "4-7-lo-debar")
		var offered: Array = []
		rs.connect("blessing_offered", func(o: Array) -> void: offered.append(o))
		rs.call("advance")
		t.eq(offered.size(), 0, "%s: no cards after the last playable stage" % RunModel.mode_key(mode))
		t.eq(U.cur(rs), "4-8-ending", "%s: 4.7 goes straight to the ending" % RunModel.mode_key(mode))
		rs.free()


func _scene_mapping(t: TestRunner) -> void:
	var cases: Dictionary = {
		"maze": "maze", "patience": "patience", "search": "search", "rhythm": "rhythm", "cutscene": "cutscene",
		"stealth": "stealth", "delivery": "delivery", "survival-camp": "survival-camp", "protect-flock": "protect-flock",
	}
	for type_id in cases:
		var def: StageDef = StageDef.from_dict({"id": "x", "type": type_id, "params": {}})
		t.eq(StageHost.scene_path(def), "res://stage-scenes/stage-%s.tscn" % cases[type_id], "type %s maps to stage-%s.tscn" % [type_id, cases[type_id]])
	var goliath: StageDef = StageDef.from_dict({"id": "x", "type": "boss", "params": {"variant": "weak-point"}})
	t.eq(StageHost.scene_path(goliath), "res://stage-scenes/stage-goliath.tscn", "the Goliath boss keeps its own scene")
	var ziklag: StageDef = StageDef.from_dict({"id": "x", "type": "boss", "params": {"variant": "rescue"}})
	t.eq(StageHost.scene_path(ziklag), "res://stage-scenes/stage-ziklag.tscn", "the Ziklag boss keeps its own scene")
	# Every Chapter 4 stage type has a scene mapped from its data.
	for d in StageDef.load_chapter(4, RunModel.Mode.NORMAL):
		t.truthy(StageHost.scene_path(d).begins_with("res://stage-scenes/stage-"), "%s has a scene path" % d.id)


func _chapter_select(t: TestRunner) -> void:
	var before: int = SaveData.model.chapters_unlocked
	for unlocked in [3, 4]:
		SaveData.model.chapters_unlocked = unlocked
		var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
		t.root.add_child(cs)
		var cards: Array = cs.get("_cards")
		var card: Button = cards[3] as Button
		if unlocked == 3:
			t.truthy(card.disabled and card.focus_mode == Control.FOCUS_NONE, "card 4 is locked while Chapter 3 is not complete")
		else:
			t.falsy(card.disabled, "card 4 opens once Chapter 3 is complete and its data exists")
			t.truthy(card.text.contains("The King"), "...and it shows the chapter title from data")
			var chosen: Array = []
			cs.connect("chapter_chosen", func(n: int) -> void: chosen.append(n))
			card.pressed.emit()
			t.eq(chosen, [4], "choosing card 4 starts Chapter 4")
		cs.free()
	SaveData.model.chapters_unlocked = before


func _unlock_flow(t: TestRunner) -> void:
	var old_path: String = SaveData.save_path
	var old_model: SaveModel = SaveData.model
	var tmp: String = "user://test-ch4-flow-save.json"
	SaveData.save_path = tmp
	SaveData.model = SaveModel.new()
	t.falsy(SaveData.is_unlocked(4), "Chapter 4 starts locked")
	SaveData.unlock_after(1)
	SaveData.unlock_after(2)
	t.falsy(SaveData.is_unlocked(4), "...and stays locked after Chapter 2")
	SaveData.unlock_after(3)
	t.truthy(SaveData.is_unlocked(4), "completing Chapter 3 unlocks Chapter 4")
	SaveData.unlock_after(4)
	t.eq(SaveData.model.chapters_unlocked, 4, "completing Chapter 4 unlocks nothing further")
	var m: SaveModel = SaveModel.from_dict({"chapters_unlocked": 9})
	t.eq(m.chapters_unlocked, 4, "a save can never unlock a fifth chapter")
	SaveData.model = old_model
	SaveData.save_path = old_path
	if FileAccess.file_exists(tmp):
		DirAccess.remove_absolute(tmp)
	# start_chapter(4, mode) begins at 4.1 in every mode through the real autoload too.
	for mode in H.MODES:
		RunState.start_chapter(4, mode)
		t.eq(U.cur(RunState), "4-1-sad-news", "%s: start_chapter(4) begins at 4-1-sad-news" % RunModel.mode_key(mode))
		t.eq(RunState.model.chapter, 4, "...in Chapter 4")


func _host_music(t: TestRunner) -> void:
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host._on_music(&"slow-harp-song")
	t.eq(Audio.current_music, &"slow-harp-song", "the host plays the quiet moment's cue")
	host._on_music(&"")
	t.eq(Audio.current_music, Audio.MUSIC_MAIN, "an empty cue puts the main music back")
	host.free()
