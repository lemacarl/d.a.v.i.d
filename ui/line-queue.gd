class_name LineQueue
extends RefCounted
## Plays subtitle lines one after another. Every line is held max(3 s, 0.06 s per character)
## (the same time the subtitle box uses). A sticky line (speaker ui: prompts, end cards) queues
## like any other so nothing before it is lost, and stays on screen until the next line
## replaces it. Any line that arrives while a sticky line is showing replaces it at once.
## `when_drained` runs a callback once nothing is playing and nothing waits (stage win gate).

signal line_started(speaker: StringName, text: String, reference: String, hold: float, sticky: bool)
## A line's verse caption, shown together with its line (never before earlier queued lines).
signal caption_started(text: String, reference: String, hold: float)
## The line that just started has a recording under its data id (the host plays it).
signal narration_started(line_id: StringName)
## God's words in gold light, shown on their turn like any other line (never before earlier lines).
signal gold_started(text: String, reference: String, seconds: float)

## The queue just ran dry (the last line finished). Stages that must not start a timed phase over
## unread lines wait for this through StageBase.on_lines_drained.
signal drained

const MIN_SECONDS: float = 3.0
const SECONDS_PER_CHAR: float = 0.06
const GOLD_SECONDS: float = 4.0

var _pending: Array[Dictionary] = []
var _remaining: float = 0.0
var _active: bool = false
var _sticky: bool = false
var _after: Callable = Callable()


static func hold_for(text: String) -> float:
	return maxf(MIN_SECONDS, text.length() * SECONDS_PER_CHAR)


## Routes a stage line: speaker ui (prompts, end cards) is sticky, everything else queues.
## Speaker caption is the verse caption of the line requested just before it: it is attached to
## that line and appears on that line's turn.
func request(speaker: StringName, text: String, reference: String = "", line_id: StringName = &"") -> void:
	if speaker == &"caption":
		_attach_caption(text, reference)
		return
	push(speaker, text, reference, speaker == &"ui", line_id)


func request_gold(text: String, reference: String = "", seconds: float = 0.0) -> void:
	_pending.append({"gold": true, "text": text, "reference": reference, "seconds": seconds, "sticky": false, "id": &""})
	if not _active or _sticky:
		_start_next()


func push(speaker: StringName, text: String, reference: String = "", sticky: bool = false, line_id: StringName = &"") -> void:
	# A line already waiting with the same id (for example repeated "Got you!") is not queued twice.
	if not String(line_id).is_empty():
		for e in _pending:
			if e.get("id", &"") == line_id:
				return
	_pending.append({"speaker": speaker, "text": text, "reference": reference, "sticky": sticky, "id": line_id})
	if not _active or _sticky:
		_start_next()


func tick(delta: float) -> void:
	if not _active:
		return
	_remaining -= delta
	if _remaining > 0.0:
		return
	if not _pending.is_empty():
		_start_next()
		return
	_active = false
	_sticky = false
	drained.emit()
	_run_after()


func is_idle() -> bool:
	return not _active and _pending.is_empty()


## Runs `cb` now when idle, otherwise once the queue has drained. One callback at a time.
func when_drained(cb: Callable) -> void:
	if is_idle():
		cb.call()
		return
	_after = cb


## Drops everything (stage replaced or restarted). Does not run the pending callback.
func clear() -> void:
	_pending.clear()
	_active = false
	_sticky = false
	_remaining = 0.0
	_after = Callable()


func _attach_caption(text: String, reference: String) -> void:
	if not _pending.is_empty():
		var last: Dictionary = _pending.back() as Dictionary
		last["caption"] = text
		last["caption_reference"] = reference
		return
	# The parent line already started (or nothing is playing): show it now with the line.
	caption_started.emit(text, reference, _remaining if _active else hold_for(text))


func _start_next() -> void:
	var e: Dictionary = _pending.pop_front() as Dictionary
	var text: String = str(e["text"])
	_active = true
	_sticky = bool(e.get("sticky", false))
	if e.has("gold"):
		var seconds: float = float(e.get("seconds", 0.0))
		_remaining = seconds if seconds > 0.0 else GOLD_SECONDS
		gold_started.emit(text, str(e["reference"]), _remaining)
		return
	_remaining = hold_for(text)
	var line_id: StringName = StringName(str(e.get("id", "")))
	if not String(line_id).is_empty():
		narration_started.emit(line_id)
	line_started.emit(e["speaker"], text, str(e["reference"]), _remaining, _sticky)
	if e.has("caption"):
		caption_started.emit(str(e["caption"]), str(e.get("caption_reference", "")), _remaining)


func _run_after() -> void:
	if not _after.is_valid():
		return
	var cb: Callable = _after
	_after = Callable()
	cb.call()
