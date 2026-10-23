class_name StagePatience
extends StagePlayBase
## Stage type `patience` (4.4, the sound in the treetops). The Philistines gather in the valley of Rephaim,
## the trees sway and the wind blows (cue `windSfx`). OK before the treetops rustle only makes David's men
## say the `earlyLine` (a data line, at most once per `earlyCooldownSec`); it never fails and never costs
## anything. After a delay drawn from `rustleDelaySecRange` the treetops rustle with a marching sound
## (cue `marching`, trees lit); OK within `rustleWindowSec` sends the army charging and the Philistines flee
## (no gore), then the stage is won. If the window passes the rustle goes quiet and comes again after the
## shortest delay of the range, for ever, so the stage can never stall. Watchful Eyes, Smooth Stones, Song of
## Courage and the other Blessings change nothing here. Params: rustleDelaySecRange, rustleWindowSec,
## earlyLine, earlyCooldownSec, windSfx. Events: `enter`, `win`.

enum Phase { WAIT, RUSTLE, CHARGE, DONE }

const TREE_COUNT: int = 7
const MEN_COUNT: int = 4
const FOE_COUNT: int = 5
const WIND_PERIOD_SEC: float = 5.0
const CHARGE_SEC: float = 2.4
const CHARGE_SPEED: float = 420.0
const FLEE_SPEED: float = 620.0
const HOLD_MAX_SEC: float = 25.0
const DEFAULT_COOLDOWN_SEC: float = 1.5
const MARCH_CUE: StringName = &"marching"

var phase: Phase = Phase.WAIT
var misses: int = 0
var early_presses: int = 0
var early_lines: int = 0
var rustles: int = 0
var window_sec: float = 1.5
var delay_range: Vector2 = Vector2(8.0, 14.0)
var trees: Array[ActorTree] = []
var men: Array[ActorFigure] = []
var foes: Array[ActorFigure] = []

var _wait_left: float = 0.0
var _window_left: float = 0.0
var _charge_left: float = 0.0
var _wind_left: float = 0.0
var _cooldown_left: float = 0.0
var _cooldown_sec: float = DEFAULT_COOLDOWN_SEC
var _early_line: StringName = &""
var _wind_cue: StringName = &"wind"
var _press_seen: bool = false
var _lines_ready: bool = true
var _hold_clock: float = 0.0


func setup(stage_def: StageDef, run_model: RunModel, stack: ModifierStack) -> void:
	super(stage_def, run_model, stack)
	var r: Array = def.param_array("rustleDelaySecRange")
	if r.size() >= 2:
		delay_range = Vector2(float(r[0]), float(r[1]))
	delay_range.x = maxf(delay_range.x, 0.5)
	delay_range.y = maxf(delay_range.y, delay_range.x)
	window_sec = maxf(def.param_float("rustleWindowSec", 1.5), 0.1)
	_cooldown_sec = def.param_float("earlyCooldownSec", DEFAULT_COOLDOWN_SEC)
	_early_line = StringName(def.param_string("earlyLine", ""))
	_wind_cue = StringName(def.param_string("windSfx", "wind"))
	phase = Phase.WAIT
	misses = 0
	early_presses = 0
	early_lines = 0
	rustles = 0
	_press_seen = false
	_cooldown_left = 0.0
	_window_left = 0.0
	_charge_left = 0.0
	_wind_left = 0.0
	_hold_clock = 0.0
	_lines_ready = not wait_for_lines
	_wait_left = _rng.randf_range(delay_range.x, delay_range.y)
	trees.clear()
	men.clear()
	foes.clear()
	backdrop.color = Color(0.45, 0.62, 0.78)
	StageUtil.make_rect(world, Rect2(0, 620, StageUtil.SCREEN.x, 460), Color(0.36, 0.5, 0.28))
	_build_trees()
	_build_foes()
	_build_men()
	david.position = Vector2(300.0, 880.0)
	world.move_child(david, -1)


func _on_begin() -> void:
	spawn_companion_if_blessed()
	request_sfx(_wind_cue)
	_wind_left = WIND_PERIOD_SEC
	_apply_visuals(play_event(&"enter"))


