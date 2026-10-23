class_name StageCutscene
extends StagePlayBase
## Plays a cutscene's data beats in order. Lines wait for OK or a short auto-advance.
## `tutorial` beats hand control to the player (walk, return a sheep, sling a stone) until
## their `until` event happens. All text comes from LineBook through the data beats.

enum Wait { NONE, LINE, TUTORIAL, QUIET, CUTAWAY }
enum SlowPhase { NONE, IN, HOLD, OUT }

## A `visual` beat was shown (tests and tools watch this; the stage itself draws it).
signal visual_requested(cue: StringName)

const SHEEP_SCENE: PackedScene = preload("res://actors/actor-sheep.tscn")
const STONE_FX_SCENE: PackedScene = preload("res://actors/actor-stone.tscn")
const FACE_COUNT: int = 3
const STONE_FROM: Vector2 = Vector2(360, 700)
const STONE_TO: Vector2 = Vector2(1560, 560)
const STONE_ARC: float = 160.0

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
var _line_sec: float = 0.0
# Effects: bounded screen shake, slow motion (Engine.time_scale, always restored), cut-aways.
var _shake_left: float = 0.0
var _shake_total: float = 0.0
var _shake_amp: float = 0.0
var _slow_phase: SlowPhase = SlowPhase.NONE
var _slow_clock: float = 0.0
var _slow_target: float = 1.0
var _slow_hold: float = 0.0
var _slow_ramp: float = 0.0
var _cutaway: StringName = &""
var _fx_stone: ActorStone = null
var _faces: Array[ActorFace] = []


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_blank_throws = true
	beats = def.cutscene_beats()
	beat_index = -1
	waiting = Wait.NONE
	_line_sec = def.param_float("lineSec", 0.0)
	david.visible = false
	_stray = SHEEP_SCENE.instantiate() as ActorSheep
	_stray.visible = false
	world.add_child(_stray)
	restore_time_scale()
	_shake_left = 0.0
	_cutaway = &""
	_fx_stone = STONE_FX_SCENE.instantiate() as ActorStone
	_fx_stone.visible = false
	world.add_child(_fx_stone)
	_faces.clear()
	for i in FACE_COUNT:
		var f: ActorFace = ActorFace.new()
		f.position = Vector2(StageUtil.SCREEN.x * (float(i) + 1.0) / float(FACE_COUNT + 1), StageUtil.SCREEN.y * 0.5)
		f.visible = false
		world.add_child(f)
		_faces.append(f)


func _on_begin() -> void:
	_apply_visuals(play_event(&"start"))
	_next_beat()


func report_stone_thrown() -> void:
	super()
	_thrown = true


## OK in the tutorial throws a stone; in Lamb mode it plays the harp ring instead (no stone),
## which satisfies the stone-thrown step.
func on_action_tap() -> void:
	if _finished:
		return
	match waiting:
		Wait.TUTORIAL:
			if lamb_harp_mode():
				play_harp_tap()
				_thrown = _thrown or _until == "stone-thrown"
			else:
				super()
		Wait.LINE:
			if _wait_total - _wait_left >= BalanceData.feel("cutsceneMinLineSec"):
				_next_beat()


## The hold has no use in a cutscene.
func on_action_hold() -> void:
	pass


func _step(delta: float) -> void:
	_fx_step(delta)
	match waiting:
		Wait.LINE, Wait.QUIET:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_next_beat()
		Wait.CUTAWAY:
			_wait_left -= delta
			_move_cutaway()
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
			done = _moved >= BalanceData.feel("tutorialMovedDistance")
		"sheep-returned":
			if _stray.state == ActorSheep.State.LOST and _stray.position.distance_to(david.position) <= BalanceData.feel("tutorialReturnRadius"):
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
	_hide_cutaways()
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
			return _start_visual(str(beat.get("cue", "")))
		"sfx":
			_start_sfx(str(beat.get("cue", "")), beat)
			return false
		"shake":
			_start_shake(float(beat.get("amount", 0.0)), float(beat.get("seconds", 0.0)))
			return false
		"slow-motion":
			_start_slowmo(float(beat.get("scale", 0.0)), float(beat.get("seconds", 0.0)))
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
			StageUtil.set_backdrop(backdrop, "end-card")
			_show_line(beat, false)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"quiet-moment":
			_wait(Wait.QUIET, float(beat.get("seconds", BalanceData.feel("cutsceneQuietSec"))))
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
		request_gold_light(str(l.get("text", "")), str(l.get("reference", "")), float(beat.get("seconds", 0.0)))
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
	_hide_cutaways()
	_end_effects()
	david.visible = false
	for b in play_event(&"win"):
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			StageUtil.set_backdrop(backdrop, str((b as Dictionary).get("cue", "")))
	win()


# --- Visual cues and effects (2.3, 2.4, 2.7) ---

