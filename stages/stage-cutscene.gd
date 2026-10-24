class_name StageCutscene
extends StagePlayBase
## Plays a cutscene's data beats in order. Lines wait for OK or a short auto-advance.
## `tutorial` beats hand control to the player (walk, return a sheep, sling a stone) until
## their `until` event happens. All text comes from LineBook through the data beats.
##
## Chapter 3 beats: `interactive` kind `watch-then-ok` (3.3): the arrow flies for `arrowFlightSec`
## (beat `seconds` overrides) and lands far past the boy; OK is ignored while it flies and once it has
## landed OK ends the beat ("come out"); D-pad does nothing; no failure is possible (after
## `arrowWaitSec` the beat moves on by itself). The beat's `then` list plays next. Faithful Friend
## (`arrowHintPerStage`) shows a faint trail behind the arrow: drawing only, never read by the beat.
## `unlock` {id} and `grant` {resource, amount} are reported through `grant_requested` (the host applies them).
##
## Chapter 4: `quiet-moment` {seconds, music} (4.1) waits the full time with no input: OK and the D-pad do
## nothing, no skip is offered, Back still pauses (the host). Its `music` cue goes to the host through
## `music_requested`; an empty cue asks the host for the main music again when the moment ends. A soft
## harp glow stands in for art. The 4.8 final shot is the `visual` cue `bethlehem-night-star` (hills at
## night, resting sheep, a star) and stays behind the `end-card`; the 4.6 gold light and the 4.8 caption
## use the existing `gold-light` and `caption` beats (the host line queue gates the stage win).

enum Wait { NONE, LINE, TUTORIAL, QUIET, CUTAWAY, WATCH, OK }
enum SlowPhase { NONE, IN, HOLD, OUT }

## A `visual` beat was shown (tests and tools watch this; the stage itself draws it).
signal visual_requested(cue: StringName)
## A music cue for the host to play; an empty cue means the main music again.
signal music_requested(cue: StringName)

## Placeholder scenes owned by this stage (visual cue id -> [kind, action]).
const LOCAL_CUE_SCENES: Dictionary = {
	"bethlehem-night-star": [&"night-hills", &"show"],
}

const SHEEP_SCENE: PackedScene = preload("res://actors/actor-sheep.tscn")
const STONE_FX_SCENE: PackedScene = preload("res://actors/actor-stone.tscn")
const FACE_COUNT: int = 3
const STONE_FROM: Vector2 = Vector2(360, 700)
const STONE_TO: Vector2 = Vector2(1560, 560)
const STONE_ARC: float = 160.0
const ARROW_FROM: Vector2 = Vector2(420, 640)
const ARROW_TO: Vector2 = Vector2(1620, 600)
const ARROW_ARC: float = 220.0
const BOY_POS: Vector2 = Vector2(1060, 640)
const QUIET_POS: Vector2 = Vector2(960, 560)
const OK_GLYPH_POS: Vector2 = Vector2(960, 880)
## The throw tutorial: seconds the scene stays after the throw, and after the stone lands.
const AFTER_THROW_SEC: float = 1.5
const AFTER_HIT_SEC: float = 0.8
const TARGET_DISTANCE: float = 650.0
## The returned stray walks back to the flock, then stays this long before the step ends.
const RETURN_SPEED: float = 300.0
const RETURN_HOLD_SEC: float = 0.5
const RETURN_MAX_SEC: float = 6.0
## Lowest y a lost sheep may stand at in the 1.1 hills (above it is sky and far hills).
const STRAY_MIN_Y: float = 640.0

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
var _shaken: bool = false
var _slow_phase: SlowPhase = SlowPhase.NONE
var _slow_clock: float = 0.0
var _slow_target: float = 1.0
var _slow_hold: float = 0.0
var _slow_ramp: float = 0.0
var _cutaway: StringName = &""
var _fx_stone: ActorStone = null
var _scene: ActorScene = null
var _scene_kind: StringName = &""
var _practice: ActorTarget = null
var _since_throw: float = 0.0
var _since_hit: float = 0.0
var _landed: bool = false
var _returning: bool = false
var _return_hold: float = 0.0
var _return_clock: float = 0.0
var _clock: float = 0.0
var _faces: Array[ActorFace] = []
var _arrow: Node2D = null
var _trail: Line2D = null
var _boy: ColorRect = null
## A plain "OK" button shape (no words) that pulses while OK ends the arrow beat.
var _ok_glyph: Node2D = null
## The quiet moment's harp glow (4.1) and whether a music cue is playing for it.
var _quiet: Node2D = null
var _quiet_music: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	_blank_throws = true
	# A copy: an interactive beat splices its `then` beats in, and the LineBook cache must stay intact.
	beats = def.cutscene_beats().duplicate()
	beat_index = -1
	waiting = Wait.NONE
	_line_sec = def.param_float("lineSec", 0.0)
	david.visible = false
	_stray = SHEEP_SCENE.instantiate() as ActorSheep
	_stray.visible = false
	world.add_child(_stray)
	restore_time_scale()
	_shake_left = 0.0
	_shaken = false
	_cutaway = &""
	_scene = null
	_scene_kind = &""
	_practice = ActorTarget.new()
	_practice.visible = false
	world.add_child(_practice)
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
	_build_arrow()
	_build_quiet()