func on_lines_drained() -> void:
	_lines_ready = true


func _build_trees() -> void:
	for i in TREE_COUNT:
		var t: ActorTree = ActorTree.new()
		t.tree_height = 300.0 + float(i % 3) * 40.0
		t.phase = float(i) * 0.9
		t.position = Vector2(lerpf(160.0, 1760.0, float(i) / float(TREE_COUNT - 1)), 600.0 + float(i % 2) * 40.0)
		world.add_child(t)
		trees.append(t)


func _build_foes() -> void:
	for i in FOE_COUNT:
		var f: ActorFigure = ActorFigure.new().setup(190.0, Color(0.5, 0.25, 0.25), Color(0.2, 0.15, 0.1))
		f.position = Vector2(1250.0 + float(i) * 120.0, 800.0 + float(i % 3) * 60.0)
		world.add_child(f)
		foes.append(f)


func _build_men() -> void:
	for i in MEN_COUNT:
		var m: ActorFigure = ActorFigure.new().setup(190.0, Color(0.3, 0.45, 0.7), Color(0.25, 0.16, 0.1))
		m.position = Vector2(120.0 + float(i) * 70.0, 800.0 + float(i % 2) * 70.0)
		world.add_child(m)
		men.append(m)


# ---- Input ---------------------------------------------------------------------------------------------

## OK acts on the press (the tap that follows on release is dropped); Lamb only sends the tap.
func on_action_press() -> void:
	_press_seen = true
	_ok()


func on_action_tap() -> void:
	if _press_seen:
		_press_seen = false
		return
	_ok()


func _ok() -> void:
	if _finished or phase == Phase.CHARGE or phase == Phase.DONE:
		return
	if phase == Phase.RUSTLE:
		_start_charge()
		return
	early_presses += 1
	if _cooldown_left > 0.0 or _early_line == &"":
		return
	_cooldown_left = _cooldown_sec
	var l: Dictionary = LineBook.line(_early_line)
	if not l.is_empty():
		early_lines += 1
		emit_story_line(l)


func _start_charge() -> void:
	phase = Phase.CHARGE
	_charge_left = CHARGE_SEC
	for t in trees:
		t.lit = false


# ---- Time ----------------------------------------------------------------------------------------------

func _step(delta: float) -> void:
	_cooldown_left = maxf(0.0, _cooldown_left - delta)
	var amount: float = 0.05
	var speed: float = 1.6
	match phase:
		Phase.WAIT:
			_tick_wait(delta)
		Phase.RUSTLE:
			amount = 0.11
			speed = 17.0
			_window_left -= delta
			if _window_left <= 0.0:
				_end_window()
		Phase.CHARGE:
			amount = 0.07
			speed = 3.0
			_tick_charge(delta)
	for t in trees:
		t.animate(elapsed, amount, speed)


func _tick_wait(delta: float) -> void:
	_wind_left -= delta
	if _wind_left <= 0.0:
		_wind_left = WIND_PERIOD_SEC
		request_sfx(_wind_cue)
	if not _lines_ready:
		_hold_clock += delta
		if _hold_clock >= HOLD_MAX_SEC:
			_lines_ready = true
		return
	_wait_left -= delta
	if _wait_left <= 0.0:
		phase = Phase.RUSTLE
		_window_left = window_sec
		rustles += 1
		request_sfx(MARCH_CUE)
		for t in trees:
			t.lit = true


## The window passed without OK: the treetops go quiet and the rustle comes again soon.
func _end_window() -> void:
	misses += 1
	phase = Phase.WAIT
	_wait_left = delay_range.x
	_wind_left = WIND_PERIOD_SEC
	for t in trees:
		t.lit = false


func _tick_charge(delta: float) -> void:
	_charge_left -= delta
	for i in men.size():
		men[i].position.x += CHARGE_SPEED * delta
		men[i].position.y += sin(elapsed * 18.0 + float(i)) * 1.5
	for f in foes:
		f.position.x += FLEE_SPEED * delta
	if _charge_left <= 0.0:
		phase = Phase.DONE
		_apply_visuals(play_event(&"win"))
		win()