## Shows a visual cue. A cue that would show a fallen body is dropped. Timed cut-aways (the stone in
## flight, the soldiers' wide-eyed faces) hold the scene for `cutawaySec`. Returns true when it waits.
func _start_visual(cue: String) -> bool:
	if StageUtil.is_body_cue(cue):
		return false
	StageUtil.set_backdrop(backdrop, cue)
	visual_requested.emit(StringName(cue))
	var kind: StringName = StageUtil.cutaway_kind(cue)
	if kind == &"":
		if cue.contains("thud") or cue.contains("shake"):
			_start_shake(0.0, 0.0)
		return false
	_cutaway = kind
	if kind == &"stone":
		_fx_stone.position = STONE_FROM
		_fx_stone.visible = true
	else:
		for f in _faces:
			f.visible = true
	_wait(Wait.CUTAWAY, BalanceData.feel("cutawaySec"))
	return true


## `sfx` beat: the cue goes to the host. The cues `slow-motion` and `screen-shake` also start the effect.
func _start_sfx(cue: String, beat: Dictionary) -> void:
	request_sfx(StringName(cue))
	if cue == "slow-motion":
		_start_slowmo(float(beat.get("scale", 0.0)), float(beat.get("seconds", 0.0)))
	elif cue == "screen-shake":
		_start_shake(float(beat.get("amount", 0.0)), float(beat.get("seconds", 0.0)))


func _move_cutaway() -> void:
	if _cutaway != &"stone" or _wait_total <= 0.0:
		return
	var k: float = clampf(1.0 - _wait_left / _wait_total, 0.0, 1.0)
	_fx_stone.position = STONE_FROM.lerp(STONE_TO, k) + Vector2(0.0, -sin(k * PI) * STONE_ARC)


func _hide_cutaways() -> void:
	_cutaway = &""
	if _fx_stone != null:
		_fx_stone.visible = false
	for f in _faces:
		f.visible = false


## Bounded screen shake of the scene. 0 for amount or seconds uses the data defaults (balance feel).
func _start_shake(amount: float, seconds: float) -> void:
	var amp: float = amount if amount > 0.0 else BalanceData.feel("shakePx")
	var sec: float = seconds if seconds > 0.0 else BalanceData.feel("shakeSec")
	_shake_amp = clampf(amp, 0.0, BalanceData.feel("shakeMaxPx"))
	_shake_total = maxf(sec, 0.0)
	_shake_left = maxf(_shake_left, _shake_total)


## Slow motion: Engine.time_scale eases to `scale`, holds `seconds` of real time, eases back to 1.0.
## 0 for either uses the data defaults. Every way out of the stage restores 1.0.
func _start_slowmo(scale: float, seconds: float) -> void:
	_slow_target = clampf(scale if scale > 0.0 else BalanceData.feel("slowMotionScale"), 0.05, 1.0)
	_slow_hold = seconds if seconds > 0.0 else BalanceData.feel("slowMotionSec")
	_slow_ramp = maxf(BalanceData.feel("slowMotionRampSec"), 0.01)
	_slow_clock = 0.0
	_slow_phase = SlowPhase.IN


func _fx_step(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left = maxf(_shake_left - delta, 0.0)
		var a: float = _shake_amp * (_shake_left / _shake_total) if _shake_total > 0.0 else 0.0
		world.position = Vector2(_rng.randf_range(-a, a), _rng.randf_range(-a, a))
		if _shake_left <= 0.0:
			world.position = Vector2.ZERO
	if _slow_phase == SlowPhase.NONE:
		return
	# `delta` already carries the time scale; real seconds are delta / scale.
	_slow_clock += delta / maxf(Engine.time_scale, 0.01)
	match _slow_phase:
		SlowPhase.IN:
			var k: float = minf(_slow_clock / _slow_ramp, 1.0)
			Engine.time_scale = lerpf(1.0, _slow_target, k)
			if k >= 1.0:
				_slow_phase = SlowPhase.HOLD
				_slow_clock = 0.0
		SlowPhase.HOLD:
			Engine.time_scale = _slow_target
			if _slow_clock >= _slow_hold:
				_slow_phase = SlowPhase.OUT
				_slow_clock = 0.0
		SlowPhase.OUT:
			var k2: float = minf(_slow_clock / _slow_ramp, 1.0)
			Engine.time_scale = lerpf(_slow_target, 1.0, k2)
			if k2 >= 1.0:
				restore_time_scale()


func is_slow_motion() -> bool:
	return _slow_phase != SlowPhase.NONE


## Puts the engine clock back to normal and cancels any slow motion. Safe to call at any time.
func restore_time_scale() -> void:
	_slow_phase = SlowPhase.NONE
	Engine.time_scale = 1.0


func _end_effects() -> void:
	restore_time_scale()
	_shake_left = 0.0
	if world != null:
		world.position = Vector2.ZERO


func _exit_tree() -> void:
	_end_effects()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED or what == NOTIFICATION_PREDELETE:
		if _slow_phase != SlowPhase.NONE:
			restore_time_scale()