func _build_quiet() -> void:
	_quiet_music = false
	_quiet = Node2D.new()
	_quiet.position = QUIET_POS
	_quiet.visible = false
	_quiet.add_child(_disc(230.0, Color(1.0, 0.85, 0.5, 0.12)))
	_quiet.add_child(_disc(150.0, Color(1.0, 0.88, 0.55, 0.2)))
	_quiet.add_child(_disc(70.0, Color(1.0, 0.93, 0.7, 0.45)))
	for k in 5:
		var string: Line2D = Line2D.new()
		string.width = 4.0
		string.default_color = Color(1.0, 0.95, 0.75, 0.9)
		string.add_point(Vector2(-60.0 + 30.0 * float(k), -90.0 + 10.0 * float(k)))
		string.add_point(Vector2(-60.0 + 30.0 * float(k), 70.0))
		_quiet.add_child(string)
	world.add_child(_quiet)


func _build_arrow() -> void:
	_boy = StageUtil.make_rect(world, Rect2(BOY_POS - Vector2(22, 70), Vector2(44, 90)), Color(0.8, 0.65, 0.5))
	_boy.visible = false
	_trail = Line2D.new()
	_trail.width = 10.0
	_trail.default_color = Color(1.0, 0.9, 0.5, BalanceData.feel("arrowTrailAlpha"))
	_trail.add_point(ARROW_FROM)
	_trail.add_point(ARROW_FROM)
	_trail.visible = false
	world.add_child(_trail)
	_arrow = Node2D.new()
	_arrow.visible = false
	var shaft: Line2D = Line2D.new()
	shaft.width = 6.0
	shaft.default_color = Color(0.5, 0.35, 0.2)
	shaft.add_point(Vector2(-60, 0))
	shaft.add_point(Vector2(50, 0))
	_arrow.add_child(shaft)
	var head: Polygon2D = Polygon2D.new()
	head.polygon = PackedVector2Array([Vector2(50, -12), Vector2(80, 0), Vector2(50, 12)])
	head.color = Color(0.75, 0.75, 0.8)
	_arrow.add_child(head)
	world.add_child(_arrow)
	_ok_glyph = Node2D.new()
	_ok_glyph.position = OK_GLYPH_POS
	_ok_glyph.visible = false
	_ok_glyph.add_child(_disc(64.0, Color(1.0, 1.0, 1.0, 0.35)))
	_ok_glyph.add_child(_disc(44.0, Color(0.15, 0.15, 0.2, 0.9)))
	_ok_glyph.add_child(_disc(26.0, Color(1.0, 0.9, 0.5, 0.95)))
	world.add_child(_ok_glyph)


func _disc(radius: float, color: Color) -> Polygon2D:
	var d: Polygon2D = Polygon2D.new()
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		pts.append(Vector2.from_angle(TAU * float(i) / 24.0) * radius)
	d.polygon = pts
	d.color = color
	return d


## True while the OK button shape is on screen (the arrow has landed and OK ends the beat).
func ok_glyph_shown() -> bool:
	return _ok_glyph != null and _ok_glyph.visible


## True while the faint Faithful Friend trail is drawn behind the arrow.
func arrow_trail_shown() -> bool:
	return _trail != null and _trail.visible


