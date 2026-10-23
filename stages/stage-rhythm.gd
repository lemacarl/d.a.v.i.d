class_name StageRhythm
extends StageBase
## Rhythm stage with the single OK input (Chapter 1 harp). Notes float toward a gold line;
## OK while one crosses it is a hit and brightens the room. Misses never end the stage.

const NOTE_POOL: int = 24
const LINE_X: float = 560.0
const LINE_Y: float = 540.0
const NOTE_SIZE: Vector2 = Vector2(48, 48)
const DARK: Color = Color(0.08, 0.07, 0.12)
const BRIGHT: Color = Color(0.95, 0.82, 0.5)

var duration: float = 60.0
var elapsed: float = 0.0
var hits: int = 0
var misses: int = 0
var brightness: float = 0.0

var world: Node2D = null
var backdrop: ColorRect = null

var _room: ColorRect = null
var _line: ColorRect = null
var _notes: Array[ColorRect] = []
var _note_x: PackedFloat32Array = PackedFloat32Array()
var _note_on: PackedByteArray = PackedByteArray()
var _spawn_gap: float = 1.5
var _spawn_timer: float = 0.0
var _note_speed: float = 0.0
var _window_px: float = 0.0
var _step_gain: float = 0.0


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
	_step_gain = 1.0 / maxf(1.0, duration * npm / 60.0)
	elapsed = 0.0
	hits = 0
	misses = 0
	brightness = 0.0
	world = Node2D.new()
	world.name = "World"
	add_child(world)
	backdrop = StageUtil.make_backdrop(world)
	_room = ColorRect.new()
	_room.size = StageUtil.SCREEN
	_room.color = Color(1, 0.9, 0.6, 0.0)
	_room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world.add_child(_room)
	_line = ColorRect.new()
	_line.color = Color(1.0, 0.84, 0.2)
	_line.position = Vector2(LINE_X - 3.0, LINE_Y - 200.0)
	_line.size = Vector2(6, 400)
	world.add_child(_line)
	_notes.clear()
	_note_x.resize(NOTE_POOL)
	_note_on.resize(NOTE_POOL)
	for i in NOTE_POOL:
		var n: ColorRect = ColorRect.new()
		n.color = Color(0.9, 0.95, 1.0)
		n.size = NOTE_SIZE
		n.visible = false
		world.add_child(n)
		_notes.append(n)
		_note_x[i] = 0.0
		_note_on[i] = 0


func _on_begin() -> void:
	_handle_rest(play_event(&"enter"))


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
	for i in NOTE_POOL:
		if _note_on[i] == 0:
			continue
		_note_x[i] -= _note_speed * delta
		_notes[i].position = Vector2(_note_x[i] - NOTE_SIZE.x * 0.5, LINE_Y - NOTE_SIZE.y * 0.5)
		if _note_x[i] < LINE_X - _window_px:
			_retire(i)
			misses += 1
	if elapsed >= duration:
		_handle_rest(play_event(&"win"))
		win()


func on_action_tap() -> void:
	if _finished:
		return
	var best: int = -1
	var best_d: float = _window_px
	for i in NOTE_POOL:
		if _note_on[i] == 0:
			continue
		var d: float = absf(_note_x[i] - LINE_X)
		if d <= best_d:
			best_d = d
			best = i
	if best < 0:
		return
	_retire(best)
	hits += 1
	brightness = minf(1.0, brightness + _step_gain)
	_room.color = Color(BRIGHT.r, BRIGHT.g, BRIGHT.b, brightness * 0.6)


func _spawn_x() -> float:
	return StageUtil.SCREEN.x - 96.0


func _spawn_note() -> void:
	for i in NOTE_POOL:
		if _note_on[i] == 0:
			_note_on[i] = 1
			_note_x[i] = _spawn_x()
			_notes[i].visible = true
			return


func _retire(i: int) -> void:
	_note_on[i] = 0
	_notes[i].visible = false


## Notes currently on screen (tests use this to place hits).
func active_notes() -> int:
	var n: int = 0
	for i in NOTE_POOL:
		n += _note_on[i]
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
