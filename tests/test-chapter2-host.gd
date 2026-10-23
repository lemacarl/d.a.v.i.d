extends RefCounted
## Chapter 2 through the real StageHost: OK press and release, the entry line queue, the win.

const U := preload("res://tests/ch2-util.gd")


func run(t: TestRunner) -> void:
	_lamb_entry_lines(t)
	_release_after_glow(t)
	_harp_hold_in_glow(t)
	RunState.set_stones(0)
	RunState.set_followers(0)
	RunState.end_run()


func _key(down: bool) -> InputEventAction:
	var ev: InputEventAction = InputEventAction.new()
	ev.action = &"ui_accept"
	ev.pressed = down
	return ev


## A live host on stage 2.6 in `mode`, entered through RunState with `stones` carried.
func _host(mode: RunModel.Mode, stones: int, blessing: StringName = &"") -> StageHost:
	RunState.start_chapter(2, mode)
	U.go_to(RunState, "2-6-goliath")
	if blessing != &"":
		RunState.add_blessing(blessing)
	RunState.set_stones(stones)
	var host: StageHost = StageHost.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(host)
	return host


## Loads the current stage into the host; `record` runs first, so it sees every line.
func _load(host: StageHost, record: Callable = Callable()) -> void:
	if record.is_valid():
		record.call()
	host.load_stage(RunState.current_stage)


## One simulated step of the host (line queue, hold timer) and its stage.
func _step(host: StageHost, seconds: float = 0.1) -> void:
	host._process(seconds)
	host._stage.tick(seconds)


func _until_glow(host: StageHost, max_sec: float = 120.0) -> void:
	var el: float = 0.0
	var s: StageGoliath = host._stage as StageGoliath
	while el < max_sec and not s.glow_active():
		_step(host)
		el += 0.1


func _finish(host: StageHost) -> void:
	host.clear_stage()
	host.free()
	Engine.time_scale = 1.0


func _lamb_entry_lines(t: TestRunner) -> void:
	var host: StageHost = _host(RunModel.Mode.LAMB, 5)
	var shown: Array[String] = []
	host._lines.line_started.connect(func(_sp: StringName, text: String, _r: String, _h: float, _st: bool) -> void: shown.append(text))
	_load(host)
	var s: StageGoliath = host._stage as StageGoliath
	t.truthy(s._gated, "Lamb: the stage waits for its entry lines")
	var el: float = 0.0
	while el < 120.0 and not s.glow_active():
		_step(host)
		el += 0.1
	t.truthy(s.glow_active(), "Lamb: the glow opens")
	t.truthy(host._lines.is_idle(), "Lamb: the line queue is empty when the first glow opens")
	t.eq(shown.size(), 4, "Lamb: three entry lines and the laugh were shown first")
	t.eq(shown[0], LineBook.line(&"c2-6-goliath-dog")["text"], "Lamb: the dog line comes first")
	t.eq(shown[1], LineBook.line(&"c2-6-david-sword")["text"], "Lamb: then the sword line")
	t.eq(shown[2], LineBook.line(&"c2-6-david-name")["text"], "Lamb: then the name line")
	t.eq(shown[3], LineBook.line(&"c2-6-laugh")["text"], "Lamb: the laugh line is shown before the glow")
	t.truthy(el > 9.0, "Lamb: the glow does not open over the entry lines (%s s)" % el)
	# The hit cuts away at once: nothing is left to show, so 2.7 follows the moment the stone lands.
	host._input(_key(true))
	var guard: int = 0
	while not s.is_finished() and guard < 100:
		_step(host)
		guard += 1
	t.eq(shown.size(), 4, "Lamb: no line is shown after the hit")
	t.eq(String(U.cur(RunState)), "2-7-victory", "Lamb: the hit goes straight to the victory scene")
	_finish(host)


func _release_after_glow(t: TestRunner) -> void:
	var host: StageHost = _host(RunModel.Mode.NORMAL, 5)
	_load(host)
	var s: StageGoliath = host._stage as StageGoliath
	_until_glow(host)
	t.truthy(s.glow_active(), "Normal: the glow opens")
	# Press 1.2 s before the glow closes and hold on: released 0.2 s after it closed (a 1.4 s press).
	s._phase_left = 1.2
	host._input(_key(true))
	for i in 14:
		_step(host)
	t.falsy(s.glow_active(), "Normal: the glow has closed")
	host._input(_key(false))
	var guard: int = 0
	while not s.is_finished() and guard < 100:
		_step(host)
		guard += 1
	t.truthy(s.is_finished(), "Normal: a press that began in the glow wins on release after it")
	t.eq(s.misses, 0, "Normal: the late release is not a miss")
	guard = 0
	while U.cur(RunState) != "2-7-victory" and guard < 400:
		_step(host, 0.2)
		guard += 1
	t.eq(String(U.cur(RunState)), "2-7-victory", "Normal: the win leads to 2.7")
	_finish(host)


func _harp_hold_in_glow(t: TestRunner) -> void:
	var host: StageHost = _host(RunModel.Mode.NORMAL, 5, &"song-of-courage")
	_load(host)
	var s: StageGoliath = host._stage as StageGoliath
	_until_glow(host)
	host._input(_key(true))
	for i in 25:
		_step(host)
	host._input(_key(false))
	t.falsy(s.is_finished(), "Normal: a hold of 2 s or more is the harp, not a hit")
	t.eq(s.misses, 0, "Normal: ...and not a miss")
	t.eq(RunState.model.stones, 5, "Normal: ...and costs no stone")
	_finish(host)
