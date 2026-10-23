extends RefCounted
## Regression tests for the Milestone 1 test report fixes (D1, D3, D4, D6, D8, D10, D13).


func run(t: TestRunner) -> void:
	_lamb_offers_three(t)
	_seed_per_attempt(t)
	_lamb_harp(t)
	_gather_distance(t)
	_hud_counters(t)
	_pause_focus(t)
	_chapter_cards(t)


func _def(stage_id: String, mode: RunModel.Mode) -> StageDef:
	for d in StageDef.load_chapter(1, mode):
		if d.id == StringName(stage_id):
			return d
	return null


func _state() -> Node:
	return load("res://autoload/run-state.gd").new() as Node


func _lamb_offers_three(t: TestRunner) -> void:
	# D4: Lamb prefers mode-relevant cards, then fills up to three.
	for mode in [RunModel.Mode.LAMB, RunModel.Mode.SHEPHERD, RunModel.Mode.NORMAL]:
		var rs: Node = _state()
		rs.call("start_chapter", 1, mode)
		var offer: Array = rs.call("offer_blessings")
		t.eq(offer.size(), 3, "mode %s offers three Blessings" % RunModel.mode_key(mode))
		var ids: Dictionary = {}
		for c in offer:
			ids[(c as Dictionary)["id"]] = true
		t.eq(ids.size(), 3, "offered cards are distinct")
		if mode == RunModel.Mode.LAMB:
			for c in rs.call("available_blessings"):
				t.truthy(ids.has((c as Dictionary)["id"]), "Lamb offer includes every mode-relevant card first")
		rs.free()


func _seed_per_attempt(t: TestRunner) -> void:
	# D13: a new seed per attempt and restart, unless set_seed fixed it.
	var rs: Node = _state()
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	var a: int = (rs.get("model") as RunModel).rng_seed
	rs.call("restart_stage")
	var b: int = (rs.get("model") as RunModel).rng_seed
	rs.call("start_chapter", 1, RunModel.Mode.NORMAL)
	var c: int = (rs.get("model") as RunModel).rng_seed
	t.truthy(a != b and b != c and a != c, "seed changes on restart and on a new attempt")
	rs.free()
	var fixed: Node = _state()
	fixed.call("set_seed", 777)
	fixed.call("start_chapter", 1, RunModel.Mode.NORMAL)
	fixed.call("restart_stage")
	t.eq((fixed.get("model") as RunModel).rng_seed, 777, "set_seed keeps the seed fixed (tests)")
	fixed.free()


func _lamb_harp(t: TestRunner) -> void:
	# D6: in Lamb OK plays the harp in the field stages; no stone is thrown.
	var rm: RunModel = RunModel.new()
	rm.mode = RunModel.Mode.LAMB
	var night: StageProtectFlock = StageProtectFlock.new()
	night.setup(_def("1-2-night-1", RunModel.Mode.LAMB), rm, ModifierStack.new(RunModel.Mode.LAMB))
	var thrown: Array = [0]
	night.stone_thrown.connect(func() -> void: thrown[0] = int(thrown[0]) + 1)
	night.begin()
	night.on_action_tap()
	t.truthy(night.lamb_harp_mode(), "Lamb runs the harp tap in nights")
	t.eq(thrown[0], 0, "Lamb night: OK throws no stone")
	night.free()
	var boss: StageBoss = StageBoss.new()
	boss.setup(_def("1-3-lion", RunModel.Mode.LAMB), rm, ModifierStack.new(RunModel.Mode.LAMB))
	boss.stone_thrown.connect(func() -> void: thrown[0] = int(thrown[0]) + 1)
	boss.begin()
	boss.on_action_tap()
	t.eq(thrown[0], 0, "Lamb gather stage: OK throws no stone")
	boss.free()
	var nm: RunModel = RunModel.new()
	var normal: StageProtectFlock = StageProtectFlock.new()
	normal.setup(_def("1-2-night-1", RunModel.Mode.NORMAL), nm, ModifierStack.new(RunModel.Mode.NORMAL))
	t.falsy(normal.lamb_harp_mode(), "Normal does not use the harp tap")
	normal.free()


