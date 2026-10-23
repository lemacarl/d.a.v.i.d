class_name StageCutscene
extends StagePlayBase
## Plays a cutscene's data beats in order. Lines wait for OK or a short auto-advance.
## `tutorial` beats hand control to the player (walk, return a sheep, sling a stone) until
## their `until` event happens. All text comes from LineBook through the data beats.

enum Wait { NONE, LINE, TUTORIAL, QUIET }

const SHEEP_SCENE: PackedScene = preload("res://actors/actor-sheep.tscn")
const DEFAULT_LINE_SEC: float = 4.0
const MIN_LINE_SEC: float = 0.4
const MOVED_DISTANCE: float = 60.0
const RETURN_RADIUS: float = 90.0
const DEFAULT_QUIET_SEC: float = 5.0

var beats: Array = []
var beat_index: int = -1
var waiting: Wait = Wait.NONE

var _wait_left: float = 0.0
var _wait_total: float = 0.0
var _until: String = ""
var _moved: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO
var _thrown: bool = false
var _stray: ActorSheep = null
var _line_sec: float = DEFAULT_LINE_SEC


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_blank_throws = true
	beats = def.cutscene_beats()
	beat_index = -1
	waiting = Wait.NONE
	_line_sec = def.param_float("lineSec", DEFAULT_LINE_SEC)
	david.visible = false
	_stray = SHEEP_SCENE.instantiate() as ActorSheep
	_stray.visible = false
	world.add_child(_stray)


func _on_begin() -> void:
	_apply_visuals(play_event(&"start"))
	_next_beat()


## Ends the cutscene early (skippable cutscenes).
func skip_to_end() -> void:
	if _finished:
		return
	beat_index = beats.size()
	_finish()


func report_stone_thrown() -> void:
	super()
	_thrown = true


func on_action_tap() -> void:
	if _finished:
		return
	match waiting:
		Wait.TUTORIAL:
			super()
		Wait.LINE:
			if _wait_total - _wait_left >= MIN_LINE_SEC:
				_next_beat()


func _step(delta: float) -> void:
	match waiting:
		Wait.LINE, Wait.QUIET:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_next_beat()
		Wait.TUTORIAL:
			_check_tutorial()


func _check_tutorial() -> void:
	_moved += david.position.distance_to(_last_pos)
	_last_pos = david.position
	var done: bool = false
	match _until:
		"david-moved":
			done = _moved >= MOVED_DISTANCE
		"sheep-returned":
			if _stray.state == ActorSheep.State.LOST and _stray.position.distance_to(david.position) <= RETURN_RADIUS:
				_stray.set_state(ActorSheep.State.FLOCK)
				report_sheep_saved()
				done = true
		"stone-thrown":
			done = _thrown
		_:
			done = true
	if done:
		_next_beat()


func _next_beat() -> void:
	waiting = Wait.NONE
	david.visible = false
	_stray.visible = false
	while not _finished:
		beat_index += 1
		if beat_index >= beats.size():
			_finish()
			return
		if not beats[beat_index] is Dictionary:
			continue
		if _start_beat(beats[beat_index] as Dictionary):
			return


## Starts a beat. Returns true when it waits (so the loop stops), false to continue at once.
func _start_beat(beat: Dictionary) -> bool:
	var t: String = str(beat.get("type", ""))
	match t:
		"visual":
			StageUtil.set_backdrop(backdrop, str(beat.get("cue", "")))
			return false
		"narration", "dialogue", "caption":
			_show_line(beat, false)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"gold-light":
			_show_line(beat, true)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"end-card":
			_show_line(beat, false)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"quiet-moment":
			_wait(Wait.QUIET, float(beat.get("seconds", DEFAULT_QUIET_SEC)))
			return true
		"tutorial":
			_show_line(beat, false)
			_begin_tutorial(str(beat.get("until", "")))
			return true
	return false


func _wait(kind: Wait, seconds: float) -> void:
	waiting = kind
	_wait_left = seconds
	_wait_total = seconds


func _show_line(beat: Dictionary, gold: bool) -> void:
	var l: Dictionary = StageUtil.line_of(str(beat.get("line", "")))
	if l.is_empty():
		return
	if gold:
		request_gold_light(str(l.get("text", "")), str(l.get("reference", "")))
	else:
		emit_story_line(l)


func _begin_tutorial(until: String) -> void:
	waiting = Wait.TUTORIAL
	_until = until
	_moved = 0.0
	_thrown = false
	_last_pos = david.position
	david.visible = true
	if until == "sheep-returned":
		_stray.set_state(ActorSheep.State.LOST)
		_stray.position = (david.position + Vector2(420, -260)).clamp(FIELD.position, FIELD.end)
		_stray.visible = true


func _finish() -> void:
	waiting = Wait.NONE
	david.visible = false
	for b in play_event(&"win"):
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			StageUtil.set_backdrop(backdrop, str((b as Dictionary).get("cue", "")))
	win()
