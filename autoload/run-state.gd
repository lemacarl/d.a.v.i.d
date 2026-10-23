extends Node
## Holds the live RunModel, the chapter's stages and the ModifierStack. Emits run signals.
## No disk writes, no UI, no story text. Mode decides what a failure does.

signal hearts_changed(hearts: int, hearts_max: int)
signal stones_changed(stones: int)
signal followers_changed(followers: int)
signal blessing_added(id: StringName)
## message is "pool:{id}" or "line:{id}" (resolve with LineBook.resolve).
signal run_failed(message: String)
signal chapter_completed(chapter: int)
signal stage_changed(def: StageDef)
## Between stages: options is an Array of Blessing card dictionaries. Answer with add_blessing or skip_blessing.
signal blessing_offered(options: Array)
## Shepherd only: David is tired and must rest this many seconds, then the host calls end_rest().
signal tired(seconds: float)
signal rested

const CHAPTER_PATH: String = "res://data/chapters/ch%d.json"
const DEFAULT_TARGET: String = "chapter-start"
const DEFAULT_MESSAGE: String = "pool:david-falls"

var model: RunModel = RunModel.new()
var mods: ModifierStack = ModifierStack.new()
var chapter_data: Dictionary = {}
var stage_defs: Array[StageDef] = []
var current_stage: StageDef = null
var awaiting_blessing: bool = false
var is_tired: bool = false

var _raw_stages: Array = []
var _injected: Dictionary = {}
var _restart_index: int = 0
## Stones carried when the current stage was entered (restored by a pause-menu stage restart).
var _entry_stones: int = 0
## Followers and scripted food when the current stage was entered (a stage restart gets them back).
var _entry_followers: int = 0
var _entry_food: int = 0
var _seed_fixed: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Tests and tools: supply chapter data instead of reading data/chapters and data/stages.
func set_chapter_data(n: int, chapter: Dictionary, stages: Array) -> void:
	_injected[n] = {"chapter": chapter, "stages": stages}


## Fixes the seed (tests). Without it every chapter attempt and restart draws a new seed.
func set_seed(s: int) -> void:
	_seed_fixed = true
	model.rng_seed = s
	_rng.seed = s


func _reseed() -> void:
	if not _seed_fixed:
		model.rng_seed = randi()
	_rng.seed = model.rng_seed


func start_chapter(n: int, mode: RunModel.Mode = RunModel.Mode.NORMAL) -> void:
	model.mode = mode
	model.start_chapter(n, BalanceData.hearts_max())
	_reseed()
	mods.set_mode(mode)
	mods.clear_blessings()
	awaiting_blessing = false
	is_tired = false
	_load_chapter(model.chapter)
	_emit_counters()
	if stage_defs.is_empty():
		current_stage = null
		return
	_enter_stage(0)


## Called by the host when the current stage emits stage_won.
func advance() -> void:
	if current_stage == null or awaiting_blessing:
		return
	if not model.cleared_stages.has(current_stage.id):
		model.cleared_stages.append(current_stage.id)
	_apply_unlocks(current_stage)
	if current_stage.blessing_after:
		var options: Array = offer_blessings()
		if not options.is_empty():
			awaiting_blessing = true
			blessing_offered.emit(options)
			return
	_go_next()


## Adds a Blessing for this chapter. If a pick was pending, play continues to the next stage.
func add_blessing(id: StringName) -> void:
	var card: Dictionary = BalanceData.blessing_card(id)
	if card.is_empty() or model.blessings.has(id):
		return
	if mods.add_blessing(card):
		model.blessings.append(id)
		model.blessing_stage[id] = model.stage_index
		blessing_added.emit(id)
	if awaiting_blessing:
		awaiting_blessing = false
		_go_next()


func skip_blessing() -> void:
	if awaiting_blessing:
		awaiting_blessing = false
		_go_next()


## Cards that may be offered now: chapter, chapter pool, mode relevance, unlock and availability rules.
func available_blessings() -> Array:
	return _eligible_cards(true)


