extends RefCounted
## 4.7 Lo-debar (search): walk, talk to the four villagers with OK, follow the arrows to Mephibosheth's
## house. No enemies, never fails, no hint words, and no mode or Blessing changes the story.

const U := preload("res://tests/ch4-play-util.gd")
const ID: String = "4-7-lo-debar"

var _made: Array[Node] = []


func run(t: TestRunner) -> void:
	_setup_and_bounds(t)
	_win_path(t)
	_order_and_hints(t)
	_never_fails(t)
	_table_scene(t)
	_outcome_matrix(t)
	for n in _made:
		n.free()


func _make(mode: RunModel.Mode, blessing: String = "") -> Array:
	var s: StageSearch = StageSearch.new()
	_made.append(s)
	var rec: Dictionary = U.build(s, ID, mode, blessing)
	return [s, rec]


## Meets every villager in chain order, then walks into the house.
func _play_through(s: StageSearch) -> void:
	for i in s.chain.size():
		var v: ActorVillager = s.villagers[s.chain[i]]
		U.walk_to(s, v.position + Vector2(60, 0))
		s.on_action_tap()
	U.walk_to(s, s.house.position)


func _setup_and_bounds(t: TestRunner) -> void:
	var s: StageSearch = _make(RunModel.Mode.NORMAL)[0]
	s.begin()
	t.eq(s.villagers.size(), 4, "four villagers (data)")
	t.eq(s.chain, [0, 1, 2, 3] as Array[int], "the chain runs through every villager")
	t.eq(s.current_target(), 0, "the first target is the first villager")
	var before: int = s.world.get_child_count()
	U.run_for(s, 30.0)
	t.eq(s.world.get_child_count(), before, "no nodes are created while the stage runs")
	t.falsy(s.table_shown, "the table scene waits for the win")