## Where the arrow is (tests: it must end far past the boy).
func arrow_x() -> float:
	return _arrow.position.x if _arrow != null else 0.0


func boy_x() -> float:
	return BOY_POS.x


func _on_begin() -> void:
	_apply_visuals(play_event(&"start"))
	_next_beat()


func report_stone_thrown() -> void:
	super()
	_note_throw()


func _note_throw() -> void:
	if not _thrown:
		_since_throw = 0.0
		_since_hit = 0.0
		_landed = false
	_thrown = true


## During the stone step the practice target is what the stone flies at.
func _pick_target() -> Node2D:
	if _practice != null and _practice.visible:
		return _practice
	return null


func _on_stone_hit(target: Node2D) -> void:
	if target == _practice and _practice != null:
		_practice.hit()
		request_sfx(&"hit")
		_landed = true
		_since_hit = 0.0


## OK in the tutorial throws a stone; in Lamb mode it plays the harp ring instead (no stone),
## which satisfies the stone-thrown step.
func on_action_tap() -> void:
	if _finished:
		return
	match waiting:
		Wait.TUTORIAL:
			if lamb_harp_mode():
				play_harp_tap()
				if _until == "stone-thrown":
					_note_throw()
					_landed = true
					if _practice != null and _practice.visible:
						_practice.hit(Color(1.0, 0.88, 0.45))
			else:
				super()
		Wait.LINE:
			if _wait_total - _wait_left >= BalanceData.feel("cutsceneMinLineSec"):
				_next_beat()
		Wait.OK:
			_next_beat()


## The hold has no use in a cutscene.
func on_action_hold() -> void:
	pass


func _step(delta: float) -> void:
	_clock += delta
	if _scene_kind == &"hills":
		# David walks on the grass, not up into the sky.
		david.position.y = maxf(david.position.y, STRAY_MIN_Y - 40.0)
	_fx_step(delta)
	if _scene != null:
		_scene.advance(delta)
	if _practice != null:
		_practice.advance(delta)
	match waiting:
		Wait.LINE:
			_wait_left -= delta
			if _wait_left <= 0.0:
				_next_beat()
		Wait.QUIET:
			_wait_left -= delta
			_quiet.scale = Vector2.ONE * (1.0 + 0.05 * sin(_clock * 1.3))
			_quiet.modulate.a = 0.75 + 0.25 * sin(_clock * 0.9)
			if _wait_left <= 0.0:
				_next_beat()
		Wait.CUTAWAY:
			_wait_left -= delta
			_move_cutaway()
			if _wait_left <= 0.0:
				_next_beat()
		Wait.TUTORIAL:
			_check_tutorial(delta)
		Wait.WATCH:
			_fly_arrow(delta)
		Wait.OK:
			_wait_left -= delta
			_ok_glyph.scale = Vector2.ONE * (1.0 + 0.12 * sin(elapsed * 6.0))
			if _wait_left <= 0.0:
				_next_beat()


func _check_tutorial(delta: float) -> void:
	_moved += david.position.distance_to(_last_pos)
	_last_pos = david.position
	var done: bool = false
	match _until:
		"david-moved":
			done = _moved >= BalanceData.feel("tutorialMovedDistance")
		"sheep-returned":
			done = _check_return(delta)
		"stone-thrown":
			done = _check_throw(delta)
		_:
			done = true
	if done:
		_next_beat()


## The stray is picked up when David is near, then visibly walks back to the flock; the step ends once it is there.
func _check_return(delta: float) -> bool:
	if not _returning:
		if _stray.state == ActorSheep.State.LOST and _stray.position.distance_to(david.position) <= BalanceData.feel("tutorialReturnRadius"):
			_stray.rescue(return_spot(), BalanceData.feel("sheepReturnSpeed"))
			report_sheep_saved()
			_returning = true
			_return_hold = 0.0
			_return_clock = 0.0
		return false
	_return_clock += delta
	# In the tree the sheep walks itself; outside it (tests) the stage steps it.
	if not _stray.is_inside_tree():
		_stray.advance_return(delta)
	if _stray.returning and _return_clock < RETURN_MAX_SEC:
		_stray.scale.x = -1.0 if return_spot().x < _stray.position.x else 1.0
		return false
	_stray.position = return_spot()
	if _scene != null:
		_scene.sheep_returned()
	_return_hold += delta
	return _return_hold >= RETURN_HOLD_SEC


