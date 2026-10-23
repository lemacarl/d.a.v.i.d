class_name RunModel
extends RefCounted
## Live state of one attempt at a chapter. Pure data, no nodes, no signals.

## HARD is appended last so saved and serialized values keep their meaning.
enum Mode { NORMAL, SHEPHERD, LAMB, HARD }

const CHAPTER_MIN: int = 1
const CHAPTER_MAX: int = 4
## Goliath's Sword is the only thing that survives a chapter change, and only into this chapter.
const SWORD_CARRIES_INTO_CHAPTER: int = 4

var mode: Mode = Mode.NORMAL
var chapter: int = 1
var stage_index: int = 0
var hearts: int = 3
var hearts_max: int = 3
var stones: int = 0
var followers: int = 0
var blessings: Array[StringName] = []
## Stage index at which each Blessing was picked (id -> index), so a stage restart can drop later picks.
var blessing_stage: Dictionary = {}
var cleared_stages: Array[StringName] = []
var sword_unlocked: bool = false
var stats: Dictionary = {"sheep_saved": 0, "stones_thrown": 0}
var rng_seed: int = 0


static func mode_key(m: Mode) -> String:
	match m:
		Mode.SHEPHERD:
			return "shepherd"
		Mode.LAMB:
			return "lamb"
		Mode.HARD:
			return "hard"
	return "normal"


static func mode_from_key(key: String) -> Mode:
	match key:
		"shepherd":
			return Mode.SHEPHERD
		"lamb":
			return Mode.LAMB
		"hard":
			return Mode.HARD
	return Mode.NORMAL


## True for the modes where David can fail a stage like the written game (Normal and Hard).
static func fails_like_normal(m: Mode) -> bool:
	return m == Mode.NORMAL or m == Mode.HARD


## Begins a fresh attempt at chapter n. Keeps mode. Clears blessings, hearts, stones,
## followers, stats and cleared stages. The sword is kept only when entering chapter 4.
func start_chapter(n: int, max_hearts: int) -> void:
	chapter = clampi(n, CHAPTER_MIN, CHAPTER_MAX)
	stage_index = 0
	hearts_max = max_hearts
	reset_attempt()
	blessings.clear()
	blessing_stage.clear()
	if chapter != SWORD_CARRIES_INTO_CHAPTER:
		sword_unlocked = false


## Resets the per-attempt numbers (hearts, stones, followers, stats, cleared stages).
func reset_attempt() -> void:
	hearts = hearts_max
	stones = 0
	followers = 0
	stats["sheep_saved"] = 0
	stats["stones_thrown"] = 0
	cleared_stages.clear()


func to_dict() -> Dictionary:
	var b: Array = []
	for id in blessings:
		b.append(String(id))
	var c: Array = []
	for id in cleared_stages:
		c.append(String(id))
	return {
		"mode": mode_key(mode),
		"chapter": chapter,
		"stage_index": stage_index,
		"hearts": hearts,
		"hearts_max": hearts_max,
		"stones": stones,
		"followers": followers,
		"blessings": b,
		"blessing_stage": blessing_stage.duplicate(),
		"cleared_stages": c,
		"sword_unlocked": sword_unlocked,
		"stats": stats.duplicate(),
		"rng_seed": rng_seed,
	}


static func from_dict(d: Dictionary) -> RunModel:
	var m: RunModel = RunModel.new()
	m.mode = mode_from_key(str(d.get("mode", "normal")))
	m.chapter = clampi(int(d.get("chapter", 1)), CHAPTER_MIN, CHAPTER_MAX)
	m.stage_index = maxi(int(d.get("stage_index", 0)), 0)
	m.hearts_max = maxi(int(d.get("hearts_max", 3)), 1)
	m.hearts = clampi(int(d.get("hearts", m.hearts_max)), 0, m.hearts_max)
	m.stones = maxi(int(d.get("stones", 0)), 0)
	m.followers = maxi(int(d.get("followers", 0)), 0)
	var b: Variant = d.get("blessings", [])
	if b is Array:
		for id in (b as Array):
			m.blessings.append(StringName(str(id)))
	var bs: Variant = d.get("blessing_stage", {})
	if bs is Dictionary:
		for k in (bs as Dictionary):
			m.blessing_stage[StringName(str(k))] = int((bs as Dictionary)[k])
	var c: Variant = d.get("cleared_stages", [])
	if c is Array:
		for id in (c as Array):
			m.cleared_stages.append(StringName(str(id)))
	m.sword_unlocked = bool(d.get("sword_unlocked", false))
	var s: Variant = d.get("stats", {})
	if s is Dictionary:
		m.stats["sheep_saved"] = int((s as Dictionary).get("sheep_saved", 0))
		m.stats["stones_thrown"] = int((s as Dictionary).get("stones_thrown", 0))
	m.rng_seed = int(d.get("rng_seed", 0))
	return m