func _eligible_cards(mode_filter: bool) -> Array:
	var out: Array = []
	var pool: Array = []
	var p: Variant = chapter_data.get("blessingPool", [])
	if p is Array:
		pool = p as Array
	var mode_key: String = RunModel.mode_key(model.mode)
	for c in BalanceData.blessing_cards():
		var card: Dictionary = c as Dictionary
		var id: StringName = StringName(str(card.get("id", "")))
		if model.blessings.has(id):
			continue
		if not _in_chapter(card):
			continue
		if not pool.is_empty() and not pool.has(String(id)):
			continue
		if mode_filter and not bool(BalanceData.as_dict(card.get("modeRelevance", {})).get(mode_key, true)):
			continue
		var after: String = str(card.get("availableAfterStage", ""))
		if not after.is_empty() and not model.cleared_stages.has(StringName(after)):
			continue
		if card.has("unlock") and id == &"goliaths-sword" and not model.sword_unlocked:
			continue
		out.append(card)
	return out


## Up to offerCount random cards (seeded by rng_seed). Mode-relevant cards come first; if
## fewer than offerCount exist (Lamb), the rest are filled from the other eligible cards.
func offer_blessings() -> Array:
	var cards: Array = available_blessings()
	var n: int = BalanceData.offer_count()
	var out: Array = []
	while out.size() < n and not cards.is_empty():
		out.append(cards.pop_at(_rng.randi_range(0, cards.size() - 1)))
	if out.size() < n:
		var rest: Array = []
		for c in _eligible_cards(false):
			if not out.has(c):
				rest.append(c)
		while out.size() < n and not rest.is_empty():
			out.append(rest.pop_at(_rng.randi_range(0, rest.size() - 1)))
	return out


## Reports a stage failure. Returns what happened:
## &"ignored" (mode vetoed), &"restart-chapter", &"restart-stage" or &"goto-stage".
func fail_stage(reason: StringName) -> StringName:
	if current_stage == null:
		return &"ignored"
	if not mods.allows(&"stage-fail", current_stage):
		return &"ignored"
	if reason == &"timeout" and not mods.allows(&"timeout-fail", current_stage):
		return &"ignored"
	var entry: Dictionary = current_stage.on_lose_for(reason)
	var target: String = str(entry.get("target", DEFAULT_TARGET))
	var message: String = str(entry.get("message", DEFAULT_MESSAGE))
	var keep: bool = bool(entry.get("keepBlessings", target != "chapter-start"))
	var idx: int = model.stage_index
	var carried: int = _entry_stones
	var entry_followers: int = _entry_followers
	var entry_food: int = _entry_food
	var result: StringName = &"restart-stage"
	if target == "chapter-start":
		idx = _restart_index
		result = &"restart-chapter"
	elif target.begins_with("stage:"):
		var found: int = _index_of(StringName(target.substr(6)))
		idx = found if found >= 0 else _restart_index
		result = &"goto-stage"
	_reset_attempt(idx, keep, result == &"restart-chapter")
	if result == &"restart-stage":
		# Replaying a stage keeps the stones it was entered with (2.6 after 2.5).
		set_stones(carried)
		# Replaying a camp day starts from the men the day began with; scripted food is not lost.
		set_followers(entry_followers)
		model.next_stage_food = entry_food
	run_failed.emit(message)
	_enter_stage(idx)
	return result


## Restart the whole chapter attempt from its restart stage (blessings reset). Emits run_failed.
func restart_chapter() -> void:
	if current_stage == null:
		return
	_reset_attempt(_restart_index, false, true)
	run_failed.emit(DEFAULT_MESSAGE)
	_enter_stage(_restart_index)


## Pause-menu restart: same stage again, Blessings kept, no run_failed.
func restart_stage() -> void:
	if current_stage == null:
		return
	var carried: int = _entry_stones
	var entry_followers: int = _entry_followers
	var entry_food: int = _entry_food
	_reset_attempt(model.stage_index, true, false)
	# Stones collected in an earlier stage (2.5) are still carried when this stage restarts.
	set_stones(carried)
	set_followers(entry_followers)
	model.next_stage_food = entry_food
	_enter_stage(model.stage_index)