## Where the returned sheep rejoins the flock.
func return_spot() -> Vector2:
	return ActorHills.RETURN_SPOT


## The throw step ends only after the stone has flown, landed and popped (or the harp ring has played).
func _check_throw(delta: float) -> bool:
	if not _thrown:
		return false
	_since_throw += delta
	if _landed:
		_since_hit += delta
	if _since_throw >= AFTER_THROW_SEC * 3.0:
		return true
	return _since_throw >= AFTER_THROW_SEC and _landed and _since_hit >= AFTER_HIT_SEC


func _next_beat() -> void:
	waiting = Wait.NONE
	_end_quiet()
	_ok_glyph.visible = false
	_hide_cutaways()
	david.visible = false
	_stray.visible = false
	_stray.scale.x = 1.0
	_stray.rotation = 0.0
	_practice.visible = false
	if _scene != null:
		_scene.set_glow(false)
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
			if _scene != null:
				_scene.set_glow(true)
			_show_line(beat, true)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"end-card":
			StageUtil.set_backdrop(backdrop, "end-card")
			_show_line(beat, false)
			_wait(Wait.LINE, float(beat.get("seconds", _line_sec)))
			return true
		"quiet-moment":
			_start_quiet(beat)
			return true
		"tutorial":
			_show_line(beat, false)
			_begin_tutorial(str(beat.get("until", "")))
			return true
		"interactive":
			return _start_interactive(beat)
		"unlock":
			report_grant(StringName(str(beat.get("id", ""))), 1)
			return false
		"grant":
			report_grant(StringName(str(beat.get("resource", ""))), int(beat.get("amount", 0)))
			return false
	return false


## The quiet moment: no input, the time runs out by itself. The beat's music cue is handed to the host.
func _start_quiet(beat: Dictionary) -> void:
	_wait(Wait.QUIET, float(beat.get("seconds", BalanceData.feel("cutsceneQuietSec"))))
	_quiet.visible = true
	var music: String = str(beat.get("music", ""))
	if not music.is_empty():
		_quiet_music = true
		music_requested.emit(StringName(music))


func _end_quiet() -> void:
	if _quiet == null or not _quiet.visible:
		return
	_quiet.visible = false
	if _quiet_music:
		_quiet_music = false
		music_requested.emit(&"")


## True while the quiet moment runs (tests; the player has no input then).
func quiet_active() -> bool:
	return waiting == Wait.QUIET


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
	_landed = false
	_returning = false
	_since_throw = 0.0
	_since_hit = 0.0
	_last_pos = david.position
	david.visible = true
	if _scene != null:
		_scene.begin_play()
	if until == "sheep-returned":
		_stray.set_state(ActorSheep.State.LOST)
		var p: Vector2 = (david.position + Vector2(420, -120)).clamp(FIELD.position, FIELD.end)
		if _scene_kind == &"hills":
			p.y = maxf(p.y, STRAY_MIN_Y)
		_stray.position = p
		_stray.visible = true
	elif until == "stone-thrown":
		_place_practice()


## The practice target stands a long throw away, on the side of David with more room.
func _place_practice() -> void:
	var side: float = 1.0 if david.position.x < FIELD.get_center().x else -1.0
	var x: float = clampf(david.position.x + side * TARGET_DISTANCE, FIELD.position.x + 80.0, FIELD.end.x - 80.0)
	var y: float = clampf(david.position.y - 110.0, FIELD.position.y + 260.0, FIELD.end.y - 170.0)
	_practice.position = Vector2(x, y)
	_practice.rotation = 0.0
	_practice.visible = true
	david.set_facing(Vector2(side, 0.0))


func _finish() -> void:
	waiting = Wait.NONE
	_end_quiet()
	_hide_arrow()
	_hide_cutaways()
	_end_effects()
	david.visible = false
	for b in play_event(&"win"):
		if b is Dictionary and str((b as Dictionary).get("type", "")) == "visual":
			StageUtil.set_backdrop(backdrop, str((b as Dictionary).get("cue", "")))
	win()


# --- Interactive beat: watch the arrow, then OK (3.3) ---

