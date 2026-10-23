class_name LineQueue
extends RefCounted
## Plays subtitle lines one after another. Every line is held max(3 s, 0.06 s per character)
## (the same time the subtitle box uses). A sticky line (speaker ui: prompts, end cards) queues
## like any other so nothing before it is lost, and stays on screen until the next line
## replaces it. Any line that arrives while a sticky line is showing replaces it at once.
## `when_drained` runs a callback once nothing is playing and nothing waits (stage win gate).

signal line_started(speaker: StringName, text: String, reference: String, hold: float, sticky: bool)

const MIN_SECONDS: float = 3.0
const SECONDS_PER_CHAR: float = 0.06

var _pending: Array[Dictionary] = []
var _remaining: float = 0.0
var _active: bool = false
var _sticky: bool = false
var _after: Callable = Callable()


static func hold_for(text: String) -> float:
	return maxf(MIN_SECONDS, text.length() * SECONDS_PER_CHAR)


## Routes a stage line: speaker ui (prompts, end cards) is sticky, everything else queues.
func request(speaker: StringName, text: String, reference: String = "") -> void:
	push(speaker, text, reference, speaker == &"ui")


func push(speaker: StringName, text: String, reference: String = "", sticky: bool = false) -> void:
	_pending.append({"speaker": speaker, "text": text, "reference": reference, "sticky": sticky})
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


func _start_next() -> void:
	var e: Dictionary = _pending.pop_front() as Dictionary
	var text: String = str(e["text"])
	_active = true
	_sticky = bool(e.get("sticky", false))
	_remaining = hold_for(text)
	line_started.emit(e["speaker"], text, str(e["reference"]), _remaining, _sticky)


func _run_after() -> void:
	if not _after.is_valid():
		return
	var cb: Callable = _after
	_after = Callable()
	cb.call()
