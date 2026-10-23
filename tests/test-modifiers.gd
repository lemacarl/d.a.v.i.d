extends RefCounted
## Modifier whitelist, mode behaviour, Blessing order, and "no combination changes the story".

const STORY_LINE_TYPES: Array[String] = ["narration", "dialogue", "caption", "gold-light"]


func run(t: TestRunner) -> void:
	_blessing_data(t)
	_whitelist(t)
	_modes(t)
	_order(t)
	_combos(t)
	_story_data(t)


func _blessing_data(t: TestRunner) -> void:
	var cards: Array = BalanceData.blessing_cards()
	t.eq(cards.size(), 13, "blessings.json has 13 cards")
	t.eq(BalanceData.offer_count(), 3, "three cards offered")
	var seen: Dictionary = {}
	for c in cards:
		var card: Dictionary = c as Dictionary
		seen[card["id"]] = true
		for field in ["id", "name", "effect", "chapters", "reference", "modifiers", "modeRelevance"]:
			t.truthy(card.has(field), "%s has %s" % [card["id"], field])
		var m: BlessingModifier = BlessingModifier.new(card)
		t.eq(m.invalid_keys.size(), 0, "%s uses registry keys only" % card["id"])
	t.eq(seen.size(), 13, "13 unique ids")
	var bad: Dictionary = {"id": "evil", "modifiers": {"goliath-falls": true, "skipStoryMult": 2}}
	var s: ModifierStack = ModifierStack.new()
	t.falsy(s.add_blessing(bad), "card with unregistered keys is refused")
	t.eq(s.blessing_modifiers.size(), 0, "refused card not added")
	t.truthy(s.rejected_keys.size() > 0, "refusal recorded")


func _whitelist(t: TestRunner) -> void:
	var s: ModifierStack = ModifierStack.new()
	t.near(s.apply(&"made-up-key", 7.0), 7.0, "unknown key returned unchanged")
	t.truthy(s.rejected_keys.has(&"made-up-key"), "unknown key recorded as rejected")
	s.rejected_keys.clear()
	for k in ModifierStack.STORY_KEYS:
		t.near(s.apply(k, 5.0), 5.0, "story key %s unchanged" % k)
		t.truthy(s.allows(k), "story key %s always allowed" % k)
	t.eq(s.rejected_keys.size(), ModifierStack.STORY_KEYS.size(), "story keys recorded as rejected")
	t.eq(ModifierStack.TUNABLE_KEYS.size(), 13, "13 tunable keys")
	for k in ModifierStack.TUNABLE_KEYS:
		t.falsy(ModifierStack.is_story(k), "%s is not a story key" % k)


func _modes(t: TestRunner) -> void:
	var n: ModifierStack = ModifierStack.new(RunModel.Mode.NORMAL)
	var sh: ModifierStack = ModifierStack.new(RunModel.Mode.SHEPHERD)
	var l: ModifierStack = ModifierStack.new(RunModel.Mode.LAMB)
	t.near(n.apply(&"enemy-speed", 100.0), 100.0, "Normal enemy speed unchanged")
	t.near(sh.apply(&"enemy-speed", 100.0), 60.0, "Shepherd enemy speed x0.6")
	t.near(sh.apply(&"sheep-wander", 1.0), 0.5, "Shepherd sheep wander lower")
	t.near(sh.apply(&"rest-time", 0.0), 3.0, "Shepherd rest 3 s")
	t.truthy(sh.apply_bool(&"stones-refill", false), "Shepherd stones refill")
	t.falsy(sh.apply_bool(&"timer-enabled", true), "Shepherd timer off")
	t.truthy(n.apply_bool(&"timer-enabled", true), "Normal timer on")
	t.falsy(n.apply_bool(&"stones-refill", false), "Normal stones do not refill")
	t.falsy(l.apply_bool(&"enemy-spawn-enabled", true), "Lamb spawns no enemies")
	t.truthy(sh.apply_bool(&"enemy-spawn-enabled", true), "Shepherd keeps enemies")
	t.falsy(l.apply_bool(&"timer-enabled", true), "Lamb timer off")
	t.truthy(n.allows(&"stage-fail"), "Normal can fail")
	t.truthy(n.allows(&"david-fall"), "Normal David can fall")
	t.falsy(sh.allows(&"stage-fail"), "Shepherd cannot fail")
	t.falsy(sh.allows(&"david-fall"), "Shepherd David cannot fall")
	t.falsy(sh.allows(&"timeout-fail"), "Shepherd timeout cannot fail")
	t.falsy(l.allows(&"stage-fail"), "Lamb cannot fail")
	t.falsy(l.allows(&"enemy-spawn"), "Lamb vetoes enemy spawn")
	t.truthy(sh.allows(&"enemy-spawn"), "Shepherd allows enemy spawn")


