extends RefCounted
## Chapter 2 flow: unlock, start, restart, Blessing offers, failure rules by mode, completion.

const U := preload("res://tests/ch2-util.gd")


func run(t: TestRunner) -> void:
	_data(t)
	_start_and_restart(t)
	_blessing_offers(t)
	_failures(t)
	_completion(t)
	_cards(t)


func _data(t: TestRunner) -> void:
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch2.json")
	var stages: Array[StageDef] = StageDef.load_chapter(2, RunModel.Mode.NORMAL)
	t.eq(stages.size(), (ch["stages"] as Array).size(), "every Chapter 2 stage is defined")
	var types: Dictionary = {}
	for d in stages:
		types[String(d.id)] = String(d.type)
	t.eq(types["2-2-road"], "delivery", "2.2 is a delivery stage")
	t.eq(types["2-5-brook"], "stealth", "2.5 is a stealth stage")
	t.eq(types["2-6-goliath"], "boss", "2.6 is a boss stage (variant weak-point)")
	t.eq(StageHost._scene_key(U.stage_def("2-6-goliath", RunModel.Mode.NORMAL)), "goliath", "the weak-point boss uses its own scene")
	t.eq(StageHost._scene_key(_lion()), "boss", "Chapter 1 bosses keep the boss scene")
	for key in ["delivery", "stealth", "goliath", "boss", "cutscene"]:
		t.truthy(ResourceLoader.exists("res://stage-scenes/stage-%s.tscn" % key), "scene for %s exists" % key)


func _lion() -> StageDef:
	for d in StageDef.load_chapter(1, RunModel.Mode.NORMAL):
		if d.id == &"1-3-lion":
			return d
	return null


func _start_and_restart(t: TestRunner) -> void:
	for mode in U.modes():
		var rs: Node = U.new_run_state()
		var key: String = RunModel.mode_key(mode)
		rs.call("start_chapter", 2, mode)
		t.eq(U.cur(rs), "2-1-errand", "%s: Chapter 2 starts at 2-1-errand" % key)
		t.eq((rs.get("model") as RunModel).chapter, 2, "%s: chapter 2" % key)
		U.go_to(rs, "2-2-road")
		rs.call("advance")
		if rs.get("awaiting_blessing"):
			rs.call("add_blessing", &"quick-feet")
		rs.call("restart_chapter")
		t.eq(U.cur(rs), "2-2-road", "%s: restart_chapter lands on 2-2-road (the opening is not replayed)" % key)
		t.eq((rs.get("model") as RunModel).blessings.size(), 0, "%s: Blessings reset on a chapter restart" % key)
		rs.free()


func _offer_ids(rs: Node) -> Array:
	var ids: Array = []
	for c in rs.call("offer_blessings"):
		ids.append(str((c as Dictionary)["id"]))
	return ids


func _blessing_offers(t: TestRunner) -> void:
	var pool: Array = U.blessings().slice(1)
	for mode in U.modes():
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 2, mode)
		U.go_to(rs, "2-2-road")
		t.truthy((rs.get("current_stage") as StageDef).blessing_after, "%s: 2.2 offers Blessings" % RunModel.mode_key(mode))
		var offered: Array = _offer_ids(rs)
		t.eq(offered.size(), 3, "%s: three cards offered" % RunModel.mode_key(mode))
		for id in offered:
			t.truthy(pool.has(id), "%s: offered card %s is in the Chapter 2 pool" % [RunModel.mode_key(mode), id])
		t.falsy(offered.has("shepherds-staff"), "Chapter 1 and 3 only cards are never offered")
		rs.free()
	var rs2: Node = U.new_run_state()
	rs2.call("start_chapter", 2, RunModel.Mode.NORMAL)
	U.go_to(rs2, "2-6-goliath")
	t.falsy((rs2.get("current_stage") as StageDef).blessing_after, "Goliath offers no Blessings (they reset at the chapter's end)")
	rs2.free()


func _failures(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 2, RunModel.Mode.NORMAL)
	U.go_to(rs, "2-2-road")
	t.eq(rs.call("fail_stage", &"timeout"), &"restart-stage", "Normal: timeout restarts the road")
	t.eq(U.cur(rs), "2-2-road", "...at 2-2-road")
	t.eq(rs.call("fail_stage", &"loaves-zero"), &"restart-chapter", "Normal: no loaves restarts the chapter")
	t.eq(U.cur(rs), "2-2-road", "...which restarts at 2-2-road")
	rs.free()
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var r2: Node = U.new_run_state()
		r2.call("start_chapter", 2, mode)
		U.go_to(r2, "2-2-road")
		t.eq(r2.call("fail_stage", &"timeout"), &"ignored", "%s: timeout ignored" % RunModel.mode_key(mode))
		t.eq(r2.call("fail_stage", &"loaves-zero"), &"ignored", "%s: loaves-zero ignored" % RunModel.mode_key(mode))
		r2.free()


func _completion(t: TestRunner) -> void:
	for mode in U.modes():
		var rs: Node = U.new_run_state()
		var done: Array = []
		rs.connect("chapter_completed", func(n: int) -> void: done.append(n))
		rs.call("start_chapter", 2, mode)
		var seen: Array = []
		var guard: int = 0
		while done.is_empty() and guard < 30:
			seen.append(U.cur(rs))
			rs.call("advance")
			if rs.get("awaiting_blessing"):
				rs.call("skip_blessing")
			guard += 1
		t.eq(seen, ["2-1-errand", "2-2-road", "2-3-challenge", "2-4-saul", "2-5-brook", "2-6-goliath", "2-7-victory"], "%s: Chapter 2 stage order" % RunModel.mode_key(mode))
		t.eq(done, [2], "%s: finishing 2.7 completes Chapter 2" % RunModel.mode_key(mode))
		rs.free()


func _cards(t: TestRunner) -> void:
	var before: int = SaveData.model.chapters_unlocked
	SaveData.model.chapters_unlocked = 1
	var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs)
	var cards: Array = cs.get("_cards")
	t.truthy((cards[1] as Button).disabled, "card 2 is locked until Chapter 1 is complete")
	cs.free()
	SaveData.model.chapters_unlocked = 2
	var cs2: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs2)
	var cards2: Array = cs2.get("_cards")
	t.falsy((cards2[1] as Button).disabled, "card 2 unlocks when Chapter 1 is complete and its data exists")
	t.truthy((cards2[2] as Button).disabled, "card 3 stays locked")
	cs2.free()
	SaveData.model.chapters_unlocked = before
