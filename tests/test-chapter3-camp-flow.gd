extends RefCounted
## Chapter 3 flow around the camp: 400 men by the end of day 3, restarts that hand back the day's
## starting men, the chapter's start and restart stages, and the camp through the real host.

const U := preload("res://tests/ch3-camp-util.gd")

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_three_days(t)
	_restarts(t)
	_chapter_flow(t)
	_through_host(t)
	for n in _made:
		n.free()
	RunState.end_run()
	RunState.set_followers(0)


## Plays the three days with a bot that only welcomes the groups (David stays in the shelter).
func _three_days(t: TestRunner) -> void:
	for mode in U.modes():
		var rm: RunModel = RunModel.new()
		var last: Dictionary = {}
		for day in [1, 2, 3]:
			var s: StageSurvivalCamp = StageSurvivalCamp.new()
			_made.append(s)
			last = U.build(s, U.stage_def("3-5-day-%d" % day, mode), mode, "", rm)
			s.begin()
			var el: float = 0.0
			while el < 200.0 and not s.is_finished():
				s.tick(U.STEP)
				s.on_action_tap()
				el += U.STEP
			t.eq(int(last["won"]), 1, "%s: day %d is won" % [RunModel.mode_key(mode), day])
		t.truthy(rm.followers >= 400, "%s: 400 men by the end of day 3 (%d)" % [RunModel.mode_key(mode), rm.followers])


func _restarts(t: TestRunner) -> void:
	var rs: Node = U.new_run_state()
	rs.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs, "3-5-day-2")
	rs.call("set_followers", 250)
	rs.call("advance")
	if rs.get("awaiting_blessing"):
		rs.call("skip_blessing")
	t.eq(U.cur(rs), "3-5-day-3", "day 3 follows day 2")
	var model: RunModel = rs.get("model")
	rs.call("add_followers", 100)
	t.eq(rs.call("fail_stage", &"men-below-goal-at-end"), &"restart-stage", "Normal: too few men replays day 3")
	t.eq(U.cur(rs), "3-5-day-3", "...day 3 again")
	t.eq(model.followers, 250, "...with the men the day began with")
	rs.call("add_followers", 40)
	rs.call("restart_stage")
	t.eq(model.followers, 250, "a pause-menu restart also hands the men back")
	rs.free()
	for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB]:
		var rs2: Node = U.new_run_state()
		rs2.call("start_chapter", 3, mode)
		U.go_to(rs2, "3-5-day-3")
		t.eq(rs2.call("fail_stage", &"men-below-goal-at-end"), &"ignored", "%s: the camp never fails" % RunModel.mode_key(mode))
		rs2.free()
	# Scripted food survives a replay of the stage that takes it.
	var rs3: Node = U.new_run_state()
	rs3.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs3, "3-7-abigail")
	rs3.call("grant_food", 3)
	rs3.call("advance")
	if rs3.get("awaiting_blessing"):
		rs3.call("skip_blessing")
	t.eq(U.cur(rs3), "3-8-camp", "Abigail leads to the camp")
	var m3: RunModel = rs3.get("model")
	t.eq(m3.next_stage_food, 3, "the camp is entered with the food")
	m3.next_stage_food = 0
	rs3.call("restart_stage")
	t.eq(m3.next_stage_food, 3, "a restart of the stage gets the scripted food back")
	rs3.call("restart_chapter")
	t.eq(m3.next_stage_food, 0, "a chapter restart clears it")
	rs3.free()


func _chapter_flow(t: TestRunner) -> void:
	var zik: StageDef = U.stage_def("3-9-ziklag", RunModel.Mode.NORMAL)
	t.eq(StageHost._scene_key(zik), "ziklag", "the rescue boss uses the Ziklag scene")
	t.truthy(ResourceLoader.exists("res://stage-scenes/stage-ziklag.tscn"), "the Ziklag scene exists")
	t.eq(StageHost._scene_key(U.stage_def("3-5-day-1", RunModel.Mode.NORMAL)), "survival-camp", "the camp keeps its own scene")
	var ch: Dictionary = BalanceData.read_json("res://data/chapters/ch3.json")
	t.eq(ch.get("restartStage"), "3-2-spear", "chapter 3 restarts at 3-2-spear")
	for mode in U.modes():
		var rs: Node = U.new_run_state()
		rs.call("start_chapter", 3, mode)
		t.eq(U.cur(rs), "3-1-song", "%s: chapter 3 starts at 3-1-song" % RunModel.mode_key(mode))
		rs.call("restart_chapter")
		t.eq(U.cur(rs), "3-2-spear", "%s: restart_chapter lands on 3-2-spear" % RunModel.mode_key(mode))
		rs.free()
	var rs4: Node = U.new_run_state()
	rs4.call("start_chapter", 3, RunModel.Mode.NORMAL)
	U.go_to(rs4, "3-2-spear")
	t.eq(rs4.call("fail_stage", &"spear-hits"), &"restart-stage", "Normal: three spear hits replay 3.2")
	t.eq(U.cur(rs4), "3-2-spear", "...3.2 again")
	t.eq(rs4.call("fail_stage", &"spear-hits"), &"restart-stage", "...and again")
	rs4.free()
	# The chapter card unlocks from the save, with data present.
	var before: int = SaveData.model.chapters_unlocked
	SaveData.model.chapters_unlocked = 3
	var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(cs)
	var cards: Array = cs.get("_cards")
	t.falsy((cards[2] as Button).disabled, "the chapter 3 card is open once chapter 2 is complete")
	cs.free()
	SaveData.model.chapters_unlocked = 2
	var cs2: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	(Engine.get_main_loop() as SceneTree).root.add_child(cs2)
	t.truthy(((cs2.get("_cards") as Array)[2] as Button).disabled, "the chapter 3 card is locked before that")
	cs2.free()
	SaveData.model.chapters_unlocked = before


func _through_host(t: TestRunner) -> void:
	RunState.start_chapter(3, RunModel.Mode.NORMAL)
	U.go_to(RunState, "3-5-day-1")
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	host.load_stage(RunState.current_stage)
	var s: StageSurvivalCamp = host._stage as StageSurvivalCamp
	t.truthy(s != null, "the host builds the camp from its scene")
	var el: float = 0.0
	while el < 200.0 and not s.is_finished():
		host._process(0.1)
		s.tick(0.1)
		s.on_action_tap()
		el += 0.1
	t.eq(RunState.model.followers, 135, "arrivals reach RunState.followers through the host")
	host.clear_stage()
	host.free()
	Engine.time_scale = 1.0