func _order(t: TestRunner) -> void:
	var s: ModifierStack = ModifierStack.new(RunModel.Mode.SHEPHERD)
	s.set_blessings([&"quick-feet", &"smooth-stones", &"strength-of-the-lord"] as Array[StringName])
	t.near(s.apply(&"enemy-speed", 100.0), 60.0, "blessings do not disturb mode keys")
	t.near(s.apply(&"walk-speed", 100.0), 120.0, "percent Blessing multiplies")
	t.near(s.apply(&"stun-time", 1.0), 2.0, "stun bonus adds one second")
	var f: ModifierStack = ModifierStack.new()
	f.set_blessings([&"mighty-men", &"goliaths-sword"] as Array[StringName])
	t.eq(f.feature(&"companionCount", 0), 1, "feature value from Blessing data")
	t.eq(f.feature(&"actionClearsObstacles", []), ["thorns", "ropes"], "feature list from Blessing data")
	t.eq(f.feature(&"heartOnSpare", -1), -1, "feature default when absent")
	# mode first, then blessings in pick order: x0.6 then x1.2 vs add order check via custom modifiers
	var a: Modifier = Modifier.new()
	var s2: ModifierStack = ModifierStack.new(RunModel.Mode.SHEPHERD)
	s2.set_blessing_modifiers([a] as Array[Modifier])
	t.near(s2.apply(&"enemy-speed", 10.0), 6.0, "base modifier is identity")


func _combos(t: TestRunner) -> void:
	var all: Array[Modifier] = []
	for c in BalanceData.blessing_cards():
		all.append(BlessingModifier.new(c as Dictionary))
	var bad_story: int = 0
	var bad_veto: int = 0
	var bad_rejects: int = 0
	var count: int = 0
	for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB, RunModel.Mode.HARD]:
		var bare: ModifierStack = ModifierStack.new(mode)
		var expect_fail: bool = bare.allows(&"stage-fail")
		var expect_fall: bool = bare.allows(&"david-fall")
		var expect_spawn: bool = bare.allows(&"enemy-spawn")
		var stack: ModifierStack = ModifierStack.new(mode)
		for mask in range(1 << all.size()):
			var picked: Array[Modifier] = []
			for i in all.size():
				if mask & (1 << i):
					picked.append(all[i])
			stack.set_blessing_modifiers(picked)
			count += 1
			for k in ModifierStack.STORY_KEYS:
				if not stack.allows(k) or absf(stack.apply(k, 3.0) - 3.0) > 0.0001:
					bad_story += 1
			if stack.allows(&"stage-fail") != expect_fail or stack.allows(&"david-fall") != expect_fall or stack.allows(&"enemy-spawn") != expect_spawn:
				bad_veto += 1
			for k in ModifierStack.TUNABLE_KEYS:
				stack.apply(k, 1.0)
		bad_rejects += stack.rejected_keys.size() - ModifierStack.STORY_KEYS.size()
	t.eq(count, 4 * (1 << all.size()), "every mode x every Blessing combination checked")
	t.eq(bad_story, 0, "no combination changes a story key or vetoes a story event")
	t.eq(bad_veto, 0, "Blessings never change mode failure rules")
	t.eq(bad_rejects, 0, "tunable keys never rejected")


## Lines in stage events and cutscenes must be identical across modes (skipped if stage data is not written yet).
func _story_data(t: TestRunner) -> void:
	var any: bool = false
	for ch in range(1, 5):
		var normal: Array[StageDef] = StageDef.load_chapter(ch, RunModel.Mode.NORMAL)
		if normal.is_empty():
			continue
		any = true
		for mode in [RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB, RunModel.Mode.HARD]:
			var other: Array[StageDef] = StageDef.load_chapter(ch, mode)
			t.eq(other.size(), normal.size(), "chapter %d same stage count in mode %d" % [ch, mode])
			for i in mini(other.size(), normal.size()):
				t.eq(other[i].story_line_ids(), normal[i].story_line_ids(), "%s story lines identical in mode %d" % [normal[i].id, mode])
				t.eq(other[i].next_id, normal[i].next_id, "%s next stage identical in mode %d" % [normal[i].id, mode])
		for d in normal:
			if d.id == &"2-6-goliath":
				for mode in [RunModel.Mode.NORMAL, RunModel.Mode.SHEPHERD, RunModel.Mode.LAMB, RunModel.Mode.HARD]:
					var g: StageDef = StageDef.from_dict(d.raw, mode)
					t.eq(g.win_kind(), &"timing-hit", "Goliath falls on the forehead hit in mode %d" % mode)
	if not any:
		t.skip("data/stages not written yet: story-line comparison across modes")