## Changes mode mid-chapter (pause menu). Re-merges the stage data; call restart_stage() afterwards.
func set_mode(mode: RunModel.Mode) -> void:
	model.mode = mode
	mods.set_mode(mode)
	var keep_id: StringName = current_stage.id if current_stage != null else &""
	_build_defs()
	if keep_id != &"":
		var i: int = _index_of(keep_id)
		if i >= 0:
			current_stage = stage_defs[i]
			model.stage_index = i


## Damage from a stage hit. Normal: at zero hearts the stage fails (only if the stage
## has a hearts-zero lose entry; otherwise hearts floor at 1). Shepherd: David is tired, rests, continues.
## Lamb: no damage.
func apply_hit(amount: int = 1) -> void:
	if model.mode == RunModel.Mode.LAMB or is_tired or current_stage == null:
		return
	model.hearts = maxi(model.hearts - amount, 0)
	if model.hearts == 0 and model.mode == RunModel.Mode.NORMAL and not current_stage.has_lose(&"hearts-zero"):
		model.hearts = 1
	hearts_changed.emit(model.hearts, model.hearts_max)
	if model.hearts > 0:
		return
	if mods.allows(&"david-fall", current_stage):
		fail_stage(&"hearts-zero")
	else:
		is_tired = true
		tired.emit(mods.apply(&"rest-time", 0.0))


## Host calls this when the rest timer ends: hearts refill and play continues.
func end_rest() -> void:
	if not is_tired:
		return
	is_tired = false
	model.hearts = model.hearts_max
	hearts_changed.emit(model.hearts, model.hearts_max)
	rested.emit()


func heal(amount: int = 1) -> void:
	model.hearts = clampi(model.hearts + amount, 0, model.hearts_max)
	hearts_changed.emit(model.hearts, model.hearts_max)


func set_stones(n: int) -> void:
	model.stones = maxi(n, 0)
	stones_changed.emit(model.stones)


func add_stones(n: int) -> void:
	set_stones(model.stones + n)


## Spends one carried stone. Returns false when none are left (stage decides: refill or fail).
func spend_stone() -> bool:
	if model.stones <= 0:
		return false
	model.stones -= 1
	stones_changed.emit(model.stones)
	return true


func stones_refill_enabled() -> bool:
	return mods.apply_bool(&"stones-refill", false)


func set_followers(n: int) -> void:
	model.followers = maxi(n, 0)
	followers_changed.emit(model.followers)


func add_followers(n: int) -> void:
	set_followers(model.followers + n)


func record_sheep_saved() -> void:
	model.stats["sheep_saved"] = int(model.stats["sheep_saved"]) + 1


func record_stone_thrown() -> void:
	model.stats["stones_thrown"] = int(model.stats["stones_thrown"]) + 1


func unlock_sword() -> void:
	model.sword_unlocked = true


## A scripted scene grants food for the next stage only (3.7). Replaces any earlier grant, so a
## replayed scene never stacks; the next stage consumes it once (StageBase.take_food_bonus).
func grant_food(amount: int) -> void:
	model.next_stage_food = maxi(amount, 0)


## Applies a grant reported by a stage (StageBase.grant_requested).
func apply_grant(resource: StringName, amount: int) -> void:
	match resource:
		&"food":
			grant_food(amount)
		&"goliaths-sword":
			unlock_sword()


## Ends the whole run (quit to title, game complete): clears the per-run sword and Blessings.
func end_run() -> void:
	model.sword_unlocked = false
	model.blessings.clear()
	model.blessing_stage.clear()
	mods.clear_blessings()
	awaiting_blessing = false
	current_stage = null


func _in_chapter(card: Dictionary) -> bool:
	for ch in (card.get("chapters", []) as Array):
		if int(ch) == model.chapter:
			return true
	return false


func _apply_unlocks(def: StageDef) -> void:
	var card: Dictionary = BalanceData.blessing_card(&"goliaths-sword")
	var unlock: Dictionary = BalanceData.as_dict(card.get("unlock", {}))
	if str(unlock.get("scope", "")) == "run" and StringName(str(unlock.get("stage", ""))) == def.id:
		unlock_sword()


