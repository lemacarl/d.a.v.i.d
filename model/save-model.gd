class_name SaveModel
extends RefCounted
## What persists in user://save.json. No run progress is saved.

const VERSION: int = 1
const CHAPTER_COUNT: int = 4
const MODES: Array[String] = ["normal", "shepherd", "lamb"]
const SUBTITLE_SCALE_MAX: float = 3.0

var version: int = VERSION
var chapters_unlocked: int = 1
var mode: String = "normal"
var settings: Dictionary = default_settings()


static func default_settings() -> Dictionary:
	return {"music_volume": 1.0, "narration_volume": 1.0, "subtitle_scale": 1.0}


func is_unlocked(chapter: int) -> bool:
	return chapter >= 1 and chapter <= chapters_unlocked


## Chapter n+1 unlocks when chapter n completes (never lowers, capped at 4).
## Lamb completions unlock only if lamb_unlocks is true. Returns true if something unlocked.
func unlock_after(completed: int, mode_key: String = "normal", lamb_unlocks: bool = true) -> bool:
	if mode_key == "lamb" and not lamb_unlocks:
		return false
	var target: int = mini(completed + 1, CHAPTER_COUNT)
	if target > chapters_unlocked:
		chapters_unlocked = target
		return true
	return false


func to_dict() -> Dictionary:
	return {
		"version": version,
		"chapters_unlocked": chapters_unlocked,
		"mode": mode,
		"settings": settings.duplicate(),
	}


## True if d has the right shape. Missing fields are fine (defaults); wrong types are not.
static func validate(d: Variant) -> bool:
	if not d is Dictionary:
		return false
	var dd: Dictionary = d as Dictionary
	if dd.has("version"):
		if not _is_num(dd["version"]) or int(dd["version"]) > VERSION or int(dd["version"]) < 1:
			return false
	if dd.has("chapters_unlocked"):
		if not _is_num(dd["chapters_unlocked"]):
			return false
	if dd.has("mode"):
		if not dd["mode"] is String or not MODES.has(dd["mode"]):
			return false
	if dd.has("settings"):
		if not dd["settings"] is Dictionary:
			return false
		for k in (dd["settings"] as Dictionary):
			if not _is_num((dd["settings"] as Dictionary)[k]):
				return false
	return true


## Builds a sanitized model (clamped values, defaults for anything missing).
static func from_dict(d: Dictionary) -> SaveModel:
	var m: SaveModel = SaveModel.new()
	m.chapters_unlocked = clampi(int(d.get("chapters_unlocked", 1)), 1, CHAPTER_COUNT)
	var md: String = str(d.get("mode", "normal"))
	m.mode = md if MODES.has(md) else "normal"
	var s: Dictionary = BalanceData.as_dict(d.get("settings", {}))
	m.settings["music_volume"] = clampf(float(s.get("music_volume", 1.0)), 0.0, 1.0)
	m.settings["narration_volume"] = clampf(float(s.get("narration_volume", 1.0)), 0.0, 1.0)
	m.settings["subtitle_scale"] = clampf(float(s.get("subtitle_scale", 1.0)), 1.0, SUBTITLE_SCALE_MAX)
	return m


static func _is_num(v: Variant) -> bool:
	return typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT
