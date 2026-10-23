class_name StageRhythm
extends StageBase
## Rhythm stage with the single OK input (Chapter 1 harp). Notes float toward a gold line;
## OK while one crosses it is a hit and brightens the room. Misses never end the stage.
##
## 3.2 spear dodge (`params.spearDodge`): while the harp plays, Saul throws spears. David stands in one
## of the lanes (D-pad left / right steps between them). A spear is aimed at David's lane: the lane
## glows for `glowSec`, then the spear flies for `spearFlightSec` (feel, or `spearDodge.flightSec`)
## and lands. Out of the lane = a dodge; in it = a hit (`take_hit`). `firstSpearSec` and `intervalSec`
## time the spears; `count` dodges win (the win kind `count-reached`, key `dodges`). `count` 0 or
## enemies off (Lamb) = no spears and the stage wins when `durationSec` ends. `spear-hits` in `lose`
## ends the stage after that many hits (`fail` is vetoed in Shepherd and Lamb, and absent from Shepherd
## data). Events: `spear-N` at the Nth glow (`spear-1` is Saul's line) and `win`.

const NOTE_POOL: int = 24
const LINE_X: float = 560.0
const LINE_Y: float = 540.0
const NOTE_SIZE: Vector2 = Vector2(48, 48)
const LANE_MAX: int = 3
const LANE_Y: float = 840.0
const LANE_TOP_Y: float = 90.0
const LANE_SIZE: Vector2 = Vector2(300, 440)
const DAVID_SCENE: PackedScene = preload("res://actors/actor-david.tscn")
const DARK: Color = Color(0.08, 0.07, 0.12)
const BRIGHT: Color = Color(0.95, 0.82, 0.5)

var duration: float = 60.0
var elapsed: float = 0.0
var hits: int = 0
var misses: int = 0
var brightness: float = 0.0
## Spear dodge state (3.2).
enum Spear { OFF, WAIT, GLOW, FLY }
var dodges: int = 0
var spear_hits: int = 0
var spears_thrown: int = 0
var lane: int = 0
var spear_phase: Spear = Spear.OFF
var spear_lane: int = 0

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
var _dodge_goal: int = 0
var _hit_limit: int = 0
var _glow_sec: float = 0.0
var _flight_sec: float = 0.0
var _interval_sec: float = 0.0
var _spear_timer: float = 0.0
var _lane_count: int = 0
var _lane_x: PackedFloat32Array = PackedFloat32Array()
var _lane_glow: Array[ColorRect] = []
var _david: ActorDavid = null
var _spear: ActorSpear = null
## Without spears (Lamb) Saul's scripted line still plays once, at the first spear time.
var _story_sec: float = -1.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	if world != null:
		world.queue_free()
	duration = def.param_float("durationSec", 60.0)
	if def.win_kind() == &"duration-elapsed" and def.win.has("seconds"):
		duration = float(def.win["seconds"])
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
	_setup_spears()


func _on_begin() -> void:
	_handle_rest(play_event(&"enter"))


func _process(delta: float) -> void:
	if Input.is_action_just_pressed(&"ui_left"):
		step_lane(-1)
	elif Input.is_action_just_pressed(&"ui_right"):
		step_lane(1)
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
	_spear_step(delta)
	if _finished:
		return
	if elapsed >= duration:
		_win_stage()


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


func _win_stage() -> void:
	_handle_rest(play_event(&"win"))
	win()


# --- Spear dodge (3.2) ---