func _go_next() -> void:
	# Stones travel only where the stage that just ended says so (win.carry, 2.5 into 2.6).
	if model.stones > 0 and not _carries_stones(current_stage):
		set_stones(0)
	var nxt: int = -1
	if current_stage.next_id != &"":
		nxt = _index_of(current_stage.next_id)
	if nxt < 0 and current_stage.next_id == &"":
		chapter_completed.emit(model.chapter)
		return
	if nxt < 0:
		nxt = model.stage_index + 1
	if nxt >= stage_defs.size():
		chapter_completed.emit(model.chapter)
		return
	_enter_stage(nxt)


func _carries_stones(def: StageDef) -> bool:
	var carry: Variant = def.win.get("carry", [])
	return carry is Array and (carry as Array).has("stones")


func _enter_stage(idx: int) -> void:
	model.stage_index = idx
	_entry_stones = model.stones
	_entry_followers = model.followers
	_entry_food = model.next_stage_food
	current_stage = stage_defs[idx]
	var regen: int = int(mods.apply(&"heart-regen", 0.0))
	if regen > 0:
		model.hearts = mini(model.hearts + regen, model.hearts_max)
		hearts_changed.emit(model.hearts, model.hearts_max)
	stage_changed.emit(current_stage)


func _reset_attempt(idx: int, keep_blessings: bool, whole_chapter: bool) -> void:
	is_tired = false
	awaiting_blessing = false
	model.hearts = model.hearts_max
	model.stones = 0
	model.next_stage_food = 0
	if whole_chapter:
		model.followers = 0
		model.stats["sheep_saved"] = 0
		model.stats["stones_thrown"] = 0
		if model.chapter != RunModel.SWORD_CARRIES_INTO_CHAPTER:
			model.sword_unlocked = false
	_reseed()
	var kept: Array[StringName] = []
	for sid in model.cleared_stages:
		if _index_of(sid) < idx:
			kept.append(sid)
	model.cleared_stages = kept
	if not keep_blessings:
		model.blessings.clear()
		model.blessing_stage.clear()
		mods.clear_blessings()
	else:
		_drop_blessings_from(idx)
	_emit_counters()


## Blessings picked at or after stage `idx` are given up (the pick is offered again when the stage
## is replayed), so replaying a stage never stacks picks.
func _drop_blessings_from(idx: int) -> void:
	var kept: Array[StringName] = []
	for id in model.blessings:
		if int(model.blessing_stage.get(id, 0)) < idx:
			kept.append(id)
		else:
			model.blessing_stage.erase(id)
	if kept.size() == model.blessings.size():
		return
	model.blessings = kept
	mods.set_blessings(kept)


func _emit_counters() -> void:
	hearts_changed.emit(model.hearts, model.hearts_max)
	stones_changed.emit(model.stones)
	followers_changed.emit(model.followers)


func _index_of(id: StringName) -> int:
	for i in stage_defs.size():
		if stage_defs[i].id == id:
			return i
	return -1


func _load_chapter(n: int) -> void:
	if _injected.has(n):
		var inj: Dictionary = _injected[n] as Dictionary
		chapter_data = inj["chapter"] as Dictionary
		_raw_stages = inj["stages"] as Array
	else:
		chapter_data = BalanceData.read_json(CHAPTER_PATH % n)
		var arr: Variant = BalanceData.read_json(StageDef.STAGES_PATH % n).get("stages", [])
		_raw_stages = arr as Array if arr is Array else []
	_build_defs()


func _build_defs() -> void:
	stage_defs.clear()
	var by_id: Dictionary = {}
	for d in _raw_stages:
		if d is Dictionary:
			by_id[StringName(str((d as Dictionary).get("id", "")))] = d
	var order: Array = []
	var listed: Variant = chapter_data.get("stages", [])
	if listed is Array and not (listed as Array).is_empty():
		for sid in (listed as Array):
			order.append(StringName(str(sid)))
	else:
		order = by_id.keys()
	for sid in order:
		if by_id.has(sid):
			stage_defs.append(StageDef.from_dict(by_id[sid] as Dictionary, model.mode))
	var rs: int = _index_of(StringName(str(chapter_data.get("restartStage", ""))))
	_restart_index = maxi(rs, 0)
