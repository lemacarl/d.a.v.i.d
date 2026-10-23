class_name StageRhythm
extends StageBase
## Rhythm stage with the single OK input (Chapter 1 harp). Notes float toward a gold line;
## OK while one is in the hit zone is a hit and brightens the room. Misses never end the stage.
## OK registers on PRESS here (the host's release-tap and any hold are ignored after a press).

const NOTE_POOL: int = 16
const LINE_X: float = 620.0
const LINE_Y: float = 540.0
const SPAWN_X: float = 1560.0
const TRACK_X0: float = 480.0
const TRACK_X1: float = 1620.0
const DARK: Color = Color(0.045, 0.035, 0.08)
const WARM: Color = Color(0.42, 0.27, 0.17)
const MISS_FADE_SEC: float = 0.6

var duration: float = 60.0
var elapsed: float = 0.0
var hits: int = 0
var misses: int = 0
var brightness: float = 0.0
var shown_brightness: float = 0.0
var miss_streak: int = 0

var world: Node2D = null
var backdrop: ColorRect = null
var room: ActorHarpRoom = null

## 1 = live note, 2 = missed note fading out (cannot be hit).
var _notes: Array[ActorNote] = []
var _note_x: PackedFloat32Array = PackedFloat32Array()
var _note_on: PackedByteArray = PackedByteArray()
var _note_fade: PackedFloat32Array = PackedFloat32Array()
var _spawn_gap: float = 1.5
var _spawn_timer: float = 0.0
var _note_speed: float = 0.0
var _window_px: float = 0.0
var _step_gain: float = 0.0
var _dim_amount: float = 0.0
var _dim_after: int = 3
var _approach_px: float = 1.0
var _press_pending: bool = false


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	if world != null:
		world.queue_free()
	duration = def.param_float("durationSec", 60.0)
	var npm: float = maxf(1.0, def.param_float("notesPerMinute", 1.0))
	_spawn_gap = 60.0 / npm
	_spawn_timer = 0.0
	_note_speed = def.param_float("noteSpeed", 0.0)
	_window_px = _note_speed * def.param_float("hitWindowSec", 0.0)
	_approach_px = maxf(1.0, _note_speed * def.param_float("approachSec", 1.2))
	var full_fraction: float = clampf(def.param_float("fullBrightHitFraction", 0.7), 0.05, 1.0)
	_step_gain = 1.0 / maxf(1.0, duration * npm / 60.0 * full_fraction)
	_dim_amount = _step_gain * maxf(0.0, def.param_float("missDimFraction", 0.0))
	_dim_after = maxi(1, def.param_int("missDimAfter", 3))
	_press_pending = false
	elapsed = 0.0
	hits = 0
	misses = 0
	miss_streak = 0
	brightness = 0.0
	shown_brightness = 0.0
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	backdrop = StageUtil.make_backdrop(world)
	room = ActorHarpRoom.new()
	room.line_x = LINE_X
	room.line_y = LINE_Y
	room.track_x0 = TRACK_X0
	room.track_x1 = TRACK_X1
	room.zone_radius = maxf(70.0, _window_px)
	world.add_child(room)
	_notes.clear()
	_note_x.resize(NOTE_POOL)
	_note_on.resize(NOTE_POOL)
	_note_fade.resize(NOTE_POOL)
	for i in NOTE_POOL:
		var n: ActorNote = ActorNote.new()
		n.visible = false
		world.add_child(n)
		_notes.append(n)
		_note_x[i] = 0.0
		_note_on[i] = 0
		_note_fade[i] = 0.0
	_apply_backdrop()


func _on_begin() -> void:
	_handle_rest(play_event(&"enter"))
	_apply_backdrop()


func _process(delta: float) -> void:
	tick(minf(delta, 0.1))