func _setup_spears() -> void:
	dodges = 0
	spear_hits = 0
	spears_thrown = 0
	lane = 0
	spear_lane = 0
	spear_phase = Spear.OFF
	_lane_glow.clear()
	_david = null
	_spear = null
	_story_sec = -1.0
	var cfg: Dictionary = def.param_dict("spearDodge")
	var lanes: Array = def.param_array("spearDodge.lanes")
	_lane_count = clampi(lanes.size(), 0, LANE_MAX)
	_dodge_goal = int(cfg.get("count", 0))
	if _dodge_goal <= 0 or _lane_count < 2 or not enemies_enabled():
		if cfg.has("firstSpearSec") and not def.beats(&"spear-1").is_empty():
			_story_sec = float(cfg["firstSpearSec"])
		return
	_hit_limit = int(def.lose_for(&"spear-hits").get("count", 0))
	_glow_sec = float(cfg.get("glowSec", 0.0))
	_flight_sec = float(cfg.get("flightSec", BalanceData.feel("spearFlightSec")))
	_interval_sec = float(cfg.get("intervalSec", 0.0))
	_spear_timer = float(cfg.get("firstSpearSec", _interval_sec))
	spear_phase = Spear.WAIT
	var offset: float = BalanceData.feel("spearLaneOffsetPx")
	_lane_x.resize(_lane_count)
	for i in _lane_count:
		_lane_x[i] = StageUtil.SCREEN.x * 0.5 + (float(i) / float(_lane_count - 1) - 0.5) * offset * 2.0
		var g: ColorRect = ColorRect.new()
		g.color = Color(1.0, 0.35, 0.25, 0.0)
		g.size = LANE_SIZE
		g.position = Vector2(_lane_x[i] - LANE_SIZE.x * 0.5, LANE_Y - LANE_SIZE.y + 120.0)
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		world.add_child(g)
		_lane_glow.append(g)
	_david = DAVID_SCENE.instantiate() as ActorDavid
	_david.position = Vector2(_lane_x[0], LANE_Y)
	world.add_child(_david)
	_spear = ActorSpear.new()
	_spear.rotation = -PI * 0.5
	_spear.visible = false
	world.add_child(_spear)


## True when this stage throws spears (Normal and Shepherd 3.2; never in Lamb).
func spears_enabled() -> bool:
	return spear_phase != Spear.OFF


## D-pad left (-1) or right (+1): David steps to the next lane. No-op without spears.
func step_lane(dir: int) -> void:
	if _finished or _david == null:
		return
	lane = clampi(lane + dir, 0, _lane_count - 1)
	_david.position.x = _lane_x[lane]
	_david.set_facing(Vector2(float(dir), 0.0))


func _spear_step(delta: float) -> void:
	if _david == null:
		if _story_sec >= 0.0 and elapsed >= _story_sec:
			_story_sec = -1.0
			_handle_rest(play_event(&"spear-1"))
		return
	_spear_timer -= delta
	match spear_phase:
		Spear.WAIT:
			if _spear_timer <= 0.0:
				_start_glow()
		Spear.GLOW:
			var k: float = clampf(1.0 - _spear_timer / maxf(_glow_sec, 0.01), 0.0, 1.0)
			_lane_glow[spear_lane].color.a = 0.15 + 0.4 * k
			if _spear_timer <= 0.0:
				spear_phase = Spear.FLY
				_spear_timer = _flight_sec
				_spear.position = Vector2(_lane_x[spear_lane], LANE_TOP_Y)
				_spear.visible = true
				request_sfx(&"bounce")
		Spear.FLY:
			var f: float = clampf(1.0 - _spear_timer / maxf(_flight_sec, 0.01), 0.0, 1.0)
			_spear.position.y = lerpf(LANE_TOP_Y, LANE_Y, f)
			if _spear_timer <= 0.0:
				_land_spear()


func _start_glow() -> void:
	spears_thrown += 1
	spear_lane = lane
	spear_phase = Spear.GLOW
	_spear_timer = _glow_sec
	_lane_glow[spear_lane].color.a = 0.15
	_handle_rest(play_event(StringName("spear-%d" % spears_thrown)))


func _land_spear() -> void:
	_spear.visible = false
	_lane_glow[spear_lane].color.a = 0.0
	spear_phase = Spear.WAIT
	_spear_timer = _interval_sec
	if lane == spear_lane:
		spear_hits += 1
		take_hit(1)
		if _hit_limit > 0 and spear_hits >= _hit_limit:
			fail(&"spear-hits")
		return
	dodges += 1
	request_sfx(&"pickup")
	if dodges >= _dodge_goal and def.win_kind() == &"count-reached":
		_win_stage()


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