## `watch-then-ok`: starts the arrow flight. Other kinds are skipped. The beat's `then` beats are
## spliced in right after it and play once OK ends the beat.
func _start_interactive(beat: Dictionary) -> bool:
	if str(beat.get("kind", "")) != "watch-then-ok":
		return false
	var then: Variant = beat.get("then", [])
	if then is Array:
		for i in (then as Array).size():
			beats.insert(beat_index + 1 + i, (then as Array)[i])
	var sec: float = float(beat.get("seconds", 0.0))
	_wait(Wait.WATCH, sec if sec > 0.0 else BalanceData.feel("arrowFlightSec"))
	_boy.visible = true
	_arrow.visible = true
	_arrow.position = ARROW_FROM
	_trail.set_point_position(1, ARROW_FROM)
	_trail.visible = int(get_feature(&"arrowHintPerStage", 0)) > 0
	return true


func _fly_arrow(delta: float) -> void:
	_wait_left = maxf(_wait_left - delta, 0.0)
	var k: float = clampf(1.0 - _wait_left / maxf(_wait_total, 0.01), 0.0, 1.0)
	_arrow.position = ARROW_FROM.lerp(ARROW_TO, k) + Vector2(0.0, -sin(k * PI) * ARROW_ARC)
	_trail.set_point_position(1, _arrow.position)
	if k >= 1.0:
		waiting = Wait.OK
		_wait_left = BalanceData.feel("arrowWaitSec")
		_wait_total = _wait_left
		_ok_glyph.visible = true


func _hide_arrow() -> void:
	if _arrow == null:
		return
	_arrow.visible = false
	_trail.visible = false
	_boy.visible = false
	_ok_glyph.visible = false


# --- Visual cues and effects (2.3, 2.4, 2.7) ---

## Shows a visual cue. A cue that would show a fallen body is dropped. Timed cut-aways (the stone in
## flight, the soldiers' wide-eyed faces) hold the scene for `cutawaySec`. Returns true when it waits.
func _start_visual(cue: String) -> bool:
	if StageUtil.is_body_cue(cue):
		return false
	StageUtil.set_backdrop(backdrop, cue)
	_play_scene(cue)
	visual_requested.emit(StringName(cue))
	var kind: StringName = StageUtil.cutaway_kind(cue)
	if kind == &"":
		# The THUD cue shakes only when no shake beat already ran (it plays with the faces).
		if (cue.contains("thud") or cue.contains("shake")) and not _shaken:
			_start_shake(0.0, 0.0)
		return false
	_cutaway = kind
	if kind == &"faces" and _shake_left > 0.0:
		# The THUD shake belongs to the faces: it fades out inside the cut, never after it.
		_shake_left = minf(_shake_left, BalanceData.feel("cutawaySec"))
		_shake_total = _shake_left
	if kind == &"stone":
		_fx_stone.position = STONE_FROM
		_fx_stone.visible = true
	else:
		for f in _faces:
			f.visible = true
	_wait(Wait.CUTAWAY, BalanceData.feel("cutawaySec"))
	return true


## Draws the placeholder scene a visual cue stands for (see StageUtil.CUE_SCENES) and starts its action.
func _play_scene(cue: String) -> void:
	var kind: StringName = _scene_kind_of(cue)
	if kind == &"":
		return
	if _scene == null or _scene_kind != kind:
		if _scene != null:
			world.remove_child(_scene)
			_scene.queue_free()
		match kind:
			&"hills":
				_scene = ActorHills.new()
			&"night-hills":
				_scene = ActorArkNightHills.new()
			_:
				_scene = ActorHouse.new()
		_scene_kind = kind
		world.add_child(_scene)
		world.move_child(_scene, backdrop.get_index() + 1)
	_scene.play(_scene_action_of(cue))


func _scene_kind_of(cue: String) -> StringName:
	if LOCAL_CUE_SCENES.has(cue):
		return (LOCAL_CUE_SCENES[cue] as Array)[0] as StringName
	return StageUtil.scene_kind(cue)


func _scene_action_of(cue: String) -> StringName:
	if LOCAL_CUE_SCENES.has(cue):
		return (LOCAL_CUE_SCENES[cue] as Array)[1] as StringName
	return StageUtil.scene_action(cue)


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
	_shaken = true
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