## Advances the stage by `delta` seconds (tests call this directly).
func tick(delta: float) -> void:
	if _finished or def == null:
		set_process(false)
		return
	elapsed += delta
	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		_spawn_timer += _spawn_gap
		_spawn_note()
	var nearest: float = INF
	for i in NOTE_POOL:
		if _note_on[i] == 0:
			continue
		_note_x[i] -= _note_speed * delta
		var n: ActorNote = _notes[i]
		n.position = Vector2(_note_x[i], LINE_Y)
		if _note_on[i] == 2:
			_note_fade[i] -= delta / MISS_FADE_SEC
			n.modulate.a = maxf(0.0, _note_fade[i])
			if _note_fade[i] <= 0.0:
				_retire(i)
			continue
		var d: float = _note_x[i] - LINE_X
		n.scale = Vector2.ONE * (1.0 + 0.06 * sin(elapsed * 6.0 + float(i)))
		if d >= 0.0:
			nearest = minf(nearest, d)
		if d < -_window_px:
			_note_on[i] = 2
			_note_fade[i] = 1.0
			_register_miss()
	shown_brightness += (brightness - shown_brightness) * minf(1.0, delta * 4.0)
	room.shown = shown_brightness
	room.approach = 0.0 if nearest == INF else clampf(1.0 - maxf(0.0, nearest - _window_px) / _approach_px, 0.0, 1.0)
	room.progress = clampf(elapsed / maxf(0.001, duration), 0.0, 1.0)
	room.step(delta)
	_apply_backdrop()
	if elapsed >= duration:
		_handle_rest(play_event(&"win"))
		_apply_backdrop()
		win()


## OK went down: the hit lands now, whatever the mode. The release tap that follows is ignored.
func on_action_press() -> void:
	_press_pending = true
	_try_hit()


## Lamb sends only this (on press); other modes send it on release after on_action_press.
func on_action_tap() -> void:
	if _press_pending:
		_press_pending = false
		return
	_try_hit()


func _try_hit() -> void:
	if _finished or room == null:
		return
	var best: int = -1
	var best_d: float = _window_px
	for i in NOTE_POOL:
		if _note_on[i] != 1:
			continue
		var d: float = absf(_note_x[i] - LINE_X)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		room.flash = maxf(room.flash, 0.3)
		return
	_retire(best)
	hits += 1
	miss_streak = 0
	brightness = minf(1.0, brightness + _step_gain)
	room.flash = 1.0
	room.pluck = 1.0
	room.burst(Vector2(LINE_X, LINE_Y), 12)
	request_sfx(&"harp")


func _register_miss() -> void:
	misses += 1
	miss_streak += 1
	if _dim_amount > 0.0 and miss_streak >= _dim_after:
		brightness = maxf(0.0, brightness - _dim_amount)


func _apply_backdrop() -> void:
	if backdrop != null:
		backdrop.color = DARK.lerp(WARM, shown_brightness)


func _spawn_note() -> void:
	for i in NOTE_POOL:
		if _note_on[i] == 0:
			_note_on[i] = 1
			_note_x[i] = SPAWN_X
			_notes[i].position = Vector2(SPAWN_X, LINE_Y)
			_notes[i].modulate.a = 1.0
			_notes[i].visible = true
			return


func _retire(i: int) -> void:
	_note_on[i] = 0
	_notes[i].visible = false


## Notes currently on screen (tests use this to place hits).
func active_notes() -> int:
	var n: int = 0
	for i in NOTE_POOL:
		if _note_on[i] == 1:
			n += 1
	return n


## True when a note is inside the hit window right now.
func note_in_window() -> bool:
	for i in NOTE_POOL:
		if _note_on[i] == 1 and absf(_note_x[i] - LINE_X) <= _window_px:
			return true
	return false


func _handle_rest(rest: Array) -> void:
	for b in rest:
		if not b is Dictionary:
			continue
		var beat: Dictionary = b as Dictionary
		var t: String = str(beat.get("type", ""))
		if t == "visual":
			StageUtil.set_backdrop(backdrop, str(beat.get("cue", "")))
		elif t == "end-card":
			var l: Dictionary = StageUtil.line_of(str(beat.get("line", "")))
			if not l.is_empty():
				request_line(StringName(str(l.get("speaker", "ui"))), str(l.get("text", "")), str(l.get("reference", "")))