func _win_path(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageSearch = pair[0]
	var rec: Dictionary = pair[1]
	s.begin()
	t.eq(rec["ids"], [&"c4-7-david-ask"], "David asks on entering")
	# The house is closed before the villagers have been met.
	U.walk_to(s, s.house.position)
	t.eq(rec["won"], 0, "the house does not win before the villagers are met")
	t.falsy(s.house.open, "the house door is closed")
	U.walk_to(s, s.villagers[0].position + Vector2(60, 0))
	t.eq(s.talked_count, 0, "nothing happens until OK")
	s.on_action_tap()
	t.eq(s.talked_count, 1, "OK beside the first villager talks to him")
	t.truthy(s.villagers[0].talked, "he is marked as met")
	t.eq(s.current_target(), 1, "the arrow now points to the second villager")
	t.truthy(s.villagers[0].bubble, "his speech bubble shows (dots only)")
	t.truthy(rec["sfx"].has(&"pickup"), "talking plays a cue")
	for i in range(1, 4):
		U.walk_to(s, s.villagers[i].position + Vector2(60, 0))
		s.on_action_tap()
	t.eq(s.talked_count, 4, "all four villagers met")
	t.eq(s.current_target(), -1, "the last arrow points to the house")
	t.truthy(s.house.open, "the house door opens")
	t.eq(rec["won"], 0, "not won until David reaches the house")
	U.walk_to(s, s.house.position)
	t.eq(rec["won"], 1, "reaching Mephibosheth's house wins")
	t.eq(rec["ids"], [&"c4-7-david-ask", &"c4-7-meph", &"c4-7-david-table"], "the win lines play in order")
	t.eq(rec["failed"], 0, "never fails")


func _order_and_hints(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL)
	var s: StageSearch = pair[0]
	s.begin()
	# OK beside the third villager first: no progress, but the arrow shows the way.
	U.walk_to(s, s.villagers[2].position + Vector2(60, 0))
	s.on_action_tap()
	t.eq(s.talked_count, 0, "talking out of order does not skip the chain")
	t.truthy(s.villagers[2].bubble, "...but he points the way")
	s.tick(U.STEP)
	t.truthy(s._pointer.visible, "the pointing arrow shows over him")
	var to: Vector2 = s.target_position()
	var want: float = (to - s.villagers[2].position).angle()
	t.truthy(absf(angle_difference(s._pointer.rotation, want)) < 0.01, "the arrow points at the villager David should find")
	U.run_for(s, 5.0)
	t.falsy(s._pointer.visible, "the pointer fades after a few seconds")
	t.falsy(s.villagers[2].bubble, "...and so does the bubble")
	# OK in the open talks to nobody.
	U.walk_to(s, s.field_point(Vector2(0.5, 0.5)))
	var far: bool = true
	for v in s.villagers:
		if v.position.distance_to(s.david.position) <= StageSearch.TALK_REACH:
			far = false
	if far:
		s.on_action_tap()
		t.eq(s.talked_count, 0, "OK away from everyone does nothing")
	# Meeting the same villager twice counts once.
	U.walk_to(s, s.villagers[0].position + Vector2(60, 0))
	s.on_action_tap()
	s.on_action_tap()
	t.eq(s.talked_count, 1, "talking twice to one villager counts once")
	# The guide arrow beside David shows after the first talk and points at the target.
	s.tick(U.STEP)
	t.truthy(s._guide.visible, "the guide arrow shows once the search is under way")
	var gd: Vector2 = (s.target_position() - s.david.position).normalized()
	t.truthy(absf(angle_difference(s._guide.rotation, gd.angle())) < 0.01, "the guide arrow points to the next target")
	# Idle for a while: the guide arrow shows by itself.
	var s2: StageSearch = _make(RunModel.Mode.LAMB)[0]
	s2.begin()
	s2.tick(U.STEP)
	t.falsy(s2._guide.visible, "no guide arrow in the first seconds")
	U.run_for(s2, StageSearch.GUIDE_IDLE_SEC + 1.0)
	t.truthy(s2._guide.visible, "the guide arrow helps a player who is lost")
	# Hints data as a custom chain order.
	var d: StageDef = U.stage_def(ID, RunModel.Mode.NORMAL)
	d.params["hints"] = [2, 0, 3, 1]
	var s3: StageSearch = StageSearch.new()
	_made.append(s3)
	var rec: Dictionary = U.U3.build(s3, d, RunModel.Mode.NORMAL)
	s3.begin()
	t.eq(s3.chain, [2, 0, 3, 1] as Array[int], "a valid hints list sets the chain order")
	s3.david.position = s3.villagers[2].position + Vector2(40, 0)
	s3.on_action_tap()
	t.eq(s3.current_target(), 0, "the chain follows the list")
	t.eq(rec["failed"], 0, "no failure")


func _never_fails(t: TestRunner) -> void:
	for mode in U.modes():
		var pair: Array = _make(mode)
		var s: StageSearch = pair[0]
		s.begin()
		U.run_for(s, 300.0)
		t.eq(pair[1]["failed"], 0, "%s: idling never fails" % RunModel.mode_key(mode))
		t.eq(pair[1]["hits"], 0, "%s: nothing hurts David" % RunModel.mode_key(mode))
		t.eq(pair[1]["won"], 0, "%s: no accidental win" % RunModel.mode_key(mode))
	t.eq(U.stage_def(ID, RunModel.Mode.NORMAL).lose.size(), 0, "the data has no lose condition")


func _table_scene(t: TestRunner) -> void:
	var pair: Array = _make(RunModel.Mode.NORMAL, "mighty-men")
	var s: StageSearch = pair[0]
	s.begin()
	t.eq(s.companion_count(), 1, "Mighty Men walks with David")
	_play_through(s)
	t.eq(pair[1]["won"], 1, "won with a companion")
	t.truthy(s.table_shown, "the long-table scene replaces the village on the win")
	t.falsy(s._village.visible, "the village is hidden")
	t.falsy(s.david.visible, "David is part of the table scene, not the walking figure")


func _outcome_matrix(t: TestRunner) -> void:
	for mode in U.modes():
		for b in U.blessings():
			var pair: Array = _make(mode, b)
			var s: StageSearch = pair[0]
			var rec: Dictionary = pair[1]
			var tag: String = U.tag(mode, b)
			s.begin()
			_play_through(s)
			s.on_action_hold()
			t.eq(rec["won"], 1, "%s: the search is won" % tag)
			t.eq(rec["failed"], 0, "%s: no failure" % tag)
			t.eq(rec["ids"], [&"c4-7-david-ask", &"c4-7-meph", &"c4-7-david-table"], "%s: the story lines never change" % tag)
			t.eq(s.talked_count, 4, "%s: every villager met" % tag)
