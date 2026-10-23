class_name StageBase
extends Node
## Contract for every stage type. Subclasses override _on_begin, on_action_tap and on_action_hold.
## A stage never changes screens, never touches RunState, and never rewrites story text.

signal stage_started
signal stage_won
signal stage_failed(reason: StringName)
signal hit_taken(amount: int)
signal sheep_saved
signal stone_thrown
## count = number of followers added by this event (not the new total).
signal follower_added(count: int)
## line_id is the data line id (empty for lines that have no recording, such as a verse caption).
signal line_requested(speaker: StringName, text: String, reference: String, line_id: StringName)
## seconds = hold time from the data beat (0 = the data default).
signal gold_light_requested(text: String, reference: String, seconds: float)
## A sound cue id from data/audio.json. The host plays it; a stage never plays sound itself.
signal sfx_requested(cue: StringName)
## One stone was picked up (the host adds it to RunModel.stones, the single source).
signal stone_collected
## One carried stone was used on a miss (the host spends it from RunModel.stones).
signal stone_spent
## A stage-local HUD counter changed: kind &"loaves" or &"time"; value < 0 hides it.
signal counter_changed(kind: StringName, value: int)
## An enemy was spared (passed by instead of hit). Mercy turns each one into a heart.
signal spared
## The stage restores hearts (food eaten). The host heals David.
signal heal_requested(amount: int)
## A scripted scene grants something: &"food" (amount for the next stage) or &"goliaths-sword" (the
## Nob unlock, amount 1). The host applies it; stages never touch RunState.
signal grant_requested(resource: StringName, amount: int)

var def: StageDef = null
var run: RunModel = null
var mods: ModifierStack = null
var _finished: bool = false
## Set by the host before begin(): the stage may hold its timed phases until the host line queue
## has shown the lines requested while beginning (see on_lines_drained).
var wait_for_lines: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	def = stage_def
	run = run_model
	mods = stack
	_finished = false


## Starts the stage: runs the subclass hook, then emits stage_started.
func begin() -> void:
	_on_begin()
	stage_started.emit()


## Subclass hook called by begin().
func _on_begin() -> void:
	pass


func on_action_tap() -> void:
	pass


func on_action_hold() -> void:
	pass


## OK went down (the host calls this on every non-Lamb press; the tap follows on release).
func on_action_press() -> void:
	pass


## The host line queue has shown every line requested so far (first time after begin()).
func on_lines_drained() -> void:
	pass


## Tuned value for a whitelisted key. Never pass story keys (they are returned unchanged).
func get_modifier(key: StringName, base: float) -> float:
	if mods == null:
		return base
	return mods.apply(key, base)


func get_flag(key: StringName, base: bool) -> bool:
	return get_modifier(key, 1.0 if base else 0.0) > 0.5


## Blessing data that is not a number (e.g. &"companionCount"). Returns default without a stack.
func get_feature(key: StringName, default: Variant = null) -> Variant:
	if mods == null:
		return default
	return mods.feature(key, default)


func timer_enabled() -> bool:
	return get_flag(&"timer-enabled", true)


func enemies_enabled() -> bool:
	return get_flag(&"enemy-spawn-enabled", true)


func stones_refill() -> bool:
	return get_flag(&"stones-refill", false)


## Win is a story outcome: not routed through modifiers. Emits stage_won once.
func win() -> void:
	if _finished:
		return
	_finished = true
	stage_won.emit()


## Reports a failure. Returns false (and the stage keeps running) if the mode vetoes it.
func fail(reason: StringName) -> bool:
	if _finished or mods == null:
		return false
	if not mods.allows(&"stage-fail", def):
		return false
	if reason == &"timeout" and not mods.allows(&"timeout-fail", def):
		return false
	_finished = true
	stage_failed.emit(reason)
	return true


func is_finished() -> bool:
	return _finished


func take_hit(amount: int = 1) -> void:
	hit_taken.emit(amount)


func report_sheep_saved() -> void:
	sheep_saved.emit()


func report_stone_thrown() -> void:
	stone_thrown.emit()


func report_stone_collected() -> void:
	stone_collected.emit()


func report_stone_spent() -> void:
	stone_spent.emit()


func report_heal(amount: int) -> void:
	heal_requested.emit(amount)


func report_grant(resource: StringName, amount: int) -> void:
	grant_requested.emit(resource, amount)


## Food for this stage: the scripted grant carried from the previous scene (3.7) plus the
## Gift of Abigail Blessing. Call once at the start of a stage that uses food; it is consumed.
func take_food_bonus() -> int:
	var granted: int = 0
	if run != null:
		granted = run.next_stage_food
		run.next_stage_food = 0
	return granted + int(get_modifier(&"food-start", 0.0))


func report_spared() -> void:
	spared.emit()


## True when the OK action clears this obstacle kind (Goliath's Sword: thorns, ropes).
func clears_obstacle(kind: StringName) -> bool:
	var kinds: Variant = get_feature(&"actionClearsObstacles", [])
	return kinds is Array and (kinds as Array).has(String(kind))


func report_counter(kind: StringName, value: int) -> void:
	counter_changed.emit(kind, value)


func add_followers(count: int) -> void:
	follower_added.emit(count)


func request_line(speaker: StringName, text: String, reference: String = "", line_id: StringName = &"") -> void:
	line_requested.emit(speaker, text, reference, line_id)


func request_sfx(cue: StringName) -> void:
	sfx_requested.emit(cue)


## Emits a data line. A dialogue line that carries a verse caption (script "Caption: ...") is
## followed by a caption line holding the caption text and the reference.
func emit_story_line(l: Dictionary) -> void:
	var speaker: StringName = StringName(str(l.get("speaker", "")))
	var text: String = str(l.get("text", ""))
	var reference: String = str(l.get("reference", ""))
	var caption: String = str(l.get("caption", ""))
	var line_id: StringName = StringName(str(l.get("id", "")))
	if caption.is_empty():
		request_line(speaker, text, reference, line_id)
		return
	request_line(speaker, text, "", line_id)
	request_line(&"caption", caption, reference)


func request_gold_light(text: String, reference: String = "", seconds: float = 0.0) -> void:
	gold_light_requested.emit(text, reference, seconds)


## Plays the data beats of an event trigger ("start", "win", ...): narration, dialogue,
## caption and gold-light beats are resolved through LineBook and emitted as signals.
## Other beat types (visual, sfx, tutorial, ...) are returned for the stage to handle.
func play_event(trigger: StringName) -> Array:
	var rest: Array = []
	if def == null:
		return rest
	for b in def.beats(trigger):
		if not b is Dictionary:
			continue
		var beat: Dictionary = b as Dictionary
		var t: String = str(beat.get("type", ""))
		if t == "narration" or t == "dialogue" or t == "caption" or t == "gold-light":
			var l: Dictionary = LineBook.line(StringName(str(beat.get("line", ""))))
			if l.is_empty():
				continue
			if t == "gold-light":
				request_gold_light(str(l.get("text", "")), str(l.get("reference", "")), float(beat.get("seconds", 0.0)))
			else:
				emit_story_line(l)
		else:
			rest.append(beat)
	return rest