func _gather_distance(t: TestRunner) -> void:
	# D8: Lamb gather lambs spawn at least 300 px from David.
	var rm: RunModel = RunModel.new()
	rm.mode = RunModel.Mode.LAMB
	var worst: float = INF
	for seed_value in 60:
		rm.rng_seed = seed_value + 1
		var boss: StageBoss = StageBoss.new()
		boss.setup(_def("1-3-lion", RunModel.Mode.LAMB), rm, ModifierStack.new(RunModel.Mode.LAMB))
		for l in boss.lambs:
			worst = minf(worst, l.position.distance_to(boss.david.position))
		boss.free()
	t.truthy(worst >= BalanceData.feel("minLambDistance"), "gather lambs spawn >= 300 px from David (min %s)" % worst)


func _hud_counters(t: TestRunner) -> void:
	# D10: Chapter 1 shows neither the stones nor the followers counter.
	var hud: Hud = Hud.new()
	hud._ready()
	var boxes: Array = []
	for c in hud.get_children():
		if c is HBoxContainer and c != hud._hearts_row:
			boxes.append(c)
	t.eq(boxes.size(), 5, "hud has stone, follower, loaf, time and food counters")
	for b in boxes:
		t.falsy((b as Control).visible, "counter hidden while it has nothing to count")
	hud._on_stones(3)
	t.truthy(hud._stones_box.visible, "stones counter shows once stones exist")
	hud.set_counter(&"food", 3)
	t.truthy(hud._food_box.visible, "the food counter shows when food was applied")
	t.eq(hud._food_label.text, "3", "...with its number")
	hud.set_counter(&"food", -1)
	t.falsy(hud._food_box.visible, "...and hides again")
	hud.free()


func _pause_focus(t: TestRunner) -> void:
	# D1: after the pause menu closes (Back or Resume) focus returns to the card.
	var main: Node = (load("res://main.tscn") as PackedScene).instantiate()
	t.root.add_child(main)
	RunState.start_chapter(1, RunModel.Mode.NORMAL)
	var options: Array = RunState.offer_blessings()
	RunState.blessing_offered.emit(options)
	var vp: Viewport = t.root
	var card: Control = vp.gui_get_focus_owner()
	t.truthy(card is BlessingCard, "Blessing pick focuses a card first")
	for how in ["back", "resume"]:
		main.call("_open_pause")
		t.falsy(vp.gui_get_focus_owner() is BlessingCard, "pause menu takes focus")
		if how == "back":
			main.set("_last_back_msec", -1000)
			main.call("_handle_back")
		else:
			main.call("_close_pause", true)
		t.eq(vp.gui_get_focus_owner(), card, "focus returns to the card after %s" % how)
	main.free()
	RunState.end_run()


func _chapter_cards(t: TestRunner) -> void:
	# D3: chapters without data stay locked even if the save says unlocked; Up from the mode row
	# returns to the last focused card.
	var before: int = SaveData.model.chapters_unlocked
	SaveData.model.chapters_unlocked = 4
	var cs: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs)
	var cards: Array = cs.get("_cards")
	t.falsy((cards[0] as Button).disabled, "chapter 1 card is enabled")
	t.falsy((cards[1] as Button).disabled, "chapter 2 card is enabled once its data exists and the save unlocks it")
	t.falsy((cards[2] as Button).disabled, "chapter 3 card is enabled once its data exists and the save unlocks it")
	t.falsy((cards[3] as Button).disabled, "chapter 4 card is enabled once its data exists and the save unlocks it")
	SaveData.model.chapters_unlocked = 3
	var cs3: Control = (load("res://screens/chapter-select/chapter-select.tscn") as PackedScene).instantiate() as Control
	t.root.add_child(cs3)
	var locked: Array = cs3.get("_cards")
	t.truthy((locked[3] as Button).disabled and (locked[3] as Button).focus_mode == Control.FOCUS_NONE, "chapter 4 card stays locked until chapter 3 is complete")
	cs3.free()
	SaveData.model.chapters_unlocked = 4
	var modes: Array = cs.get("_mode_buttons")
	t.eq((modes[0] as Button).get_node((modes[0] as Button).focus_neighbor_top), cards[0], "Up from the mode row targets the last focused card")
	cs.free()
	SaveData.model.chapters_unlocked = before
